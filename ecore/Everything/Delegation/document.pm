package Everything::Delegation::document;

use strict;
use warnings;

# Used in: findings_, sql_prompt
use Time::HiRes;

# Used in: ajax_update
use JSON;
use Everything::Delegation::opcode;

# Used in: dr_nates_secret_lab_2 (resurrect, opencoffin), nodeheaven for safe deserialization
use Everything::Serialization qw(safe_deserialize_dumper);

BEGIN {
    *getNode         = *Everything::HTML::getNode;
    *getNodeById     = *Everything::HTML::getNodeById;
    *getVars         = *Everything::HTML::getVars;
    *getId           = *Everything::HTML::getId;
    *urlGen          = *Everything::HTML::urlGen;
    *linkNode        = *Everything::HTML::linkNode;
    *htmlcode        = *Everything::HTML::htmlcode;
    *parseLinks      = *Everything::HTML::parseLinks;
    *isNodetype      = *Everything::HTML::isNodetype;
    *getRef          = *Everything::HTML::getRef;
    *getType         = *Everything::HTML::getType;
    *updateNode      = *Everything::HTML::updateNode;
    *setVars         = *Everything::HTML::setVars;
    *linkNodeTitle   = *Everything::HTML::linkNodeTitle;
    *canUpdateNode   = *Everything::HTML::canUpdateNode;
    *updateLinks     = *Everything::HTML::updateLinks;
    *canReadNode     = *Everything::HTML::canReadNode;
    *encodeHTML      = *Everything::HTML::encodeHTML;
}

# Used by your_gravatar, recent_users
use Digest::MD5;

# Used by Node Backup
use Everything::S3;
use IO::Compress::Zip;
use utf8;

sub confirm_password {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $token    = $query->param('token');
    my $action   = $query->param('action');
    my $expiry   = $query->param('expiry');
    my $username = $query->param('user');

    unless ( $token and $action and $username ) {
        return q|<p>To use this page, please click on or copy and paste the link from the email we sent you. </p><p>If we didn't send you an email, you don't need this page.</p>|;
    }

    return '<p>Invalid action.</p>'
      unless ( $action eq 'activate' || $action eq 'reset' );

    my $user = getNode( $username, 'user' );

    if ( $expiry && time() > $expiry ) {

        # make sure unactivated account is gone in case they want to recreate it
        $DB->nukeNode( $user, -1, 'no tombstone' )
          if $action eq 'activate'
          && $user
          && !$user->{lasttime}
          && $expiry =~ /$$user{passwd}/;

        return $query->p(
            'This link has expired. But you can '
              . linkNode(
                getNode(
                    $action eq 'reset' ? 'Reset password' : 'Sign up',
                    'superdoc'
                ),
                'get a new one'
              )
              . '.'
        );
    }

    return $query->p(
        'The account you are trying to activate does not exist. But you can '
          . linkNode( getNode( 'Sign up', 'superdoc' ), 'create a new one' )
          . '.' )
      unless $user;

    return
      q|<p>We're sorry, but we don't accept new users from the IP address you used to create this account. Please get in touch with us if you think this is a mistake.</p>| if $action eq 'activate' && $user->{acctlock};

    my $prompt = '';

    if ( $query->param('op') ne 'login' ) {

        # check for locked-user infection...
        my $newVars = getVars($user);
        if ( $newVars->{infected} ) {

            # new user infects current user
            $VARS->{infected} = 1 unless $APP->isGuest($USER);

        }
        elsif ( htmlcode('checkInfected') ) {

            # current user infects new user
            $newVars->{infected} = 1;
            setVars( $user, $newVars );
        }

        $action = 'validate' if $newVars->{infected};
        $prompt = "Please log in with your username and password to $action your account";

    }
    elsif ($USER->{title} ne $username
        || $USER->{salt} eq $query->param('oldsalt') )
    {
        $prompt = 'Password or link invalid. Please try again';
    }

    $query->delete('passwd');

    return htmlcode('openform')
      . $query->fieldset(
        { style => 'width: 25em; max-width: 100%; margin: 3em auto 0' },
        $query->legend('Log in')
          . $query->p( $prompt . ':' )
          . $query->p(
            { style => 'text-align: right' },
            $query->label(
                'Username:'
                  . $query->textfield(
                    -name     => 'user',
                    readonly  => 'readonly',
                    size      => 30,
                    maxlength => 240
                  )
              )
              . '<br>'
              . $query->label(
                'Password:' . $query->password_field('passwd', '', 30, 240 )
              )
              . '<br>'
              . $query->checkbox( 'expires', '', '+10y', 'stay logged in' )
              . '<br>'
              . $query->submit( 'sockItToMe', $action )
          )
      )
      . $query->hidden('token')
      . $query->hidden('action')
      . $query->hidden('expiry')
      . $query->hidden( 'oldsalt', $USER->{salt} )
      . $query->hidden( -name => 'op', value => 'login', force => '1' )
      . '</form>'
      if $prompt;

    return q|<p>Password updated. You are logged in.</p>| if $action eq 'reset';

    # send welcome message
    htmlcode(
        'sendPrivateMessage',
        {
            'author_id'    => getId( getNode( 'Virgil', 'user' ) ),
            'recipient_id' => $USER->{node_id},
            'message'      =>
                q|Welcome to E2! We hope you're enjoying the site. If you haven't already done so, we recommend reading both [E2 Quick Start] and [Links on Everything2] before you start writing anything. If you have any questions or need help, feel free to ask any editor (editors have a \$ next to their names in the Other Users list)|
        }
    );

    return q|<p>Your account has been activated and you have been logged in.</p><p>Perhaps you'd like to edit |
      . linkNode( $USER, 'your profile' )
      . q|, or check out the logged-in users' <a href="/">front page</a>, or maybe just read <a href="/?op=randomnode">something at random</a>.|;

}

