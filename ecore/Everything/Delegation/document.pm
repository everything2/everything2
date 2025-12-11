package Everything::Delegation::document;

use strict;
use warnings;

# Used in: reputation_graph, reputation_graph_horizontal
use Date::Parse;

# Used in: findings_, sql_prompt
use Time::HiRes;

# Used in: ajax_update
use JSON;
use Everything::Delegation::opcode;

# Used in: chatterbox_xml_ticker, cool_nodes_xml_ticker, new_nodes_xml_ticker,
#          private_message_xml_ticker, rdf_search, user_information_xml,
#          user_search_xml_ticker
use XML::Generator;

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

# Used by Log Archive
use DateTime;

# Used by reputation_graph, reputation_graph_horizontal
use Date::Parse;

# Used by Node Backup
use Everything::S3;
use IO::Compress::Zip;
use utf8;

sub bounty_hunters_wanted {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<style type="text/css"> .mytable th, .mytable td {border: 1px solid silver;padding: 3px;}</style>|;

    $str .= q|<p align=center><b>[Everything's Most Wanted] is now automated</b></p>|;
    $str .= q(<p>Okay, so [mauler|I] just finished fully automating the [Everything's Most Wanted] feature so that noders can manage bounties they have posted by themselves without having to go through the tedious process of messaging an admin several times. Hopefully this feature should be a lot more useful now. [Everything's Most Wanted\|Check it out!]</p>);
    $str .= q(<p>The five most recently requested nodes are automatically listed below. If you fill one of these, please message the requesting noder to claim your prize. Please see [Everything's Most Wanted|the main list] for full details on conditions and rewards.</p>);
    $str .= q|<p>&nbsp;</p>|;
    $str .= q|<table>|;
    $str .= q|<p><table class='mytable' align=center><tr><th>Requesting Sheriff</th><th>Outlaw Nodeshell</th><th>GP Reward (if any)</th></tr>|;

    my $REQ  = getVars( getNode( 'bounty order',  'setting' ) );
    my $OUT  = getVars( getNode( 'outlaws',       'setting' ) );
    my $REW  = getVars( getNode( 'bounties',      'setting' ) );
    my $HIGH = getVars( getNode( 'bounty number', 'setting' ) );
    my $MAX  = 5;

    my $bountyTot   = $HIGH->{1};
    my $numberShown = 0;
    my $outlawStr   = '';
    my $requester   = undef;
    my $reward      = undef;

    for ( my $i = $bountyTot ; $numberShown < $MAX ; $i-- ) {

        if ( exists $REQ->{$i} ) {
            $numberShown++;
            $requester = $REQ->{$i};
            $outlawStr = $OUT->{$requester};
            $reward    = $REW->{$requester};
            $str .= "<tr><TD>[$requester]</TD><TD>$outlawStr</TD><TD>$reward</TD></tr>";
        }
    }

    $str .= q{</table><p align=center>([Everything's Most Wanted|see full list])</p><p>&nbsp;</p>};

    return $str;
}

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


# REMOVED (2025-12-10): create_category delegation (112 lines)
# Now handled by Everything::Page::create_category
# React component provides interactive category creation form

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

    my $maintainerName = $query->param('m');
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

    my $order = $query->param('o');

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
      if ( $maintainer->{node_id} > 0 );

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

sub drafts {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str      = qq|<div id="pagebody">|;
    my $user     = $query->param('other_user');
    my $username = '';

    my $showhidenukedlink   = undef;
    my $shownukedlinkparams = {};

    if ($user) {
        $shownukedlinkparams->{other_user} = $user;
        my $u = getNode( $user, 'user' );
        return
            '<div id="pagebody"><p>No user named "'
          . $query->escapeHTML($user)
          . '" found.</p></div>'
          unless $u;
        $user = $$u{node_id};

        # record displayed status:
        $username = $$u{title} unless $user == $$USER{node_id};
    }

    if ( $query->param('shownuked') ) {
        $showhidenukedlink =
          linkNode( $NODE, 'Hide nuked', $shownukedlinkparams );
    }
    else {
        $shownukedlinkparams->{shownuked} = 1;
        $showhidenukedlink =
          linkNode( $NODE, 'Show nuked', $shownukedlinkparams );
    }

    $showhidenukedlink = "<strong>($showhidenukedlink)</strong>";

    $user ||= $$USER{node_id};
    $query->delete('other_user') unless $username;

    my $status = {};    # plural of Latin 'status' is 'status'
    my ( $ps, $cansee, $collaborators, $nukeeslast, $title, $showhide, $cs,
        $nukees )
      = ( '', '', '', '', '', '', '', '' );
    my $draftType = getType('draft');

    my $nukedStatus = getNode('nuked', 'publication_status');

    my $draftStatus = "publication_status != $$nukedStatus{node_id}";

    if ( $query->param('shownuked') ) {
        $draftStatus = "publication_status = $$nukedStatus{node_id}";
    }

    my $statu = sub {
        $_[0]->{type} = $draftType;
        $ps = $_[0]->{publication_status};
        if ( $$status{$ps} ) {
            $ps = $$status{$ps};
        }
        else {    # only look up each status once
            $ps = $ps ? $$status{$ps} = getNodeById($ps)->{title} : 'broken';
            $$status{$ps} = 1 unless $username;  # to track if any of mine nuked
        }
        return qq'<td class="status">$ps</td>';
    };

    my @showit = (
        'title, author_user, publication_status, collaborators',
        'node JOIN draft ON node_id = draft_id',
"author_user = $user AND type_nodetype = $$draftType{node_id} AND $draftStatus",
        'ORDER BY title'
    );

    unless ($username) {
        $title         = 'Your drafts';
        $cs            = '<th>Collaborators';
        $collaborators = sub {
            qq'<td class="collaborators">'
              . (
                defined( $_[0]->{collaborators} )
                ? ( $_[0]->{collaborators} )
                : ('')
              ) . '</td>';
        };

        $showit[-1] =
            'ORDER BY publication_status='
          . getId( getNode( 'nuked', 'publication_status' ) )
          . ', title'
          if $nukeeslast;

        $showit[-1] .= ' LIMIT 25';
        unshift @showit, 'show paged content';

    }
    else {
        $title  = "${username}'s drafts (visible to you)";
        $cansee = sub {
            my $draft = shift;
            return $APP->canSeeDraft( $USER, $draft, "find" );
        };

        $cs =
'<th title="shows whether you or a usergroup you are in is a collaborator on this draft">Collaborator?';
        $collaborators = sub {
            my $yes = '&nbsp;';
            if ( $_[0]->{collaborators} ) {
                if ( $_[0]->{collaborators} =~
                    qr/(?:^|,)\s*$$USER{title}\s*(?:$|,)/i )
                {
                    $yes = 'you';
                }
                elsif ( $ps =
                    'private' || $APP->canSeeDraft( $USER, $_[0], 'edit' ) )
                {
                    $yes = 'group';
                }
            }
            return qq|<td class="collaborators">$yes</td>|;
        };

        @showit = ( 'show content', $DB->sqlSelectMany(@showit) );
    }

    my ( $drafts, $navigation, $count ) = htmlcode(
        @showit, '<tr class="&oddrow"> status, "<td>", title, "</td>", coll'
        ,
        cansee => $cansee,
        status => $statu,
        coll   => $collaborators
    );

    if ( $drafts eq '' ) {
        if ( !$username ) {
            $str .= qq|<p>You have no drafts.</p>$showhidenukedlink|;
        }
        else {
            $str .=
qq|<p>[${username}[user]] has no drafts visible to you.</p>$showhidenukedlink|;
        }
    }
    else {

        my $showcount = '';
        $showcount = "<p>You have $count drafts.</p>" if $navigation;

        my $outstr = '';
        $outstr = "<h2>$title</h2>$showhidenukedlink<br />
      $showcount
      <table><tr><th>status</th><th>title</th>$cs</th></tr>
      $drafts
      </table>
      $nukees
      $navigation<br />" if $drafts ne '';

        $str .= $outstr;
    }
    $str .= qq|</div>|;                             #pagebody
    $str .= htmlcode( "openform", "pagefooter" );

    unless ( $query->param('other_user') ) {
        $str .= htmlcode('editwriteup');
    }
    $str .= qq|</form>|;

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

    $str .= htmlcode("giftshop_star");
    $str .= htmlcode("giftshop_sanctify");
    $str .= htmlcode("giftshop_buyvotes");
    $str .= htmlcode("giftshop_votes");
    $str .= htmlcode("giftshop_ching");
    $str .= htmlcode("giftshop_buyching");
    $str .= htmlcode("giftshop_topic");
    $str .= htmlcode("giftshop_buyeggs");
    $str .= htmlcode("giftshop_eggs");

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
    my $view_weblog  = $query->param('view_weblog');
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
        $link = "<b>$link</b>" if $node_id == $view_weblog;
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

sub writeups_by_type {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    ####################################################################
    # get all the URL parameters

    my $wuType = abs int( $query->param('wutype') || 0 );

    my $count = $query->param('count') || 50;
    $count = abs int($count);

    my $page = abs int( $query->param('page') || 0 );

    ####################################################################
    # Form with list of writeup types and number to show

    my (@WRTYPE) =
      $DB->getNodeWhere( { type_nodetype => getId( getType('writeuptype') ) } );
    my %items;
    map { $items{ $$_{node_id} } = $$_{title} } @WRTYPE;

    my @idlist = sort { $items{$a} cmp $items{$b} } keys %items;
    unshift @idlist, 0;
    $items{0} = 'All';

    my $str = htmlcode('openform') . qq|<fieldset><legend>Choose...</legend><input type="hidden" name="page" value="$page"><label><strong>Select Writeup Type:</strong>|
      . $query->popup_menu( 'wutype', \@idlist, 0, \%items ).q|</label><label> &nbsp; <strong>Number of writeups to display:</strong>|
      . $query->popup_menu( 'count',
        [ 10, 25, 50, 75, 100, 150, 200, 250, 500 ], $count )
      . '</label> &nbsp; '
      . $query->submit('Get Writeups')
      . '</fieldset></form>';

    ####################################################################
    # get writeups
    #

    my $where = '';
    $where = "wrtype_writeuptype=$wuType" if $wuType;
    my $wus = $DB->sqlSelectMany('
       node.node_id, writeup_id, parent_e2node, publishtime,
      node.author_user,
      type.title AS type_title', '
      writeup
      JOIN node ON writeup_id = node.node_id
      JOIN node type ON type.node_id = writeup.wrtype_writeuptype',
        $where, '
      ORDER BY publishtime DESC LIMIT ' . ( $page * $count ) . ',' . $count );

    ####################################################################
    # display
    #

    $str .= '<table style="margin-left: auto; margin-right: auto;">
      <tr>
      <th>Title</th>
      <th>Author</th>
      <th>Published</th>
      </tr>';

    my $oddrow = 1;
    while ( my $row = $wus->fetchrow_hashref ) {
        $str .= $APP->writeups_by_type_row( $row, $VARS, ( $oddrow % 1 == 0 ) );
        $oddrow++;
    }

    $str .= q|</table>|;

    $str .= '<p class="morelink">';
    $str .=
      linkNode( $NODE, '&lt&lt Prev',
        { wutype => $wuType, page => $page - 1, count => $count } )
      . ' | '
      if $page;

    $str .=
        '<b>Page '
      . ( $page + 1 )
      . '</b> | '
      . linkNode(
        $NODE,
        'Next &gt;&gt;',
        { wutype => $wuType, page => $page + 1, count => $count }
      ) . '</p>';

    return $str;
}


sub simple_usergroup_editor {
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $forbidden_for_editors = {'content editors' => 1, 'gods' => 1, 'e2gods' => 1};
    my $editor_only = ($APP->isEditor($USER) and not $APP->isAdmin($USER));

    my @find =
      $APP->isEditor($USER)
      ? ( 'node', 'type_nodetype=' . getId( getType('usergroup') ) )
      : (
        'nodeparam JOIN node on nodeparam.node_id=node.node_id',
        "paramkey='usergroup_owner' AND paramvalue='$$USER{node_id}'"
      );

    my $csr = $DB->sqlSelectMany( 'node.node_id, node.title',
        @find, 'ORDER By node_id' );

    my $str = '';
    my %ok  = ();
    while ( my $row = $csr->fetchrow_hashref() ) {
        if($editor_only)
        {
            next if exists($forbidden_for_editors->{lc($row->{title})});
        }
        #    next if $protected{$row -> {node_id}};
        $ok{ $row->{node_id} } = 1;

        $str .= '<li>Edit '
          . linkNode( $NODE->{node_id}, $row->{title},
            { for_usergroup => $row->{node_id} } )
          . '</li>';
    }

    return 'You have nothing to edit here.' unless $str;

    $str =
qq'<table><tr><td width="200" valign="top" border="1">Choose a usergroup to edit:<ul>
$str
</ul>
</td>';

    my $usergroup =
      $query->param('for_usergroup')
      ? getNodeById( $query->param('for_usergroup') )
      : 0;

    if($usergroup and exists($forbidden_for_editors->{lc($usergroup->{title})}) and $editor_only)
    {
        $usergroup = undef;
    }

    return $str . '</tr></table>'
      unless $usergroup and $ok{ $usergroup->{node_id} };

    $str .= '<td valign="top">
<h3>Editing ' . linkNode($usergroup) . '</h3>';

    foreach ( $query->param ) {
        if ( $_ =~ /rem_(\d+)/ ) {
            my $u = getNodeById($1);
            next unless $u;
            $DB->removeFromNodegroup( $usergroup, $u, -1 );
            $str .= 'Removed: ' . linkNode($u) . '<br>';
        }
    }

    if ( $query->param('addperson') ) {
        my $u;
        foreach ( split( "\n", $query->param('addperson') ) ) {
            $_ =~ s/\s+$//g;
            if ( defined( $u = getNode( $_, 'user' ) ) ) {
                $DB->insertIntoNodegroup( $usergroup, -1, $u );
                $str .= 'Added user: ' . linkNode($u) . '<br>';
                next;
            }
            if ( defined( $u = getNode( $_, 'usergroup' ) ) ) {
                $DB->insertIntoNodegroup( $usergroup, -1, $u );
                $str .= 'Added usergroup: ' . linkNode($u) . '<br>';
                next;
            }
            $str .=
                '<font color="red">No such user&#91;group&#93; '
              . $_
              . '!</font><br>';
        }
    }

    updateNode( $usergroup, -1 );

    $str .= htmlcode('openform');
    $str .= '<table>
<tr><td width="200"><strong>Remove?</strong></td><td width="300">User</td></tr>
';
    foreach ( @{ $$usergroup{group} } ) {
        my $u = getNodeById($_);
        next unless $u;
        $str .=
          "<tr><td><input type=\"checkbox\" name=\"rem_$$u{node_id}\"></td><td>"
          . linkNode($u);
        $str .=
            ' <small>('
          . htmlcode( 'timesince', ( $u->{lasttime} ) . ',1' )
          . ')</small>';
        $str .= '</td></tr>';
    }

    $str .= q|</table>|;

    $str .= q|Add people (one per line):<br>|;
    $str .= q|<textarea name="addperson" rows="20" cols="30"></textarea>|;
    $str .= q|<input type="submit" name="submit" value="Update group">|;
    $str .= qq|<input type="hidden" name="for_usergroup" value="$usergroup->{node_id}">|;

    $str .= q|</form>|;

    $str .= q|<p><b>Users Ignoring This Group</b> (includes ex-members)</p>|;
    $str .= q|<ul>|;
    my $ignore = $DB->sqlSelectMany( 'messageignore_id', 'messageignore',
        'ignore_node=' . $query->param('for_usergroup') );
    my $ignorelist;
    while ( $ignorelist = $ignore->fetchrow_hashref() ) {
        $str .= q|<li>| . linkNode( $$ignorelist{messageignore_id} ) . q|</li>|;
    }
    $str .= q|</ul></td></tr></table>|;
    return $str;

}

# everything_s_biggest_stars - REMOVED (migrated to Everything::Page::everything_s_richest_noders + React)
# word_messer_upper - REMOVED (migrated to Everything::Page::word_messer_upper + React)
# log_archive - REMOVED (migrated to Everything::Page::log_archive + React)

sub show_user_vars
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $str = '';

    my $uid = getId($USER);
    return 'Try logging in.' if $APP->isGuest($USER);
    my $isRoot = $APP->isAdmin($USER);
    my $isEDev = $APP->isDeveloper($USER);
    return ($str . ' Ummmm... no.') unless $isRoot || $isEDev;

    my $username;
    $username = $query->param('username') if $isRoot;
    my $inspectUser;
    $inspectUser = getNode($username, 'user') if (defined $username);
    $inspectUser = $USER if (!$inspectUser);
    my $inspectVars = getVars($inspectUser);

    if ($isRoot) {
        $str .=
        htmlcode('openform', 'uservarsform', 'GET')
        . 'Showing user variables for '
        . $query->textfield(
            -value => $$inspectUser{title}
            , -name => 'username'
            , -size => 30
            )
        . $query->submit('Show user vars')
        . '<br />'
        . $query->end_form
        ;
    } else {
        $str .= $inspectUser->{title} . '<br />';
    }


    my $tOpen = q|<table border="1" cellpadding="1" cellspacing="1">|;
    my $tClose = q|</table>|;

    my @validKeys = ();
    my $key = undef;
    my $val = undef;

    if($isRoot) {
    @validKeys = keys(%$inspectVars);
    } else {
    @validKeys =
    (
        'borged',
        'coolnotification','cools','coolsafety',
        'emailSubscribedusers','employment',
        'ipaddy',
        'level',
        'mission','motto',
        'nick','nodelets','nohints','nowhynovotes',
        'nullvote','numborged','numwriteups','nwriteups',
        'personal_nodelet',
        'specialties'
    );
    }

    if($isEDev) {
        push(@validKeys, 'can_weblog') unless $isRoot;
        push(@validKeys, 'hidden_weblog') unless $isRoot;
        # List of hidden weblog commands (from Unhideify!)
        foreach (keys %$inspectVars){
            if(/hide_weblog_(\d*)/){
                push @validKeys, $_ unless $isRoot;
            }
        }
    }

    @validKeys = sort(@validKeys);
    $str .= '<h3>VARS</h3>' . $tOpen;
    foreach my $key (@validKeys) {
        next if length($key)==0;
        $val = encodeHTML($inspectVars->{$key});
        $val =~ s/[\r\n]+/<br>/g if $key =~ /^notelet/;
        $val='(<em>null</em>)' unless defined $val;
        $str.='<tr><td>' . encodeHTML($key)
            . '</td><td>' . $val . "</td>\n";
    }
    $str.=$tClose;

    if($isRoot) {
        @validKeys = keys(%$inspectUser);
    } else {
        @validKeys = ();
    }
    @validKeys = sort(@validKeys);
    $str .= '<h3>USER</h3>'.$tOpen;
    foreach my $key (@validKeys) {
        next if length($key)==0;
        next if (($key eq 'vars') || ($key eq 'passwd'));
        if($key ne '' and $key ne 'vars')
        {
            $val = $inspectUser->{$key};
            $val='(<em>null</em>)' unless defined $val;
            $str.='<tr><td>' . encodeHTML($key)
                . '</td><td>' . encodeHTML($val) . "</td>\n";
        }
    }
    $str.=$tClose;

    return $str;
}

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

sub cache_dump
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $output = q|This is what the cache contains<br>|;
    $output .= q|(Process ID: |.$$.q|)<br /><p>|;

    my $cache = $DB->getCache()->dumpCache();
    my $num = $DB->getCache()->getCacheSize();
    $output .= "Cache size: $num";

    $output .= q|<ul>|;

    my $typestats;

    foreach my $cache_entry (@$cache)
    {
        next unless $cache_entry;

        my $item = $cache_entry->[0];
        my $extrainfo = [];

        $typestats->{$item->{type}->{title}} ||= 0;
        $typestats->{$item->{type}->{title}}++;

        push @{$extrainfo}, $item->{type}->{title};

        if($cache_entry->[1]->{permanent})
        {
            push @{$extrainfo}, 'permanent';
        }

        if(exists($item->{group}))
        {
            push @{$extrainfo}, scalar(@{$item->{group}}). q| items in group|;
        }

        if(exists($DB->{cache}->{groupCache}->{$item->{node_id}}))
        {
            push @$extrainfo, scalar(keys %{$DB->{cache}->{groupCache}->{$item->{node_id}}}).q| items in groupCache|;
        }

        $output .= "<li> $item->{title} (".join(' , ',@$extrainfo).')';
    }

    $output .= q|</ul><br /><br />Counts: <ul>|;

    foreach my $key(keys %$typestats)
    {
        $output .= "<li>$key: ".$typestats->{$key}
    }

    $output .= q|</ul>|;
    $output .= q|Pagecache:<ul>|;

    foreach my $key (keys %{$DB->{cache}->{pagecache}})
    {
        $output .= "<li>$key: ".$DB->{cache}->{pagecache}->{$key};
    }

    $output .= q|</ul>|;
    return $output;

}

sub the_tokenator
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $output = '';
    my @params = $query->param;

    my (@users, @thenodes);
    foreach (@params) {
        if(/^tokenateUser(\d+)$/)
        {
            $users[$1] = $query->param($_);
        }
    }

    for(my $count=0; $count < @users; $count++)
    {
        next unless $users[$count];

        my ($U) = getNode($users[$count], 'user');
        if (not $U)
        {
            $output.="couldn't find user $users[$count]<br />";
            next;
        }

        # Send an automated notification.
        my $failMessage = htmlcode('sendPrivateMessage',{
            'recipient_id'=>getId($U),
            'message'=>'Whoa! Somebody has given you a [token]! Use it to [E2 Gift Shop|reset the chatterbox topic].',
            'author'=>'Cool Man Eddie'});

        $output .= "User $$U{title} was given one token";

        my $v = getVars($U);
        if (!exists($$v{tokens}))
        {
            $$v{tokens} = 1;
        } else {
            $$v{tokens} += 1;
        }
        setVars($U, $v);
        $output .= q|<br />|;
    }

    # Build the table rows for inputting user names
    my $count = 5;
    $output.=htmlcode('openform');
    $output.='<table border="1">';

    $output.=q|<tr><th>Tokenate these users</th></tr> |;

    for (my $i = 0; $i < $count; $i++)
    {
        $query->param("tokenateUser$i", '');
        $output.=q|<tr><td>|;
        $output.=$query->textfield("tokenateUser$i", '', 40, 80);
        $output.=q|</td>|;
    }

    $output.=q|</table>|;
    $output.=htmlcode('closeform');

    return $output;
}

sub go_outside
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $isCoolPerson = $APP->isEditor($USER) || $APP->isChanop($USER);

    if ($VARS->{lockedin} > time && !$isCoolPerson)
    {
        my $remainingtime = int( ($VARS->{lockedin} - time)/ 60 + 0.5);
        my $lockmessage = q|<p><strong style='color:red;'>|
        . qq|You cannot change rooms for $remainingtime minutes.  |
        . q|You can still send private messages, however, or talk to people in your current room.</strong></p>|;
        return $lockmessage;
    }

    return if $APP->isGuest($USER);
    $APP->changeRoom($USER,0);
    return q|You step outside. You see many noders here.|;
}

sub ip2name
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $output = htmlcode('openform');
    $output .= q|Please use me sparingly! I am expensive to run! Note: this probably won't work too well with people that have dynamic IP addresses. <p>|;

    if (my $like = $query->param('ipaddy'))
    {
        $like =~ s/\./\%\%2e/g;
        $like = "\%ipaddy\=$like\%";

        my $results = '';
        my $csr = $DB->sqlSelectMany('setting_id', 'setting', 'vars like '. $DB->{dbh}->quote($like));

        while (my ($id) = $csr->fetchrow)
        {
            $results.=linkNode($id).q|<br>|;
        }

        $results ||= q|<i>nein!</i><br>|;
        $output .= $results;
    }

    $output .= $query->textfield('ipaddy', '');
    $output .= htmlcode('closeform');

    return $output;
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

sub create_node
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $str = '';

    # Static HTML text from doctext
    $str .= '<p><i><h3>Please:</h3></i>  <ul><li>Before creating a [new] node make sure there isn\'t already a node that you could simply [add a writeup] to.  Often a user will create a new node only to find there are several others on the same topics.  Just type several key-words in the [search box] above--there\'s a pretty good chance somebody\'s already created a node about it. <br><br></p>';

    # Delete 'node' param and start form
    $query->delete("node");
    $str .= $query->start_form;

    # Node name textfield
    $str .= "Node name: ";
    $str .= $query->textfield(
        -name => "node",
        -size => 50,
        -maxlength => 100,
        -value => ($query->param('newtitle') || "")
    );
    $str .= "<br>";

    # Nodetype popup
    $str .= "Nodetype: ";
    my @idlist = ();
    my %items = ();
    my $csr = $DB->sqlSelectMany("*", "node", "type_nodetype=".getId(getType('nodetype'))." ORDER BY title ASC");

    while(my $r = $csr->fetchrow_hashref()) {
        my $n = getNodeById($$r{node_id});
        $items{$$n{node_id}} = $$n{title};
        push @idlist, $$n{node_id};
    }

    $query->param('type', getId(getType('e2node')));
    $str .= $query->popup_menu("type", \@idlist, "", \%items);

    # Hidden field and submit button
    $str .= '<input TYPE="hidden" NAME="op" VALUE="new">';
    $str .= $query->submit('createit', 'Create It!');
    $str .= $query->end_form;

    return $str;
}


sub everything_s_most_wanted
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $text = '';

    # Static HTML: CSS and header
    $text .= '<style type="text/css">
.mytable th, .mytable td
{
border: 1px solid silver;
padding: 3px;
}
</style>

<p><blockquote><p align=center><b>Welcome to Everything\'s Most Wanted</b></p>


';

    # Block 1: Main bounty management logic
    my $minlevel = 3;
    my $lvl = $APP->getLevel($USER);
    my $isSheriff = $APP->inUsergroup($USER, "sheriffs");

    my $userGP = $$USER{GP};
    my $sheriff = $$USER{title};
    my $BountyLimit = ($userGP / 10);

    my $str = "<p><br>Howdy stranger! Reckon you have the [cojones] to take down some of the meanest nodes this side of the [Rio Grande]? Below is a list of the most dangerously unfilled nodes ever to wander the lawless plains of the [nodegel]. Track one down, hogtie it, and fill it up with good content, and you might end up earning yourself a shiny silver sheriff's star.

<p>Any user can fill a posted node and claim the posted bounty. If you think you have captured one of these fugitives, contact the requesting sheriff. If they judge your writeup worthy, you will get your reward!

<p>Check back often for new bounties. Happy hunting!</p>

<p>&nbsp;</p>";

    unless (($APP->isAdmin($USER)) || ($isSheriff)) {
        $text .= $str;
        return $text if ($lvl < $minlevel);
    }

    $str .= "<p><hr width=50></p><p>&nbsp;</p>";

    if ($query->param("yankify")) {
        my $removee = encodeHTML($query->param("removee"));
        my $user = getNode($removee, 'user');
        unless ($user) {
            $text .= "<p>The user '$removee' doesn't exist!</p><p>Please [Everything's Most Wanted|try again].</p><p>&nbsp;</p>";
            return $text;
        }

        my $rewardnode = getNode('bounties', 'setting');
        my $REF = getVars($rewardnode);
        my $refund = $$REF{$removee};
        $APP->adjustGP($user, $refund);

        my $v = getVars($user);
        $$v{Bounty} = 0;
        setVars($user, $v);

        if ($$USER{title} eq $removee) {
            $$VARS{Bounty} = 0;
            setVars($USER, $VARS);
        }

        my $deletenode = getNode('bounty order', 'setting');
        my $deletevars = getVars($deletenode);
        delete $$deletevars{$$v{BountyNumber}};
        setVars($deletenode, $deletevars);

        $str = "<hr width=50></p><p>&nbsp;</p><p>Okay, [$removee]'s bounty has been removed";
        if ($refund > 0) {
            $str .= " and <b>$refund GP</b> has been returned to their account";
        }
        $str .= ".</p><p>Do you need to [Everything's Most Wanted|remove another bounty]?</p>";
        $str .= "<p>&nbsp;</p>";

        $text .= $str;
        return $text;
    }

    $$VARS{Bounty} = 0 unless($$VARS{Bounty});

    if ($$VARS{Bounty} == 1) {
        my $citation = undef;
        my $outset = getVars(getNode('outlaws', 'setting'));
        my $outlaw = $$outset{$sheriff};
        my $rwdset = getVars(getNode('bounties', 'setting'));
        my $reward = $$rwdset{$sheriff};
        if ($reward eq "N/A") {
            $reward = 0;
        }

        if ($query->param("bountify")) {
            my $LuckyWinner = encodeHTML($query->param("rewardee"));
            my $user = getNode($LuckyWinner, 'user');
            unless ($user) {
                $text .= "<p>The user '$LuckyWinner' doesn't exist!</p><p>Please [Everything's Most Wanted|try again].</p><p>&nbsp;</p>";
                return $text;
            }
            if ($$USER{title} eq $LuckyWinner) {
                $text .= "<p>It is not possible to reward yourself!</p><p>Please [Everything's Most Wanted|try again].</p><p>&nbsp;</p>";
                return $text;
            }

            $APP->adjustGP($user, $reward);
            $$VARS{Bounty} = 0;
            setVars($USER, $VARS);

            my $deletenode = getNode('bounty order', 'setting');
            my $deletevars = getVars($deletenode);
            delete $$deletevars{$$VARS{BountyNumber}};
            setVars($deletenode, $deletevars);

            $citation = "[$LuckyWinner] tracked down $outlaw and earned $reward GP from [$sheriff]!";

            my $justicenode = getNode('justice served', 'setting');
            my $justicevars = getVars($justicenode);
            my $numbernode = getNode('bounty number', 'setting');
            my $numbervar = getVars($numbernode);

            my $citesNum = (($$numbervar{"justice"})+1);
            $$justicevars{$citesNum} = $citation;
            $$numbervar{"justice"}++;
            setVars($justicenode, $justicevars);
            setVars($numbernode, $numbervar);

            $str = "<p>Okay, user [$LuckyWinner] has been rewarded the bounty of <b>$reward GP</b>.</p><p>Would you like to [Everything's Most Wanted|post a new bounty]?</p>";
            $str .= "<p>&nbsp;</p>";

            $text .= $str;
            return $text;
        }

        if ($query->param("awardify")) {
            my $LuckyWinner = encodeHTML($query->param("awardee"));
            my $Prize = encodeHTML($query->param("awarded"));
            my $user = getNode($LuckyWinner, 'user');
            unless ($user) {
                $text .= "<p>The user '$LuckyWinner' doesn't exist!</p><p>Please [Everything's Most Wanted|try again].</p><p>&nbsp;</p>";
                return $text;
            }
            if ($$USER{title} eq $LuckyWinner) {
                $text .= "<p>It is not possible to reward yourself!</p><p>Please [Everything's Most Wanted|try again].</p><p>&nbsp;</p>";
                return $text;
            }

            $APP->adjustGP($user, $reward);
            $$VARS{Bounty} = 0;
            setVars($USER, $VARS);

            my $deletenode = getNode('bounty order', 'setting');
            my $deletevars = getVars($deletenode);
            delete $$deletevars{$$VARS{BountyNumber}};
            setVars($deletenode, $deletevars);

            $citation = "[$LuckyWinner] rounded up $outlaw and earned a bounty from [$sheriff] of $Prize";
            if ($reward > 0) {
                $citation .= " and $reward GP";
            }
            $citation .= "!";

            my $justicenode = getNode('justice served', 'setting');
            my $justicevars = getVars($justicenode);
            my $numbernode = getNode('bounty number', 'setting');
            my $numbervar = getVars($numbernode);

            my $citesNum = (($$numbervar{"justice"})+1);
            $$justicevars{$citesNum} = $citation;
            $$numbervar{"justice"}++;
            setVars($justicenode, $justicevars);
            setVars($numbernode, $numbervar);

            $str = "<p><br>Okay, let the record show that user [$LuckyWinner] has been awarded a bounty of <b>$Prize</b>";
            if ($reward > 0) {
                $str .= " and <b>$reward GP</b>";
            }
            $str .= "!</p>";
            $str .= "<p>&nbsp;</p><p>Would you like to [Everything's Most Wanted|post a new bounty]?</p>";
            $str .= "<p>&nbsp;</p>";

            $text .= $str;
            return $text;
        }

        if ($query->param("Reward")) {
            $str = "<p>&nbsp;</p><p>Okay, who would you like the posted bounty of <b>$reward GP</b> to be awarded to? ";
            $str .= htmlcode('openform');
            $str .= $query->textfield("rewardee");
            $str .= " " . $query->submit("bountify","Reward Them!");
            $str .= $query->end_form;
            $str .= "<p>&nbsp;</p>";

            $text .= $str;
            return $text;
        }

        if ($query->param("Award")) {
            $str = htmlcode('openform');
            $str .= "<p>Okay, which noder are you rewarding? ";
            $str .= $query->textfield("awardee") . " And what exactly are you giving to them? ";
            $str .= $query->textfield("awarded") . "</p>";
            $str .= " " . $query->submit("awardify","Reward Them!");
            $str .= $query->end_form;
            $str .= "<p>&nbsp;</p>";

            $text .= $str;
            return $text;
        }

        if ($query->param("Remove")) {
            $APP->adjustGP($USER, $reward);
            $$VARS{Bounty} = 0;
            setVars($USER, $VARS);

            my $deletenode = getNode('bounty order', 'setting');
            my $deletevars = getVars($deletenode);
            delete $$deletevars{$$VARS{BountyNumber}};
            setVars($deletenode, $deletevars);

            $str = "<p>&nbsp;</p><p>Okay, your bounty has been removed";
            if ($reward > 0) {
                $str .= ", and the bounty you posted of <b>$reward GP</b> has been returned to your account";
            }
            $str .= ".<p>Would you like to [Everything's Most Wanted|post a new bounty]?</p></p><p>&nbsp;</p>";

            $text .= $str;
            return $text;
        }

        $str .= "<p>You have already posted a bounty. Would you like to remove it (either because it has been filled by a user, or because you just want to take it down)?</p>";

        $str .= htmlcode('openform');
        unless ($$VARS{GPoptout}) {
            unless ($reward == 0) {
                $str .= "<p>" . $query->submit("Reward","Yes, and I'd like to pay out the reward (GP only)") . "</p>";
            }
        }
        $str .= "<p>" . $query->submit("Award","Yes, and I'd like to pay out the reward (including other reward(s) besides GP)") . "</p>";
        $str .= "<p>" . $query->submit("Remove","Yes, just remove it (and return any GP to me)") . "</p>";
        $str .= $query->end_form;
        $str .= "<p>&nbsp;</p>";

        $str .= "<p>&nbsp;</p>";

        $text .= $str;
        return $text;
    }

    if ($query->param("postBounty")) {
        my $bounty = encodeHTML(scalar($query->param("bounty")));
        my $comment = encodeHTML(scalar($query->param("comment")));
        my $outlawed = encodeHTML(scalar($query->param("outlaw")));
        my $isNode = getNode($outlawed, 'e2node');

        if ($bounty eq "") {
            $bounty = "N/A";
        }
        if ($comment eq "") {
            $comment = "&nbsp;";
        }

        unless ($bounty <= $BountyLimit) {
            $text .= "<p>&nbsp;</p><p>Your bounty is too high! Bounties cannot be greater than 10% of your total GP. Please [Everything's Most Wanted|try again].</p>";
            return $text;
        }
        if ($bounty < 0) {
            $text .= "<p>&nbsp;</p><p>You must enter a bounty of 0 or greater. Please [Everything's Most Wanted|try again].</p>";
            return $text;
        }
        if (($bounty < 1) && ($bounty ne "N/A")) {
            $text .= "<p>&nbsp;</p><p>You must enter a number. Please [Everything's Most Wanted|try again].</p>";
            return $text;
        }
        if ($outlawed eq "") {
            $text .= "<p>&nbsp;</p><p>You must specify a node or nodeshell to be filled. Please [Everything's Most Wanted|try again].</p>";
            return $text;
        }
        unless ($isNode) {
            $text .= "<p>&nbsp;</p><p>No such node! Your 'Outlaw Node' must be a valid node or nodeshell.  Please [Everything's Most Wanted|try again].</p>";
            return $text;
        }

        $APP->adjustGP($USER, -$bounty);

        my $bountyNum = undef;
        my $ordernode = getNode('bounty order', 'setting');
        my $maxnode = getNode('bounty number', 'setting');
        my $BNT = getVars($ordernode);
        my $MAX = getVars($maxnode);

        $bountyNum = ($$MAX{1} + 1);
        $$MAX{1}++;
        $$BNT{$bountyNum} = $sheriff;
        setVars($ordernode, $BNT);
        setVars($maxnode, $MAX);

        $$VARS{Bounty} = 1;
        $$VARS{BountyNumber} = $bountyNum;
        setVars($USER, $VARS);

        my $settingsnode = getNode('bounties', 'setting');
        my $bountySettings = getVars($settingsnode);
        $$bountySettings{$sheriff} = $bounty;
        setVars($settingsnode, $bountySettings);

        my $outlawStr = "[$outlawed]";
        my $outlawnode = getNode('outlaws', 'setting');
        my $outlawvars = getVars($outlawnode);
        $$outlawvars{$sheriff} = $outlawStr;
        setVars($outlawnode, $outlawvars);

        my $commentsnode = getNode('bounty comments', 'setting');
        my $commentsvars = getVars($commentsnode);
        $$commentsvars{$sheriff} = $comment;
        setVars($commentsnode, $commentsvars);

        $text .= "<p>&nbsp;</p><p>Your bounty has been posted!</p>";
        return $text;
    }

    if ($query->param("Yes")) {
        $str = "<p>Welcome to the team, Deputy! Enter the outlaw nodeshell you want rounded up below, along with a GP reward. Don't forget to [hardlink] your nodeshell! Also, feel free to add a different kind of reward if you would like, instead of or in addition to the GP reward. Some suggestions include C!s, a postcard, a [node audit], some sort of homemade item, or anything else you can imagine! In this case, explain your reward in the 'Outlaw Nodeshell' box, and feel free to leave the 'Bounty' box blank or enter 0.</p>

<p>When your bounty is posted, any GP you put up as a reward will be removed from your account and held in [escrow], pending successful capture of the bandit in question. However, if you later take your bounty down and choose not to authorize payment to another user, your GP will be returned to you in full. Finally, please note that bounties cannot be larger than 10% of your total GP.</p>";
        $str .= htmlcode('openform');
        $str .= "Outlaw node (just node title, do *not* hardlink): ";
        $str .= $query->textfield("outlaw");
        $str .= "<br><br>Any comments (such as additional non-GP rewards): ";
        $str .= $query->textfield("comment");
        $str .= "<br><br>Bounty (in GP): ";
        if ($$VARS{GPoptout}) {
            $str .= " <em>You are currently [User Settings|opted out] of the [GP] system. Please enter a non-GP reward in the 'comments' box above.</em><br><br>";
        } else {
            $str .= $query->textfield("bounty")."<br><br>";
        }
        $str .= $query->submit("postBounty","Post Bounty!");
        $str .= $query->end_form;
        $str .= "<p>&nbsp;</p>";

        $text .= $str;
        return $text;
    }

    $str .= "<p>Since you are Level $minlevel or higher, you are allowed to add a bounty of your own to the list below. Would you like to add a bounty?</p>";

    $str .= htmlcode('openform');
    $str .= $query->submit("Yes","Yes!");
    $str .= $query->end_form;
    $str .= "<p>&nbsp;</p>";

    $text .= $str;

    # Block 2: Sheriff/admin section for removing bounties
    $str = '';  # REINITIALIZE for mod_perl
    $isSheriff = $APP->inUsergroup($USER, "sheriffs");

    if (($APP->isAdmin($USER)) || ($isSheriff)) {
        unless ($query->param("yankify")) {
            $str .= "<p>&nbsp;</p><p><hr width=50></p><p>&nbsp;</p>";

            if ($APP->isAdmin($USER)) {
                $str .= "<p>Since you are an administrator, you have the authority to delete bounties if necessary. Note that you can also delete or edit automatically generated entries from the 'Justice Served' list by going the [justice served] settings node and removing or editing entries (hard coded entries can be deleted by patching this node).</p>";
            } else {
                $str .= "<p>Since you are a member of the [sheriffs] usergroup, you have the authority to delete bounties if necessary.</p>";
            }

            $str .= "<p>&nbsp;</p><p>Enter the name of a user whose bounty you need to remove: ";
            $str .= htmlcode('openform');
            $str .= $query->textfield("removee");
            $str .= " " . $query->submit("yankify","Remove Bounty");
            $str .= $query->end_form;
            $str .= "<p>&nbsp;</p>";
        }
    }

    $text .= $str;

    # Static HTML: Close blockquote and start table section
    $text .= '</blockquote></p>

<p><hr width=50></p><p>&nbsp;</p>
<table>
';

    # Block 3: Display bounty table
    $str = '';  # REINITIALIZE for mod_perl

    $str .= "<p><table class='mytable'><tr><th>Requesting Sheriff</th><th>Outlaw Node</th><th>Details of the Crime</th><th>GP Reward (if any)</th></tr>";

    my $REQ = getVars(getNode('bounty order','setting'));
    my $OUT = getVars(getNode('outlaws', 'setting'));
    my $REW = getVars(getNode('bounties', 'setting'));
    my $COM = getVars(getNode('bounty comments', 'setting'));
    my $MAX = getVars(getNode('bounty number', 'setting'));

    my $bountyTot = 0;
    my $outlawStr = undef;
    my $requester = undef;
    my $reward = undef;
    my $details = undef;

    my $numBounties = 1;

    while ($numBounties < $$MAX{1}) {
        $numBounties++;
    }
    $bountyTot = $numBounties;

    for(my $i = $bountyTot; $i >= 1; $i--) {
        if (exists $$REQ{$i}) {
            $requester = $$REQ{$i};
            $outlawStr = $$OUT{$requester};
            $reward = $$REW{$requester};
            $details = $$COM{$requester};
            $str .= "<tr><TD>[$requester]</TD><TD>$outlawStr</TD><TD>$details</TD><TD>$reward</TD></tr>";
        }
    }

    $text .= $str;

    # Static HTML: Close table and start Justice Served section
    $text .= '</table>

<p>&nbsp;<br></p>

<h1>Justice Served!</h1>

<ul>
';

    # Block 4: Display justice served list
    $str = '';  # REINITIALIZE for mod_perl

    my $JUST = getVars(getNode('justice served','setting'));
    my $NUM = getVars(getNode('bounty number','setting'));

    my $justiceTot = $$NUM{"justice"};
    my $justice = undef;

    for(my $i = $justiceTot; $i > 0; $i--) {
        if (exists $$JUST{$i}) {
            $justice = $$JUST{$i};
            $str .= "<li>$justice</li>";
        }
    }

    $text .= $str;

    # Static HTML: Close list
    $text .= '</ul>
';

    # Block 5: Include Justice Served oppressor_document if it exists
    my $justiceDoc = getNode("Justice Served", "oppressor_document");
    if (defined $justiceDoc) {
        $text .= $$justiceDoc{doctext};
    }

    return $text;
}


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

# REMOVED (2025-12-10): my_big_writeup_list delegation (286 lines)
# Now handled by Everything::Page::my_big_writeup_list
# React component provides comprehensive writeup listing with sorting

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

# noding_speedometer - REMOVED (migrated to Everything::Page::noding_speedometer + React)

# everything_publication_directory - REMOVED (migrated to Everything::Page::everything_publication_directory + React)

# your_filled_nodeshells - REMOVED (migrated to Everything::Page::your_filled_nodeshells + React)
# nodes_of_the_year - REMOVED (migrated to Everything::Page::nodes_of_the_year + React)

sub usergroup_discussions
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    # March 2009: Most of the code here is Swap hacking on top of N-Wing's
    # and kthejoker's code.

    $text = '<p align="right"><small>See also [usergroup message archive]</small></p>' . "\n";

    return $text
        . "If you logged in, you would be able to strike up long-winded conversations with [usergroup lineup|your buddies]"
        if $APP->isGuest($USER);

    # N-Wing loves sticking this function all over the place -- Swap
    local *in_an_array = sub {
        my $needle = shift;
        my @haystack = @_;

        for (@haystack)
        {
            return 1 if $_ eq $needle;
        }
        return 0;
    };

    my $uid = getId($USER);

    my $csr = $DB->sqlSelectMany( "node_id", "node",
        "type_nodetype=16 ORDER BY node_id" );
    my @ug_ids = ();
    while ( my $row = $csr->fetchrow_hashref )
    {
        push @ug_ids, $row->{node_id};
    }

    # A few usergroups are not really usergroups that have discussions.
    # For now, that's %%, and e2gods. Don't show those.
    my @exclude_ug_ids = qw(829913 1175790);

    my @thisnoder_ug_ids = ();
    foreach my $ug_id (@ug_ids)
    {
        my $ids = getNodeById($ug_id)->{group};
        if ( in_an_array( $uid, @$ids ) )
        {
            push @thisnoder_ug_ids, $ug_id
                unless in_an_array( $ug_id, @exclude_ug_ids );

            if ( $ug_id == 114 )
            {    # If an admin, also an ed
                push @thisnoder_ug_ids, 923653;
            }
        }
    }

    return $text
        . "You have no usergroups! Find [usergroup lineup|some friends first], and then start a discussion with them."
        unless @thisnoder_ug_ids;

    my $show_ug = int($query->param('show_ug') || 0);

    # Is this table here kosher? Does CSS have a better way to do this?
    my $tablecols = 8;
    $text .=
        "Choose the usergroup to filter by: <br/> <center><table cellspacing=\"7\">\n";

    my $count = 1;
    foreach my $ug_id (@thisnoder_ug_ids)
    {
        $text .= "<tr>" if ( $count % $tablecols == 1 );
        my $ug = getNodeById($ug_id);
        $text .= "<td>";
        $text .= "<b>" if $ug_id == $show_ug;
        $text .= "<center>"
            . linkNode( $NODE, "$$ug{title}", { show_ug => $ug_id } )
            . "</center>";
        $text .= "</b>" if $ug_id == $show_ug;
        $text .= "</td>";
        $text .= "</tr>\n" if $count % $tablecols == 0;
        $count++;
    }

    while ( $count % $tablecols != 0 )
    {    # I'm a good boy, and I tidy up the table.
        $text .= "<td>&nbsp;</td>";
        $count++;
    }
    $text .= "</tr> </table></center> <br/>";

    # As elsewhere in e2, "nothing" really means "everything".
    $text .= "<center>Or ";
    $text .= "<b>" if $show_ug == 0;
    $text .= linkNode( $NODE,
        "show discussions from all usergroups.",
        { show_ug => 0 } ) . "</center><br/>\n";
    $text .= "</b>" if $show_ug == 0;

    # Check for manual manipulations of query string, for security.
    if ( $show_ug && !in_an_array( $show_ug, @thisnoder_ug_ids ) )
    {
        $text .= "You are not a member of the selected usergroup.<br/>";
        return $text;
    }

    my $wherestr = '';
    if ($show_ug)
    {
        $wherestr .= "restricted=$show_ug";
    }
    else
    {    # No usergroup requested, show all available.
        my $appendstr = "(@thisnoder_ug_ids)";
        $appendstr =~ s/ /, /g;
        $wherestr .= "restricted in " . $appendstr;
    }

    $csr = $DB->sqlSelectMany( "root_debatecomment", "debatecomment",
        $wherestr, "GROUP BY root_debatecomment" );

    my @types = qw( debate );
    foreach (@types)
    {
        $_ = getId( getType($_) );
    }

    my @nodes = ();
    while ( my $temprow = $csr->fetchrow_hashref )
    {
        my $N = getNodeById( $temprow->{root_debatecomment} );
        next unless $N;
        my $latest = getNodeById(
            $DB->sqlSelect(
                "MAX(debatecomment_id)", "debatecomment",
                "root_debatecomment=$$N{node_id}"
            )
        );
        next unless $latest;
        my $latesttime = $$latest{'createtime'};
        $latesttime = $APP->convertDateToEpoch($latesttime);
        push @nodes, [ $N, $latest, $latesttime ];
    }
    @nodes = sort { my ( @a, @b ); return @$b[2] <=> @$a[2]; } @nodes;

    # Limit the number of nodes to the pagination requirements
    my $offset     = $query->param("offset") || 0;
    my $limit      = 50;
    my $totalnodes = scalar(@nodes);
    my $nodesleft  = $totalnodes - $offset;
    my $thispage   = ( $limit < $nodesleft ? $limit : $nodesleft );

    @nodes = @nodes[ $offset .. $offset + $thispage - 1 ];

    if ( not @nodes )
    {
        $text .= "<p align=\"center\">There are no discussions!</p>";
    }
    else
    {
        $text .= '<style type="text/css">
                        <!--
            th {
              text-align: left;
            }
            -->
            </style>

            </p>

            <p>
            <table>
            <tr bgcolor="#dddddd">
            <th class="oddrow" width="200" colspan="2">title</th>
            <th class="oddrow" width="80">usergroup</th>
            <th class="oddrow" width="80">author</th>
            <th class="oddrow" width="50">replies</th>
            <th class="oddrow" width="30">new</th>
            <th class="oddrow" width="100">last updated</td>
            <!--th width="100">type</th-->
            </tr>
            ';
        foreach my $nodestuff (@nodes)
        {
            my $n      = @$nodestuff[0];
            my ($user) = getNodeById( $$n{author_user} );
            my $ug     = $$n{restricted};

            my $latest = @$nodestuff[1];
            my $latestreadtime = $DB->sqlSelect(
                "dateread", "lastreaddebate",
                "user_id=$uid and debateroot_id=$$n{node_id}"
            );

            my $latesttime = $latest->{createtime};
            $latesttime ||= "<em>(none)</em>";

            my $latesttime_e = @$nodestuff[2];
            my $latestreadtime_e = undef;
            $latestreadtime_e = $APP->convertDateToEpoch($latestreadtime)
                if $latestreadtime;

            my $unread = ( $latestreadtime_e < $latesttime_e );

            my $replycount = $DB->sqlSelect( "COUNT(*)", "debatecomment",
                "root_debatecomment=$$n{node_id}" );

            # Don't count the root node itself
            $replycount--;

            $text .=
                  "<tr><td>"
                . linkNode( $n, $$n{title}, { lastnode_id => 0 } )
                . "</td><td><small>("
                . linkNode( $n, "compact",
                { lastnode_id => 0, displaytype => "compact" } )
                . ")</small></td><td><small>"
                . linkNode( $ug, 0, { lastnode_id => 0 } )
                . "</small></td><td>"
                . linkNode( $$user{"node_id"}, 0, { lastnode_id => 0 } )
                . "</td><td>"
                . $replycount
                . "</td><td>";
            $text .= ( $unread ? '&times;' : '&nbsp;' );
            $text .=
                  "</td><td>"
                . $latesttime
                . "</td>"
                . "</tr>\n";
        }
        $text .= "</table>\n";
        $text .=
            "<p align=\"right\">There are $totalnodes discussions total</p>";

        # Show pagination links if necessary
        my $numnodes = scalar(@nodes);
        if ( $offset > 0 || $numnodes == $limit )
        {
            $text .= '<p align="right">';
            if ( $offset > 0 )
            {
                my ( $start, $end );
                $end   = $offset;
                $start = $offset - $limit + 1;
                $text .= linkNode( $NODE, "prev $start &ndash; $end",
                    { show_ug => $show_ug, offset => $offset - $limit } );
                $text .= "<br />";
            }

            my $bot = $offset + 1;
            my $top = $offset + $numnodes;
            $text .= "Now: $bot &ndash; $top <br/>";

            # Yeah, ok, there's one pathological case this doesn't really
            # handle, but I think users can deal with a blank page if they
            # happen to have exactly mod($limit) discussions.
            if ( $numnodes == $limit )
            {
                my ( $start, $end );
                $start = $offset + $limit + 1;
                $end   = $offset + 2 * $limit;
                $text .= linkNode( $NODE, "next $start &ndash; $end",
                    { show_ug => $show_ug, offset => $offset + $limit } );
                $text .= "<br />";
            }
            $text .= "</p>\n";
        }
    }

    $text .= '
         <hr />
         <b>Choose a title for a new discussion:</b><br />
         <form method="post">
         <input type="hidden" name="op" value="new">
         <input type="hidden" name="type" value="debate">
         <input type="hidden" name="displaytype" value="edit">
         <input type="hidden" name="debate_parent_debatecomment" value="0">
         <input type="text" size="50" maxlength="64" name="node"
                value=""><br />';

    my %thisnoder_ug_names = ();
    foreach my $ug_id (@thisnoder_ug_ids)
    {
        my $N = getNodeById($ug_id);
        $thisnoder_ug_names{$ug_id} = $$N{title};
    }

    $text .= "Choose the usegroup it's for: <br />";
    $text .= $query->popup_menu( 'debatecomment_restricted',
        \@thisnoder_ug_ids, $show_ug, \%thisnoder_ug_names );

    $text .= $query->checkbox( "announce_to_ug", "checked", "yup",
        "Announce new discussion to usergroup" );

    $text .= "<br /> <br/>\n";

    $text .= "Write the first discussion post: <br/>";

    $text .= $query->textarea(
        {   name    => "newdebate_text",
            id      => "newdebate_text",
            default => "",
            rows    => 20,
            columns => 80
        }
    );

    $text .= '<input type="submit" name="sexisgood" value="Start new discussion!">';

    $text .= "\n</form>";

    return $text;
}

sub mark_all_discussions_as_read
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $str = '';

    my $uid = $$USER{node_id};
    my $isRoot = $APP->isAdmin($USER);
    my $isCE = $APP->isEditor($USER);

    # Usergroup IDs
    my ($ce_id, $gods_id) = (923653, 114);

    my $doneCE = $query->param("mark_ce_read");
    if (!$doneCE) {
        $str .= "<p>Apply pressure to the hypertext if you want to mark all of
  your old CE debates as read (and the new ones too,
  everything!).</p>";

        $str .= "<p><center>\n";
        $str .= linkNode($NODE, "Mark CE Debates as Read", {"mark_ce_read" => 1}) . "\n";
        $str .= "</center></p>\n";
    }
    else {
        my $csr = $DB->sqlSelectMany("root_debatecomment", "debatecomment",
                                     "restricted=$ce_id",
                                     "GROUP BY root_debatecomment");
        while (my $row = $csr->fetchrow_hashref) {
            my $debate = $row->{root_debatecomment};
            my $lastread = $DB->sqlSelect("dateread",
                                          "lastreaddebate",
                                          "user_id=$uid and
                                           debateroot_id=$debate");
            if ($lastread) {
                $DB->sqlUpdate("lastreaddebate",
                               {-dateread => "NOW()"},
                               "user_id=$uid and
                                debateroot_id=$debate");
            }
            else {
                $DB->sqlInsert("lastreaddebate",
                               {"user_id" => $uid,
                                "debateroot_id" => $debate,
                                -dateread => "NOW()"}
                              );
            }
        }
        $str .= 'It is done. All of your CE debates have been marked
           as read. Hopefully there\'s never a reason to do this
           again. <br />';
    }

    my $doneRoot = $query->param("mark_admin_read");
    if (!$doneRoot && $isRoot) {
        $str .= "<p>It appears you are like a god amongst men. You may do the same but to your admin debates.</p>";

        $str .= "<p><center>\n";
        $str .= linkNode($NODE, "Mark Admin Debates as Read", {"mark_admin_read" => 1}) . "\n";
        $str .= "</center></p>\n";
    }
    elsif ($doneRoot && $isRoot) {
        my $csr = $DB->sqlSelectMany("root_debatecomment", "debatecomment",
                                     "restricted=$gods_id",
                                     "GROUP BY root_debatecomment");
        while (my $row = $csr->fetchrow_hashref) {
            my $debate = $row->{root_debatecomment};
            my $lastread = $DB->sqlSelect("dateread",
                                          "lastreaddebate",
                                          "user_id=$uid and
                                           debateroot_id=$debate");
            if ($lastread) {
                $DB->sqlUpdate("lastreaddebate",
                               {-dateread => "NOW()"},
                               "user_id=$uid and
                                debateroot_id=$debate");
            }
            else {
                $DB->sqlInsert("lastreaddebate",
                               {"user_id" => $uid,
                                "debateroot_id" => $debate,
                                -dateread => "NOW()"}
                              );
            }
        }
        $str .= 'It is done. All of your admin debates have been marked
           as read. Hopefully there\'s never a reason to do this
           again. <br />';
    }

    return $str;
}

sub guest_front_page {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    # Ensure guest users have nodelets configured for proper e2 config generation
    # This ensures buildNodeInfoStructure populates nodelet data correctly
    unless ($VARS->{nodelets}) {
        my $guest_nodelets = $Everything::CONF->guest_nodelets;
        if ($guest_nodelets && ref($guest_nodelets) eq 'ARRAY' && @$guest_nodelets) {
            $VARS->{nodelets} = join(',', @$guest_nodelets);
        }
    }

    # Disable link parsing
    $PAGELOAD->{noparsecodelinks} = 1;

    my $html = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">

<html lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
';

    # Add meta description tag
    $html .= htmlcode('metadescriptiontag');

    $html .= '
<title>Everything2</title>
<link rel="stylesheet" id="basesheet" type="text/css" href="' . htmlcode('linkStylesheet', 'basesheet') . '" media="all">
';

    # Add zensheet (user style)
    $html .= '<link rel="stylesheet" id="zensheet" type="text/css" href="'
           . htmlcode('linkStylesheet', $$VARS{userstyle} || $Everything::CONF->default_style, 'serve')
           . '" media="screen,tv,projection">';

    # Add custom style if present
    if (exists($$VARS{customstyle}) && defined($$VARS{customstyle})) {
        $html .= '
    <style type="text/css">
' . $APP->htmlScreen($$VARS{customstyle}) . '
    </style>';
    }

    $html .= '
    <link rel="stylesheet" id="printsheet" type="text/css" href="' . htmlcode('linkStylesheet', 'print') . '" media="print">
    <link rel="icon" href="' . $APP->asset_uri("static/favicon.ico") . '" type="image/vnd.microsoft.icon">
    <!--[if lt IE 8]><link rel="shortcut icon" href="' . $APP->asset_uri("static/favicon.ico") . '" type="image/x-icon"><![endif]-->
    <link rel="alternate" type="application/atom+xml" title="Everything2 New Writeups" href="/node/ticker/New+Writeups+Atom+Feed">
    <script async src="https://www.googletagmanager.com/gtag/js?id=G-2GBBBF9ZDK"></script>
</head>



<body class="fullpage" id="guestfrontpage">
    <div id="header">
           <div id="e2logo"><a href="/title/About+Everything2">Everything<span id="e2logo2">2</span></a></div>
';

    $html .= parseLinks("<h2 id='tagline'>[Everything2 Help|Read with us. Write for us.]</h2>");

    $html .= '
    </div>
<div id=\'wrapper\'>
    <div id=\'mainbody\'>

';

    # Build the main content
    my $zenStr;

    if ($APP->isGuest($USER)) {
        $PAGELOAD->{pagenodelets} = getNode('Sign in', 'nodelet')->{node_id};
        $PAGELOAD->{pagenodelets} .= ',' . getNode('Recommended Reading', 'nodelet')->{node_id};
        $PAGELOAD->{pagenodelets} .= ',' . getNode('New Writeups', 'nodelet')->{node_id};
    }

    $zenStr .= "<div id='welcome_message'>";
    my @wit = (
        " Defying definition since 1999",
        " Literary Karaoke",
        " Writing everything about everything.",
        " E2, Brute?",
        " Our fiction is more entertaining than Wikipedia's.",
        " You will never find a more wretched hive of ponies and buttercups.",
        " Please try to make more sense than our blurbs.",
        " Words arranged in interesting ways",
        " Remove lid. Add water to fill line. Replace lid. Microwave for 1 1/2 minutes. Let cool for 3 minutes.",
        " Welcome to the rebirth of your desire to write.",
        " Don't know where this \"writers' site\" crap came from but it sure as hell isn't in the prospectus. ",
        " Read, write, enjoy.",
        " Everything2.com has baked you a pie! (Do not eat it.)"
    );

    $zenStr .= "            <form action='/' method='GET' id='searchform'>
                <input type='text' placeholder='Search' name='node' id='searchfield'>
                <button type='submit' id='search'>Search</button>
            </form>";
    $zenStr .= "<h3 id='wit'>" . $wit[int(rand(@wit))] . "</h3></div>";

    $zenStr .= '
     <div id="bestnew">
        <h3 id="bestnew_title">[Cool Archive|The Best of The Week]</h3>
        ' . htmlcode('frontpage_altcontent') . '
      </div>';

    $zenStr .= '
  <div id="frontpage_news">
        <h2 id="frontpage_news_title">[News for Noders. Stuff that matters.|News for Noders]</h2>
   ' . htmlcode('frontpage_news') . '</div>';

    $html .= parseLinks($zenStr);

    # Add sidebar and footer
    $html .= '
</div>
<div id=\'sidebar\'';

    $html .= ' class="pagenodelets"' if $PAGELOAD->{pagenodelets};

    $html .= '>
<div id="e2-react-root"></div>
</div>

</div>
<div id=\'footer\'>
';

    $html .= htmlcode('zenFooter');

    $html .= '
</div>
';

    $html .= htmlcode('static javascript');

    $html .= '
</body>
</html>';

    return $html;
}

# The Catwalk (superdoc)
# Browser for all stylesheets/themes on E2
# Allows sorting, filtering by author, and testing themes
sub the_catwalk
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    # Guest users get simple message
    return "This page will allow you to customize your view of the site if you sign up for an account."
        if ( $APP->isGuest($USER) );

    my $str            = undef;
    my $nodeType       = 1854352;    # Stylesheet nodetype
    my $selectionTypeID = undef;
    my $sqlSort        = undef;
    my $sqlFilterUser  = undef;
    my $plainTextFilter = undef;
    my $total          = undef;
    my $sth            = undef;
    my $num            = 100;
    my $listedItems    = undef;
    my $next           = undef;
    my $queryText      = undef;
    my $numCurFound    = 0;
    my $aID            = undef;
    my $nextprev       = undef;
    my $remainder      = undef;

    # Sort options for combo box
    my $choicelist = [
        '0',        '(no sorting)',
        'nameA',    'title, ascending (ABC)',
        'nameD',    'title, descending (ZYX)',
        'createA',  'create time, ascending (oldest first)',
        'createD',  'create time, descending (newest first)',
    ];
    my $opt = 'sort order: ';
    $opt .= htmlcode( 'varsComboBox', 'ListNodesOfType_Sort', 0, @$choicelist );

    $opt .= 'only show things ('
        . $query->checkbox( 'filter_user_not', 0, 1, 'not' )
        . ') written by '
        . $query->textfield('filter_user')
        . '<br>';

    # Clear custom style if requested
    if ( defined( $query->param('clearVandalism') ) ) {
        delete( $$VARS{customstyle} );
    }

    $str = '';

    # Show current user's stylesheet
    if ( length( $$VARS{userstyle} ) ) {
        $str .= "\n<p>What's your style? Currently " . linkNode( $$VARS{userstyle} ) . ".</p>";
    }
    $str .= "\n<p>A selection of popular stylesheets can be found at [Theme Nirvana]; below is a list of every stylesheet ever submitted here.</p>";

    # Show customization options
    if ( length( $$VARS{customstyle} ) ) {
        $str .= '<p>Note that you have customised your style using the [style defacer], which is going to affect the formatting of any stylesheet you choose. '
            . linkNode( $NODE, 'Click here to clear that out', { clearVandalism => 'true' } )
            . ' if that\'s not what you want. If you want to create a whole new stylesheet, visit [the draughty atelier].</p>';
    }
    else {
        $str .= "<p>You can customise your stylesheet at the [style defacer] or, if you're feeling brave, create a whole new stylesheet at [the draughty atelier].</p>";
    }

    # Form for filtering/sorting
    $str .= '
<form method="POST">
<input type="hidden" name="node_id" value="' . $NODE->{node_id} . '" />
';
    $str .= $opt;
    $str .= $query->submit( 'fetch', 'Fetch!' ) . '
</form>';

    $selectionTypeID = $VARS->{ListNodesOfType_Type};

    # Helper function to force 0 or 1 from CGI parameter
    my $cgiBool = sub {
        my $val = $query->param( $_[0] );
        return ( defined $val && $val eq '1' ) ? 1 : 0;
    };

    # Mapping of unsafe VARS sort data into safe SQL
    my %mapVARStoSQL = (
        '0'       => '',
        'nameA'   => 'title ASC',
        'nameD'   => 'title DESC',
        'authorA' => 'author_user ASC',
        'authorD' => 'author_user DESC',
        'createA' => 'createtime ASC',
        'createD' => 'createtime DESC',
    );
    my $sort_key = $VARS->{ListNodesOfType_Sort} || '0';
    $sqlSort = $mapVARStoSQL{ $sort_key } || '';

    # Handle user filtering
    my $filterUserNot = $cgiBool->('filter_user_not');
    my $filterUser    = ( defined $query->param('filter_user') ) ? $query->param('filter_user') : undef;
    if ( defined $filterUser ) {
        $filterUser = getNode( $filterUser, 'user' ) || getNode( $filterUser, 'usergroup' ) || undef;
    }

    $sqlFilterUser  = '';
    $plainTextFilter = '';
    if ( defined $filterUser ) {
        $sqlFilterUser = ' AND author_user' . ( $filterUserNot ? '!=' : '=' ) . getId($filterUser);
        $plainTextFilter .= ( $filterUserNot ? ' not' : '' ) . ' created by ' . linkNode( $filterUser, 0, { lastnode_id => 0 } );
    }

    # Get total count
    $sth = $DB->{dbh}->prepare( "SELECT COUNT(*) FROM node WHERE type_nodetype='$nodeType'" . $sqlFilterUser );
    $sth->execute();
    ($total) = $sth->fetchrow;
    $str .= $plainTextFilter if length($plainTextFilter);

    # Get paginated list
    $listedItems = '';
    $next        = $query->param('next') || '0';
    $queryText   = "SELECT node_id, title, author_user, createtime FROM node WHERE type_nodetype = '$nodeType'";
    $queryText .= $sqlFilterUser if length($sqlFilterUser);
    $queryText .= ' ORDER BY ' . $sqlSort if length($sqlSort);
    $queryText .= " LIMIT $next, $num";

    $sth = $DB->{dbh}->prepare($queryText);
    $sth->execute();
    $numCurFound = 0;
    while ( my $item = $sth->fetchrow_arrayref ) {
        ++$numCurFound;
        $listedItems .= '<tr>';
        $aID = $$item[2];

        # Show edit link if admin or user viewing page created node
        $listedItems .= '<td>' . linkNode( @$item[ 0, 1 ], { lastnode_id => 0 } ) . '</td>';
        $listedItems .= '<td>' . linkNode( $aID, 0, { lastnode_id => 0 } ) . '</td>';
        my $createTime = @$item[3];
        $listedItems .= '<td>' . htmlcode( 'parsetimestamp', $createTime . ',1' ) . '</td><td>' . htmlcode( 'timesince', $createTime . ',1,100' ) . '</td>';
        $listedItems .= '<td>'
            . (
            $APP->isGuest($USER)
            ? '&nbsp;'
            : '&#91;&nbsp;<a href="/?displaytype=choosetheme&theme='
                . $$item[0]
                . '&noscript=1"
             onfocus="this.href = this.href.replace( \'&noscript=1\' , \'\' ) ;">test</a>&nbsp;]'
            ) . '</td>';
        $listedItems .= "</tr>\n";
    }
    $str .= ' (Showing items ' . ( $next + 1 ) . ' to ' . ( $next + $numCurFound ) . '.)' if $total;
    $str .= '</p><p><table border="0">
<tr><th>title</th><th>author</th><th>created</th><th>age</th><th>&nbsp;</th></tr>
'
        . $listedItems . '
</table></p>
';
    return $str if ( $total < $num );

    # Helper function to generate pagination links
    my $jumpLinkGen = sub {
        my ( $startNum, $disp ) = @_;
        my $opts = {
            'node_id' => $$NODE{node_id},
            'fetch'   => 1,
            'next'    => $startNum,
        };
        if ( defined $filterUser ) {
            $$opts{filter_user}     = $$filterUser{title};
            $$opts{filter_user_not} = $filterUserNot;
        }
        return '<a href=' . urlGen($opts) . '>' . $disp . '</a>';
    };

    $nextprev = '';
    $remainder = $total - ( $next + $num );
    if ( $next > 0 ) {
        $nextprev .= $jumpLinkGen->( $next - $num, 'previous ' . $num ) . "<br />\n";
    }
    if ( $remainder < $num and $remainder > 0 ) {
        $nextprev .= $jumpLinkGen->( $next + $num, 'next ' . $remainder ) . "\n";
    }
    elsif ( $remainder > 0 ) {
        $nextprev .= $jumpLinkGen->( $next + $num, 'next ' . $num ) . "<br />\n";
    }
    $str .= qq|<p align="right">$nextprev</p>| if length($nextprev);

    return $str;
}

sub usergroup_message_archive
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $str      = undef;
    my $uID      = undef;
    my $isRoot   = undef;
    my $NL       = undef;
    my $BRN      = undef;
    my $UG       = undef;
    my $ugID     = undef;
    my $MSG      = undef;
    my $numMsg   = undef;
    my $LIMITS   = undef;
    my $MAXSHOW  = undef;
    my $showStart = undef;
    my $startDefault = undef;
    my $csr      = undef;
    my $numShow  = undef;
    my $TD       = undef;
    my $msgCount = undef;
    my $a        = undef;
    my $name     = undef;
    my $jsName   = undef;
    my $t        = undef;
    my $text     = undef;
    my $groupLink = undef;
    my @G        = ();
    my @MSGS     = ();
    my @jumps    = ();

    # Initial HTML
    $str = '<p align="right"><small>See also ' . linkNode( getNode( 'Usergroup discussions', 'superdoc' ) ) . '</small></p>

<p>If you are a member of one of these groups, you can view messages sent to the group.</p>

<p>';

    $uID    = getId($USER);
    $isRoot = $APP->isAdmin($USER);

    return $str . 'You must login to use this feature.</p>' if $APP->isGuest($USER);

    if ( $APP->isAdmin($USER) ) {
        $str .= 'You can edit the usergroups that have messages archived at <a href='
            . urlGen( { 'node' => 'usergroup message archive manager', 'type' => 'restricted_superdoc' } )
            . '>usergroup message archive manager</a>.</p><p>';
    }

    $NL  = "\n";
    $BRN = "<br />\n";

    # Groups that archive
    $str .= 'To view messages sent to a group, choose one of the following groups. You can only see the messages if the group has the feature enabled, and you\'re a member of the group.'
        . $BRN
        . 'choose from: ';

    my $ks = $APP->getNodesWithParameter('allow_message_archive');

    foreach my $ug (@$ks) {
        $ug = getNodeById($ug);
        next unless $ug;
        push @G, linkNode( $NODE, $ug->{title}, { viewgroup => $ug->{title} } );
    }

    $str .= join( ', ', @G ) . '</p><p>' . $NL;

    # Find usergroup we're showing
    $UG = $query->param('viewgroup');
    return $str . '</p>' unless length($UG);
    $UG = getNode( $UG, 'usergroup' );
    return $str . 'There is no such usergroup.</p>' unless $UG;
    $str .= $query->hidden( 'viewgroup', $UG->{title} );    # so form works
    $groupLink = linkNode( $UG, 0, { lastnode_id => 0 } );
    return $str . 'You aren\'t a member of ' . $groupLink . ', so you can\'t view the group\'s messages.</p>'
        unless Everything::isApproved( $USER, $UG );
    $str .= 'Viewing messages for group ' . $groupLink . ': ' . $BRN;
    $ugID = getId($UG);
    return $str . 'Ack! Unable to find group ID!</p>' unless $ugID;

    # Archiving allowed?
    return $str . 'This group doesn\'t archive messages.</p>' unless $APP->getParameter( $UG, "allow_message_archive" );

    # Misc. variable/database setup
    my $userid = getId($USER);
    $LIMITS = 'for_user=' . $ugID . ' AND for_usergroup=' . $ugID;

    # Copy selected messages to self
    $str .= htmlcode( 'varcheckboxinverse', 'ugma_resettime,Keep original send date' )
        . ' (instead of using "now" time)'
        . $BRN;
    $numMsg = 0;    # using now to keep track of number of msgs copied
    foreach ( $query->param ) {
        if ( $_ =~ /^cpgroupmsg_(\d+)$/ ) {
            $MSG = $DB->sqlSelectHashref( '*', 'message', 'message_id=' . $1 );
            next unless $MSG;

            # already checked if user is in group, so only need to make
            # sure message is a group-archived one
            next unless ( $MSG->{for_user} == $ugID ) && ( $MSG->{for_usergroup} == $ugID );
            ++$numMsg;
            delete $MSG->{message_id};
            delete $MSG->{tstamp} if $VARS->{ugma_resettime};
            $MSG->{for_user} = $userid;
            $DB->sqlInsert( 'message', $MSG );
        }
    }
    $str .= '(Copied ' . $numMsg . ' group message' . ( $numMsg == 1 ? '' : 's' ) . ' to self.)' . $BRN if $numMsg;

    # Find range of messages to show
    ($numMsg) = $DB->sqlSelect( 'COUNT(*)', 'message', $LIMITS );
    $MAXSHOW      = $query->param('max_show') || 25;    # maximum number of messages to show at a time
    $startDefault = $numMsg - $MAXSHOW;                 # default to show most recent messages
    $startDefault = 0 if $startDefault < 0;
    $showStart = defined $query->param('startnum') ? $query->param('startnum') : $startDefault;
    if ( $showStart =~ /^(\d+)$/ ) {
        $showStart = $1;
        $showStart = $startDefault if $showStart > $startDefault;
    } else {
        $showStart = $startDefault;
    }
    $str .= $query->hidden( 'startnum', $showStart );    # so form works

    # Get messages
    $csr = $DB->sqlSelectMany( '*', 'message', $LIMITS, 'ORDER BY tstamp,message_id LIMIT ' . $showStart . ',' . $MAXSHOW );
    return $str . 'Ack! Unable to get messages!</p>' unless $csr;
    while ( my $msg_row = $csr->fetchrow_hashref ) {
        push( @MSGS, $msg_row );
    }
    $csr->finish();

    $numShow = scalar(@MSGS);
    $str .= 'Showing '
        . $numShow
        . ' message'
        . ( $numShow == 1 ? '' : 's' )
        . ' (number '
        . ( $showStart + 1 ) . ' to '
        . ( $showStart + $numShow )
        . ') out of a total of '
        . $numMsg . '.'
        . $BRN
        if $numShow;

    # Show messages
    $str .= '<table border="0">' . $NL . '<tr><th># cp</th><th>author</th><th>time</th><th>message</th>' . $NL;
    $TD       = '<td valign="top">';
    $msgCount = $showStart;
    foreach my $MSG (@MSGS) {

        $str .= '<tr>';

        # message number / copy to self
        $str .= $TD
            . '<small><small>'
            . ++$msgCount
            . '</small></small><input type="checkbox" name="cpgroupmsg_'
            . $MSG->{message_id}
            . '" value="copy" /></td>';

        # name
        my $author_node = $MSG->{author_user} || 0;
        if ($author_node) { $author_node = getNodeById($author_node) || 0; }
        $name = $author_node ? $author_node->{title} : '';
        $name =~ tr/ /_/;
        $name   = encodeHTML($name);
        $jsName = $name;
        $jsName =~ s/'/\\'/g;
        $str .= $TD . '<small>';
        $str .= '(<a href="javascript:replyToCB(\'' . $jsName . '\'">r</a>) ' if $VARS->{showmessages_replylink};
        $str .= $author_node ? linkNode( $author_node, $name, { lastnode_id => 0 } ) : '?';
        $str .= '</small></td>';

        # date/time
        my $timestamp = $MSG->{tstamp};
        $str .= $TD . '<small style="font-family: Andale Mono, sans-serif;">';
        $str .= $timestamp;
        $str .= '</small></td>';

        # message
        $text = $MSG->{msgtext};
        $text =~ s/</&lt;/g;
        $text =~ s/>/&gt;/g;
        $text =~ s/\s+\\n\s+/<br \/>/g;
        $text = parseLinks($text);
        $text =~ s/\[/&#91;/g;    # can't have [ in final text (even in links), because everything is parsed for links *again*, which can cause bad display
        $str .= $TD . $text . '</td>';

        $str .= '</tr>' . $NL;
    }
    $str .= '<tr><td colspan="5">checking the box in the "cp" column will <strong>c</strong>o<strong>p</strong>y the message&#91;s&#93; to your private message box</td></tr>'
        . $NL
        . '</table>'
        . $NL;

    # Link to first/prev/next/last messages
    if ( $numMsg > scalar(@MSGS) ) {

        # generates link to this node, starting at the given message number
        # arguments: ('link display','starting number')
        my $genLink = sub {
            my ( $link_text, $sn ) = @_;
            $link_text ||= 'start at ' . ( $sn + 1 );
            $sn = 0 if $sn < 0;
            return linkNode( $NODE, $link_text, { viewgroup => $UG->{title}, startnum => $sn, lastnode_id => 0 } );
        };

        my $s      = undef;
        my $limitL = undef;
        my $limitU = undef;

        $s = 'first ' . $MAXSHOW;
        if ( $showStart != 0 ) {
            $limitU = $MAXSHOW < $numMsg ? $MAXSHOW : $numMsg;
            $s .= ' (1-' . $limitU . ')';
            push( @jumps, $genLink->( $s, 0 ) );
        } else {
            push( @jumps, $s );
        }

        $s = 'previous';
        if ( $showStart > 0 ) {
            $limitL = $showStart - $MAXSHOW;
            $limitL = 1 if $limitL < 1;
            $limitU = $limitL + $MAXSHOW;
            $limitU = $numMsg if $limitU > $numMsg;
            $s .= ' (' . $limitL . '-' . ( $limitU - 1 ) . ')';
            push( @jumps, $genLink->( $s, $showStart - $MAXSHOW ) );
        } else {
            push( @jumps, $s );
        }

        push( @jumps, '<strong>current (' . ( $showStart + 1 ) . '-' . ( $showStart + $numShow ) . ')</strong>' );

        if ( $showStart < $startDefault ) {
            $limitU = $showStart + $MAXSHOW + $MAXSHOW;
            $limitU = $numMsg if $limitU > $numMsg;
            $limitL = $limitU - $MAXSHOW + 1;
            $limitL = 1 if $limitL < 1;
            $limitL = $startDefault + 1 if $limitL > ( $startDefault + 1 );
            $s = 'next (' . $limitL . '-' . $limitU . ')';
            push( @jumps, $genLink->( $s, $limitL - 1 ) );
        } else {
            push( @jumps, 'next' );
        }

        $s = 'last ' . $MAXSHOW;
        if ( $showStart < $startDefault ) {
            $s .= ' (' . ( $startDefault + 1 ) . '-' . $numMsg . ')';
            push( @jumps, $genLink->( $s, $startDefault ) );
        } else {
            push( @jumps, $s );
        }

        $str .= '&#91; ' . join( ' &#93; &nbsp; &#91; ', @jumps ) . ' &#93;' . $BRN;
    }

    $str = htmlcode( 'openform', '' ) . $str . $BRN . htmlcode( 'closeform', '' );

    return $str;
}

sub welcome_to_everything
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $zenStr = undef;

    $zenStr = '<div id="welcome_message">Everything2 is a collection of user-submitted writings about
    more or less everything. Spend some time looking around and reading, or '
        . linkNodeTitle('Everything2 Help|learn how to contribute')
        . '.</div>';

    $zenStr .= '<div id="loglinks">
<h3>Logs</h3>
' . htmlcode('daylog') . '
</div>';

    $zenStr .= '<div id="cooluserpicks">
<h3>Cool User Picks!</h3>
' . htmlcode('frontpage_cooluserpicks') . '</div>';

    $zenStr .= '
    <div id="staff_picks">
    <h3>Staff Picks</h3>
' . htmlcode('frontpage_staffpicks')
        . '</div>'
        unless ( $APP->isGuest($USER) );

    $zenStr .= '
     <div id="creamofthecool">
        <h3 id="creamofthecool_title">'
        . linkNodeTitle('Cool Archive[superdoc]|Cream of the Cool')
        . '</h3>
        ' . htmlcode('frontpage_creamofthecool') . '
      </div>';

    if ( !$APP->isGuest($USER) ) {
        $zenStr .= '
  <div id="frontpage_news">
        <h2 id="frontpage_news_title">'
            . linkNodeTitle('News for Noders. Stuff that matters.[superdoc]|News for Noders')
            . '</h2>
   ' . htmlcode('frontpage_news') . '</div>';
    }

    return $zenStr;
}

sub short_url_lookup
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    return unless $query;

    my $shortString = $query->param('short_string');
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

sub theme_nirvana {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<p>The following is a list of [stylesheet]s for the [zen theme] in order of popularity. You can find additional zen themes on [The Catwalk].</p>\n";
    my %styles;
    my $n;

    if(defined($query->param('clearVandalism'))) {
        delete($$VARS{customstyle});
    }

    if(length($$VARS{userstyle})) {
        $str .= "\n<p>Your current stylesheet is ".linkNode($$VARS{userstyle}).".</p>";
    }

    if(length($$VARS{customstyle})) {
        $str.='<p>Note that you have customised your style using the [style defacer] or [ekw Shredder], which is going to affect the formatting of any stylesheet you choose. '.linkNode($NODE,'Click here to clear that out',{clearVandalism=>'true'}).' if that\'s not what you want. If you want to create a whole new stylesheet, visit [the draughty atelier].</p>';
    }
    else {
        $str.="<p>You can also customise your stylesheet at the [style defacer] or create a whole new stylesheet at [the draughty atelier].</p>";
    }

    # ============ same code as choose theme view page =============
    # only show themes for "active" users (in this case lastseen within 6 months
    my ($sec,$min,$hour,$mday,$mon,$year) = gmtime(time - 15778800); # 365.25*24*3600/2
    my $cutoffDate = ($year+1900).'-'.($mon+1)."-$mday";
    my $defaultStyle = getNode($Everything::CONF->default_style, "stylesheet")->{node_id};

    my $rows = $DB->sqlSelectMany( 'setting.setting_id,setting.vars' ,
        'setting,user' ,
        "setting.setting_id=user.user_id
            AND user.lasttime>='$cutoffDate'
            AND setting.vars LIKE '%userstyle=%'
            AND setting.vars NOT LIKE '%userstyle=$defaultStyle%'" ) ;

    my $dbrow ;
    while($dbrow = $rows->fetchrow_arrayref)
    {
       $$dbrow[1] =~ m/userstyle=([0-9]+)/;
       if (exists($styles{$1}))
       {
          $styles{$1} = $styles{$1}+1;
       }
       else
       {
          $styles{$1} = 1;
       }
    }

    my @keys = sort {$styles{$b} <=> $styles{$a}} (keys(%styles)) ;
    unshift( @keys , $defaultStyle ) ;
    # ======== end same code ========
    $styles{ $defaultStyle } = '&#91;default]' ;
    $str .= '<table align="center">
       <tr>
       <th>Stylesheet Name</th>
       <th>Author</th>
       <th>Number of Users</th><th>&nbsp;</th>
       </tr>';
    my $ctr = 0;
    foreach (@keys) {
       $n = getNodeById($_);
       next unless $n ;
       $ctr++;

       if ($ctr%2==0)
       {
          $str .= '<tr class="evenrow">';
       }
       else
       {
          $str .= '<tr class="oddrow">';
       }

       $str .= '<td>'.linkNode($n, '', {lastnode_id=>0}).'</td>
            <td style="text-align:center">'.linkNode($$n{author_user}, '', {lastnode_id=>0}).'</td>
            <td style="text-align:right">'.$styles{$_}.'</td>
            <td>'.
            ( $APP->isGuest($USER) ? '&nbsp;' :
                '&#91; <a href="/?displaytype=choosetheme&theme='.$_.'&noscript=1"
                    onfocus="this.href = this.href.replace( \'&noscript=1\' , \'\' ) ;">test</a> ]' ).'
            </td>
          </tr>';
    }
    $str .= '</table>';

    return $str;
}

sub style_defacer {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '';

    $str .= parseLinks("<p>So you're not satisfied with [Theme Nirvana|the beautiful styles lovingly crafted for you by the best designers on E2]? Thought not. I bet you want to change all the colours, add low-res background images and generally [MySpace|MySpacify] it. Well, don't ever say we're not good to you. This form right here will let you add any styles that you want, which will then override those in the theme. If you used to use ekw theme and fear change, then perhaps you'd like to start by using the [ekw shredder], which will attempt to create a custom style based on your old EKW settings.</p><p>You need at least a small amount of knowledge of [CSS] to edit these, but if you start with a Shredded ekw style you should be able to simply edit the colours in that, or otherwise use it as a starting point. One day we may have an easier way to edit this. Perhaps after ascorbic retires.</p>");

    $str .= htmlcode('openform');

    if (defined($query->param('vandalism'))) {
        $$VARS{customstyle} = $query->param('vandalism');
        if (!length($$VARS{customstyle})) {
            delete($$VARS{customstyle});
        }
    }

    $str .= "<textarea id=\"vandalism\" rows='40' name=\"vandalism\">" . $APP->htmlScreen($$VARS{customstyle}) . "</textarea><br />\n";
    $str .= "<input type='submit' name='submit' value='Throw that paint'>\n";
    $str .= "</form>";

    return $str;
}

# REMOVED (2025-12-10): the_killing_floor_ii delegation (102 lines)
# Now handled by Everything::Page::the_killing_floor_ii
# Deprecated editorial tool - preserved for site integrity but no longer functional

sub caja_de_arena {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $gonesince = $query->param('gonesince') || '1 YEAR';
    my $showlength = $query->param('showlength') || 1000;

    my $filter = "doctext != ''";

    $filter .= " AND lasttime < DATE_SUB(NOW(), INTERVAL $gonesince)";
    $filter .= ' AND numwriteups=0' unless $query->param('published');
    $filter .= "doctext LIKE '%[http%'" if $query->param('extlinks');

    return "Spam entries: <br />".htmlcode('show paged content', 'title, user_id AS author_user, doctext', 'node JOIN user on node_id=user_id JOIN document ON node_id=document_id', $filter, 'ORDER BY lasttime DESC LIMIT 10', "author, $showlength, smite", ('smite' => sub {
        my $verify = htmlcode('verifyRequestHash', 'polehash');
        '<hr>'.linkNode(getNode('The Old Hooked Pole', 'restricted_superdoc')
        , 'Smite Spammer'
        , {%$verify
        , confirmop => 'remove'
        , removeauthor => 1
        , author => $_[0]{title}
        , -title => 'detonate this noder, blank their homenode, remove their writeups, blacklist their IP where appropriate'
        , -class => 'action'});
    }
    ));
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

# e2node_reparenter - Migrated to React
# See: Everything::Page::e2node_reparenter
# React component: MagicalWriteupReparenter.js (shared with magical_writeup_reparenter)

sub feed_edb {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '<p>';

    my $UID = getId($USER);
    my $isRoot = $APP->isAdmin($USER);
    return $str . 'You narrowly escape EDB\'s mouth.</p>' unless $isRoot;

    my $t;
    my $m = '';

    if( (defined $query->param('numborgings')) && defined($t=$query->param('numborgings')) && (length($t)!=0) && ($t=~/^(-?\d*)$/)) {

        $t=$1 || 0;
        my $z;
        if($t>0) {
            #borg self
            $z=1;
            $VARS->{numborged}=$t;
            $VARS->{borged}=time;
            $m='Simulating being borged '.$t.' time'.($t==1?'':'s').'.';
        } else {
            #unborg self
            $z=0;
            delete $VARS->{borged};
            if($t==0) {
                $m='Unborged.';
            } else {
                $m='Borg-proof '.(-$t).' time'.($t==-1?'':'s').'.';
            }
        }
        $m .= "<br />\n<a href=" . urlGen({node_id=>$NODE->{node_id}}) . '>EDB still hungry</a>';
        $VARS->{numborged}=$t;
        $DB->sqlUpdate('room',{borgd=>$z},'member_user='.$UID);

    } else {

        $m = 'This is mainly for the 3 of us that need to play with EDB.<br />Er, that doesn\'t quite sound the way I meant it. How about "...want to experiment with EDB".<br />Mmmmm, that isn\'t quite what I meant, either. Lets try: "...want to have EDB eat them".<br />Argh, I give up.<br /><br /><code>numborgings = ( &nbsp;</code>';
        $m .= join(', &nbsp; ',map {linkNode($NODE,'&nbsp;'.$_.'&nbsp;',{numborgings=>$_,lastnode_id=>0})} qw(-100 -10 -2 -1 0 1 2 5 10 25 50 100));
        $m .= '<code>&nbsp;);</code>';

    }

    $str .= 'Your current borged count: '.($VARS->{numborged}||0)."<br /><br />\n".$m;
    $str .= '</p>';

    return $str;
}

sub klaproth_van_lines {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    return '<p>Welcome to Klaproth Van Lines.  This utility will reparent writeups for a single user in bulk.</p>' unless($APP->isAdmin($USER));

    my $str = '<p>Welcome to Klaproth Van Lines.  This utility will reparent writeups for a single user in bulk.</p>';
    $str .= htmlcode('openform');
    $str .= '<table border="1">';

    return $str . '<tr><th>[Klaproth] has no business with you ... just now.</th></tr></table>' . htmlcode('closeform') unless $APP->isAdmin($USER);

    # Debug
    if($query->param('user_name') && $query->param('idlist')) {
        $str .= '<tr><th>Altar\'d states!</th></tr>';
    }

    my $myusername = $query->param('user_name') || '';
    my $myoldlist = $query->param('oldlist') || '';

    if($myusername && $myoldlist) {
        # Second stage - retrieve and validate form data

        # For which user is this request?
        my $uservictim = getNode($myusername, 'user');

        # Sorry, we don't know that user
        unless($uservictim) {
            $str .= '<tr><th>There is no user: "' . $myusername . '"</th></tr>';
            $str .= '</table>' . htmlcode('closeform');
            return $str;
        }

        # Strip the linefeeds
        $myoldlist =~ s/\s+\n/\n/g;

        my @idlist = split('\n', $myoldlist);
        my $tempid = undef;
        my $goodstr = '';
        my $errstr = '';

        # Build the table's top, to be used if no errors are found
        $goodstr .= '<tr><td colspan=2>The following writeups by <strong>';
        $goodstr .= $$uservictim{title};
        $goodstr .= '</strong> are ready to be reparented.';
        $goodstr .= 'Nothing has happened to them ... yet.</td>';
        $goodstr .= '<tr><th>Writeups to reparent</th><th>New homes</th></tr>';
        $goodstr .= '<tr><td><ol>';

        # Iterate over the writeup ID list and make sure they're all kosher
        foreach my $wu (@idlist) {
            next unless $wu;

            # Use the writeup ID to get the node ID
            $tempid = getNodeById($wu);

            # Error if this didn't work -- e.g. writeup has no parent
            $errstr .= '<li><strong>Error</strong>:Writeup ID ' . $wu . ' has no parent' unless $tempid;
            next unless $tempid;

            # ID must be type 'writeup' (117) ? want an error msg ?
            $errstr .= '<li><strong>Error</strong>:ID ' . $wu . ' is not a writeup' unless $$tempid{type_nodetype} == 117;
            next unless $$tempid{type_nodetype} == 117;

            # Check that the author is correct
            if ($$tempid{author_user} == $$uservictim{node_id}) {
                $goodstr .= '<li>' . linkNode($tempid, $$tempid{title});
            } else {
                $errstr .= '<li><strong>Error</strong>: ' . linkNode($tempid, $$tempid{title});
                $errstr .= ' is not by target author';
            }
        }
        $goodstr .= '</ol></td>';
        $goodstr .= '<td><ol>';

        my $mynewlist = $query->param('newlist') || '';
        my @nodelist = ();
        my @nodeidlist = ();

        # Iterate over the new node list to ensure they're all e2nodes
        if($mynewlist) {
            $mynewlist =~ s/\s+\n/\n/g;
            @nodelist = split('\n', $mynewlist);

            # Iterate over the new parent list and grab the node IDs
            foreach my $wu (@nodelist) {
                next unless $wu;

                $tempid = getNode($wu, 'e2node');
                # Error if this didn't work -- e.g. not an e2node
                $errstr .= '<li><strong>Error</strong>: ' . $wu . ' is not an e2node.' unless $tempid;
                next unless $tempid;

                # ID must be type 'node' (116) ? want an error msg ?
                next unless $$tempid{type_nodetype} == 116;

                # Seems OK ...
                # ... Add to node id list (for later post)
                push(@nodeidlist, $$tempid{node_id});
                # ... add to the display list
                $goodstr .= '<li>' . linkNode($tempid, $$tempid{title});
            }
        }
        $goodstr .= '</ol></td></tr>';

        # Check that the counts match
        if($#idlist != $#nodelist) {
            $errstr .= '<li><strong>Error</strong>: Mismatched lists! ';

            if($#idlist > $#nodelist) {
                $errstr .= 'More IDs than Nodes';
            } else {
                $errstr .= 'More Nodes than IDs';
            }
        }

        # Assemble the table
        if($errstr) {
            # Errors were encountered
            $str .= '<tr><td>Errors were found<br><ul>' . $errstr . '</ul></td></tr>';
        } else {
            # Show the source and target lists
            $str .= $goodstr;

            # Rebuild the table rows for final verification (debug)
            $str .= '<tr><td><input type=hidden name="movelist" value="';
            $str .= join(',', @idlist);
            $str .= '"></td>';
            $str .= '<td><input type=hidden name="homelist" value="';
            $str .= join(',', @nodeidlist);
            $str .= '"></td></tr>';
            $str .= '<tr><td colspan=2><input type="checkbox" value=1 name="doit" CHECKED/> Do it!</td></tr>';
        }
    } else {
        if($query->param('doit') && $query->param('doit') == 1) {
            # Final stage, do the actual move

            my @moveidlist = split(',', $query->param('movelist') || '');
            my @homeidlist = split(',', $query->param('homelist') || '');

            $str .= '<tr><td>';
            my $i = 0;
            foreach my $wu (@moveidlist) {
                my $wuid = getNodeById($wu);
                my $oldparent = getNodeById($$wuid{parent_e2node});
                my $newparent = getNodeById($homeidlist[$i]);

                # Report it
                $str .= $wu . ' ' . $$wuid{title} . ' in ' . $$oldparent{title};
                $str .= ' has moved to ' . linkNode($newparent, $$newparent{title});
                $str .= '<br />';

                # Do it - based on 'Magical Writeup Reparenter'
                # ... out of the old e2node ...
                $DB->removeFromNodegroup($oldparent, $wuid, $USER);
                # ... store the new e2node as parent ...
                $$wuid{parent_e2node} = $$newparent{node_id};
                # ... Retitle the writeup "new name (type)" ...
                my $wutype = getNodeById($$wuid{wrtype_writeuptype});
                $$wuid{title} = $$newparent{title} . ' (' . $$wutype{title} . ')';
                # ... Put it in its new e2node ...
                $DB->insertIntoNodegroup($newparent, $USER, $wuid);
                # ... Make sure all parties know of the change
                updateNode($oldparent, -1);
                updateNode($newparent, -1);
                updateNode($wuid, -1);

                # Loop counter (don't know how to use foreach on 2 arrays)
                $i++;
            }
            $str .= '</td></tr>';
        } else {
            # No data yet - build and present the input form
            $str .= '<tr><td colspan=2>Username: ';
            $str .= '<input type="text" name="user_name"></td></tr>';
            $str .= '<tr><th>Source writeup IDs<br><small>';
            $str .= '(get \'em from the ';
            $str .= linkNode(getNode('Altar of Sacrifice', 'oppressor_superdoc'), 'Altar');
            $str .= ')</small></th><th>Target node names</th></tr>';
            $str .= '<tr><td>';
            $str .= '<textarea name="oldlist" ROWS=20 COLS=30></textarea>';
            $str .= '</td><td>';
            $str .= '<textarea name="newlist" ROWS=20 COLS=30></textarea>';
            $str .= '</td></tr>';
        }
    }

    $str .= '</table>';
    $str .= htmlcode('closeform');

    return $str;
}

sub nate_s_secret_unborg_doc {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    return 'Maybe you\'d better just stay in there' unless $APP->isAdmin($USER);

    $VARS->{borged} = '';

    $DB->sqlUpdate('room', {borgd => '0'}, 'member_user=' . getId($USER));

    return 'you\'re unborged';
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

sub node_forbiddance {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $unforbid = $query->param("unforbid");
    my $ufusr = getNodeById($unforbid);
    my $forbid = $query->param("forbid");
    my $fusr = getNode($forbid, 'user');
    my $str = '';

    if($unforbid && $ufusr) {
        $DB->sqlDelete("nodelock", "nodelock_node=" . $ufusr->{user_id});
        $str .= "It is done...they are free<br><br>";
    }

    if($forbid && $fusr) {
        $DB->sqlInsert("nodelock", {'nodelock_node' => $fusr->{user_id}, 'nodelock_user' => $USER->{user_id}, 'nodelock_reason' => $query->param("reason")});
        $str .= "It is done...they have been forbidden<br><br>";
    }

    $str .= htmlcode("openform");
    $str .= "Forbid user <input type=\"text\" name=\"forbid\"> because <input type=\"text\" name=\"reason\"><br><input type=\"submit\" value=\"do it\"></form>";

    $str .= "<br><br><p align=\"center\"><hr width=\"300\"></p>";

    my $csr = $DB->sqlSelectMany("*", "nodelock left join node on nodelock_node = node_id", "type_nodetype=" . getId(getType('user')));

    $str .= "<ul>";

    while(my $row = $csr->fetchrow_hashref) {
        $str .= "<li>" . linkNode($row->{nodelock_node}) . " is forbidden by " . linkNode($row->{nodelock_user}) . " (<small>" . (($row->{nodelock_reason}) ? (parseLinks($row->{nodelock_reason})) : ("<em>No reason given</em>")) . "</small>) " . linkNode($NODE, "unforbid", {'unforbid' => $row->{nodelock_node}});
    }

    $str .= "</ul>";

    return $str;
}


sub the_old_hooked_pole {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    return 'You\'ve got other things to snoop on, don\'t ya.' unless ($APP->isEditor($USER));

    # block spammer's IP if a locked account had logged in from same IP less than this long ago (SQL INTERVAL)
    my $ipTrauma = '1 MONTH';

    my $str = '';

    my @savedUsers = ();
    my $usersToNail = {};
    my $smite = $query->param('op') eq 'remove' ? 1 : '';  # did we come here from the Smite Spammer link (old version)?
    my $usernameString = $smite ? $query->param('author') : $query->param('usernames');
    $smite ||= $query->param('smite');  # from Smite Spammer link (new version)

    if ($usernameString) {

        my $typeIdUser = getType('user')->{node_id};
        my $typeIdWriteup = getType('writeup')->{node_id};
        my $typeIdE2node = getType('e2node')->{node_id};
        $usernameString =~ s/[\[\]]//g;
        my @usernames = split('\s*[\n\r]\s*', $usernameString);

        my $ordinal = 1;
        my $inputTable =
            join "\n    UNION ALL\n"
                , map { "    SELECT " . $DB->quote($_) . " AS title"
                        . ", " . ($ordinal++) . " AS ordinal" } @usernames;

        my $userQuery = qq|

SELECT input.title 'input', node.title, node.node_id, user.lasttime
  , user.acctlock
  , (SELECT COUNT(writeups.node_id)
      FROM node writeups
      WHERE node.node_id = writeups.author_user
      AND writeups.type_nodetype = $typeIdWriteup)
     'writeup count'
  , (SELECT COUNT(nodeshells.node_id)
      FROM node AS nodeshells
      WHERE node.node_id = nodeshells.author_user
      AND nodeshells.type_nodetype = $typeIdE2node)
     'nodeshell count'
  , input.ordinal
  FROM (
$inputTable
  ) input
  LEFT JOIN node
    ON node.title = input.title
    AND node.type_nodetype = $typeIdUser
  LEFT JOIN user
    ON node.node_id = user.user_id
  GROUP BY input.title
  ORDER BY input.ordinal|;

        $str .= "<h3>Query</h3><pre>$userQuery</pre>" if ($query->param("showquery"));

        $usersToNail = $DB->{dbh}->selectall_hashref($userQuery, 'ordinal');
    }

    if (keys %$usersToNail) {

        my $smiteSpammer = sub {
            my @smitten = ();
            my $targetUserData = shift;
            my $spammer = $targetUserData->{node_id};

            if (getRef $spammer) {  # may conceivably have been nuked
                $spammer->{doctext} = '';
                updateNode($spammer, -1);
                my $uservars = getVars($spammer);
                $uservars = { ipaddy => $uservars->{ipaddy} };
                setVars($spammer, $uservars);
                push @smitten, 'Blanked homenode';
                htmlcode('addNodenote', $targetUserData->{node_id}, "Spammer: smitten by [$USER->{title}\[user]]");
            }

            # has this user logged in from the same IP as a recently locked user?
            my $badIP = $DB->sqlSelect('myIP.iplog_ipaddy'
                , "iplog myIP JOIN iplog badIP JOIN user
                    ON myIP.iplog_ipaddy = badIP.iplog_ipaddy
                    AND myIP.iplog_ipaddy != 'unknown'
                    AND user_id = badIP.iplog_user
                    AND user_id != myIP.iplog_user"
                , "myIP.iplog_user = $targetUserData->{node_id}
                    AND acctlock != 0
                    AND lasttime > DATE_SUB(NOW(), INTERVAL $ipTrauma)"
            );

            push @smitten, htmlcode('blacklistIP', $badIP, "Spammer $targetUserData->{input} using same IP as recently locked account") if $badIP;

            @smitten;
        };

        $str .= '<h3>The Doomed Performers</h3>';
        $str .= '<ul>';

        foreach my $targetOrdinal (sort keys %$usersToNail) {

            my $safeToWhack = 1;
            my $safeToLock = 1;
            my @unsafeReasons = ();
            my $targetUserData = $usersToNail->{$targetOrdinal};
            my $targetName  = $targetUserData->{'input'};
            $targetName = encodeHTML($targetName);

            $str .= "<li>";

            if ($targetUserData->{node_id} == 0) {

                push @unsafeReasons,  "$targetName isn't a valid user";
                $safeToWhack = 0;
                $safeToLock = 0;

            } else {

                $targetName = linkNode($targetUserData->{node_id});

            }

            if ("$targetUserData->{lasttime}" ne "0" && "$targetUserData->{lasttime}" ne "") {

                push @unsafeReasons,  "$targetName logged in at $targetUserData->{lasttime}!";
                $safeToWhack = 0;

            }

            if ($targetUserData->{'nodeshell count'} != 0) {

                push @unsafeReasons,  "$targetName has $targetUserData->{'nodeshell count'} nodeshells!";
                $safeToWhack = 0;

            }

            if ($targetUserData->{'writeup count'} != 0) {

                my %removereason = $query->param('removereason') ? (removereason => $query->param('removereason')) : ();
                my $removeLink = linkNode(getNode('Altar of Sacrifice', 'oppressor_superdoc'), 'Remove them...'
                    , {author => $targetUserData->{'title'}, %removereason});
                push @unsafeReasons,  "$targetName has $targetUserData->{'writeup count'} writeups! &#91; $removeLink ]";
                $safeToWhack = 0;


            }

            if (!htmlcode('verifyRequest', 'polehash')) {
                push @unsafeReasons,  "$targetName not being whacked because security hash verification failed.";
                $safeToWhack = 0;
                $safeToLock = 0;

            }

            if ($safeToWhack) {

                $str .= "Deleted $targetName ($targetUserData->{node_id}).";
                nukeNode($targetUserData->{node_id}, $USER);

            } else {

                if ($safeToLock) {

                    if ($targetUserData->{acctlock} == 0) {

                        htmlcode('lock user account', $targetUserData->{node_id});
                        push @unsafeReasons,  "<strong>Locked account.</strong>";

                    } else {

                        push @unsafeReasons,  "<strong>Account already locked.</strong>";

                    }

                    push @unsafeReasons, $smiteSpammer->($targetUserData) if $smite;

                }

                $str .= '<ul><li>' . (join '<li>', @unsafeReasons) . '</ul>';
                push @savedUsers, $targetUserData->{'input'};

            }

        }

        $str .= '</ul>';

    }

    return $str if $smite || $query->param('detonate');

    $str .= '<h3>&ldquo;Off the stage with \'em!&rdquo;</h3>
       A mass user deletion tool which provides basic checks for deletion.
      <br><br>Copy and paste list of names of users to destroy.
      <p>
      This does the following things:
      </p>
      <ul>
        <li>Checks to see if the user has ever logged in
        <li>Checks if the user has any live writeups
        <li>Checks if the user has any live e2nodes
        <li>Deletes the user if it is safe
        <li>Locks a user if deletion isn\'t safe
      </ul>
      '
        . htmlcode('openform', 'username_whacker', 'POST')
        . $query->hidden(-name => "showquery")
        . htmlcode('verifyRequestForm', 'polehash')
        ;

    if (scalar @savedUsers) {
        my $savedList = "";
        $savedList .= join "\n", @savedUsers;
        $str .= '<fieldset><legend>The users who were spared</legend>';
        $query->delete("ignored-saved");
        $str .= $query->textarea(
            -name => "ignored-saved"
            , -value => $savedList
            , -class => "expandable"
        );
        $str .= '</fieldset>';
        $str .= "<br><br>";
    }

    $str .= ''
        . '<fieldset><legend>Inadequate Performers</legend>'
        . $query->textarea(-name => "usernames"
            , -rows => "2"
            , -cols => "15"
            , -class => "expandable"
        )
        . "<br><br>"
        . $query->submit(-name => "Get The Hook!")
        . '</fieldset>'
        . $query->end_form()
        ;

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

    if ($mode eq 'vote') {
        Everything::Delegation::opcode::vote($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);
        return 0;
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

    # REMOVED 2025-12-10: Legacy modes no longer called by frontend
    # - annotate: Annotation feature never implemented in frontend, table empty (removed 2025-12-10)
    # REMOVED 2025-12-07: Legacy modes no longer called by frontend
    # - update: Already retired, returned error message
    # - getlastmessage: React Chatterbox manages message IDs internally
    # - checkCools: React manages cool nodes via initial page data
    # - checkMessages: React Messages nodelet uses /api/messages
    # - checkFeedItems: User feed feature unused/deprecated
    # - deleteFeedItem: User feed feature unused/deprecated
    # - markNotificationSeen: Now handled by /api/notifications/dismiss (removed 2025-11-27)
    # - checkNotifications: Replaced by React Notifications nodelet (removed 2025-11-27)

    $NODE = getNodeById(124);

    return '';
}

1;