sub display_categories {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $canContributePublicCategory = ( $APP->getLevel($USER) >= 1 );
    my $guestUser                   = $Everything::CONF->guest_user;
    my $uid                         = $USER->{user_id};
    my $isCategory                  = 0;
    my $linktype = getId( getNode( 'category', 'linktype' ) );

    my $sql = '';
    my $ds  = undef;
    my $str = '';
    my $ctr = 0;

    my $count = 50;
    my $page  = int( $query->param('p') );
    if ( $page < 0 ) {
        $page = 0;
    }

    my $maintainerName = $query->param('m') // '';
    $maintainerName =~ s/^\s+|\s+$//g;
    my $maintainer = undef;

    if ( length($maintainerName) > 0 ) {
        $maintainer = getNode( $maintainerName, 'user' );
        if ( !$maintainer->{node_id} ) {
            $maintainer = getNode( $maintainerName, 'usergroup' );
            if ( !$maintainer->{node_id} ) {
                $maintainerName = '';
                $maintainer->{node_id} = 0;
            }
        }
    }

    my $userType      = getId( getType('user') );
    my $usergroupType = getId( getType('usergroup') );
    my $categoryType  = getId( getType('category') );

    my $order = $query->param('o') // '';

    $str .= q|<form method="get" action="/index.pl">|;
    $str .= q|<input type="hidden" name="node_id" value="| . getId($NODE);
    $str .= q|" />|;
    $str .= q|<table><tr><td><b>Maintained By:</b></td><td>|;
    $str .= $query->textfield(
        -name      => 'm',
        -default   => $maintainerName,
        -size      => 25,
        -maxlength => 255
    );

    $str .= q| (leave blank to list all categories)</td>|;
    $str .= q|</tr><tr><td><b>Sort Order:</b></td><td>|;
    $str .= q|<select name="o">|;
    $str .= q|<option value="">Category Name</option>|;
    $str .= q|<option value="m">Maintainer</option>|;
    $str .= q|</select></td></tr></table>|;
    $str .= $query->submit( 'submit', 'Submit');
    $str .= $query->end_form;

    my $contribute = "";
    $contribute = q|<th>Can I Contribute?</th>| if !$APP->isGuest($USER);

    $str .= q|<table width="100%"><tr>|;
    $str .= qq|<th>Category</th><th>Maintainer</th>$contribute</tr>|;

    my $orderBy = 'n.title,a.title';

    if ( $order eq 'm' ) {
        $orderBy = 'a.title,n.title';
    }

    my $authorRestrict = '';
    $authorRestrict = "AND n.author_user = $$maintainer{node_id}\n"
      if ( $maintainer && ($maintainer->{node_id} // 0) > 0 );

    my $startAt = $page * $count;

    $sql = "SELECT n.node_id, n.title, n.author_user
    , a.title AS maintainer
    , a.type_nodetype AS maintainerType
    FROM node n
    JOIN node a
    ON n.author_user = a.node_id
    WHERE n.type_nodetype = $categoryType
    $authorRestrict
    AND n.title NOT LIKE '%\_root'
    ORDER BY $orderBy
    LIMIT $startAt,$count";

    $ds = $DB->{dbh}->prepare($sql);
    $ds->execute() or return $ds->errstr;
    while ( my $n = $ds->fetchrow_hashref ) {
        my $maintName        = $n->{maintainer};
        my $maintId          = $n->{author_user};
        my $isPublicCategory = ( $guestUser == $maintId );

        $ctr++;
        if ( $ctr % 2 == 0 ) {
            $str .= '<tr class="evenrow">';
        }
        else {
            $str .= '<tr class="oddrow">';
        }
        $str .= '<td>' . linkNode( $n->{node_id}, $n->{title} ) . '</td>';

        my $authorLink = linkNode( $n->{author_user}, $maintName );
        $authorLink = 'Everyone' if $isPublicCategory;
        $authorLink .= ' (usergroup)'
          if ( $n->{maintainerType} == $usergroupType );

        $str .= qq|<td style="text-align:center">$authorLink</td>\n|;

        if ( !$APP->isGuest($USER) ) {
            $str .= '<td style="text-align:center">';
            if (   ( $isPublicCategory and $canContributePublicCategory )
                or ( $maintId == $uid ) )
            {
                $str .= '<b>Yes!</b>';
            }
            elsif ($n->{maintainerType} == $usergroupType
                && $APP->inUsergroup( $uid, $maintName ) )
            {
                $str .= '<b>Yes!</b>';
            }
            else {
                $str .= 'No';
            }
            $str .= "</td>\n";
        }

        $str .= '</tr>';
    }

    if ( $ctr <= 0 ) {
        $str .= '<tr><td colspan="2"><em>No categories found!</em></td></tr>';
    }
    $str .= '</table>';

    $str .= '<p style="text-align:center">';
    if ( $page > 0 ) {
        $str .=
            '<a href="/index.pl?node_id='
          . getId($NODE) . '&p='
          . ( $page - 1 ) . '&m='
          . $maintainerName . '&o='
          . $order
          . '">&lt;&lt; Previous</a>';
    }

    $str .= ' | <b>Page ' . ( $page + 1 ) . '</b> | ';
    if ( $ctr >= $count ) {
        $str .=
            '<a href="/index.pl?node_id='
          . getId($NODE) . '&p='
          . ( $page + 1 ) . '&m='
          . $maintainerName . '&o='
          . $order
          . '">Next &gt;&gt;</a>';
    }
    $str .= '</p>';

    return $str;

}

sub e2_collaboration_nodes {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = '';

    # To be done:
    #   "create" for crtleads:
    #       allow "create by all" with a create maintainance that
    #       forbids preterite users from creating;
    #
    #   "delete" for editors/crtleads:
    #       allow "delete by all" with delete maintainance, or
    #       just allow delete by CEs and let non-CE crtleads lump
    #       it?
    #
    #   Test, test, test the locking code.
    #       Maybe ask nate how that feature was intended to work,
    #       or hey, maybe it exists in a later version of
    #       ecore...?
    #
    #   Damn, we need ACLs.

    #---------------------------------------------------------
    # Is the user allowed in?

    return "<p>Permission denied.</p>" unless ( $APP->isEditor($USER) );

    $str .= qq|<p><b>Here's how these puppies operate:</b></p>|;
    $str .= qq|<dl><dt><b>Access</b></dt><dd>|;
    $str .=
      qq|<p>Any CE or god can view or edit any collaboration node. A regular |;
    $str .=
      qq|user can't, unless one of us explicitly grants access. You grant |;
    $str .= qq|access by editing the node and adding the user's name to the |;
    $str .=
      qq|"Allowed Users" list for that node (just type it into the box; it |;
    $str .= qq|should be clear). You can also add a user<em>group</em> to the |;
    $str .=
      qq|list: In that case, every user who belongs to that group will have |;
    $str .= qq|access (<em>full</em> access) to the node. </p></dd> |;

    $str .= qq|<dt><b>Locking</b></dt>|;
    $str .= qq|<dd>|;
    $str .=
      qq|<p>The only difficulty with this is the fact that two different |;
    $str .=
      qq|users will, inevitably, end up trying to edit the same node at the |;
    $str .=
      qq|same time. They'll step on each other\'s changes. We handle this |;
    $str .= qq|problem the way everybody does: When somebody begins editing a |;
    $str .=
      qq|collaboration node, it is automatically "locked". CEs and gods can |;
    $str .= qq|forcibly unlock a collaboration node, but don't |;
    $str .= qq|do it too casually because, once again, you may step on the |;
    $str .= qq|user's changes. Any user can voluntarily release his or her |;
    $str .= qq|<em>own</em> lock on a collaboration node (but they'll forget |;
    $str .= qq|which is why you can do it yourself). Finally, all "locks" on |;
    $str .= qq|these nodes expire after fifteen idle minutes, or maybe it's |;
    $str .=
      qq|twenty. I can't remember. <strong>Use it or lose it.</strong></p>|;

    $str .= qq|<p>The "locking" feature may be a bit perplexing at first, but |;
    $str .= qq|it's necessary if the feature is to be useful in practice. |;
    $str .= qq|</p></dd></dl><br />|;
    $str .= qq|<p>The HTML "rules" here are the same as for writeups, except |;
    $str .= qq|that you can also use the mysterious and powerful |;
    $str .= qq|&lt;highlight&gt; tag. </p>|;

    $str .= '
    <hr />
    <b>Search for a collaboration node:</b><br />
    <form method="post" enctype="application/x-www-form-urlencoded">
    <input type="text" name="node" value="" size="50" maxlength="64">
    <input type="hidden" name="type" value="collaboration">
    <input type="submit" name="searchy" value="search">
    <br />
    <input type="checkbox" name="soundex" value="1" default="0">Near Matches
    <input type="checkbox" name="match_all" value="1" default="0">Ignore Exact
    </form>';

    $str .= '
    <hr />
    <b>Create a new collaboration node:</b><br />
    <form method="post">
    <input type="hidden" name="op" value="new">
    <input type="hidden" name="type" value="collaboration">
    <input type="hidden" name="displaytype" value="useredit">
    <input type="text" size="50" maxlength="64" name="node" value="">
    <input type="submit" value="create">
    </form>';

    $str .= '<br /><br /><br /><br />
    <p><i>Bug reports and tearful accusations (or admissions) of 
    infidelity go to <a href="/index.pl?node_id=470183">wharfinger</a>.</i></p>';

    return $str;
}

sub e2_gift_shop {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = qq|<p>Welcome to the Everything2 Gift Shop!</p>|;

    $str .= htmlcode("giftshop_star") // '';
    $str .= htmlcode("giftshop_sanctify") // '';
    $str .= htmlcode("giftshop_buyvotes") // '';
    $str .= htmlcode("giftshop_votes") // '';
    $str .= htmlcode("giftshop_ching") // '';
    $str .= htmlcode("giftshop_buyching") // '';
    $str .= htmlcode("giftshop_topic") // '';
    $str .= htmlcode("giftshop_buyeggs") // '';
    $str .= htmlcode("giftshop_eggs") // '';

    $str .= qq|<p><hr width='300' /></p><p><b>Self Eggsamination</b></p>|;

    if ( $$VARS{GPoptout} ) {
        $str .=
            "<p>You currently have <b>"
          . ( $VARS->{easter_eggs} || "0" )
          . "</b> easter egg"
          . ( $VARS->{easter_eggs} == 1 ? "" : "s" )
          . " and <b>"
          . ( $VARS->{tokens} || "0" )
          . "</b> token"
          . ( $VARS->{tokens} == 1 ? "" : "s" ) . ".</p>";
    }
    else {
        $str .=
            "<p>You currently have <b>"
          . $$USER{GP}
          . " GP</b>, <b>"
          . ( $$VARS{easter_eggs} || "0" )
          . "</b> easter egg"
          . ( $$VARS{easter_eggs} == 1 ? "" : "s" )
          . ", and <b>"
          . ( $$VARS{tokens} || "0" )
          . "</b> token"
          . ( $$VARS{tokens} == 1 ? "" : "s" ) . ".</p>";
    }

    htmlcode( 'achievementsByType', 'miscellaneous,' . $$USER{user_id} );

    $$VARS{oldexp} = $$USER{experience};
    $$VARS{oldGP}  = $$USER{GP};

    return $str;
}

sub e2_ticket_center {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<style type='text/css'>
    .staff_only { background: #c0ffee; display: block; }
    .smallcell { width: 100px; }
    .summarycell { width: 50%; }
    .summary { width: 90%; }
    .createticket { width: 90%; }
    </style><!-- / block context sensitive coloring problems -->|;

    ## This section is for ticket creation.  The list will display below the create area.

    my $isGod = $APP->isAdmin($USER);
    my $isCE  = $APP->isEditor($USER);

    ## Don't display conditions
    return "$str<p>You must be logged in to view service tickets.</p>"
      if $APP->isGuest($USER);
    return $str unless ($isGod);    ## temp until system is ready

    ## Define variables
    my (@TKTTYPES) =
      $DB->getNodeWhere( { type_nodetype => getId( getType('ticket_type') ) } );
    my @TKTTYPE;
    foreach (@TKTTYPES) { push @TKTTYPE, $_; }
    my $settickettype = "\n\t\t<select id='tickettype' name='tickettype'>";
    foreach (@TKTTYPE) {
        $settickettype .=
            "\n\t\t\t<option value='"
          . $_->{node_id} . "'>"
          . $_->{title}
          . "</option>";
    }
    $settickettype .= "\n\t\t</select>";

    my $header = "<h3>Create a New Ticket</h3>\n"
      . '<form method="post" action="/index.pl" enctype="multipart/form-data">';
    my $ticketsummary =
      '<input type="text" class="summary" name="summary" maxlength="250">';
    my $ticketdescription =
        "<textarea id='description' name='description' "
      . htmlcode( 'customtextarea', '1' )
      . " wrap='virtual' >"
      . "</textarea>";

    my $createdby =
      "<input type='hidden' name='createdby' value='$$USER{node_id}'>";
    my $footer = "\n"
      . $createdby . "\n"
      . '<input type="hidden" name="op" value="new">' . "\n"
      . '<input type=hidden name="type" value="1949335">' . "\n"
      . $query->submit( "createit", "Enter Ticket" ) . "\n"
      . $query->end_form;

    ## Admin Only checkbox only visible to admins, C_Es
    my $adminchecktitle = '';
    my $admincheck      = '';
    if ( $isGod || $isCE ) {
        $adminchecktitle = '<span class="staff_only">Admin<br>Only?</span>';
        $admincheck =
'<span class="staff_only"><input type="checkbox" name="adminonly" value="1">';
    }
    else {
        $adminchecktitle = q|&nbsp;|;
        $admincheck      = q|&nbsp;|;
    }

    ## start multi-line string to define the table layout
    my $createtable = '
    <table border="0" class="createticket" cellpadding="0" cellspacing="0">
    <tr>
    <th class="smallcell">' . $adminchecktitle . '</td>
    <th>Type</td>
    <th class="summarycell">Short Summary</td>
    <tr>
    <td align="center">' . $admincheck . '</td>
    <td align="center">' . $settickettype . '</td>
    <td align="center">' . $ticketsummary . '</td>
    <tr>
    <th colspan="3">Detailed Description <small>(please be specific)</small></th>
    <tr><td colspan="3">' . $ticketdescription . '</td></table>';

    ## end multi-line string to create the table layout

    $str .= $header . $createtable . $footer;

    $str .=
qq|<hr><h3>Ticket Listing</h3><!-- / block context sensitive coloring problems -->|;

    my $testnode = undef;
    my $output   = "";
    my $csr      = $DB->{dbh}->prepare( "
    SELECT *
    FROM node
    WHERE type_nodetype = 1949335 LIMIT 100" );
    $csr->execute();

    while ( my $s = $csr->fetchrow_hashref ) {
        $output .= "<p>";
        foreach my $keys ( sort( keys( %{$s} ) ) ) {
            $output .= $keys . ":" . $s->{$keys} . " ";
        }

        $output .= "summary: " . $s->{'summary'} . "</p>";
    }

    return $str . $output;
}

sub edit_weblog_menu {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    return if $APP->isGuest($USER);

    my $str = htmlcode('openform') . '<fieldset><legend>Display:</legend>';

    if ( $query->param('nameifyweblogs') ) {
        $$VARS{nameifyweblogs} = 1;
    }
    else {
        delete $$VARS{nameifyweblogs} if $query->param('submit');
    }

    $str .= $query->checkbox(
        -name    => 'nameifyweblogs',
        -checked => ( $$VARS{nameifyweblogs} ? 'checked' : '' ),
        -value   => 1,
        -label   => 'Use dynamic names (-ify!)'
      )
      . '
    </fieldset>';

    my $wls = {};
    $wls = getVars( getNode( 'webloggables', 'setting' ) )
      if $$VARS{nameifyweblogs};
    my $somethinghidden = 0;

    $str .= "\n<fieldset><legend>Show items:</legend>\n";
    foreach ( split ',', $$VARS{can_weblog} ) {
        if ( $query->param( 'show_' . $_ ) ) {
            delete $$VARS{ 'hide_weblog_' . $_ };
        }
        elsif ( $query->param('submit') ) {
            $$VARS{ 'hide_weblog_' . $_ } = $$VARS{'hidden_weblog'} =
              $somethinghidden = 1;
        }

        my $groupTitle = "News";
        if ( $$VARS{nameifyweblogs} ) {
            $groupTitle = $$wls{$_};
        }
        else {
            $groupTitle = getNodeById( $_, "light" )->{title}
              unless $_ == 165580;
        }

        $str .= $query->checkbox(
            -name    => 'show_' . $_,
            -checked => ( $$VARS{ 'hide_weblog_' . $_ } ? '' : 'checked' ),
            -value   => 1,
            -label   => $groupTitle
        ) . "<br>\n";
    }

    delete $$VARS{'hidden_weblog'} unless $somethinghidden;

    return
        $str
      . '</fieldset><input type="submit" name="submit" value="'
      . ( $$VARS{nameifyweblogs} ? 'Changeify!' : 'Submit' )
      . '"></form>';

}

sub news_archives {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $isGod        = $APP->isAdmin($USER);
    my $isEd         = $APP->isEditor($USER);
    my $webloggables = getVars( getNode( "webloggables", "setting" ) );
    my $view_weblog  = $query->param('view_weblog') // '';
    my $skipped      = 0;
    my @labels       = ();

    foreach my $node_id (
        sort { lc( $$webloggables{$a} ) cmp lc( $$webloggables{$b} ) }
        keys(%$webloggables)
      )
    {
        my $title   = $$webloggables{$node_id};
        my $wclause = "weblog_id='$node_id' AND removedby_user=''";
        my $count   = $DB->sqlSelect( 'count(*)', 'weblog', "$wclause" );
        my $link = linkNode( $NODE, $title, { 'view_weblog' => "$node_id" } );
        $link = "<b>$link</b>" if defined($view_weblog) && $view_weblog =~ /^\d+$/ && $node_id == $view_weblog;
        push @labels,
            "$link<br /><font size='1'>($count node"
          . ( $count == 1 ? '' : 's' )
          . ')</font>';
    }

    my $text = "";
    if ( !$view_weblog ) {
        $text = "<table border='1' width='100%' cellpadding='3'>";

        my $labelcount = 0;
        foreach (@labels) {
            if ( $labelcount % 8 == 0 ) { $text .= "<tr>"; }
            $text .= "<td align='center'>" . $_ . "</td>";
            if ( $labelcount % 8 == 7 ) { $text .= "</tr>"; }
            $labelcount++;
        }

        $text .= "</table>";

        return $text;
    }

    return $text
      if ( ( $view_weblog == 114 ) || ( $view_weblog == 923653 ) )
      && ( !($isEd) );

    if ( $isGod && ( my $unlink_node = $query->param('unlink_node') ) ) {
        $unlink_node =~ s/\D//g;
        $DB->sqlUpdate(
            'weblog',
            { 'removedby_user' => $$USER{user_id} },
            "weblog_id='$view_weblog' AND to_node='$unlink_node'"
        );
    }

    $text .=
        '<p align="center"><font size="3">Viewing news items for <b>'
      . linkNode( getNode($view_weblog) )
      . '</b></font> - <small>[News Archives|back to archive menu]</small></p>';

    $text .= q|<table border='1' width='100%' cellpadding='3'>|
      . q|<tr><th>Node</th><th>Time</th><th>Linker</th>|
      . ( $isGod ? '<th>Unlink?</th>' : '' ) . '</tr>';
    my $wclause = "weblog_id='$view_weblog' AND removedby_user=''";
    my $csr =
      $DB->sqlSelectMany( '*', 'weblog', $wclause, 'order by tstamp desc' );
    while ( my $ref = $csr->fetchrow_hashref() ) {
        my $N = getNode( $$ref{to_node} );
        $skipped++ unless $N;
        next       unless $N;
        my $link   = linkNode($N);
        my $time   = htmlcode( 'parsetimestamp', "$$ref{tstamp},128" );
        my $linker = getNode( $$ref{linkedby_user} );
        $linker = $linker ? linkNode($linker) : '<i>unknown</i>';
        my $unlink = linkNode( $NODE, 'unlink?',
            { 'unlink_node' => $$ref{to_node}, 'view_weblog' => $view_weblog }
        );
        $text .=
          "<tr><td>$link</td><td><small>$time</small></td><td>$linker</td>"
          . ( $isGod ? "<td>$unlink</td>" : '' ) . '</tr>';
    }
    $text .= "</table>";

    $text .=
        "<br /><table border='1' width='100%' cellpadding='3'>"
      . "<tr><th>$skipped deleted node"
      . ( $skipped == 1 ? ' was' : 's were' )
      . ' skipped</th></tr></table>'
      if $skipped;

    return $text;
}


sub topic_archive {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<table>|;
    $str .= "<th>$_</th>\n" foreach ( 'Time', 'Details' );

    my $sectype =
      getId( getNode( 'E2 Gift Shop', 'superdoc' ) ); # So probably 1872678 then
    my $startat = $query->param('startat') || '';
    $startat =~ s/[^0-9]//g;
    $startat ||= 0;

    my $csr = $DB->sqlSelectMany( '*', 'seclog',
"seclog_node=$sectype AND seclog_time>'2011-01-22 00:00:00' order by seclog_time DESC limit $startat,50"
    );

    while ( my $row = $csr->fetchrow_hashref ) {
        $str .= q|<tr>|;
        $str .= qq|<td><small>$row->{seclog_time}</small></td>|;
        $str .= q|<td>| . $row->{seclog_details} . q|</td>|;
        $str .= q|</tr>|;
    }

    $str .= q|</table>|;

    ### Generate the pager
    my $cnt = $DB->sqlSelect( 'count(*)', 'seclog',
        "seclog_node=$sectype AND seclog_time>'2011-01-22 00:00:00'" );
    my $firststr = "$startat-" . ( $startat + 50 );
    $str .= q|<p align="center"><table width="70%"><tr>|;
    $str .= q|<td width="50%" align="center">|;
    if ( ( $startat - 50 ) >= 0 ) {
        $str .= linkNode( $NODE, $firststr,
            { 'startat' => ( $startat - 50 ), 'sectype' => $sectype } );
    }
    else {
        $str .= $firststr;
    }
    $str .= q|</td>|;
    $str .= q|<td width="50%" align="center">|;
    my $secondstr = ( $startat + 50 ) . '-'
      . ( ( $startat + 100 < $cnt ) ? ( $startat + 100 ) : ($cnt) );

    if ( ( $startat + 50 ) <= ($cnt) ) {
        $str .= linkNode( $NODE, $secondstr,
            { 'startat' => ( $startat + 50 ), 'sectype' => $sectype } );
    }
    else {
        $str .= q|(end of list)|;
    }

    $str .= q|</tr></table>|;
    return $str;

}

# writeups_by_type - Migrated to React
# See: Everything::Page::writeups_by_type
# React component: WriteupsByType.js


# simple_usergroup_editor - Migrated to React
# See: Everything::Page::simple_usergroup_editor
# React component: SimpleUsergroupEditor.js

# everything_s_biggest_stars - REMOVED (migrated to Everything::Page::everything_s_richest_noders + React)
# word_messer_upper - REMOVED (migrated to Everything::Page::word_messer_upper + React)
# log_archive - REMOVED (migrated to Everything::Page::log_archive + React)
# show_user_vars - Migrated to React
# See: Everything::Page::show_user_vars
# React component: ShowUserVars.js

sub sanctify_user
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    #Note that if you adjust these settings, you should also adjust them in the "Epicenter" nodelet and the "sanctify" opcode --mauler
    my $minLevel = 11;
    my $Sanctificity = 10;

    return "<p>Sorry, this tool can only be used by people who have [User Settings|opted in] to the GP system.</p>" if ($VARS->{GPoptout});
    return "<p>Who do you think you are? The Pope or something?</p><p>Sorry, but you will have to come back when you reach Level $minLevel.</p>" unless $APP->getLevel($USER)>= $minLevel or $APP->isEditor($USER);
    return "<p>Sorry, but you don't have at least $Sanctificity GP to give away. Please come back when you have more GP.</p>" if $USER->{GP} < $Sanctificity;

    my $str = "<p>This tool lets you give <b>$Sanctificity GP</b> at a time to any user of your choice. The GP is transferred from your own account to theirs. Please use it for the good of Everything2!</p>";

    if ($query->param('give_GP'))
    {
        my $recipient = $query->param('give_to');
        my $user = getNode($recipient, 'user');
        return "<p>The user '$recipient' doesn't exist!</p>" unless $user;
        return q{<p>It is not possible to sanctify yourself!</p><p>Would you like to [Sanctify user|try again on someone else]?</p>} if ($USER->{title} eq $recipient && !$APP->isAdmin($USER));
        $$user{sanctity} += 1;
        updateNode($user, -1);

        $APP->adjustGP($user, $Sanctificity);
        $APP->adjustGP($USER, -$Sanctificity);

        $APP->securityLog($NODE, $USER, "$USER->{title} sanctified $user->{title} with $Sanctificity GP.");

        my $from =  ($query->param('anon') eq 'sssh') ? '!' : (' by [' . $USER->{title} . ']!');
        htmlcode('sendPrivateMessage',{
            'author_id' => getId(getNode('Cool Man Eddie', 'user')),
            'recipient_id' => $user->{user_id},
            'message' => "Whoa! You’ve been [Sanctify|sanctified]$from" });
        $str = q|<p>User [| . $user->{title} .q|] has been given 10 GP. |;
        return $str . q|</p>You have <b>| . $USER->{GP} . q{GP</b> left. Would you like to [Sanctify user|sanctify someone else]?</p><p>Or, return to the [E2 Gift Shop].</p>};
    }

    $str.=$query->start_form();
    $str.=$query->hidden('node_id', $$NODE{node_id});
    $str.= q|</p><p>Which noder has earned your favor? |.$query->textfield('give_to');
    $str.= $query->checkbox(-name=>'anon',
        -value=>'sssh',
        -label=>'Remain anonymous') . '</p>';
    $str.=$query->submit('give_GP','Sanctify!');
    $str.=$query->end_form();

    $str.=q|<p>Or, return to the [E2 Gift Shop].</p>|;

    $VARS->{oldexp} = $USER->{experience};
    $VARS->{oldGP} = $USER->{GP};

    return $str;
}

sub node_backup
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    return q|<p>If you logged in, you'd be able to create a backup of your writeups here.</p>| if $APP->isGuest($USER);

    # Node backup requires S3 and is not available in development environment
    if ($Everything::CONF->environment eq 'development') {
        return q|<p>Node backup is not available in the development environment.</p><p>This feature requires AWS S3 access for storing backups, which is only configured in production.</p>|;
    }

    my $zipbuffer = undef;
    my $zip = IO::Compress::Zip->new(\$zipbuffer);
    my $s3 = Everything::S3->new('nodebackup');

    my $str = '';
    $str .= q|<p>Welcome to the node backup utility. Here you can download all of your writeups and/or drafts in a handy zipfile.</p>|;

    $str .= htmlcode('openform','backup')
        .'<label>Back up:'
        .$query->popup_menu(
            -name => 'dowhat'
            , values => ['writeups and drafts', 'writeups', 'drafts'])
        .'</label><br><br>'
        .$query->radio_group(
            -name=>'e2parse',
            values=>['1','2','3'],
            labels=>{
                '1' => '... as you typed them',
                '2' => '... as E2 renders them',
                '3' => '... in both formats'},
            linebreak => 'true')
        .'<br>';

    if($APP->isAdmin($USER))
    {
        $str .= q|For noder: |.$query->textfield(-name => 'for_noder').q| <em>(admin only)</em><br />|;
    }
    $str .= htmlcode('closeform', 'Create backup');
    return $str unless $query->param('sexisgood');

    my $e2parse = $query->param('e2parse');
    my $targetNoder = undef;

    if ($query->param('for_noder') && $APP->isAdmin($USER)) {
        # hard-of-access option to test on other other users' stuff:
        # draft security hole comparable to [SQL prompt]
        my $targetNoderName = $query->param('for_noder');
        $targetNoder = getNode($targetNoderName, 'user');
    }

    $targetNoder ||= $USER;
    my $uid = $targetNoder->{user_id};

    my @types;
    @types = ($1, $2) if $query -> param('dowhat') =~ /(writeup)?.*?(draft)?s$/;
    @types = map { $_ ? 'type_nodetype='.getType($_)->{node_id} : () } @types;
    my $where = join ' OR ', @types;

    my $TAGNODE = getNode('approved html tags', 'setting');
    my $TAGS=getVars($TAGNODE);

    my @wus;
    my $csr = $DB->sqlSelectMany(
        'title, doctext, type_nodetype, node_id'
        , 'document JOIN node ON document_id=node_id'
        , "author_user=$uid AND ($where)");

    while (my $wu_row = $csr->fetchrow_hashref){
        push @wus, $wu_row if $e2parse & 1;
        push @wus, {
            title => $wu_row->{title},
            type_nodetype => $wu_row->{type_nodetype},
            suffix => 'html',
            doctext => "<base href=\"https://everything2.com\">\n".
                $APP->breakTags(parseLinks($APP->screenTable($APP->htmlScreen($wu_row -> {doctext},$TAGS))))
        } if $e2parse & 2;
    }

    unless (@wus){
        return  q|<p>No |.$query->param('dowhat').q| found.</p>|;
    }

    my $draftType = getId(getType('draft'));
    my %usedtitles = ();

    foreach my $wu (@wus) {
        my $wu_title = $wu->{title};
        my $suffix = $wu->{suffix} || 'txt';

        #Slashes create directories in the zip file, so change them to
        #dashes. Various other characters make various OSes puke, so change them, too.
        $wu_title =~ s,[^[:alnum:]&#; ()],-,g;
        $wu_title .= ' (draft)' if $wu->{type_nodetype} == $draftType;
        my $trytitle = $wu_title;

        my $dupebust = 1;
        $wu_title = $trytitle.' ('.$dupebust++.')' while $usedtitles{"$wu_title.$suffix"};
        $usedtitles{"$wu_title.$suffix"} = 1;

        my $doctext = $wu->{doctext};
        utf8::encode($doctext);
        my $wusuffix = $wu->{suffix};
        utf8::encode($wusuffix);
        $zip->newStream(Name => ($wusuffix || 'text')."/$wu_title.$suffix");
        $zip->print($doctext);
    }

    my ($day, $month, $year) = (gmtime(time + $VARS->{localTimeOffset} + $VARS->{localTimeDST}*3600))[3 .. 5];
    $month += 1; # month initially 0..11; make it 1..12
    $year += 1900;
    $day = "0$day" if $day < 10;
    $month = "0$month" if $month < 10;

    my $cleanUser = $APP->rewriteCleanEscape($targetNoder->{title});
    my $format = ('text', 'html', 'text-html')[$e2parse-1];

    # make URL hard to guess
    my $obfuscateUrl = int(rand(8999999)) + 1000000;
    my $outputfilename = "$cleanUser.$format.$obfuscateUrl.$year-$month-$day.zip";

    $zip->close();
    $s3->upload_data($outputfilename, $zipbuffer, {content_type => 'application/zip'});

    my $url = "https://s3-us-west-2.amazonaws.com/nodebackup.everything2.com/$outputfilename";

    $str .= "<p> Your backup is ready. You can fetch it <strong><a href=\"$url\">$url</a></strong></p>";
    $str .= "<p>This link is public in the sense that anyone with the URL can download it, and will last for 7 days, in which time it will be automatically deleted. This is the only time you will see this link, so download it now.</p>";

    $str .= '<p>This is not your work and some of it may be private. Please do not read the drafts and remember to delete the backup after checking it is OK.'
        if $uid != $USER->{user_id} and $where =~ /$draftType/;

    return $str;
}

sub usergroup_picks
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $text = '<p>Some of Everything2\'s [usergroup]s keep lists of writeups and documents particularly relevant to the group in question. These are listed below. </p>';
    $text .= '<p>You can also keep tabs on these using the Usergroup Writeups [nodelet settings|nodelet]. Find out more about these and other usergroups at [Usergroup Lineup].</p>';

    my $isGod = $APP->isAdmin($USER);
    my $isEd = $APP->isEditor($USER);

    my $webloggables = getVars(getNode("webloggables", "setting"));
    my $view_weblog = $query->param('view_weblog') || 0;
    my $skipped = 0;
    my @labels;

    foreach my $node_id (sort {
        lc($$webloggables{$a}) cmp lc($$webloggables{$b})
    } keys(%$webloggables)) {
        next if ($node_id==165580||$node_id==923653||$node_id==114);
        my $somenode=getNode($node_id);
        next unless($somenode);
        my $title = $$somenode{title};
        my $wclause = "weblog_id='$node_id' AND removedby_user=''";
        my $count = $DB->sqlSelect('count(*)','weblog',"$wclause");
        my $link = linkNode($NODE,$title,{'view_weblog'=>"$node_id"});
        $link = "<b>$link</b>" if $view_weblog && $node_id == $view_weblog;
        push @labels, "$link<br /><font size='1'>($count node".($count==1?'':'s').')</font>';
    }

    if (!$view_weblog) {
        $text .= "<table border='0' width='100%' cellpadding='3' valign='top'><tr>";
        my $labelcount=0;
        foreach (@labels) {
            if ($labelcount % 10 ==0) {$text.="<td><ul>";}
            $text .= "<li>".$_."</li>";
            if ($labelcount % 10 == 9) {$text.="</ul></td>";}
            $labelcount++;
        }
        $text .= "</ul></td></table>";
        return $text;
    }

    return $text if (($view_weblog == 114)||($view_weblog==923653))&&(!($isEd));

    if($isGod && (my $unlink_node = $query->param('unlink_node'))){
        $unlink_node =~ s/\D//g;
        $DB->sqlUpdate('weblog',{'removedby_user'=>$$USER{user_id}},"weblog_id='$view_weblog' AND to_node='$unlink_node'");
    }

    $text .= '<p align="center"><font size="3">Viewing news items for <b>'.linkNode(getNode($view_weblog)).'</b></font> - <small>[News Archives|back to archive menu]</small></p>';

    $text .= "<table border='1' width='100%' cellpadding='3'><tr><th>Node</th><th>Time</th><th>Linker</th>".($isGod?'<th>Unlink?</th>':'').'</tr>';
    my $wclause = "weblog_id='$view_weblog' AND removedby_user=''";
    my $csr = $DB->sqlSelectMany('*','weblog',$wclause,'order by tstamp desc');
    while(my $ref = $csr->fetchrow_hashref()){
        my $N = getNode($$ref{to_node});
        $skipped++ unless $N;
        next unless $N;
        my $link = linkNode($N);
        my $time = htmlcode('parsetimestamp',"$$ref{tstamp},128");
        my $linker = getNode($$ref{linkedby_user});
        $linker = $linker?linkNode($linker):'<i>unknown</i>';
        my $unlink = linkNode($NODE,'unlink?',{'unlink_node'=>$$ref{to_node},'view_weblog'=>$view_weblog});
        $text .= "<tr><td>$link</td><td><small>$time</small></td><td>$linker</td>".($isGod?"<td>$unlink</td>":'').'</tr>';
    }
    $text .= "</table>";

    $text .= "<br /><table border='1' width='100%' cellpadding='3'><tr><th>$skipped deleted node".($skipped==1?' was':'s were').' skipped</th></tr></table>' if $skipped;

    return $text;
}

# create_node - Migrated to React
# See: Everything::Page::create_node
# React component: CreateNode.js

# everything_s_most_wanted - Migrated to React
# See: Everything::Page::everything_s_most_wanted
# React component: EverythingsMostWanted.js


sub recalculate_xp
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $text = '';

    # Static HTML: CSS
    $text .= '<style type="text/css">
.mytable th, .mytable td
{
border: 1px solid silver;
padding: 3px;
}
</style>

';

    my $targetStr = '';
    my $targetUser = undef;
    my $targetVars = undef;

    if ( $APP->isAdmin($USER) ) {
        $targetStr .= "<label>Target user:"
            . $query->textfield(-name => 'targetUser')
            . "</label><br>"
            ;

        my $targetUsername = $query->param('targetUser');

        if ($targetUsername) {
            $targetUser = getNode($targetUsername, 'user');

            if (!$targetUser) {
                $targetStr .= "<p><em>Could not find user '"
                    . encodeHTML($targetUsername)
                    . "'</em></p>"
                    ;
            }
        }
    }

    my $checkCanRecalc = sub {
        ### Check if user joined before October 29, 2008
        return "This service is only needed by and available to users who joined E2 prior to October 29, 2008.
   Don't worry - all of your XP was earned under the present system.</p>" if ($$USER{node_id} > 1960662);

        return "<p>Our records show that you have already recalculated your XP.
   You are only allowed to recalculate your XP once.</p>" if ($$VARS{hasRecalculated} == 1);

        return '';
    };

    my $noRecalcStr = &$checkCanRecalc();

    # Do these checks for normal users.  Bypass them if a god is recalculating someone else
    if (!$targetUser) {
        if ($noRecalcStr ne '') {
            if ($targetStr) {
                $noRecalcStr .= ''
                    . $query->start_form()
                    . $targetStr
                    . $query->hidden('node_id', $$NODE{node_id})
                    . $query->submit('recalculate_XP', 'Recalculate!')
                    . $query->end_form()
                    ;
            }

            $text .= $noRecalcStr;
            return $text;
        }

        $targetVars = $VARS;
        $targetUser = $USER;

    } else {
        $targetVars = getVars($targetUser);
    }

    my $uid = getId($targetUser);

    ##################################################
    # set variables for each system
    #
    my $wuBonus = 5;
    my $coolBonus = 20;

    #####################################################
    my $rows = undef;
    my $row = undef;
    my $queryText = '';
    my $count = undef;

    my $writeupCount = 0;
    my $heavenTotalReputation = 0;
    my $coolCount = 0;
    my $xp = 0;
    my $upvotes = 0;
    my $NodeHeavenCoolCount = 0;

    #
    # Experience
    #
    $queryText = "SELECT experience FROM user WHERE user_id=$uid";
    $rows = $DB->{dbh}->prepare($queryText);
    $rows->execute()
        or do { $text .= $rows->errstr; return $text; };
    $xp = $rows->fetchrow_array();

    #
    # Writeup Count
    #
    $queryText = "SELECT COUNT(*) FROM node,writeup WHERE node.node_id=writeup.writeup_id AND node.author_user=$uid";
    $rows = $DB->{dbh}->prepare($queryText);
    $rows->execute()
        or do { $text .= $rows->errstr; return $text; };
    $writeupCount = $rows->fetchrow_array();

    #
    # Total Upvotes
    #
    my $queryText2 = '';
    my $rows2 = undef;
    my $row2 = undef;
    $queryText = "SELECT node_id FROM node
    JOIN draft ON node_id=draft_id
    WHERE node.author_user=$uid";
    $rows = $DB->{dbh}->prepare($queryText);
    $rows->execute()
        or do { $text .= $rows->errstr; return $text; };
    $queryText2 = "SELECT COUNT(vote_id) FROM vote WHERE weight>0 AND vote_id=?";
    $rows2 = $DB->{dbh}->prepare($queryText2);
    while($row = $rows->fetchrow_arrayref)
    {
        $rows2->execute($$row[0]);
        $upvotes += $rows2->fetchrow_array();
    }

    #
    # Heaven Total Reputation
    #
    $queryText = "SELECT SUM(heaven.reputation) AS totalReputation FROM heaven WHERE heaven.type_nodetype=117 AND heaven.author_user=$uid";
    $rows = $DB->{dbh}->prepare($queryText);
    $rows->execute()
        or do { $text .= $rows->errstr; return $text; };
    while($row = $rows->fetchrow_arrayref)
    {
        $heavenTotalReputation = $$row[0];
    }

    #
    # Cool Count
    #
    $queryText = "SELECT COUNT(*) FROM node
    JOIN coolwriteups ON node_id=coolwriteups_id
    WHERE node.author_user=$uid";
    $rows = $DB->{dbh}->prepare($queryText);
    $rows->execute()
        or do { $text .= $rows->errstr; return $text; };
    $coolCount = $rows->fetchrow_array();

    #
    # Node Heaven Cool Count
    #
    $queryText = 'SELECT COUNT(*) from coolwriteups,heaven where coolwriteups_id=node_id AND author_user='.$$targetUser{node_id};
    $rows = $DB->{dbh}->prepare($queryText)
        or do { $text .= $rows->errstr; return $text; };
    $rows->execute()
        or do { $text .= $rows->errstr; return $text; };
    $NodeHeavenCoolCount = $rows->fetchrow_array();

    if ($heavenTotalReputation < 0) {
        $heavenTotalReputation = 0;
    }

    #
    # cached upvotes and cools from deleted drafts/heaven
    #
    my ($upcache, $coolcache) = $DB -> sqlSelect('upvotes, cools', 'xpHistoryCache',
        "xpHistoryCache_id=$uid");

    my $newXP = (($writeupCount * $wuBonus) + ($upvotes + $upcache + $heavenTotalReputation) +
        (($coolCount + $coolcache + $NodeHeavenCoolCount) * $coolBonus));

    my $str = '';

    $str .= '<p>This superdoc converts your current XP total to the XP total you would have
   if the new system had been in place since the start of your time as a noder.
   Any excess XP will be converted into GP.</p><p>Conversion is permanent; once
   you recalculate, you can not go back. Each user can only recalculate their
   XP one time.</p>
';

    $str .= "&nbsp; <b>User: ".$$targetUser{title}."</b>";
    $str .= '<table class="mytable">
   <tr class="oddrow">
   <td>Current XP:</td>
   <td style="text-align:right">'.$xp.'</td>
   </tr>
   <tr class="evenrow">
   <td>Writeups:</td>
   <td style="text-align:right">'.$writeupCount.'</td>
   <tr class="oddrow">
   <td>Upvotes Received:</td>
   <td style="text-align:right">'.($upvotes + $upcache + $heavenTotalReputation).'</td>
   </tr>
   <tr class="evenrow">
   <td>C!s Received:</td>
   <td style="text-align:right">'.($coolCount + $coolcache + $NodeHeavenCoolCount).'</td>
   </tr>
   <tr class="oddrow">
   <td><b>Recalculated XP:</b></td>

   <td style="text-align:right"><b>'.$newXP.'</b></td>
   </tr>
   </table>';

    if ($xp > $newXP) {
        $str .= "<p><b>Recalculation Bonus!</b>&nbsp; Your current XP is greater than your recalculated XP, so if you choose to recalculate you will be awarded a one-time recalculation bonus of  <b>".($xp - $newXP)." GP!</b></p>";
    }

    $str .= "<p></p>";

    $str .= $query->start_form();
    $str .= $targetStr;
    $str .= $query->hidden('node_id', $$NODE{node_id});
    $str .= $query->checkbox(-name=>'confirm',
-value=>'wakaru',
-label=>'I understand that recalculating my stats is permanent, and that I can never go back once I have done so.') . '</p>';
    $str .= $query->submit('recalculate_XP','Recalculate!');
    $str .= $query->end_form();

    if ($query->param('recalculate_XP')) {
        my $warnstr = '';
        if ($query->param('confirm') eq 'wakaru') {
            $APP->securityLog($NODE, $USER, "$$USER{title} recalculated $$targetUser{title}'s XP");
            $APP->adjustExp($targetUser, (-$xp));
            $APP->adjustExp($targetUser, $newXP);
            $$targetVars{hasRecalculated} = 1;
            $DB -> sqlDelete('xpHistoryCache', "xpHistoryCache_id=$uid");
            setVars($targetUser, $targetVars);
            $str = "<p>Recalculation complete! You now have <b>".$newXP." XP</b>";
            if ($xp > $newXP) {
                $$targetUser{GP} += ($xp-$newXP);
                updateNode($targetUser, -1);
                $$targetVars{oldexp} = $$targetUser{experience};
                $str .= " and <b>".$$targetUser{GP}." GP</b>.";
            } else {
                $str .= ".";
            }
        } else {
            $warnstr = "<p><b>!! Note !! You must check the box to acknowledge you understand before your XP can be recalculated.</b></p>";
        }
        $text .= $warnstr . $str;
        return $text;
    } else {
        $text .= $str;
        return $text;
    }
}

sub the_nodeshell_hopper
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    my $str = 'A smarter nodeshell deletion implementation
    <br><br>Copy and paste off of the nodeshells marked for destructions lists.
    DO NOT separate them by pipes anymore.
    <b>This is slow to execute</b>, but is worth it.<br><br>
    <ul>This does the following things:
        <li>Checks to see if it\'s an E2node
        <li>Checks to see whether it is empty
        <li>Checks for firmlinks
        <li>Deletes the nodeshell
    </ul>';

    my @nodeshellgroup = ();
    my $nodeshell      = undef;

    $str .= '<ul>';

    if ( defined $query->param('nodeshells') ) {
        my $shells = $query->param('nodeshells');

        $shells =~ s/\s+\n/\n/g;
        $shells =~ s/\r/\n/g;
        $shells =~ s/\[//g;
        $shells =~ s/\]//g;

        @nodeshellgroup = split( '\n', $shells );

        # jay: this is wharfcode.
        my %exempt = (
            9651    => 1,
            631430  => 1,
            3146    => 1,
            9147    => 1,
            406468  => 1,
            331     => 1,
            614583  => 1,
            1019934 => 1,
            893653  => 1,
            448206  => 1,
            470183  => 1,
            488505  => 1,
            898636  => 1,
            650043  => 1
        );

        foreach my $nshell (@nodeshellgroup) {
            $nodeshell = getNode( $nshell, 'e2node' );

            if ( defined $nodeshell ) {
                $str .= '<li>' . $$nodeshell{title} . ' - exists';

                unless (
                    $DB->sqlSelect(
                        "to_node", "links",
                        "linktype=1150375
                AND from_node=$$nodeshell{node_id}"
                    )
                    )
                {

                    if(defined($nodeshell->{group}) and scalar(@{$nodeshell->{group}}) >0 ) {
                        $str .= ' - not empty, can\'t delete.';
                    } else {
                        $str .= ' - empty - nuking';
                        $DB->nukeNode( $nodeshell, $USER );
                        $str .= ' - <font color="red"><b>DELETED</b></font>';
                    }

                } else {
                    $str .= ' - Part of a firmlink, can\'t delete';
                }    #firmlink check

            } else {
                $str .=
                    '<li>"' . $nshell . '" doesn\'t exist as an e2node.';
            }    #if(defined $nodeshell)

        }
    }

    $str .= '</ul>';

    $str .= '<form method="post">
    <input type="hidden" name="node_id" value="1140925">
    <textarea name="nodeshells" rows="20" cols="60" ></textarea>
    <br><br><input type="submit" value="Whack em all!">
    </form>
    <br><br>';

    $text .= $str;
    return $text;
}

sub costume_remover
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    my @params = $query->param;
    my $str    = '';

    my @users     = ();
    my @thenodes  = ();
    foreach (@params) {
        if (/^undressUser(\d+)$/) {
            $users[$1] = $query->param($_);
        }
    }

    for ( my $count = 0 ; $count < @users ; $count++ ) {
        next unless $users[$count];

        my ($U) = getNode( $users[$count], 'user' );
        if ( not $U ) {
            $str .= "couldn't find user $users[$count]<br />";
            next;
        }

        # Send an automated notification.
        my $failMessage = htmlcode(
            'sendPrivateMessage',
            {
                'recipient_id' => getId($U),
                'message'      => 'Hey, your costume has been removed because it was deemed abusive. Please choose your costume more carefully next time, or you will lose costume-wearing privileges.',
                'author' => 'Klaproth',
            }
        );

        $str .= "User $$U{title} was stripped of their costume.";

        my $v = getVars($U);
        delete $$v{costume};
        setVars( $U, $v );
        $str .= q|<br />|;

    }
    $text .= $str;

    # Build the table rows for inputting user names
    my $count = 5;
    $str =
        "<p>This tool deletes the costume variable for selected users. Use it to remove abusively or innapropriately named costumes.</p><p>";
    $str .= htmlcode('openform');
    $str .= '<table border="1">';

    $str .= "\t<tr><th>Undress these users</th></tr> ";

    for ( my $i = 0 ; $i < $count ; $i++ ) {
        $query->param( "undressUser$i", '' );
        $str .= "\n\t<tr><td>";
        $str .= $query->textfield( "undressUser$i", '', 40, 80 );
        $str .= "</td>";
    }

    $str .= '</table>';
    $str .= htmlcode('closeform');
    $str .= "</p>";

    $text .= $str;
    return $text;
}

# mark_all_discussions_as_read - MIGRATED TO Everything::Page::mark_all_discussions_as_read (December 2025)

# guest_front_page - MIGRATED TO Everything::Page::guest_front_page (December 2025)
# Template: templates/pages/guest_front_page.mc
# React component: GuestFrontPage.js

# The Catwalk - Migrated to React
# See: Everything::Page::the_catwalk
# React component: TheCatwalk.js

# usergroup_message_archive - Migrated to React
# See: Everything::Page::usergroup_message_archive
# React component: UsergroupMessageArchive.js

# welcome_to_everything - MIGRATED TO Everything::Page::welcome_to_everything (December 2025)
# React component: WelcomeToEverything.js

sub short_url_lookup
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    return unless $query;

    my $shortString = $query->param('short_string') // '';
    my $redirectNode = htmlcode('decode short string', $shortString);

    if (!defined $redirectNode) {

        my $errorString =
            $shortString eq '' ?
                "There doesn't look to be a short URL to look up."
                : "The string <strong>$shortString</strong> doesn't appear to go anywhere."
            ;

        return
            '<h3>Short URL Error</h3>'
            . "<p>"
            . $errorString
            . "  Why not "
            . htmlcode('randomnode', 'try a random node')
            . " instead?"
            . "</p>"
            ;

    }

    my $urlParams = { };
    my $bNoQuoteUrl = 1;

    my $redirect_url = urlGen($urlParams, $bNoQuoteUrl, $redirectNode);
    return q|<script>window.location.href="|.'http://' . $ENV{HTTP_HOST} . $redirect_url.q|";</script>|;
}

sub reset_password
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $validForMinutes = 20;

    my ($prompt, $user) = ('', '');
    my $pass = $query -> param('duck');
    my $who = $query -> param('who');

    if (!$query -> param('sockItToMe')){
        $prompt = 'Forgotten your password? Fill in your user name or email address here and choose
            a new password, and we will send you an email containing a link to reset it';

    }elsif($pass ne $query -> param('swan')){
        $prompt = "Passwords don't match";

    }elsif(!$pass || !$who){
        $prompt = 'Fill in all fields';

    }else{
        $user = getNode($who, 'user');
        ($user) = $DB -> getNodeWhere({email => $who}, 'user')
            unless $user || $who !~ /^(\S+\@\S+\.\S+)$/;

        $prompt = 'Unknown user or email' unless $user;
    }

    $query -> delete('duck', 'swan');

    return htmlcode('openform')
        .$query -> fieldset({style => 'width: 35em; max-width: 100%; margin: 3em auto 0'},
            $query -> legend('Choose new password')
            .$query -> p($prompt.':')
            .$query -> p({style => 'text-align: right'},
                $query -> label('Username or email address:'
                    .$query -> textfield('who', '', 30, 240))
                .'<br>'
                .$query -> label('New password:'
                    .$query -> password_field('duck', '', 30, 240))
                .'<br>'
                .$query -> label('Repeat new password:'
                    .$query -> password_field('swan', '', 30, 240))
                .'<br>'
                .$query -> submit('sockItToMe', 'Submit')
            )
        )
    .'</form>' if $prompt;

    $APP -> updatePassword($user, $user -> {passwd}) unless $user -> {salt};

    my ($action, $expiry, $mail, $blurb);

    if ($user -> {lasttime}){
        $action = 'reset';
        $expiry = time() + $validForMinutes * 60;
        $mail = 'Everything2 password reset';
        $blurb = 'Your password reset link is on its way.';
    }else{
        $action = 'activate';
        ($mail, $expiry) = split /\|/, $user -> {passwd};
        $mail = 'Welcome to Everything2';
        $blurb = 'You have been sent a new account activation link.';
    }

    my $params = $APP -> getTokenLinkParameters($user, $pass, $action, $expiry);
    my $link = urlGen($params, 'no quotes', getNode('Confirm password', 'superdoc'));

    my %mail = %{getNode($mail , 'mail')};

    my $name = $user -> {realname} || $user -> {title};
    $mail{doctext} =~ s/«name»/$name/;
    $mail{doctext} =~ s/«link»/$link/g;
    $mail{doctext} =~ s/«servername»/$ENV{SERVER_NAME}/g;

    $APP -> node2mail($user -> {email}, \%mail, 1);

    $APP->securityLog($NODE, $USER, "$action link requested for [$$user{title}\[user]] ($$user{email})");

    return $query -> p($blurb);
}

sub the_costume_shop
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $isHalloween = htmlcode('isSpecialDate','halloween');
    #my $isHalloween = 1;
    my $userGP = $$USER{GP};
    my $costume;
    my $costumeCost = 30;


    if (!$isHalloween) {
    return "<br><br>Sorry, shop's closed. Check back on All Hallows' Eve...<br><br>";
    }

    my $str ='';

    #return "Closed for repair. You know those bricks that you've been getting at the Wheel of Surprise? Someone just threw one of them through the window. We will open again as soon as possible." unless $APP->isAdmin($USER);

    $costumeCost = 0 if $APP->isAdmin($USER);

    if ($userGP < $costumeCost) {
    if (exists($$VARS{costume})) {
    return "<br><br>Alright, you've got your costume. Wanna change it? Bring me back some cold, hard [GP|cash money]!<br><br>";
    }
    return "<br><br>Sorry - a costume don't come free. Go [GP|start a lemonade stand] or something.<br><br>";
    }

    $str = "<br><br>Well, I see you've scrounged up some cash. So I tell you what. You give me 30 [GP] and I'll give you a [chatterbox name change|costume]. Whaddya say?<br><br>";

    if ($query->param("dressup")) {

       $costume = $query->param("costume");
       $costume =~ tr/[]<>&//d;
       my $usercheck = getNode($costume, getType('user'));

       unless ($usercheck) {

          $$VARS{costume} = $costume;
          $$VARS{treats} = 0;
          $APP->adjustGP($USER, -$costumeCost);
          return "Alright, you've got your costume. Wanna change it? Bring me back some more money!";
       } else {
          $str = "<p><b>That costume is also a username! Please try another option.</b></p>";
       }
    }

    $str.=htmlcode('openform');
    $str.=$query->textfield(-name => 'costume');
    $str.=$query->submit('dressup','Dress Me Up');
    $str.=$query->end_form;

    $str .= "<br>";

    if ($APP->isAdmin($USER)) {
        $str .= "<p>Note that since you are an administrator you can also remove abusive costumes at the [Costume Remover].</p>";
    }

    return $str;
}

sub dr__nate_s_secret_lab {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "It...  it...  it...  it...\n<p>\n";

    my $nid = $query->param("olde2nodeid");
    return $str . "huh?" unless $nid;

    # Check if node already exists - can't resurrect a living node
    my $existing = $DB->getNodeById($nid);
    return $str . "That node (id: $nid) is already alive! No resurrection needed." if $existing;

    my $burialground = $query->param("heaven") ? "heaven" : "tomb";

    # Use the new resurrectNode method in NodeBase
    my $N = $DB->resurrectNode($nid, $burialground);
    return $str . "ACK! Resurrection failed!" unless $N;

    # Insert it into the nodegroup - added by ascorbic
    my $nt = $$N{title};
    $nt =~ s/ \(\w+\)$//;
    my $e2N = getNode($nt, 'e2node');
    if($e2N) {
        insertIntoNodegroup($e2N, $USER, $N);
        updateNode($e2N, -1);
    }

    $APP->securityLog($NODE, $USER, "$$N{title} (id: $$N{node_id}) was raised from its $burialground");
    $DB->{cache}->incrementGlobalVersion($N);

    return $str . "Inserted $nid<br><br> as ".linkNode($N) . '<br>';
}

sub new_user_images {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my @params = $query->param;

    foreach (@params) {
        if (/approvepic_(\d+)$/) {
            my $num = int($1);
            $DB->getDatabaseHandle()->do("delete from newuserimage where newuserimage_id=$num");
        }
        if (/deletepic_(\d+)$/) {
            my $num = int($1);
            my $U = getNodeById($num);
            $U->{imgsrc} = "";
            updateNode($U, -1);
            $DB->getDatabaseHandle()->do("delete from newuserimage where newuserimage_id=$num");
        }
    }

    my $str = "New user images:\n";
    $str .= htmlcode('openform');

    my $csr = $DB->sqlSelectMany("*", 'newuserimage', '1 = 1', 'order by tstamp desc LIMIT 10');

    while (my $P = $csr->fetchrow_hashref()) {
        my $U = getNodeById($P->{newuserimage_id});
        $str .= qq|<img src="https://s3-us-west-2.amazonaws.com/hnimagew.everything2.com$U->{imgsrc}" />|;
        $str .= "<br>posted by " . linkNode($U);
        $str .= $query->checkbox("approvepic_$P->{newuserimage_id}", "", "1", "approve");
        $str .= $query->checkbox("deletepic_$P->{newuserimage_id}", "", "1", "remove");
        $str .= "<hr width=90%><p>";
    }
    $csr->finish;

    $str .= htmlcode('closeform');

    return $str;
}

sub ajax_update
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $mode = $query->param("mode") || "var";
    $PAGELOAD->{noparsecodelinks} = 'nolinks';

    if ($mode eq 'message') {
        $query->param('message',$query->param("msgtext"));
        my @deleteParams = split(',', $query->param("deletelist") || '');
        foreach (@deleteParams) {
            $query->param($_,1);
        }
        Everything::Delegation::opcode::message($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);
        return $query->param('sentmessage');
    }

    if ($mode eq 'getNodeInfo') {
        my $type = $query->param("type");
        my $title = $query->param("title");
        my $field = $query->param("field");
        return unless ($type && $title && $field);

        my $tempNode = getNode($title,$type);
        return unless $tempNode;

        return $tempNode->{$field};
    }

    $NODE = getNodeById(124);

    return '';
}

sub what_does_what {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    return unless $APP->isAdmin($USER);

    my $str = "<p align=\"right\">".linkNode(getNode("superdoc documentation", "setting"), "edit/add documentation", {displaytype => "edit"})."</p>";

    my $documentation = getVars(getNode("superdoc documentation", "setting"));

    $documentation ||= {};

    my @types = ("superdoc","oppressor_superdoc");

    push @types, ("restricted_superdoc", "setting") if $APP->isAdmin($USER);
    foreach(@types)
    {
        $str.="<h1>$_";
        $str.=" - ".linkNode(getNode("$_ documentation", "setting"), "edit documentation") if $APP->isAdmin($USER);
        $str.="</h1><table>";
        my $type = getType($_);
        my $csr = $DB->sqlSelectMany("node_id", "node", "type_nodetype=$type->{node_id} order by title");

        my $rownum = 1;

        while(my $row = $csr->fetchrow_hashref)
        {
            my $N = getNodeById($row->{node_id});

            $str.="<tr".(($rownum % 2)?(" class=\"oddrow\""):(""))."><td><small><strong>".linkNode($N)."</strong></small></td><td><small>($N->{node_id})</small></td><td>".($documentation->{$N->{node_id}} || "<em>none</em>")."</td></tr>";
            $rownum++;
        }

        $str.="</table><br>";
    }
    return $str;
}

sub quick_rename {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = htmlcode('openform');

    $str .= "<p align=\"right\"><small>This will allow you to retitle a lot of e2nodes in mass. Enter the title of the node originally on the left, and the new title on the right.  It will retitle the node and repair it, all in one fell swoop</small></p>";

    foreach(1..30)
    {
        my $from = $query->param("retitle_from$_");
        my $to = $query->param("retitle_to$_");

        next unless($from and $to);
        $from =~ s/\s+$//g;
        $to =~ s/\s+$//g;
        my $fromnode = getNode($from, "e2node");

        unless($fromnode)
        {
            $str.="<font color=\"red\">No such e2node".linkNodeTitle($from,0,1)."</font><br>";
            next;
        }

        my $realfrom = $$fromnode{title};
        my $changeCaps = ($realfrom ne $to && lc($realfrom) eq lc($to));

        if($realfrom eq $to){
            $str.="<font color=\"red\">Didn't change the title at  all:".linkNodeTitle($realfrom,0,1)."</font><br>";
            next;
        }

        my $tonode = getNode($to, "e2node");
        if($tonode && !$changeCaps)
        {
            $str.="<font color=\"red\">Target e2node already exists: ".linkNodeTitle($to,0,1)."</font><br>";
            next;
        }


        $fromnode->{title} = $to;
        updateNode($fromnode, -1);

        $str.=linkNodeTitle($realfrom,0,1)." has been renamed to ".linkNode($fromnode)." ";

        my $repair_success = htmlcode("repair e2node", $fromnode->{node_id});

        if($repair_success)
        {
            $str.="(repair ok)";
        }else
        {
            $str.="(repair failed)";
        }

        $query->delete("retitle_from$_", "retitle_to$_");
        $str.="<br>";

    }

    $str.= "<p>Retitle items: <br><br>";
    $str.="<table>";
    for(1..30)
    {
        $str.= "<tr>";
        $str.= $query->td("<tt>retitle: </tt>");
        $str.= $query->td({-width => "200"}, $query->textfield("retitle_from$_"));
        $str.= $query->td("<tt>to: </tt>");
        $str.= $query->td({-width => "200"}, $query->textfield("retitle_to$_"));
        $str.= "</tr>";
    }

    $str.="</table>";
    $str.=htmlcode('closeform', "Retitle items");

    return $str;
}

sub recalculated_users {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $queryText = "SELECT user.user_id,user.experience FROM setting,user WHERE setting.setting_id=user.user_id AND setting.vars LIKE '%hasRecalculated=1%'";

    my $rows = $DB->{dbh}->prepare($queryText)
        or return $DB->{dbh}->errstr;
    $rows->execute()
        or return $DB->{dbh}->errstr;

    my @list = ();
    my $dbrow;
    while($dbrow = $rows->fetchrow_arrayref)
    {
        push(@list, linkNode($dbrow->[0]) . ' - Level: ' . $APP->getLevel($dbrow->[0]) . ' - XP: ' . $dbrow->[1]);
    }

    my $str = '';
    $str .= '<h3>Users who have run [Recalculate XP]</h3>';
    $str .= '<ol style="margin-left:55px">';
    foreach my $key (sort { lc($a) cmp lc($b) } @list)
    {
        $str .= '<li>'.$key.'</li>';
    }
    $str .= '</ol>';

    return $str;
}

1;
