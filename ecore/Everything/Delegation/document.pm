package Everything::Delegation::document;

use strict;
use warnings;

# Used in: reputation_graph, reputation_graph_horizontal
use Date::Parse;

# Used in: findings_, sql_prompt
use Time::HiRes;

# Used in: gnl
use Everything::FormMenu;

# Used in: ajax_update
use JSON;
use Everything::Delegation::opcode;

# Used in: chatterbox_xml_ticker, cool_nodes_xml_ticker, new_nodes_xml_ticker,
#          private_message_xml_ticker, rdf_search, user_information_xml,
#          user_search_xml_ticker
use XML::Generator;

# Used in: personal_session_xml_ticker, podcast_rss_feed
use POSIX qw(strftime asctime);

# Used in: universal_message_xml_ticker
use XML::Simple;

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
    *insertNodelet   = *Everything::HTML::insertNodelet;
    *getType         = *Everything::HTML::getType;
    *updateNode      = *Everything::HTML::updateNode;
    *setVars         = *Everything::HTML::setVars;
    *linkNodeTitle   = *Everything::HTML::linkNodeTitle;
    *canUpdateNode   = *Everything::HTML::canUpdateNode;
    *updateLinks     = *Everything::HTML::updateLinks;
    *canReadNode     = *Everything::HTML::canReadNode;
    *encodeHTML      = *Everything::HTML::encodeHTML;
}

# Used by e2_sperm_counter
use POSIX qw(ceil);

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

# Used by XML ticker fullpage functions: new_nodes_xml_ticker,
#         private_message_xml_ticker, rdf_search, user_information_xml,
#         user_search_xml_ticker
use Everything::XML;

sub admin_settings {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    ## no critic 'Perl::Critic::Policy::ValuesAndExpressions::RequireInterpolationOfMetachars'
    return
        '<p>You need to sign in or '
      . linkNode( getNode( 'Sign up', 'superdoc' ), 'register' )
      . ' to use this page.</p>'
      if $APP->isGuest($USER);

    $PAGELOAD->{pageheader} = '<!-- at end -->' . htmlcode('settingsDocs');

    my $str = htmlcode( 'openform', -id => 'pagebody' );

    #editor options
    if ( $APP->isEditor($USER) ) {
        if(not $APP->isEditor($USER))
        {
            return;
        }
        my $nl = "<br />\n";
        $str .= "<p><strong>Editor Stuff</strong>\n";
        $str .= $nl
          . htmlcode( 'varcheckbox',
'killfloor_showlinks,Add HTML in the killing floor display for easy copy & paste'
          );

        $str .=
          $nl . htmlcode( 'varcheckbox', 'hidenodenotes,Hide Node Notes' );

        $str .= '</p>';

        my $f = $query->param('sexisgood');    #end of form indicator
        my $l = 768;                           #max length of each macro

#key is allowed macro, value is the default
#note: things like $1 are NOT supposed to be interpolated - that is done when the macro is executed
        my %allowedMacros = (
            'room' =>
'/say /msg $1 Just so you know - you are not in the default room, where most people stay. To get back into the main room, either visit {go outside}, or: go to the top of the "other users" nodelet, pick "outside" from the dropdown list, and press the "Go" button.',
            'newbie' =>
'/say /msg $1 Hello, your writeups could use a little work. Read [Everything University] and [Everything FAQ] to improve your current and future writeups. $2+'
              . "\n"
              . '/say /msg $1 If you have any questions, you can send me a private message by typing this in the chatterbox: /msg $0 (Your message here.)',
            'html' =>
'/say /msg $1 Your writeups could be improved by using some HTML tags, such as &lt;p&gt; , which starts a new paragraph. [Everything FAQ: Can I use HTML in my writeups?] lists the tags allowed here, and [E2 HTML tags] shows you how to use them.',
            'wukill' => '/say /msg $1 FYI - I removed your writeup $2+',
            'nv'     =>
'/say /msg $1 Hey, I know that you probably didn\'t mean to, but advertising your writeups ("[nodevertising]") in the chatterbox isn\'t cool. Imagine if everyone did that - there would be no room for chatter.',
            'misc1' =>
'/say /msg \$0 Use this for your own custom macro. See [macro FAQ] for information about macros.'
              . "\n"
              . '/say /msg $0 If you have an idea of another thing to add that would be wanted by many people, give N-Wing a /msg.',
            'misc2' =>
              '/say /msg $0 Yup, this is an area for another custom macro.'
        );

        my @ks = sort( keys %allowedMacros );

        foreach my $k (@ks) {
            my $v = undef;
            if (   ( defined $query->param( 'usemacro_' . $k ) )
                && ( $v = $query->param( 'usemacro_' . $k ) eq '1' ) )
            {
                #possibly add macro
                if (   ( defined $query->param( 'macrotext_' . $k ) )
                    && ( $v = $query->param( 'macrotext_' . $k ) ) )
                {
                    $v =~ tr/\r/\n/;
                    $v =~ s/\n+/\n/gs;    #line endings are a pain
                    $v =~
                      s/[^\n\x20-\x7e]//gs; #could probably also allow \x80-\xfe
                    $v = substr( $v, 0, $l );
                    $v =~ s/\{/[/gs;
                    $v =~ s/\}/]/gs
                      ; #hack - it seems you can't use square brackets in a superdoc :(
                    $VARS->{ 'chatmacro_' . $k } = $v;
                }
            }
            elsif ($f) {

                #delete unwanted macro (but only if no form submit problems)
                delete $VARS->{ 'chatmacro_' . $k };
            }
        }

        $str .=
            '<p><strong>Macros</strong></p>' . "\n"
          . '<table cellspacing="1" cellpadding="2" border="1"><tr><th>Use?</th><th>Name</th><th>Text</th></tr>'
          . "\n";

        foreach my $k (@ks) {
            my $v = $VARS->{ 'chatmacro_' . $k };
            my $z = ( $v && length($v) > 0 ) ? 1 : 0;
            unless ($z) { $v = $allowedMacros{$k}; }
            $v =~ s/\[/{/gs;
            $v =~ s/\]/}/gs;    #square-link-in-superdoc workaround :(
            $str .=
                '<tr><td>'
              . $query->checkbox( 'usemacro_' . $k, $z, '1', '')
              . '</td><td><code>'
              . $k
              . '</code></td><td>'
              . $query->textarea(
                -name     => 'macrotext_' . $k,
                -default  => $v,
                -rows     => 6,
                -columns  => 65,
                -override => 1
              ) . "</td></tr>\n";
        }

        $str .=
            "</table>\n"
          . 'If you will use a macro, make sure the "Use" column is checked. If you won\'t use it, uncheck it, and it will be deleted. The text in the "macro" area of a "non-use" macro is the default text, although you can change it (but be sure to check the "use" checkbox if you want to keep it). Each macro must currently begin with <code>/say</code> (which indicates that you\'re saying something). Note: each macro is limited to '
          . $l
          . ' characters. Sorry, until a better solution is found, instead of square brackets, &#91; and &#93;, you\'ll have to use curly brackets, { and } instead. <tt>:(</tt> There is more information about macros at [macro FAQ].</p>';

    }

    $str .= htmlcode('closeform');
    return $str;
}

sub advanced_settings {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    ## no critic 'Perl::Critic::Policy::ValuesAndExpressions::RequireInterpolationOfMetachars'
    return
        '<p>You need to sign in or '
      . linkNode( getNode( 'Sign up', 'superdoc' ), 'register' )
      . ' to use this page.</p>'
      if ( $APP->isGuest($USER) );

    if ( defined $query->param('sexisgood') ) {
        $VARS->{'preference_last_update_time'} = DateTime->now()->epoch() - 60;
    }

    $PAGELOAD->{pageheader} = '<!-- put at end -->' . htmlcode('settingsDocs');
    my $str = htmlcode( 'openform', -id => 'pagebody' );
    $str .= q|<h2>Page display</h2>|;

    my @headeroptions = qw(audio length hits dtcreate);
    my @footeroptions = qw(kill sendmsg addto social);

    my $legacycheck = '^$|c:type,c:(author|pseudoanon)(,\w:'
      . join( ')?(,\w:', @headeroptions ) . ',?)?';
    my $legacyhead = '';
    $legacyhead = '<p>'
      . $query->checkbox(
        -name  => 'replaceoldheader',
        -label =>
'Overwrite all existing header settings. (Changing settings here will not overwrite any custom formatting you already have in place unless you check this.)'
      )
      . "</p>\n"
      unless $VARS->{wuhead} =~ /^$legacycheck$/
      || $query->param('replaceoldheader');

    $legacycheck = '^$|(l:kill)?,?c:vote,c:cfull(,\w:'
      . join( ')?(,\w:', @footeroptions ) . ',?)?';
    my $legacyfoot = '';
    $legacyfoot = '<p>'
      . $query->checkbox(
        -name  => 'replaceoldfooter',
        -label =>
'Overwrite all existing footer settings. (Changing settings here will not overwrite any custom formatting you already have in place unless you check this.)'
      )
      . "</p>\n"
      unless $VARS->{wufoot} =~ /^$legacycheck$/
      || $query->param('replaceoldfooter');

    if ( defined( $query->param('change_stuff') ) ) {
        $VARS->{wuhead} = 'c:type,c:author,c:audio,c:length,c:hits,r:dtcreate'
          unless $legacyhead;
        $VARS->{wuhead} =~ s/,$//;

        foreach my $headeroption (@headeroptions) {
            if ( $query->param( 'wuhead_' . $headeroption ) ) {
                $VARS->{wuhead} .= ",c:$headeroption,"
                  unless $VARS->{wuhead} =~ /\w:$headeroption/;
            }
            else {
                $VARS->{wuhead} =~ s/,?\w:$headeroption//g;
            }
        }

        $VARS->{wufoot} = 'l:kill,c:vote,c:cfull,c:sendmsg,c:addto,r:social'
          unless $legacyfoot;
        $VARS->{wufoot} =~ s/,$//;
        foreach my $footeroption (@footeroptions) {
            if ( $query->param( 'wufoot_' . $footeroption ) ) {
                $VARS->{wufoot} .= ",c:$footeroption"
                  unless $VARS->{wufoot} =~ /\w:$footeroption/;
            }
            else {
                $VARS->{wufoot} =~ s/,?\w:$footeroption//g;
            }
        }

        if ( $query->param('nokillpopup') ) {
            $VARS->{nokillpopup} = 4;
        }
        else {
            delete $VARS->{nokillpopup};
        }
    }

    $str .= "<fieldset><legend>Writeup Headers</legend>\n";
    $str .= htmlcode( 'varcheckboxinverse', 'info_authorsince_off',
        'Show how long ago the author was here' );
    $str .= "<br>\n";

    $str .= $query->checkbox(
        -name    => 'wuhead_audio',
        -checked => ( ( $VARS->{'wuhead'} =~ 'audio' ) ? 1 : 0 ),
        -label   => 'Show links to any audio files'
    );
    $str .= "<br>\n";

    $str .= $query->checkbox(
        -name    => 'wuhead_length',
        -checked => ( ( $VARS->{'wuhead'} =~ 'length' ) ? 1 : 0 ),
        -label   => 'Show approximate word count of writeup'
    );
    $str .= "<br>\n";

    $str .= $query->checkbox(
        -name    => 'wuhead_hits',
        -checked => (
            ( $VARS->{'wuhead'} =~ 'hits' || $VARS->{'wuhead'} eq '' ) ? 1 : 0
        ),
        -label => 'Show a hit counter for each writeup'
    );
    $str .= "<br>\n";

    $str .= $query->checkbox(
        -name    => 'wuhead_dtcreate',
        -checked => (
            ( $VARS->{'wuhead'} =~ 'dtcreate' || $VARS->{'wuhead'} eq '' )
            ? 1
            : 0
        ),
        -label => 'Show time of creation'
    );
    $str .= "<br>\n";

    $str .= "$legacyhead</fieldset>";

    $str .= "<fieldset><legend>Writeup Footers</legend>\n";

    if (    $USER->{title} =~ /^(?:mauler|riverrun|Wiccanpiper|DonJaime)$/
        and $APP->isAdmin($USER) )
    {
    # only gods can disable pop-up: they get the missing tools in Master Control
    # as of 2011-07-15 only three gods are using it. Let's lose it gradually...
        $str .= $query->checkbox(
            -name    => 'nokillpopup',
            -checked => ( $VARS->{nokillpopup} == 4 ),
            -label   => 'Admin tools always visible, no pop-up'
        ) . '<br>';
    }

    $str .= $query->checkbox(
        -name    => 'wufoot_sendmsg',
        -checked => (
            ( $VARS->{'wufoot'} =~ 'sendmsg' || $VARS->{'wufoot'} eq '' ) ? 1 : 0
        ),
        -label => 'Show a box to send messages to the author'
    );
    $str .= "<br>\n";

    $str .= $query->checkbox(
        -name    => 'wufoot_addto',
        -checked => (
            ( $VARS->{'wufoot'} =~ 'addto' || $VARS->{'wufoot'} eq '' ) ? 1 : 0
        ),
        -label =>
'Show a tool to add the writeup to your bookmarks, a usergroup page or a category'
    );
    $str .= "<br>\n";

    $str .= $query->checkbox(
        -name    => 'wufoot_social',
        -checked => (
            ( $VARS->{'wufoot'} =~ 'social' || $VARS->{'wufoot'} eq '' ) ? 1 : 0
        ),
        -label => 'Show social bookmarking buttons'
    );
    $str .= "<br>\n";

    if ( $VARS->{nosocialbookmarking} ) {
        $str .=
"<small>To see social bookmarking buttons on other people's writeups you must enable them for yours<br>\n";

        $str .= htmlcode(
            'varcheckboxinverse',
            'nosocialbookmarking',
            'Enable social bookmarking buttons on my writeups'
        ) . "</small><br>\n";
    }

    $str .= "$legacyfoot</fieldset>";

    $str .= $query->hidden( -name => 'change_stuff' );

    $str .=
q|<p><small><strong>[Old Writeup Settings]</strong> provides more control over writeup headers and footers, but the interface is rather complicated.</small></p>|;
    $str .= q|<fieldset><legend>Homenodes</legend>|;

    $str .= htmlcode( 'varcheckbox', 'hidemsgme', 'I am anti-social.' );
    $str .= q|(So don't display the user /msg box in users' homenodes.)|;
    $str .= q|<br>|;

    $str .= htmlcode( 'varcheckbox', 'hidemsgyou',
'No one talks to me either, so on homenodes, hide the "/msgs from me" link to [Message Inbox]'
    );
    $str .= q|<br>|;

    $str .= htmlcode( 'varcheckbox', 'hidevotedata',
'Not only that, but I\'m careless with my votes and C!s (so don\'t show them on my homenode)'
    );
    $str .= q|<br>|;

    $str .= htmlcode( 'varcheckbox', 'hidehomenodeUG',
'I\'m a loner, Dottie, a rebel. (Don\'t list my usergroups on my homenode.)'
    );
    $str .= q|<br>|;

    $str .= htmlcode( 'varcheckbox', 'hidehomenodeUC',
        'I\'m a secret librarian. (Don\'t list my categories on my homenode.)' );
    $str .= q|<br>|;

    $str .= htmlcode( 'varcheckbox', 'showrecentwucount',
'Let the world know, I\'m a fervent noder, and I love it! (show recent writeup count in homenode.)'
    );
    $str .= q|<br>|;

    $str .= htmlcode( 'varcheckboxinverse', 'hidelastnoded',
        'Link to user\'s most recently created writeup on their homenode' );
    $str .= q|<br>|;
    $str .= q|</fieldset>|;

    $str .= q|<fieldset><legend>Other display options</legend>|;
    $str .= htmlcode( 'varcheckboxinverse', 'hideauthore2node',
        'Show who created a writeup page title (a.k.a. e2node)' );
    $str .= q|<br>|;

    $VARS->{repThreshold} ||= '0'
      if exists( $VARS->{repThreshold} );    # ecore stores 0 as ''
    if ( $query->param('sexisgood') ) {
        $query->param( 'activateThreshold', 1 )
          if $query->param('repThreshold') ne ''
          and $VARS->{repThreshold} eq 'none';
        unless ( $query->param('activateThreshold') ) {
            $VARS->{repThreshold} = 'none';
        }
        else {
            $VARS->{repThreshold} = $query->param('repThreshold');
            unless ( $VARS->{repThreshold} =~ /\d+|none/ ) {
                delete $VARS->{repThreshold};
            }
            else {
                $VARS->{repThreshold} = int $VARS->{repThreshold};
                if ( $query->param('repThreshold') > 50 ) {
                    $query->param( 'repThreshold', 50 );
                    $str .= '<small>Maximum threshold is 50.</small><br>';
                }
            }
        }
    }

    $query->param( 'repThreshold', '' ) if $VARS->{repThreshold} eq 'none';

    $str .= $query->checkbox(
        -name    => 'activateThreshold',
        -value   => 1,
        -checked => ( $VARS->{repThreshold} eq 'none' ? 0 : 1 ),
        -force   => 1,
        -label   => 'Hide low-reputation writeups in New Writeups and e2nodes.'
    );

    $str .= ' <label>Reputation threshold: ';
    $str .= $query->textfield( 'repThreshold', $VARS->{repThreshold}, 3, 3 );
    $str .=
      '</label> (default is ' . $Everything::CONF->writeuplowrepthreshold . ')';

    $str .= q|<br>|;
    $str .= htmlcode( 'varcheckbox', 'noSoftLinks', 'Hide softlinks');
    $str .= q|<br>|;
    $str .= q|</fieldset>|;

    $str .= q|<h2>Information</h2>|;
    $str .= q|<fieldset><legend>Writeup maintenance</legend>|;

    $str .= htmlcode( 'varcheckboxinverse', 'no_notify_kill',
        'Tell me when my writeups are deleted');
    $str .= q|<br>|;

    $str .= htmlcode( 'varcheckboxinverse', 'no_editnotification',
'Tell me when my writeups get edited by [e2 staff|an editor or administrator]'
    );
    $str .= q|</fieldset>|;

    $str .= q|<fieldset><legend>Writeup response</legend>|;

    $str .= htmlcode(
        'varcheckboxinverse',
        'no_coolnotification',
        'Tell me when my writeups get [C!]ed ("cooled")'
    );
    $str .= q|<br>|;

    $str .= htmlcode( 'varcheckboxinverse', 'no_likeitnotification',
        'Tell me when Guest Users like my writeups');
    $str .= q|<br>|;

    $str .= htmlcode(
        'varcheckboxinverse',
        'no_bookmarknotification',
        'Tell me when my writeups get bookmarked on E2'
    );
    $str .= q|<br>|;

    $str .= htmlcode( 'varcheckboxinverse', 'no_bookmarkinformer',
        'Tell others when I bookmark a writeup on E2' );
    $str .=
      htmlcode( 'varcheckbox', 'anonymous_bookmark', 'but do it anonymously' );
    $str .= q|</fieldset>|;

    $str .= q|<fieldset><legend>Social bookmarking</legend>|;

    $str .= htmlcode( 'varcheckboxinverse', 'nosocialbookmarking',
        'Allow others to see social bookmarking buttons on my writeups' );
    $str .=
q|<small>Unchecking this will also hide the social bookmarking buttons on other people's writeups.</small><br>|;

    $str .= htmlcode( 'varcheckboxinverse', 'no_socialbookmarknotification',
        'Tell me when my writeups get bookmarked on a social bookmarking site'
    );
    $str .= q|<br>|;

    $str .= htmlcode( 'varcheckboxinverse', 'no_socialbookmarkinformer',
        'Tell others when I bookmark a writeup on a social bookmarking site' );
    $str .= q|</p></fieldset>|;

    $str .= q|<fieldset><legend>Other information</legend>|;

    $str .= htmlcode( 'varcheckboxinverse', 'no_discussionreplynotify',
        'Tell me when someone replies to my usergroup discussion posts' );
    $str .= q|<br>|;

    $str .= htmlcode( 'varcheckbox', 'hidelastseen',
        'Don\'t tell anyone when I was last here');
    $str .= q|<br>|;
    $str .= q|</fieldset>|;

    $str .= q|<h2>Messages</h2>|;
    $str .= q|<fieldset><legend>Message Inbox</legend>|;

    $str .= htmlcode( 'varcheckbox', 'sortmyinbox',
        'Sort my messages in message inbox');
    $str .= q|<br>|;

    $str .= htmlcode( 'varcheckbox', 'mitextarea',
        'Larger text box in Message Inbox');
    $str .= q|<br></fieldset>|;

    $str .= q|<fieldset><legend>Usergroup messages</legend>|;
    $str .= htmlcode( 'varcheckbox', 'getofflinemsgs',
        'Get online-only messages, even while offline.' );
    $str .= '([online only /msg|explanation])';
    $str .= q|</fieldset>|;

    $str .= q|<h2>Miscellaneous</h2>|;
    $str .= q|<fieldset><legend>Chatterbox</legend>|;

    $str .= htmlcode( 'varcheckboxinverse', 'noTypoCheck',
        'Check for chatterbox command typos' );
    $str .=
q|&ndash; /mgs etc.(when enabled, some messages that aren't typos may be flagged as such, although this will protect you against most real typos)<br>|;
    $str .= q|</fieldset>|;

    $str .= q|<fieldset><legend>Nodeshells</legend>|;

    $str .= htmlcode( 'varcheckbox', 'hidenodeshells',
        'Hide nodeshells in search results and softlink tables' );
    $str .=
q|<br><small>A nodeshell is a page on Everything2 with a title but no content</small>|;
    $str .= q|</fieldset>|;

    $str .= q|<fieldset><legend>GP system</legend>|;
    $str .=
      htmlcode( 'varcheckbox', 'GPoptout', 'Opt me out of the GP System.' );
    $str .= q|<br>|;
    $str .=
q|<small>[GP] is a points reward system. You get points for doing good stuff and can use them to buy fun stuff.</small>|;
    $str .= q|</fieldset>|;

    $str .= q|<fieldset><legend>Little-needed</legend>|;

    $str .= htmlcode( 'varcheckbox', 'defaultpostwriteup',
        'Publish immediately by default.');
    $str .= q|<br>|;

    $str .=
q|<small>(Some older users may appreciate having 'publish immediately' initially selected instead 'post as draft'.)</small><br>|;

    $str .= htmlcode('varcheckbox', 'noquickvote',
        'Disable quick functions (a.k.a. AJAX).' );
    $str .= q|<br>|;

    $str .=
q|<small>(Voting, cooling, chatting, etc will all require complete pageloads. You probably don't want this.)</small><br>|;

    $str .= htmlcode( 'varcheckbox', 'nonodeletcollapser',
        'Disable nodelet collapser');
    $str .= q|<br>|;
    $str .=
q|<small>(clicking on a nodelet title will not hide its content).</small><br>|;

    $str .= htmlcode( 'varcheckbox', 'HideNewWriteups',
        'Hide your new writeups by default');
    $str .= q|<br>|;
    $str .=
'<small>(note: some writeups, such as [Everything Daylogs|day log]s and maintenance-related writeups,always default to a hidden creation)</small><br>';

    $str .= htmlcode( 'varcheckbox', 'nullvote', 'Show null vote button');
    $str .=
q|<br><small>Some old browsers needed at least one radio-button to be selected</small></fieldset>|;

    $str .= q|<h2>Unsupported options</h2>|;
    $str .= q|<fieldset><legend>Experimental/In development</legend>|;
    $str .=
q|<p><small>The time zone and other settings here do not currently affect the display of all times on the site.</small><br>|;

    $str .=
      htmlcode( 'varcheckbox', 'localTimeUse', 'Use my time zone offset');

#daylight saving time messes things up; cheap way is to have a separate checkbox for daylight saving time
    my $specialNames = {
        '-12:00' => 'International date line West',
        '-11:00' => 'Samoa',
        '-10:00' => 'Hawaii',
        '-9:00'  => 'Alaska',
        '-8:00'  => 'Pacific (Los Angeles/Vancouver)/Baja California',
        '-7:00'  => 'Mountain (Calgary/Denver/Salt Lake City)/Chihuahua/La Paz',
        '-6:00'  => 'Central (Winnipeg/Chicago/New Orleans)/Central America',
        '-5:00'  => 'Eastern (New York City/Atlanta/Miami)/Bogota/Lima/Quito',
        '-4:30'  => 'Caracas',
        '-4:00'  => 'Atlantic (Halifax)/Asuncion/Santiago/Georgetown/San Juan',
        '-3:30'  => 'Newfoundland',
        '-3:00'  => 'Greenland/Rio de Janeiro/Brasilia/Buenos Aires/Montevideo',
        '-1:00'  => 'Azores/Cabo Verde',
        '0:00'   => 'UTC server time (Lisbon/London/Dublin/Reykjavik/Monrovia)',
        '1:00'   => 'Central Europe (Madrid/Amsterdam/Paris/Berlin/Prague)',
        '2:00'   => 'Eastern Europe/Jerusalem/Istanbul/Cairo/Cape Town',
        '3:00'   => 'Moscow/Baghdad/Nairobi',
        '3:30'   => 'Tehran',
        '4:00'   => 'Caucasus (Tblisi/Yerevan/Baku)/Abu Dhabi/Port Louis',
        '4:30'   => 'Kabul',
        '5:00'   => 'Ekaterinburg/Islamabad/Tashkent',
        '5:30'   => 'Chennai/Kolkata/Mumbai/Sri Jayawardenepura',
        '6:00'   => 'Astana/Dhaka/Novosibirsk',
        '6:30'   => 'Yangoon (Rangoon)',
        '7:00'   => 'Bangkok/Hanoi/Jakarta/Krasnoyarsk',
        '8:00'   =>
          'Beijing/Hong Kong/Singapore/Urumqi/Irkutsk/Perth/Ulaanbataar',
        '9:00'  => 'Tokyo/Seoul/Yakutsk',
        '9:30'  => 'Adelaide/Darwin',
        '10:00' => 'Guam/Sydney/Melbourne/Brisbane/Vladivostok',
        '11:00' => 'Magadan/Solomon Islands/New Caledonia',
        '12:00' => 'Auckland/Wellington/Fiji',
        '13:00' => 'Nuku\'alofa',
    };

    my $params  = '';
    my $t       = -43200;    # 12 * 3600: time() uses seconds
    my $minutes = '00';
    my $plus;
    for ( my $hours = -12 ; $hours <= 13 ; ++$hours ) {
        my $n = ( $hours % 12 ? 2 : ( $hours ? 1 : 3 ) );
        $plus = '-' unless $hours;
        for ( my $i = $n ; $i ; $i-- ) {
            my $zone = "$hours:$minutes";
            $params .= ",$t,$plus$zone"
              . ( $specialNames->{$zone} ? " - $specialNames->{$zone}" : '' );
            $minutes = $minutes eq '00' ? '30' : '00';
            $t += 1800;
            $plus = '+' unless $hours;
        }
    }
    $params =~ s/\b(\d):/0$1:/g;

    #Y2k bug:
    #    60*60*24*365*100=3153600000=100 years ago, 365 days/year
    #    60*60*24*25=2160000=25 extra leap days; adjustment to 26: Feb 29, 2004
    #week in future:
    #    60*60*24*7=604800=week

    $params =
      ',-3155760000,Y2k bug' . $params . ',604800,I live for the future';

    $str .= htmlcode( 'varsComboBox', 'localTimeOffset,0' . $params );
    $str .= q|<br>|;

    $str .= htmlcode( 'varcheckbox', 'localTimeDST',
        'I am currently in daylight saving time');
    $str .= q|(so add an an hour to my normal offset)<br>|;

    $str .= htmlcode( 'varcheckbox', 'localTime12hr',
        'I am from a backwards country that uses a 12 hour clock');
    $str .= q|(show AM/PM instead of 24-hour format)|;

    $str .= q|</p></fieldset>|;

    $str .= htmlcode('closeform');
    return $str;
}

sub alphabetizer {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<p>Go ahead -- one entry per line:</p>|;
    $str .= htmlcode('openform');

    $str .= q|<p><!-- N-Wing added options 2005-12-12 -->|;

    $str .= q|separator: |;
    $str .=
      htmlcode( 'varsComboBox', 'alphabetizer_sep', 0, 0, 'none (default)',
        1, '<br>', 2, '<li> (use in UL or OL)' );
    $str .= q|<br />|;

    $str .= q|sort: |;
    $str .= htmlcode( 'varcheckbox', 'alphabetizer_sortorder', 'reverse' );
    $str .= htmlcode( 'varcheckboxinverse', 'alphabetizer_case',
        'ignore case (default yes)' );
    $str .= q|<br />|;

    $str .= htmlcode( 'varcheckbox', 'alphabetizer_format','make everything an E2 link' );

    $str .= q|</p><p>|;

    $str .= $query->textarea( 'alpha', '', 20, 60 );
    $str .= q|</p>|;

    $str .= htmlcode('closeform');

    my $list = $query->param('alpha');
    return $str unless $list;

    my $outputstr = '';
    my $leOpen    = '';
    my $leClose   = '';
    my $s         = $VARS->{'alphabetizer_sep'};
    if ( $s == 1 ) {
        $leClose = '&lt;br&gt;';
    }
    elsif ( $s == 2 ) {
        $leOpen  = '&lt;li&gt;';
        $leClose = '&lt;/li&gt;';
    }
    else {
        #no formatting
    }

    my @entries = split "\n", $list;

    foreach (@entries) {
        s/^\s*(.*?)\s*$/$1/;

        # Put articles at the end so they don't screw up
        # the sort.
        $_ =~ s/^(An?) (.*)$/$2, $1/i;
        $_ =~ s/^(The) (.*)$/$2, $1/i;
    }

    if ( $VARS->{'alphabetizer_case'} ) {
        @entries = sort @entries;
    }
    else {
        @entries = sort { lc($a) cmp lc($b) } @entries;
    }

    @entries = reverse @entries if $VARS->{'alphabetizer_sortorder'};

    foreach (@entries) {
        next unless length($_);
        $_ =~ s/^(.*), (An?)/$2 $1/i;
        $_ =~ s/^(.*), (The)/$2 $1/i;

        if ( $VARS->{'alphabetizer_format'} ) {

            #put brackets around the string.
            $_ = '[' . $_ . ']';
        }
    }

    foreach (@entries) {
        next unless length($_);

        $outputstr .= $leOpen . encodeHTML( $_, 1 ) . $leClose . "\n";
    }

    return qq|$str<pre>$outputstr</pre></p>|;
}

sub ask_everything__do_i_have_the_swine_flu_ {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str =
q|<p>You walk up to the Everything Oracle, insert your coin, and ask the question that's most on your mind: DO I HAVE [SWINE FLU]???</p>|;
    $str .=
q|<br>The answer instantly flashes on the screen:<br><br><p align=center>|;

    my @flu = (
        q|No.|,
        q|Yes.|,
        q|Maybe.|,
        q|I'm afraid that is classified information.|,
        q|Does your mother know you're here?|,
        q|Who wants to know?|,
        q|No.|,
        q|Please try again.|,
        q|I could tell you but then I'd have to kill you. If the Swine Flu doesn't do it first.|,
        q|No. You're probably Jewish and not allowed to have Swine Flu.|,
        q|You... INSERT ANOTHER COIN|,
        q|No. But for aboot tree-fiddy I get you some.|,
        q|Would you rather have the answer that's behind door number three?|,
        q|Not yet|,
        q|No. You don't deserve it.|,
        q|Yes. You've earned it.|,
        q|Hast thou eaten of the tree, whereof I commanded thee that thou shouldest not eat? Damn right you have the Swine Flu!|,
        q|I'm sorry, Dave. I cannot allow this.|,
        q|Yes. You got it from kissing Al Gore.|,
        q|Yes. You got it from kissing Janet Reno.|,
        q|Yes. A tall, dark stranger gave it to you.|,
        q|Yes. It's part of an evil plot by the E2 gods.|,
        q|No.|,
        q|Why does it always have to be about you?|,
        q|No. Nice shoes!|,
        q|Yes. And the horse you rode in on|,
        q|No. You have Avian Flu. Get a clue and know the difference!|,
        q|No. Your biology is too alien to be infected.|,
        q|No. You may be a swine but you're not that kind of swine.|,
        q|No. Just no.|,
        q|No. Have you made your will yet?|,
        q|No. But, if you ask nicely, you can have mine.|,
        q|What, you didn't get yours yet? Here, have some.|,
        q|You sick puppy, you...|,
        q|Who's asking? Oh, it's you, ignorant as usual.|,
        q|I'm not sure. Let's play doctor and find out.|,
        q|What do you mean, SWINE FLU? Omigod, you were with that floozy again!! What did you catch this time? That's it! I'm taking the kids and am going to my mother's!|,
        q|Yes. No. Yes. No. Oh, whatever.|,
        q|Yes. YES. <b>OH GOD YES!</b>|,
        q|Maybe. What's in it for me?|,
        q|I know but I'm not telling.|,
        q|ACCESS DENIED|,
        q|Do I look like a doctor?|,
        q|My sources say no|,
        q|Outlook not so good|,
        q|Signs point to yes|,
        q|I see dead people.|,
        q|"Wouldn't you like to know?|,
        q|No. Swine Flu is not an STD.|,
        q|No. I'd do something about that rash, though.|,
        q|No. You're not smart enough to get it.|,
        q|No.|,
        q|Yes. Now go away.|,
        q|42|,
        q|YES. OH YES! Thank you so much for asking!|,
        q|Whaddaya mean, do you have Swine Flu? If you don't know, who does?|,
        q|What do I care if you have Swine Flu?|,
        q|GUARDS!!!|,
        q|No.|,
        q|Yes. No. What was the question again?|,
        q|No. Can I have your stuff when you die?|,
        q|GET AWAY FROM ME!!!|
    );

    $str .= q|<b><font size='+1'>|.$flu[ int( rand(@flu) ) ] .q|</font></b>|;
    $str .= q|</p>|;
    return $str;
}

sub available_rooms {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my @stuff = (
        q|Yeah, yeah, get a room...|,
        q|I'll take door number three...|,
        q|Hey, that's a llama back there!|,
        q|Three doors, down, on your right, just past [Political Asylum]|,
        q|They can't ALL be locked!?|,
        q|Why be so stuffed up in a room? [Go outside]!|
    );

    my $str =
        q|<p align="center">|
      . ( $stuff[ rand(@stuff) ] )
      . q|</p><br><br>|
      . q|<p align="right">..or you could |
      . linkNode( getNode( 'go outside', 'superdocnolinks' ) )
      . q|</p><br><br>|;

    my $csr = $DB->sqlSelectMany( 'node_id, title',
        'node', 'type_nodetype=' . getId( getType('room') ) );

    my $rooms = {};

    while ( my $ROW = $csr->fetchrow_hashref() ) {
        $rooms->{ lc( $ROW->{title} ) } = $ROW->{node_id};
    }

    $str .= q|<ul>|;

    foreach ( sort( keys %{$rooms} ) ) {
        $str .= q|<li>| . linkNode( getNodeById( $rooms->{$_} ) );
    }

    $str .= q|</ul>|;
    return $str;
}

sub bad_spellings_listing {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str =
q|<p>If you have the option enabled to show <strong>common bad spellings</strong> in your writeups, common bad spellings will be flagged and displayed you are looking at your writeup by itself (as opposed to the e2node, which may contain other noders' writeups).</p>|;
    $str .=
q|<p>This option can be toggled at [Settings[Superdoc]] in the Writeup Hints section. You currently have it |;
    $str .=
      $VARS->{nohintSpelling}
      ? 'disabled, which is not recommended'
      : 'enabled, the recommended setting';
    $str .= q|</p><p>|;

    my $spellInfo = getNode( 'bad spellings en-US', 'setting' );
    return $str . '<strong>Error</strong>: unable to get spelling setting.'
      unless defined $spellInfo;

    my $isRoot = $APP->isAdmin($USER);
    my $isCE   = $APP->isEditor($USER);
    if ($isRoot) {
        $str .=
            '<p>(Site administrators can edit this setting at '
          . linkNode( $spellInfo, 0, { lastnode_id => 0 } )
          . '.)</p><p>';
    }

    $spellInfo = getVars($spellInfo);
    return $str . '<strong>Error</strong>: unable to get spelling information.'
      unless defined $spellInfo;

    #table header
    $str .=
q|Spelling errors and corrections:<table border="1" cellpadding="2" cellspacing="0"><tr><th>invalid</th><th>correction</th></tr>|;

    #table body - wrong spellings to correct spellings
    my $s        = '';
    my $numShown = 0;
    foreach ( sort( keys(%{$spellInfo}) ) ) {
        next if substr( $_, 0, 1 ) eq '_';
        next if $_ eq 'nwing';
        ++$numShown;
        $s = $_;
        $s =~ tr/_/ /;
        $str .= '<tr><td>' . $s . '</td><td>' . $spellInfo->{$_} . '</td></tr>';
    }

    #table footer
    $str .= '</table>';

    $str .= '(' . $numShown . ' entries';
    $str .= ' shown, ' . scalar( keys(%{$spellInfo}) ) . ' total' if $isCE;
    $str .= ')';

    $str .= q|</p>|;
    return $str;
}

sub bestow_easter_eggs {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    return 'Who do you think you are? The Easter Bunny?'
      unless $APP->isAdmin($USER);

    my @params = $query->param;
    my $str    = '';

    my @users = ();
    foreach (@params) {
        if (/^eggUser(\d+)$/) {
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
                'message' => 'Far out! Somebody has given you an [easter egg].',
                'author'  => 'Cool Man Eddie',
            }
        );

        $str .= "User $$U{title} was given one easter egg";

        my $v = getVars($U);
        if ( !exists( $v->{easter_eggs} ) ) {
            $v->{easter_eggs} = 1;
        }
        else {
            $v->{easter_eggs} += 1;
        }

        setVars( $U, $v );
        $str .= "<br />\n";
    }

    # Build the table rows for inputting user names
    my $count = 5;
    $str .= htmlcode('openform');
    $str .= '<table border="1">';
    $str .= "\t<tr><th>Egg these users</th></tr> ";

    for ( my $i = 0 ; $i < $count ; $i++ ) {
        $query->param( "eggUser$i", '' );
        $str .= "\n\t<tr><td>";
        $str .= $query->textfield( "eggUser$i", '', 40, 80 );
        $str .= '</td>';
    }

    $str .= '</table>';

    $str .= htmlcode('closeform');

    if ( $query->param('Give yourself an egg you greedy bastard') ) {
        if ( !exists( $VARS->{easter_eggs} ) ) {
            $VARS->{easter_eggs} = 1;
        }
        else {
            $VARS->{easter_eggs} += 1;
        }
    }

    $str .= htmlcode('openform');
    $str .= $query->submit('Give yourself an egg you greedy bastard');
    $str .= $query->end_form;

    return $str;
}

sub between_the_cracks {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $isGuest = $APP->isGuest($USER);
    return '<p>Undifferentiated from the masses of the streets, you fall between the cracks yourself.</p>' if $isGuest;

    my $rowCtr = 0;

    my ( $title, $queryText, $rows );
    my $count    = 1000;
    my $maxVotes = int( $query->param('mv') );
    my ( $minRep, $repRestriction, $repStr ) = ( undef, '', '' );
    my $resultCtr = 50;

    if ( $maxVotes <= 0 ) {
        $maxVotes = 5;
    }

    if ( defined $query->param('mr') && $query->param('mr') ne '' ) {
        $minRep = int( $query->param('mr') );
        if ( $minRep > 5 || abs($minRep) > ( $maxVotes - 2 ) ) {
            $minRep = undef;
        }

        if ( defined $minRep ) {
            $repRestriction = "AND reputation >= $minRep";
            $repStr         = " and a reputation of $minRep or greater";
        }
    }

    my $str =
qq|<p>These nodes have fallen between the cracks, and seem to have gone unnoticed. This page lists <em>up to</em> $resultCtr writeups that you haven't voted on that have fewer than $maxVotes total vote(s)$repStr on E2. Since they have been neglected until now, why don\'t you visit them and click that vote button?</p>|;
    $str .= q|<form method="get"><div>|;
    $str .= q|<input type="hidden" name="node_id" value="| . getId($NODE) . q|" />|;
    $str .= q|<b>Display writeups with |;

    my @mvChoices = ();

    for ( my $i = 1 ; $i <= 10 ; $i++ ) {
        push @mvChoices, $i;
    }

    $str .= $query->popup_menu( 'mv', \@mvChoices, $maxVotes );
    $str .= ' (or fewer) votes and ';

    my %mrLabels = ();
    my @mrValues = ();

    for ( my $i = -3 ; $i <= 3 ; $i++ ) {
        $mrLabels{$i} = $i;
        push @mrValues, $i;
    }

    $mrLabels{''} = 'no restriction';
    push @mrValues, '';

    $str .= $query->popup_menu(
        -name    => 'mr',
        -labels  => \%mrLabels,
        -default => $minRep,
        -values  => \@mrValues
    );

    $str .= ' (or greater) rep.';

    $str .= q|</b><input type="submit" value="Go" /></div></form>|;
    $str .= q|<table width="100%"><tr><th>#</th><th>Writeup</th><th>Author</th>|;
    $str .= q|<th>Total Votes</th><th>Create Time</th></tr>|;

    $queryText =
      qq|SELECT title, author_user, createtime, writeup_id, totalvotes
    FROM writeup
    JOIN node
      ON writeup.writeup_id = node.node_id
    LEFT OUTER JOIN vote
      ON vote.vote_id = node.node_id AND vote.voter_user = $$USER{user_id}
    WHERE
      node.totalvotes <= $maxVotes
      $repRestriction
      AND node.author_user <> $$USER{user_id}
      AND vote.voter_user IS NULL
      AND wrtype_writeuptype <> 177599
    ORDER BY writeup.writeup_id
    LIMIT $count|;

    $rows = $DB->{dbh}->prepare($queryText);
    $rows->execute() or return $rows->errstr;

    while ( my $wu = $rows->fetchrow_hashref ) {
        $title = $wu->{title};
        if ( $title =~ /^(.*?) \([\w-]+\)$/ ) { $title = $1; }
        $title =~ s/\s/_/g;

        if ( !$APP->isUnvotable( $wu->{writeup_id} ) ) {
            $rowCtr++;
            if ( $rowCtr % 2 == 0 ) {
                $str .= '<tr class="evenrow">';
            }
            else {
                $str .= '<tr class="oddrow">';
            }
            $str .=
              '<td style="text-align:center;padding:0 5px">' . $rowCtr . '</td>
         <td>' . linkNode( $wu->{writeup_id}, '', { lastnode_id => 0 } ) . '</td>
         <td>'
              . linkNode( $wu->{author_user}, '', { lastnode_id => 0 } ) . '</td>
         <td style="text-align:center">' . $wu->{totalvotes} . '</td><td style="text-align:right">' . $wu->{createtime} . '</td></tr>';
        }
        last if ( $rowCtr >= $resultCtr );
    }

    if ( $rowCtr == 0 ) {
        $str .=
            '<tr><td colspan="3"><em>You have voted on all '
          . $count
          . ' writeups with the lowest number of votes.</em></td></tr>';
    }

    return $str;
}

sub blind_voting_booth {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $poweruser = $APP->isEditor($USER);

    my $wu       = undef;
    my $hasvoted = 0;

    my $str =
'Welcome to the blind voting booth.  You can give anonymous feedback without knowing who wrote a writeup here, if you so choose.<br><br>';

    if ( !( $query->param('op') eq 'vote' ) ) {
        return q|You're done for today| if ( $USER->{votesleft} == 0 );

        my $wucount = 0;
        while ( !$wu && $wucount < 30 ) {

            my $limit = $DB->sqlSelect( 'max(writeup_id)', 'writeup' );
            my $min   = $DB->sqlSelect( 'min(writeup_id)', 'writeup' );
            my $rnd   = int( rand( $limit - $min ) );

            $rnd += $min;

            my $maybewu =
              $DB->sqlSelect( 'writeup_id', 'writeup', "writeup_id=$rnd" );

            if ($maybewu) {
                my $tempref = getNodeById($maybewu);

                if (   $tempref->{wrtype_writeuptype} != 177599
                    && $tempref->{author_user} != $USER->{user_id} )
                {
                    $wu = $maybewu if ( !$APP->hasVoted( $tempref, $USER ) );
                }
            }

            $wucount++;
        }

    }
    else {
        my $wutemp = getNodeById( $query->param('votedon') );

        return linkNode( $NODE, 'Try Again' ) unless ($wutemp);
        return linkNode( $NODE, 'Try Again' )
          if ( !$APP->hasVoted( $wutemp, $USER ) );

        $wu       = $query->param('votedon');
        $hasvoted = 1;

    }

    my $rndnode    = getNodeById($wu);
    my $nodeauthor = getNodeById( $rndnode->{author_user} );

    $str .= htmlcode('votehead');
    $str .= '(<b>' . $rndnode->{title} . '</b>) by ';
    if ( $hasvoted == 1 ) {
        $str .= linkNode( getNode( $nodeauthor->{title}, 'user' ),
            $nodeauthor->{title} )
          . ' - ('
          . linkNode( getNodeById( $rndnode->{parent_e2node} ), 'full node' )
          . ')';
    }
    else {
        $str .= '? - ('
          . linkNode( getNodeById( $rndnode->{parent_e2node} ), 'full node' )
          . ')';
    }

    $str .= '<br>';

    if ( $hasvoted == 0 ) {
        $str .=
            '<input type="hidden" name="votedon" value="'
          . $rndnode->{node_id}
          . '"><input type="radio" name="vote__'
          . $rndnode->{node_id}
          . '" value="1"> +<input type="radio" name="vote__'
          . $rndnode->{node_id}
          . '" value="-1"> - '
          . linkNode(
            $NODE,
            'pass on this writeup',
            { garbage => int( rand(100000) ) }
          );
    }
    else {
        $str .= 'Reputation: ' . $rndnode->{reputation};
    }

    $str .= '<br><hr><br>';
    $str .= $rndnode->{doctext};

    if ( $hasvoted == 0 ) {
        $str .=
'<table border="0" width="100%"><tr><td align="left"><INPUT TYPE="submit" NAME="sexisgreat" VALUE="vote!"></td>';
        if ($poweruser) {
            $str .=
'<td align="right"><INPUT TYPE="submit" NAME="node" VALUE="the killing floor II"></td>';
        }

        $str .= '</tr></table></form>';
    }

    $str .= '<br><br><hr><br>' . linkNode( $NODE, 'Another writeup, please' )
      if ( $hasvoted && $USER->{votesleft} != 0 );

    return $str;
}

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

sub buffalo_generator {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my @verbNouns = qw(Buffalo buffalo police bream perch char people dice cod smelt pants);
    my @intermediatePunctuation = ( ',', ';', ',', ':', '...' );
    my @finalPunctuation        = ( '.', '!', '?' );

    my $str      = '';
    my $sentence = '';

    @verbNouns = ('buffalo') if ( $query->param('onlybuffalo') );

    while (1) {
        $sentence = '';
        while (1) {
            $sentence .= $verbNouns[ int( rand(@verbNouns) ) ];
            last if ( rand(1) < 0.1 );
            $sentence .=
              $intermediatePunctuation[ int( rand(@intermediatePunctuation) ) ]
              if ( rand(1) < 0.25 );
            $sentence .= ' ';
        }
        $sentence = ucfirst($sentence);
        $sentence .= $finalPunctuation[ int( rand(@finalPunctuation) ) ] . ' ';
        $str      .= $sentence;
        last if ( rand(1) < 0.4 );
    }

    $str .=
        q|<ul><li>|
      . linkNode( $NODE, 'MOAR', { moar => 'more' } )
      . q|</li>|;
    $str .=
        q|<li>|
      . linkNode( $NODE, 'Only buffalo', { onlybuffalo => 'true' } )
      . q|</li>|;
    $str .=
        q|<li>|
      . linkNodeTitle('Buffalo Haiku Generator|In haiku form')
      . q|</li>|;
    $str .=
      q|<li>|
      . linkNodeTitle('Buffalo buffalo Buffalo buffalo buffalo buffalo Buffalo buffalo|...what?'
      ) . q|</li></ul>|;

    return $str;

}

sub buffalo_haiku_generator {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my @verbNouns = qw(Buffalo buffalo police people bream perch char dice cod smelt pants);
    my @wordLength =
      ( 3, 3, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 );
    my @intermediatePunctuation = ( ',', ';', ',', ':', '...' );
    my @finalPunctuation        = ( '.', '!', '?' );
    my @lineLength              = ( 5,   7,   5 );
    my $str                     = '';
    my $sentence                = '';

    @verbNouns = ('buffalo') if ( $query->param('onlybuffalo') );

    $sentence = '<p style="text-align:center">';
    for ( my $i = 0 ; $i < 3 ; $i++ ) {
        my $syllables = 0;
        while ( $syllables < $lineLength[$i] ) {
            my $wordNumber = ( rand(@verbNouns) );
            if ( $syllables + $wordLength[$wordNumber] > $lineLength[$i] ) {
                $wordNumber =
                  ( 4 + rand( @verbNouns - 4 ) );    # Pick a one-syllable word.
            }
            $syllables += $wordLength[$wordNumber];
            $sentence .= $verbNouns[$wordNumber];
            $sentence .=
              $intermediatePunctuation[ int( rand(@intermediatePunctuation) ) ]
              if ( rand(1) < 0.1 );
            $sentence .= ' ';
        }
        $sentence .= q|<br />|;
    }
    $sentence = ucfirst($sentence);
    $str .= $sentence . q|</p>|;

    $str .=
        q|<ul><li>|
      . linkNode( $NODE, 'Furthermore!', { moar => 'further' } )
      . q|</li>|;
    $str .=
        q|<li>|
      . linkNodeTitle('Buffalo Generator|More buffalo, less haiku')
      . q|</li>|;
    $str .=
      q|<li>|
      . linkNodeTitle(
        'Buffalo buffalo Buffalo buffalo buffalo buffalo Buffalo buffalo')
      . q|</li></ul>|;

    return $str;
}

sub chatterlighter {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $nlid = getNode( 'Notifications', 'nodelet' )->{node_id};
    $PAGELOAD->{pagenodelets} = "$nlid," if $VARS->{nodelets} =~ /\b$nlid\b/;
    $PAGELOAD->{pagenodelets} .= getNode( 'New Writeups', 'nodelet' )->{node_id};

    my $str = insertNodelet( getNode( 'Chatterbox', 'nodelet' ) );
    $str .= q|<span class="instant ajax chatterlight_rooms:updateNodelet:Other+Users"></span>|;
    $str .= q|<div id="chatterlight_rooms">|;
    $str .= q|<p><span title="What chatroom you are in">Now talking in: |;
    $str .= linkNode( $USER->{in_room} ) || 'outside';
    $str .= q|</span> |;
    $str .= htmlcode('changeroom');
    $str .= q|</div>|;

    return $str;
}

sub clientdev_home {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<h2>Registered Clients</h2>|;
    $str .= q|<p>|;
    $str .= q{(See [clientdev: Registering a client|here] for more information as to what this is about)<br />};
    $str .= q|<table border="1" cellpadding="1" cellspacing="0">|;
    $str .= q|<tr><th>title</th><th>version</th></tr>|;

    my @clientdoc = $DB->getNodeWhere( {}, 'e2client', 'title' );
    my $v         = undef;

    foreach (@clientdoc) {
        $v = $_->{'version'};
        $str .=
            '<tr><td>'
          . linkNode($_)
          . '</td><td>'
          . ( ( defined $v ) && length($v) ? encodeHTML( $v, 1 ) : '' )
          . '<td></tr>';
    }

    $str .= '</table>';

    if ( $DB->isApproved( $USER, $NODE ) ) {
        $str .= htmlcode('openform');
        $str .= q|<input type="hidden" name="op" value="new">|;
        $str .= q|<input type="hidden" name="type" value="e2client">|;
        $str .= q|<input type="hidden" name="displaytype" value="edit">|;
        $str .= q|<h2>Register your client:</h2>|;
        $str .= $query->textfield( 'node', '', 25 );
        $str .= htmlcode('closeform');
    }

    $str .= q|</p>|;

    $str .= q|<p>Things to (eventually) come:</p>|;
    $str .= q|<ol><li>make debates work for general groups</li>|;
    $str .= q|<li>list of people, their programming language, the platform, and the project</li>|;
    $str .= q|</ol>|;

    $str .= q|<p>|;
    $str .= htmlcode( 'linkGroupMessages', 'N-Wing' );
    $str .= q|</p>|;

    $str .= q|<p><hr /></p>|;

    my $cd = getNode( 'clientdev', 'usergroup' );
    if ( $DB->isApproved( $USER, $cd ) ) {
        $str .= q|<p>|.htmlcode( 'weblog', "5,$cd->{node_id}" ).q|<p>|;
    }

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

sub cool_archive {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<p>Welcome to the Cool Archive page -- where you can see the entire|;
    $str .= q|library of especially worthwhile content in the mess of Everything history.  Enjoy.|;
    $str .= q|<small>(|;
    $str .= linkNode( getNode( 'Cool Archive Atom Feed', 'ticker' ), 'feed', { lastnode_id => 0 } );
    $str .= q|)</small></p>|;

    $str .= q|<p><strong>NB</strong>: sorting by something other than most recently or oldest C!ed requires entering a user.</p>|;

    $str .= htmlcode('openform');

    my $isEDev  = $APP->isDeveloper($USER);
    my $orderby = $query->param('orderby');
    $orderby = '' if not defined($orderby);

    my $useraction = $query->param('useraction');
    $useraction ||= '';

    my %orderhash = (
        'tstamp DESC'                => 'Most Recently Cooled',   # coolwriteups
        'tstamp ASC'                 => 'Oldest Cooled',          # coolwriteups
        'title ASC'                  => 'Title(needs user)',      # node
        'title DESC'                 => 'Title (Reverse)',        # node
        'reputation DESC, title ASC' => 'Highest Reputation',     # writeup
        'reputation ASC, title ASC'  => 'Lowest Reputation',      # writeup
        'cooled DESC, title ASC'     => 'Most Cooled',            # writeups
    );

    my $offset = $query->param('place');
    $offset ||= 0;

    $orderby = '' unless exists $orderhash{$orderby};

    $orderby ||= 'tstamp DESC';

    my @ordervals = keys %orderhash;

    $str .= 'Order by: '
      . $query->popup_menu( 'orderby', \@ordervals, $orderby, \%orderhash );
    $str .= ' and ';
    my @actions = qw(cooled written);
    $str .= $query->popup_menu( 'useraction', \@actions );
    $str .= ' by user: ';
    $str .= $query->textfield( 'cooluser', '', 15, 30 );

    $str .= htmlcode('closeform');

    my $user = $APP->htmlScreen( scalar $query->param('cooluser') );

 # Select 51 rows so that we know, if 51 come back, we can provide a "next" link
 #  even though we always display 50 at most
    my $pageSize = 50;
    my $limit    = $pageSize + 1;

    my ( $csr, $wherestr, $coolQuery ) = ( undef, undef, undef );

    if ($user) {
        my $U = getNode( $user, 'user' );
        return $str . "<br />Sorry, no '$user' is found on the system!"
          unless $U;

        if ( $useraction eq 'cooled' ) {
            $coolQuery = qq|
        select node.*, writeup.*, cw.*
        from 
         (select * from coolwriteups where cooledby_user = ? ) cw
        inner join node
          on node.node_id = cw.coolwriteups_id
        inner join writeup
          on writeup.writeup_id = node.node_id
        order by $orderby
        limit ?
        offset ?|;

            $csr = $DB->{dbh}->prepare($coolQuery);
            $csr->execute( getId($U), $limit, $offset );

        }
        elsif ( $useraction eq 'written' ) {

            $coolQuery = qq|
        select nd.*, writeup.*, coolwriteups.*
        from 
        (select * from node where author_user = ? ) nd 
        inner join coolwriteups
        on coolwriteups.coolwriteups_id = nd.node_id
        inner join writeup
        on writeup.writeup_id = nd.node_id
        where writeup.cooled != 0
        order by $orderby
        limit ?
        offset ?|;

            $csr = $DB->{dbh}->prepare($coolQuery);
            $csr->execute( getId($U), $limit, $offset );

        }

    }
    elsif ( $orderby =~ /^(title|reputation|cooled) (ASC|DESC)/ ) {

        return $str
          . '<br>To sort by title, reputation, or number of C!s, a user name must be supplied.';

    }
    else {

# Ordered by tstamp
# We can do sorting and limiting in sub-query because it contains our sort field

# We use "bigLimit" instead of the default limit because it's possible for
#  a bunch of cools to point to writeups which no longer exist.  This is our hacky way
#  of making sure paging still works ($limit or more results are necessary to trigger
#  the "next" link) without doing a huge join
        my $bigLimit = 10 * $limit;

        $coolQuery = qq|
      select node.*, writeup.*, cw.*
      from 
      (select * from coolwriteups order by $orderby limit ? offset ? ) cw
      inner join writeup
        on writeup.writeup_id = cw.coolwriteups_id
      inner join node
        on node.node_id = cw.coolwriteups_id|;

        $csr = $DB->{dbh}->prepare($coolQuery);
        $csr->execute( $bigLimit, $offset );

    }

    return encodeHTML($coolQuery) unless $csr;

    $str .= '<table width="100%" cellpadding="0" cellspacing="0">';
    $str .= '<tr>';
    $str .= '<th>Writeup</th><th>Written by</th><th>Cooled By</th></tr>';

    my $count = 0;

    my $rownum = 1;
    while ( my $row = $csr->fetchrow_hashref ) {
        $str .= $APP->cool_archive_row( $row, ( $rownum % 2 ) );
        $rownum++;
    }

    $csr->finish;

    $str .= '<tr><td>';
    $str .= linkNode(
        $NODE,
        "<--last $pageSize",
        {
            orderby    => $orderby,
            cooluser   => $user,
            useraction => $useraction,
            place      => $offset - $pageSize
        }
    ) if $offset >= $pageSize;

    $str .= '</td><td colspan="2" align="right">';
    $str .= linkNode(
        $NODE,
        "next $pageSize-->",
        {
            orderby    => $orderby,
            cooluser   => $user,
            useraction => $useraction,
            place      => $offset + $pageSize
        }
    ) if $count > $pageSize;

    $str .= '</td></tr>';
    $str .= '</table>';
    return $str;

}

sub create_a_registry {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<p>Registries are places where people can share snippets of information about themselves, like their [email address] or [favourite vegetables].</p>|;

    $str .= q|<p>Before you create any new registries, you should have a look at [the registries] we already have.</p>|;

    $str .= htmlcode('openform');

    if ( $query->param('sexisgood') ) {
        return $str;
    }

    if ( $APP->getLevel($USER) < 8 ) {
        return q{You would need to be [The Everything2 Voting/Experience System|level 8] to create a registry.}
          unless $APP->getLevel($USER);

    }

    my $labels = [ 'key', 'value' ];
    my $rows   = [
        {
            'key'   => 'Title',
            'value' =>
              '<input type="text" name="node" size="40" maxlength="255">
      <input type="hidden" name="op" value="new">
      <input type="hidden" name="type" value="registry">
      <input type="hidden" name="displaytype" value="display">'
        },
        {
            'key'   => 'Description',
            'value' =>
              '<textarea name="registry_doctext" rows="7" cols="50"></textarea>'
        },
        {
            'key'   => 'Answer style',
            'value' => $query->popup_menu(
                -name   => 'registry_input_style',
                -values => [ 'text', 'yes/no', 'date' ]
            )
        },
        {
            'key'   => ' ',
            'value' => '<input type="submit" name="sexisgood" value="create">'
        }
    ];
    $str .= $APP->buildTable( $labels, $rows, 'nolabels' );
    $str .= q|</form>|;
    return $str;
}

sub create_category {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<p><b><big>[Everything2 Help] &gt; [Everything2 Categories]</big></b></p>|;

    $str .= q{<p>A [category] is a way to group a list of related nodes. You can create a category that only you can edit, a category that anyone can edit, or a category that can be maintained by any [Everything2 Usergroups|usergroup] you are a member of.</p>};

    $str .= q|<p>The scope of categories is limitless. Some examples might include:</p>|;

    $str .= q|<ul>|;
    $str .= qq|<li>$USER->{title}'s Favorite Movies</li>|;
    $str .= q|<li>The Definitive Guide To Star Trek</li>|;
    $str .= q|<li>Everything2 Memes</li>|;
    $str .= q|<li>Funny Node Titles</li>|;
    $str .= q|<li>The Best Books of All Time</li>|;
    $str .= qq|<li>Albums $USER->{title} Owns</li>|;
    $str .= q|<li>Writeups About Love</li>|;
    $str .= q|<li>Angsty Poetry</li>|;
    $str .= q|<li>Human Diseases</li>|;
    $str .= q|<li>... the list could go on and on</li>|;
    $str .= q|</ul>|;

    $str .= q{<p>Before you create your own category you might want to visit the [Display Categories|category display page] to see if you can contribute to an existing category.</p>};

    my $guestUser = $Everything::CONF->guest_user;
    #
    # Filter people out who can't create categories
    #
    if ( $APP->isGuest($USER) ) {
        $str .= 'You must be [login|logged in] to create a category.';
        return $str;
    }

    if ( $APP->getLevel($USER) <= 1 ) {
        $str .= 'Note that until you are at least Level 2, you can only add your own writeups to categories.';
    }

    # this check may or may not be needed/wanted
    my $userlock =
      $DB->sqlSelectHashref( '*', 'nodelock', "nodelock_node=$$USER{user_id}" );
    if ($userlock) {
        return 'You are forbidden from creating categories.';
    }

    #
    # Output Form
    #

    $str .= $query->start_form;
    $query->param( 'node', '' );
    $str .= '<p><b>Category Name:</b><br />';
    $str .= $query->textfield(
        -name      => 'node',
        -default   => '',
        -size      => 50,
        -maxlength => 255
    );
    $str .= '</p><p><b>Maintainer:</b><br />';

    # Get usergroups current user is a member of
    my $sql = "SELECT DISTINCT ug.node_id,ug.title 
    FROM node ug,nodegroup ng 
    WHERE ng.nodegroup_id=ug.node_id AND ng.node_id=$$USER{user_id} ORDER BY ug.title";
    my $ds = $DB->{dbh}->prepare($sql);
    $ds->execute() or return $ds->errstr;
    my $catType = getId( getType('category') );
    my @vals    = ();
    my %txts    = ();

    # current user
    $txts{ $USER->{user_id} } = "Me ($USER->{title})";
    push @vals, $USER->{user_id};

    # guest user will be used for "Any Noder"
    $txts{$guestUser} = 'Any Noder';
    push @vals, $guestUser;
    while ( my $ug = $ds->fetchrow_hashref ) {
        $txts{ $ug->{node_id} } = $ug->{title} . ' (usergroup)';
        push @vals, $ug->{node_id};
    }

    $str .= $query->popup_menu('maintainer', \@vals, '', \%txts);

    my @customDimensions = htmlcode('customtextarea');

    # clear op which is set to "" on page load
    # also clear 'type' which may have been set to navigate to this page
    $query->delete( 'op', 'type' );

    $str .= '</p>'
      . '<fieldset><legend>Category Description</legend>'
      . $query->textarea(
        -name  => 'category_doctext',
        -id    => 'category_doctext',
        -class => 'formattable',
        @customDimensions
      )
      . '</fieldset>'
      . $query->hidden( -name => 'op',   -value => 'new' )
      . $query->hidden( -name => 'type', -value => $catType );

    $str .= $query->submit( 'createit', 'Create It!');
    $str .= $query->end_form;

    return $str;
}

sub create_room {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $isChanop = $APP->isChanop($USER);

    if (    $APP->getLevel($USER) < $Everything::CONF->create_room_level
        and not $APP->isAdmin($USER)
        and not $isChanop )
    {
        return "<I>Too young, my friend.</I>";
    }

    my $str = "";

    if ( $APP->isSuspended( $USER, 'room' ) ) {
        return
'<h2 class="warning">You\'ve been suspended from creating new rooms!</h2>';
    }

    $query->delete( 'op', 'type', 'node' );
    $str .= $query->start_form;
    $str .= $query->hidden( -name => 'op',   -value => 'new' );
    $str .= $query->hidden( -name => 'type', -value => 'room' );
    $str .= 'Room name: ';
    $str .= $query->textfield( -name => 'node', -size => 28, -maxlenght => 80 );
    $str .= q|<p>And a few words of description: |.$query->textarea( 'room_doctext', '', 5, 60, '', 'wrap=virtual');
    $str .= $query->submit('enter');
    $str .= $query->end_form;

    return $str;
}

sub database_lag_o_meter {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<p>|;

    my %stats = ();
    my %vars  = ();

    my $csr = $DB->{dbh}->prepare('show status');
    $csr->execute;

    while ( my ( $key, $val ) = $csr->fetchrow ) {
        $stats{$key} = $val;
    }

    $csr->finish;
    $csr = $DB->{dbh}->prepare('show variables');
    $csr->execute;
    while ( my ( $key, $val ) = $csr->fetchrow ) {
        $vars{$key} = $val;
    }

    $csr->finish;

    $stats{smq} =
      sprintf( "%.2f", 1000000 * $stats{Slow_queries} / $stats{Queries} );
    my $time = $stats{Uptime};
    my ( $d, $h, $m, $s ) = ( 0, 0, 0, 0 );

    $d    += int( $time / ( 60 * 60 * 24 ) );
    $time -= $d * ( 60 * 60 * 24 );
    $h    += int( $time / ( 60 * 60 ) );
    $time -= $h * ( 60 * 60 );
    $m    += int( $time / (60) );
    $time -= $m * (60);
    $s    += int($time);

    my $uptime = sprintf( "%d+%02d:%02d:%02d", $d, $h, $m, $s );

    $str .=
      "Uptime: $uptime<br>Queries: " . $APP->commifyNumber( $stats{Queries} );
    $str .= "<br>Slow (>$vars{long_query_time} sec): ";
    $str .= $APP->commifyNumber( $stats{Slow_queries} );
    $str .= qq|<br>Slow/Million: $stats{smq}<br>|;

    $str .=
qq|<p>Slow/Million Queries is a decent barometer of how much lag the Database is hitting.  Rising=bad, falling=good.|;
    return $str;
}

sub decloaker {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<p><em>Or to drown my clothes, and say I was stripped.</em> --- [Parolles]</p>|;

    return qq|$str The Treaty of Algeron prohibits your presence.|
      if $APP->isGuest($USER);
    $APP->uncloak( $USER, $VARS );
    $str .= '...like a new-born babe....';

    return $str;
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

sub do_you_c__what_i_c_ {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<h4>What It Does</h4><ul>|;
    $str .= q|<li>Picks up to 100 things you've cooled.</li>|;
    $str .= q|<li>Finds everyone else who has cooled those things, too, then uses the top 20 of those (your "best friends.")</li>|;
    $str .= q|<li>Finds the writeups that have been cooled by your "best friends" the most.</li>|;
    $str .= q|<li>Shows you the top 10 from that list that you haven't voted on and have less than 10C!s.</li>|;
    $str .= q|</ul>|;

    my $user = $query->param('cooluser');
    $str .= htmlcode('openform');
    $str .= q|<p>Or you can enter a user name to see what we think <em>they</em> would like:|
      . $query->textfield( 'cooluser', encodeHTML($user), 15, 30 );
    $str .= htmlcode('closeform') . '</p>';

    my $user_id = $USER->{user_id};

    my $pronoun = 'You';
    if ($user) {
        my $U = getNode( $user, 'user' );
        return
            $str
          . "<br />Sorry, no '"
          . encodeHTML($user)
          . "' is found on the system!"
          unless $U;
        $user_id = $U->{user_id};
        $pronoun = 'They';
    }

    my $numCools    = 100;
    my $numFriends  = 20;
    my $numWriteups = 10;
    my $maxCools    = $query->param('maxcools') || 10;

    my $coolList = $DB->sqlSelectMany( 'coolwriteups_id', 'coolwriteups',
        "cooledby_user=$user_id order by rand() limit $numCools" );
    return $str
      . "$pronoun haven't cooled anything yet. Sorry - you might like to try [The Recommender], which uses bookmarks, instead."
      unless $coolList->rows;

    my @coolStr = ();

    while ( my $c = $coolList->fetchrow_hashref ) {
        push( @coolStr, $$c{coolwriteups_id} );
    }

    my $coolStr = join( ',', @coolStr );

    my $userList = $DB->sqlSelectMany(
        "count(cooledby_user) as ucount, cooledby_user",
        "coolwriteups",
"coolwriteups_id in ($coolStr) and cooledby_user!=$user_id group by cooledby_user order by ucount desc limit $numFriends"
    );

    return $str . "$pronoun don't have any 'best friends' yet. Sorry."
      unless $userList->rows;

    my @userSet = ();

    while ( my $u = $userList->fetchrow_hashref ) {
        push( @userSet, $$u{cooledby_user} );
    }

    my $userStr = join( ',', @userSet );

    my $recSet = $DB->sqlSelectMany(
        "count(coolwriteups_id) as coolcount, coolwriteups_id",
        "coolwriteups",
"(select count(*) from coolwriteups as c1 where c1.coolwriteups_id = coolwriteups.coolwriteups_id and c1.cooledby_user=$user_id)=0 and (select author_user from node where node_id=coolwriteups_id)!=$user_id and cooledby_user in ("
          . $userStr
          . ") group by coolwriteups_id having coolcount>1 order by coolcount desc limit 300"
    );

    my $count = undef;

    while ( my $r = $recSet->fetchrow_hashref ) {
        my $n = getNode( $$r{coolwriteups_id} );
        next unless $$n{type}{title} eq 'writeup';
        next if $APP->hasVoted( $n, $USER );
        next if $$n{author_user} == 176726;    ##Don't show Webby's writeups
        next if $$n{cooled} > $maxCools;
        next unless $n;
        $count++;
        $str .= linkNode($n) . "<br />";
        last if ( $count == $numWriteups );
    }

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

sub drafts_for_review {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    return 'Only [Sign Up|logged-in users] can see drafts.'
      if $APP->isGuest($USER);

    my $review       = getId( getNode( 'review', 'publication_status' ) );
    my @noteResponse = ();
    @noteResponse = (
        ", (Select CONCAT(timestamp, ': ', notetext) From nodenote As response
    Where response.nodenote_nodeid = request.nodenote_nodeid
    And response.timestamp > request.timestamp
    Order By response.timestamp Desc Limit 1) as latestnote,
    (Select count(*) From nodenote As response
    Where response.nodenote_nodeid = request.nodenote_nodeid
    And response.timestamp > request.timestamp) as notecount"
        , "notecount > 0,"
        , '<th align="center" title="node notes">N?</th>'
        , 'notes'
    ) if $APP->isEditor($USER);

    my $drafts = $DB->sqlSelectMany(
        "title, author_user, request.timestamp AS publishtime $noteResponse[0]",
        "draft
    JOIN node on node_id = draft_id
    JOIN nodenote AS request ON draft_id = nodenote_nodeid
    AND request.noter_user = 0
    LEFT JOIN nodenote AS newer
      ON request.nodenote_nodeid = newer.nodenote_nodeid
      AND newer.noter_user = 0
      AND request.timestamp < newer.timestamp"
        , "publication_status = $review
    AND newer.timestamp IS NULL"
        , "ORDER BY $noteResponse[1] request.timestamp"
    );

    my %funx = (
        startline => sub {
            $_[0]->{type}{title} = 'draft';
            '<td>';
        },
        notes => sub {
            $_[0]{latestnote} =~ s/\[user\]//;
            my $note = encodeHTML( $_[0]{latestnote}, 'adv' );
            '<td align="center">'
              . (
                $_[0]{notecount}
                ? linkNode(
                    $_[0],
                    $_[0]{notecount},
                    {
                        '#'    => 'nodenotes',
                        -title => "$_[0]{notecount} notes; latest $note"
                    }
                  )
                : '&nbsp;'
              ) . '</td>';
        }
    );

    return
      "<table><tr><th>Draft</th><th>For review since</th>$noteResponse[2]</tr>"
      . htmlcode(
        'show content', $drafts
        ,               qq!<tr class="&oddrow"> startline, title, byline, "</td>
    <td align='right'>", listdate, "</td>", $noteResponse[3]!,
        %funx
      ) . '</table>';
}

sub duplicates_found_ {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $showTechStuff = 1;       #TODO maybe only show for @$% people later
    my $list          = undef;
    my $author        = '';
    my $lnode         = $query->param('lastnode_id') || 0;
    my $current_user_id = $$USER{node_id};
    my $oddrow        = '';
    my $ONE           = undef;

#TODO - get fancy by also showing dates, if multiple of same type by same author
    foreach my $N ( @{ $$NODE{group} } ) {
        $N = $DB->getNodeById( $N, 'light' );
        next unless canReadNode( $USER, $N );
        $author = $$N{author_user};
        next
          if ( ( $$N{type}{title} eq 'draft' )
            and not $APP->canSeeDraft( $USER, $N, 'find' ) );
        $ONE    = $list ? undef : $N;
        $oddrow = ( $oddrow ? '' : ' class="oddrow"' );
        $list .= "<tr$oddrow>";
        if ($showTechStuff) {
            $list .= '<td>' . $$N{node_id} . '</td>';
        }

        $list .= '<td>'
          . linkNode( $N, '', { lastnode_id => $lnode } )
          . '</td><td>'
          . $$N{type}{title}
          . '</td><td>';

        if ($author) {
            $list .= '<strong>' if $author == $current_user_id;
            $list .= linkNode( $author, '', { lastnode_id => 0 } );
            $list .= '</strong>' if $author == $current_user_id;
        }

        $list .= '<td>' . $$N{createtime} . '</td>';
        $list .= '</td></tr>';
    }

    unless ($list) {
        # Call the nothing_found delegation directly
        if (my $delegation = Everything::Delegation::document->can('nothing_found')) {
            my $nothing_node = getNodeById($Everything::CONF->not_found_node);
            return $delegation->($DB, $query, $nothing_node, $USER, $VARS, $PAGELOAD, $APP);
        }

        # Fallback error if delegation not found
        return '<p>Error: No matches found, and the "nothing_found" delegation is missing.</p>';
    }
    elsif ($ONE) {
        $Everything::HTML::HEADER_PARAMS{-status} = 303;
        $Everything::HTML::HEADER_PARAMS{-location} =
          htmlcode( 'urlToNode', $ONE );
        return;
    }

    my $str =
        '<p><big>Multiple nodes named "'
      . $query->param('node')
      . '" were found:</big></p><table><tr>';

    $str .= '<th>node_id</th>' if $showTechStuff;
    $str .=
      qq|<th>title</th><th>type</th><th>author</th><th>createtime</th></tr>|;
    $str .= $list;
    $str .= qq|</table>|;

    $str .= qq|<p>On Everything2, different things can have the same title.|;
    $str .=
qq| For example, a user could have the name "aardvark", but there could also be a page full of writeups called "[aardvark]".</p>|;
    $str .= qq|<p>If you are looking for information about a topic, choose |;
    $str .=
qq|<strong>e2node</strong>; this is where people's writeups are shown.<br>|;
    $str .=
      qq|If you want to see a user's profile, pick <strong>user</strong>.<br>|;
    $str .=
      qq|Other types of page, such as <strong>superdoc</strong>, are special
and may be interactive or help keep the site running.</p>|;
    return $str;
}

sub e2_acceptable_use_policy {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    return qq|<center><h1>Acceptable Use Policy</h1></center>

<hr />

<p>By using this website, you implicitly agree to the following condition(s):</p>

<ol>
<li>[Be cool]. Do not harass other users in any way (i.e., in the chatterbox, via /msg, in writeups, in the creation of nodeshells or in any other way). "Harassment" is defined as:
  <ul><li>Threatening (an)other user(s) in any way, and/or</li>
      <li>Creating additional accounts intended to annoy other users</li>
  </ul></li>
<li>Do not flood the chatterbox or the New Writeups list ("spamming").</li>
</ol>

<p>By willfully violating (at the discretion of the administration) any of the above condition(s), you may be subjected to the following actions:</p>

<ul>
<li>You may be forbidden from noding for as long as deemed necessary by the administration.</li>
<li>You may be forbidden from using the chatterbox for as long as deemed necessary by the administration.</li>
<li>Your account may be locked and made inaccessible.</li>
<li>Your IP address/hostname may be banned from accessing our webservers.</li>
<li>Depending on the severity of the violation(s), a complaint may be made to your internet service provider.</li>
</ul>

<p>Attempting to circumvent any disciplinary action <b>by any means</b> will most assuredly result in a complaint being made to your internet service provider.</p>

<p><small><small>Last revised: 23 April 2008</small></small></p>|;

}

sub e2_bouncer {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    return "Permission Denied" unless $APP->isChanop($USER);

    my $header = '<p>...a.k.a [Nerf] Borg.</p>';

    $header .= htmlcode( 'openform2', 'bouncer' );

    my @stuff2 = (
        "Yeah, yeah, get a room...",
        "I'll take door number three...",
        "Hey, that's a llama back there!",
        "Three doors, down, on your right, just past [Political Asylum]",
        "They can't ALL be locked!?",
        "Why be so stuffed up in a room? [Go outside]!"
    );

    # $roommenu gets put into the $table
    my $roommenu =
      '<select name="roomname"><option name="outside">outside</option>';

    # The rest of this builds the list of rooms for the bottom.
    my $str2 =
        "<hr><p align=\"center\">"
      . ( $stuff2[ rand(@stuff2) ] )
      . "</p><br>"
      . "<p align=\"left\">Visit room: </p>";

    my $csr2 = $DB->sqlSelectMany( "node_id, title",
        "node", "type_nodetype=" . getId( getType("room") ) );
    my $rooms2 = {};
    while ( my $ROW2 = $csr2->fetchrow_hashref() ) {
        $$rooms2{ lc( $$ROW2{title} ) } = $$ROW2{node_id};
    }

    $str2 .= "<ul><li>[Go Outside|outside]</li>";
    foreach ( sort( keys %$rooms2 ) ) {
        my $nodehash = getNodeById( $$rooms2{$_} );
        $str2 .= "<li>" . linkNode($nodehash);
        $roommenu .=
            '<option name='
          . $nodehash->{'title'} . '>'
          . $nodehash->{'title'}
          . '</option>';
    }

    $roommenu .= '</select>';
    $str2     .= "</ul>";

    my $table =
qq|<table><tr><td valign="top" align="right" width="80"><p>Move user(s)</p>|;
    $table .=
qq|<p><i>Put each username on its own line, and don\'t hardlink them.</i></p>|;
    $table .= qq|</td><td><textarea name="usernames" rows="20" cols="30">|;
    $table .= $query->param('usernames');
    $table .= qq|</textarea></td></tr><tr>|;
    $table .= qq|<td valign="top" align="right">to room</td>|;
    $table .= qq|<td valign="top" align="right">$roommenu</td></tr>|;
    $table .= qq|<tr><td valign="top" colspan="2" align="right">|;
    $table .=
      qq|<input type="submit" name="sexisgood" value="submit" /></form>|;
    $table .= qq|</td></tr></table>|;

    if (   defined $query->param('usernames')
        && defined $query->param('roomname') )
    {
        my $usernames = $query->param('usernames');
        my $roomname  = $query->param('roomname');
        my $room      = getNode( $roomname, 'room' );
        my $str       = '';

        if ( !$room && !( $roomname eq 'outside' ) ) {
            return
                '<p><font color="#c00000">Room <b>"'
              . $roomname
              . '"</b> does not exist.</font></p>';
        }
        elsif ( $roomname eq 'outside' ) {
            $room = 0;
            $str .= "<p>Moving users outside into the main room.</p>\n";
        }
        else {
            $str .=
                "<p>Moving users to room <b>"
              . linkNode( $$room{'node_id'} )
              . ":</b></p>\n";
        }

        # Remove whitespace from beginning and end of each line
        $usernames =~ s/\s*\n\s*/\n/g;

        my @users = split( '\n', $usernames );

        $str .= "<ol>\n";

        my $count = 0;

        foreach my $username (@users) {
            my $user = getNode( $username, 'user' );

            if ($user) {
                $APP->changeRoom( $user, $room );
                $str .= '<li>' . linkNode( $$user{'node_id'} ) . "</li>\n";
            }
            else {
                $str .=
                    "<li><font color=\" #c00000\">User <b>\""
                  . $username
                  . "\"</b> does not exist.</font></li>\n";
            }

            ++$count;
        }

        $str .= "</ol>\n";

        $str .= "<p>No users specified.</p>\n" if ( $count == 0 );

        return $header . $table . $str . $str2;
    }
    else {
        return $header . $table . $str2;
    }

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

sub e2_marble_shop {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str =
qq|<p><big>Yes!<br>We have no marbles!<br>We have no marbles today!</big></p><br><br><p>Thank-you for your custom.</p>|;
    $str .= qq|<p>Please come back the next time you lose them.</p>|;
    return $str;
}

sub e2_penny_jar {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    return
      '<p>You must be logged in to [touch the puppy|touch the pennies].</p>'
      if ( $APP->isGuest($USER) );
    return "Sorry, it seems you are not interested in [GP|pennies] right now."
      if ( $$VARS{GPoptout} );

    my $userGP    = $$USER{GP};
    my $pennynode = getNode( "penny jar", "setting" );
    my $pennies   = getVars($pennynode);
    my $str       = "";

    return
"<p>Sorry, there are no more [GP|pennies] in the jar! Would you like to [Give a penny, take a penny|donate one]?</p>"
      if $$pennies{1} < 1;

    $str .=
"<p>Oh look! It's a jar of [GP|pennies]!</p><p>Would you like to give a penny or take a penny?</p>";

    if ( $query->param('give') ) {
        return "<p>Sorry, you do not have any GP to give!</p>" if $userGP < 1;

        $$pennies{1}++;
        setVars( $pennynode, $pennies );
        $APP->adjustGP( $USER, -1 );
    }

    if ( $query->param('take') ) {
        return
"<p>Sorry, there are no more [GP|pennies] in the jar! Would you like to [Give a penny, take a penny|donate one]?</p>"
          if $$pennies{1} < 1;
        $$pennies{1}--;
        setVars( $pennynode, $pennies );
        $APP->adjustGP( $USER, 1 );
    }

    $str .= $query->start_form();
    $str .= $query->hidden( 'node_id', $$NODE{node_id} );
    $str .=
      $query->submit( 'give', 'The more you give the more you get. Give!' );
    $str .= $query->end_form();

    $str .= $query->start_form();
    $str .= $query->hidden( 'node_id', $$NODE{node_id} );
    $str .= $query->submit( 'take', 'No! Giving is for the weak. Take!' );
    $str .= $query->end_form();

    if ( $$pennies{1} == 1 ) {
        $str .= "<p>There is currently <b>1</b> penny in the penny jar.</p>";
    }
    else {

        if ( $$pennies{1} ) {
            $str .=
                "<p>There are currently <b>"
              . $$pennies{1}
              . "</b> pennies in the penny jar.</p>";
        }
        else {
            $str .= "<p>There are no more pennies in the penny jar!</p>";

        }
    }

    return $str;
}

sub e2_rot13_encoder {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str =
qq|<p>This is the E2 Rot13 Encoder.  It also does decoding.  You can just paste the stuff you want swapped around in the little box and click the buttons. It's really quite simple.  Enjoy!</p>|;

    $str .=
      qq|<form name="myform"><textarea name="rotter" rows="30" cols="80">|;

    my $n = getNodeById( $query->param("lastnode_id") );
    if ( defined($n) and $$n{type}{title} eq "writeup" ) {
        $str .= encodeHTML( $$n{doctext} );
    }
    $str .=
qq|</textarea><br><input type="button" name="e2_rot13_encoder" value="Rot13 Encode"><input type="button" name="e2_rot13_encoder" value="Rot13 Decode"></form><br><br><br><br><br><br><small><p align="right">Thanks to [mblase] for the function update.</p></small>|;

    return $str;
}

sub e2_source_code_formatter {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

#    <!--  wharfinger  11/23/00                                              -->
#    <!--  This "code", such as it is, is in the public domain.              -->
#    <!--  Replace angle-brackets with &lt;/&gt; and square brackets with    -->
#    <!--  &#91;/&#93;                                                       -->

    return q|<script><!--
    function do_fix_brackets( widget, option ) {
        if ( option != 'fix' && option != 'restore' ) {
            window.alert(   'do_fix_brackets( ) error:\n\n' +
                            '    option == "' + option + '"\n\n' +
                            'It must be "fix" or "restore".' );
        } else {
            //  Realistically speaking, we could use any non-'fix' value 
            //  of option to signify 'restore' (I mean, that's what we ARE
            //  doing, right?), but that's ugly. For example, you could 
            //  call "do_fix_brackets( 'foo', 'fixbrackets' )" and have it 
            //  do just the opposite of what it looks like.
            widget.value = ( option == 'fix' )
                                ? fix_brackets( widget.value )
                                : restore_brackets( widget.value );

            widget.select();
            widget.focus();
        }

        return false;   //  Even if this was invoked by a "submit" button,
                        //  don't submit.
    }

    //---------------------------------------------------------------------
    //  Is there any way to pass by reference in JavaScript?
    function fix_brackets( str ) {
        str = str.replace( /\&/g, '&amp;' );
        str = str.replace( /\</g, '&lt;' );
        str = str.replace( /\>/g, '&gt;' );

        //  0x5b is left square bracket; 0x5d is right square bracket.
        //  We do that because E2 will jump to conclusions about what the 
        //  square brackets are for. If we needed the square brackets for 
        //  the set operator, we could do eval( '/\x5b0-9\x5d/g' ) or 
        //  something.
        str = str.replace( /\x5b/g, '&#91;' );
        str = str.replace( /\x5d/g, '&#93;' );

        return str;
    }

    //---------------------------------------------------------------------
    function restore_brackets( str ) {
        str = str.replace( /&lt;/g, '<' );
        str = str.replace( /&gt;/g, '>' );
        str = str.replace( /&amp;/g, '&' );

        //  0x5b is left square bracket; 0x5d is right square bracket.
        //  We do that because E2 will jump to conclusions about what the 
        //  square brackets are for.
        str = str.replace( /&#91;/g, '\x5b' );
        str = str.replace( /&#93;/g, '\x5d' );

        return str;
    }
    --></script>

    <!-- **** HTML **** -->
    <p align="justify">You have fallen into the loving arms of the E2 Source Code 
    Formatter. Just paste your [source code] into the box and click the 
    <b>"Reformat"</b> button, and [Vanna White\|all your dreams will come true].  
    If you don't know (or don't care) what [source code] is, you won't find this 
    thing useful at all. </p>

    <p align="justify">The <b>"Reformat"</b> button replaces [angle bracket]s, 
    [square bracket]s, and [ampersand]s with appropriate [HTML character 
    entities]. <b>"DEformat"</b> changes them back again. </p>

    <p align="justify">Because users' [screen resolution]s vary, we strongly urge 
    you to keep your code &lt;= 80 columns in width so that it doesn't mess with 
    E2's page formatting. If the lines are far too wide, [The Power Structure of Everything 2\|a god] 
    may feel compelled to fix the thing -- and most of our gods are not 
    programmers. To that end, we also strongly encourage you to use spaces 
    instead of tabs: Most browsers display tabs as eight spaces, which increases 
    the line width for no good reason since you probably only want four-space 
    tabs anyway. Even if you don't, you should. Don't start me on about where the 
    braces go. </p>

    <p align="justify">These operations are performed on the entire string, so 
    you'll want to paste in only the actual [source code] part of your [writeup]. 
    You'll need to supply your own <tt>&lt;pre&gt;</tt> [E2 HTML tags\|tag]s as 
    well. I fussed around with making it <tt>&lt;pre&gt;</tt>-aware, but that got 
    painful. </p>

    <dl>
    <dt><b>Other E2 Formatting Utilities:</b></dt>
    <dd><b>[Wharfinger's Linebreaker]:</b> For formatting poetry and [lyric]s.</dd>
    </dl>

    <form name="codefixer">
      <textarea name="edit" cols="80" rows="20"></textarea>

      <br>

      <input type="button" name="submit" value="Reformat" 
        onclick="javascript:do_fix_brackets( document.codefixer.edit, 'fix' )">
      <input type="button" name="submit" value="DEformat" 
        onclick="javascript:do_fix_brackets( document.codefixer.edit, 'restore' )">
      <input type="button" name="clear" value="Clear" 
        onclick="javascript:document.codefixer.edit.value='';">
      </input>
    </form>

    <br><hr>
    <p>Originally by [wharfinger]</p>|;

}

sub e2_sperm_counter {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    #welcome to the E2 sperm counter.
    #We're all not breeding, don't be afraid.

    #Get the number of users on the system.
    my $usrs    = $DB->sqlSelect( "count(*)", "user" );
    my $usrsnow = $DB->sqlSelect( "count(*)", 'room' );

    #85% of our users are male;
    $usrs *= .85;

    #at any particular point, one could have between 1.2 and 1.4 billion sperm
    #so lets do some scientific calculations as to why.

    my $rand  = rand(200000000);
    my $rand2 = rand(200000000);
    $rand  += 1200000000;
    $rand2 += 1200000000;

    $usrs    *= $rand;
    $usrsnow *= $rand2;

    $usrs    = ceil($usrs);
    $usrsnow = ceil($usrsnow);

    $usrs    = reverse("$usrs");
    $usrsnow = reverse("$usrsnow");

    $usrs    =~ s/(\d\d\d)/$&\,/g;
    $usrsnow =~ s/(\d\d\d)/$&\,/g;

    my $c = chop($usrs);
    $usrs .= $c unless ( $c eq "," );

    $c = chop($usrsnow);
    $usrsnow .= $c unless ( $c eq "," );

    $usrs    = reverse($usrs);
    $usrsnow = reverse($usrsnow);

    return
"<p align=\"center\">E2 Users world wide have<br><br> <big><big><big><big><big><big><strong>$usrs</strong></big></big></big></big></big></big><br>sperm swimming around.<br><br>Currently online there are<br><br><big><big><big><big><big><big><strong>$usrsnow</strong></big></big></big></big></big></big><br>being wasted now, as you node.</p>";

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

sub edev_faq {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<!-- NPB TODO make in-page style sheets -->|;

    $str .=
        q|<p>Okey-dokey, here are some FAQs for those in the |
      . linkNode( getNode( 'edev', 'usergroup' ) )
      . q| usergroup.
You, |
      . linkNode( $USER, 0, { lastnode_id => 0 } ) . ', '
      . (
        $APP->isDeveloper( $USER, "nogods" )
        ? '<strong>are</strong> a respected <small>(haha, yeah, right!)</small>'
        : 'are <strong>not</strong> a'
      )
      . q| member of the edev group here, on E2. In this FAQ, "I" is [N-Wing].
</p>|;

    $str .=
q|<p>First: All E2 development is driven out of <a href="https://github.com/everything2/everything2">Github</a>. Anyone there can spin up a development environment, see how it works, submit pull requests, or ask for features that they can work on. There's plenty to chip in on. Check out the <a href="https://github.com/everything2/everything2/issues">open issues</a> and feel free to start contributing.</p>|;

    $str .= q|<p>Questions:</p><ol>|;
    $str .= q|<li><a href="#powers">What are some of my superpowers?</a></li>|;
    $str .=
q|<li><a href="#msg">Why are random people sending me private messages that start with "EDEV:" or "ONO: EDEV:"?</a></li>|;

    $str .=
q|<li><a href="#background">What is the background of edev and it's relationship to the development of the site/source?</a></li>|;
    $str .=
q|<li><a href="#edevify">What is this "Edevify!" link thingy I see in my Epicenter nodelet?</a></li>|;
    $str .=
q|<li><a href="#ownesite">Does everybody have their own Everything site for hacking on?</a></li>|;
    $str .= q|<li><a href="#edevite">What is an edevite?</a></li>|;
    $str .= q|<li><a href="#edevdoc">What is an Edevdoc?</a></li>|;
    $str .=
q|<li><a href="#whyjoin">Why did others (or, why should I) join the edev group?</a></li>|;
    $str .=
q|<li><a href="#improvements">How do we go about finding tasks here? If we have personal projects for the improvement of E2, what is the appropriate way to get started? Should I verify that what I'm thinking of is useful, or should I make it work and then submit source patches?</a></li>|;
    $str .= q|</ol>|;

    $str .=
q|<p><hr /><a name="powers">Q: <strong>What are some of my superpowers?</strong></a><br />|;
    $str .=
q|A: I wouldn't say <em>superpowers</em>, just <em>powers</em>. Anyway:</p>|;
    $str .= q|<ul>|;
    $str .=
q|<li>You're a hash! (in the [Other Users] nodelet, [edevite]s have a <code>%</code> next to their name (which is only viewable by fellow edevites))</li>|;
    $str .=
q|<li>You can see the source code for many things here. If you visit something like a [superdoc] (for example, this node), if you append <code>&amp;displaytype=viewcode</code> to the URL, it will show the code that generates that node. When you have the [Everything Developer] nodelet turned on, you can more easily simply follow the little "viewcode" link (which only displays on nodes you may view the source for). For example, you can see this node's source by going |
      . linkNode( $NODE, 'here', { 'displaytype' => 'viewcode' } )
      . q|</li>|;
    $str .=
q|<li>You can see other random things, like [dbtable]s (nodes and other things (like softlinks) are stored in tables in the database; viewing one shows the field names and storage types) and [theme] (a theme contains information about a generic theme).</li>|;
    $str .=
q|<li>You can see/use [List Nodes of Type], which lists nodes of a certain type. One example <small>(</small>ab<small>)</small>use of this is to get a list of rooms. [nate] in [Edev First Post!] <small>(doesn't that sound like a troll title?)</small> lists some other node types you may be interested in. Actually, you should probably read that anyway, it has other starting information, too.</li>|;
    $str .=
q|<li>You have your own (well, shared with editors and admins) section in [user settings 2]. (As of the time this FAQ was written, there is only 1 setting there, which is explained in the <a href="#msg">next question</a>.)</li>|;
    $str .=
q|<li>You can [Edevify] things. See the <a href="#edevify">later question</a> for more information about this.</li>|;
    $str .= q|</ul>|;

    $str .=
q|<p><hr /><a name="msg">Q: <strong>Why/how are random people sending me private messages that have '([edev])' in front of them?</strong></a><br />|;
    $str .=
q|A (short) : They aren't random people, and they aren't sending to just you.<br />|;
    $str .=
q|A (longer) : When somebody is a member of a [usergroup], they can send a private message to that group, which will then be sent to everybody in that group. In this case, those "random people" are other people in the [edev] usergroup, and they're typing something like this in the chatterbox:<br /><br />|;
    $str .=
q|<code>/msg edev Hi everybody, I'm Doctor Nick! Have you seen [EDev FAQ] yet?</code><br /><br />|;
    $str .=
q|and (assuming the other person is you), everybody in edev would then get a message that looks something like:<br /><br />|;
    $str .= q|<form><input type="checkbox">|;
    $str .=
qq|([edev]) <i> $$USER{title} says</i> Hi everybody, I'm Doctor Nick! Have you seen [EDev FAQ] yet?<br /><br />|;
    $str .=
q|If the <code>/msg</code> is changed to a <code>/msg?</code> instead (with the question mark), then that message is only sent to people that are currently online (which will make the message start with 'ONO: '). For the most part, there isn't much reason to send this type of message in the edev group. For a little more information about this feature, see [online only /msg].|;
    $str .= q|</form></p>|;

    $str .=
q|<p><hr /><a name="background">Q: <strong>What is the background of edev and it's relationship to the development of the site/source?</strong></a><br />|;
    $str .=
q|A: Edev is the coordination list for development of Everything2.com. It is used for discussion of new features or of modifications, or to help people debug their problems. Some code snippets people have written as part of edev have been incorporated into the E2 code here. The main way this happens is by creating Github pull requests.|;
    $str .= q|</p>|;

    $str .=
q|<p><hr /><a name="edevify">Q: <strong>What is this "Edevify!" link thingy I see in my Epicenter nodelet?</strong></a><br />|;
    $str .=
q|A: This simply puts whatever node you're viewing on the [edev] (usergroup) page. About the only time to use this is when you create a normal writeup that is relevant to edev. Note: this does not work on things like "group" nodes, which includes [e2node]s; to "Edevify" your writeup, you must be viewing your writeup alone (the easiest way is to follow the idea/thing link when viewing your writeup from the e2node).|;
    $str .= q|</p>|;

    $str .=
q|<p><hr /><a name="ownesite">Q: <strong>Does everybody have their own Everything site for hacking on?</strong></a><br />
A: Yes! Everything has a development environment that is powered by <a href="https://vagrantup.com">Vagrant</a> and <a href="https://www.virtualbox.org">VirtualBox</a>. Starting up your very own copy of the environment is as simple as installing a couple of pieces of software, cloning the repository, and typing <em>"vagrant up"</em>.|;
    $str .= q|</p>|;

    $str .=
q|<p><hr /><a name="edevite">Q: <strong>What is an edevite?</strong></a><br />|;
    $str .=
q|A: Instead of calling somebody "a member of the [edev] group" or "in the [edev] (user)group", I just call them an "edevite".|;
    $str .= q|</p>|;

    $str .=
q|<p><hr /><a name="edevdoc">Q: <strong>What is an Edevdoc?</strong></a><br />|;
    $str .=
q|A: The [Edevdoc] extends the [document] nodetype, but allows edevites (and only edevites) to create and view it. They are primarily useful in testing out APIs and writing Javascript pieces to test out new interfaces and functionality. You can also do it entirely in the development environment as well.|;
    $str .= q|</p>|;

    $str .=
q|<p><hr /><a name="whyjoin">Q: <strong>Why did others (or, why should I) join the edev group?</strong></a><br />|;
    $str .=
q|A from [anotherone]: I'm in the group because I like to take stuff apart, see how it works. [participate in your own manipulation\|Understand what's going on]. I've had a few of my ideas implemented, and it was cool knowing that I'd dome something useful.<br />|;
    $str .=
q|A from [conform]: I'm interested (for the moment) on working on the theme implementation and I've got some ideas for nodelet UI improvements.<br />|;
    $str .=
q|A from [N-Wing]: I originally (way back in the old days of Everything 1) had fun trying to break/hack E1 (and later E2) (hence my previous E2 goal, "Breaking Everything"). Around the time I decided to start learning some Perl, the edev group was announced, so I was able to learn Perl from working code <strong>and</strong> find more problems in E2 at the same time. (However, it wasn't until later I realized that E2 isn't the best place to start learning Perl from. <tt>:)</tt> )|;
    $str .= q|</p>|;

    $str .=
q|<p><hr /><a name="improvements">Q: <strong>How do we go about finding tasks here? If we have personal projects for the improvement of E2, what is the appropriate way to get started? Should I verify that what I'm thinking of is useful, or should I make it work and then submit source patches?</strong></a><br />|;
    $str .=
q|A: Generally, feel free to post a message to the group or <a href="https://github.com/everything2/everything2/issues">open an issue</a> on the page. </p>|;

    return $str;
}

sub edev_documentation_index {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my @edoc = $DB->getNodeWhere( {}, "edevdoc", "title" );
    my $str  = "";
    foreach (@edoc) {
        $str .= linkNode($_) . "<br>\n";
    }

    $str .= "<p><i>Looks pretty lonely...</i>" if @edoc < 10;

    return $str unless $APP->isDeveloper($USER);

    $str .= htmlcode('openform');
    $str .= "<INPUT type=hidden name=op value=new>\n";
    $str .= "<INPUT type=hidden name=type value=edevdoc>\n";
    $str .= "<INPUT type=hidden name=displaytype value=edit>\n";
    $str .= "<h2>Make that dev doc:</h2>";
    $str .= $query->textfield( 'node', "", 25 );
    $str .= htmlcode('closeform');

    return $str;

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

sub editor_endorsements {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my @grp = (
        @{ getNode( "gods",            "usergroup" )->{group} || []},
        @{ getNode( "Content Editors", "usergroup" )->{group} || []},
        @{ getNode( "exeds",           "nodegroup" )->{group} || []}
    );
    my %except = map { getNode( $_, "user" )->{node_id} => 1 }
      ( "Cool Man Eddie", "EDB", "Webster 1913", "Klaproth" );

    @grp =
      sort { lc( getNodeById($a)->{title} ) cmp lc( getNodeById($b)->{title} ) }
      @grp;
    my $str =
"Select your <b>favorite</b> editor to see what they've [Page of Cool|endorsed]:";

    $str .= htmlcode("openform");
    my $last = 0;
    $str .= "<select name=\"editor\">";
    foreach (@grp) {
        next if $last == $_;
        $last = $_;
        $str .=
            qq|<option value="$_"|
          . ( ( $query->param('editor') . '' eq "$_" ) ? (' SELECTED ') : ('') )
          . '>'
          . getNodeById($_)->{title}
          . q|</option>|
          unless ( $except{$_} )
          or not getNodeById($_)->{type}->{title} eq 'user';
    }
    $str .= q|</select><input type="submit" value="Show Endorsements"></form>|;

    my $ed = $query->param('editor');
    $ed =~ s/[^\d]//g;
    return $str unless $ed && getNodeById($ed)->{type}->{title} eq 'user';

    my $csr = $DB->sqlSelectMany(
        'node_id',
        'links left join node on links.from_node=node_id',
        'linktype='
          . getId( getNode( 'coollink', 'linktype' ) )
          . " and to_node='$ed' order by title"
    );

    my $innerstr = "";
    my $count    = 0;
    while ( my $row = $csr->fetchrow_hashref ) {
        $count++;
        my $n = getNodeById( $$row{node_id} );
        $$n{group} ||= [];
        my $num = scalar( @{ $$n{group} } );
        $innerstr .= "<li>"
          . linkNode($n)
          . (
            ( $$n{type}{title} eq 'e2node' )
            ?       ( " - $num writeup"
                  . ( ( $num == 0 || $num > 1 ) ? ('s') : ('') ) )
            : (" - ($$n{type}{title})")
          ) . "</li>";
    }

    $str .= linkNode( getNodeById($ed) )
      . " has endorsed $count nodes<br><ul>$innerstr</ul>";

    return $str;
}

sub everything_data_pages {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<p>A note to client developers: |;
    $str .=
q|The following are Everything Data Pages (nodetype=<code>fullpage</code>) -- you may write scripts to parse them and provide you with entertaining |;
    $str .=
q|server-side data.  With the [New Nodes XML Ticker] and the [User Search XML Ticker] please don't hit it |;
    $str .=
q|more than every 5 mins, as they are fairly expensive pages.  Please don't hit ANY of the pages more frequently |;
    $str .=
q|than every 30 seconds -- although you may offer a "refresh" button to the users.  I'd prefer not to have tons of inactive users bogging down the server. |;
    $str .=
q|</p><p><a href="headlines.rdf">http://everything2.com/headlines.rdf</a> is the RDF feed of Cool Nodes -- "Cool User Picks!".</p><p>|;

    $str .= '<table><tr><th>title</th><th>node_id</th>';
    my $isRoot = $APP->isAdmin($USER);
    my $isDev  = $isRoot || $APP->isDeveloper($USER);

    $str .= '<th>viewcode</th>' if $isDev;
    $str .= '<th>edit</th>'     if $isRoot;
    $str .= "</tr>\n";

    $str =
        '(<a href='
      . urlGen( { node => 'List Nodes of Type', chosen_type => 'fullpage' } )
      . '>alternate display</a> at [List Nodes of Type])'
      . $str
      if $isDev;

    my @nodes =
      $DB->getNodeWhere( { type_nodetype => getId( getType('fullpage') ) } );
    foreach (@nodes) {
        $str .= '<tr><td>' . linkNode($_) . '</td><td>' . $$_{node_id};
        $str .=
          '</td><td>'
          . linkNode( $_, 'viewcode', { displaytype => 'viewcode' } )
          if $isDev;
        $str .= '</td><td>' . linkNode( $_, 'edit', { displaytype => 'edit' } )
          if $isRoot;
        $str .= "</td></tr>\n";
    }

    $str .= '</table>';

    $str .= q|</p><br><br><hr><br><table>|;

    $str .=
q|These are the second generation tickers, using a more unified XML base, and also exporting information more fully. These are of type [ticker].|;

    @nodes =
      $DB->getNodeWhere( { type_nodetype => getId( getType('ticker') ) } );
    foreach (@nodes) {
        $str .= '<tr><td>' . linkNode($_) . '</td><td>' . $$_{node_id};
        $str .=
          '</td><td>'
          . linkNode( $_, 'viewcode', { displaytype => 'viewcode' } )
          if $isDev;
        $str .= '</td><td>' . linkNode( $_, 'edit', { displaytype => 'edit' } )
          if $isRoot;
        $str .= "</td></tr>\n";
    }

    $str .= q|</table>|;
    return $str;

}

sub everything_finger {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str      = '';
    my $wherestr = '';

    #old way
    unless ( $$VARS{infravision} ) {
        $wherestr .= ' and ' if $wherestr;
        $wherestr .= 'visible=0';
    }

    my $csr =
      $DB->sqlSelectMany( '*', 'room', $wherestr, 'order by experience DESC' );

    $str .=
'<table align="center" width="75%" cellpadding="2" border="1" cellspacing="0"><tr><th>Who</th><th>What</th><th>Where</th></tr>';

    my $uid = undef;           #current display user's ID

    my $newbielook = $APP->isEditor($USER);

    my $flags = "";
    my $num   = 0;
    while ( my $U = $csr->fetchrow_hashref ) {
        $num++;
        $uid = $$U{member_user};
        $str .= '<tr><td>';
        $str .= linkNode( $uid, $$U{nick}, { lastnode_id => 0 } );

        $flags = '';

        $flags .= '<font color="#ff0000">invis</font>' if $$U{visible};

        $flags .= '@' if $APP->isAdmin($uid);
        $flags .= '$'
          if $APP->isEditor( $uid, "nogods" )
          and not $APP->isAdmin($uid);
        $flags .= '%' if $APP->isDeveloper( $uid, "nogods" );

        my $difftime = time() - $U->{unixcreatetime};
        if ( $newbielook and $difftime < 60 * 60 * 24 * 30 ) {
            my $d = sprintf( "%d", $difftime / ( 60 * 60 * 24 ) ) + 1;
            $flags .= '<strong>' if $d <= 3;
            $flags .= $d;
            $flags .= '</strong>' if $d <= 3;
        }

        $str .= '</td><td>' . $flags . '</td><td>';

        $str .= ( $$U{room_id} ) ? linkNode( $$U{room_id} ) : 'outside';
        $str .= "</td></tr>\n";
    }

    $csr->finish;

    $str .= '</table>';

    return '<em>No users are logged in!</em>' unless $num;
    my $intro = "There are currently $num users on Everything2<br>";

    return $intro . $str;

}

sub everything_document_directory {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<style type="text/css">|;
    $str .= q|<!--
    th {
      text-align: left;
    }
    -->
    </style>|;

    $str .= q|<p>|;

    return '<p>Please log in first.</p>' if $APP->isGuest($USER);

    my $isRoot = $APP->isAdmin($USER);
    my $isCE   = $APP->isEditor($USER);
    my $isEDev = $APP->isDeveloper($USER);

    my $showLinkViewcode = $isEDev || $isRoot;
    my $showNodeId       = $isEDev || $isRoot;

    my @types        = ();
    my $filteredType = undef;
    my $pushit       = 0;

    if ( $query->param('filter_nodetype') ) {
        $filteredType = $query->param('filter_nodetype');
        $pushit       = 1;
        if ( ( !$isCE ) && ( $filteredType eq 'oppressor_superdoc' ) ) {
            $pushit = 0;
        }
        elsif ( ( !$isRoot ) && ( $filteredType eq 'restricted_superdoc' ) ) {
            $pushit = 0;
        }
        elsif ( ( !$isEDev ) && ( $filteredType eq 'EDevdoc' ) ) {
            $pushit = 0;
        }

        if ($pushit) {
            push( @types, $filteredType );
        }
    }
    else {
        @types = qw(superdoc document superdocnolinks);
        push( @types, 'oppressor_superdoc' )  if $isCE;
        push( @types, 'restricted_superdoc' ) if $isRoot;
        push( @types, 'restricted_testdoc' )  if $isRoot;
        push( @types, 'Edevdoc' )             if $isEDev;
    }

    foreach (@types) {
        $_ = getId( getType($_) );
    }

    #TODO checkboxes to NOT show things

    my %ids = ( $USER->{node_id} => $USER, $NODE->{node_id} => $NODE );
    local *getNodeFromID = sub {
        my $nid = $_[0];
        return unless ( defined $nid ) && ( $nid =~ /^\d+$/ );

        #already known, return it
        return $ids{$nid} if exists $ids{$nid};

#unknown, find that (we also cache a mis-hit, so we don't try to get it again later)
        my $N = getNodeById($nid);
        return $ids{$nid} = $N;
    };

    my $opt = undef;

    my $choicelist = [
        '0',       'whatever the database feels like',
        'idA',     'node_id, ascending (lowest first)',
        'idD',     'node_id, descending (highest first)',
        'nameA',   'title, ascending (ABC)',
        'nameD',   'title, descending (ZYX)',
        'authorA', 'author\'s ID, ascending (lowest ID first)',
        'authorD', 'author\'s ID, descending (highest ID first)',
        'createA', 'create time, ascending (oldest first)',
        'createD', 'create time, descending (newest first)',
    ];

    $opt .=
        'sort order: '
      . htmlcode( 'varsComboBox', 'EDD_Sort', 0, @$choicelist )
      . "<br />\n";

    $opt .= 'only show things';
    $opt .= ' written by ' . $query->textfield('filter_user') . '<br />';
    $opt .=
        'only show nodes of type'
      . $query->textfield('filter_nodetype')
      . '<br />';

    $str .= q|Choose your poison, sir:<form method="POST">|;
    $str .= qq|<input type="hidden" name="node_id" value="$NODE->{node_id}">|;
    $str .= qq|$opt<input type="submit" value="Fetch!"></form>|;

    my $filterUser =
      ( defined $query->param('filter_user') )
      ? $query->param('filter_user')
      : undef;
    if ( defined $filterUser ) {
        $filterUser =
             getNode( $filterUser, 'user' )
          || getNode( $filterUser, 'usergroup' )
          || undef;
    }

    if ( defined $filterUser ) {
        $filterUser = getId($filterUser);
    }

    #mapping of unsafe VARS sort data into safe SQL
    my %mapVARStoSQL = (
        '0'       => '',
        'idA'     => 'node_id ASC',
        'idD'     => 'node_id DESC',
        'nameA'   => 'title ASC',
        'nameD'   => 'title DESC',
        'authorA' => 'author_user ASC',
        'authorD' => 'author_user DESC',
        'createA' => 'createtime ASC',
        'createD' => 'createtime DESC',
    );

    my $sqlSort = '';
    if ( ( exists $VARS->{EDD_Sort} ) && ( defined $VARS->{EDD_Sort} ) ) {
        if ( exists $mapVARStoSQL{ $VARS->{EDD_Sort} } ) {
            $sqlSort = $mapVARStoSQL{ $VARS->{EDD_Sort} };
        }
    }

    $str .= '<table><tr bgcolor="#dddddd">';
    $str .= '<th class="oddrow"><small><small>viewcode</small></small></th>'
      if $showLinkViewcode;
    $str .=
'<th class="oddrow">title</th><th class="oddrow">author</th><th class="oddrow">type</th><th class="oddrow">created</th>';
    $str .= '<th class="oddrow">node_id</th>' if $showNodeId;
    $str .= '</tr>';

    my @nodes = $DB->getNodeWhere(
        { type_nodetype => \@types, author_user => $filterUser },
        '', $sqlSort );
    my $shown = 0;
    my $limit = $query->param('edd_limit') || 0;
    if ( $limit =~ /^(\d+)$/ ) {
        $limit = $1 || 0;
    }
    else {
        $limit = 0;
    }

    unless ($limit) {

        #default to a reasonable limit if don't specify limit
        $limit = 60;
        $limit += 10 if $isEDev;
        $limit += 10 if $isCE;
        $limit += 10 if $isRoot;
    }

    foreach my $n (@nodes) {
        last if $shown >= $limit;
        ++$shown;
        my $user = getNodeFromID( $n->{author_user} );

        $str .= '<tr><td>';
        $str .=
            '<a href='
          . urlGen( { 'node_id' => $n->{node_id}, 'displaytype' => 'viewcode' } )
          . '>vc</a></td><td>'
          if $showLinkViewcode;
        $str .= linkNode( $n, 0, { lastnode_id => 0 } );
        $str .=
qq|</td><td>$$user{title}</td><td><small>$$n{type}{title}</small></td><td><small>|;
        $str .= htmlcode( 'parsetimestamp', $n->{createtime} . ',1' );
        $str .= '</small></td>';

        if ($showNodeId) {
            $str .= '<td>' . $n->{node_id} . '</td>';
        }

        $str .= '</tr>';
    }

    $str = (
        ( $shown != scalar(@nodes) )
        ? linkNode(
            $NODE, scalar(@nodes),
            { edd_limit => scalar(@nodes), lastnode_id => 0 }
          )
        : $shown
      )
      . ' found, '
      . $shown
      . ' most recent shown.<br />'
      . $str
      . '</table>';

    $str =
        'Lucky you; you also can use <a href='
      . urlGen( { 'node' => 'List Nodes of Type', 'type' => 'superdoc' } )
      . '>List Nodes of Type</a>,</p><p>'
      . $str
      if ( $isEDev || $isCE );

    $str .= q|</p>|;
    return $str;

}

sub everything_i_ching {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my %figures = (
        'BBBBFB' => 'Shih, the army',
        'BFBBBB' => 'Pi, holding together (union)',
        'FFBFFF' => 'Hsiao Ch\'u, the taming power of the small',
        'FFFBFF' => 'Lu, treading (conduct)',
        'BBBFFF' => 'T\'ai, peace',
        'FFFBBB' => 'P\'i, standstill (stagnation)',
        'FFFFBF' => 'T\'ung Jo e\'n, fellowship with men',
        'FBFFFF' => 'Ta Yu, possession in great measure',
        'BBBFBB' => 'Ch\'ien, Modesty',
        'BBFBBB' => 'Yu, enthusiasm',
        'BFFBBF' => 'Sui, following',
        'FBBFFB' => 'Ku, Work on What Has Been Spoiled (Decay)',
        'FBFBBF' => 'Shih Ho, biting through',
        'FBBFBF' => 'Pi, grace',
        'FBBBBB' => 'Po, splitting apart',
        'BBBBBF' => 'Fu, return, the turning point',
        'BFFFBB' => 'Hsien, influence (wooing)',
        'BBFFFB' => 'Ho\' e\'ng, duration',
        'FBBBFF' => 'Sun, decrease',
        'FFBBBF' => 'I, increase',
        'BFFFFF' => 'Kuai, break-through (resoluteness)',
        'FFFFFB' => 'Kou, coming to meet',
        'BFFBFB' => 'K\'un, oppression (exhaustion)',
        'BFBFFB' => 'Ching, the well',
        'FFBFBB' => 'Chien, development (gradual progress)',
        'BBFBFF' => 'Kuei Mei, the marrying maiden',
        'BBFFBF' => 'Fo\'^e\'ng, abundance (fullness)',
        'FBFFBB' => 'Lu, the wanderer',
        'FFBBFB' => 'Huan, dispersion (dissolution)',
        'BFBBFF' => 'Chieh, limitation',
        'BFBFBF' => 'Chi Chi, after completion',
        'FFFFFF' => 'Ch\'ien, the creative',
        'BBBBBB' => 'K\'un, the receptive',
        'BFBBBF' => 'Chun, difficulty at the beginning',
        'FBBBFB' => 'Mo\'eng, youthful folly',
        'BFBFFF' => 'Hsu, waiting (nourishment)',
        'FFFBFB' => 'Sung, conflict',
        'BBBBFF' => 'Lin, approach',
        'FFBBBB' => 'Kuan, contemplation (view)',
        'FFFBBF' => 'Wu Wang, innocence (the unexpected)',
        'FBBFFF' => 'Ta Ch\'u, the taming power of the great',
        'FBBBBF' => 'I, the corners of the mouth (providing nourishment)',
        'BFFFFB' => 'Ta Kuo, preponderance of the great',
        'BFBBFB' => 'K\'an, the abysmal (water)',
        'FBFFBF' => 'Li, the clinging (fire)',
        'FFFFBB' => 'Tun, retreat',
        'BBFFFF' => 'Ta Chuang, the power of the great',
        'FBFBBB' => 'Chin, progress',
        'BBBFBF' => 'Ming I, darkening of the light',
        'FFBFBF' => 'Chai Jo\' e\'n, the family (the clan)',
        'FBFBFF' => 'K\'uei, opposition',
        'BFBFBB' => 'Chien, obstruction',
        'BBFBFB' => 'Hsieh, deliverence',
        'BFFBBB' => 'Ts\'ui, gathering together (massing)',
        'BBBFFB' => 'Sho\'^e\'ng, pushing upward',
        'BFFFBF' => 'Ko, revolution (molting)',
        'FBFFFB' => 'Ting, the caldron',
        'BBFBBF' => 'Cho\'^e\'n, the arousing (shock, thunder)',
        'FBBFBB' => 'Ko\'^e\'n, keeping still, mountain',
        'FFBFFB' => 'Sun, the gentle (the penetrating, wind)',
        'BFFBFF' => 'Tui, the joyous (lake)',
        'FFBBFF' => 'Chung Fu, inner truth',
        'BBFFBB' => 'Hsiao Kuo, preponderance of the small'
    );

    #coin method

    my @pset = qw(B F B F);
    my @sset = qw(F F B B);

    my $primary   = '';
    my $secondary = '';
    while ( length($primary) < 6 ) {
        my $coins = int( rand(2) ) + int( rand(2) ) + int( rand(2) );

        $primary   .= $pset[$coins];
        $secondary .= $sset[$coins];

    }

    my $PNODE = getNode( $figures{$primary}, 'e2node' );
    return "$figures{$primary} not found!" unless $PNODE;
    my $PWRITEUP = getNodeById( $PNODE->{group}[0] );

    my $SNODE = getNode( $figures{$secondary}, 'e2node' );
    return "$figures{$secondary} not found!" unless $SNODE;
    my $SWRITEUP = getNodeById( $SNODE->{group}[0] );

    my $str = '';

    $str .= q|<table width=100% border=0 cellpadding=3 cellspacing=1>|;
    $str .=
q|<tr><th width=50%>Primary Hexagram</th><th width=50%>Secondary Hexagram</th></tr>|;
    $str .= q|<tr><td width="50%" valign="top">|;

    $str .=
      "<center>" . linkNode($PNODE) . q|</center></td><td width="50%" valign="top">|;
    $str .= "<center>" . linkNode($SNODE) . "</center></tr>";

    $str .= q|<tr bgcolor="black"><td colspan="2">|;
    $str .=
q|<table width="100%" bgcolor="black" cellpadding="2" cellspacing="0"><tr><td align="center" width="50%">|;
    $str .=
      htmlcode( 'generatehex', $primary ) . q|</td><td width="50%" align="center">|;
    $str .= htmlcode( 'generatehex', $secondary ) . q|</td></tr></table>|;

    $str .= q|</td></tr><tr><td valign="top" width="50%">|;
    $str .= q|<p>|.parseLinks( $PWRITEUP->{doctext} );
    $str .= q|</td><td valign="top" width="50%">|;
    $str .= q|<p>|.parseLinks( $SWRITEUP->{doctext} );

    $str .= "</td></tr></table>";

    $str .= q|<br><p align=right>|;
    $str .=
q|<i>The [Everything I Ching] is brought to you by [The Gilded Frame] and [nate]</i>|;
    $str .=
        q|<p align=center><font size=5>|
      . linkNode( $NODE, 're-divine' )
      . q|</font>|;

    return $str;
}

sub everything_poll_archive {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $numtoshow = 10;
    my $startat   = int( $query->param('startat') ) || 0;

    my @polls = $DB->getNodeWhere( { poll_status => 'closed' },
        'e2poll', "e2poll_id DESC LIMIT $startat, $numtoshow" );

    my $str = '<ul>';

    foreach (@polls) {
        $str .= '<li>' . htmlcode( 'showpoll', $_ ) . '</li>';
    }

    $str .= '</ul>';

    my $PrevLink = '';
    $PrevLink =
      linkNode( $NODE, 'previous', { startat => $startat - $numtoshow } )
      if $startat;
    my $NextLink = '';
    $NextLink = linkNode( $NODE, 'next', { startat => $startat + $numtoshow } )
      if scalar @polls == $numtoshow;

    $str .= qq'<p align="right" class="pagination">$PrevLink $NextLink</p>';

    return $str;

}

sub everything_poll_creator {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $pollgod      = 'mauler';
    my $turnPollsOff = 0;
    return 'Sorry, poll creation has been temporarily disabled.'
      if ($turnPollsOff);

    #new restrict check for any usergroup
    my $isRoot = $APP->isAdmin($USER);

#my $userlevel=$APP->getLevel($USER);
#return 'You must be Level 3 to create polls. Sorry.' if (($userlevel<3)&&(!$isRoot));

    my $str = q|<h3>Important! Read this or weep!</h3>|;
    $str .= q|<ul>|;
    $str .=
q|<li>Welcome to the E2 Poll Creator! Please use this form to create a poll on any topic that interests you. Please do not abuse this privilege</li>|;
    $str .=
q|<li>By default, all polls have a "None of the above" option at the end. Be imaginative and use as many of the available option slots as possible so that it will not be needed.</li>|;
    $str .=
qq|<li>People cannot vote on a poll until the current poll god, [$pollgod\[user]], has made it the [Everything User Poll[superdoc]\|Current User Poll].</li>|;
    $str .=
q|<li>Old completed polls are at the [Everything Poll Archive[superdoc]]. New polls in the queue for posting are at [Everything Poll Directory[superdoc]]. For more information, see [Polls[by Virgil]]. </li>|;
    $str .=
qq|<li>If you accidentally stumbit a poll before it is complete, /msg [$pollgod\[user]], who will delete it.</li>|;
    $str .=
q|<li>You cannot create a poll without a question, without a title, or with the same title as an existing poll.</li>|;
    $str .=
q|</ul><form name="pollmaker" method="post"><input type="hidden" name="op" value="new">|;
    $str .=
q|<input type="hidden" name="type" value="e2poll"><fieldset><legend>Sumbit a new poll</legend><table>|;
    $str .= q|<tr><th align="right">Title:</th>|;
    $str .=
q|<td><input type="text" size="50" maxlength="64" name="node" value=""></td>|;
    $str .= q|</tr>|;
    $str .= q|<tr><th align="right">Question:</th>|;
    $str .=
q|<td><input type="text" size="50" maxlength="255" name="e2poll_question" value=""></td>|;
    $str .= q|</tr>|;
    $str .= q|<tr><th align="left" colspan="2">Answers:</th></tr>|;

    for ( 1 .. 12 ) {
        $str .= qq|<tr><th align="right">$_:</th>|;
        $str .=
qq|<td> <input type="text" size="50" maxlength="255" name="option$_" value=""></td>|;
        $str .= qq|</tr>|;
    }

    $str .= q|<tr><th>And finally:</th><td>None of the above</td></tr>|;
    $str .=
      q|</table><input type="submit" value="Create Poll"></fieldset></form>|;

    return $str;
}

sub everything_poll_directory {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $isRoot = $APP->isAdmin($USER);

    my $dailypoll = '';
    $dailypoll = $query->param('dailypoll') if $isRoot;
    my $poll_id          = $query->param('poll_id');
    my $oldpolls         = $query->param('oldpolls') || 0;
    my $pollfilter       = undef;
    my $pollLink         = '';
    my %oldPollParameter = ();

    if ($oldpolls) {
        $pollLink         = linkNode( $NODE->{node_id}, 'Hide old polls' );
        %oldPollParameter = ( oldpolls => 1 );
    }
    else {
        $pollfilter = { 'poll_status !' => 'closed' };
        $pollLink =
          linkNode( $NODE->{node_id}, 'Show old polls', { oldpolls => 1 } );
    }

    if ($dailypoll) {
        $DB->sqlUpdate( 'e2poll', { poll_status => 'closed' },
            q|poll_status='current'| );
        $DB->sqlUpdate( 'e2poll', { poll_status => 'current' },
            qq|e2poll_id=$poll_id| );

        htmlcode( 'addNotification', 'e2poll', '', { e2poll_id => $poll_id } );
    }

    my ( $PrevLink, $NextLink ) = ( '', '' );
    my $numtoshow = 8;

    my $startat = $query->param('startat') || 0;
    if ($startat) {
        my $finishat = $startat - $numtoshow;
        $PrevLink = linkNode( $NODE, 'previous',
            { startat => $finishat, %oldPollParameter } );
    }

    my @nodes = $DB->getNodeWhere( $pollfilter, 'e2poll',
        "e2poll_id DESC LIMIT $startat, $numtoshow" );
    my $str = "";

    $str .= '<p>Go to the <b>'
      . linkNodeTitle('Everything User Poll[superdoc]') . '</b>.';
    $str .= '</p><p>' . $pollLink . '.' if $isRoot;
    $str .= '</p><ul>';

    foreach my $n (@nodes) {
        getRef $n;
        $str .= '<li>' . htmlcode( 'showpoll', $n, 'show status' );

        if ($isRoot) {
            $str .= '<p>'
              . (
                $n->{poll_status} ne 'current'
                ? linkNode( $NODE->{node_id}, 'make current',
                    { poll_id => $n->{node_id}, dailypoll => 1 } )
                  . ' | '
                : ''
              )
              . linkNode( $n, 'edit', { displaytype => 'edit' } ) . ' | '
              . linkNode( $n, 'delete',
                { node_id => $n->{node_id}, confirmop => 'nuke' } )
              . '</p>';
        }

        $str .= '</li>';
    }

    if ( scalar @nodes == $numtoshow ) {
        $NextLink = linkNode( $NODE, 'next',
            { startat => $startat + $numtoshow, %oldPollParameter } );
    }

    $str .=
      qq'</ul><p align="right" class="pagination">$PrevLink $NextLink</p>';
    return $str;

}

sub everything_quote_server {
    return q|<br><br><b><font size="3"><div id="quoteserver" align="center"></div></font></b><br><br><br>|;
}

sub everything_user_poll {
    return htmlcode('showcurrentpoll');
}

sub everything_user_search {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str =
      q|<p>Here you can list all the writeups contributed by any user.</p>|;

    $str .= htmlcode( 'openform', '-method', 'get' );

    $str .= q|<fieldset><legend>Choose user</legend>|;
    $str .= q|<label>User name:|;

    my @friends = (
        'lawnjart',      'clampe',
        'dem bones',     'Jet-Poop',
        'dannye',        'sensei',
        'jessicapierce', 'junkpile',
        'Lord Brawl',    'ToasterLeavings',
        'wharfinger',    'Lometa',
        'riverrun',      'jaybonci',
        'Quizro',        'Demeter',
        'ideath',        'dann',
        'Evil Catullus', 'Mr. Hotel',
        'Roninspoon',    'wertperch',
        'anthropod',     'Professor Pi',
        'Igloowhite',    'iceowl',
        'panamaus',      'sid',
        'Oolong',        'mauler',
        'aneurin',       'Wiccanpiper',
        'avalyn',        'TheDeadGuy',
        'The Debutante', 'LaggedyAnne',
        'Junkill',       'Jack',
        'Timeshredder',  'Noung',
        'The Custodian', 'Tem42',
        'Aerobe',        'Auspice'
    );

    my $friend = $query->param('usersearch');

    $friend ||= $friends[ rand(@friends) ];

    $str .=
      $query->textfield( 'usersearch', $friend ) . $query->hidden('showquery');

    $str .= q|</label>|;

    $str .= q|<label>Order By:|;

    my $choices = [
        'writeup.publishtime DESC',
        'writeup.publishtime ASC',
        'node.title ASC',
        'node.title DESC',
        'node.reputation DESC',
        'node.reputation ASC',
        'writeup.wrtype_writeuptype ASC',
        'writeup.wrtype_writeuptype DESC',
        'length(node.title) ASC',
        'length(node.title) DESC',
        'node.hits ASC',
        'node.hits DESC',
        'RAND()'
    ];

    my $labels = {
        'writeup.publishtime DESC' => 'Age, Newest First',
        'writeup.publishtime ASC'  => 'Age, Oldest First',
        'node.title ASC'           => 'Title, Forwards (...012...ABC...)',
        'node.title DESC'          => 'Title, Backwards (...ZYX...210...)',
        'node.reputation DESC'     => 'Reputation, Highest First',
        'node.reputation ASC'      => 'Reputation, Lowest First',
        'writeup.wrtype_writeuptype ASC' =>
          'Type (person, thing, idea, place, ...)',
        'writeup.wrtype_writeuptype DESC' =>
          'Type (..., place, idea, thing, person)',
        'length(node.title) ASC'  => 'Title Length, Shortest First',
        'length(node.title) DESC' => 'Title Length, Longest First',
        'node.hits DESC'          => 'Times Viewed, Most First',
        'node.hits ASC'           => 'Times Viewed, Least First',
        'RAND()'                  => 'Random'
    };

    # while we have the options, check parameter validity:
    # don't let user execute arbitrary SQL -- VERY BAD

    $query->delete('orderby')
      if $query->param('orderby')
      and not $labels->{ $query->param('orderby') };

    $str .= $query->hidden('filterhidden')
      . $query->popup_menu(
        -name    => 'orderby',
        -values  => $choices,
        -labels  => $labels,
        -default => 'writeup.publishtime DESC'
      );

    $str .= q|</label>|;

    $str .=
      q|<input type="submit" name="submit" value="submit"></fieldset></form>|;

    # keep all necessary parameters in %params hash for sort/filter links
    my %params = $query->Vars();
    my $us =
      $APP->htmlScreen( $params{usersearch} );    #user's title to find WUs on

    unless ($us) {
        $str .= '<p>Please give a user name.</p>';
    }
    else {
        #quit if invalid user given
        my $user = getNode( $us, 'user' );

        unless ($user) {
            $str .=
                'It seems that the user "'
              . $us
              . '" doesn\'t exist... how very, very strange... (Did you type their name correctly?)';
        }
        else {

            if ( $user->{title} eq 'EDB' ) {
                $str .=
'<p align="center"><big><big><strong>G r o w l [EDB reads his Message Inbox|!]</strong></big></big>';
            }
            else {

                # constants
                my $typeID = getId( getType('writeup') )
                  or return "Ack! Can't get writeup nodetype.";
                my $perpage = 50;    # number to show at a time

                my $uid = getId($user);       # lowercase = user searching on
                my $viewing_user_id = $$USER{node_id};    # user that is viewing
                my $isRoot  = $APP->isAdmin($USER);
                my $isEd    = $APP->isEditor($USER);
                my $isMe    = ( $uid == $viewing_user_id ) && ( $uid != 0 );
                my $rep     = $isMe || $isEd;
                my $isGuest = $APP->isGuest($USER);

         # remove url-derived and other superfluous parameters, include defaults
                delete @params{qw(node node_id type op submit)};
                delete $params{page}
                  unless ( defined( $params{page} ) and $params{page} > 1 );
                $params{usersearch} = $user->{title}; # clean/right case for links
                $params{orderby} ||= 'writeup.publishtime DESC';

                $params{filterhidden} = 0
                  if not defined( $params{filterhidden} );
                $params{filterhidden} = ( 0, 1, 2 )[ int $params{filterhidden} ]
                  if $rep;

                # set up query
                my $edSelect = '';
                $edSelect = ", (SELECT 1 FROM nodenote
          WHERE nodenote.noter_user != 0
          AND (nodenote.nodenote_nodeid = node.node_id
          OR nodenote.nodenote_nodeid = writeup.parent_e2node)
          LIMIT 1 ) AS hasnote" if $isEd;

                my ( $voteSelect, $voteJoin ) = ( '', '' );
                ( $voteSelect, $voteJoin ) = (
                    ', vote.weight',
"LEFT OUTER JOIN vote ON vote.voter_user = $viewing_user_id AND vote.vote_id = node.node_id"
                ) unless $isGuest;

                my ( $filter, $showFilter ) = ( '', '' );
                ( $filter, $showFilter ) = (
                    'AND writeup.notnew '
                      . ( '= 0', '!= 0' )[ $params{filterhidden} - 1 ],
                    ' published '
                      . ('not ')[ $params{filterhidden} - 1 ]
                      . 'hidden'
                ) if $params{filterhidden};

                my @sqlQuery = (
                    "node.node_id, writeup.parent_e2node, writeup.cooled,
            type.title AS type_title, node.reputation, writeup.notnew, writeup.publishtime,
            $uid AS author_user
            $voteSelect
            $edSelect",
                    "node LEFT OUTER JOIN writeup
            ON writeup.writeup_id = node.node_id $voteJoin
            JOIN node AS type ON type.node_id=writeup.wrtype_writeuptype",
                    "node.author_user = $uid
            AND node.type_nodetype = $typeID $filter",
                    "ORDER BY $params{orderby}, node.node_id ASC LIMIT $perpage"
                );

                # utility functions for display
                my $tweakedLink = sub {

# returns a sorting link with the current parameters, as overridden by given values
# arguments:
# $text - link text
# $settings - hash ref of override values

                    my ( $text, $settings ) = @_;
                    delete $$settings{page}
                      unless ( defined( $$settings{page} )
                        and $$settings{page} > 1 );

                    return "<strong>$text</strong>"
                      unless scalar
                      map { $$settings{$_} ne $params{$_} ? 1 : () }
                      keys %$settings;

                    my %linkParams = %params;
                    @linkParams{ keys %$settings } =
                      @$settings{ keys %$settings };
                    return linkNode( $NODE, $text, \%linkParams );
                };

                my $sortLink = sub {

                    # returns a heading sort up/down choice

                    my ( $disp1, $disp2, $orderField, $backwards ) = @_;
                    my ( $sort1, $sort2 ) =
                      ( "$orderField ASC", "$orderField DESC" );
                    ( $sort1, $sort2 ) = ( $sort2, $sort1 ) if $backwards;

                    return &$tweakedLink( $disp1, { orderby => $sort1 } ) . '/'
                      . &$tweakedLink( $disp2, { orderby => $sort2 } );
                };

                # header
                my $head = '';
                $head =
                    '<h2>query arguments:</h2><pre>'
                  . encodeHTML( join "\n,\n", @sqlQuery )
                  . '</pre>'
                  if $isRoot && $params{showquery};

                if ($rep) {

                    # explain extra information, and offer choice based on it
                    $head .=
qq!<p><small>Writeups published with '<em>Don't display in "New Writeups"</em>' checked have "H" for <strong>h</strong>idden in the "H" column.!;
                    $head .=
                      ' Writeups with node notes have "N" in the "HN" column.'
                      if $isEd;
                    $head .=
                        '</small></p><p>Show: '
                      . &$tweakedLink( 'all writeups', { filterhidden => 0 } )
                      . ', '
                      . &$tweakedLink( 'only unhidden writeups',
                        { filterhidden => 1 } )
                      . ', '
                      . &$tweakedLink( 'only hidden writeups',
                        { filterhidden => 2 } )
                      . '</p>';
                }

# build table header row, sort row and instructions for content rows in parallel

                # defining width here stops IE7 wrapping later
                my $thRow =
'<tr><th align="center"><abbr title="Cools" style="width:2em">C!s</abbr></th><th align="left">Writeup Title (type)</th>';

                my $sortRow =
                    '<tr><td>&nbsp;</td><td align="left"><small>'
                  . &$sortLink( 'forwards', 'backwards', 'node.title' )
                  . '</small></td>';

                my $instructions =
'<tr class="&oddrow">c, "<td align=\'left\'>", parenttitle, type, "</td>"';

                my %funx = (
                    c => sub {
                        my $cMsg     = '&nbsp;';
                        my $numCools = $_[0]->{cooled};
                        if ($numCools) {
                            $cMsg = "${numCools}C!";
                            $cMsg .= 's' if $numCools > 1;
                            $cMsg = "<strong>$cMsg</strong>";
                        }
                        return '<td align="center">' . $cMsg . '</td>';
                    }
                );

                if ($rep) {
                    $thRow .=
'<th colspan="2" align="center"><abbr title="Reputation">Rep</abbr></th>';
                    $sortRow .=
                        '<td colspan="2" align="center"><small>'
                      . &$sortLink( 'inc', 'dec', 'node.reputation' )
                      . '</small></td>';
                    $instructions .= ',rep';
                    $funx{rep} = sub {
                        my $wu = shift;
                        my $r  = $$wu{reputation} || 0;

                        my $votescast = $DB->{dbh}->selectall_hashref(
                            "SELECT weight, COUNT(voter_user) AS total
              FROM vote
              WHERE vote_id = $$wu{node_id}
              GROUP BY weight", 'weight'
                        );

                        my $p = $votescast->{1}->{total}  || 0;
                        my $m = $votescast->{-1}->{total} || 0;

                        return
qq'<td class="reputation">$r</td><td class="reputation"><small>+$p/-$m</small></td>';
                    };
                }

                unless ( $isMe || $isGuest ) {
                    $thRow   .= '<th><abbr title="Your vote">Vote</abbr></th>';
                    $sortRow .= '<td>&nbsp;</td>';
                    $instructions .= ',vote';
                    $funx{vote} = sub {
                        '<td align="center">'
                          . ( '-', '&nbsp;', '+' )[
                          (
                              defined( $_[0]->{weight} )
                              ? ( $_[0]->{weight} + 1 )
                              : (1)
                          )
                          ]
                          . '</td>';
                    };
                }

                if ($rep) {
                    $thRow .= '<th><abbr title="H=Hidden';
                    my $flags = 'H';
                    $sortRow      .= '<td>&nbsp;</td>';
                    $instructions .= ',hn';
                    $funx{hn} = sub {
                        '<td align="center">'
                          . ( $_[0]->{notnew}  ? 'H' : '' )
                          . ( $_[0]->{hasnote} ? 'N' : '' ) . '</td>';
                    };

                    if ($isEd) {
                        $thRow .= ', N=Has node note';
                        $flags .= 'N';
                    }

                    $thRow .= qq'">$flags</abbr></th>';
                }

                $thRow .= '<th align="center">Published</th></tr>';
                $sortRow .=
                    '<td align="center"><small>'
                  . &$sortLink( 'newest', 'oldest', 'writeup.publishtime', 1 )
                  . ' first</small></td></tr>';
                $instructions .=
                  ', "<td align=\'right\'><small>", listdate , "</small></td>"';

                # get it...
                my ( $wulist, $pages, $countWUs, $startRow, $lastRow ) =
                  htmlcode( 'show paged content',
                    @sqlQuery, $instructions, %funx );

                my $userHas = $isMe ? 'You have' : linkNode($user) . ' has';

                unless ($countWUs) {
                    $str .= "$head<p>$userHas no writeups$showFilter.</p>";
                }
                else {
                    $countWUs =
                      ( $countWUs == 1 ? 'one writeup' : "$countWUs writeups" )
                      . $showFilter
                      . (
                        $countWUs > $perpage
                        ? ". Showing writeups $startRow to $lastRow"
                        : ''
                      );
                }

                $str .= "$head<p>$userHas $countWUs:</p>";
                $str .=
qq|<table border='0' cellspacing='0' width='100%'>$thRow$sortRow$wulist</table>|;
                $str .= $pages;
            }
        }
    }
    return $str;
}

sub everything_s_best_users {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<p align="right"><small>[News for noders.  Stuff that matters.]</small></p>|;

    # Form toolbar (check boxes and Change button)
    $str .= q|<p align="right">|;
    $str .= q|<small>If you miss the merit display, you can go and complain to [ascorbic], but try getting some perspective first.</small>|
      if $VARS->{ebu_showmerit};

    if ( !$APP->isGuest($USER) ) {

        # Clear/reset the form control variables
        delete $VARS->{ebu_showmerit};    # if($query->param('gochange'));
        delete $VARS->{ebu_showdevotion}  if ( $query->param('gochange') );
        delete $VARS->{ebu_showaddiction} if ( $query->param('gochange') );
        delete $VARS->{ebu_newusers}      if ( $query->param('gochange') );
        delete $VARS->{ebu_showrecent}    if ( $query->param('gochange') );

        # $VARS->{ebu_showmerit} = 1 if($query->param("ebu_showmerit") eq "on");
        $VARS->{ebu_showdevotion} = 1
          if ( $query->param('ebu_showdevotion') eq 'on' );
        $VARS->{ebu_newusers} = 1 if ( $query->param('ebu_newusers') eq 'on' );
        $VARS->{ebu_showaddiction} = 1
          if ( $query->param('ebu_showaddiction') eq 'on' );
        $VARS->{ebu_showrecent} = 1
          if ( $query->param('ebu_showrecent') eq 'on' );

        # Show the mini-toolbar
        $str .= htmlcode('openform')

          # . '<input type="checkbox" name="ebu_showmerit" '
          # . ($VARS->{ebu_showmerit}?' CHECKED ':'')
          # . '>Display by merit '
          . '<input type="checkbox" name="ebu_showdevotion" '
          . ( $VARS->{ebu_showdevotion} ? ' CHECKED ' : '' )
          . '>Display by [devotion] '
          . '<input type="checkbox" name="ebu_showaddiction" '
          . ( $VARS->{ebu_showaddiction} ? ' CHECKED ' : '' )
          . '>Display by [addiction] '
          . '<input type="checkbox" name="ebu_newusers" '
          . ( $VARS->{ebu_newusers} ? ' CHECKED ' : '' )
          . '>Show New users  '
          . '<input type="checkbox" name="ebu_showrecent" '
          . ( $VARS->{ebu_showrecent} ? ' CHECKED ' : '' )
          . '>Don\'t show fled users &nbsp;<input type="hidden" '
          . 'name="gochange" value="foo">'
          . '<input type="submit" value="change"></p>';
    }
    else {
        # No toolbar for the Guest User.
        return '';
    }

    $str .= q|<p>Shake these people's manipulatory appendages.  They deserve it.<br /><em>A drum roll please....</em></p>|;

    $str .= q|<!-- Start the TABLE ...  --->|;
    $str .= q|<table border="0" width="70%" align="center">|;
    $str .= q|<!-- I left this out of the code block to avoid escaping the quotes. -->|;
    $str .= q|<tr bgcolor="#ffffff">|;

    # Find out the date 2 years ago
    my $rows    = undef;
    my $datestr = undef;

    my $queryText = 'SELECT DATE_ADD(CURDATE(), INTERVAL -2 YEAR)';
    $rows = $DB->{dbh}->prepare($queryText);
    $rows->execute();
    $datestr = $rows->fetchrow_array();

    # Body of the table

    # Declare and init the string that contains our whole HTML stream.

    # Build the rest of the table's heading row
    $str .= q|<th></th><th>User</th>|;

    # ... only include the Merit column if the checkbox is on.
    if ( $VARS->{ebu_showmerit} ) {
        $str .= "<th>Merit</th>";
    }

    if ( $VARS->{ebu_showdevotion} ) {
        $str .= q|<th>Devotion</th>|;
    }

    if ( $VARS->{ebu_showaddiction} ) {
        $str .= q|<th>Addiction</th>|;
    }

    $str .= q|<th>Experience</th><th># Writeups</th><th>Rank</th><th>Level</th>|;
    $str .= q|</tr>|;

    # Build the database query
    # ... skip these users

    my $skip = {
        'dbrown'         => 1,
        'nate'           => 1,
        'hemos'          => 1,
        'Webster 1913'   => 1,
        'Klaproth'       => 1,
        'Cool Man Eddie' => 1,
        'ShadowLost'     => 1,
        'EDB'            => 1,
        'everyone'       => 1,
    };

    # ... set the query limits (including 'no monkeys')
    my $maxShow = 60;
    my $limit   = $maxShow;

    $limit += ( keys %$skip );

    my $recent = '';
    if ( $VARS->{ebu_newusers} ) {
        $recent =
" and (select createtime from node where node_id=user.user_id)>'$datestr 00:00:00'";
    }

    # use the same cutoff date for fled users that we do for recent users
    # the old code cut off recent users at 2 years and fled users at 1 year

    my $noFled = '';
    if ( $VARS->{ebu_showrecent} ) {
        $noFled = " and user.lasttime>'$datestr 00:00:00' ";
    }

    # Run the query
    my $csr = '';
    if ( $$VARS{ebu_showmerit} ) {

        # Query for all users with >24 writeups, sort by merit
        $csr = $DB->sqlSelectMany( 'user_id', 'user',
            "numwriteups > 24 $noFled order by merit desc limit $limit" );
    }

    if ( $$VARS{ebu_showdevotion} ) {

        # Query for all users with >24 writeups, sort by merit
        $csr = $DB->sqlSelectMany( 'user_id', 'user',
"numwriteups > 24 $noFled order by (numwriteups*merit) desc limit $limit"
        );
    }

    if ( $$VARS{ebu_showaddiction} ) {

        # Query for all users with >24 writeups, sort by merit
        $csr = $DB->sqlSelectMany(
"user_id, ((numwriteups*merit)/datediff(now(),node.createtime)) as addiction",
            "user, node",
"numwriteups > 24 $noFled and node.node_id=user.user_id order by addiction desc limit $limit"
        );
    }

    if ( $csr eq '' ) {

        # default
        # Query for all users, sort by XP (classic EBU sort)
        $csr = $DB->sqlSelectMany( "user_id", "user",
            "user_id > 0 $noFled $recent order by experience desc limit $limit"
        );
    }

    # Set up to loop over the result set
    my $uid   = getId($USER) || 0;
    my $isMe  = 0;
    my $step  = 0;
    my $color = '';
    my $range = { 'min' => 135, 'max' => 255, 'steps' => $maxShow };

    my $curr   = 0;
    my $lvlttl = getVars( getNode( 'level titles', 'setting' ) );
    my $lvl    = 0;

    # Loop over the result set and display each row
    my $place = 0;
    while ( my $nid = $csr->fetchrow_hashref ) {
        my $node = getNodeById( $nid->{user_id} );
        next if ( exists $$skip{ $$node{title} } );
        next if ( $step >= $maxShow );

        # This record is for the person who is logged in
        $isMe = $$node{node_id} == $uid;

        $lvl = $APP->getLevel($node);

        # Get the user vars for the user of record
        my $V = getVars($node);

        # Fled users may have actual #numwriteups < 25 if they've
        # had writeups nuked since they last logged in.
        next unless $$V{numwriteups};    #if no WUs, less-than test breaks
        next if ( ( $$V{numwriteups} < 25 ) && ( !$$VARS{ebu_newusers} ) );

        # Devotion is broken because numwriteups in the db isn't accurate
        # ($$V{numwriteups} is accurate, though)
        my $devo  = int( ( $$V{numwriteups} * $$node{merit} ) + .5 );
        my $merit = sprintf( '%.2f', $$node{merit} || 0 );

        $curr = $$range{max} -
          ( ( $$range{max} - $$range{min} ) / $$range{steps} ) * $step;
        $curr  = sprintf( '%02x', $curr );
        $color = '#' . $curr . $curr . $curr;

        $str .= "<tr bgcolor=\"$color\" >";
        $str .= "<td align=\"center\"><small>";
        $str .= ++$place;
        $str .= "</small></td><td>";
        $str .= ( $isMe ? '<strong>' : '' );
        $str .= ( linkNode( $node, 0, { lastnode_id => undef } ) );
        $str .= ( $isMe ? '</strong>' : '' ) . "</td>";
        if ( $VARS->{ebu_showmerit} ) {
            $str .= "<td>$merit</td>";
        }

        if ( $VARS->{ebu_showdevotion} ) {
            $str .= "<td>$devo</td>";
        }

        if ( $VARS->{ebu_showaddiction} ) {
            my $addict = sprintf( '%.3f', $nid->{addiction} );
            $str .= "<td>$addict</td>";
        }

        $str .=
"<td>$$node{experience}</td><td>$$V{numwriteups}</td><td>$$lvlttl{$lvl}</td><td>$lvl</td></tr>\n";

        ++$step;
    }

    $str .= q|</table>|;
    return $str;
}

sub everything_s_best_writeups {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    return 'Curiosity killed the cat, ya know.'
      unless ( $APP->isEditor($USER) );

    my $str =
'Everything\'s 50 "Most Cooled" Writeups (visible only to staff members):';
    my $csr = $DB->{dbh}
      ->prepare('SELECT writeup_id FROM writeup ORDER BY cooled DESC LIMIT 50');

    $csr->execute();

    $str .=
'<br><br><table><tr bgcolor="#CCCCCC"><td width="200">Writeup</td><td width="200">Author</td></tr>';
    while ( my $row = $csr->fetchrow_hashref() ) {
        my $bestnode = getNodeById( $row->{writeup_id} );
        next unless ($bestnode);

        my $bestparent = getNodeById( $bestnode->{parent_e2node} );
        my $bestuser   = getNodeById( $bestnode->{author_user} );

        $str .=
            '<tr><td>'
          . linkNode( $bestnode,   $bestnode->{title} ) . ' - '
          . linkNode( $bestparent, 'full' ) . ' <b>'
          . $$bestnode{cooled}
          . 'C!</b></td><td> by '
          . linkNode( $bestuser, $bestuser->{title} )
          . '</td></tr>';
    }

    $str .= '</table>';

    return $str;
}

sub page_of_cool {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my @grp = (
        @{ getNode( 'gods',            'usergroup' )->{group} || [] },
        @{ getNode( 'Content Editors', 'usergroup' )->{group} || [] },
        @{ getNode( 'exeds', 'nodegroup' )->{group} || [] }
    );
    my $except = {};

    foreach my $except_user ( 'Cool Man Eddie',
        'EDB', 'Webster 1913', 'Klaproth', 'PadLock' )
    {
        my $user = $DB->getNode( $except_user, 'user' );
        if ($user) {
            $except->{ $user->{node_id} } = 1;
        }
    }
    @grp =
      sort { lc( getNodeById($a)->{title} ) cmp lc( getNodeById($b)->{title} ) }
      @grp;
    my $first_block =
"Browse through the latest editor selections below, or choose a specific editor (or former editor) to see what they've endorsed:";

    $first_block .= htmlcode('openform');
    $first_block .= q|<select name="editor">|;
    foreach (@grp) {
        my $selected = (($query->param('editor') . '') eq "$_") ? ' SELECTED ' : '';
        unless ( $except->{$_} || (getNodeById($_)->{type}->{title} ne 'user') ) {
            $first_block .=
                "<option value=\"$_\""
              . $selected
              . '>'
              . getNodeById($_)->{title}
              . '</option>';
        }
        $except->{$_} = 1;
    }

    $first_block .= q|</select><input type="submit" value="Show Endorsements"></form>|;

    my $ed = $query->param('editor');
    $ed =~ s/[^\d]//g;

    if ( $ed && getNodeById($ed)->{type}->{title} eq 'user' ) {
        my $csr = $DB->sqlSelectMany(
            'node_id',
            'links left join node on links.from_node=node_id',
            'linktype='
              . getId( getNode( 'coollink', 'linktype' ) )
              . " and to_node='$ed' order by title"
        );

        my $innerstr;
        my $count = 0;
        while ( my $row = $csr->fetchrow_hashref ) {
            $count++;
            my $n = getNodeById( $row->{node_id} );
            $$n{group} ||= [];
            my $num = scalar( @{ $n->{group} } );
            $innerstr .= q|<li>|
              . linkNode($n)
              . (
                ( $$n{type}{title} eq 'e2node' )
                ?       ( " - $num writeup"
                      . ( ( $num == 0 || $num > 1 ) ? ("s") : ("") ) )
                : (" - ($$n{type}{title})")
              ) . q|</li>|;
        }

        $first_block .= linkNode( getNodeById($ed) )
          . " has endorsed $count nodes<br><ul>$innerstr</ul>";

    }

    my $second_block =
qq|<table width="100%" cellpadding="2" cellspacing="0" border="0"><tr align="left"><th>Title</th><th>Cooled by</th></tr>|;

    my $COOLNODES = getNode 'coolnodes', 'nodegroup';
    my $COOLLINKS = getNode 'coollink',  'linktype';
    my $cn        = $$COOLNODES{group};
    my $clink     = getId $COOLLINKS;

    my $return    = '';
    my $increment = 50;
    my $next      = $query->param('next');
    $next ||= 0;

    my $count = 0;

    foreach ( reverse @$cn ) {
        $count++;
        next if $count < $next;
        last if $count > $next + $increment;
        my $csr =
          $DB->{dbh}->prepare( "select * from links where from_node="
              . getId($_)
              . " and linktype=$clink" );
        my $str = '<tr class="';
        $str .= ( int($count) & 1 ) ? 'oddrow' : 'evenrow';
        $str .= '">';
        $csr->execute;
        my $link = $csr->fetchrow_hashref;
        $csr->finish;
        $str .= '<td>' . linkNode($_) . '</td>';

        if ($link) {
            $str .= '<td>' . linkNode( $$link{to_node} ) . '</td>';
        }
        else {
            $str .= '<td>&nbsp;</td>';
        }
        $str          .= "</tr>\n";
        $second_block .= $str;
    }
    my $next_elements = '<tr><td>';

    if ( $next > 0 ) {
        $next_elements .=
          linkNode( $NODE, "prev $increment", { next => $next - $increment } );
    }
    else {
        $next_elements .= '&nbsp;';
    }
    $next_elements .= '</td><td>';

    if ( $next + $increment < @$cn ) {
        $next_elements .=
          linkNode( $NODE, "next $increment", { next => $next + $increment } );
    }
    else {
        $next_elements .= '&nbsp;';
    }

    $second_block .= $next_elements . '</td></tr></table>';

    return $first_block . $second_block;
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

sub superbless {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    return '<p>You have not yet learned that spell.</p>'
      unless $APP->isEditor($USER);

    my $str = "";
    if ( htmlcode( 'verifyRequest', 'superbless' ) ) {
        my @params = $query->param;
        my @users  = ();
        my @gp     = ();

        foreach (@params) {
            if (/^EnrichUsers(\d+)$/) {
                $users[$1] = $query->param($_);
            }
            if (/^BestowGP(\d+)$/) {
                $gp[$1] = $query->param($_);
            }
        }

        my $curGP = undef;
        for ( my $count = 0 ; $count < @users ; $count++ ) {
            next unless $users[$count] and $gp[$count];

            my ($U) = getNode( $users[$count], 'user' );
            if ( not $U ) {
                $str .= "couldn't find user $users[$count]<br />";
                next;
            }

            $curGP = $gp[$count];

            unless ( $curGP =~ /^\-?\d+$/ ) {
                $str .=
                  "$curGP is not a valid GP value for user $users[$count]<br>";
                next;
            }

            my $signum = ( $curGP > 0 ) ? 1 : ( ( $curGP < 0 ) ? -1 : 0 );

            $str .= "User $$U{title} was given $curGP GP.";
            $APP->securityLog( $NODE, $USER,
                "$$U{title} was superblessed $curGP GP by $$USER{title}" );

            if ( $signum != 0 ) {
                $$U{karma} += $signum;
                updateNode( $U, -1 );
                htmlcode( 'achievementsByType', 'karma' );
                $APP->adjustGP( $U, $curGP );
            }
            else {
                $str .= ', so nothing was changed';
            }
            $str .= "<br>\n";
        }
    }
    my $count = 10;

    $str .=
        htmlcode( 'openform', 'superblessForm' )
      . htmlcode( 'verifyRequestForm', 'superbless' )
      . '<table border="1">';

    $str .= "<tr><th>Bestow user</th><th>with GP</th></tr> ";

    for ( my $i = 0 ; $i < $count ; $i++ ) {
        $query->param( "EnrichUsers$i", '' );
        $query->param( "BestowGP$i",    '' );
        $str .= "<tr><td>";
        $str .= $query->textfield(
            -name      => "EnrichUsers$i",
            -size      => 40,
            -maxlength => 80,
            -class     => 'userComplete'
        );
        $str .= "</td><td>";
        $str .= $query->textfield( "BestowGP$i", '', 4, 7 );
        $str .= "</td></tr>";
    }

    $str .= '</table>' . htmlcode('closeform');

    return $str;
}

sub spam_cannon {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $MAX_VICTIMS = 20;

    my $uid   = getId($USER);
    my $foad  = "<p><strong>Permission Denied.</strong></p>\n";
    my $level = $$VARS{'level'};

    $level =~ s/([0-9]+).*$/$1/;

    return $foad unless $APP->isEditor($USER);

    my $msgtext = '';
    if ( defined $query->param('spam_message') ) {
        $msgtext = $query->param('spam_message');
        $msgtext =~ s/&/&amp;/g;
        $msgtext =~ s/\[/&#91;/g;
        $msgtext =~ s/\]/&#93;/g;
        $msgtext =~ s/"/&quot;/g;
    }

    my $str =
'<p>The Spam Cannon sends a single /msg to multiple recipients, without having to create a usergroup. Usergroups are not yet supported as recipients, but /msg aliases are. </p><p>The privilege of using this tool will be revoked if abused. </p>'
      . htmlcode( 'openform2', 'spammer' );

    $str .=
qq|<table><tr><td valign="top" align="right" width="100"><p><b>Recipients:</b></p>|;
    $str .=
qq|<p><i>Put each username on its own line, and don't hardlink them. Don't bother with underscores.</i></p>|;
    $str .= qq|</td><td><textarea name="recipients" rows="20" cols="30">|;
    $str .= $query->param('recipients');
    $str .= qq|</textarea></td></tr>|;
    $str .= qq|<tr><td valign="top" align="right"><p><b>Message:</b></p></td>|;
    $str .=
qq|<td><input type="text" size="40" maxlength="243" name="spam_message" value="$msgtext"></td></tr>|;
    $str .=
qq|<tr><td valign="top" colspan="2" align="right"><input type="submit" value="Send"></td></tr></table></form>|;

    if (   defined $query->param('recipients')
        && defined $query->param('spam_message') )
    {
        my $recipients = $query->param('recipients');
        my $message    = $query->param('spam_message');

        # Remove HTML tags from message
        $message =~ s/<[^>]+>//g;

        # Feedback to user
        $str .= "<dl>\n<dt><b>Sent message:</b></dt>\n";
        $str .= "<dd>" . $message . "</dd>\n";
        $str .= "<dd>&nbsp;</dd>\n";
        $str .= "<dt><b>To users:</b></dt>\n";

        # Remove whitespace from beginning and end of each line in
        # list of recipients.
        $recipients =~ s/\s*\n\s*/\n/g;

        # Split recipient list into array
        my @users = split( '\n', $recipients );
        my $count = 0;
        my $sent
          ;  # Keep track of who we've sent the /msg to, so as to avoid repeats.

        # Iterate through recipient list
        foreach my $victimname (@users) {
            if ( ++$count > $MAX_VICTIMS ) {
                $str .=
"<dd><font color=\"#c00000\"><strong>Enough.</strong></font> You trying to talk to the whole world at once?</dd>\n";
                last;
            }

       # If it's an alias, get the proper username before getting the user hash.
            my $victim = getNode( $victimname, 'user' );

            if ( defined($victim) ) {
                if ( $victim->{message_forward_to} ) {
                    $victim = getNodeById( $victim->{message_forward_to} );
                }

                # Skip duplicates
                if ( $sent->{ $victim->{'node_id'} } ) {
                    $str .=
                        q|<dd><font color="#c00000">You sent this to |
                      . linkNode( $victim->{'node_id'} )
                      . q| already.</font></dd>|;
                    next;
                }
                else {
                    $sent->{ $victim->{'node_id'} } = 1;
                }

                # Some feedback for the user
                $str .= "<dd>" . linkNode( $victim->{'node_id'} ) . "</dd>\n";

# Insert message into messages table.
# $DB->sqlInsert( 'message', { msgtext => "(massmail): " . $message, author_user => $$USER{ 'node_id' }, for_user => $$victim{ 'node_id' } } );
            }
            else {
                # SAY WHAT?! HE AIN'T HERE! HE DON'T EXIST!
                $str .=
                    "<dd><font color=\"#c00000\">User <b>\""
                  . $victimname
                  . "\"</b> does not exist.</font></dd>\n";
            }
        }

        $str .= "</dl>\n";
        $str .= "<p>No users specified.</p>\n" if ( $count == 0 );
    }

    $str .= "<br>\n";
    return $str;
}

sub pit_of_abomination {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = htmlcode('openform');
    $str .= q|<p>For they are an Offense in thine Eyes, and that thine Eyes might be freed from the sight of their Works, thou mayest abominate them here. And their feeble Screeds shall not appear in that List which is call&egrave;d New Writeups, nor shall they be shewn amongst the Works of the Worthy in the Nodes of E2. Yet still mayest thou seek them out when thy Fancy is such.|;
    $str .= q|<fieldset><legend>Abominate</legend>|;
    $str .= q|<label>Wretch's name:<input type="text" name="abomination"></label>|;
    $str .= q|<label title="also ignore user's messages and chat"><input type="checkbox" name="pratenot" value="1" checked="checked">disdain also their prattle</label>|;
    $str .= q|<br><input type="submit" name="abominate" value="Abominate!">|;

    if ( scalar( $query->param('abominate') )
        and my $abominame = $query->param('abomination') )
    {
        unless ( my $abomination = getNode( $abominame, 'user' ) ) {
            $str .= '<p>User ' . encodeHTML($abominame) . ' not found.';
        }
        else {
            $VARS->{unfavoriteusers} .= ',' if $VARS->{unfavoriteusers};
            $VARS->{unfavoriteusers} .= $abomination->{user_id}
              unless $VARS->{unfavoriteusers} =~ /\b$abomination->{ user_id }\b/;
            $str .= htmlcode( 'ignoreUser', $abominame )
              if $query->param('pratenot');
        }
    }

    $str .= qq|</fieldset></form>|;
    $str .= htmlcode('openform');

    if ( scalar $query->param('debominate') ) {
        foreach ( $query->multi_param('debominees') ) {
            $VARS->{unfavoriteusers} =~ s/\b$_\b,?//;
        }
    }

    $VARS->{unfavoriteusers} =~ s/,$//;

    if ( $VARS->{unfavoriteusers} ) {
        my @abominees = split ',', $VARS->{unfavoriteusers};
        $str .=
'<p>Yet should they swear Betterment and rue their Ways, repenting in Sackcloth and Ashes,
thou mayest in thy great Mercy relent.
<fieldset><legend>Relent</legend>
    '
          . $query->checkbox_group(
            -name      => 'debominees',
            -values    => [@abominees],
            -labels    => { map { $_ => getNodeById($_)->{title} } @abominees },
            -linebreak => 'true'
          )
          . $query->submit( -name => 'debominate', -value => 'Relent!' )
          . '</fieldset>';
    }
    else {
        $str .= '<p>In thy Mercy hast thou stayed thy Hand.';
    }

    $str .= q|</form>|;
    return $str;
}

sub level_distribution {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|<p>The following shows the number of active E2 users at each level (based on users logged in over the last month).</p>|;

    my $levels = {};
    my $queryText = q|SELECT setting.setting_id,setting.vars FROM setting,user WHERE setting.setting_id=user.user_id AND user.lasttime>=DATE_ADD(CURDATE(), INTERVAL -1 MONTH) AND setting.vars LIKE '%level=%'|;

    my $rows = $DB->{dbh}->prepare($queryText);
    $rows->execute() or return $rows->errstr;

    while ( my $dbrow = $rows->fetchrow_arrayref ) {
        $dbrow->[1] =~ m/level=([0-9]+)/;
        if ( exists( $levels->{$1} ) ) {
            $levels->{$1} = $levels->{$1} + 1;
        }
        else {
            $levels->{$1} = 1;
        }
    }

    $str .= q|<table align="center"><tr><th>Level</th><th>Title</th><th>Number of Users</th></tr>|;
    my $ctr = 0;
    foreach
      my $key ( sort { $levels->{$b} <=> $levels->{$a} } ( keys(%$levels) ) )
    {
        $ctr++;

        if ( $ctr % 2 == 0 ) {
            $str .= '<tr class="evenrow">';
        }
        else {
            $str .= '<tr class="oddrow">';
        }
        $str .= '<td>'
          . ( $key + 0 )
          . '</td><td style="text-align:center">'
          . ( getVars( getNode( 'level titles', 'setting' ) )->{ ( $key + 0 ) }
              || 0 )
          . '</td><td style="text-align:right">'
          . $levels->{$key}
          . '</td></tr>';
    }

    $str .= '</table>';
    return $str;
}

sub manna_from_heaven {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $numDays = $query->param("days") || 30;

    my $str =
        "<form method='get'><input type='hidden' name='node_id' value='"
      . $$NODE{node_id}
      . "' /><input type='text' value='$numDays' name='days' /><input type='submit' name='sexisgood' value='Change Days' /></form>";
    my $usergroup = getNodeById(923653);    #content editors node

    my $wuCount;
    my $wuTotal = 0;

    $str .= q|<table width='25%'><tr><th width='80%' >User</th><th width='20%'>Writeups</th></tr>|;

    foreach ( @{ $$usergroup{group} } ) {
        my $u = getNodeById($_);
        next if $$u{title} eq 'e2gods';
        $wuCount = $DB->sqlSelect( 'count(*)', 'node',
                'type_nodetype=117 and author_user='
              . $_
              . " and TO_DAYS(NOW())-TO_DAYS(createtime) <=$numDays" );
        $wuTotal += $wuCount;
        $str .=
            q|<tr><td><b>|
          . linkNode($u)
          . q|</b></td><td>|
          . linkNode( getNode( 'everything user search', 'superdoc' ),
            " $wuCount",
            { usersearch => $$u{title}, orderby => 'createtime DESC' } )
          . q|</td></tr>|;
    }

    $usergroup = getNodeById(829913);    # e2gods

    foreach ( @{ $usergroup->{group} } ) {
        my $u = getNodeById($_);
        $wuCount = $DB->sqlSelect( 'count(*)', 'node',
                'type_nodetype=117 and author_user='
              . $_
              . " and TO_DAYS(NOW())-TO_DAYS(createtime) <=$numDays" );
        $wuTotal += $wuCount;
        $str .=
            q|<tr><td><b>|
          . linkNode($u)
          . q|</b></td><td>|
          . linkNode( getNode( 'everything user search', 'superdoc' ),
            " $wuCount",
            { usersearch => $u->{title}, orderby => 'createtime DESC' } )
          . q|</td></tr>|;
    }

    $str .= qq|<tr><td><b>Total</b></td><td>$wuTotal</td></tr>|;
    $str .= q|</table>|;

    return $str;

}

sub content_reports {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = q|These jobs are run on a 24 hour basis and cached in the database. They show user-submitted content that is in need of repair.|;
    $str .= q|<table style="padding: 2px; margin: 5px;">|;

    my $drivers = {
        'editing_invalid_authors' => {
            'title'          => 'Invalid Authors on nodes',
            'extended_title' => 'These nodes do not have authors. Either the users were deleted or the records were damaged. Includes all types'
        },
        'editing_null_node_titles' => {
            'title'          => 'Null titles on nodes',
            'extended_title' => 'These nodes have null or empty-string titles. Not necessarily writeups.'
        },
        'editing_writeups_bad_types' => {
            'title'          => 'Writeup types that are invalid',
            'extended_title' => 'These are writeup types, such as (thing), (idea), (definition), etc that are not valid'
        },
        'editing_writeups_broken_titles' => {
            'title'          => q|Writeup titles that aren't the right pattern|,
            'extended_title' =>
q|These are writeup titles that don't have a left parenthesis in them, which means that it doesn't follow the 'parent_title (type)' pattern.|
        },
        'editing_writeups_invalid_parents' => {
            'title'          => q|Writeups that don't have valid e2node parents|,
            'extended_title' => q|These nodes need to be reparented|
        },
        'editing_writeups_under_20_characters' => {
            'title'          => 'Writeups under 20 characters',
            'extended_title' => 'Writeups that are under 20 characters'
        },
        'editing_writeups_without_formatting' => {
            'title'          => 'Writeups without any HTML tags',
            'extended_title' => q|Writeups that don't have any HTML tags in them, limited to 200, ignores E1 writeups.|
        },
        'editing_writeups_linkless' => {
            'title'          => 'Writeups without links',
            'extended_title' => q|Writeups post-2001 that don't have any links in them|
        },
        'editing_e2nodes_with_duplicate_titles' => {
            'title'          => 'Writeups with titles that only differ by case',
            'extended_title' => 'Writeups that only differ by case'
        },
    };

    if ( $query->param('driver') ) {
        my $driver   = $query->param('driver');
        my $datanode = getNode( $driver, 'datastash' );

        if ( $datanode and exists $drivers->{$driver} ) {
            my $data = $DB->stashData($driver);
            $data = [] unless ( UNIVERSAL::isa( $data, 'ARRAY' ) );
            $str .= q|<h2>|.$drivers->{$driver}->{title}.q|</h2><br />|;
            $str .= q|<p>|.$drivers->{$driver}->{extended_title}.q|</p>|;

            if ( scalar(@$data) ) {
                $str .= q|<ul>|;
                foreach my $node_id (@$data) {
                    my $N = getNodeById($node_id);
                    if ($N) {
                        $str .=
qq|<li><a href="/?node_id=$node_id">node_id: $node_id title: |
                          . ( $N->{title} || '' )
                          . " type: $N->{type}->{title} </li>";
                    }
                    else {
                        $str .= qq|<li>Could not assemble node reference for id: $node_id</li>|;
                    }
                }
                $str .= q|</ul>|;
            }
            else {
                $str .= "Driver <em>$driver</em> has no failures";
            }
        }
        else {
            $str .= "Could not access driver: <em>$driver</em>.";
        }

        $str .= q|<br />Back to | . linkNode($NODE) . q|<br />|;
    }
    else {
        $str .= q|<tr><td><strong>Driver name</strong></td><td style="text-align: center"><strong>Failure count</strong><td></tr>|;

        foreach my $driver ( sort { $a cmp $b } keys %$drivers ) {
            my $datanode = getNode( $driver, 'datastash' );
            next unless $datanode;
            next unless $datanode->{vars};

            my $data = $DB->stashData($driver);
            $data = [] unless UNIVERSAL::isa( $data, 'ARRAY' );

            $str .= q|<tr><td style="padding: 4px">|
              . linkNode(
                $NODE,
                $drivers->{$driver}->{title},
                { 'driver' => $driver }
              )
              . q|</td><td style="width: 150px; text-align: center;">|
              . scalar(@$data)
              . q|</td></tr>|;
        }

    }

    $str .= q|</table>|;
    return $str;
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
    my $startat = $query->param('startat');
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

    my $wuType = abs int( $query->param('wutype') );

    my $count = $query->param('count') || 50;
    $count = abs int($count);

    my $page = abs int( $query->param('page') );

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

sub nodelet_settings {
    my $DB       = shift;
    my $query    = shift;
    my $NODE     = shift;
    my $USER     = shift;
    my $VARS     = shift;
    my $PAGELOAD = shift;
    my $APP      = shift;

    my $str = '';
    if ( $APP->isGuest($USER) ) {
        $str =
            '<p>You need to sign in or '
          . linkNode( getNode( 'Sign up', 'superdoc' ), 'register' )
          . ' to use this page.</p>';
    }
    else {
        $PAGELOAD->{pageheader} = '<!-- bottom -->' . htmlcode('settingsDocs');
        $str = htmlcode( 'openform', -id => 'pagebody' );

        $str .= q|<fieldset><legend>Choose and sort nodelets</legend> You can change the order of nodelets by dragging and dropping the menus here (don't forget to save) or by dragging them around by the title on most other pages.|;

        my $i        = undef;
        my @selected = ();
        my $prefix   = 'nodeletedit';

        if ( $query->param($prefix) ) {
            my $id = undef;
            foreach ( grep { /^$prefix\d+/ } $query->param() ) {
                push( @selected, $id )
                  if ( $id = $query->param($_)
                    and not grep { /^$id$/ } @selected );
            }
            $$VARS{nodelets} = join ',', @selected;
        }
        else {
            @selected = split ',', $$VARS{nodelets};
        }

        my $names = { '0' => '(none)' };
        my $ids   = $Everything::CONF->supported_nodelets;
        foreach my $id ( @$ids, @selected )
        {   # include @selected in case user has a non-standard nodelet selected
            my $n = $DB->getNodeById($id);
            next unless $n;
            $names->{$id} ||= $n->{title};
        }
        $ids =
          [ sort { lc( $names->{$a} ) cmp lc( $names->{$b} ) } keys %$names ]
          ;    # keys to include non-standard

        my @menus = ();
        for ( $i = 1 ; $selected[ $i - 1 ] ; $i++ ) {
            push @menus,
              $query->popup_menu(
                -name   => $prefix . $i,
                values  => $ids,
                labels  => $names,
                default => $selected[ $i - 1 ],
                force   => 1
              );
        }

        while ( $ids->[$i] ) {
            push @menus,
              $query->popup_menu(
                -name   => $prefix . $i,
                values  => $ids,
                labels  => $names,
                default => '0',
                force   => 1
              );
            $i++;
        }

        $str .=
            $query->hidden( -name => $prefix, value => 1 )
          . q|<ul id="rearrangenodelets"><li>|
          . join( "</li>\n<li>", @menus )
          . "</li></ul>\n";
        $str .= q|If the 'Epicenter' nodelet is not selected, its functions are placed in the page header.</fieldset>|;

        my $settingsstr = '';
        my @nodelets    = split ',', $$VARS{nodelets};
        foreach my $nodelet (@nodelets) {
            my $n    = getNodeById($nodelet);
            my $name = $$n{title} . ' nodelet settings';
            next
              unless $n
              && $$n{type}->{title} eq 'nodelet'
              && getNode( $name, 'htmlcode' );
            my $id = lc($name);
            $id =~ s/\W//g;
            $settingsstr .=
                qq|<fieldset id="$id"><legend>$name</legend>|
              . htmlcode($name)
              . q|</fieldset>|;
        }
        $str .= "<h2>Settings</h2>\n$settingsstr" if $settingsstr;

        $str .= htmlcode( 'closeform', 'Save settings' );
    }
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

sub everything_s_biggest_stars
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $rows = undef;
    my $str = '';
    my $dbrow = undef;
    my $limit = 100;

    my $queryText = 'SELECT user_id,stars FROM user ORDER BY stars DESC LIMIT '.$limit;
    $rows = $DB->{dbh}->prepare($queryText) or return $rows->errstr;
    $rows->execute() or return $rows->errstr;

    $str .= '<h3>'.$limit.' Most Starred Noders</h3>';
    $str .= '<ol>';
    while(my $row = $rows->fetchrow_arrayref)
    {
        $str .= '<li>'.linkNode($$row[0]).' ('.$$row[1].' stars)</li>';
    }

    $str .= '</ol><hr />';
    return $str;
}

sub word_messer_upper
{
  my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
  my $text = $query->param('text');
  my $numbreaks = $query->param('numbreaks');
  $numbreaks ||= 0;
  $numbreaks = int($numbreaks);

  my $str = '';

  if (not $text) {
    $str.=q|Type in something you'd like to see messed up:<br>|;
  } else {
    my $words = [split ' ', $text];
    while ($numbreaks--) {
      $words->[rand(int(@$words))].="\n";
    }
    $words = $APP->fisher_yates_shuffle($words);
    $text = join ' ', @$words;
    $query->param('text', $text);
  }

  $str.=htmlcode('openform');
  $str.='insert '.$query->textfield('numbreaks', '', 2, 2).q| line breaks<br>|;
  $str.=$query->textarea('text', $text, 40, 60,'' , 'wrap=virtual');
  $str.=htmlcode('closeform');
  $text =~ s/\n/\&lt\;br\&gt\;\<br\>/gs;
  $text =~ s/\</\&lt\;/g;
  $text =~ s/\>/\&gt\;/g;
  return $str.$text;
}

sub log_archive
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $nodeId = getId($NODE);
    my $stubdate = DateTime->new(year => 2001, month => 1, day => 1);
    my $curDate = DateTime->now;
    my $minYear = 1997;
    my $maxYear = $curDate->year;

    my $month = int($query->param('m'));
    if ($month < 1 || $month > 12)
    {
      $month = $curDate->month;
    }

    my $year = int($query->param('y'));
    if ($year < $minYear || $year > $maxYear)
    {
      $year = $year || $curDate->year;
    }

    my $prevYear = $year;
    my $prevMonth = $month - 1;
    if ($prevMonth < 1)
    {
      $prevMonth = 12;
      $prevYear = $prevYear - 1;
    }
    my $nextYear = $year;
    my $nextMonth = $month + 1;
    if ($nextMonth > 12)
    {
      $nextMonth = 1;
      $nextYear = $nextYear + 1;
    }
    my $month_name = $stubdate->set_month($month)->month_name;
    my $queryText = 'SELECT
    writeupNode.node_id,
    writeupNode.title,
    writeupNode.author_user,
    writeupNode.reputation,
    authorNode.title AS authorTitle,
    writeup.writeup_id,
    writeup.wrtype_writeuptype,
    notnew,
    nodeTypeNode.title AS writeupTypeTitle,
    writeup.parent_e2node,
    e2node.title AS parentTitle,
    writeupNode.createtime
    FROM node writeupNode,node authorNode,writeup,node nodeTypeNode,node e2node
    WHERE writeupNode.node_id=writeup.writeup_id
    AND writeupNode.author_user=authorNode.node_id
    AND nodeTypeNode.node_id=writeup.wrtype_writeuptype
    AND e2node.node_id=writeup.parent_e2node
    AND (e2node.title LIKE \''.$month_name.' %, '.$year.'\'
    OR e2node.title LIKE \'Dream Log: '.$month_name.' %, '.$year.'\'
    OR e2node.title = \'Editor Log: '.$month_name.' '.$year.'\'
    OR e2node.title = \'root log: '.$month_name.' '.$year.'\')
    ORDER BY writeupNode.createtime';

    my $str = '';
    $str .= '<form method="get" action="/index.pl">
    <div style="text-align:center">
    <input type="hidden" name="node_id" value="'.$nodeId.'">
    <b>Select Month and Year:</b>
    <select name="m">';
    for (my $i = 1; $i <= 12; $i++)
    {
      $str .= '<option value="'.$i.'"';
      if ($i == $month)
      {
        $str .= ' selected="selected"';
      }
      $str .= '>'.$stubdate->set_month($i)->month_name.'</option>';
    }
    $str .= '</select>
    <select name="y">';
    for(my $i = $curDate->year; $i >= $minYear; $i--)
    {
    $str .= '<option value="'.$i.'"';
    if ($i == $year)
    {
        $str .= ' selected="selected"';
    }
    $str .= '>'.$i.'</option>';
    }
    $str .= '</select>
    <input type="submit" value="Get Logs"><br />';
    if ($prevYear >= $minYear)
    {
      $str .= '<a href="/index.pl?node_id='.$nodeId.'&m='.$prevMonth.'&y='.$prevYear.'">&lt;&lt; '.$stubdate->set_month($prevMonth)->month_name.' '.$prevYear.'</a> -';
    }

    if ($nextYear <= $curDate->year)
    {
      $str .= '- <a href="/index.pl?node_id='.$nodeId.'&m='.$nextMonth.'&y='.$nextYear.'">'.$stubdate->set_month($nextMonth)->month_name.' '.$nextYear.' &gt;&gt;</a>';
    }
    $str .= '</div>
    </form>
    <p><small>Writeups are displayed based on their titles, and are sorted by &quot;Create Time&quot;.<br />
    Titles and create times do not always match up (i.e., someone can post a daylog for &quot;February 28, '.($curDate->year - 10).'&quot; today, and that daylog will be displayed in the February '.($curDate->year - 10).' archive).</small></p>';

    my $dbrow;
    my $rowCtr = 0;
    my $logs = $DB->{dbh}->prepare($queryText);
    $logs->execute()
    or return $logs->errstr;

    my $daylogs = '';
    my $dreamlogs = '';
    my $editorlogs = '';
    my $rootlogs = '';
    my $curRow;

    my $daylogCtr = 0;
    my $dreamlogCtr = 0;
    my $editorlogCtr = 0;
    my $rootlogCtr = 0;

    while($dbrow = $logs->fetchrow_arrayref)
    {
        $curRow = '';
        $curRow .= '<td><a href="/index.pl?node_id='.$$dbrow[9].'">'.$$dbrow[10].'</a> ';
        $curRow .= ' (<a href="/index.pl?node_id='.$$dbrow[5].'">'.$$dbrow[8].'</a>)</td>';
        $curRow .= '<td><a href="/index.pl?node_id='.$$dbrow[2].'">'.$$dbrow[4].'</a></td>';
        $curRow .= '<td style="text-align:right;white-space:nowrap">'.$$dbrow[11].'</td>';
        $curRow .= '</tr>';

        # day logs
        if ($$dbrow[10] =~ m/^(January|February|March|April|May|June|July|August|September|October|November|December) [0-9]{1,2}, [0-9]{4}$/)
        {
            $daylogCtr++;
            if ($daylogCtr% 2 == 0)
            {
                $daylogs .= '<tr class="evenrow">'.$curRow;
            }
            else
            {
                $daylogs .= '<tr class="oddrow">'.$curRow;
            }
        }
        # dream logs
        elsif ($dbrow->[10] =~ m/^Dream Log: (January|February|March|April|May|June|July|August|September|October|November|December) [0-9]{1,2}, [0-9]{4}$/)
        {
            $dreamlogCtr++;
            if ($dreamlogCtr% 2 == 0)
            {
                $dreamlogs .= '<tr class="evenrow">'.$curRow;
            }
            else
            {
                $dreamlogs .= '<tr class="oddrow">'.$curRow;
            }
        }
        # editor logs
        elsif ($dbrow->[10] =~ m/^Editor Log: (January|February|March|April|May|June|July|August|September|October|November|December) [0-9]{4}$/)
        {
            $editorlogCtr++;
            if ($editorlogCtr% 2 == 0)
            {
                $editorlogs .= '<tr class="evenrow">'.$curRow;
            }
            else
            {
                $editorlogs .= '<tr class="oddrow">'.$curRow;
            }
        }
        # root logs
        elsif ($dbrow->[10] =~ m/^root log: (January|February|March|April|May|June|July|August|September|October|November|December) [0-9]{4}$/)
        {
            $rootlogCtr++;
            if ($rootlogCtr% 2 == 0)
            {
                $rootlogs .= '<tr class="evenrow">'.$curRow;
            }
            else
            {
                $rootlogs .= '<tr class="oddrow">'.$curRow;
            }
        }
    }

    $str .= '<table width="100%">
    <tr><th colspan="3"><h3>Day Logs</h3></th></tr>';
    if (length($daylogs) > 0)
    {
      $str .= '<tr><th>Title</th><th>Author</th><th>Create Time</th></tr>'.$daylogs;
    }
    else
    {
      $str .= '<tr><td colspan="3"><em>No day logs found</em></td></tr>';
    }

    if (length($dreamlogs) > 0)
    {
      $str .= '<tr><th colspan="3"><h3>Dream Logs</h3></th></tr><tr><th>Title</th><th>Author</th><th>Create Time</th></tr>'.$dreamlogs;
    }

    $str .= '<tr><th colspan="3"><h3>Editor Logs</h3></th></tr>';
    if (length($editorlogs) > 0)
    {
      $str .= '<tr><th>Title</th><th>Author</th><th>Create Time</th></tr>'.$editorlogs;
    }
    else
    {
      $str .= '<tr><td colspan="3"><em>No editor logs found</em></td></tr>';
    }

    $str .= '<tr><th colspan="3"><h3>Root Logs</h3></th></tr>';
    if (length($rootlogs) > 0)
    {
      $str .= '<tr><th>Title</th><th>Author</th><th>Create Time</th></tr>'.$rootlogs;
    }
    else
    {
      $str .= '<tr><td colspan="3"><em>No root logs found</em></td></tr>';
    }
    $str .= '</table>';

    return $str;
}

sub delegation_hitlist
{
  my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
  my $str = '';
  my $count = 0;
  my $types = [qw(superdoc restricted_superdoc superdocnolinks oppressor_superdoc fullpage htmlcode htmlpage nodelet ticker achievement)];

  foreach my $type (@$types)
  {
    my $nt = getType($type);
    my $csr;
    if($type eq "achievement")
    {
      $csr = $DB->sqlSelectMany('node_id','node LEFT JOIN achievement on node.node_id=achievement.achievement_id',"type_nodetype=$nt->{node_id} and code IS NOT NULL AND code !=''");
    }else{
      $csr = $DB->sqlSelectMany('node_id','node LEFT JOIN document on node.node_id=document.document_id',"type_nodetype=$nt->{node_id} AND doctext IS NOT NULL AND doctext!=''");
    }
    $str .= "<ul>$type";
    while(my $row = $csr->fetchrow_arrayref)
    {
      my $n = getNodeById($row->[0]);
      next unless $n;
      $count++;
      $str .= q|<li>|.linkNode($n).q|</li>|;
    }
    $str .= q|</ul>|;
  }

  $str .= qq|<br /><strong>$count delegations remain</strong>|;
  return $str;
}

sub suspension_info
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $isEd = $APP->isEditor($USER);
    my $isChanop = $APP->isChanop($USER);
    my %chanopSuspensionTypes = ('room' => 1, 'topic' => 1, 'chat' => 1);

    my $failMessage = q{<p>Looks like you stumbled upon a page you can't access.  Try the [Welcome to Everything|front page].</p>};

    return $failMessage unless $isEd || $isChanop;

    my $str = q|<p><strong>See also: [Node Forbiddance[restricted_superdoc]]</strong> to suspend writeup posting privileges.</p>|;

    my $userName = $query->param('lookup_name');
    my $userId = undef;
    $userId = getId(getNode($userName, 'user')) if defined $userName;
    $query->param('lookup_user', $userId) if $userId;

    my $sustypeId = $query->param('sustype');
    my $sustype = getNodeById($sustypeId);
    my $lookupUserId = $query->param('lookup_user');
    my $lookupUser = getNodeById($lookupUserId);
    my $suspensionInfo = '';

    my $invalidSustype = 0;

    if ($isChanop && !$isEd) {
        if ($sustype && !$chanopSuspensionTypes{$$sustype{title}}) {
            $invalidSustype = 1;
        }
    }

    if (htmlcode('verifyRequest', 'suspension') && $sustype && $lookupUser && !$invalidSustype)
    {
        my $outstr = '';

        if($query->param('unsuspend'))
        {
            $DB->sqlDelete('suspension', "suspension_user=$lookupUser->{node_id} and suspension_sustype=$sustype->{node_id}");
            $APP->securityLog($NODE, $USER, "$lookupUser->{title} was unsuspended from $sustype->{title} by $USER->{title}");
            $outstr = 'Suspension repealed';

        } else {

            $DB->sqlInsert('suspension', {'suspension_user' => $lookupUser->{node_id},  'suspension_sustype' => $sustype->{node_id}, 'suspendedby_user' => $USER->{node_id}});
            $APP->securityLog($NODE, $USER, "$lookupUser->{title} was suspended from $sustype->{title} by $USER->{title}");
            $outstr = 'Suspension imposed';
        }

        $str .= qq|<font color="red"><big><big><strong>$outstr</strong></big></big></font>|;
    }

    if ($lookupUser)
    {
        $str.=q|<table><tr>|;

        $str.=qq|<td valign="center">Suspension info for: <br><strong>$lookupUser->{title}</strong></td>|;

        my $sustypeTypeId = getId(getType('sustype'));
        my $suspensionRestrict = '';
        if ($isChanop && !$isEd) {
            $suspensionRestrict = 'AND title IN ('
            . join(', ', map { $DB->quote($_); } keys %chanopSuspensionTypes)
            . ')'
            ;
        }
        my $csr =
        $DB->sqlSelectMany(
            'node_id, title, doctext'
            , 'node LEFT JOIN document ON node_id = document_id'
            , "type_nodetype = $sustypeTypeId $suspensionRestrict AND title != 'email'"
        );

        my %suspension_types = ();

        while(my $row = $csr->fetchrow_hashref) {
            $suspension_types{$$row{title}} = { node_id => $$row{node_id}, desc => $$row{doctext} };
        }

        for my $suspension_name (sort keys %suspension_types) {
        my $suspension_id = $suspension_types{$suspension_name}->{node_id};
        $suspensionInfo .= "<dt>$suspension_name</dt>"
            . q|<dd>| . $suspension_types{$suspension_name}->{desc} . q|</dd>|;
        $str.=q|<td>|;
        $str.=qq|<p align="center">$suspension_name suspension</p>|;

        my $sushash =
            $DB->sqlSelectHashref(
            '*'
            , 'suspension'
            , "suspension_user = $lookupUser->{node_id} "
                . "AND suspension_sustype = $suspension_id"
            );

        my $linkParams = htmlcode('verifyRequestHash', 'suspension');
        $linkParams->{'lookup_user'} = $lookupUser->{node_id};
        $linkParams->{'sustype'} = $suspension_id;

        if($sushash)
        {
            $str.= '<p align="center"><small>'
                . 'Suspended by '
                . linkNode(getNodeById($sushash->{suspendedby_user}))
                . '</small></p>'
                ;

            my $orig_started = $sushash->{started};
            $sushash->{started} ||= '00000000000000';
            $sushash->{started} =~ /(\d{4})-?(\d{2})-?(\d{2})\s*(\d{2}):?(\d{2}):?(\d{2})/;

            $str .= q|<p align="center"><small><small>|
                . "on $2-$3-$1 at $4:$5:$6 "
                . q|</small></small></p>|
                ;
            $linkParams->{'unsuspend'} = 1;
            $str .= q|<p align="center"><small>|
                . linkNode($NODE,'Unsuspend', $linkParams)
                . q|</small></p>|
                ;

        }
        else
        {
            $str.=q|<p align="center"><small><em>No restriction</em></small></p>|;
            $str.=q|<p align="center"><small>|
                . linkNode($NODE, 'Suspend', $linkParams)
                . q|</small></p>|;
        }
        $str.=q|</td>|;
        $str.=q|<td width="30"> </td>|;

        }

        $str.=q|</tr></table><br><br>|;
    }

    my $formFields = htmlcode('verifyRequestForm', 'suspension')
    . $query->textfield(-name => 'lookup_name')
    . $query->submit(-value => 'Check info')
    ;

    $suspensionInfo = "<dl>\n$suspensionInfo\n</dl>" if $suspensionInfo ne '';

    $str.=htmlcode('openform', 'suspensionlookupform');
    $str.= qq|Check suspension info for: $formFields</form>

    <hr width="200">

    <strong>General Information:</strong>
    <p>Each type of suspension carries its own weight.  More can be added later, but for right now, this works.  Borging and account locking may eventually move to this one interface.</p>

    $suspensionInfo

    <p>
    Keep in mind that the punishment should fit the crime, and that systematic downvoting is not a "crime" at all, regardless of what an asshole thing to do that it is. Autovoters, C! abusers, etc.  Use these sparingly, but as needed.
    </p>
    |;

    return $str;
}

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

sub websterbless
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $output = q|<p>A simple tool used to reward users who suggest writeup corrections to [Webster 1913].</p>|;

    # Display explanatory text to the gods group and designated Webby secretaries.
    my $notestr = 'Users are blessed with 3 GP and receive an automated thank-you note from Webster 1913:<br /><br />';
    $notestr .= '<blockquote><em>[Webster 1913] says re [Writeup name]: Thank you! My servants have attended to any errors.</em></blockquote><br />';
    $notestr .= 'Writeup name is optional (this parameter is pure text, it is not checked in any way).<br /><br />';

    # Display a count of Webby's messages, if non-zero. This count links to Webby's mailbox. The link currently works only for gods.
    # TODO: Make mailbox link work for Webby secretaries.
    # (The following is adapted from showmessages)
    # ... make SQl query text for Webster 1913's messages
    my $limits = 'for_user='.getId(getNode('Webster 1913', 'user'));
    # ... total messages for user, archived and not, group and not, from all users
    my $totalMsg = $DB->sqlSelect('COUNT(*)','message',$limits);
    # ... display the number of messages in Webster 1913's Message Inbox.
    my $moreMsgStr = '';
    if($totalMsg) {
        $moreMsgStr .= '<a href='.urlGen({node=>'Message Inbox', type=>'superdoc',spy_user=>'Webster 1913'}).'>'.$totalMsg.'</a> messages total';
    }

    # Display the number of messages Webster has, and link to Message Inbox
    $output .= $notestr;
    # Display the note text and the message text (if any).
    $output .=  '<br />Webster 1913 has ' . $moreMsgStr . '<br /><br />' if length($moreMsgStr);

    #Adapted from superbless
    my @params = $query->param;
    my $str = '';

    # Get the list of users to be thanked.
    my (@users, @thenodes);
    foreach (@params)
    {
        if(/^webbyblessUser(\d+)$/)
        {
            $users[$1] = $query->param($_);
        }

        if(/^webbyblessNode(\d+)$/)
        {
            $thenodes[$1] = $query->param($_);
        }
    }

    # For this purpose the bless is fixed at 3 GP.
    my $curGP = 3;

    # Loop through, apply the bless, report the results
    for(my $count=0; $count < @users; $count++)
    {
        next unless $users[$count];

        my ($U) = getNode ($users[$count], 'user');
        if (not $U)
        {
            $str.="couldn't find user $users[$count]<br />";
            next;
        }

        # Send an automated thank-you.
        htmlcode('sendPrivateMessage',{
            'recipient_id'=>getId($U),
            'message'=>'Thank you! My servants have attended to any errors.',
            'author'=>'Webster 1913',
            'renode'=>$thenodes[$count]});

        $str .= "User $$U{title} was given $curGP GP";
        $U->{karma}+=1;
        updateNode($U, -1);
        htmlcode('achievementsByType','karma');
        $APP->securityLog(getNode('Superbless', 'superdoc'), $USER, "$$USER{title} [Websterbless|Websterblessed] $$U{title} with $curGP GP.");
        $APP->adjustGP($U, $curGP);
        $str .= "<br />\n";
    }

    $output .= $str;
    $output .= htmlcode('openform');
    $output .= q|<table border="1">|;


    # Build the table rows for inputting user names
    my $count = 5;
    $str = '';
    $str.= q|<tr><th>Thank these users</th><th>Writeup name</th></tr>|;

    for (my $i = 0; $i < $count; $i++)
    {
        $query->param("webbyblessUser$i", '');
        $query->param("webbyblessNode$i", '');
        $str.=q|<tr><td>|;
        $str.=$query->textfield("webbyblessUser$i", '', 40, 80);
        $str.=q|</td><td>|;
        $str.=$query->textfield("webbyblessNode$i", '', 40, 80);
        $str.=q|</td></tr>|;
    }

    $output .= $str.q|</table>|.htmlcode('closeform');
    return $output;
}

sub login
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $str = '';
    if($query->param('op') eq 'login' && !$APP->isGuest($USER))
    {
        $str.= "Hey.  Glad you're back.  Would you like to go to your ".linkNode($USER, 'home node').' or to '.linkNode($Everything::CONF->default_node).'?<br />';
        $str .= '...or back to '.linkNode($query->param('lastnode_id')).'?<br />' if ($query->param('lastnode_id'));
        return $str;
    } elsif ($query->param('op') eq 'login') {
        $str .= q|Oops.  You must have the wrong login or password or something:<p>|;
    } elsif (!$APP->isGuest($USER)) {
        $str.=q|Hey, |.linkNode($USER).q|...  this is where you log in:<p>|;
    }else {
        $str .=q|Welcome to |.$Everything::CONF->site_name.q|.  Authenticate yourself:<p>|;
    }

    #security fix
    my $pass = $query->param('passwd');
    $pass =~ s/./\*/g;
    $query->param('passwd', $pass);

    $str .= q|<form method="POST" action="|.$ENV{SCRIPT_NAME}.q|" id="loginsuperdoc">|.
        q|<input type="hidden" name="op" value="login" />|.
        $query->hidden('node_id', getId($NODE))."\n".
        $query->hidden('lastnode_id', scalar($query->param('lastnode_id')))."\n".

    $query->textfield (-name => 'user',
        -size => 20,
        -maxlength => 20) . q|<br>| .
    $query->password_field(-name => 'passwd',
        -size => 20,
        -maxlength => 240) .q|<br>|.
    $query->checkbox('expires', '', '+10y', 'save me a permanent cookie, cowboy!').
    $query->submit('sexisgood', 'submit') .
    $query->end_form;
    $str.=q{[Reset password[superdoc]|Forgot your password or username?]};
    $str.=q{<p>Don't have an account? [Sign up[superdoc]|Create one]!};
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
        return q{<p>It is not possible to sanctify yourself!</p><p>Would you like to [Sanctify user|try again on someone else]?</p>} if ($USER->{title} eq $recipient);
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

sub everything_statistics
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $str = '';

    # Total Number of Nodes
    my $total_nodes = $DB->sqlSelect('count(*)', 'node');
    $str .= "<p>Total Number of Nodes: $total_nodes</p>";

    # Total Number of Writeups
    my $writeup_type = getType('writeup');
    my $total_writeups = $DB->sqlSelect('count(*)', 'node', 'type_nodetype=' . getId($writeup_type));
    $str .= "<p>Total Number of Writeups: $total_writeups</p>";

    # Total Number of Users
    my $total_users = $DB->sqlSelect('count(*)', 'user');
    $str .= "<p>Total Number of Users: $total_users</p>";

    # Total Number of Links
    my $total_links = $DB->sqlSelect('count(*)', 'links');
    $str .= "<p>Total Number of Links: $total_links</p>";

    # Footer text
    $str .= '<p>You may also find the ' . linkNode(getNode('Everything Finger', 'superdoc'), 'Everything Finger') . ' interesting if you are looking to pull something useful out of all these nodes. Useful? Ha.</p>';
    $str .= '<p>' . linkNode(getNode('news for noders.  stuff that matters.', 'document')) . '</p>';

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
    my $view_weblog = $query->param('view_weblog');
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
        $link = "<b>$link</b>" if $node_id == $view_weblog;
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

sub settings
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $text = '';

    # Block 1: Guest check and initialization
    if ($APP->isGuest($USER)) {
        return '<p>You need to sign in or ' . linkNode(getNode('Sign up','superdoc'), 'register') . ' to use this page.</p>';
    }

    # Save last updated time for preferences (DateTime loaded at top)
    if (defined $query->param('sexisgood')) {
        $$VARS{'preference_last_update_time'} = DateTime->now()->epoch()-60;
    }
    $PAGELOAD->{pageheader} = '<!-- put at end -->'.htmlcode('settingsDocs');
    $text .= htmlcode('openform',-id=>'pagebody');

    # Static HTML: Look and feel section
    $text .= '<h2 id="appearance">Look and feel</h2>';
    $text .= '<fieldset><legend>Style</legend>';

    # Block 2: Style selection
    if($query->param('chosenstyle')) {
        my $style = getNodeById(scalar $query->param('chosenstyle'));
        my $style_type = '';
        $style_type = $$style{type}{title} if $style;
        if ($style_type eq 'stylesheet' or $query->param('chosenstyle') eq 'default' ){
            delete $$VARS{userstyle};
            $$VARS{userstyle} = $$style{node_id} if $style;
        }
    }

    my $sheets = undef;
    my $supported_sheets = $DB->getNodesWithParam("supported_sheet");
    foreach my $thissheet (@$supported_sheets) {
        my $fixlevel = $APP->getParameter($thissheet, "fix_level");
        my $sh = getNodeById($thissheet);

        my $auth = getNodeById($$sh{author_user});
        my $author_string = "";
        if($auth) {
            $author_string = " by ".$auth->{title};
        }
        $$sheets{$thissheet} = $$sh{title}.($$sh{title} ne $Everything::CONF->default_style ? $author_string : ' (default)');
    }

    $$sheets{ $$VARS{userstyle} } = getNodeById($$VARS{userstyle})->{title}
        unless !$$VARS{userstyle} || $$sheets{ $$VARS{userstyle} };

    my @values = ( 'default' , keys %$sheets );
    $$sheets{default} = '(default)';
    $$sheets{ $$VARS{userstyle} } .= '*' if $$VARS{userstyle};
    my $str = 'Choose a style: ' . $query->popup_menu( -name => 'chosenstyle', -id => 'settings_styleselector', values=> \@values,
        labels=>$sheets, default=>$$VARS{userstyle}||'default');

    $text .= "$str";

    # Static HTML: Style options and Quick functions
    $text .= htmlcode('varcheckboxinverse', 'nogradlinks', 'Show the softlink color gradient') . '<br>';
    $text .= '</fieldset>';
    $text .= '<fieldset><legend>Quick functions</legend>';

    if ($$VARS{noquickvote}) {
        $text .= htmlcode('varcheckboxinverse', 'noquickvote', 'Enable quick functions (a.k.a. AJAX).');
        $text .= '<br><small>(Voting, cooling, chatting, etc will no longer require complete pageloads. Highly recommended.)</small><br>';
    }

    $text .= '<label>On-page transitions:' . htmlcode('varsComboBox', 'fxDuration', '0', '1', 'Off (instant)', '100', 'Supersonic', '150', 'Faster', '0', 'Fast (default)', '300', 'Less fast', '400', 'Medium', '600', 'Slow', '800', 'Slower', '1000', 'Glacial') . '</label>';
    $text .= '<br>';
    $text .= htmlcode('varcheckboxinverse', 'noreplacevotebuttons', 'Replace ');
    $text .= '<label><input type="radio" name="sampledummy">+</label><label><input type="radio" name="sampledummy">-</label>';
    $text .= ' voting buttons with <input type="button" value="Up"><input type="button" value="Down"> buttons.';
    $text .= '<br>';
    $text .= htmlcode('varcheckbox', 'votesafety', 'Ask for confirmation when voting.');
    $text .= '<br>';
    $text .= htmlcode('varcheckbox', 'coolsafety', 'Ask for confirmation when cooling writeups.') . '<br>';
    $text .= '</fieldset>';

    # Static HTML: Your writeups section
    $text .= '<h2 id="writeups">Your writeups</h2>';
    $text .= '<fieldset><legend>Editing</legend>';
    $text .= htmlcode('varcheckbox', 'HideWriteupOnE2node', 'Only show your writeup edit box text on the writeup\'s own page');
    $text .= ' (useful for slow connections; [E2 Options: Don\'t default to writeup edit on e2nodes|more information])<br>';
    $text .= htmlcode('varcheckbox', 'settings_useTinyMCE', 'Use WYSIWYG content editor to format writeups') . '<br>';
    $text .= 'Writeup edit box display size: ' . htmlcode('varsComboBox', 'textareaSize', '0', '0', '20 x 60 (Small) (Default)', '1', '30 x 80 (Medium)', '2', '50 x 95 (Large)');
    $text .= '([E2 Options: Editbox size choices|more information])<br>';
    $text .= '</fieldset>';
    $text .= '<fieldset><legend>Writeup Hints</legend>';
    $text .= 'Check for some common mistakes made in creating or editing writeups.<br>';
    $text .= htmlcode('varcheckboxinverse', 'nohints', 'Show critical writeup hints') . ' (recommended: on)<br>';
    $text .= htmlcode('varcheckboxinverse', 'nohintSpelling', 'Check for common misspellings') . ' (recommended: on)<br>';
    $text .= htmlcode('varcheckboxinverse', 'nohintHTML', 'Show HTML hints') . ' (recommended: on)<br>';
    $text .= htmlcode('varcheckbox', 'hintXHTML', 'Show strict HTML hints') . '<br>';
    $text .= htmlcode('varcheckbox', 'hintSilly', 'Show silly hints');
    $text .= '</fieldset>';

    # Static HTML: Other users section
    $text .= '<h2 id="noders">Other users</h2>';
    $text .= '<fieldset><legend>Other users\' writeups</legend>';
    $text .= '<label>Anonymous voting:' . htmlcode('varsComboBox', 'anonymousvote', '0', '0', 'Always show author\'s username', '1', 'Hide author completely until I have voted on a writeup', '2', 'Hide author\'s name until I have voted but still link to the author');
    $text .= '</label>';
    $text .= '</fieldset>';

    # Block 3: Favorite noders and message blocking
    $str = '';  # REINITIALIZE for mod_perl
    my $favoritelinktype = getId(getNode("favorite","linktype"));

    my $csr = $DB->sqlSelectMany("*","links", "from_node = $$USER{'node_id'} AND linktype = $favoritelinktype");

    my @list = ();
    while( my $favnoder = $csr->fetchrow_hashref) {
        $favnoder = getNodeById($$favnoder{'to_node'});
        push @list, '<li>'.$query->checkbox('cutlinkto_'.$$favnoder{'node_id'},'','1','').linkNode($favnoder).'</li>';
    }

    if(@list) {
        $str .= '<fieldset><legend>Favorite other users</legend>Your favourite noders are:<ul>';
        $str .= join("",@list);
        $str .= '</ul><input type="hidden" name="op" value="linktrim">';
        $str .= htmlcode('verifyRequestForm', 'linktrim');
        $str .= $query->hidden("cutlinkfrom",$$USER{'node_id'});
        $str .= $query->hidden("linktype",$favoritelinktype);
        $str .= 'Check a user\'s name to remove them from the list.</fieldset>';
    }

    $str .= '<fieldset><legend>Less favorite other users</legend>';

    if(my $uname = $query->param('nomail')) {
        htmlcode('ignoreUser',"$uname");
    }

    foreach ($query->param) {
        next unless /restore_(\d+)/;
        my $restore = $1;
        $DB->sqlDelete('messageignore', "messageignore_id=$$USER{node_id} and ignore_node=$restore");
    }

    $str .= 'Block messages from: ';
    $str .= $query->textfield(-name=>'nomail', default=>'', override=>'1');
    $str .= '<br><small>(If you enter a user name here, you will not receive private messages from this person or see their comments in the Chatterbox. If you enter a group, you will not receive messages to that group.)</small><br>';

    $csr = $DB->sqlSelectMany('ignore_node', 'messageignore', 'messageignore_id='.$$USER{node_id});
    @list = ();  # REINITIALIZE for mod_perl
    while (my ($u) = $csr->fetchrow) {
        push @list, '<li>'.$query->checkbox('restore_'.$u, '', '1', '').linkNode($u).'</li>';
    }
    $csr->finish;

    if (@list) {
        $str .= '<br>You are ignoring:<ul>'.join("",@list).'</ul>';
        $str .= 'Check a user\'s name to remove them from the list.<br>';
        $str .= '<small>More thorough ignoring is available at the [Pit of Abomination].</small><br>';
    }

    $str .= '<br>If one of your messages is blocked, you will be informed:';
    $str .= htmlcode('varsComboBox','informmsgignore','0', '0','by private message','1','in the chatterbox',2,'both ways',3,'do not inform (bad idea)');
    $str .= '<br><small>(<strong>Warning</strong>: "do not inform" could lead to you engaging in a one-sided conversation without noticing.)</small></p>';
    $str .= '</fieldset>';

    $text .= $str.'<br>';

    # Static HTML: JavaScript theme config and close form
    $text .= '<script type="text/javascript">THEME = {"default_style": "'.$Everything::CONF->default_style.'"}</script>';
    $text .= htmlcode('closeform', 'Save Settings');

    return $text;
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

sub the_well_of_cool
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $text = '';
    my $str = '';

    if ($query->param("Drink deeply from the well of cool")) {
        $$VARS{cools} += 1;
    }

    $str .= htmlcode('openform');
    $str .= $query->submit('Drink deeply from the well of cool');
    $str .= $query->end_form;

    $text .= $str;

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

sub my_big_writeup_list
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    #
    #  Again, Gorgonzola takes perfectly good E2 code and twists it
    #  to his nefarious purposes
    #

    my $user_id = $$USER{node_id} || 0;

    if ( $APP->isGuest($USER) ) {
        return
              'You need an account to access this node.<br /><br />.'
            . 'Why not '
            . linkNode( getNode( 'Sign Up', 'superdoc' ), 'create one' ) . '?';
    }
    my ($name) = @_;
    $name ||= "";

    my $str = htmlcode('openform');

    my $victim = $query->param('usersearch');
    $victim = $$USER{title} unless ($victim);

    if ( $APP->isAdmin($USER) ) {
        $str .= $query->textfield( 'usersearch', $victim );
    } else {
        $str .= $query->hidden( 'usersearch', $victim );
        $str .= 'For: ' . $$USER{title};
    }

    #N-Wing converted this from FormMenu to plain old CGI so items could be in a logical order

    #this sets the ordering of items in the combo box
    my $choices = [
        'title ASC',
        'wrtype_writeuptype ASC,title ASC',
        'cooled DESC,title ASC',
        'cooled DESC,node.reputation DESC,title ASC',
        'node.reputation DESC,title ASC',
        'writeup.publishtime DESC',
        'writeup.publishtime ASC'
    ];

    my $labels = {
        'title ASC'                                    => 'Title',
        "wrtype_writeuptype ASC,title ASC"             => "Writeup type, then title",
        "cooled DESC,title ASC"                        => "C!, then title",
        'cooled DESC,node.reputation DESC,title ASC'   => 'C!, then reputation',
        'node.reputation DESC,title ASC'               => 'Reputation',
        'writeup.publishtime DESC'                     => 'Date, most recent first',
        'writeup.publishtime ASC'                      => 'Date,most recent last'
    };

    my $raw = $query->param('raw');
    $str .= $query->hidden('filterhidden');

    $str .=
        "Order By:"
        . $query->popup_menu( 'orderby', $choices, 'title ASC', $labels );
    $str .=
        "<br />"
        . $query->checkbox( -name => 'raw', -label => 'Raw Data', -checked => $raw );
    my $fdelim = $query->param('delimiter');
    $fdelim = "_" unless ($fdelim);
    $str .=
          "&nbsp;&nbsp;Delimiter: "
        . $query->textfield( 'delimiter', $fdelim )
        . "<br />";
    $str .= $query->submit( "sexisgood", "submit" ) . $query->end_form;
    $text .= $str;

    # REINITIALIZE variables for second code block
    $user_id = $$USER{node_id} || 0;

    if ( $APP->isGuest($USER) ) {
        return $text;
    }

    my $isRoot = $APP->isAdmin($USER);
    my $us     = undef;
    my $israw  = $query->param('raw');

    if ($isRoot) {
        $us = $query->param('usersearch');    #user's title to find WUs on
    } else {
        $us = $$USER{title};
    }
    my $orderby = $query->param('orderby');
    my $delim   = $query->param('delimiter');

    return $text unless ($orderby);
    my $orderdata = {
        'title ASC'                                  => 1,    # Title
        'wrtype_writeuptype ASC,title ASC'           => 1,    # Writeup type, then title
        'cooled DESC,title ASC'                      => 'Number C!',    # Number of C!
        'cooled DESC,node.reputation DESC,title ASC' =>
            'C! then rep',                                     # Number of C!, then rep, title
        'node.reputation DESC,title ASC' => 'Reputation',     # Reputation
        'writeup.publishtime DESC'       => 'Date, most recent first',
        'writeup.publishtime ASC'        => 'Date, most recent last'
    };
    $orderby = '' unless exists $$orderdata{$orderby};

    #NOTE:  we must CHECK to make sure orderby is one of
    #our valid options, otherwise a user could potentially
    #execute arbitrary SQL -- VERY BAD

    $orderby ||= 'title ASC';

    if ($israw) {
        return $text . "Delimiter (" . $delim . ") must be exactly one character."
            unless ( length($delim) == 1 );
    }

    #quit if no user given to get info on
    return $text . 'It helps to give a user\'s nick.' unless $us;

    #quit if invalid user given
    my $user = getNode( $us, 'user' );

    my $usEncode = encodeHTML($us);
    return
          $text
        . "It seems that the user '$usEncode' doesn't exist... how very, very strange... (Did you type their name correctly?)"
        unless ( defined $user );
    return $text
        . 'Are you really looking for almost all the words in the English language?'
        if $$user{title} eq 'Webster 1913';

    #constants setup
    my $uid = getId($user) || 0;    #lowercase = user searching on

    my $isMe = ( $uid == $user_id ) && ( $uid != 0 );
    my $rep  = $isMe || $isRoot;

    $str = '';

    my $isEd = $rep || ( $APP->isEditor($USER) );

    #quit for special bots

    return $text
        . '<p align="center"><big><big><strong>G r o w l !</strong></big></big>'
        if ( $$user{title} eq 'EDB' );

    return $text
        . '<p align="center"><big><big><strong>Um, no.</strong></big></big>'
        if ( $$user{title} eq 'Webster 1913' );

    #load writeup information

    #database setup
    my $qh     = undef;             #query handle
    my $typeID = getId( getType('writeup') ) || 0;

    #
    # total writeup count

    #

    $qh = $DB->{dbh}
        ->prepare( 'SELECT COUNT(*) FROM node WHERE author_user='
            . $uid
            . ' AND type_nodetype='
            . $typeID );

    $qh->execute();
    my ($totalWUs) = $qh->fetchrow();
    $qh->finish();

    return $text . linkNode($user) . ' has no writeups' . '.'
        unless $totalWUs;

    #load in only writeups we're currently looking at
    $qh = $DB->{dbh}->prepare(
              'SELECT parent_e2node, title, cooled, reputation, publishtime'
            . ', totalvotes'
            . ' FROM node, writeup WHERE node.author_user='
            . $uid
            . ' AND node.type_nodetype='
            . $typeID
            . ' AND writeup.writeup_id=node.node_id'
            . ' ORDER BY '
            . $orderby

            #    ' LIMIT 1,50'  #comment this out after debug
    );
    $qh->execute();    #gets current WUs and their info
    my @allWUInfo = ();
    while ( my $r = $qh->fetchrow_hashref ) {
        push( @allWUInfo, $r );
    }
    $qh->finish();

    #done with getting writeup info, the rest is just display

    $str .=
          ( $totalWUs == 1 ? 'This writeup was' : 'These ' . $totalWUs . ' writeups were all' )
        . ' written by '
        . linkNode( $user, ( $isMe ? 'you' : 0 ), { lastnode_id => 0 } )
        . ":</p>\n";

    #prepare for loop
    my $drn  = 0;       #display row number - for row coloring
    my $wuid = undef;   #current WU's ID

    #loop through WUs, and show their info
    if ($israw) {
        $str .= "<pre>";
        foreach my $wu (@allWUInfo) {

            $wuid = getId($wu);

            $str .= $$wu{title} . $delim;

            if ( $$wu{cooled} ) {
                $str .= "$$wu{cooled}C!" . $delim;
            } else {
                $str .= " " . $delim;
            }

            if ($rep) {
                $str .= $$wu{reputation} . $delim;

                my $votescast = $$wu{totalvotes};

                $str .= $votescast . $delim;
            }

            $str .= htmlcode( 'parsetimestamp', "$$wu{publishtime}" ) . "\n";
        }
        $str .= "</pre>";

    } else {

        #header

        $str .=
              '<table border="0" cellpadding="1" cellspacing="0">' . "\n"
            . '<tr><th align="left">Writeup Title (type)</th><th>C!</th>';
        $str .= '<th colspan="2" align="center">Rep</th>' if $rep;
        $str .= '<th align="center">Published</th>';
        $str .= "</tr>\n";
        foreach my $wu (@allWUInfo) {

            $wuid = getId($wu);

            $str .= '<tr';
            $str .= ' class="oddrow" bgcolor="#bbbbff"' unless ( $drn % 2 );
            $str .= '>';

            $str .=
                  '<td nowrap>'
                . linkNode( $$wu{parent_e2node}, $$wu{title}, { lastnode_id => 0 } )
                . '</td><td>';
            $str .= " <strong>$$wu{cooled}C!</strong>&nbsp;" if $$wu{cooled};
            $str .= '</td>';

            if ($rep) {
                my $r = $$wu{reputation} || 0;

                my $votescast = $$wu{totalvotes};
                my $p         = ( $votescast + $r ) / 2;
                my $m         = ( $votescast - $r ) / 2;
                $str .=
                      '<td>' . $r
                    . '</td><td><small>+'
                    . $p . '/-'
                    . $m
                    . '</small></td>';
            }

            $str .=
                  '<td nowrap align="right"><small>'
                . htmlcode( 'parsetimestamp', "$$wu{publishtime}" )
                . "</small></td></tr>\n";

            ++$drn;
        }
        $str .= "</table>\n";
    }

    $text .= $str;
    return $text;
}

sub site_trajectory_2
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    $text .= '<style>
<!--
th {
  text-align:left;
}
.graph td {
  border-bottom: 1px solid #ccc;
  border-right: 1px solid #ccc;
  padding: 3px;
}
.graph div {
  position: relative;
/*  line-height: 25px;*/
  height: 25px;
  width: 100%;
}
.bar {
  background-color: #9e9;
  padding: 0px;
  display: block;
  position: absolute;
  left: 0;
  top: 0;
  z-index: 1;
  box-sizing: border-box;
  height: 100%;
}
.val {
  z-index: 100;
  display: block;
  position: absolute;
  left: 5px;
  top: 2px;
}
-->
</style>

';

    my $monthsago = 1;
    my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) =
        gmtime(time);
    $year += 1900;
    my $strMonth = undef;
    my $backyear = int( $query->param("y") ) || $year - 5;

    # no nodes before 1999
    if ( $backyear < 1999 ) {
        $backyear = 1999;
    }

    my $str =
          '<form method="get" action="/index.pl">
         <input type="hidden" name="node_id" value="'
        . $$NODE{node_id} . '" />
         <b>Report back to </b>
         <select name="y">
         <option value="'
        . $backyear . '">'
        . $backyear
        . '</option>';
    for ( my $i = $year ; $i > 1999 ; $i-- ) {
        $str .= '<option value="' . $i . '">' . $i . '</option>';
    }
    $str .=
          '<option value="1999">1999 (not suggested)</option>
         </select>
         <input type="submit" value="Go" />
         </form>
         <hr />
         <table width="100%" class="graph">
         <tr>
         <th>Month</th>
         <th>New Writeups</th>
         <th>Contributing Users</th>
         <th>C!s Spent</th>
         <th title="ratio of all C!s spent to new writeups">C!:NW</th>
         </tr>';

    $monthsago = 1;
    my $maxwucnt    = 1;
    my $maxusercnt  = 1;
    my $maxcoolcnt  = 1;
    my $maxcnwratio = .1;
    while ( $year >= $backyear ) {
        $strMonth = ( $month + 1 ) . '';
        if ( length($strMonth) == 1 ) {
            $strMonth = "0" . $strMonth;
        }
        my $strDate = $year . "-" . $strMonth . "-01";
        my $limit =
              'type_nodetype='
            . getId( getType('writeup') )
            . " and publishtime >= '"
            . $strDate
            . "' and publishtime < DATE_ADD('"
            . $strDate
            . "',INTERVAL 1 MONTH)";

        my $wucnt = $DB->sqlSelect( 'count(*)',
            'node JOIN writeup on writeup.writeup_id=node.node_id', $limit );
        if ( $wucnt > $maxwucnt ) {
            $maxwucnt = $wucnt;
        }

        # this query counts contributing users (new and old)
        $limit =
              "type_nodetype='"
            . getId( getType('writeup') )
            . "' AND createtime>='"
            . $strDate
            . "' AND createtime<DATE_ADD('"
            . $strDate
            . "',INTERVAL 1 MONTH)";
        my $usercnt = $DB->sqlSelect( 'count(DISTINCT author_user)', 'node', $limit );
        if ( $usercnt > $maxusercnt ) {
            $maxusercnt = $usercnt;
        }

        $limit =
              "tstamp >= '"
            . $strDate
            . "' and tstamp < DATE_ADD('"
            . $strDate
            . "',INTERVAL 1 MONTH)";

        my $coolcnt = $DB->sqlSelect( 'count(*)', 'coolwriteups', $limit );
        if ( $coolcnt > $maxcoolcnt ) {
            $maxcoolcnt = $coolcnt;
        }

        my $cnwratio = $wucnt ? $coolcnt / $wucnt : 0;
        if ( $cnwratio > $maxcnwratio ) {
            $maxcnwratio = $cnwratio;
        }

        $str .= "\n<tr>";
        $str .= '<td class="DateLabel">';
        if ( $month == 0 ) {
            $str .= '<b>' . ( $month + 1 ) . '/' . ($year) . '</b>';
        } else {
            $str .= ( $month + 1 ) . '/' . ($year);
        }
        $str .= '</td>';

        $str .=
              '<td><div><span class="val">'
            . $wucnt
            . '</span><span class="bar wubar" style="width:'
            . ( $wucnt * 100.0 / 11060.0 )
            . '%;" data-value="'
            . $wucnt
            . '">&nbsp;</span></div></td>
           <td><div><span class="val">'
            . $usercnt
            . '</span><span class="bar userbar" style="width:'
            . ( $usercnt * 100.0 / 1230.0 )
            . '%;" data-value="'
            . $usercnt
            . '">&nbsp;</span></div></td>
           <td><div><span class="val">'
            . $coolcnt
            . '</span><span class="bar coolbar" style="width:'
            . ( $coolcnt * 100.0 / 6650.0 )
            . '%;" data-value="'
            . $coolcnt
            . '">&nbsp;</span></div></td>
           <td><div><span class="val">'
            . sprintf( "%.2f", $cnwratio )
            . '</span><span class="bar cnwratio" style="width:'
            . ( $cnwratio * 100.0 / 4.0 )
            . '%;" data-value="'
            . $cnwratio
            . '">&nbsp;</span></div></td>
           </tr>';

        $month--;
        if ( $month < 0 ) {
            $month = 11;
            $year--;
        }
        $monthsago++;

    }
    $str .= "</table>";

    $str .=
          '<script>
$(document).ready(function() {
  var maxwucnt = '
        . $maxwucnt . ';
  var maxusercnt = '
        . $maxusercnt . ';
  var maxcoolcnt = '
        . $maxcoolcnt . ';
  var maxcnwratio= '
        . $maxcnwratio . ';
  $(".wubar").each(function(index) {
    $(this).css("width", (parseInt($(this).data("value")) * 100.0 / maxwucnt) + "%");
  });
  $(".userbar").each(function(index) {
    $(this).css("width", (parseInt($(this).data("value")) * 100.0 / maxusercnt) + "%");
  });
  $(".coolbar").each(function(index) {
    $(this).css("width", (parseInt($(this).data("value")) * 100.0 / maxcoolcnt) + "%");
  });
  $(".cnwratio").each(function(index) {
    $(this).css("width", (parseFloat($(this).data("value")) * 100.0 / maxcnwratio) + "%");
  });
});
</script>';

    $text .= $str;
    return $text;
}

sub node_row
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    return $text unless ( $APP->isEditor($USER) );

    my $str =
          'There are '
        . $DB->sqlSelect( 'COUNT(*)', 'weblog',
        'weblog_id=' . $$NODE{node_id} )
        . ' waiting on Node Row.  Of those, you removed '
        . $DB->sqlSelect(
        'COUNT(*)',
        'weblog',
        'weblog_id='
            . $$NODE{node_id}
            . ' AND linkedby_user='
            . $$USER{user_id}
        ) . '.<br /><br />';

    $text .= $str;
    $text .= htmlcode( 'weblog', '10', '', 'restore', '1', '0' );

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

sub noding_speedometer
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    #constants
    my $user_id = getId($USER);
    my $isGuest = $APP->isGuest($USER);
    my $isRoot  = $APP->isAdmin($USER);

    return 'Sorry, but only registered members can use the Noding Speedometer.'
        if $isGuest;

    my $user_in  = $query->param('speedyuser');
    my $username = $user_in || $$USER{title};
    $username = encodeHTML($username);

    # A non-number will break the page, so:
    my $clock_nodes = $query->param('clocknodes');
    unless ($clock_nodes) { $clock_nodes = 50 }
    unless ( $clock_nodes =~ /^[0-9]+$/ ) {
        return "Please enter a number of nodes greater than 0.";
    }
    my $str =
          htmlcode('openform')
        . "<table><tr><td>Username: </td><td><input type=\"text\" name=\"speedyuser\" value=\"$username\"></td></tr><tr><td>Nodes to clock: </td><td><input type=\"text\" name=\"clocknodes\" value=\""
        . $clock_nodes
        . "\"></td></tr></table>"
        . htmlcode('closeform') . "<br>";

    return $str .= "Okay, the radar gun's ready.  Who should we clock?"
        unless ($user_in);

    my $u = getNode( $user_in, 'user' );
    return $str .=
        "<br><br>Your aim is way off. "
        . encodeHTML($user_in)
        . " isn't a user. Try again."
        unless ($u);

    my $initcnt = $DB->sqlSelect( "count(*)", "node",
            "author_user=$$u{user_id} AND type_nodetype="
            . getId( getType('writeup') ) );

    return $str .= "<br><br>Um, user $$u{title} has no writeups!"
        if ( $initcnt == 0 );

    $str .= "$$u{title} has <b>$initcnt</b> nodes in total. ";
    my $cnt = undef;

    if ( $initcnt >= $clock_nodes ) {
        $cnt = $clock_nodes;
    } else {
        $str .=
              "Since it's less than "
            . $clock_nodes
            . ", we'll just clock them for $initcnt.<br>";
        $cnt = $initcnt;
    }

    my $lastcnt = $DB->sqlSelect(
        "TO_DAYS(NOW())-TO_DAYS(publishtime)",
        "node JOIN writeup ON writeup_id=node_id",
        "author_user=$$u{node_id} ORDER BY publishtime DESC limit "
            . ( $cnt - 1 ) . ",1"
    );

    if ( $lastcnt < 1 ) {
        $str .= "<br><br>Wait a while, ";
        return $str
            . "do at least one [day|lap] around the track before timing yourself."
            if ( $$USER{node_id} == $$u{node_id} );
        return $str . "let ["
            . $$u{title}
            . "] do at least one [day|lap] around the track before timing them.";
    }

    my $speed = $lastcnt / $cnt;

    $str .=
          "To write the last $cnt nodes, it took $$u{title} $lastcnt days.   This works out at <b>"
        . sprintf( "%.2f", $speed )
        . "</b> days per node.<br><br>";

# Setting arbitrary speed values. I guess 1 node per day or faster is RED hot, less than 3 days per node is ORANGE, less than 7 days per node is YELLOW, and anything slower is GREEN.

    my $color   = "white";
    my $width   = "0";
    my $comment = "";

    SWITCH: {
        if ( $speed <= 0.75 ) {
            $color   = "#6600CC";
            $width   = "100";
            $comment =
                "$$u{title} has broken the speedometer and is probably not even human...";
            last SWITCH;
        }
        if ( $speed <= 1 ) {
            $color = "red";
            $width = "90";
            $comment =
                "[THE IRON NODER CHALLENGE|IRON NODER] speed! $$u{title} has been issued a [social life|ticket].";
            last SWITCH;
        }
        if ( $speed <= 3 ) {
            $color   = "orange";
            $width   = "75";
            $comment = "Pretty fast! A warning and a doughnut bribe may be in order.";
            last SWITCH;
        }
        if ( $speed <= 7 ) {
            $color   = "yellow";
            $width   = "50";
            $comment = "Nothing the node police need to worry about just yet.";
            last SWITCH;
        }
        if ( $speed <= 20 ) {
            $color   = "green";
            $width   = "25";
            $comment =
                "We all get there in our own time, even if we cause tailbacks on the way...";
            last SWITCH;
        }
        if ( $speed > 20 ) {
            $color   = "#330000";
            $width   = "10";
            $comment =
                "We politely suggest that you exit your vehicle and get a taxi. Perhaps the conversation will inspire you.";
            last SWITCH;
        }
    }

    $str .=
        '<p align="center"><table width="300" style="margin:auto;" cellpadding=0 cellspacing=0>';
    $str .=
        '<tr><td><table width="100%" border=0 cellpadding=0 cellspacing=0>';
    $str .= '<tr><td align="left"><small><b>NODING SPEED</b></small>';
    $str .=
        '<table width="260" border=0 cellpadding=0 cellspacing=2 style="border: solid 1px black;">';
    $str .= '<tr><td bgcolor="gray" align="left">';
    $str .=
          '<table width="'
        . $width
        . '%" border=0 cellpadding=0 cellspacing=0 bgcolor="'
        . $color . '">';
    $str .=
        '<tr><td><img src="https://s3.amazonaws.com/static.everything2.com/clear.gif" width=1 height=13 alt="" border=0>';
    $str .=
        '</td></tr></table></td></tr></table></td></tr></table></td></tr></table></p>';
    $str .= '<p align="center">' . $comment . '</p>';
    $str .= '<hr width="25%">';

# Projections. Because we're allowing them to clock X nodes, it makes sense to base the
# projections only on the last X nodes rather than basing it on their overall node-fu.
# The formula for average XP per writeup is: ((5 * NoWUs) + (20 * C!s) + upvotes) / NoWUs

# If Writeups are the holdup then:
# No. of days to levelup = writeups required * days per node
# If xp is the holdup (as will usually now be the case) then:
# No. of days to levelup = XP to next level / ((1/days per node) * AVG XP)

    my $lvwu   = getVars( getNode( "level writeups",   "setting" ) );
    my $lvxp   = getVars( getNode( "level experience", "setting" ) );
    my $curlvl = $APP->getLevel($u);
    my $curxp  = $$u{experience};
    my $req_wu = ( $$lvwu{ $curlvl + 1 } ) - $initcnt;
    my $req_xp = ( $$lvxp{ $curlvl + 1 } ) - $curxp;
    my $daystolevel_wu = 0;
    my $daystolevel_xp = 0;
    my $daystolevel    = 0;
    my $total_upvotes  = 0;
    my $total_cools    = 0;

    my $clocked_nodes = $DB->sqlSelectMany(
        'title, node_id, reputation, cooled',
        'node inner join writeup on node_id=writeup_id',
        "author_user=$$u{node_id} and type_nodetype="
            . getId( getNode( 'writeup', 'nodetype' ) ),
        'order by publishtime desc limit 0, ' . $cnt
    );

    while ( my $N = $clocked_nodes->fetchrow_hashref ) {
        my ( $name, $type ) = ( $$N{title} =~ m|(.*) \(([a-z-]+)\)| );

        if (   ( $name eq "E2 Nuke Request" )
            or ( $name eq "Edit these E2 titles" )
            or ( $name eq "Nodeshells marked for destruction" )
            or ( $name eq "Broken Nodes" ) )
        {
            next;
        }

        my ($votescast) =
            $DB->sqlSelect( 'count(*)', 'vote', 'vote_id=' . $$N{node_id} );
        my $upvotes = ( $votescast + $$N{reputation} ) / 2;
        if ( int($upvotes) != $upvotes ) {
            $upvotes = $DB->sqlSelect( 'count(*)', 'vote',
                'vote_id=' . $$N{node_id} . ' and weight=1' );
        }
        $total_upvotes += $upvotes;
        $total_cools   += $$N{cooled};
    }

    my $AVG = ( ( $cnt * 5 ) + ( $total_cools * 20 ) + $total_upvotes ) / $cnt;
    my $nodes_needed = 0;

    #debug
    #$str.= "reqwu: $req_wu, reqxp: $req_xp, lvwu: ".$$lvwu{$curlvl+1}.", initcnt: $initcnt, cnt: $cnt";

    if ( $req_wu > 0 ) {
        $daystolevel_wu = $req_wu * $speed;
        $nodes_needed   = $req_wu;
    } else {
        $req_wu = 0;
    }
    if ( $req_xp > 0 ) {
        $daystolevel_xp = $req_xp / ( ( 1 / $speed ) * $AVG );
        my $temp = $req_xp / $AVG;
        if ( $temp > $nodes_needed ) { $nodes_needed = $temp; }
    } else {
        $req_xp = 0;
    }
    if ( $daystolevel_wu > $daystolevel_xp ) {
        $daystolevel = $daystolevel_wu;
    } else {
        $daystolevel = $daystolevel_xp;
    }

    $str .= "<p><big><strong>Level-up Projections</strong></big></p>";
    $str .=
          "<p>$$u{title} needs <b>$req_wu</b> nodes and <b>$req_xp</b> experience to reach Level "
        . ( $curlvl + 1 )
        . ". Based on a noding speed of <b>"
        . sprintf( "%.2f", $speed )
        . "</b> days per node, ";
    $str .=
          "and an average XP per node of <b>"
        . sprintf( "%.2f", $AVG )
        . "</b> (clocked over the last $cnt nodes), "
        if ( $req_xp > 0 );
    $str .=
          "this will take <b>"
        . sprintf( "%.0f", $nodes_needed )
        . "</b> nodes, written over a period of <b>"
        . sprintf( "%.0f", $daystolevel )
        . "</b> days.</p>";

    $text .= $str;
    return $text;
}

sub the_everything2_voting_experience_system
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    $text .= '<style type="text/css">
.mytable th, .mytable td
{
border: 1px solid silver;
padding: 3px;
}
</style>

<h2>An [Everything2 Help] Document</h2>
<p><br />
<h1>Why it\'s important to read this before you begin writing</h1>
<p>
Everything2 may be unlike anything you have met before. Writers are rewarded for their writing, and gain certain privileges as they gain in experience.
</p><br /><hr width=250><br /><p><p>
<p align=center><big><big>
XP is an [imaginary] number granted to you by an<br>
[anonymous] stranger. Treat it as such.
</big></big></p>

<h3>Votes</strong></h3>
<p>
You begin as a Level 0 user. Level 1 users and up can vote on others\' writeups. Once you have voted you will see the voting pattern of that writeup.</p>
<p>
Use these votes wisely! The reputation of a writeup doesn\'t mean it will be deleted, nor does it mean it will <em>not</em> be deleted, but it acts as one way to qualify written work and to help editors find what can often be a weak writeup. If one of your writeups is deleted, you will lose the <strong>five</strong> [XP] you gained when posting it.</p>
<p>
Try to vote according to the standard of writing, not because you agree or disagree with what someone has written.
<p>
Voting and deletion are two ways we try to keep quality [writeup|writeups] coming in - a hastily/poorly written writeup will often gain a negative reputation.  Conversely, if your writeups are voted up by your fellow users, you will gain XP. Details are below.</p>

<p>
Note: not all powers are gained instantly upon reaching a new level: votes and C!s refresh at midnight server time.</p>

<h3>C!s</h3>
<p>
One important power is the ability to grant a "C!" (also known as "C!ing" or "chinging"). Beginning at 4th level, users will get the ability to C! an <em>individual</em> writeup by clicking the [C!] located next to the voting buttons. This will give the author of the writeup <b>twenty</b> XP, and kick the writeup to the front page and the [Cool Archive] for all to see.</p>

<p><strong>Use these chings wisely!</strong> Just because you have chings doesn\'t mean you should use them with careless abandon. Most users view a writeup\'s chings as an endorsement of <em>quality</em> regardless of the impulsive reason you may have chosen to bestow that "Attaboy". <em>Do you really want your name to be associated with something that we might consider to be stupid ten minutes/days/months from now?</em> Think twice before you click on that C!; chings spent in haste can be regretted in leisure.</p>

<p>
A writeup can be C!d <em>any number of times,</em> but only <strong>once</strong> by any given user.</p>

<h3>XP</h3>

<p>
Each of your writeups earns you 5 [XP] in addition to all the XP you get when people vote it up or cool it. If created using the guidelines detailed in [The perfect node], they will pay off many times over in XP.</p>

<h3>The voting/level system:</h3>

<p>(Note: You must meet <em>both</em> requirements to reach a level, and you lose the level if you drop below either requirement).</p>

<p><small>Your user level is in bold.</small></p>

<table>
';

    my $str        = '';
    my $fstLvl     = $query->param('fstlevel') || 0;
    my $sndLvl     = $query->param('sndlevel') || 12;

    if ( ( $sndLvl - $fstLvl ) > 99 )
    {

        my $warnStr =
'<p><b>!! This tool cannot display more than 100 levels at a time. Please choose fewer levels!</b></p>';

        $warnStr .=
              htmlcode('openform')
            . '<p>Show me all levels from Level '
            . $query->textfield( 'fstlevel', '0', '', 20 )
            . ' to Level '
            . $query->textfield( 'sndlevel', '12', '', 20 )
            . $query->submit( 'show', 'Show Levels!' )
            . $query->end_form()
            . '</p>';

        $text .= $warnStr;
        $text .= '</table>

<h3>Powers:</h3>
<ul>
<li>Level 0 &#8212; Joining Everything2 gives you the ability to [E2 Quick Start|contribute writeups], communicate with other members via the [Chatterbox] and message system, customise your view of the site in [User Settings], etc.</li>
<li>Level 1 &#8212; Can [voting|vote] on E2 writeups by other users. Can give [Star|Stars] to other users at the [E2 Gift Shop]. Can display a small (uncopyrighted) image in your home node (Nope, no [porn] allowed!).</li>
<li>Level 2 &#8212; Can [E2 Gift Shop|buy additional votes] at the [E2 Gift Shop]; can [create category|create categories].</li>
<li>Level 3 &#8212; Can [Everything Poll Creator|create polls]; can post a bounty on [Everything\'s Most Wanted].</li>
<li>Level 4 &#8212; [C!] power!</li>
<li>Level 5 &#8212; Can display a larger homenode image (up to 400&times;800), ability to [create room]s in the [Chatterbox]</li>
<li>Level 6 &#8212; Can reset the chatterbox topic by buying a token at the [E2 Gift Shop].</li>
<li>Level 7 &#8212; Can buy [Easter Egg|easter eggs] at the [E2 Gift Shop], and give them to other users.</li>
<li>Level 8 &#8212; Can [Create A Registry|create registries].</li>
<li>Level 9 &#8212; Can give votes to other users at the [E2 Gift Shop].</li>
<li>Level 10 &#8212; Can [Cloak] oneself in the [Other Users] nodelet. </li>
<li>Level 11 &#8212; Can [Sanctify] other users with GP.</li>
<li>Level 12 &#8212; Can purchase up to one extra C! per day at the [E2 Gift Shop]</li>
<li>Level 15 &#8212; [Fireball]! Can "fireball" other users in the chatterbox using the [/fireball] command.</li>
</ul>
<br>

<h3>You can [gain] or [lose] [XP] in the following ways <em>only</em>:</h3>
<ul>
<li>Each writeup you turn in gives you five [XP]. If it\'s later deleted, you lose that five XP.</li>
<li>+20 XP each time one of your writeups is [C!]\'d ([Cool Archive|Chinged] by another user and sent to the [Cool Archive])</li>
<li>+1 XP every time another user upvotes one of your [writeup|writeups].</li>
</ul>

<!-- Added by rootbeer277 -->
<p><strong>Please note</strong> that under this system, the XP requirement is entirely out of proportion to the writeup requirement.  There is no correlation between number of writeups and the amount of XP one could reasonably be expected to have given that number of writeups.  The writeup requirement exists solely as a safety net against unusual situations rather than a level guideline, and XP is the key value for advancement.</p>
<!-- End rootbeer277\'s addendum -->

<p>



<strong>Note:</strong> If a writeup you\'ve submitted has accrued a positive reputation and it is deleted, you <i><b>will not</i></b> "lose" any [XP] you\'d already gained for the + votes. You will only lose the 5 XP you got when you initially posted the writeup.</p>
<p>
Gaining and losing XP for adding and deleting also applies to "housekeeping" write-ups like [E2 Nuke Request|Writeup Deletion Request] and [Edit These E2 Titles|Node Title Edit]. It can be disconcerting to gain and lose XP from these, but that\'s life.</p>

<h3>You can [gain] or [lose] [GP] in the following ways, and possibly others:</h3>
<ul>
<li>Each time you cast a vote you have a 1 in 3 chance of gaining 1 GP.</li>
<li>+10 GP every time you are [bless|blessed] by an administrator.</li>
<li>+10 GP every time you are [sanctify|sanctified] by another user.</li>
<li>+5 GP every time you are [/fireball|fireballed] by another user in the chatterbox.</li>
<li>+3 GP every time you are [easter egg|egged] by another user in the chatterbox.</li>
<li>variable GP rewards for participating in [Everything Quest|Quests and contests].
<li>GP can be spent at the [E2 Gift Shop] and similar nodes.</li>
</ul>

<p align=center><br><em>[The Power Structure of Everything2|The administration] does not take the voting and experience point system too terribly seriously.</p>
<p align=center><u>Woe to those who do.</u></em></p>
<p align=center><br><br>
</p><br><hr width=250><br></p><p>


<p align=center>
If this is not clear, ask questions in the [Chatterbox] or approach the [E2 Staff]
</p><br>
<p align="center"><big><em>Back to</em><br><strong>[Everything2 Help]</strong></big></p><br />



<p align=right><small>
If you believe that this document needs updating or correcting, /msg any member of [E2Docs]<br>
Last updated on October 9, 2012 by [wertperch] <!-- Added header and footer, tidied up some language --><br>
</small>
</p>';

        return $text;
    }

    $str .=
'<p><table class=\'mytable\'><tr><th>Level</th><th>Level Title</th><th>XP Req</th><th>Writeups Req</th><th>Votes per Day</th><th>[C!]s per Day</th></tr>';

    my $EXP = getVars( getNode( 'level experience', 'setting' ) );
    my $WRP = getVars( getNode( 'level writeups',   'setting' ) );
    my $VTS = getVars( getNode( 'level votes',      'setting' ) );
    my $C   = getVars( getNode( 'level cools',      'setting' ) );
    my $TTL = getVars( getNode( 'level titles',     'setting' ) );

    my $exp = 0;
    my $wrp = 0;

    my $vts = 0;
    my $c   = 0;
    my $ttl = 0;

    my $userLevel = $APP->getLevel($USER);

    for ( my $i = $fstLvl ; $i <= $sndLvl ; $i++ )
    {

        if ( $i < -3 )
        {

            $exp = 1000000 * $i;
            $ttl = "Archdemon";
            $vts = 10000;
            $c   = 1000;
            $wrp = 0;

            $str .=
                  "<tr "
                . ( $i == $userLevel ? "style='font-weight:bold'" : "" )
                . "><TD>$i</TD><TD>$ttl</TD><TD>$exp</TD><TD>$wrp</TD><TD>$vts</TD><TD>$c</TD></tr>";

        }
        elsif ( $i == -3 )
        {

            $exp = 1000000 * $i;
            $ttl = "Demon";
            $vts = 1000;
            $c   = 100;
            $wrp = 0;

            $str .=
                  "<tr "
                . ( $i == $userLevel ? "style='font-weight:bold'" : "" )
                . "><TD>$i</TD><TD>$ttl</TD><TD>$exp</TD><TD>$wrp</TD><TD>$vts</TD><TD>$c</TD></tr>";

        }
        elsif ( $i == -2 )
        {

            $exp = 1000000 * $i;
            $ttl = "Master Arcanist";
            $vts = 500;
            $c   = 50;
            $wrp = 0;

            $str .=
                  "<tr "
                . ( $i == $userLevel ? "style='font-weight:bold'" : "" )
                . "><TD>$i</TD><TD>$ttl</TD><TD>$exp</TD><TD>$wrp</TD><TD>$vts</TD><TD>$c</TD></tr>";

        }
        elsif ( $i == -1 )
        {

            $exp = 1000000 * $i;
            $ttl = "Arcanist";
            $vts = "NONE";
            $c   = "NONE";
            $wrp = 0;

            $str .=
                  "<tr "
                . ( $i == $userLevel ? "style='font-weight:bold'" : "" )
                . "><TD>$i</TD><TD>$ttl</TD><TD>$exp</TD><TD>$wrp</TD><TD>$vts</TD><TD>$c</TD></tr>";

        }
        elsif ( $i < 100 )
        {

            $str .=
                  "<tr "
                . ( $i == $userLevel ? "style='font-weight:bold'" : "" )
                . "><TD>$i</TD><TD>$$TTL{$i}</TD><TD>$$EXP{$i}</TD><TD>$$WRP{$i}</TD><TD>$$VTS{$i}</TD><TD>$$C{$i}</TD></tr>";

        }
        else
        {

            $exp = $i * 2500 - 30000;
            $wrp = $i * 5;

            $str .=
                  "<tr "
                . ( $i == $userLevel ? "style='font-weight:bold'" : "" )
                . "><TD>$i</TD><TD>Transcendent</TD><TD>$exp</TD><TD>$wrp</TD><TD>50</TD><TD>$$C{100}</TD></tr>";
        }

    }

    $str .=
          htmlcode('openform')
        . '<p>Show me all levels from Level '
        . $query->textfield( 'fstlevel', '0', '', 20 )
        . ' to Level '
        . $query->textfield( 'sndlevel', '12', '', 20 )
        . $query->submit( 'show', 'Show Levels!' )
        . $query->end_form()
        . '</p>';

    $text .= $str;
    $text .= '</table>

<h3>Powers:</h3>
<ul>
<li>Level 0 &#8212; Joining Everything2 gives you the ability to [E2 Quick Start|contribute writeups], communicate with other members via the [Chatterbox] and message system, customise your view of the site in [User Settings], etc.</li>
<li>Level 1 &#8212; Can [voting|vote] on E2 writeups by other users. Can give [Star|Stars] to other users at the [E2 Gift Shop]. Can display a small (uncopyrighted) image in your home node (Nope, no [porn] allowed!).</li>
<li>Level 2 &#8212; Can [E2 Gift Shop|buy additional votes] at the [E2 Gift Shop]; can [create category|create categories].</li>
<li>Level 3 &#8212; Can [Everything Poll Creator|create polls]; can post a bounty on [Everything\'s Most Wanted].</li>
<li>Level 4 &#8212; [C!] power!</li>
<li>Level 5 &#8212; Can display a larger homenode image (up to 400&times;800), ability to [create room]s in the [Chatterbox]</li>
<li>Level 6 &#8212; Can reset the chatterbox topic by buying a token at the [E2 Gift Shop].</li>
<li>Level 7 &#8212; Can buy [Easter Egg|easter eggs] at the [E2 Gift Shop], and give them to other users.</li>
<li>Level 8 &#8212; Can [Create A Registry|create registries].</li>
<li>Level 9 &#8212; Can give votes to other users at the [E2 Gift Shop].</li>
<li>Level 10 &#8212; Can [Cloak] oneself in the [Other Users] nodelet. </li>
<li>Level 11 &#8212; Can [Sanctify] other users with GP.</li>
<li>Level 12 &#8212; Can purchase up to one extra C! per day at the [E2 Gift Shop]</li>
<li>Level 15 &#8212; [Fireball]! Can "fireball" other users in the chatterbox using the [/fireball] command.</li>
</ul>
<br>

<h3>You can [gain] or [lose] [XP] in the following ways <em>only</em>:</h3>
<ul>
<li>Each writeup you turn in gives you five [XP]. If it\'s later deleted, you lose that five XP.</li>
<li>+20 XP each time one of your writeups is [C!]\'d ([Cool Archive|Chinged] by another user and sent to the [Cool Archive])</li>
<li>+1 XP every time another user upvotes one of your [writeup|writeups].</li>
</ul>

<p><strong>Please note</strong> that under this system, the XP requirement is entirely out of proportion to the writeup requirement.  There is no correlation between number of writeups and the amount of XP one could reasonably be expected to have given that number of writeups.  The writeup requirement exists solely as a safety net against unusual situations rather than a level guideline, and XP is the key value for advancement.</p>

<p>



<strong>Note:</strong> If a writeup you\'ve submitted has accrued a positive reputation and it is deleted, you <i><b>will not</i></b> "lose" any [XP] you\'d already gained for the + votes. You will only lose the 5 XP you got when you initially posted the writeup.</p>
<p>
Gaining and losing XP for adding and deleting also applies to "housekeeping" write-ups like [E2 Nuke Request|Writeup Deletion Request] and [Edit These E2 Titles|Node Title Edit]. It can be disconcerting to gain and lose XP from these, but that\'s life.</p>

<h3>You can [gain] or [lose] [GP] in the following ways, and possibly others:</h3>
<ul>
<li>Each time you cast a vote you have a 1 in 3 chance of gaining 1 GP.</li>
<li>+10 GP every time you are [bless|blessed] by an administrator.</li>
<li>+10 GP every time you are [sanctify|sanctified] by another user.</li>
<li>+5 GP every time you are [/fireball|fireballed] by another user in the chatterbox.</li>
<li>+3 GP every time you are [easter egg|egged] by another user in the chatterbox.</li>
<li>variable GP rewards for participating in [Everything Quest|Quests and contests].
<li>GP can be spent at the [E2 Gift Shop] and similar nodes.</li>
</ul>

<p align=center><br><em>[The Power Structure of Everything2|The administration] does not take the voting and experience point system too terribly seriously.</p>
<p align=center><u>Woe to those who do.</u></em></p>
<p align=center><br><br>
</p><br><hr width=250><br></p><p>


<p align=center>
If this is not clear, ask questions in the [Chatterbox] or approach the [E2 Staff]
</p><br>
<p align="center"><big><em>Back to</em><br><strong>[Everything2 Help]</strong></big></p><br />



<p align=right><small>
If you believe that this document needs updating or correcting, /msg any member of [E2Docs]<br>
Last updated on October 9, 2012 by [wertperch] <!-- Added header and footer, tidied up some language --><br>
</small>
</p>';

    return $text;
}

sub xp_superbless
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    return $text unless $APP->isAdmin($USER);

    my $bonesrant =
'<P>This is an archived version of the old [Superbless] which used to give XP instead of GP. All blessings should be given in GP nowadays. There is no reason why administrators should fiddle with user XP except for extraordinary circumstances. All usage of this node is logged.</P><P>-[The Power Structure of Everything2|the management]</P><p>Please contact [Tem42] if a user wants XP reset to zero.<br></p>';

    $text .= $bonesrant;

    # REINITIALIZE for second code block
    return $text unless $APP->isAdmin($USER);

    my @params = $query->param;
    my $str    = '';
    my @users  = ();
    my @xp     = ();
    foreach (@params)
    {
        if (/^multiblessUser(\d+)$/)
        {
            $users[$1] = $query->param($_);
        }
        if (/^multiblessXP(\d+)$/)
        {
            $xp[$1] = $query->param($_);
        }
    }

    my $curXP = undef;
    for ( my $count = 0 ; $count < @users ; $count++ )
    {
        next unless $users[$count] and $xp[$count];

        my ($U) = getNode( $users[$count], 'user' );
        if ( not $U )
        {
            $str .= "couldn't find user $users[$count]<br />";
            next;
        }

        $curXP = $xp[$count];

        unless ( $curXP =~ /^\-?\d+$/ )
        {
            $str .= "$curXP is not a valid XP value for user $users[$count]<br>";
            next;
        }

        my $signum = ( $curXP > 0 ) ? 1 : ( ( $curXP < 0 ) ? -1 : 0 );

        $str .= "user $$U{title} was given $curXP XP";
        $APP->securityLog( $NODE, $USER,
            "$$U{title} was superblessed $curXP XP by $$USER{title}" );
        if ( $signum != 0 )
        {
            $$U{karma} += $signum;
            $APP->adjustExp( $U, $curXP );
            htmlcode( 'achievementsByType', 'karma' );

        }
        else
        {
            $str .= ', so nothing was changed';
        }
        $str .= "<br />\n";
    }
    $text .= $str;

    # REINITIALIZE for third code block
    $text .= htmlcode('openform');
    $text .= '<table border="1">
';

    return $text
        . '<TR><TH>You want to be supercursed? No? Then play elsewhere.</TH></TR></table>'
        . htmlcode('closeform')
        unless $APP->isAdmin($USER);

    my $count = 10;

    $str = '';

    $str .= "<tr><th>Bless user</th><th>with XP</th></tr> ";

    for ( my $i = 0 ; $i < $count ; $i++ )
    {
        $query->param( "multiblessUser$i", '' );
        $query->param( "multiblessXP$i",   '' );
        $str .= "<tr><td>";
        $str .= $query->textfield( "multiblessUser$i", '', 40, 80 );
        $str .= "</td><td>";
        $str .= $query->textfield( "multiblessXP$i", '', 10, 10 );
        $str .= "</td></tr>";
    }

    $text .= $str;
    $text .= '</table>
';
    $text .= htmlcode('closeform');

    return $text;
}

sub news_for_noders__stuff_that_matters_
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '<p>';

    my $news = getNode( "News", "usergroup" );
    $text .= htmlcode( 'weblog', '10', $news->{node_id}, '', '', '1' );
    $text .= q|<br><br><p align="center">[Everything FAQ]<br><br>|;
    return $text;
}

sub message_inbox
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    return "<p>If you had an account, you could get messages.</p>"
        if $APP->isGuest($USER);

    # options
    my $str = "(Also see: [Message Outbox])"
        . htmlcode( 'openform', 'message_inbox_form' )
        . '<input type="hidden" name="op" value="message">'
        . $query->hidden('perpage')
        . $query->hidden( 'sexisgood', '1' )    #so auto-VARS changing works
        . $query->fieldset(
        $query->legend('Options')
            . htmlcode( 'varcheckbox', 'sortmyinbox',
            'Sort messages by usergroup' )
            . '<br>'
            . 'Show only messages from user '
            . $query->textfield( -name => 'fromuser' )
            . ', or do the inverse: '
            . $query->checkbox(
            -name  => 'notuser',
            -label => 'hide from this user'
            )
            . '<br>'
            . 'Show only messages for group '
            . $query->textfield( -name => 'fromgroup' )
            . ', or do the inverse: '
            . $query->checkbox(
            -name  => 'notgroup',
            -label => 'hide to this group'
            )
            . '<br>'
            . 'Show only archived/unarchived messages: '
            . htmlcode( 'varsComboBox',
            'msginboxUnArc,0, 0,all, 1,unarchived, 2,archived' )
        );

    # get parameters for messages to show
    my $filterUser  = $query->param('fromuser');
    my $filterGroup = $query->param('fromgroup');
    my $spyon       = $query->param('spy_user');

    my $isRoot     = $APP->isAdmin($USER);
    my $bots       = undef;
    my $grandtotal = undef;

    $bots = getVars( getNode( 'bot inboxes', 'setting' ) )
        if $isRoot or $spyon;

    # show alternate user account's messages
    my $spystring = '';
    if ($isRoot)
    {

        my @names = sort { lc($a) cmp lc($b) } keys(%$bots);
        unshift @names, $$USER{title};

        $spystring = $query->label( 'Message inbox for: '
                . $query->popup_menu(
                -name   => 'spy_user',
                -values => \@names
                ) );
    }

    my $foruser = 0;
    if ($spyon)
    {
        my $u = getNode( $spyon, 'user' );
        if ($u)
        {
            my $okUg = getNode( $$bots{ $$u{title} }, 'usergroup' );
            $foruser = $u if $okUg and $DB->isApproved( $USER, $okUg );

        }
        elsif ($isRoot)
        {
            $spystring .=
                '<small>"' . $query->escapeHTML($spyon) . '" is not a user</small>';
        }
    }

    $str .= $query->p($spystring) if $spystring;
    $foruser = ( $foruser || $USER )->{node_id};

    # start building SQL WHERE string
    # TODO: look at XML ticker and consider sharing code
    my $sqlWhere = "for_user=$foruser";

    #show archived/unarchived things
    $sqlWhere .= ( '', ' AND archive=0', ' AND archive!=0' )
        [ $$VARS{msginboxUnArc} ];

    my $showFilters =
        ( '', ' unarchived', ' archived' )[ $$VARS{msginboxUnArc} ]
        . ' messages';

    $filterUser  = getNode( $filterUser,  'user' )      if $filterUser;
    $filterGroup = getNode( $filterGroup, 'usergroup' ) if $filterGroup;

    # sort by usergroup?
    my $ugJoin = '';
    if ( $$VARS{sortmyinbox} )
    {
        # get a list of usergroups from which we have messages, with how many
        my $ugType = getType('usergroup');
        my $csr    = $DB->sqlSelectMany(
            'count(*), title',
            "message
            LEFT JOIN node
                ON for_usergroup = node_id
                AND type_nodetype=$$ugType{node_id}",
            $sqlWhere,
            'GROUP BY title
            ORDER BY (title IS NULL)'
        );

        my $totalMess = 0;

        while ( my $group = $csr->fetchrow_hashref() )
        {
            my $num   = $$group{'count(*)'};
            my $title = $$group{title} || 'No group';
            $str .=
                  linkNode( $NODE, "<strong>$title</strong>: ",
                { 'fromgroup' => $$group{title} } )
                . "$num<br>\n";
            $totalMess += $num;
        }

        $str .=
              '('
            . linkNode( $NODE, "$totalMess$showFilters total" )
            . ")<br><br>\n";
        $grandtotal = $totalMess unless $$VARS{msginboxUnArc};

        unless ($filterGroup)
        {
            # default display is messages not for a group:
            $ugJoin = 'LEFT JOIN node ON for_usergroup = node_id';
            $sqlWhere .=
                " AND (for_usergroup=0 OR type_nodetype != $$ugType{node_id})";
            $showFilters .= ' not to any usergroup';
        }
    }

    $grandtotal ||= $DB->sqlSelect( "count(*)", "message", "for_user=$foruser" );

    # from user/to usergroup
    if ($filterUser)
    {
        my ( $n, $not ) =
            $query->param('notuser') ? ( '!', ' not' ) : ( '', '' );
        $sqlWhere .= " AND message.author_user$n=$$filterUser{node_id}";
        $showFilters .= "$not from " . linkNode($filterUser);
    }

    if ($filterGroup)
    {
        my ( $n, $not ) =
            $query->param('notgroup') ? ( '!', ' not' ) : ( '', '' );
        $sqlWhere .= " AND for_usergroup$n=$$filterGroup{node_id}";
        $showFilters .= "$not to usergroup " . linkNode($filterGroup);
    }

    # provoke jump to last page:
    $query->param( 'page', 1000000000 ) unless $query->param('page');

    # get messages
    my ( $csr, $paginationLinks, $totalmsgs, $firstmsg, $lastmsg ) = htmlcode(
        'show paged content',
        'message.*',
        "message $ugJoin",
        "$sqlWhere",,
        'ORDER BY message_id
        LIMIT 100',    # can be overridden by 'perpage' parameter
        0,             # no instructions, so it doesn't 'show' but returns cursor
        noform => 1    # 'go to page' box not wrapped in form
    );

    # display
    my $colHeading = '<tr><th align="left">delete</th><th>send time</th>
    <th colspan="2" align="right">&#91;un&#93;Archive</th></tr>';

    $str .= "$paginationLinks
    <table>
    $colHeading" if $totalmsgs;

    while ( my $MSG = $csr->fetchrow_hashref )
    {
        my $msgtext = $$MSG{msgtext};
        my $from = $$MSG{author_user};
        my $ug   = $$MSG{for_usergroup};

        getRef( $from, $ug );
        $from ||= { title => '&#91;unknown user]' };
        $ug = 0
            if $ug
            && $$ug{type}{title} ne 'usergroup'
            && $$ug{type}{title} ne 'user';

        # don't escape HTML for bots
        unless ( $$bots{ $$from{title} } eq 'Content Editors' )
        {
            $msgtext = $APP->escapeAngleBrackets($msgtext);
            $msgtext = parseLinks( $msgtext, 0, 1 );
            $msgtext =~ s/\[/&#91;/g;    # no spare [s for page parseLinks
        }
        $msgtext =~ s/\s+\\n\s+/<br>/g;    # replace literal '\n' with HTML breaks

        # delete box
        $str .=
              qq'<tr class="privmsg"><td>'
            . $query->checkbox(
            -name   => 'deletemsg_' . $$MSG{message_id},
            -value  => 'yup',
            -valign => 'top',
            -label  => '',
            -class  => 'delete'
            );

        # reply links
        my $alink = '';

        my $responses = [ encodeHTML( $$from{title} ) ];
        push @$responses, $$ug{title} if $ug;

        foreach (@$responses)
        {
            my $respondto = $_;

            # make names safe and find user if it's from Eddie.
            # (To find more users, patch the messages, not this)

            $msgtext =~ /\[([^\[\]]*)\[user]/ and ( $respondto = $1 )
                if $respondto eq 'Cool Man Eddie';    # (sic)
            next unless $respondto;
            $respondto =~ s/'/\\'/g;
            $respondto =~ s/"/\\"/g;
            $respondto =~ s/ /_/g;

            $str .=
                  '('
                . $query->a(
                {
                    class => 'action reply',
                    href => "javascript:e2.startText('zetextbox','/msg $respondto ')"
                },
                "r$alink"
                ) . ')';
            $alink = 'a';
        }

        # time sent
        my $t = $$MSG{tstamp};
        $str .=
              '</td><td><small>&nbsp;'
            . substr( $t, 0, 4 ) . '.'
            . substr( $t, 5, 2 ) . '.'
            . substr( $t, 8, 2 )
            . '&nbsp;at&nbsp;'
            . substr( $t, 11, 2 ) . ':'
            . substr( $t, 14, 2 )
            . '</small></td><td>';

        # message
        $str .= '(' . linkNode($ug) . ') ' if $ug;
        $str .= '<em>' . linkNode($from) . " says</em> $msgtext</td>";

        # archive box
        $str .=
              '<td><tt>'
            . ( $$MSG{archive} ? 'A' : '&nbsp;' )
            . '</tt>'
            . $query->checkbox(
            -name  => ( $$MSG{archive} ? 'un' : '' ) . "archive_$$MSG{message_id}",
            -value => 'yup',
            -label => '',
            -class => 'archive'
            ) . "</td></tr>\n";
    }

    # summary report
    unless ( $totalmsgs
        || $filterUser
        || $filterGroup
        || $$VARS{msginboxUnArc} == 2    # archived only
        || $foruser != $$USER{node_id} )
    {
        #no messages showing
        $showFilters =
              "<em>You may feel lonely.</em>
        <small>(But you do have $grandtotal messages all together)</small>"
            if $grandtotal;
    }
    else
    {
        $str .= $colHeading if $lastmsg - $firstmsg > 10;
        $str .= '</table>' if $totalmsgs;

        $totalmsgs ||= 'no';
        $showFilters =~ s/messages/message/
            if $totalmsgs ne 'no' && $totalmsgs == 1;
        $showFilters =
              ( $foruser == $$USER{node_id} ? 'You have ' : linkNode($foruser) . ' has ' )
            . $totalmsgs
            . $showFilters;
        $showFilters .= ". ($grandtotal all together)"
            if ( $totalmsgs eq 'no' && $grandtotal != 0 )
            || $totalmsgs != $grandtotal;
    }

    $str .= $query->p($showFilters);

    # form manipulation buttons
    $str .=
          $paginationLinks
        . $query->p(
        $query->reset('Clear All')
            . q! <input type="button" value="Clear Reply"
        onclick="$('#zetextbox').val('');">
    <input type="button" value="Delete All"
        onclick="$('.delete').each(function(){this.checked=true;});">
    <input type="button" value="Archive All"
        onclick="$('.archive&#91;name^=archive]').each(function(){this.checked=true;});">
    <input type="button" value="Unarchive All"
        onclick="$('.archive&#91;name^=unarchive]').each(function(){this.checked=true;});">!
        );

    # message and box
    if ( $query->param('sentmessage') )
    {
        $str .= '<p><i>' . $query->param('sentmessage') . '</i></p>';
    }

    $str .=
        $query->div( { id => 'MI_textbox' },
        $query->textarea(
            -name  => 'message',
            -value => '',
            -force => 1,
            -rows  => 1,
            -cols  => 35,
            -id    => 'zetextbox',
            -class => 'expandable'
        ) )
        unless $$VARS{'borged'};

    $text .=
          $str . ' '
        . $query->submit( 'message send', 'submit' )
        . $query->end_form();

    return $text;
}

sub everything_publication_directory
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    return "go away" unless $APP->inUsergroup( $USER, 'thepub' );

    $text .= '<p>Discussions on E2 Publications, most recently commented listed first.</p>

<style type="text/css">
<!--
th {
    text-align: left;
}
-->
</style>

<p>
The "restricted" column shows who may view/add to a discussion.
</p>

<!-- [%
# return \'<p>"Restricted" discussions are limited to "gods" only. This superdoc shows them (and the "restricted" column, and this paragraph too) only for "gods". </p>\' if ( isGod( $USER ) );
\'\';
%] -->

<p>
<table>
<tr bgcolor="#dddddd">
<th class="oddrow" width="200" colspan="2">title</th>
<th class="oddrow" width="80">restricted</th>
<th class="oddrow" width="80">author</th>
<th class="oddrow" width="100">created</th>
<th class="oddrow" width="100">last updated</td>
<!--th width="100">type</th-->
</tr>
';

    my @types = qw( debate );
    foreach (@types)
    {
        $_ = getId( getType($_) );
    }

    #gets a node given the ID
    #this caches nodes between hits, so it doesn't hurt to get 1 group a zillion times
    #note: this may be completely pointless if E2 caches things anyway, but I don't have much faith in that :-|
    #returns undef if unable to get a node
    #created: 2001.11.27.n2; updated: 2001.11.27.n2
    #author: N-Wing
    my %ids = ();
    local *getNodeFromID = sub {
        my $nid = $_[0];
        return unless ( defined $nid ) && ( $nid =~ /^\d+$/ );

        #already known, return it
        return $ids{$nid} if exists $ids{$nid};

        #unknown, find that
        my $N = getNodeById($nid);
        return unless defined $N;
        return $ids{$nid} = $N;
    };

    local *in_an_array = sub {
        my $needle   = shift;
        my @haystack = @_;

        for (@haystack)
        {
            return 1 if $_ eq $needle;
        }
        return 0;
    };

    my $csr = $DB->sqlSelectMany( "root_debatecomment", "debatecomment",
        "restricted=114", "ORDER BY debatecomment_id DESC" );
    my @nodes = ();
    while ( my $temprow = $csr->fetchrow_hashref )
    {
        my $N = getNodeById( $temprow->{root_debatecomment} );
        push @nodes, $N if ( $N && !in_an_array( $N, @nodes ) );
    }

    my $str           = '';
    my $restrictGroup = undef;
    foreach my $n (@nodes)
    {
        $n = getNodeById( $$n{'node_id'} );
        my ($user) = getNodeById( $$n{author_user} );
        my $created = $$n{createtime};

        # Maybe we should have some sympathy for brits, who write dates
        # backwards? Nahh...
        $created =~ s/^([0-9]+)-([0-9]+)-([0-9]+).*$/$2\/$3\/$1/;
        $created =~ s/(^|\/)0/$1/;

        my $latest = getNodeById(
            $DB->sqlSelect(
                "MAX(debatecomment_id)", "debatecomment",
                "root_debatecomment=$$n{node_id}"
            )
        );
        my $latesttime = $latest->{createtime};
        $latesttime ||= "<em>(none)</em>";
        $latesttime =~ s/^([0-9]+)-([0-9]+)-([0-9]+).*$/$2\/$3\/$1/;
        $latesttime =~ s/(^|\/)0/$1/;
        $latesttime ||= "<em>(none)</em>";

        $restrictGroup = $$n{restricted} || 923653;    #ugly backwards-
        $restrictGroup = 114 if $restrictGroup == 1;   #compatiblity hack
        $restrictGroup = getNodeFromID($restrictGroup);

        next unless $DB->isApproved( $USER, $restrictGroup );

        $str .=
              '<tr><td>'
            . linkNode( $n, 0, { lastnode_id => 0 } )
            . '</td><td><small>('
            . linkNode( $n, 'compact',
            { lastnode_id => 0, displaytype => 'compact' } )
            . ')</small></td><td><small>'
            . linkNode( $restrictGroup, 0, { lastnode_id => 0 } )
            . '</small></td><td>'
            . linkNode( $$user{'node_id'}, 0, { lastnode_id => 0 } )
            . '</td><td>'
            . $created
            . '</td>'
            . '<td>'
            . $latesttime
            . '</td>'
            . '</tr>';
    }
    $text .= $str;

    $text .= '</table>

';

    # REINITIALIZE for second code block
    $str = '';

    my $createDebate = 1;

    if ($createDebate)
    {
        $str .= '
<p><b>Create a New Discussion:</b></p>

<form method="post">
<p>
<input type="hidden" name="op" value="new" />
<input type="hidden" name="type" value="debate" />
<input type="hidden" name="displaytype" value="edit" />
<input type="hidden" name="debate_parent_debatecomment" value="0" />
<input type="text" size="50" maxlength="64" name="node" value="" /><br />';
        $str .= '<input type="submit" value="Create Debate" />
</p>
</form>
';
    }

    $text .= $str;
    return $text;
}

sub your_filled_nodeshells
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    return $text if $APP->isGuest($USER);

    my $csr = $DB->sqlSelectMany(
        'title',
        "(Select title, e2node_id,
            (select nodegroup_id from nodegroup where nodegroup_id = e2node_id limit 1) As groupentry
        From e2node Join node On node.node_id = e2node_id
        Where createdby_user = $$USER{node_id}
        Having groupentry > 0)
        AS fillede2nodes
    LEFT JOIN
        (Select parent_e2node
        From node
        Join writeup On node_id = writeup_id
        Where author_user = $$USER{node_id})
        AS writeups
    ON fillede2nodes.e2node_id = writeups.parent_e2node",
        'parent_e2node IS NULL'
    );

    my @nodes = ();
    my $wu    = undef;

    while ( my $row = $csr->fetchrow_hashref )
    {
        push @nodes, $$row{title};
    }

    my $str =
          '<p>(Be sure to check out [Your nodeshells], too.)</p><p><strong>'
        . scalar(@nodes)
        . '</strong> nodeshells created by you which have been filled by someone else:</p>
<ul>
';

    foreach ( sort { lc($a) cmp lc($b) } @nodes )
    {
        $str .= '<li>' . linkNodeTitle($_) . '</li>
';
    }

    $str .= '</ul>';

    $text .= $str;
    return $text;
}

sub random_nodeshells
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    return $text if $APP->isGuest($USER);

    my $maxId    = $DB->sqlSelect( "max(node_id)", "node" );
    my @rand     = ();
    my $numNodes = 1200;

    for ( my $x = 1 ; $x <= $numNodes ; $x++ )
    {
        push @rand, int( rand $maxId );
    }

    my $randStr = join( ', ', @rand );

    my $csr = $DB->sqlSelectMany( 'node_id', 'node',
            'type_nodetype=116 and (select count(*) from nodegroup where nodegroup_id=node.node_id) = 0 and (select count(*) from links where linktype=1150375 and from_node=node.node_id limit 1) = 0 and node_id in ('
            . $randStr
            . ')' );

    my @nodes = ();
    while ( my $row = $csr->fetchrow_hashref )
    {
        push @nodes, $$row{node_id};
    }

    my $str = '
<p><b>How this works:</b></p>

<p>The code picks '
        . $numNodes
        . ' random possible node_ids, then checks if the node_id actually exists, if it is an e2node nodetype, and if it has no writeups and no firmlinks. Interestingly, this usually produces between 30 and 40 nodeshells with pretty good consistency.</p>

<p>[Random nodeshells|Generate a new list]</p>

<p>Here are <strong>'
        . scalar(@nodes)
        . '</strong> random nodeshells:</p>
<ul>
';

    foreach (@nodes)
    {
        $str .= '<li>' . linkNode($_) . '</li>
';
    }

    $str .= '</ul>';

    $text .= $str;
    return $text;
}

sub nodes_of_the_year
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    ####################################################################
    # get all the URL parameters

    my $wuType = abs int( $query->param("wutype") );

    my $count = abs int( $query->param("count") );
    $count = 50 if !$count;

    my $orderby = $query->param('orderby') || 'cooled DESC,reputation DESC';

    # Show last year until Decemberish (11*30.5*24*3600)
    my $year = $query->param('year') || ( localtime( time - 28987200 ) )[5] + 1900;

    my $nextyear = $year + 1;

    ####################################################################
    # Form with list of writeup types and number to show

    my (@WRTYPE) =
        $DB->getNodeWhere( { type_nodetype => getId( getType('writeuptype') ) } );
    my %items = ();
    foreach my $wrtype (@WRTYPE)
    {
        $items{ $wrtype->{node_id} } = $wrtype->{title};
    }

    my @idlist = sort { $items{$a} cmp $items{$b} } keys %items;
    unshift @idlist, 0;
    $items{0} = 'All';

    my $choices = [
        'cooled DESC,node.reputation DESC',
        'node.reputation DESC', 'publishtime DESC', 'publishtime ASC'
    ];

    my $labels = {
        'cooled DESC,node.reputation DESC' => 'C!, then reputation',
        'node.reputation DESC'             => 'Reputation',
        'publishtime DESC'                 => 'Date, most recent first',
        'publishtime ASC'                  => 'Date, most recent last'
    };

    my $str =
          htmlcode('openform')
        . qq'<fieldset><legend>Choose...</legend>
    <strong>Year:</strong>'
        . $query->textfield( 'year', '2014', 4, 4 ) . '
    <label> &nbsp; <strong>Select Writeup Type:</strong>'
        . $query->popup_menu( 'wutype', \@idlist, 0, \%items )
        . '</label> &nbsp;
    <label> &nbsp; <strong>Number of writeups to display:</strong>'
        . $query->popup_menu( 'count', [ 0, 15, 25, 50, 75, 100, 150, 200, 250, 500 ],
        $count )
        . '</label>
    <br>
    <label><strong>Order By:</strong>'
        . $query->popup_menu( 'orderby', $choices, 'cooled DESC,reputation DESC',
        $labels )
        . '</label> &nbsp; '
        . $query->submit('Get Writeups')
        . '</fieldset></form>';

    ####################################################################
    # get writeups
    #
    my $where = '';

    $where = "wrtype_writeuptype=$wuType
    and " if $wuType;

    $where .=
          "publishtime >= '"
        . $year
        . "-01-01 00:00:00' and publishtime < '"
        . $nextyear
        . "-01-01 00:00:00'";

    my ( $list, $navigation ) = htmlcode(
        'show paged content',
        'writeup_id, parent_e2node, publishtime,
    node.author_user,
    type.title AS type_title,
    cooled, node.reputation',
        'writeup
    JOIN node ON writeup_id = node.node_id
    JOIN node type ON type.node_id = writeup.wrtype_writeuptype',
        $where,
        "ORDER BY $orderby LIMIT $count",
        '<tr class="&oddrow">"<td>", parenttitle, type,
        "</td><td>", author, "</td><td align=\'right\'><small>", listdate, "</small></td>
        <td><small>", cooled, "/", reputation, "</small></td>"'
    );

    ####################################################################
    # display
    #

    $str .= $navigation if $count > 25;

    $str .=
          '<table style="margin-left: auto; margin-right: auto;">
    <tr>
    <th>Title</th>
    <th>Author</th>
    <th>Published</th>
    <th>C/rep</th>
    </tr>'
        . $list
        . '</table>';

    $text .= $str . $navigation;
    return $text;
}

sub permission_denied
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    return q|<p>You don't have access to that node.</p>|;
}

sub super_mailbox
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    # A simple tool made by Lord Brawl and improvified by an anonymous coder

    my $options = getVars( getNode( 'bot inboxes', 'setting' ) );
    my @names = sort { lc($a) cmp lc($b) } keys(%$options);
    my $str = '';
    my @ok  = ();
    my %groups = ();

    my $inbox = getNode( 'Message Inbox', 'Superdoc' );
    my $isEd  = $APP->isEditor($USER);

    foreach (@names)
    {
        my $ugName = $$options{$_};
        my $ug = $groups{$ugName} ||= getNode( $ugName, 'usergroup' );
        next unless $isEd || $DB->isApproved( $USER, $ug );
        my $botuser = getNode($_,'user');
        next unless $botuser;
        push( @ok, linkNode( $botuser ) );
        my $n = getId( $botuser );

        my $x = $DB->sqlSelect( 'COUNT(*)', 'message', "for_user=$n" );
        $str .= '<li>'
            . $_ . ' has '
            . linkNode( $inbox, "$x message(s)", { spy_user => $_ } )
            . '</li>'
            if $x;
    }

    return
        "Restricted area. You are not allowed in here. Leave now or suffer the consequences."
        unless @ok;

    my $and = '';
    $and = ' and ' . pop(@ok) if scalar @ok > 1;
    my $list = join( ', ', @ok ) . $and;
    $str ||= '<li>No messages</li>';

    $text .= '<h3>The \'bot super mailbox</h3>';
    $text .=
        '<p>One stop check for msgs to \'bot and support mailboxes. You can see messages for: '
        . $list
        . '</p>';
    $text .= '<ul>' . $str . '</ul>';

    return $text;
}

sub nothing_found
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    return '<p>Oh good, there\'s nothing there!</p> <p>(It looks like you nuked it.)</p>'
        if $query->param('op') eq 'nuke'
            && $query->param('node_id')
            && $query->param('node_id') !~ /\D/;

    my $nt = $query->param('node');
    return '<p>Hmm...  that\'s odd.  There\'s nothing there!</p>' unless $nt;

    $nt = $query->escapeHTML($nt);

    my $str = '';

    if ( $nt =~ /^https?:\/\// )
    {
        $nt =~ s/'/&#39;/g;
        $nt =~ s/,/&#44;/g;
        my $s = htmlcode( 'externalLinkDisplay', $nt );
        if ( length($s) )
        {
            $str = '<p>(this appears to be an external link: ' . $s . ')</p>';
        }
    }

    if ( $APP->isAdmin($USER) && $query->param('type') eq 'writeup' && $query->param('author') )
    {
        unless ( $query->param('tinopener') )
        {
            $str =
                'You could <a href="'
                . $query->url( -absolute => 1, -rewrite => 1 )
                . '?tinopener=1">use the godly tin-opener</a> to show a censored version of any
                draft that may be here, but only do that if you really need to.';
        }
        else
        {
            # ecore redirection means only the acctlock message currently shows:
            my $author = getNode( scalar( $query->param('author') ), 'user' );
            unless ($author)
            {
                $str = 'User does not exist.';
            }
            elsif ( $$author{acctlock} )
            {
                $str =
                    linkNode($author)
                    . "'s account is locked. The tin-opener doesn't work on locked users.";
            }
            else
            {
                $str = 'No draft here.';
            }
        }
        $str = "<p><small>($str)</small></p>";
    }

    $text .= qq|<p>Sorry, but nothing matching "$nt" was found.$str|;
    $text .= htmlcode('e2createnewnode');

    return $text;
}

sub findings_
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    my @start     = Time::HiRes::gettimeofday;
    my $timeStr   = undef;
    my $timeCount = 1;

    my $str   = '';
    my $title = $query->param('node');
    my $lnode = $query->param('lastnode_id');
    $lnode ||= '0';

    return htmlcode( 'randomnode', 'Psst! Over here!' ) unless $title;
    $str .= 'Here\'s the stuff we found when you searched for "' . $title . '"';

    $str .= qq'\n\t<ul class="findings">';

    my $isRoot = $APP->isAdmin($USER);
    my $curType = undef;

    my @nodes = ();

    # Likely we are coming from a draft cold and we were short circuited here. Do a new search.
    if ( not exists( $NODE->{group} ) and defined($title) )
    {
        $NODE->{group} = $APP->searchNodeName( $title, ["e2node"], undef, 1 );
    }

    #For some reason, sometimes e2 thinks there is no nodegroup here. Huh? --[Swap]
    if ( defined $$NODE{group} )
    {
        @nodes = @{ $$NODE{group} };
    }

    my @e2node_ids = ();
    foreach my $node (@nodes)
    {
        if ( $node->{type}{title} eq "e2node" )
        {
            push @e2node_ids, $node->{node_id};
        }
    }

    my %fillednode_ids = ();

    #Only make one SQL call to find the non-nodeshells.
    if (@e2node_ids)
    {
        my $sql =
              "SELECT DISTINCT nodegroup_id
             FROM nodegroup
             WHERE nodegroup_id IN ("
            . join( ", ", @e2node_ids ) . ")";

        @fillednode_ids{ @{ $DB->{dbh}->selectcol_arrayref($sql) } } = ();
    }

    foreach my $ND ( @{ $$NODE{group} } )
    {
        #$ND = getNodeById($ND, 'light');
        next unless canReadNode( $USER, $ND );
        $curType = $$ND{type}{title};

        next if $curType eq 'writeup';
        next if $curType eq 'debatecomment';

        next if $curType eq 'draft' && !$APP->canSeeDraft( $USER, $ND, 'find' );
        if ( $curType eq 'debate' && !$isRoot )
        {
            next unless $APP->inUsergroup( $USER, getNodeById( $$ND{restricted} ) );
        }

        my $openli = "<li>";

        # Mark nodeshells with class name
        if ( $curType eq 'e2node' )
        {
            $openli = '<li class="nodeshell">'
                unless exists $fillednode_ids{ $$ND{node_id} };
        }
        if ( $APP->isGuest($USER) )
        {
            $str .= $openli . linkNode( $ND, '', { lastnode_id => 0 } );
        }
        else
        {
            $str .= $openli . linkNode( $ND, '', { lastnode_id => $lnode } );
        }
        if ( $curType ne 'e2node' )
        {
            $str .= " ($curType)";
        }
        $str .= "</li>\n";
    }

    $str .= "</ul>\n";

    # We need to clear out the results of the search because if we are coming here from a draft
    # we need to nix these search results so we can detect it and get new ones

    delete $NODE->{group};

    $text .= $str;
    $text .= htmlcode('e2createnewnode');

    return $text;
}

sub my_recent_writeups
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    return "If you logged in, you would know how many writeups you've published recently."
        if $APP->isGuest($USER);

    my $oneyearago = time() - 31536000;
    $oneyearago = htmlcode( 'DateTimeLocal', $oneyearago );

    my $userID = $$USER{node_id};

    my $numwriteups = htmlcode( 'writeupssincelastyear', "$userID" );

    $text .=
          "Since one year ago, on "
        . $oneyearago . ", "
        . linkNode( $userID, "you" )
        . " have published "
        . $numwriteups
        . " writeups. <br/> <br/>";

    return $text;
}

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

    my $show_ug = int $query->param('show_ug') || 0;

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

sub list_nodes_of_type
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    # list nodes of type
    # lists all available nodetypes, prompts to display nodes of that nodetype
    # only available to members of gods, editors, and edev
    # original version written by chromatic for EDC
    # modified by N-Wing

    my $UID       = $USER->{node_id};
    my $isRoot    = $APP->isAdmin($USER);
    my $isCE      = $APP->isEditor($USER);
    my $isEDev    = $APP->isDeveloper($USER);
    return 'Sorry, cowboy. You must be at least [edev|this tall] to ride the Node Type Lister!'
        unless $isCE || $isEDev;

    my $sth = $DB->{dbh}->prepare(
        'SELECT title, node_id FROM node, nodetype WHERE node_id = nodetype_id ORDER BY title');
    $sth->execute();
    my $opt = '';

    #TODO would be more secure to have list of things allowed, instead of things not allowed

    #reasons for skipping:
    #    user, e2node, writeup - a zillion of them
    #    ditto, plus privacy
    #    restricted_superdoc - admins only
    #    bug - ?
    #    oppressor_superdoc - editors only
    #    debate, debatecomment - like writeups/e2nodes - eventually a zillion of them

    my %skips;
    @skips{qw(user e2node writeup draft)} = ();    #later filter useralias
    delete $skips{'user'}
        if $USER->{node_id} == 9740 || 1306028 || 1390290
        ;    #2005 August new user create bug - N-Wing wants easy way to get these
             #and Two Sheds and Wiccanpiper wanted to list users for other reasons.

    #not sure about collaboration - is that supposed to be a group private thing, or public thing that only certain people can edit?

    if ($isRoot)
    {
        #    @skips{qw()} = ();
    }
    else
    {
        @skips{qw(restricted_superdoc bug)} = ();
        @skips{qw(oppressor_superdoc debate debatecomment)} = () unless $isCE;
    }

    #get node types
    my @choiceNodeTypes = ( 0, '(choose a node type)' );
    my $t;
    my $nid;
    my %validTypeIDs;    #key is valid node_id, value is title
    while ( my $item = $sth->fetchrow_arrayref )
    {
        $nid = $item->[1];

        # the getNode call may slow things down, so I'm commenting it out
        #    next unless canReadNode($USER, getNode($nid));

        $t = $item->[0];

        # the man says you're not worthy to read these
        # or it slows down the server for everything
        # so getcher own installation, buddy!
        next if ( exists $skips{$t} );

        push( @choiceNodeTypes, $nid, $t );
        $validTypeIDs{$nid} = $t;
    }
    $opt .= 'nodetype: '
        . htmlcode( 'varsComboBox', 'ListNodesOfType_Type', 0, @choiceNodeTypes )
        . "<br />\n";

    my $choicelist = [
        '0',        '(no sorting)',
        'idA',      'node_id, ascending (lowest first)',
        'idD',      'node_id, descending (highest first)',
        'nameA',    'title, ascending (ABC)',
        'nameD',    'title, descending (ZYX)',
        'authorA',  'author\'s ID, ascending (lowest ID first)',
        'authorD',  'author\'s ID, descending (highest ID first)',
        'createA',  'create time, ascending (oldest first)',
        'createD',  'create time, descending (newest first)',
    ];
    $opt .= 'sort order: ';
    $opt .= ' <small>1:</small> '
        . htmlcode( 'varsComboBox', 'ListNodesOfType_Sort', 0, @$choicelist );
    $opt .= ' <small>2:</small> '
        . htmlcode( 'varsComboBox', 'ListNodesOfType_Sort2', 0, @$choicelist );
    $opt .= '<br />
';

    $opt
        .= 'only show things ('
        . $query->checkbox( 'filter_user_not', 0, 1, 'not' )
        . ') written by '
        . $query->textfield('filter_user')
        . '<br />
';

    $text .= 'Choose your poison, sir:
<form method="POST">
<input type="hidden" name="node_id" value="' . $NODE->{node_id} . '" />
';
    $text .= $opt;
    $text .= $query->submit( 'fetch', 'Fetch!' ) . '
</form>';

    my $selectionTypeID = $VARS->{ListNodesOfType_Type};
    return $text unless $query->param('fetch');    #check if user hit Fetch button
    return $text unless $selectionTypeID && exists( $validTypeIDs{$selectionTypeID} );
    return $text
        . ' <span style="background-color: yellow;" title="'
        . $selectionTypeID
        . '">!!! Assertion Error !!!</span>'
        unless $selectionTypeID =~ /^[1-9]\d*$/;

    #force a 0 or 1 from a CGI parameter
    local *cgiBool = sub {
        return ( $query->param( $_[0] ) eq '1' ) ? 1 : 0;
    };

    #mapping of unsafe VARS sort data into safe SQL
    my %mapVARStoSQL = (
        '0'       => '',
        'idA'     => 'node_id ASC',
        'idD'     => 'node_id DESC',
        'nameA'   => 'title ASC',
        'nameD'   => 'title DESC',
        'authorA' => 'author_user ASC',
        'authorD' => 'author_user DESC',
        'createA' => 'createtime ASC',
        'createD' => 'createtime DESC',
    );

    #loop so can have secondary (or more!) sorting
    #maybe TODO don't allow stupid combos
    my $sqlSort = '';
    foreach my $varsSortKey ( 'ListNodesOfType_Sort', 'ListNodesOfType_Sort2' )
    {
        last unless exists $VARS->{$varsSortKey};
        $t = $VARS->{$varsSortKey};
        last unless defined $t;
        last unless exists $mapVARStoSQL{$t};
        $sqlSort .= ',' unless length($sqlSort) == 0;
        $sqlSort .= $mapVARStoSQL{$t};
    }

    my $filterUserNot = cgiBool('filter_user_not');
    my $filterUser = ( defined $query->param('filter_user') ) ? $query->param('filter_user') : undef;
    if ( defined $filterUser )
    {
        $filterUser = getNode( $filterUser, 'user' ) || getNode( $filterUser, 'usergroup' ) || undef;
    }
    my $sqlFilterUser   = '';
    my $plainTextFilter = '';
    if ( defined $filterUser )
    {
        $sqlFilterUser = ' AND author_user' . ( $filterUserNot ? '!=' : '=' ) . getId($filterUser);
        $plainTextFilter
            .= ( $filterUserNot ? ' not' : '' )
            . ' created by '
            . linkNode( $filterUser, 0, { lastnode_id => 0 } );
    }

    my $total;
    $sth = $DB->{dbh}
        ->prepare( "SELECT COUNT(*) FROM node WHERE type_nodetype='$selectionTypeID'" . $sqlFilterUser );
    $sth->execute();
    ($total) = $sth->fetchrow;
    $text
        .= 'Found <strong>'
        . $total
        . '</strong> nodes of nodetype <strong><a href='
        . urlGen( { 'node_id' => $selectionTypeID } ) . '>'
        . $validTypeIDs{$selectionTypeID}
        . '</a></strong>';
    $text .= $plainTextFilter if length($plainTextFilter);
    $text .= '.';

    my $num = $isRoot ? 100 : $isCE ? 75 : 60;

    #gets a node given the ID
    #this caches nodes between hits, so it doesn't hurt to get 1 user a zillion times
    #note: this is completely pointless if E2 keeps a cache per-page-load, but I don't think it currently does that
    #returns undef if unable to get a node
    #created: 2001.11.27.n2; updated: 2002.05.14.n2
    #author: N-Wing
    my %ids = ( $USER->{node_id} => $USER, $NODE->{node_id} => $NODE );
    local *getNodeFromID = sub {
        my $node_id = $_[0];
        return unless ( defined $node_id ) && ( $node_id =~ /^\d+$/ );

        #already known, return it
        return $ids{$node_id} if exists $ids{$node_id};

        #unknown, find that (we also cache a mis-hit, so we don't try to get it again later)
        my $N = getNodeById($node_id);
        return $ids{$node_id} = $N;
    };

    my $listedItems = '';
    my $next        = $query->param('next') || '0';
    my $queryText
        = "SELECT node_id, title, author_user, createtime FROM node WHERE type_nodetype = '$selectionTypeID'";
    $queryText .= $sqlFilterUser if length($sqlFilterUser);
    $queryText .= ' ORDER BY ' . $sqlSort if length($sqlSort);
    $queryText .= " LIMIT $next, $num";

    $sth = $DB->{dbh}->prepare($queryText);
    $sth->execute();
    my $numCurFound = 0;
    my $aID;         #author ID
    while ( my $item = $sth->fetchrow_arrayref )
    {
        ++$numCurFound;
        $listedItems .= '<tr><td>';
        $aID = $item->[2];

        #show edit link if admin or user viewing page created node
        if ( $isRoot || ( $aID == $UID ) )
        {
            $listedItems
                .= '<small>('
                . linkNode( $item->[0], 'edit', { lastnode_id => 0, displaytype => 'edit' } )
                . ')</small>';
        }

        $listedItems
            .= '</td><td>'
            . linkNode( @$item[ 0, 1 ], { lastnode_id => 0 } )
            . '</td><td>'
            . $item->[0]
            . '</td>';
        $listedItems .= '<td>' . linkNode( getNodeFromID($aID), 0, { lastnode_id => 0 } ) . '</td>';
        my $createTime = $item->[3];
        $listedItems
            .= '<td>'
            . htmlcode( 'parsetimestamp', $createTime . ',1' )
            . '</td><td>'
            . htmlcode( 'timesince', $createTime . ',1,100' )
            . '</td>';
        $listedItems .= "</tr>\n";
    }
    $text .= ' (Showing items ' . ( $next + 1 ) . ' to ' . ( $next + $numCurFound ) . '.)' if $total;
    $text .= '</p><p><table border="0">
<tr><th>edit</th><th>title</th><th>node_id</th><th>author</th><th>created</th><th>age</th></tr>
'
        . $listedItems
        . '
</table></p>
';
    return $text if ( $total < $num );

    local *jumpLinkGen = sub {
        my ( $startNum, $disp ) = @_;
        my $opts = {
            'node_id' => $NODE->{node_id},
            'fetch'   => 1,
            'next'    => $startNum,

            #        'chosen_type'=>$selection,    #stored in VARS now
        };
        if ( defined $filterUser )
        {
            $opts->{filter_user}     = $filterUser->{title};
            $opts->{filter_user_not} = $filterUserNot;
        }
        return '<a href=' . urlGen($opts) . '>' . $disp . '</a>';
    };

    my $nextprev  = '';
    my $remainder = $total - ( $next + $num );
    if ( $next > 0 )
    {
        $nextprev .= jumpLinkGen( $next - $num, 'previous ' . $num ) . "<br />\n";
    }
    if ( $remainder < $num and $remainder > 0 )
    {
        $nextprev .= jumpLinkGen( $next + $num, 'next ' . $remainder ) . "\n";
    }
    elsif ( $remainder > 0 )
    {
        $nextprev .= jumpLinkGen( $next + $num, 'next ' . $num ) . "<br />\n";
    }
    $text .= qq|<p align="right">$nextprev</p>| if length($nextprev);

    return $text;
}

sub macro_faq
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    $text .= '<p><big><strong>Macro FAQ</strong></big>';
    $text .= ( $APP->isEditor($USER) ) ? '' : ' (note: you are not allowed to use macros yet)';
    $text .= '</p>
<p>Okay, okay, this isn\'t really a FAQ, more like a mini-lesson on how to use the <code>/macro</code> command. But isn\'t "macro FAQ" easier to remember than "macro mini-lesson-and-possibly-later-even-some-frequently-asked-questions"?</p>

<p><strong>Use <code>/macro</code></strong><br />
A macro can be used in the chatterbox by typing:<br />
<code>/macro</code> <var>macroname</var> &#91; <var>parameter1</var> &#91; <var>parameter2</var> &#91; ... &#93; &#93; &#93;<br />
You first have to enable the macro(s) you wish to use, though, at [user settings 2]. For each macro you may want to use, check the appropriate box in the "Use?" column. If you don\'t want to use a macro any more, uncheck the box. If you desire, you can edit the macro to your liking.
</p>

<p><strong>Example</strong><br />
Here is an example of how to use the default "newbie" macro, which sends a private message to a user, telling them about [Everything University] and [Everything FAQ], and how to /msg you back.
</p><ol>
<li>visit [user settings 2]</li>
<li>in the "Macros" section, find the "newbie" macro, and check that checkbox</li>
<li>press the "Submit" button</li>
<li>in the chatterbox, type: <code>/macro newbie ';

    my $n = $USER->{title};
    $n =~ s/ /_/g;
    $text .= $n;

    $text .= ' Duh, this is easy stuff!</code></li>
<li>press the "Talk" button :)</li>
</ol>
<p>
What you just did was send a basic E2-usage message to a newbie (in this case, you). In the default "newbie" macro setup, the messages are sent to the user specified in the first parameter (in this case, you). Anything you type afterwards are added to the first message. <!-- NPB FIXME should say if invalid macro name (change return value and use that) When you send any macro, you will also get a message saying which macro you ran, along with the parameters. -->
</p>

<p><strong>Variable Substitution</strong><br />
So far, macros only support the <code>/say</code> command, which treats everything after it as something you typed in the chatterbox. Well, mostly... there are a few variables that you can use. Each variable must have a space on each site.<br />
If you use <code>$0</code> by itself, your username will substituted in (with underscores, if your name has spaces in it).<br />
If you use <code>$1</code> and up (in the form <code>$</code><var>n</var>), that will substitute the first (or <var>n</var><sup>th</sup>) word you entered after the macro\'s name.<br />
But what if you want to type a whole bunch of words? Instead of doing something like <code>$3 $4 $5 $6</code> ..., you can use <code>$3+</code> which will show all the words after the second.<br />
</p>

<p><strong>Created Macros</strong><br />
This section will have some useful macros people have created.<br />
(Um, has anybody done anything useful with these? Although I doubt it, tell [N-Wing|me] if so.)
</p>

<p><strong>Miscellaneous</strong><br />
Note: if you want to use a square bracket, &#91; and/or &#93; in the macro definition (that is, in the place where you type in the macro in [user settings 2]), you\'ll have to type it as a curly brace, { and/or } <small>(sorry about that)</small>.
<br />
Note: in most cases, the first parameter is the user you want to get the macro text. As is the case with sending a normal private message, if the user has a space in their name, you should change them into underscores.
</p>

<p><strong>FAQs</strong> <small><small>(Wow! Some actual questions in something that is supposed to <strong>all</strong> Q &amp; As!)</small></small></p>
<dl>

<dt><strong>Q</strong>: Who can use macros?</dt>
<dd><strong>A</strong>: Currently, only ';

    $text .= linkNode( getNode( 'Content Editors', 'usergroup' ) ) . ' and '
        . linkNode( getNode( 'gods', 'usergroup' ) );

    $text .= ' may.</dd>

<dt><strong>Q</strong>: What happens if you call a macro recursively?</dt>
<dd><strong>A</strong>: Who knows? While it doesn\'t cause an infinite loop, it also doesn\'t seem to work as expected. So for now, don\'t. <tt>:-/</tt></dd>

<!--
<dt><strong>Q</strong>: </dt>
<dd><strong>A</strong>: </dd>
-->

</dl>

<p><strong>Stored Macros</strong><br />
Here are all your currently defined macros. You can edit them at [user settings 2].
<table cellspacing="1" cellpadding="3" border="1">
<tr><th>Name</th><th>Text</th></tr>
';

    return $text if $APP->isGuest($USER);

    my $k;
    my $v;
    foreach ( sort( keys(%$VARS) ) )
    {
        next unless /^chatmacro_(.+)/;
        $k = $1;
        $v = $VARS->{$_};
        $v =~ s/&/&amp;/gs;
        $v =~ s/</&lt;/gs;
        $v =~ s/>/&gt;/gs;
        $v =~ s/\[/&#91;/gs;
        $v =~ s/\]/&#93;/gs;
        $v =~ s/\n/<br \/>/gs;
        $text .= '<tr><td valign="top"><code>' . $k . '</code></td><td><code>' . $v . "</code></td></tr>\n";
    }

    $text .= '</table>
</p>

<p><strong>Lame Guide/FAQ/etc. Thingy</strong><br />
If you have a question about macros, you can <code>/msg N-Wing</code>, so this currently-lame guide can be updated. You can also /msg N-Wing if you have an idea for better default macros, and/or want more added that would be probably used by other people.
</p>';

    return $text;
}

sub popular_registries
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    $text .= '<table align="center">
<tr>
<th>Registry</th>
<th># Submissions</th>
</tr>';

    my $rows;
    my $row;
    my $str    = '';
    my $queryText;
    my $limit  = 25;
    my $r;

    $queryText =
        'select for_registry,COUNT(for_registry) AS ctr FROM registration GROUP BY for_registry ORDER BY ctr DESC LIMIT '
      . $limit;
    $rows = $DB->{dbh}->prepare($queryText)
      or return $rows->errstr;
    $rows->execute()
      or return $rows->errstr;

    while ( $row = $rows->fetchrow_arrayref ) {
        $r = getNodeById( $$row[0] );
        $str .= '<tr>
      <td>' . linkNode($r) . '</td>
      <td style="text-align:center">' . $$row[1] . '</td>
      </tr>';
    }

    $text .= $str;
    $text .= '</table>';

    return $text;
}

sub fiery_teddy_bear_suit
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    $text .= '<p><i><b>';
    $text .= $$USER{title};
    $text .= '</b> is engulfed in flames . . . OW! </i>';
    $text .= '</p>';
    $text .= "\n";

    # Only gods can use this feature
    return $text . '<p>Hands off the bear, bobo.</p>' unless $APP->isAdmin($USER);

    # Display note text to the gods group
    my $notestr = 'The user(s) are publicly hugged by a Fiery Teddy Bear. Users are cursed with -1 GP.<br /><br />';

    # Adapted from superbless
    my @params = $query->param;
    my $str    = '';

    # Get the list of users to be hugged
    my (@users);
    foreach (@params) {
        if (/^hugUser(\d+)$/) {
            $users[$1] = $query->param($_);
        }
    }

    # For this purpose the curse is fixed at -1 GP
    my $curGP = 1;

    # Loop through, apply the curse, report the results
    for ( my $count = 0; $count < @users; $count++ ) {
        next unless $users[$count];

        my ($U) = getNode( $users[$count], 'user' );
        if ( not $U ) {
            $str .= "couldn't find user $users[$count]<br />";
            next;
        }

        # Fiery Teddy Bear Suit
        # Tell the catbox
        $DB->sqlInsert(
            'message',
            {
                msgtext     => '/me hugs ' . $$U{title},
                author_user => getId( getNode( 'Fiery Teddy Bear', 'user' ) ),
                for_user    => 0,                # 0 is public
                room        => $$USER{in_room}   # 0 is outside
            }
        );

        $str .= "User $$U{title} lost $curGP GP";
        $$U{karma} -= 1;
        updateNode( $U, -1 );
        $APP->securityLog(
            getNode( 'Superbless', 'superdoc' ),
            $USER,
            "$$USER{title} hugged $$U{title} using the [Fiery Teddy Bear suit] for negative $curGP GP."
        );
        $APP->adjustGP( $U, -$curGP );

        $str .= "<br />\n";
    }

    $text .= $str;

    # Build the form
    $text .= htmlcode('openform');
    $text .= '<table border="1">';

    # Build the table rows for inputting user names
    my $count = 3;
    $str = '';

    $str .= '<tr><th>Hug these users</th></tr> ';

    for ( my $i = 0; $i < $count; $i++ ) {
        $query->param( "hugUser$i", '' );
        $str .= '<tr><td>';
        $str .= $query->textfield( "hugUser$i", '', 40, 80 );
        $str .= '</td></tr>';
    }

    $text .= $str;
    $text .= '</table>';
    $text .= htmlcode('closeform');

    return $text;
}

sub gnl
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    # Header
    $text .= '<center><h3>Gigantic Node Lister</h3></center>';
    $text .= "\n";

    # Form for type selection
    $text .= htmlcode('openform');
    $text .= "\n";

    # Build type selection menu

    my $menu = new Everything::FormMenu();
    my $type = $query->param('whichtype');
    $type ||= "alltypes";

    $menu->addHash({ "alltypes" => "All Types"});
    $menu->addType('nodetype', 1);

    $text .= $menu->writePopupHTML($query, "whichtype", $type);
    $text .= "\n";

    $text .= htmlcode('closeform');
    $text .= "\n";

    # Color scheme for node types
    my %CLR = (
        document => "#AAAAcc",
        user => "#66dd66",
        usergroup => "#99CC99",
        nodetype => "#CC6666",
        htmlpage => "#CC66CC",
        htmlcode => "#FF99FF",
        node => "#FFFFFF",
        superdoc => "#6666CC",
        nodegroup => "#CCCCCC",
        image => "#33CCFF",
        default => '#ffffff',
        container => '#FFCC99',
        nodelet => '#CCFFCC'
    );

    my $ref;

    if($type eq "alltypes")
    {
        $ref = $DB->selectNodeWhere({ -1 => 1 }, "",
            "type_nodetype");
    }
    else
    {
        $ref = $DB->selectNodeWhere({type_nodetype => $type}, "");
    }

    return $text . "<p><b>No Nodes of the selected type</b>\n"
        unless(defined $ref);

    my $count = $query->param("next");
    $count ||= 0;
    my $length = $$VARS{listlen};
    $length ||= 100;
    my $max = $count + $length;

    # Generate the prev...count...next row
    my $nav;
    $nav .= "<tr><td align=left>";

    my $next = $count - $length;
    $next = 0 if ($count - $length < 0);

    $nav .= "<a href=" .
        urlGen ({node_id => getId ($NODE), next => 0}) .
        ">Previous " . ($count-$next) . " entries...</a>"
        if ($count > 0);

    $nav .= "</td><td align=center>($count-$max) of ".int(@$ref)."</td><td align=right>";

    $next = $count+$length;
    my $num = $length;
    if ($next + $length > @$ref) {
        $num = @$ref - $next;
    }

    $nav .= "<a href=" .
        urlGen ({node_id => getId ($NODE), next => $max}) .
        ">Next $num entries...</a>" if ($max < @$ref);
    $nav .= "</td></tr>";

    # Construct the table
    my $str = "<TABLE width=100% border=0>";
    my $NODEGROUP;

    if ($$VARS{group}) {
        my $GR = $DB->getNodeById($$VARS{group}, 'light');

        if(canUpdateNode($USER, $GR))
        {
            $NODEGROUP = $GR;
            $str .=
                "<SCRIPT language=\"javascript\">
                function updateMyGroup(nodeid) {
                    window.open('" .
                    urlGen({node_id => $$VARS{group},
                    displaytype => 'editor'}, "noquotes") .
                    "&add='+nodeid+'" .  "','". $$VARS{group} ."', '');
                }
                </SCRIPT>";
        }
    }

    $str .= $nav;
    $str .= "<tr><th>Node ID</td><th>Title</th><th>Type</th></tr>";

    for (my $i=$count;$i<$max and $i < @$ref;$i++){
        my $N = $DB->getNodeById($$ref[$i], 'light');
        $str .= "<tr><td align=left>" . getId($N);
        if ($NODEGROUP) {
            $str .= "<font size=1><A href=\"javascript:updateMyGroup(".getId($N).")\">add to &quot;$$NODEGROUP{title}&quot;</a></font>";
        }

        $str .= "</td><td bgcolor=#DDCCCC>" . linkNode ($N) .
            "</td><td bgcolor=" .
            ($CLR{$$N{type}{title}} || $CLR{default}) .
            ">$$N{type}{title}</td></tr>\n" if (ref $$N{type});
    }
    $str .= $nav;

    $str .= "</TABLE>";
    $text .= $str;

    return $text;
}

sub giant_teddy_bear_suit
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    $text .= '<p><i><b>';
    $text .= $$USER{title};
    $text .= '</b> has donned the Giant Teddy Bear Suit . . . </i>';
    $text .= '</p>';
    $text .= "\n";

    # Only gods can use this feature
    return $text . '<p>Hands off the bear, bobo.</p>' unless $APP->isAdmin($USER);

    # Display note text to the gods group
    my $notestr = 'The user(s) are publicly hugged by a Giant Teddy Bear. Users are blessed with 2 GP.<br /><br />';

    # Adapted from superbless
    my @params = $query->param;
    my $str    = '';

    # Get the list of users to be hugged
    my (@users);
    foreach (@params) {
        if (/^hugUser(\d+)$/) {
            $users[$1] = $query->param($_);
        }
    }

    # For this purpose the bless is fixed at 2 GP
    my $curGP = 2;

    # Loop through, apply the bless, report the results
    for ( my $count = 0; $count < @users; $count++ ) {
        next unless $users[$count];

        my ($U) = getNode( $users[$count], 'user' );
        if ( not $U ) {
            $str .= "couldn't find user $users[$count]<br />";
            next;
        }

        # Giant Teddy Bear Suit
        # Tell the catbox
        $DB->sqlInsert(
            'message',
            {
                msgtext     => '/me hugs ' . $$U{title},
                author_user => getId( getNode( 'Giant Teddy Bear', 'user' ) ),
                for_user    => 0,                # 0 is public
                room        => $$USER{in_room}   # 0 is outside
            }
        );

        $str .= "User $$U{title} was given $curGP GP";
        $$U{karma} += 1;
        updateNode( $U, -1 );
        htmlcode( 'achievementsByType', 'karma' );
        $APP->securityLog(
            getNode( 'Superbless', 'superdoc' ),
            $USER,
            "$$USER{title} hugged $$U{title} using the [Giant Teddy Bear suit] for $curGP GP."
        );
        $APP->adjustGP( $U, $curGP );

        $str .= "<br />\n";
    }

    $text .= $str;

    # Build the form
    $text .= htmlcode('openform');
    $text .= '<table border="1">';

    # Build the table rows for inputting user names
    my $count = 3;
    $str = '';

    $str .= '<tr><th>Hug these users</th></tr> ';

    for ( my $i = 0; $i < $count; $i++ ) {
        $query->param( "hugUser$i", '' );
        $str .= '<tr><td>';
        $str .= $query->textfield( "hugUser$i", '', 40, 80 );
        $str .= '</td></tr>';
    }

    $text .= $str;
    $text .= '</table>';
    $text .= htmlcode('closeform');

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
    <link rel="icon" href="' . $APP->asset_uri("react/assets/favicon.ico") . '" type="image/vnd.microsoft.icon">
    <!--[if lt IE 8]><link rel="shortcut icon" href="' . $APP->asset_uri("react/assets/favicon.ico") . '" type="image/x-icon"><![endif]-->
    <link rel="alternate" type="application/atom+xml" title="Everything2 New Writeups" href="/node/ticker/New+Writeups+Atom+Feed">
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
';

    $html .= htmlcode('nodelet_meta_container');

    $html .= '
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

# Recent Users (oppressor_superdoc)
# Displays users who have logged in within the last 24 hours
# Shows username and staff symbols (admin, editor, chanop)
sub recent_users
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $str = undef;
    my $queryText = undef;
    my $rows = undef;
    my $dbrow = undef;
    my $U = undef;
    my $flags = undef;
    my $ctr = 0;
    my $uid = undef;

    # Staff symbol links
    my $powStructLink = '<a href=' . urlGen( { 'node' => 'E2 staff', 'nodetype' => 'superdoc' } );
    my $linkRoots = $powStructLink . ' title="e2gods">@</a>';
    my $linkCEs = $powStructLink . ' title="Content Editors">$</a>';
    my $linkChanops = $powStructLink . ' title="chanops">+</a>';

    # Query users who logged in within last 24 hours
    $queryText = "SELECT user_id FROM user,node WHERE user.user_id=node.node_id AND lasttime>=ADDDATE(NOW(), INTERVAL -1 DAY) ORDER BY node.title";
    $rows = $DB->{dbh}->prepare($queryText)
        or return $rows->errstr;
    $rows->execute()
        or return $rows->errstr;

    $str = '<p>The following is a list of users who have logged in over the last 24 hours.</p>
         <table border="1">
         <tr>
         <th>#</th>
         <th>Name</th>
         <th>Title</th>
         </tr>';

    while ( $dbrow = $rows->fetchrow_arrayref ) {
        $ctr++;
        $uid = $$dbrow[0];
        $U   = getNodeById($uid);

        my $thisChanop = $APP->isChanop( $U, "nogods" );

        $flags = '';
        if ( $APP->isAdmin($U) && !$APP->getParameter( $U, "hide_chatterbox_staff_symbol" ) ) {
            $flags .= $linkRoots;
        }
        if ( $APP->isEditor( $U, "nogods" ) && !$APP->getParameter( $U, "hide_chatterbox_staff_symbol" ) ) {
            $flags .= $linkCEs;
        }
        $flags .= $linkChanops if $thisChanop;

        # gravatar column (if approved)            <td><img src="http://gravatar.com/avatar/'.md5_hex($$U{email}).'?d=identicon&s=32" alt="." /></td>
        # lastseen time (if approved)            <td style="text-align:center">'.$$U{lasttime}.'</td>
        $str .= '<tr>
            <td style="text-align:center">' . $ctr . '</td>
            <td>' . linkNode($U) . '</td>
            <td style="text-align:center">' . $flags . '</td>
            </tr>';
    }
    $str .= '</table>';

    return $str;
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
        return ( $query->param( $_[0] ) eq '1' ) ? 1 : 0;
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
    $sqlSort = $mapVARStoSQL{ $VARS->{ListNodesOfType_Sort} };

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

# Text Formatter (superdoc)
# Legacy JavaScript-based text formatting tool for converting plain text to HTML
# Provides paragraph formatting, list creation, style markup, and HTML character escaping
sub text_formatter
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $str = undef;

    # Developer note
    if ( $APP->isDeveloper($USER) ) {
        $str = '<p>Note: this is from [Magical Text Formatter]</p>';
    }

    # Static HTML/JavaScript content
    $str .= q#
<p align="right">Last updated Thursday March 21, 2002</p>
<p>
This is intended to be the E2 Text Formatter to end all Text Formatters.
It will [E2 Paragraph Tagger|insert paragraphs].
It will [Wharfinger's Linebreaker|insert line breaks].
It will [E2 Source Code Formatter|escape special characters].
It will [E2 List Formatter|format lists of items].
And it will add styles, interpret horizontal rules,
and indent using the markup tags of your choice,
all thanks to the power of [regular expression\|regular expressions].
<p>
<script language="javascript">
if (navigator.userAgent.indexOf('Opera') == -1) {
//version = navigator.userAgent.substring(navigator.userAgent.indexOf('v'));
  document.write("The \"undo\" and \"preview\" features are there because I always wanted them. I hope they're useful. ");
} else {
  document.write("The \"undo\" feature is there because I always wanted it. I hope it's useful. ");
}
</script>
Several configurable options are below the form buttons;
their default settings are all what seem to be used most often.
<p>
The one caveat is that your browser must support JavaScript 1.2,
which includes Netscape 4.0, Internet Explorer 4.0, and Opera 5.0.
If you have any problems, comments, or whatnot, send a [/msg] to [mblase].
<p>

<hr />

<form action="/index.pl" name="dummyform" method="post">

Enter the text to format below.
<a href="\#" onClick="return clearBox()">Clear the box</a>
<br /><br />
<textarea name="skratch" cols="60" rows="16"
style="font-family:monospace">Text can be *formatted* in a _variety_ of */styles/*.
Characters like <, >, and & are automatically escaped.

   You can also create indented text
   and lists of items:

1) alpha
2) bravo
3) charlie

* one
* two
* three

-----------
Just above this text is a horizontal line.</textarea>
<br /><br />
<input type="hidden" name="undo" value="">
<input type="submit" value="Format Text" onClick="doFormat();return false">
<input type="submit" value="Undo" onClick="undoFormat();return false">
<script language="javascript">
if (navigator.userAgent.indexOf('Opera') == -1) {
//version = navigator.userAgent.substring(navigator.userAgent.indexOf('v'));
  document.write('<input type="submit" value="Preview" onClick="popupHTML();return false">');
}
</script>

<hr>
Format new lines using:<br />
&nbsp; &nbsp; &nbsp; &nbsp;
<input type="radio" name="breaks" value="p" checked>
  <tt>&lt;p&gt;...&lt;/p&gt;</tt> paragraph tags at empty lines<br />
&nbsp; &nbsp; &nbsp; &nbsp;
<input type="radio" name="breaks" value="br">
  <tt>&lt;br /&gt;</tt> line break after each new line<br />

<br />
Convert <tt>*starred text*</tt> to: <br />
  &nbsp; &nbsp; &nbsp; &nbsp;
  <input type="radio" name="starred" value="b" checked> <b>bold</b>
  <input type="radio" name="starred" value="i"> <i>italics</i>
  <input type="radio" name="starred" value="u"> <u>underline</u>
  <input type="radio" name="starred" value=""> plain text
  <input type="radio" name="starred" value="ignore"> don't convert to HTML
<br />
Convert <tt>_underscored text_</tt> to: <br />
  &nbsp; &nbsp; &nbsp; &nbsp;
  <input type="radio" name="underlined" value="b"> <b>bold</b>
  <input type="radio" name="underlined" value="i" checked> <i>italics</i>
  <input type="radio" name="underlined" value="u"> <u>underline</u>
  <input type="radio" name="underlined" value=""> plain text
  <input type="radio" name="underlined" value="ignore"> don't convert to HTML
<br />
Convert <tt>/slashed text/</tt> to: <br />
  &nbsp; &nbsp; &nbsp; &nbsp;
  <input type="radio" name="slashed" value="b"> <b>bold</b>
  <input type="radio" name="slashed" value="i" checked> <i>italics</i>
  <input type="radio" name="slashed" value="u"> <u>underline</u>
  <input type="radio" name="slashed" value=""> plain text
  <input type="radio" name="slashed" value="ignore"> don't convert to HTML
<br />

<br />
Convert lines beginning with <tt>*</tt> or <tt>.</tt> to:<br />
  &nbsp; &nbsp; &nbsp; &nbsp;
  <input type="radio" name="starlist" value="ul" checked> bulleted lists
  <input type="radio" name="starlist" value="ol"> numbered lists
  <input type="radio" name="starlist" value="ignore"> don't convert to lists
<br />
Convert lines beginning with <tt>-</tt> or <tt>--</tt> to:<br />
  &nbsp; &nbsp; &nbsp; &nbsp;
  <input type="radio" name="dashlist" value="ul" checked> bulleted lists
  <input type="radio" name="dashlist" value="ol"> numbered lists
  <input type="radio" name="dashlist" value="ignore"> don't convert to lists
<br />
Convert lines beginning with <tt>1.2.3.</tt> or <tt>1)2)3)</tt> to:<br />
  &nbsp; &nbsp; &nbsp; &nbsp;
  <input type="radio" name="numberlist" value="ul"> bulleted lists
  <input type="radio" name="numberlist" value="ol" checked> numbered lists
  <input type="radio" name="numberlist" value="ignore"> don't convert to lists
<br />
Convert other indented text to:<br />
  &nbsp; &nbsp; &nbsp; &nbsp;
  <input type="radio" name="indent" value="blockquote" checked> blockquotes
  <input type="radio" name="indent" value="pre"> <tt>preformatted text</tt>
  <input type="radio" name="indent" value="ignore"> don't indent
<br />

<br />
<input type="checkbox" name="horizrule" value="yes" checked>
    Convert rows of hyphens, equals or underscores into <tt>&lt;hr /&gt;</tt> tags<br />
<!-- ADDED 08/31/01 -->
<input type="checkbox" name="logicalstyles" value="yes">
    Use <strong>&lt;strong&gt;</strong> and <em>&lt;em&gt;</em> instead of <b>&lt;b&gt;</b> and <i>&lt;i&gt;</i><br />
<!-- END ADDED -->
<input type="checkbox" name="curlyquotes" value="yes" checked>
    Convert all "curly quotes" to standard quotes<br />
<input type="checkbox" name="brackets" value="yes">
    Convert &\#91;brackets&\#93; to HTML symbols<br />
<input type="checkbox" name="asciichars" value="yes" checked>
    Convert other ASCII characters to HTML symbols<br />
<input type="checkbox" name="striptags" value="yes">
    Strip existing HTML tags before formatting<br />
<!-- <input type="checkbox" name="optimize" value="yes">
    Optimize HTML by removing extra whitespace<br /> -->
<br />

</form>


<script language="javascript1.2">
<!--
var myform = document.dummyform;
// ========================================================================
// some hacks to get around E2's lack of bracket escapes
var ob = String.fromCharCode(91);    // opening bracket
var cb = String.fromCharCode(93);    // closing bracket
function getRadio(name,pos) { return eval("myform."+name+ob+pos+cb); }
// the main formatting function, checks all options and adds tags accordingly
function clearBox() {
  myform.undo.value = myform.skratch.value;
  myform.skratch.value = "";
  return false;
}
function doFormat() {
  var text = myform.skratch.value;
  myform.undo.value = text;
  text = fixEndOfLine(text);


  // prepare the text
  if (myform.striptags.checked)   { text = stripTags(text); }
  if (myform.curlyquotes.checked) { text = fixCurlyQuotes(text); }
  if (myform.asciichars.checked)  { text = encodeAscii(text); }
  if (myform.brackets.checked)    { text = encodeBrackets(text); }


  // add text styles
  for (var i=0; i<myform.slashed.length; i++) {
    var myradio = getRadio("slashed", i);
    if (myradio.checked) { text = addStyles("\\\\/", myradio.value, text); }
  }
  for (var i=0; i<myform.starred.length; i++) {
    var myradio = getRadio("starred", i);
    if (myradio.checked) { text = addStyles("\\\\*", myradio.value, text); }
  }
  for (var i=0; i<myform.underlined.length; i++) {
    var myradio = getRadio("underlined", i);
    if (myradio.checked) { text = addStyles("_", myradio.value, text); }
  }


  // format linebreaks and horiz. rules
  for (var i=0; i<myform.breaks.length; i++) {
    var myradio = getRadio("breaks", i);
    if (myradio.value=="p" && myradio.checked) { text = addPara(text); }
    else if (myradio.value=="br" && myradio.checked) { text = addBr(text); }
  }
  if (myform.horizrule.checked)   { text = addHorizRule(text); }


  // format ordered and unordered lists and indenting
  for (var i=0; i<myform.starlist.length; i++) {
    var myradio = getRadio("starlist", i);
    if (myradio.checked) { text = addGenericList(ob+"\\\\*\\\\."+cb+" ", "li", myradio.value, text); }
  }
  for (var i=0; i<myform.dashlist.length; i++) {
    var myradio = getRadio("dashlist", i);
    if (myradio.checked) { text = addGenericList("\\\\-\\\\-?", "li", myradio.value, text); }
  }
  for (var i=0; i<myform.numberlist.length; i++) {
    var myradio = getRadio("numberlist", i);
    if (myradio.checked) { text = addGenericList("\\\\d+"+ob+"\\\\.\\\\) "+cb, "li", myradio.value, text);}
  }
  for (var i=0; i<myform.indent.length; i++) {
    var myradio = getRadio("indent", i);
    if (myradio.checked) { text = addGenericList("(\\\\t+|  +) *", "", myradio.value, text); }
  }


  // optimize HTML
  text = text.replace(/<\/?>/g, "");    // delete "empty tags"
//  if (myform.optimize.checked) { text = optimizeWhitespace(text); }
  text = optimizeWhitespace(text);
  text = text.replace(/^\n+/, "");      // trim leading linebreaks
  text = text.replace(/\n+$/, "\n");    // trim trailing linebreaks
  myform.skratch.value = text;
  myform.skratch.select();
}
// undo the latest formatting using the hidden "undo" input tag
function undoFormat() {
  var temp = myform.skratch.value;
  myform.skratch.value = myform.undo.value;
  myform.undo.value = temp;
}
// open a new browser window

function popupHTML() {
  var wintext = myform.skratch.value;
  var reg1 = new RegExp("\\\\"+ob+"("+ob+"^\\\\|"+cb+cb+"*)"+"|"+"("+ob+"^\\\\"+cb+cb+"*)\\\\"+cb, "g"); // pipe link
  var reg2 = new RegExp("\\\\"+ob+"("+ob+"^\\\\"+cb+cb+"*\\\\)"+cb, "g");   // hard link
  var reg3 = /\s/g;
  var starturl = "<a target=\"_blank\" href=\"/index.pl?node=";
  var endurl = "\">";
// ADDED 10/10/01
  wintext = wintext.replace(reg1, starturl+"$1"+endurl+"$2</a>");
  wintext = wintext.replace(reg2, starturl+"$1"+endurl+"$1</a>");
  var idx = wintext.indexOf(starturl);
  while (idx>0) {
    idx += starturl.length;
    var end = wintext.indexOf(endurl, idx);
    wintext = wintext.substring(0,idx)+escape(wintext.substring(idx,end))+wintext.substring(end);
    idx = wintext.indexOf(starturl, idx+1);
  }
// END ADDED
// ADDED 8/31/01
// whoops -- nested functions is a JS 1.3 feature.
//  wintext = wintext.replace(reg1, function makeLink($0,$1) {
//                var s1=$1, s2=s1, pp=s1.indexOf("|");
//                if (pp>0) { s2=s1.substr(pp+1); s1=s1.substr(0,pp); }
//                return "<a target=\"_blank\" href=\"/index.pl?node="+escape(s1)+"\">"+s2+"</a>";
//              }
//            );
// END ADDED

// to add: close the popup window if it's already there

  var popupWin = window.open('', 'popup', 'status,scrollbars,resizable,width=480,height=360,left=20,top=20');
  var popupText = "<html><head>";
  popupText += "<title>Magical Text Formatter Preview@everything2.com</title>";
  popupText += "</head><body bgcolor='white'>";
  popupText += "<p align='right'><a href='javascript:window.close()'>Close window</a></p>";
  popupText += wintext;
  popupText += "</body></html>\n";
  popupWin.document.open();
  popupWin.document.write(popupText);
  popupWin.document.close();
  popupWin.focus();
}
// ========================================================================
// turn all end-of-line invisible characters to "standard" \n characters
function stripTags(str) {
  reg1 = new RegExp("<"+ob+"^ "+cb+""+ob+"^>"+cb+"*>", "g");
  str = str.replace(reg1, "");
  return str;
}
function fixEndOfLine(str) {
  str = str.replace(/\r\n/g, "\n");  // windows to unix
  str = str.replace(/\r/g, "\n");    // mac to unix
  str = str.replace(/^\n+/, "");     // trim extra leading linebreaks
  str = str.replace(/\n+$/, "");     // trim extra trailing linebreaks
  return str;
}
// replace "curly quotes" with regular HTML-safe quotes
function fixCurlyQuotes(str) {
  var reg1 = new RegExp(ob+String.fromCharCode(8216)+String.fromCharCode(8217)+cb, "g");
  str = str.replace(reg1, "\"");    // single quotes
  var reg2 = new RegExp(ob+String.fromCharCode(8220)+String.fromCharCode(8221)+cb, "g");
  str = str.replace(reg2, "\'");    // double quotes
  return str;
}
// replace odd ASCII characters with their HTML equivalents
function encodeAscii(str) {
  str = str.replace(/\&/g, "&amp;");
  str = str.replace(/\</g, "&lt;");
  str = str.replace(/\>/g, "&gt;");
  // get other odd ASCII characters
  for (var i=160; i<256; i++) {
    var reg = new RegExp(String.fromCharCode(i), "g");
    str = str.replace(reg, "&\#"+i+";");
  }
  return str;
}
// replace brackets with HTML-safe characters
function encodeBrackets(str) {
  var reg1 = new RegExp("\\\\"+ob, "g");
  var reg2 = new RegExp("\\\\"+cb, "g");
  str = str.replace(reg1, "&\#91;");
  str = str.replace(reg2, "&\#93;");
  return str;
}
// create <hr> tags from ASCII rules
function addHorizRule(str) {
  var reg1 = new RegExp("(<p>|\\\\n<br \\\\/>)?\\\\n"+ob+" \\\\t"+cb+"*"+ob+"\\\\-_="+cb+"{5,}"+ob+" \\\\t"+cb+"*(\\\\n<\\\\/p>|<br \\\\/>\\\\n|\\\\n)?", "g");
  return str.replace(reg1, "\n<hr />\n");
}
// compress whitespace to optimize the HTML
function optimizeWhitespace(str) {
  str = str.replace(/  +/g, " ");
  str = str.replace(/\t+/g, " ");
  str = str.replace(/\n /g, "\n");
  str = str.replace(/\n\n+/g, "\n");
  return str;
}
// ========================================================================
// add <br /> linebreaks to the string
function addBr(str) {
  str = str.replace(/\n/g, "<br />\n");
  str += "<br />\n";
  return str;
}
// add <p> paragraph tags to the string
function addPara(str) {
  var reg1 = new RegExp("\n"+ob+" \t"+cb+"*\n+", "g");
  str = str.replace(reg1, "\n</p>\n<p>\n");
  str = "\n<p>\n" + str + "\n</p>\n";
  return str;
}
// ========================================================================
// generic function to add lists of some type
function addGenericList(match,tag,ltype,str) {
  if (ltype=="ignore") { return str; }
  var startitem = "\n  <"+tag+">", enditem = "</"+tag+">";
  var listtag = enditem + startitem;
  var reg1 = new RegExp("\\\\n\\\\s*"+match+"\\s*", "g");
  str = str.replace(reg1, listtag);
  var reg2 = new RegExp("^\\\\s*"+match+"\s*", "g");
  str = str.replace(reg2, "\n"+listtag);
  str = addListOpenClose(startitem,enditem,ltype,str);
  return str;
}
// add opening and closing list tags around all <li> groups
function addListOpenClose(startitem, enditem, ltype, str) {
  var starttag = "\n<"+ltype+">", endtag = "\n</"+ltype+">";
  var listtag = enditem + startitem;
  var idx = 0;
  while (idx>=0) {
    // add opening list tag
    var mstr = "\n<p>"+listtag; idx = str.indexOf(mstr, idx);
    if (idx<0) { mstr = "\n<br />"+listtag; idx = str.indexOf(mstr, idx); }
    if (idx<0) { mstr = "\n"+listtag; idx = str.indexOf(mstr, idx); }
    if (idx>=0) {
      str = str.substring(0,idx) + starttag + startitem + str.substring(idx+mstr.length);
      idx += starttag.length + listtag.length;
    }
    // add closing list tag
    if (idx>=0) {
      mstr = "\n</p>";
      var temp = str.indexOf(mstr, idx);
      if (temp<0) {
        mstr = "<br />\n<";
        temp = str.indexOf(mstr, idx)+6;
        if (temp<idx) { temp=str.length; }
        mstr = "";  // keep the break tag after the insertion
      }
      if (temp>=0) {
        str = str.substring(0,temp) + enditem + endtag + str.substring(temp+mstr.length);
        temp += endtag.length;
      }
      idx = temp;
    }
  }
  return str;
}
// ========================================================================
function addStyles(mark,tag,str) {
  if (tag=="ignore") { return str; }
// ADDED 8/31/01
  if (myform.logicalstyles.checked) {
    if (tag=="b") { tag = "strong"; }
    else if (tag=="i") { tag = "em"; }
  }
// END ADDED
  // check the first character in the string
  var reg1 = new RegExp("^"+mark+"("+ob+"^ >"+mark+""+cb+""+ob+"^"+mark+""+cb+"*)"+mark, "g");
  // ignore slashes inside HTML tags
  var reg2 = new RegExp("("+ob+"^<"+cb+")"+mark+"("+ob+"^ >"+mark+""+cb+""+ob+"^"+mark+""+cb+"*"+ob+"^ <"+mark+""+cb+")"+mark, "g");
  if (tag) {
    str = str.replace(reg1, "<"+tag+">" + "$1" + "</"+tag+">");
    str = str.replace(reg2, "$1" + "<"+tag+">" + "$2" + "</"+tag+">");
  } else {
    str = str.replace(reg1, "$1");
    str = str.replace(reg2, "$1" + "$2");
  }
  return str;
}
// -->
</script>#;

    return $str;
}

=head2 usergroup_message_archive

Displays archived messages for usergroups that have message archiving enabled.
Members can view messages sent to their groups and copy them to their private inbox.

=cut

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

=head2 notelet_editor

Editor for user's "Notelet" nodelet - allows users to customize their notelet content with HTML/JavaScript.
Includes a "castrator" to comment out broken JavaScript and security verification.

=cut

sub notelet_editor
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $str          = undef;
    my $feedback     = undef;
    my $charcount    = undef;
    my $rawraw       = undef;
    my $MAXRAW       = undef;
    my $curLevel     = undef;
    my $maxLen       = undef;
    my $curLen       = undef;
    my $s            = undef;
    my $l            = undef;
    my @btns         = ();

    # Notelet Castrator section
    $str      = '<h3>Notelet Castrator</h3>

<p>This is the Notelet Castrator.  Its purpose is to neuter your Notelet by
        adding // to the front of every line, commenting out all Javascript.
        Use this tool when your Nodelet is causing problems and there is no other way to fix them.</p>

';
    $str .= htmlcode('openform');
    $feedback = "Click submit to castrate your Notelet Nodelet.<br>";

    if ( $query->param('YesReallyCastrate') ) {
        $VARS->{'noteletRaw'} =~ s,\n,\n//,g;
        $VARS->{'noteletRaw'} = '// ' . $VARS->{'noteletRaw'};
        $VARS->{'noteletScreened'} = "";
        $feedback = "</p>\n<p><b>Notelet Castrated!</b><br>";
    }

    $charcount = length( $VARS->{'noteletRaw'} );

    $str .= "\n<input type='hidden' name='YesReallyCastrate' value='1'>";
    $str .= "<p>Your notelet contains $charcount characters.  ";
    $str .= $feedback . "\n";
    $str .= htmlcode('closeform') . "</p>";

    # Separator
    $str .= '
<hr width="75%"><hr width="50%"><hr width="75%">

<h3>Notelet Editor</h3>

<p>This <strong>Notelet Editor</strong> lets you edit your Notelet. No, not your nodelet, your notelet (your notelet nodelet). ';

    # Guest user check
    if ( $APP->isGuest($USER) ) {
        $str .= 'Only logged in users can use this.</p>';
        return $str;
    }

    # Check if Notelet nodelet is enabled
    unless ( $VARS->{nodelets} =~ /1290534/ ) {    # kind of a hack, but it is quick
        $str .= ' (Note: you currently don\'t have your Notelet on, so changing things here is rather pointless. You can turn on the Notelet nodelet by visiting your '
            . linkNode( getNode( 'user settings', 'superdoc' ) ) . '.)';
    }

    $str .= ' What is the notelet? It lets you put notes (or anything, really) into a nodelet. (Other nodelet settings are available at '
        . linkNode( getNode( 'Nodelet Settings', 'superdoc' ) ) . '.)</p>

';

    # Process save if submitted
    if ( $query->param('makethechange') && !$APP->isGuest($USER) ) {

        # Security checking
        unless ( htmlcode( 'verifyRequest', 'noteletedit' ) ) {
            $str .= '<h2 class="error">Security error</h2><p>Invalid attempt made to edit notelet.</p>';
            return $str;
        }

        $rawraw = $query->param('notelet_source');
        $VARS->{noteletRaw} = $VARS->{personalRaw} if exists $VARS->{personalRaw};
        delete $VARS->{'personalRaw'};    #old way

        if ( ( !defined $rawraw ) || !length($rawraw) ) {
            delete $VARS->{'noteletRaw'};
        } else {
            $MAXRAW = 32768;
            if ( length($rawraw) > $MAXRAW ) {
                $rawraw = substr( $rawraw, 0, $MAXRAW );
                $query->param( 'notelet_source', $rawraw );
            }
            $VARS->{'noteletRaw'} = $rawraw;
        }
        htmlcode( 'screenNotelet', '' );
    }

    # Notes section
    $str .= '<p><strong>Notes</strong>:</p>
<ol>
<li><code>&lt;!--</code> You may enter comments here. Why would you want comments? Scripting! (But be sure to uncheck "Remove comments.") <code>--&gt;</code></li>
<li>The raw text you enter here is limited to 1000 characters. Anything longer than that will be lost. This raw text will not be changed in any way. As a slight reward for gaining levels, the higher your level, the more of your raw text is used. ';

    $curLevel = $APP->getLevel($USER) || 0;

    $maxLen = $curLevel * 100;
    if ( $maxLen > 1000 )    { $maxLen = 1000; }
    elsif ( $maxLen < 500 )  { $maxLen = 500; }

    # Power has its privileges
    # this is in [Notelet Editor] (superdoc) and [screenNotelet] (htmlcode)
    if ( $APP->isAdmin($USER) ) {
        $maxLen = 32768;
    } elsif ( $APP->isEditor($USER) ) {
        $maxLen += 100;
    } elsif ( $APP->isDeveloper($USER) ) {
        $maxLen = 16384;    #16k ought to be enough for everyone.
    }

    $str .= 'You are level '
        . $curLevel
        . ', so your maximum used length is <strong>'
        . $maxLen
        . '</strong> characters. This means that the first '
        . $maxLen
        . ' characters of your raw text ('
        . ( $VARS->{nodeletKeepComments} ? '' : 'not ' )
        . 'including comments) will be used for your notelet text. </small></li>
</ol>

<p><strong>Preview</strong>:<br />

';

    # Preview section
    unless ( ( exists $VARS->{noteletScreened} ) || ( exists $VARS->{personalScreened} ) ) {
        $str .= '<em>No text entered for the Notelet nodelet.</em></p>';
    } else {
        if ( $query->param('oops') ) {
            $query->delete('oops');
            $str .= 'Oops. Since your Notelet text messed things up, the preview is hidden. Fix it then resubmit.</p>';
        } else {
            $curLen = length( $VARS->{noteletScreened} || $VARS->{personalScreened} );
            $s      = '';

            $s .= '(If you missed a closing tag somewhere, and the bottom part of this page is all messed up, follow this <big><strong><a href='
                . urlGen( { 'node_id' => $NODE->{node_id}, 'oops' => int( rand(99999) ) } )
                . '>Oops!</a></strong></big> link to hide the preview.)<br />
';

            if ( $query->param('YesReallyCastrate') ) {
                $s .= "\n(<b>Note:</b> your preview will be empty if you've just castrated the notelet)<br>";
            }

            $s .= 'Your filtered length is currently ' . $curLen . ' character' . ( $curLen == 1 ? '' : 's' ) . '.
<table border="1" cellpadding="5" cellspacing="0"><tr><td>'
                . ( $VARS->{noteletScreened} || $VARS->{personalScreened} ) . '
<!--
this comment saves the user from old notelet text
with no closing comment mark; that is,
LEAVE THIS HERE
-->
</td></tr></table>';
            $str .= $s . '</p>';
        }
    }

    # Edit section
    $str .= '

<p><strong>Edit</strong>:<br />
Your raw text is ';
    $l = length( $VARS->{noteletRaw} || '' );
    $str .= $l . ' character' . ( $l == 1 ? '' : 's' ) . '.
<br />
';
    $str .= htmlcode( 'openform2', 'notelet_form' );
    $str .= htmlcode( 'varcheckboxinverse', 'noteletKeepComments,Remove comments' )
        . ' (Keep comments in if you\'re using scripting; otherwise, let them be removed. In either case, any comments in your source area, below, are not changed.)<br />
<textarea name="notelet_source" rows="25" cols="65 wrap="virtual" onkeypress="var mylen = new String(document.notelet_form.notelet_source.value); if(mylen.length > 32768) alert(\'You can only have up to 32768 characters in this nodelet. You currently have \'+ String(mylen.length) + \'.  Anything typed past this point will be irretrievably removed, never to be seen again.\');">';
    $str .= encodeHTML( ( $VARS->{noteletRaw} || $VARS->{personalRaw} ), 1 );
    $str .= '</textarea>
<br />
';

    @btns = ( 'submit', 'sumbit', 'button', 'notelet', 'noteletting', 'Notelet nodelet' );

    $str .= $query->hidden( 'sexisgood', 1 );
    $str .= $query->submit( 'makethechange', $btns[ rand( int(@btns) ) ] );
    $str .= htmlcode( 'verifyRequestForm', 'noteletedit' );
    $str .= '
</form>
</p>
';

    # Clean up
    delete $VARS->{'noteletScreened'};    #FIXME FIXME FIXME hack

    return $str;
}

=head2 who_is_doing_what

Admin-only tool showing recent node creation activity (excluding common node types like writeups and e2nodes).

=cut

sub who_is_doing_what
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $str        = undef;
    my $days       = undef;
    my $ignoreList = undef;
    my $whereStr   = undef;
    my $csr        = undef;
    my $row        = undef;
    my $typename   = undef;
    my @ignoreTypes = ();

    return 'Curiosity killed the cat, this means YOU ' . linkNode( $USER, $USER->{title} )
        unless ( $APP->isAdmin($USER) );

    $days = int $query->param('days');
    $days = 2 if ( $days < 1 );
    @ignoreTypes = qw/writeup e2node draft user debatecomment/;
    $ignoreList = join ', ', map { getType($_)->{node_id} } @ignoreTypes;
    $whereStr = "createtime >= DATE_SUB(NOW(), INTERVAL $days DAY)
  AND type_nodetype NOT IN ($ignoreList)
  ORDER BY CREATETIME DESC";
    $csr = $DB->sqlSelectMany( "*", "node", $whereStr );

    $str = '<ul>';

    while ( $row = $csr->fetchrow_hashref() ) {
        $typename = getNodeById( $row->{type_nodetype} );
        $str .= '<li>' . linkNode( $row, $row->{title} ) . " - " . $typename->{title};
    }

    $str .= '</ul>';

    return $str;
}

=head2 magical_writeup_reparenter

Admin tool (oppressor_superdoc) for moving writeups from one e2node to another.
Can fix orphaned writeups and handle bulk reparenting operations.

=cut

sub magical_writeup_reparenter
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $old_e2node_id    = undef;
    my $old_e2node       = undef;
    my $old_writeup_id   = undef;
    my $writeup          = undef;
    my $parent_node      = undef;
    my $new_e2node_id    = undef;
    my $new_e2node       = undef;
    my $inputs_string    = undef;
    my $selection_string = undef;
    my $feedback_string  = undef;
    my $movedsomething   = undef;
    my $newgroup         = undef;
    my $alreadyinnodegroup = undef;
    my $move_writeup     = undef;
    my $oldtitle         = undef;
    my $author           = undef;
    my $authortitle      = undef;
    my $writeuptype      = undef;
    my $guessParentTitle = undef;
    my $potentialParent  = undef;
    my %success_reparent = ();

    # Utility routine to get a node by ID or by name
    my $getNodeByNameOrId = sub {
        my ( $node_id_or_name, $nodetype ) = @_;
        my $target_node = undef;

        if ( $node_id_or_name =~ m/\D/ ) {
            $target_node = getNode( $node_id_or_name, $nodetype );
        } else {
            $target_node = getNodeById( $node_id_or_name, $nodetype );
            $target_node = undef
                unless $target_node
                && $target_node->{type}{title} eq $nodetype;
        }

        return $target_node;

    };

    # Get the old_e2node from either old_e2node_id or old_writeup_id
    $old_e2node_id = $query->param('old_e2node_id');

    if ( defined $old_e2node_id ) {
        $old_e2node = $getNodeByNameOrId->( $old_e2node_id, 'e2node' );
    }
    # only look at old_writeup_id if we don't get a old_e2node_id
    elsif ( defined( $old_writeup_id = $query->param('old_writeup_id') ) ) {
        $writeup = $getNodeByNameOrId->( $old_writeup_id, 'writeup' );
        $old_e2node = $parent_node = $getNodeByNameOrId->( $writeup->{'parent_e2node'}, 'e2node' );

        # If this node's parent e2node is invalid, try automatically finding and reparenting it
        if ( $writeup && !$parent_node ) {
            $guessParentTitle = $writeup->{title};

            # strip off '(idea)' writeuptype from title, if present
            # but be tolerant of writeups where it gets cut off
            $guessParentTitle =~ s/^(.*?)(\([^\(]*)?$/$1/;
            $potentialParent = getNode( $guessParentTitle, 'e2node' );
            if ($potentialParent) {
                $new_e2node = $potentialParent;
                $query->param( "reparent_" . $old_writeup_id, 1 );
            }
        }

    }

    # Get new_e2node_id
    if ( defined( $new_e2node_id = $query->param('new_e2node_id') ) ) {
        $new_e2node = $getNodeByNameOrId->( $new_e2node_id, 'e2node' );
    }

    # Perform the reparenting operation
    if ( ( $old_e2node || $writeup ) && $new_e2node ) {
        $movedsomething = 0;
        $newgroup       = $new_e2node->{'group'};
        $newgroup = [] unless $newgroup && ref $newgroup eq 'ARRAY';

        foreach my $move_writeup_id ( grep { /^reparent_/ } $query->param() ) {
            next unless ( $query->param($move_writeup_id) == 1 );
            $move_writeup_id =~ s/^reparent_//;
            $alreadyinnodegroup = scalar grep { $_ == $move_writeup_id; } @$newgroup;
            $move_writeup = htmlcode( 'make node sane', $move_writeup_id );
            next unless $move_writeup;
            $movedsomething = 1;
            $success_reparent{$move_writeup_id} = 1;

            $DB->removeFromNodegroup( $old_e2node, $move_writeup, -1 )
                if ( $old_e2node && $new_e2node->{'node_id'} != $old_e2node->{'node_id'} );

            $oldtitle   = $move_writeup->{'title'};
            $author     = getNodeById( $move_writeup->{'author_user'} );
            $authortitle = "bad author";
            $authortitle = $author->{'title'} if $author;

            # Reset writeup type just in case it was invalid
            $writeuptype = $getNodeByNameOrId->( $move_writeup->{'wrtype_writeuptype'}, 'writeuptype' );
            $writeuptype = getNode( 'idea', 'writeuptype' ) unless $writeuptype;
            $move_writeup->{'wrtype_writeuptype'} = $writeuptype->{'node_id'};
            $move_writeup->{'title'}              = $new_e2node->{'title'} . " ($writeuptype->{'title'})";
            $move_writeup->{'parent_e2node'}      = $new_e2node->{'node_id'};

            $DB->insertIntoNodegroup( $new_e2node, -1, $move_writeup )
                unless ($alreadyinnodegroup);

            updateNode( $move_writeup, -1 );

            $APP->securityLog( $NODE, $USER,
                    $oldtitle . " by ["
                    . encodeHTML($authortitle) . "]"
                    . " was moved to ["
                    . encodeHTML( $move_writeup->{'title'} ) . "]" );

            $DB->sqlInsert(
                'message',
                {
                    msgtext => 'I moved your writeup "['
                        . encodeHTML($oldtitle) . ']"'
                        . ' You can now find it at "'
                        . '[' . $new_e2node->{'title'} . ']"',
                    author_user => $USER->{'node_id'},
                    for_user    => $move_writeup->{'author_user'}
                }
            );

            $feedback_string .= "<p>Didn't insert into nodegroup since it was already in the destination e2node.</p>"
                if $alreadyinnodegroup;
            $feedback_string .= "\n<p>"
                . encodeHTML($oldtitle)
                . " by "
                . linkNode($author)
                . " has been moved from ";
            $feedback_string .= linkNode($old_e2node) if ($old_e2node);
            $feedback_string .= "<i>an unparented state</i>" if ( !$old_e2node );
            $feedback_string .= " to " . linkNode($new_e2node) . "</p>";
        }

        # Get nodes with updated groups now that we've moved stuff
        if ($movedsomething) {
            htmlcode( 'repair e2node', $new_e2node ) if ($movedsomething);
            $old_e2node = getNodeById( $old_e2node->{'node_id'} ) if $old_e2node;
            $new_e2node = getNodeById( $new_e2node->{'node_id'} ) if $new_e2node;
        }

    }

    # Generate input form
    $inputs_string = "\n" . htmlcode('openform');
    if ($writeup) {
        $inputs_string .= "\n" . $query->hidden( -name => 'old_writeup_id' );
        $inputs_string .= "\n<p>A writeup id has been supplied: " . $old_writeup_id . "</p>";
        $inputs_string .= "\n";

        if ( !$parent_node && !$success_reparent{ $writeup->{'node_id'} } ) {
            $inputs_string .= "\n<p>Writeup "
                . linkNode($writeup)
                . " is unparented!  But we can still move it."
                . " </p>";
        } else {
            # Default to moving to parent so the most common problem -- orphaned nodes -- can be easily fixed
            $query->param( 'new_e2node_id', $parent_node->{'title'} )
                unless $new_e2node_id;
        }
    }

    # Old node id
    if ( $old_writeup_id && !$writeup ) {
        $inputs_string .= "\n<p>Invalid writeup id provided.</p>";
    }
    if ( $old_e2node_id && !$old_e2node ) {
        $inputs_string .= "\n<p>Invalid e2node id provided.</p>";
    }

    if ( !$writeup ) {
        if ( !$old_e2node_id ) {
            $inputs_string .= "\n<p>Please provide the node id (or title) of the e2node from which we will be moving.</p>";
        } else {
            $inputs_string .= "\n<p>Old node id:<br>";
        }
        $inputs_string .= "\n\t" . $query->textfield( -name => 'old_e2node_id' );
        if ($old_e2node) {
            $inputs_string .= " (Currently: " . linkNode($old_e2node) . ")</p>";
        }

    }

    # New node id
    if ( $new_e2node_id && !$new_e2node && $new_e2node_id =~ /\D/ ) {
        $inputs_string .= "\n\n<p>Invalid new node title provided.</p>";
    } elsif ( $new_e2node_id && !$new_e2node ) {
        $inputs_string .= "\n\n<p>Invalid new node id provided.</p>";
    }

    if ( !$new_e2node ) {
        $inputs_string .= "\n\n<p>Please input a node title or id into which we will move the writeup(s):<br>";
    } else {
        $inputs_string .= "\n\n<p>New node id (or title) for the writeups:<br>";
    }
    $inputs_string .= "\n\t" . $query->textfield( -name => 'new_e2node_id' );

    if ($new_e2node) {
        $inputs_string .= " (Currently: " . linkNode($new_e2node) . ")</p>";
    }

    # List the writeups available to move
    $selection_string .= "\n";

    my $list_writeups = sub {

        my ( $list_node, $mandatory_node ) = @_;
        return unless $list_node || $mandatory_node;
        my $mandatory_node_id = undef;
        $mandatory_node_id = $mandatory_node->{'node_id'} if $mandatory_node;

        my $group = [];
        push( @$group, @{ $list_node->{'group'} } ) if $list_node && $list_node->{'group'};

        # Add writeup to the group if it's not already there so we can reparent unparented writeups
        if ( $mandatory_node && !( grep { $_ == $mandatory_node_id } @$group ) ) {
            push( @$group, $mandatory_node_id );
            $selection_string .= "\n<p>The target writeup "
                . linkNode($mandatory_node)
                . " was not found in "
                . linkNode($list_node)
                . "'s nodegroup. "
                . " You may want to move the writeup into the node to fix this.</p>"
                if $list_node;
        }

        if ( $group && scalar @$group ) {
            $selection_string .= "\n<ul>";
            my $check_all = $query->param('reparent_all');
            foreach my $move_writeup_id (@$group) {
                my $list_writeup = $getNodeByNameOrId->( $move_writeup_id, 'writeup' );
                if ($list_writeup) {
                    my $checked = ( $writeup && $move_writeup_id == $writeup->{node_id} );
                    my $saveAE  = $query->autoEscape();
                    $query->autoEscape(0);
                    my $label = "\n\t"
                        . linkNode($list_writeup)
                        . "\n\t by "
                        . linkNode( getNodeById( $list_writeup->{'author_user'} ) )
                        . "\n\t (id = $move_writeup_id)";
                    $selection_string .= "\n\t<li>"
                        . $query->checkbox(
                        -name    => "reparent_$move_writeup_id",
                        -value   => '1',
                        -checked => $check_all || $checked,
                        -label   => $label
                        )
                        . "</li>";
                    $query->autoEscape($saveAE);
                } else {
                    $selection_string .= "\n\t<li>$move_writeup_id does not appear to be a valid writeup id!";
                    $selection_string .= linkNode($list_node) . " may have a bad group.</li>"
                        if $list_node;;
                }
            }
            $selection_string .= "\n</ul>";
        } elsif ($list_node) {
            $selection_string .= "\n<p>" . linkNode($list_node) . " is a nodeshell.</p>";
        }

    };

    # Don't force listing of writeup if we just did a reparent
    $writeup = undef if ( $writeup && $success_reparent{ $writeup->{'node_id'} } );

    # List writeups in both source and destination node
    $list_writeups->( $old_e2node, $writeup );
    if ( $new_e2node && ( !$old_e2node || $old_e2node->{'node_id'} != $new_e2node->{'node_id'} ) ) {
        $selection_string .= "\n<hr>\n" if $old_e2node || $writeup;
        $selection_string .= "<p>Destination node: " . linkNode($new_e2node) . "</p>";
        $list_writeups->($new_e2node);
    }

    # Close form
    $selection_string .= "\n<br>" . htmlcode('closeform');

    return ( $inputs_string . $selection_string . $feedback_string
            . "<p> Try "
            . linkNode( getNode( 'Klaproth Van Lines', 'restricted_superdoc' ) )
            . " for bulk moves. Certain conditions apply.</p>" );
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

sub teddisms_generator
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $str = undef;
    my $i   = undef;

    $str = "<html><body><big><big><big><big><big><big><big><big><big><big><b><i>";

    my @noun   = ( "NUN", "NUN", "NUN", "NUN", "NUN", "CHRIST", "POWERHOOKER", "CUNT", "PORN", "COCK", "CRUNCH", "POOP", "JEW", "FUCK", "FUCK", "FUCK", "FUCK", "FUCK", "FUCK", "SHIT", "SHIT", "SHIT", "SHIT", "BRIT", "FLANNEL", "CRAP", "TIT", "SLUT", "PISS", "DICK", "ASS", "PUBIC", "SIDE", "CHALLA", "COMMA", "BLING", "ASS", "TURD", "GOD" );
    my @verb   = ( "SHITT", "FUCK", "GAGG", "TAPP", "SLAPP", "BURN", "PISS", "LICK", "CRAPP", "BLAST", "MUNCH" );
    my @phrase = ("UNRELENTING FUCKTARD");

    $i = int( rand 10 );
    if ( 5 == $i ) {
        $str .= $noun[ rand scalar(@noun) ] . $verb[ rand scalar(@verb) ] . "ING " . $noun[ rand scalar(@noun) ];
    }
    elsif ( 4 == $i ) {
        $str .= $noun[ rand scalar(@noun) ] . $noun[ rand scalar(@noun) ] . $verb[ rand scalar(@verb) ] . "ER";
    }
    elsif ( 3 == $i ) {
        $str .= $noun[ rand scalar(@noun) ] . $verb[ rand scalar(@verb) ] . "ING " . $noun[ rand scalar(@noun) ] . $verb[ rand scalar(@verb) ] . "ER";
    }
    elsif ( 2 == $i ) {
        $str .= $phrase[ rand scalar(@phrase) ];
    }
    else {
        $str .= $noun[ rand scalar(@noun) ] . $verb[ rand scalar(@verb) ] . "ING " . $noun[ rand scalar(@noun) ] . $verb[ rand scalar(@verb) ] . "ER";
    }

    $str .= "!</i></b></big></big></big></big></big></big></big></big></big></big></body></html>\n";
    return $str;
}

sub voting_oracle
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $cnt         = undef;
    my $upcnt       = undef;
    my $total       = undef;
    my $percent     = undef;
    my $wus         = undef;
    my $uppercent   = undef;
    my $webbyWus    = undef;
    my $wuspercent  = undef;

    return '' if $APP->isGuest($USER);

    $cnt   = $DB->sqlSelect( "count(*)", "vote", "voter_user=$USER->{node_id} and weight between -1 and 1" );
    $upcnt = $DB->sqlSelect( "count(*)", "vote", "voter_user=$USER->{node_id} and weight=1" );

    if ( $cnt == 0 ) {
        return "..thou art too young yet. Come back soon." if $APP->getLevel($USER) == 0;
        return "Thou hast grown, but are still yet a man. Prove thy judgment!";
    }

    $total      = $DB->sqlSelect( "count(*)", "vote" );
    $percent    = sprintf( "%.4f", 100 * ( $cnt / $total ) );
    $wus        = $DB->sqlSelect( "count(*)", "writeup" );
    $uppercent  = sprintf( "%.3f", 100 * ( $upcnt / $cnt ) );
    $webbyWus   = $DB->sqlSelect( "count(*)", "node", "type_nodetype=117 and author_user=176726" );
    $wus        -= $webbyWus;
    $wuspercent = sprintf( "%.3f", 100 * ( $cnt / $wus ) );

    return "Thou hast cast $cnt votes... $percent% of the judgements made of all time, across $wuspercent% of all votable writeups. Of these, $uppercent% are upvotes.";
}

sub recent_registry_entries
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $csr    = undef;
    my $labels = undef;
    my $rows   = undef;
    my $ref    = undef;
    my $data   = undef;
    my $comments = undef;

    return "...would be shown here if you logged in." if $APP->isGuest($USER);

    $csr = $DB->sqlSelectMany( '*', 'registration', '', 'ORDER BY tstamp DESC LIMIT 100' )
        || return 'SQL Error (prepare).  Please notify a [coder]';

    $labels = [ 'Registry', 'User', 'Data', 'Comments', 'Profile?' ];
    while ( $ref = $csr->fetchrow_hashref() ) {
        $data     = $ref->{data};
        $comments = $ref->{comments};

        $data     = $APP->parseAsPlainText($data);
        $comments = $APP->parseAsPlainText($comments);

        push @$rows,
            {
            'Registry'  => linkNode( $ref->{for_registry} ),
            'User'      => linkNode( $ref->{from_user} ),
            'Data'      => $data,
            'Comments'  => ( $comments ? $comments : '&nbsp;' ),
            'Profile?'  => [ 'No', 'Yes' ]->[ $ref->{in_user_profile} ],
            }
            if ( linkNode( $ref->{for_registry} ) );
    }

    return $APP->buildTable( $labels, $rows, 'class="registries"', 'center' );
}

sub registry_information
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $csr    = undef;
    my $labels = undef;
    my $rows   = undef;
    my $ref    = undef;

    return "You'd see something here if you had an account." if $APP->isGuest($USER);

    $csr = $DB->sqlSelectMany( '*', 'registration', "from_user=$USER->{user_id}" )
        || return "SQL Problem.  Please notify a [coder].";

    $labels = [ 'Registry', 'Data', 'Comments', 'Profile?' ];
    while ( $ref = $csr->fetchrow_hashref() ) {
        push @$rows,
            {
            'Registry'  => linkNode( $ref->{for_registry} ),
            'Data'      => $APP->htmlScreen( $ref->{data} ),
            'Comments'  => $APP->htmlScreen( $ref->{comments} ),
            'Profile?'  => [ 'No', 'Yes' ]->[ $ref->{in_user_profile} ]
            };
    }

    if ($rows) {
        return "<p>To add more registry entries, check out [The Registries[superdoc]].</p>"
            . $APP->buildTable( $labels, $rows );
    }
    else {
        return '<div style="text-align:center;font-weight:bold;margin:20px;'
            . "You haven't added your data to any registries yet.<br>"
            . "To add some, visit [The Registries[superdoc]]."
            . "</div>";
    }
}

sub the_registries
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $csr = undef;
    my $str = undef;
    my $ref = undef;
    my $id  = undef;

    return "...first, you'd better log in." if $APP->isGuest($USER);

    $csr = $DB->sqlSelectMany(
        'registry.registry_id',
        'registry, registration WHERE registry.registry_id = registration.for_registry GROUP BY registration.for_registry',
        '', 'ORDER BY registration.tstamp DESC LIMIT 100'
    ) || return 'SQL Error (prepare).  Please notify a [coder]';

    $str = "<ul>";
    while ( $ref = $csr->fetchrow_hashref() ) {
        $id = $ref->{registry_id};
        $str .= "<li>" . linkNode($id) . "</li>";
    }
    $str .= "</ul>";
    $str .= "<p>(Registries are listed in order of most recent entry)</p>";

    return $str;
}

sub message_outbox
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $str          = undef;
    my $spyon        = undef;
    my $isRoot       = undef;
    my $bots         = undef;
    my $grandtotal   = undef;
    my $spystring    = undef;
    my $authoruser   = undef;
    my $sqlWhere     = undef;
    my $showFilters  = undef;
    my $csr          = undef;
    my $paginationLinks = undef;
    my $totalmsgs    = undef;
    my $firstmsg     = undef;
    my $lastmsg      = undef;
    my $colHeading   = undef;
    my $MSG          = undef;
    my $text         = undef;
    my $t            = undef;

    return "<p>If you had an account, you could send messages.</p>"
        if $APP->isGuest($USER);

    # options
    $str = "(Also see: [Message Inbox])"
        . htmlcode( 'openform', 'message_outbox_form' )
        . '<input type="hidden" name="op" value="message_outbox">'
        . $query->hidden('perpage')
        . $query->hidden( 'sexisgood', '1' )    #so auto-VARS changing works
        . $query->fieldset(
        $query->legend('Options')
            . 'Show only archived/unarchived messages: '
            . htmlcode( 'varsComboBox', 'msgoutboxUnArc,0, 0,all, 1,unarchived, 2,archived' )
        );

    $spyon  = $query->param('spy_user');
    $isRoot = $APP->isAdmin($USER);
    $bots   = getVars( getNode( 'bot inboxes', 'setting' ) ) if $isRoot or $spyon;

    # show alternate user account's messages
    $spystring = '';
    if ($isRoot) {
        my @names = sort { lc($a) cmp lc($b) } keys(%$bots);
        unshift @names, $USER->{title};

        $spystring = $query->label( 'Message Outbox for: '
                . $query->popup_menu(
                -name   => 'spy_user',
                values => \@names
                ) );
    }

    $authoruser = 0;
    if ($spyon) {
        my $u = getNode( $spyon, 'user' );
        if ($u) {
            my $okUg = getNode( $bots->{ $u->{title} }, 'usergroup' );
            $authoruser = $u if $okUg and $DB->isApproved( $USER, $okUg );

        }
        elsif ($isRoot) {
            $spystring .= '<small>"' . $query->escapeHTML($spyon) . '" is not a user</small>';
        }
    }

    $str .= $query->p($spystring) if $spystring;
    $authoruser = ( $authoruser || $USER )->{node_id};

    # start building SQL WHERE string
    $sqlWhere = "author_user=$authoruser";

    #show archived/unarchived things
    $sqlWhere .= ( '', ' AND archive=0', ' AND archive!=0' )[ $VARS->{msgoutboxUnArc} ];

    $showFilters = ( '', ' unarchived', ' archived' )[ $VARS->{msgoutboxUnArc} ];

    $grandtotal ||= $DB->sqlSelect( "count(*)", "message_outbox", "author_user=$authoruser" );

    # provoke jump to last page:
    $query->param( 'page', 1000000000 ) unless $query->param('page');

    # get messages
    ( $csr, $paginationLinks, $totalmsgs, $firstmsg, $lastmsg ) = htmlcode(
        'show paged content', 'message_outbox.*', "message_outbox ", "$sqlWhere",
        'ORDER BY message_id
        LIMIT 100',    # can be overridden by 'perpage' parameter
        0,                     # no instructions, so it doesn't 'show' but returns cursor
        noform => 1            # 'go to page' box not wrapped in form
    );

    # display
    $colHeading = '<tr><th align="left">delete</th><th>send time</th>
    <th colspan="2" align="right">&#91;un&#93;Archive</th></tr>';

    $str .= "$paginationLinks
    <table>
    $colHeading" if $totalmsgs;

    while ( $MSG = $csr->fetchrow_hashref ) {
        $text = $MSG->{msgtext};

        $text =~ s/\s+\\n\s+/<br>/g;    # replace literal '\n' with HTML breaks

        # delete box
        $str .= qq'<tr class="privmsg"><td>'
            . $query->checkbox(
            -name   => 'deletemsg_' . $MSG->{message_id},
            value   => 'yup',
            valign  => 'top',
            label   => '',
            class   => 'delete'
            ) . '</td>';

        # time sent
        $t = $MSG->{tstamp};
        $str .= '<td><small>&nbsp;'
            . substr( $t, 0,  4 ) . '.'
            . substr( $t, 5,  2 ) . '.'
            . substr( $t, 8,  2 )
            . '&nbsp;at&nbsp;'
            . substr( $t, 11, 2 ) . ':'
            . substr( $t, 14, 2 )
            . '</small></td>';

        # message text
        $str .= "<td> $text</td>";

        # archive box
        $str .= '<td><tt>' . ( $MSG->{archive} ? 'A' : '&nbsp;' ) . '</tt>'
            . $query->checkbox(
            -name  => ( $MSG->{archive} ? 'un' : '' ) . "archive_$MSG->{message_id}",
            value  => 'yup',
            label  => '',
            class  => 'archive'
            ) . "</td>";

        # close table row
        $str .= "</tr>\n";
    }

    # summary report
    unless ( $totalmsgs
        || $VARS->{msgoutboxUnArc} == 2    # archived only
        || $authoruser != $USER->{node_id} )
    {
        #no messages showing
        $showFilters = "<em>You may feel lonely.</em>
        <small>(But you do have $grandtotal sent messages all together)</small>"
            if $grandtotal;
    }
    else {
        $str .= $colHeading if $lastmsg - $firstmsg > 10;
        $str .= '</table>' if $totalmsgs;

        $showFilters =~ s/messages/message/ if $totalmsgs == 1;
        $showFilters = ( $authoruser == $USER->{node_id} ? 'You have ' : linkNode($authoruser) . ' has ' )
            . ( ( $totalmsgs == 0 ) ? ("no") : $totalmsgs )
            . $showFilters
            . ' sent messages';
        $showFilters .= ". ($grandtotal all together)" if $totalmsgs != $grandtotal;
    }

    $str .= $query->p($showFilters);

    # form manipulation buttons
    $str .= $paginationLinks
        . $query->p(
        $query->reset('Clear All') . q!
    <input type="button" value="Delete All"
        onclick="$('.delete').each(function(){this.checked=true;});">
    <input type="button" value="Archive All"
        onclick="$('.archive&#91;name^=archive]').each(function(){this.checked=true;});">
    <input type="button" value="Unarchive All"
        onclick="$('.archive&#91;name^=unarchive]').each(function(){this.checked=true;});">!
        );

    return $str . ' ' . $query->submit( 'message_outbox update', 'submit' ) . $query->end_form();
}

sub site_trajectory
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $monthsago  = undef;
    my $sec        = undef;
    my $min        = undef;
    my $hour       = undef;
    my $mday       = undef;
    my $month      = undef;
    my $year       = undef;
    my $wday       = undef;
    my $yday       = undef;
    my $isdst      = undef;
    my $strMonth   = undef;
    my $str        = undef;
    my $strDate    = undef;
    my $limit      = undef;
    my $wucnt      = undef;
    my $usercnt    = undef;
    my $coolcnt    = undef;

    $monthsago = 1;
    ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) = gmtime(time);
    $year += 1900;

    $str = "<table>\n<tr>\n<th>Month to</th>\n<th colspan='2'>New writeups (surviving, not hidden)</th>\n<th colspan='2'>New users</th>\n<th colspan='2'>C!s spent</th>\n<th title='ratio of cools to new writeups'>C!:NW</th></tr>";
    $monthsago = 1;

    while ( $year > 2007 ) {
        $strMonth = ( $month + 1 ) . '';
        if ( length($strMonth) == 1 ) {
            $strMonth = "0" . $strMonth;
        }
        $strDate = $year . "-" . $strMonth . "-01";
        $limit =
              'type_nodetype='
            . getId( getType('writeup') )
            . " and publishtime >= '"
            . $strDate
            . "' and publishtime < DATE_ADD('"
            . $strDate
            . "',INTERVAL 1 MONTH) and writeup.notnew=0";

        $wucnt = $DB->sqlSelect( 'count(*)', 'node JOIN writeup on writeup.writeup_id=node.node_id', $limit );

        $limit =
              'type_nodetype='
            . getId( getType('user') )
            . " and createtime >= '"
            . $strDate
            . "' and createtime < DATE_ADD('"
            . $strDate
            . "',INTERVAL 1 MONTH)";

        $usercnt = $DB->sqlSelect( 'count(*)', 'node', $limit );

        $limit = "tstamp >= '" . $strDate . "' and tstamp < DATE_ADD('" . $strDate . "',INTERVAL 1 MONTH)";

        $coolcnt = $DB->sqlSelect( 'count(*)', 'coolwriteups', $limit );

        $str .= "\n<tr>";
        $str .= '<td class="DateLabel">';
        if ( $month == 0 ) {
            $str .= '<b>' . ( $month + 1 ) . '/' . ($year) . '</b>';
        }
        else {
            $str .= ( $month + 1 ) . '/' . ($year);
        }
        $str .= '</td>';

        $str .=
              "\n\t<td>$wucnt</td>\n\t<td><span class='bar' style='padding-right:"
            . ( $wucnt / 45 )
            . "px;'>&nbsp;</span></td>\n\t<td>$usercnt</td>\n\t<td><span class='bar' style='padding-right:"
            . ( $usercnt / 45 )
            . "px;'>&nbsp;</span></td>\n\t<td>$coolcnt</td>\n\t<td><span class='bar' style='padding-right:"
            . ( $coolcnt / 45 )
            . "px;'>&nbsp;</span></td>";
        $str .= "\n\t<td>" . sprintf( "%.2f", $coolcnt / $wucnt ) . "</td>" if ( $wucnt > 0 );
        $str .= "</tr>";

        $month--;
        if ( $month < 0 ) {
            $month = 11;
            $year--;
        }
        $monthsago++;
    }

    $str .= "\n</table>";

    return $str;
}

sub squawkbox
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $uid          = undef;
    my $isCoolPerson = undef;
    my $oldroom      = undef;
    my $str          = undef;
    my $MSGOP        = undef;
    my $add_room     = undef;
    my @rooms        = ();
    my $sqrms        = undef;
    my $RT           = undef;
    my $msgcsr       = undef;

    $uid          = $USER->{node_id};
    $isCoolPerson = $APP->isChanop($USER);

    return "um, no" if $APP->isGuest($USER);

    return "Sorry, this is now locked except for [gods|admins] and [chanops]."
        unless $isCoolPerson;

    $VARS->{squawk_rooms} ||= "0";
    $VARS->{squawk_talk}  ||= "0";
    $VARS->{squawk_talk} = $query->param("talkin")
        if ( $query->param("talkin") or $query->param("talkin") eq "0" );

    $oldroom = $USER->{in_room};
    $USER->{in_room} = $VARS->{squawk_talk};
    $str = '';

    # here's where the magic happens
    $MSGOP = getNode( "message", "opcode" );
    Everything::Delegation::opcode::message( $DB, $query, $MSGOP, $USER, $VARS, $PAGELOAD, $APP )
        if ( $query->param("squawk") );
    $query->param( "message", "" );

    $USER->{in_room} = $oldroom;

    $add_room = getNodeById( scalar $query->param("add_room") );
    $add_room = {
        "node_id"       => "0",
        "type_nodetype" => getId( getType("room") )
        }
        if $query->param("add_room") eq "0";

    if ( $add_room and $add_room->{type_nodetype} = getId( getType("room") ) )
    {
        $VARS->{squawk_rooms} .= "," . getId($add_room)
            if ( $add_room and $APP->canEnterRoom( $add_room, $USER, $VARS ) );
    }

    if ( $query->param("showaddrooms") )
    {
        my $csr = $DB->sqlSelectMany( "node_id", "node",
            "type_nodetype=" . getId( getType("room") ) );

        while ( my $row = $csr->fetchrow_hashref )
        {
            my $N = getNodeById( $row->{node_id} );
            push @rooms, $N if $N;
        }

        @rooms = sort { lc( $a->{title} ) cmp lc( $b->{title} ) } @rooms;
        unshift @rooms, { node_id => "0", title => "outside" };

        $str .= htmlcode("openform");
        $str .= "<select name=\"add_room\">";
        foreach (@rooms)
        {
            $str .= "<option value=\"$_->{node_id}\">$_->{title}</option>";
        }
        $str .= "</select>";
        $str .= "<input type=\"submit\" value=\"Add Room\"></form>";
        $str .= "<br><br>";
    }
    else
    {
        $str .= htmlcode("openform");
        $str .= "<input type=\"hidden\" name=\"showaddrooms\" value=\"1\">";
        $str .= "<input type=\"submit\" value=\"Add Rooms\">";
        $str .= "</form>";
    }

    $sqrms = {};
    foreach ( split( ",", $VARS->{squawk_rooms} ) )
    {
        $sqrms->{$_} = 1;
    }

    foreach ( my @params = $query->param )
    {
        next unless $_ =~ /^unsquawk_(\d+)$/;
        delete $sqrms->{$1};
    }

    $VARS->{squawk_rooms} = join ",", keys %$sqrms;
    return $str unless ( keys %$sqrms > 0 );

    $str .= htmlcode("openform");
    $str .= "<table>";
    $str .= "<tr>";
    $str .= "<td width=\"100\"><strong>Room</strong></td>";
    $str .= "<td width=\"150\"><strong>Remove Watch</strong></td>";
    $str .= "<td width=\"150\"><strong>Talk</strong></td>";
    foreach ( sort { $a <=> $b } keys %$sqrms )
    {
        my $room = getNodeById($_);
        $room = {
            title          => "outside",
            node_id        => "0",
            type_nodetype  => getId( getType("room") )
            }
            if ( $_ == 0 );
        next unless $room;
        $str .= "<tr>";
        $str .= "<td>"
            . ( ( $_ == 0 ) ? ("outside") : ( linkNode($room) ) )
            . "</td>";
        $str
            .= "<td><input type=\"checkbox\" name=\"unsquawk_$room->{node_id}\"></td>";
        $str
            .= "<td><input type=\"radio\" value=\"$room->{node_id}\" name=\"talkin\""
            . ( ( $VARS->{squawk_talk} == $room->{node_id} ) ? (" CHECKED ") : ("") )
            . "></td>";
        $str .= "</tr>";
    }
    $str .= "</table>";
    $str .= "<br>";
    $str .= "<p align=\"center\"><hr width=\"200\"></p>";

    $RT = getVars( getNode( "room topics", "setting" ) );
    $VARS->{squawk_talk} ||= 0;
    $str
        .= "<p align=\"center\"><table><tr><td>"
        . $RT->{ $VARS->{squawk_talk} }
        . "</td></tr></table></p>";

    $str .= "<br>";
    $str .= "<table>";
    $str .= "<tr>";
    $str .= "<td width=\"75\"><strong>Where</strong></td>";
    $str .= "<td width=\"50\"><strong>When</strong></td>";
    $str .= "<td width=\"100\"><strong>Who</strong></td>";
    $str .= "<td width=\"80%\"><strong>What</strong></td>";
    $str .= "</tr>";

    $msgcsr = $DB->sqlSelectMany(
        "*", "message",
        "("
            . join( " or ", map { " room='$_' " } keys %$sqrms )
            . ") and for_user=0 and unix_timestamp(now())-unix_timestamp(tstamp) < 300 order by tstamp asc"
    );

    while ( my $msg = $msgcsr->fetchrow_hashref )
    {
        my $room = getNodeById( $msg->{room} );
        $room = {
            title         => "outside",
            node_id       => "0",
            type_nodetype => getId( getType("room") )
            }
            if ( $msg->{room} == 0 );
        next unless $room;

        my $user = getNodeById( $msg->{author_user} );
        next unless $user;

        my $msgtext = encodeHTML( $msg->{msgtext} );
        if ( $msgtext =~ /^\/me (.*)$/ )
        {
            $msgtext = "<em>$1</em>";
        }

        $str .= "<tr>";
        $str
            .= "<td>"
            . (
            ( $msg->{room} == $VARS->{squawk_talk} )
            ? ("<strong>$room->{title}</strong>")
            : ("($room->{title})")
            ) . "</td>";
        $str
            .= "<td><small>"
            . htmlcode( 'parsetimestamp', "$msg->{tstamp},2" )
            . "</small></td>";
        $str .= "<td>&lt;" . linkNode($user) . "&gt;</td>";
        $str .= "<td>$msgtext</td>";
        $str .= "</tr>";
    }
    $str .= "</table>";
    $str .= "<br><br>";
    $str .= "<input type=\"text\" width=\"400\" name=\"message\" maxlength=\"255\">";
    $str .= "<input type=\"hidden\" name=\"squawk\" value=\"1\">";
    $str .= "<input type=\"submit\" value=\"talk\">";
    $str .= "</form>";

    return $str;
}

sub squawkbox_update
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $oldroom       = undef;
    my $str           = undef;
    my $MSGOP         = undef;
    my $add_room      = undef;
    my @rooms         = ();
    my $sqrms         = undef;
    my $RT            = undef;
    my $ignorelist    = undef;
    my @ignorelistlist = ();
    my $ignoreStr     = undef;
    my $searchcriteria = undef;
    my $msgcsr        = undef;

    return "um, no" if $APP->isGuest($USER);

    $VARS->{squawk_rooms} ||= "0";
    $VARS->{squawk_talk}  ||= "0";
    $VARS->{squawk_talk} = $query->param("talkin")
        if ( $query->param("talkin") or $query->param("talkin") eq "0" );

    $oldroom = $USER->{in_room};
    $USER->{in_room} = $VARS->{squawk_talk};
    $str = '';

    # here's where the magic happens
    $MSGOP = getNode( "message", "opcode" );
    Everything::Delegation::opcode::message( $DB, $query, $MSGOP, $USER, $VARS, $PAGELOAD, $APP )
        if ( $query->param("squawk") );
    $query->param( "message", "" );

    $USER->{in_room} = $oldroom;

    $add_room = getNodeById( $query->param("add_room") );
    $add_room = {
        "node_id"       => "0",
        "type_nodetype" => getId( getType("room") )
        }
        if $query->param("add_room") eq "0";

    if ( $add_room and $add_room->{type_nodetype} = getId( getType("room") ) )
    {
        $VARS->{squawk_rooms} .= "," . getId($add_room)
            if ( $add_room and $APP->canEnterRoom( $add_room, $USER, $VARS ) );
    }

    if ( $query->param("showaddrooms") )
    {
        my $csr = $DB->sqlSelectMany( "node_id", "node",
            "type_nodetype=" . getId( getType("room") ) );

        while ( my $row = $csr->fetchrow_hashref )
        {
            my $N = getNodeById( $row->{node_id} );
            push @rooms, $N if $N;
        }

        @rooms = sort { lc( $a->{title} ) cmp lc( $b->{title} ) } @rooms;
        unshift @rooms, { node_id => "0", title => "outside" };

        $str .= htmlcode("openform");
        $str .= "<select name=\"add_room\">";
        foreach (@rooms)
        {
            $str .= "<option value=\"$_->{node_id}\">$_->{title}</option>";
        }
        $str .= "</select>";
        $str .= "<input type=\"submit\" value=\"Add Room\"></form>";
        $str .= "<br><br>";
    }
    else
    {
        $str .= htmlcode("openform");
        $str .= "<input type=\"hidden\" name=\"showaddrooms\" value=\"1\">";
        $str .= "<input type=\"submit\" value=\"Add Rooms\">";
        $str .= "</form>";
    }

    $sqrms = {};
    foreach ( split( ",", $VARS->{squawk_rooms} ) )
    {
        $sqrms->{$_} = 1;
    }

    foreach ( my @params = $query->param )
    {
        next unless $_ =~ /^unsquawk_(\d+)$/;
        delete $sqrms->{$1};
    }

    $VARS->{squawk_rooms} = join ",", keys %$sqrms;
    return $str unless ( keys %$sqrms > 0 );

    $str .= htmlcode("openform");
    $str .= "<table>";
    $str .= "<tr>";
    $str .= "<td width=\"100\"><strong>Room</strong></td>";
    $str .= "<td width=\"150\"><strong>Remove Watch</strong></td>";
    $str .= "<td width=\"150\"><strong>Talk</strong></td>";
    foreach ( sort {$a <=> $b} keys %$sqrms )
    {
        my $room = getNodeById($_);
        $room = {
            title         => "outside",
            node_id       => "0",
            type_nodetype => getId( getType("room") )
            }
            if ( $_ == 0 );
        next unless $room;
        $str .= "<tr>";
        $str .= "<td>"
            . ( ( $_ == 0 ) ? ("outside") : ( linkNode($room) ) )
            . "</td>";
        $str
            .= "<td><input type=\"checkbox\" name=\"unsquawk_$room->{node_id}\"></td>";
        $str
            .= "<td><input type=\"radio\" value=\"$room->{node_id}\" name=\"talkin\""
            . ( ( $VARS->{squawk_talk} == $room->{node_id} ) ? (" CHECKED ") : ("") )
            . "></td>";
        $str .= "</tr>";
    }
    $str .= "</table>";
    $str .= "<br>";
    $str .= "<p align=\"center\"><hr width=\"200\"></p>";

    $RT = getVars( getNode( "room topics", "setting" ) );
    $VARS->{squawk_talk} ||= 0;
    $str
        .= "<p align=\"center\"><table><tr><td>"
        . $RT->{ $VARS->{squawk_talk} }
        . "</td></tr></table></p>";

    $str .= "<br>";
    $str .= "<table>";
    $str .= "<tr>";
    $str .= "<td width=\"75\"><strong>Where</strong></td>";
    $str .= "<td width=\"50\"><strong>When</strong></td>";
    $str .= "<td width=\"100\"><strong>Who</strong></td>";
    $str .= "<td width=\"100\"><strong>What</strong></td>";
    $str .= "</tr>";

    # Build ignore list and then get the messages
    $ignorelist = $DB->sqlSelectMany( 'ignore_node', 'messageignore',
        'messageignore_id=' . $USER->{user_id} );
    while ( my ($ignorelistu) = $ignorelist->fetchrow )
    {
        push @ignorelistlist, $ignorelistu;
    }
    $ignoreStr = join( ", ", @ignorelistlist );
    $searchcriteria
        = "("
        . join( " or ", map { " room='$_' " } keys %$sqrms )
        . ") and for_user=0 and unix_timestamp(now())-unix_timestamp(tstamp) < 300";
    $searchcriteria .= " and author_user not in ($ignoreStr)" if $ignoreStr;
    $searchcriteria .= " order by tstamp asc";

    $msgcsr = $DB->sqlSelectMany( "*", "message", $searchcriteria );

    while ( my $msg = $msgcsr->fetchrow_hashref )
    {
        my $room = getNodeById( $msg->{room} );
        $room = {
            title         => "outside",
            node_id       => "0",
            type_nodetype => getId( getType("room") )
            }
            if ( $msg->{room} == 0 );
        next unless $room;

        my $user = getNodeById( $msg->{author_user} );
        next unless $user;

        my $msgtext = encodeHTML( $msg->{msgtext} );
        if ( $msgtext =~ /^\/me (.*)$/ )
        {
            $msgtext = "<em>$1</em>";
        }

        $str .= "<tr>";
        $str
            .= "<td>"
            . (
            ( $msg->{room} == $VARS->{squawk_talk} )
            ? ("<strong>$room->{title}</strong>")
            : ("($room->{title})")
            ) . "</td>";
        $str
            .= "<td><small>"
            . htmlcode( 'parsetimestamp', "$msg->{tstamp},2" )
            . "</small></td>";
        $str .= "<td>&lt;" . linkNode($user) . "&gt;</td>";
        $str .= "<td>$msgtext</td>";
        $str .= "</tr>";
    }
    $str .= "</table>";
    $str .= "<br><br>";
    $str .= "<input type=\"text\" width=\"400\" name=\"message\" maxlength=\"255\">";
    $str .= "<input type=\"hidden\" name=\"squawk\" value=\"1\">";
    $str .= "<input type=\"submit\" value=\"talk\">";
    $str .= "</form>";

    return $str;
}

sub the_recommender
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $str = undef;

    # Static HTML from doctext
    $str = '<h4>What It Does</h4>

<ul>
<li>Takes the idea of [Do you C! what I C?] but pulls the user\'s bookmarks rather than C!s, so it\'s accessible to everyone.</li>
<li>Picks up to 100 things you\'ve bookmarked.</li>
<li>Finds everyone else who has cooled those things, then uses the top 20 of those (your "best friends.")</li>
<li>Finds the writeups that have been cooled by your "best friends" the most.</li>
<li>Shows you the top 10 from that list that you haven\'t voted on and have less than 10C!s.</li>
</ul>


';

    $str.=htmlcode('openform');
    $str.='<p>Or you can enter a user name to see what we think <em>they</em> would like:'.$query->textfield('cooluser', '', 15,30);
    $str.=htmlcode('closeform').'</p>';

    my $user_id = undef;
    my $user = undef;
    my $pronoun = undef;

    $user_id = $$USER{user_id};

    $user = $query->param('cooluser');
    $pronoun = 'You';
    if($user) {
        my $U = getNode($user, 'user');
        return $str . '<br />Sorry, no "'.encodeHTML($user).'" is found on the system!' unless $U;
        $user_id=$$U{user_id};
        $pronoun='They';
    }
    my $numCools = 100;
    my $numFriends = 20;
    my $numWriteups = 10;
    my $maxCools = $query->param('maxcools') || 10;

    my $linktype=getId(getNode('bookmark', 'linktype'));
    my $sqlstring = "links.from_node=$user_id AND links.linktype=$linktype order by rand() limit $numCools";
    my $coolList = $DB->sqlSelectMany("writeup.writeup_id", "links INNER JOIN writeup ON writeup.parent_e2node = links.to_node OR writeup.writeup_id = links.to_node", $sqlstring);

    return $str."$pronoun haven't bookmarked anything cool yet. Sorry" unless $coolList->rows;
    my @coolStr;

    while (my $c = $coolList->fetchrow_hashref) {
        push (@coolStr, $$c{writeup_id});
    }

    my $coolStr = join(',',@coolStr);

    my $userList = $DB->sqlSelectMany("count(cooledby_user) as ucount, cooledby_user","coolwriteups","coolwriteups_id in ($coolStr) and cooledby_user!=$user_id group by cooledby_user order by ucount desc limit $numFriends");

    my @userSet;

    return "$pronoun don't have any 'best friends' yet. Sorry." unless $userList->rows;

    while (my $u = $userList->fetchrow_hashref) {
        push (@userSet, $$u{cooledby_user});
    }
    my $userStr = join(',',@userSet);

    my $recSet = $DB->sqlSelectMany("count(coolwriteups_id) as coolcount, coolwriteups_id", "coolwriteups", "(select count(*) from coolwriteups as c1 where c1.coolwriteups_id = coolwriteups.coolwriteups_id and c1.cooledby_user=$user_id)=0 and (select author_user from node where node_id=coolwriteups_id)!=$user_id and cooledby_user in (".$userStr.") group by coolwriteups_id having coolcount>1 order by coolcount desc limit 100");

    my $count = undef;

    while (my $r = $recSet->fetchrow_hashref) {
        my $n = getNode($$r{coolwriteups_id});
        next if $APP->hasVoted($n, $USER);
        next if $$n{cooled} > $maxCools;
        next unless $n;
        $count++;
        $str .= linkNode($n)."<br />";
        last if ($count == $numWriteups);
    }

    return $str;
}

sub writeup_search
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my @start = Time::HiRes::gettimeofday;
    my $timeStr = undef;
    my $timeCount = 1;

    my $str = undef;

    $str .= $query->start_form("POST","http://everything2.com/title/Writeup%20Search",$query->script_name, "onSubmit='return fullText();'");

    my $default ='';
    my $lnid = getId($NODE);

    $str.= $query->textfield(-name => 'node',
        -id => 'node_search',
        -default => $default,
        -size => 28,
        -maxlength => 80);

    $str.='<input type="submit" name="searchy" value="search" />';
    $str.='<input type="hidden" name="lastnode_id" value="'.$lnid.'" />';
    $str.=$query->end_form;

    my $title = $query->param('node');
    my $lnode = $query->param('lastnode_id');
    $lnode ||= '0';

    return htmlcode('randomnode','Psst! Over here!') unless $title;
    $str .= 'Here\'s the stuff we found when you searched for "'.$title.'"';

    if($title =~ /^https?:\/\// ) {
        $title =~ s/'/&#39;/g;
        $title =~ s/,/&#44;/g;
        my $s = htmlcode('externalLinkDisplay',$title);
        if(length($s)) {
            $str .= ' <br>(this appears to be an external link: '.$s.'<br>';
            $str .= ' everything2 does not validate and is not responsible';
            $str .= ' for the contents of any external web page referenced';
            $str .= ' from this server.)';
        }
    }

    $str .= "\n\t<ul>";

    my $curType = undef;
    foreach my $ND (@{ $$NODE{group} }) {
        next unless canReadNode($USER, $ND);
        $curType = $$ND{type}{title};

        next unless $curType eq 'writeup';
        next unless $$ND{wrtype_writeuptype} == 1871559;

        if ( $APP->isGuest($USER) ){
            $str .= '<li>' . linkNode($ND, '', {lastnode_id=>0} );
        }
        else {
            $str .= '<li>' . linkNode($ND, '', {lastnode_id=>$lnode});
        }
        if($curType ne 'e2node'){
            $str .= " ($curType)";
        }

        $str .= "</li>\n";
    }

    $str .= "</ul>\n";

    $str .= htmlcode('e2createnewnode');

    return $str;
}

1;

# Functions to migrate - continuing additions

# Note: this file is getting very large. Adding remaining delegation functions systematically.


sub my_achievements
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    return "If you logged in, you could see what achievements you've earned here." if $APP->isGuest($USER);

    my $debugStr = '';
    my @debug = ();
    @debug = ($$USER{node_id}, 1) if $query -> param('debug');

    $debugStr .= htmlcode('achievementsByType', 'user', @debug);
    $debugStr .= htmlcode('achievementsByType', 'usergroup', @debug);
    $debugStr .= htmlcode('achievementsByType', 'miscellaneous', @debug);

    if (@debug){
        $debugStr .= htmlcode('achievementsByType', 'reputation', @debug);
        $debugStr .= htmlcode('achievementsByType', 'cool', @debug);
        $debugStr .= htmlcode('achievementsByType', 'vote', @debug);
        $debugStr .= htmlcode('achievementsByType', 'karma', @debug);
        $debugStr .= htmlcode('achievementsByType', 'experience', @debug);
        $debugStr .= htmlcode('achievementsByType', 'writeup', @debug);
    }

    my $achievementList = $DB->sqlSelectMany(
        'display, achievement_still_available, achieved_achievement'
        , "achievement LEFT OUTER JOIN achieved
            ON achieved_achievement=achievement_id
            AND achieved_user=$$USER{node_id}"
        , ''
        , 'ORDER BY achievement_type, subtype DESC'
    );

    my $aStr = undef;
    my $uStr = undef;
    my $aCount = 0;
    my $uCount = 0;

    while (my $a = $achievementList->fetchrow_hashref){
        if ($$a{achieved_achievement}){
            $aStr .= $query -> li($$a{display});
            $aCount++;
        }elsif($$a{achievement_still_available}){
            $uStr .= $query -> li($$a{display});
            $uCount++;
        }
    }

    my $totalAchievements = $aCount + $uCount;

    my $str = $query -> p("You have reached <strong>$aCount</strong> out of a total of
        <strong>$totalAchievements</strong> achievements:")
        .$query -> ul($aStr)
        .$query -> h3('Achievements Left To Reach')
        .$query -> ul($uStr);

    $str .= $debugStr if $debugStr && $DB -> isApproved($USER, getNode('edev', 'usergroup'));

    return $str;
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

sub new_logs_nodelet
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $str = '<p>Daylogs have long had an established place in the everything2 [nodegel], even if there is no general agreement about what that place is and if it should exist. Some hate them, some ignore them, some wouldn\'t miss them for the world.
</p>
<p>If you fall into (or even carefully skirt the [brink] of) this last category, the [New logs] nodelet is for you. It shows the last few writeups of type \'log\', whether or not they were posted hidden, and saves you nervous energy and the time you would otherwise spend feverishly checking the daylog nodes several times a day.
</p>
<p>To insert the [New logs] nodelet you can either use the new improved interface at [Nodelet Settings], or simply click on the Useful Button below, which will insert it right after [New Writeups].
</p>
' . htmlcode('openform') . '
<input type="hidden" name="op" value="movenodelet">
<input type="hidden" name="nodelet" value="1923735">
<input type="hidden" name="position" value="after263">
<input type="submit" value="Useful Button">
</form>';

    return $str;
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


sub old_writeup_settings {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = htmlcode('openform');
    $str .= '<p>This is the old header display section of [Writeup Settings], plus footer settings using the same syntax. This provides slightly greater control over the display than the radio-button-based selection interface that will be the default.

<h3>Writeup Header Display</h3>

<p>
This is where you can choose exactly what information to display in writeup headings. The easiest way to use this is use one of the given defaults, but if you\'re feeling brave, you can manually type in a coding sequence to specify what you want.
</p>

';

    # First code block - edev note
    $str .= '<p>edev note: this information is derived from [displayWriteupInfo].</p>' if $APP->isDeveloper($USER);

    # Second code block - header settings
    my $uid = getId($USER) || 0;
    return 'You may use this after you create an account.' if $APP->isGuest($USER);
    my $isRoot = $APP->isAdmin($USER);
    my $isCE = $APP->isEditor($USER);
    my $isEDev = $APP->isDeveloper($USER);

    my $maxLen = 127;

    local *cleanUp = sub {
        my $w = shift;
        return unless (defined $w) && length($w);
        $w = lc($w);
        $w =~ tr/a-z:,\\//cd; #only a few chars allowed
        $w = substr($w,0,$maxLen) if (length($w)>$maxLen); #only short space
        return $w;
    };

    my $v = 'wuhead'; #name in VARS

    my $newSpec;
    if($query->param('usedefault_default')) {
        delete $$VARS{$v};
    } else {
    foreach($query->param) {
        next unless /^usedefault_(.)$/;
        $query->param('sexisgood','submit'); #hack to make checkbox opts work
        if($query->param('hsdefault_'.$1)) {
            $newSpec = $query->param('hsdefault_'.$1);
            last;
        }
    }
    if(!(defined $newSpec)) {
        unless($newSpec=$query->param('headspec')) {
            $newSpec = $$VARS{$v};
        }
    }
    }
    $newSpec = cleanUp($newSpec);
    if((defined $newSpec) && length($newSpec)) {
        $$VARS{$v}=$newSpec;
    } else {
        delete $$VARS{$v};
        $newSpec = '';
    }
    $query->param('headspec',$newSpec);

    my $nl = "<br />\n";

    $query->param('hsdefault_b', 'l:type,l:author,c:kill,r:vote,r:cshort'); #bare
    $query->param('hsdefault_a', 'l:type,l:pseudoanon,c:kill,c:vote,c:cshort,r:dtcreate'); #pseudo-anonymous author
    $query->param('hsdefault_c', 'l:typeauthorprint,c:kill,c:vote,c:cshort,r:dtcreate'); #classic
    $query->param('hsdefault_f', 'l:typeauthorprint,c:kill,c:vote,r:dtcreate,\n,l:cfull,sendmsg,c:length,r:notnew,r:social'); #full

    $str .= $query->submit('usedefault_default','clear to default').$nl;
    $str .= $query->textfield('headspec','',80,$maxLen).$query->submit('sexisgood','custom').$nl;

    my $wuHead;

    my $testingMode = 0;

    $wuHead = $$VARS{wuhead};
    $$VARS{wuhead} = $query->param('headspec');
    $str.="<p>".htmlcode('displayWriteupInfo','178416')."</p><p>&nbsp;</p>" if $testingMode;

    $str .= $query->textfield('hsdefault_b','',80,$maxLen).$query->submit('usedefault_b','default: bare').$nl;

    $$VARS{wuhead} = $query->param('hsdefault_b');
    $str.="<p>".htmlcode('displayWriteupInfo','178418')."</p><p>&nbsp;</p>" if $testingMode;

    $str .= $query->textfield('hsdefault_c','',80,$maxLen).$query->submit('usedefault_c','default: classic').$nl;

    $$VARS{wuhead} = $query->param('hsdefault_c');
    $str.="<p>".htmlcode('displayWriteupInfo','178420')."</p><p>&nbsp;</p>" if $testingMode;

    $str .= $query->textfield('hsdefault_f','',80,$maxLen).$query->submit('usedefault_f','default: full').$nl;

    $$VARS{wuhead} = $query->param('hsdefault_f');
    $str.="<p>".htmlcode('displayWriteupInfo','178422')."</p><p>&nbsp;</p>" if $testingMode;

    $str .= $query->textfield('hsdefault_a','',80,$maxLen).$query->submit('usedefault_a','default: pseudo-anonymous author').$nl;

    $$VARS{wuhead} = $query->param('hsdefault_a');
    $str.="<p>".htmlcode('displayWriteupInfo','178424')."</p><p>&nbsp;</p>" if $testingMode;

    $$VARS{wuhead} = $wuHead;

    #more?

    $str .= '



<h3>Writeup Footer Display</h3>

<p>Please enter the word \'nothing\' in the \'custom\' box below if you wish for nothing to appear in your footer; if it is blank, E2 will assume you want the default setting.</p>


';

    # Third code block - footer settings
    $uid = getId($USER) || 0;
    return 'You may use this after you create an account.' if $APP->isGuest($USER);
    $isRoot = $APP->isAdmin($USER);
    $isCE = $APP->isEditor($USER);
    $isEDev = $APP->isDeveloper($USER);

    #return 'You need to be at least level 3 to use this.' unless $isCE || $isEDev || !($APP->getLevel($USER)<3);    #if level is changed, change votefoot also

    $maxLen = 127;

    local *cleanUp = sub {
        my $w = shift;
        return unless (defined $w) && length($w);
        $w = lc($w);
        $w =~ tr/a-z:,\\//cd; #only a few chars allowed
        $w = substr($w,0,$maxLen) if (length($w)>$maxLen); #only short space
        return $w;
    };

    $v = 'wufoot'; #name in VARS

    $newSpec = undef;
    if($query->param('usefootdefault_default')) {
        delete $$VARS{$v};
    } else {
    foreach($query->param) {
        next unless /^usefootdefault_(.)$/;
        $query->param('sexisgood','submit'); #hack to make checkbox opts work
        if($query->param('fsdefault_'.$1)) {
            $newSpec = $query->param('fsdefault_'.$1);
            last;
        }
    }
    if(!(defined $newSpec)) {
        unless($newSpec=$query->param('footspec')) {
            $newSpec = $$VARS{$v};
        }
    }
    }
    $newSpec = cleanUp($newSpec);
    if((defined $newSpec) && length($newSpec)) {
        $$VARS{$v}=$newSpec;
    } else {
        delete $$VARS{$v};
        $newSpec = '';
    }
    $query->param('footspec',$newSpec);

    $nl = "<br />\n";

    $query->param('fsdefault_b', 'l:type,l:author,c:kill,r:vote,r:cshort'); #bare
    $query->param('fsdefault_a', 'l:type,l:pseudoanon,c:kill,c:vote,c:cshort,r:dtcreate'); #pseudo-anonymous author
    $query->param('fsdefault_c', 'l:typeauthorprint,c:kill,c:vote,c:cshort,r:dtcreate'); #classic
    $query->param('fsdefault_f', 'l:typeauthorprint,c:kill,c:vote,r:dtcreate,\n,l:cfull,sendmsg,c:length,r:notnew,r:social'); #full

    $str .= $query->submit('usefootdefault_default','clear to default').$nl;
    $str .= $query->textfield('footspec','',80,$maxLen).$query->submit('sexisgood','custom').$nl;

    my $wufoot;

    $testingMode = 0;

    $wufoot = $$VARS{wufoot};
    $$VARS{wufoot} = $query->param('footspec');
    $str.="<p>".htmlcode('displayWriteupInfo','178416')."</p><p>&nbsp;</p>" if $testingMode;

    $str .= $query->textfield('fsdefault_b','',80,$maxLen).$query->submit('usefootdefault_b','default: bare').$nl;

    $$VARS{wufoot} = $query->param('fsdefault_b');
    $str.="<p>".htmlcode('displayWriteupInfo','178418')."</p><p>&nbsp;</p>" if $testingMode;

    $str .= $query->textfield('fsdefault_c','',80,$maxLen).$query->submit('usefootdefault_c','default: classic').$nl;

    $$VARS{wufoot} = $query->param('fsdefault_c');
    $str.="<p>".htmlcode('displayWriteupInfo','178420')."</p><p>&nbsp;</p>" if $testingMode;

    $str .= $query->textfield('fsdefault_f','',80,$maxLen).$query->submit('usefootdefault_f','default: full').$nl;

    $$VARS{wufoot} = $query->param('fsdefault_f');
    $str.="<p>".htmlcode('displayWriteupInfo','178422')."</p><p>&nbsp;</p>" if $testingMode;

    $str .= $query->textfield('fsdefault_a','',80,$maxLen).$query->submit('usefootdefault_a','default: pseudo-anonymous author').$nl;

    $$VARS{wufoot} = $query->param('fsdefault_a');
    $str.="<p>".htmlcode('displayWriteupInfo','178424')."</p><p>&nbsp;</p>" if $testingMode;



    $$VARS{wufoot} = $wufoot;

    #more?

    $str .= '





<p>Writeups will look a bit like this:</p>
<hr>

<div class=\'writeup\'>
<div class=\'writeup_title\'>
' . htmlcode('displayWriteupInfo', '10156') . '
</div>
<!-- This is a hack to stop formatting overflow - ascorbic-->
<table class="writeuptable"><tr><td><div class="writeup_text">
<p>Eno has been an enduring influence on music as well as modern art.  Taking cues from [John Cage], Eno created a genre called [ambient music].  He also produced excellent artists such as [David Bowie], the [Talking Heads], [Devo], [John Cale], [U2], [James] as well as pursuing side and solo projects at the same time.  Unfortunately, he also created [The Microsoft Sound]...</p>
</div></td></tr>


<!-- next 3 lines added Saturday, April 5, 2008 -->
<tr><td>
' . htmlcode('displayWriteupInfo', '10156') . '
</td></tr>


</table>
</div>



<hr>

<p>
To use one of the given defaults, press the button that describes the default you desire. If you want to make a minor change to one of the defaults, you can also edit it in any text box, but be sure to press the button next to the one you wish to use. After you submit a change, the top text box will have your current setting, which you can further customize. If the top area is blank, you are using the default display setting.
</p>

<p>
Are you seeing "<strong>unknown value</strong>" messages? This means you typed something in incorrectly. To try to fix it yourself, see which word it says is unknown, and correct the typing in the topmost text box below. If you aren\'t sure what is wrong, you can reset to one of the defaults by pressing one of default buttons.
</p>

<p>
If you decide to type in the setting, the following table describes what you may enter, and what it does. For example, if you enter<br /><br />
<code>l:author,c:vote,r:cshort</code><br /><br />
then at the top of every writeup you view will display the writeup\'s author to the left, voting area in the center, and some C! information to the right. Breaking it down, the first <code>l:</code> (lowercase L) says to make the next thing left-aligned. The <code>author</code> part says to display the writeup\'s author in that area. The <code>,</code> (comma) says start the next section, and the steps are repeated - <code>c:vote</code> to center the voting area, then <code>r:cshort</code> to display the "short" C! area to the right.<br />
<table border="1" cellspacing="0" cellpadding="3">
<tr><th>code</th><th>what it does</th></tr>

<tr><td><code>l:</code><var>section</var></td><td>makes the section left-aligned (this is a lowercase \'L\', not the number \'1\') (this is the default alignment)</td></tr>
<tr><td><code>c:</code><var>section</var></td><td>makes the section center-aligned</td></tr>
<tr><td><code>r:</code><var>section</var></td><td>makes the section right-aligned</td></tr>
<tr><td><code>,</code></td><td>start a new section on the same line</td></tr>
<tr><td><code>\\n</code></td><td>start a new line <small>(note: type this as a \'<code>\\</code>\' followed by an \'<code>n</code>\': this is <em>not</em> a newline character)<small></td></tr>

<tr><td><code>addto</code></td><td>Shows a link or a pop-up widget (depending on whether you have scripting enabled) to add a writeup to your bookmarks, a category or a usergroup page.</td></tr>
<tr><td><code>author</code></td><td>shows writeup\'s author; see also: <code>authoranon</code> and <code>pseudoauthor</code></td></tr>
<tr><td><code>authoranon</code></td><td>only shows writeup\'s author if it is yours, or you have voted on it; see also: <code>author</code> and <code>pseudoanon</code></td></tr>
<tr><td><code>bookmark</code></td><td>Shows a link to bookmark the individual writeup. This will only be displayed when viewing the entire e2node, not the individual writeup.</td></tr>
<tr><td><code>cfull</code></td><td>This shows full C! information, which is the number of C!s, and who gave them, but only when you\'re viewing a writeup by itself. If you\'re viewing the writeups with other ones, this acts just like  <code>cshort</code>. (To view a writeup by itself, follow the place/idea/thing/person link.)</td></tr>
<tr><td><code>cshort</code></td><td>This shows short C! information, which is the number of C!s. This is close to the original way C! information was shown.</td></tr>
<tr><td><code>dtcreate</code></td><td>shows date and time writeup was created</td></tr>
<tr><td><code>hits</code></td><td>shows the number of hits received since November, 2008</td></tr>
<tr><td><code>kill</code></td><td>shows if a writeup is marked for destruction';

    $str .= '; editor note: this also shows deletion checkboxes' if $APP->isEditor($USER);

    $str .= '</td></tr>
<tr><td><code>length</code></td><td>Shows the number of characters, and approximate number of words, in the writeup.</td></tr>
<tr><td><code>notnew</code></td><td>shows if the writeup was created hidden';

    $str .= '' unless $APP->isEditor($USER);
    $str .= '; note: this will only display if it is your writeup' unless $APP->isEditor($USER);

    $str .= '</td></tr>
<tr><td><code>pseudoanon</code></td><td>like <code>authoranon</code> (only shows writeup\'s author if it is yours, or you have voted on it), but anonymous text links to author\'s homenode, and the user\'s name appears if you hover the mouse cursor over the link; see also: <code>author</code> and <code>authoranon</code></td></tr>
<tr><td><code>sendmsg</code></td><td>Provides a text area where you can send the writeup\'s author a message. The area acts just like a normal private message (<tt>/msg</tt>), except you don\'t need to enter the /msg part, and the writeup\'s title is automatically prepended to your message. (This is mainly provided as an easier way to send the author a message, without having to bother with copying their name and writeup title.)</td></tr>
<tr><td><code>type</code></td><td>shows writeup type (idea/person/thing/idea/definition)</td></tr>
<tr><td><code>typeauthorprint</code></td><td>shows writeup type and author (this combination is commonly used, so it has its own code)</td></tr>
<tr><td><code>vote</code></td><td>shows voting area</td></tr>
<tr><td><code>social</code></td><td>shows social bookmarking buttons</td></tr>

</table>
</p>

<p>Don\'t understand what to do? Try following these steps:</p>
<ol>
<li>Press the "clear to default" button (this just makes sure you have the exact setup as what I\'m talking about). Your setting is now the default.</li>
<li>You can look at the visual examples provided below each textbox to give you an idea of what the different set ups look like. Like a little of this one, a little of that one? Mix and match to come up with the perfect solution.</li>
<li>The top box is your <b>current</b> writeup footer display.</li>
</ol>

<p>
Press the "clear to default" button to reset to the normal display; "default: bare", "default: classic", "default: full", or "default: pseudo-anonymous author" to use one of the default values; or "custom" after typing in your own code sequence.<br />
<strong>Tip</strong>: most people won\'t need to ultra-customize the display, they\'ll be fine with one of the defaults.<br />
</p>

';

    $str .= htmlcode('closeform');

    return $str;
}

sub wheel_of_surprise {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    return '<p>You must be logged in to be suprised.</p>' if($APP->isGuest($USER));
    #my $isHalloween = htmlcode('isSpecialDate','halloween');

    my $isHalloween = 0;
    my $costumeCost = 5;

    my ($str, $resultStr) = ("","");

    my $spinCost = 5;

    if ($isHalloween) {
    $spinCost = 0;
    } else {

    #if ($$USER{GP} < $spinCost) {
    # return "<p>Sorry, you don't have enough GP to spin the wheel.</p>";
    #}
    return "<p>Your vow of poverty does not allow you to gamble. You need to [User Settings|opt in to] the GP System in order to spin the wheel.</p>" if ($$VARS{GPoptout});

    if ($$USER{GP} < $spinCost) {
      #if ($$USER{GP} < -10) {
      return "<p>You approach the Wheel but two large gentlemen with shaved heads and tattoos saying \"MOM\" stop you. One of them twists your head to face the wall while the other points to a sign on said wall that says \"shirt and shoes required\". You know that they'd let you play naked if you flashed them some GP but then if you had that much GP you wouldn't be barefoot and shirtless, would you now?  As the large gentleman twists your head toward the door, you spot the oversized sign that says <strong><font color=\"#FF0000\">Minimum Wager 5 GP</font></strong>.</p><p>Come back when you have GP to burn and a shirt on your back.</p>";
    }

    }

    if ($query->param("spinthewheel")) {
    $$VARS{spin_wheel} += 1;
    $$USER{GP} += (-1*$spinCost);
    my $rnd = int(rand(10000));
    $resultStr= "<p>The Wheel of Surprise awards you ...";

    if ($isHalloween) {
    if ($rnd<450) {
                 $resultStr .= " <b>a brick!</b> You also feel a hand in your pocket as a spooky voice asks if you have a banana. You tell it that [Yes! We have no bananas!|you do not have a banana] and, no, you would not be glad to see the hand's owner, even if it were not pitch dark. The hand creeps back out of your pocket and disappears into the darkness.";
    }
    elsif ($rnd<500) {
                $resultStr .= " <b>a voodoo doll!</b> Why, this looks like someone high up in the E2 management. You forget all about tricks and treats, and quickly trot off to raid your mom's sewing cabinet for pins.";
    }
    elsif ($rnd<1000) {
                $resultStr .= " <b>a bucket full of coal!</b> Wrong holiday, you think, but you also get a sense that someone is trying to distract you from something. Your wallet feels lighter.";
    }
    elsif ($rnd<1500) {
                $resultStr .= " <b>an apple with a razor blade.</b> What a pathetic clich&egrave;! You fling a coin at the wheel and leave in disgust.";
    }
    elsif ($rnd<2000) {
                $resultStr .= " <b>a coin covered in goo.</b> A deep voice asks you for abaht tree-fiddy. You fork over 10GP and run.";
    }
    elsif ($rnd<2500) {
                $resultStr .= " <b>a piece of jalape&ntilde;o-flavoured chewing gum!</b> &iexcl;Ay ay caliente! Some small change flies out of your pocket as you dip your head into the nearest fountain.";
    }
    elsif ($rnd<3000) {
                $resultStr .= " <b>a pint of blood wine</b>! As you lift it to your lips, you hear a voice that sounds like a drunk Norwegian with a bad case of catarrh. You decide to skip the drink and slink off instead.";
    }
    elsif ($rnd<3500) {
                $resultStr .= " <b>a clammy hand.</b> You soon discover that the hand is attached to a zombie. The zombie growls \"treeeeeat, treeeeeat!\" and tries to tuck into your arm. You decide that now would be a good time to disappear.";
    }
    elsif ($rnd<4000) {
                $resultStr .= " <b>a tin-foil hat.</b> Just what you need to complete your conspiracy theorist costume. What do you mean, that's <em>not</em> a costume?";
    }
    elsif ($rnd<4500) {
    #        $resultStr .= "<b>a trick!</b> Hope you didn't need that GP ...";
    #        $$USER{GP} += -10;
                $resultStr .= " <b>a generic trick!</b> Something tells you you should try again.";
    }
        elsif ($rnd<4550) {
                return "ACK! Wheel disabled by Werewolf attack! ([Young Frankenstein|Where wolf? There wolf!])";
        }
        elsif ($rnd<4700) {
                $$USER{GP} += 10;
                return "You discover a trick that makes the wheel make a horrible chattering noise. After several minutes of making an unholy din a skeleton appears and offers to pay you if you'll just STOP. You're not the sort to refuse money for nothing so that's the way you do it.";
        }
        elsif ($rnd<4702) {
                $$USER{GP} += 1000;
                return "As the wheel clatters to a halt, you see a little man in green hanging onto it for dear life. You pluck him off and dust him down. He promises you great rewards if you let him go but you find that the legendary pot of gold is really just full of GP. Never trust an E2 leprechaun.";
        }
        elsif ($rnd<5000) {
                return "ACK! Wheel disabled by Vampire attack!";
        }
    else {
        $resultStr .= "<b>a treat!</b> I wonder what it's for ...";
        if (!exists($$VARS{treats})) {
            $$VARS{treats} = 1;
        }
        else {
            $$VARS{treats} += 1;
        }
                $resultStr .= "<br />You count the treats in your bag. $$VARS{treats}!";
                   if ($$VARS{treats} >= $costumeCost) {
                   $resultStr .= "<br />That's enough to [The Costume Shop|buy a costume]!";
                   }
                   else {
                   $resultStr .= " That might buy a Richard Nixon mask but you'll have to work some more if you want to dress up properly;"
                   }
    }
}

    if (!$isHalloween) {
        $APP->securityLog($NODE, $USER, "[$$USER{title}] spun the [Wheel of Surprise].");
    if ($rnd<3800) {
        $resultStr .= "<b>nothing!</b> Too bad ...";
    }
    elsif ($rnd<3850) {
        $resultStr .= "<b>a coupon for a free [Butterfinger McFlurry].</b> Alas, they no longer make them.";
    }
    elsif ($rnd<3910) {
        $resultStr .= "<b>a porcupine egg!</b> I wonder what will hatch. Probably nothing.";
    }
    elsif ($rnd<3915) {
        $resultStr .= "<b>a tin of fair trade caviar!</b> The perfect gift for the up-and-coming hippie plutocrat!";
    }
    elsif ($rnd<3930) {
        $resultStr .= "<b>an easter ostrich egg!</b> This has to be worth three ordinary easter eggs! I wonder what's inside.";
        if (!exists($$VARS{easter_eggs})) {
            $$VARS{easter_eggs} = 3;
            $$VARS{easter_eggs_bought} = 3;
        }
        else {
            $$VARS{easter_eggs} += 3;
            $$VARS{easter_eggs_bought} += 3;
        }
    }
    elsif ($rnd<3935) {
        $resultStr .= "<b>a Christmas egg!</b> It's red and green and plays Jingle Bells when you open it. That's about all that it does. Is that not enough!?";
        if (!exists($$VARS{easter_eggs})) {
            $$VARS{easter_eggs} = 1;
            $$VARS{easter_eggs_bought} = 1;
        }
        else {
            $$VARS{easter_eggs} += 1;
            $$VARS{easter_eggs_bought} += 1;
        }
    }
    elsif ($rnd<3940) {
        $resultStr .= "<b>a passover egg!</b> I wonder what's inside. Probably a matzo ball.";
        if (!exists($$VARS{easter_eggs})) {
            $$VARS{easter_eggs} = 1;
            $$VARS{easter_eggs_bought} = 1;
        }
        else {
            $$VARS{easter_eggs} += 1;
            $$VARS{easter_eggs_bought} += 1;
        }
    }
    elsif ($rnd<3950) {
        $resultStr .= "<b>five counterfeit GP!</b> You pawn them off on some unsuspecting noder in exchange for a shiny new easter egg.";
        if (!exists($$VARS{easter_eggs})) {
            $$VARS{easter_eggs} = 1;
            $$VARS{easter_eggs_bought} = 1;
        }
        else {
            $$VARS{easter_eggs} += 1;
            $$VARS{easter_eggs_bought} += 1;
        }
    }
    elsif ($rnd<4000) {
        $resultStr .= "<b>an anvil!</b> At least that's what it feels like when you drop it on your foot. Hmm. Maybe it's a strange form of easter egg.";
        if (!exists($$VARS{easter_eggs})) {
            $$VARS{easter_eggs} = 1;
            $$VARS{easter_eggs_bought} = 1;
        }
        else {
            $$VARS{easter_eggs} += 1;
            $$VARS{easter_eggs_bought} += 1;
        }
    }
    elsif ($rnd<4950) {
        $resultStr .= "<b>an easter egg!</b> I wonder what's inside.";
        if (!exists($$VARS{easter_eggs})) {
            $$VARS{easter_eggs} = 1;
            $$VARS{easter_eggs_bought} = 1;
        }
        else {
            $$VARS{easter_eggs} += 1;
            $$VARS{easter_eggs_bought} += 1;
        }
    }
    elsif ($rnd<4999) {
        $resultStr .= "<b>a C!</b> Coolness!";
                $$VARS{cools} ||= 0;
        $$VARS{cools} += 1;
        setVars($USER,$VARS);
    }
    elsif ($rnd==4999) {
        $resultStr .= "<b>5 C!s</b> Hurry up and spend 'em while you got 'em!";
                $$VARS{cools} ||= 0;
        $$VARS{cools} += 5;
        setVars($USER,$VARS);
    }
    elsif  ($rnd == 5000) {
        $resultStr .= "<b>500 GP!</b> Jackpot!";
        $$USER{GP} += 500;
    }
    elsif ($rnd<5006) {
        $resultStr .= "<b>158 GP!</b> That's 100 GP adjusted for inflation.";
        $$USER{GP} += 158;
    }
    elsif ($rnd<5011) {
        $resultStr .= "<b>42 GP!</b> That's 100 GP after taxes. You get the feeling that it's also the answer to something.";
        $$USER{GP} += 42;
    }
    elsif ($rnd<5100) {
        $resultStr .= "<b>100 GP!</b> Sweet!";
        $$USER{GP} += 100;
    }

    elsif ($rnd<5200) {
        $resultStr .= "<b>a token!</b> Go spend it at the [e2 gift shop|gift shop]!";
        if (!exists($$VARS{tokens})) {
            $$VARS{tokens} = 1;
            $$VARS{tokens_bought} += 1;
        }
        else {
            $$VARS{tokens} += 1;
            $$VARS{tokens_bought} += 1;
        }
        setVars($USER,$VARS);
    }
    elsif ($rnd<5240) {
        $resultStr .= "<b>a New York City subway token!</b> Free ride! Expires April 13, 2003.";
    }
    elsif ($rnd<5500) {
        $resultStr .= "<b>25 GP!</b> Hooray!";
        $$USER{GP} += 25;
    }
    elsif ($rnd<6500) {
        $resultStr .= "<b>10 GP!</b> Spin it again!";
        $$USER{GP} += 10;
    }
    elsif ($rnd<6750) {
        $resultStr .= "<b>5 GP!</b> You also find one GP that the last player left behind.";
        $$USER{GP} += 6;
    }
    elsif ($rnd<7000) {
        $resultStr .= "<b>nothing</b> as it comes to a creaking, chattering, jerky halt. You complain to the manager about the wheel's condition and get your nickel back.";
        $$USER{GP} += 5;
    }
    elsif ($rnd<9000) {
        $resultStr .= "<b>your [5 GP|nickel] back!</b> Spin it again!";
        $$USER{GP} += 5;
    }
    else {
        $resultStr .= "<b>1 GP!</b> (Wah-wah-wah!)";
        $$USER{GP} += 1;
    }
    $resultStr .= "</p>";

    htmlcode('achievementsByType','miscellaneous,'.$$USER{user_id});

}

}

    if (!$isHalloween) {
    $str = '<h3>Welcome, welcome, one and all. Step right up, put your [5 GP|nickel] in the hat and spin the wonderful Wheel of Surprise! Who knows what mysterious wonders will emerge?</h3><p><small>All rights reserved. Must be 18 to play (19 in Quebec and Alabama). Contest open to legal residents of Earth and overseas territories only. Wash cold, tumble dry low. Guarantee void in Tennessee.</small></p>';
}
    else {
    $str = '<h3>Welcome, welcome, one and all. Tonight we\'re offering a Trick or Treat Special - and it\'s free to spin, all night long! Who knows what mysterious wonders will emerge?</h3><p><small>Guarantee void in Transylvania.</small></p>';
}




    $str.=htmlcode('openform');
    $str.=$query->submit('spinthewheel','spin');
    $str.=$query->end_form;

    # Second code block
    ###This makes sure future XP and GP messages in the epicenter will be accurate - mauler

    $$VARS{oldexp} = $$USER{experience};
    $$VARS{oldGP} = $$USER{GP};

    return $resultStr.$str;
}

sub reputation_graph_horizontal {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    # Alright, so this might be a [lot|little] hacky to any of you perl gurus who are looking
    # at this. My plea is that I'm an Object Oriented programmer who is used to using languages
    # with true built in methods for working with dates.

    my $writeupId = int($query->param('id'));
    my $writeup = getNodeById($writeupId);
    return "Not a valid node. Try clicking the &quot;Rep Graph&quot; link from a writeup you have already voted on." unless $writeup;

     my $str = '<p>You are viewing the monthly reputation graph for the following writeup:<br />'.linkNode($writeup).' by '.linkNode($$writeup{author_user}).'</p>';


    if ($$writeup{type_nodetype} != 117)
    {
      return "You can only view the reputation graph for writeups. Try clicking on the &quot;Rep Graph&quot; link from a writeup you have already voted on.";
    }

    my $queryText;
    my $csr;

    # let logged in admins see graph even if they haven't voted
    my $isRoot = $APP->isAdmin($USER);
    my $canView = $isRoot;
    # users can view the graphs of their own writeups
    if (!$canView)
    {
      $canView = ($$writeup{author_user} == $$USER{node_id});
    }
    # if not an admin, see if user has voted on the writeup
    if (!$canView)
    {
      $queryText = 'SELECT weight FROM vote WHERE vote_id='.$writeupId.' AND voter_user='.$$USER{node_id};
      $csr = $DB->{dbh}->prepare($queryText);
      $csr->execute();
      if($csr->rows>0){$canView=1;}
    }

    if (!$canView)
    {
      return "You haven't voted on that writeup, so you are not allowed to see its reputation. Try clicking on the &quot;Rep Graph&quot; link from a writeup you have already voted on.";
    }

    my @prevDate = strptime($$writeup{publishtime});
    my $year = $prevDate [5];
    my $month = $prevDate [4];

    my $posRow;
    my $negRow;
    my $labelRow;
    $queryText = "SELECT weight,votetime FROM vote WHERE vote_id=$writeupId ORDER BY votetime";
    $csr = $DB->{dbh}->prepare($queryText);
    $csr->execute();
    my @curDate;
    my $rep = 0;
    my $altText;
    while(my $row = $csr->fetchrow_hashref)
    {
      @curDate = strptime($$row{votetime});

      while($curDate[5]>$year || ($curDate[5]==$year && $curDate[4]>$month))
      {
    $altText = ($month+1).'/'.($year+1900).' - Rep: '.$rep;
    if($rep>=0)
    {
      $posRow .= '<td valign="bottom" title="'.$altText.'"><img src="http://www.pitt.edu/~rttaylor/e2/0c0.gif" width="2" height="'.$rep.'" alt="'.$altText.'" /></td>';
      $negRow .= '<td></td>';
    }
    else
    {
      $negRow .= '<td valign="top" title="'.$altText.'"><img src="http://www.pitt.edu/~rttaylor/e2/f00.gif" width="2" height="'.-$rep.'" alt="'.$altText.'" /></td>';
      $posRow .= '<td></td>';
    }
    if($month==0)
    {
      $labelRow.='<td>|</td>';
    }
    else
    {
      $labelRow.='<td></td>';
    }

    $month++;
    if($month>11)
    {
      $month = 0;
      $year++;
    }
      }

      if ($prevDate[5] > $curDate[5] || ($prevDate[5] >= $curDate[5] && $prevDate[4] > $prevDate[4]))
      {
    $altText = ($curDate[4]+1).'/'.($curDate[5]+1900).' - Rep: '.$rep;
    if($rep>=0)
    {
      $posRow .= '<td valign="bottom" title="'.$altText.'"><img src="http://www.pitt.edu/~rttaylor/e2/0c0.gif" width="2" height="'.$rep.'" alt="'.$altText.'" /></td>';
      $negRow .= '<td></td>';
    }
    else
    {
      $negRow .= '<td valign="top" title="'.$altText.'"><img src="http://www.pitt.edu/~rttaylor/e2/f00.gif" width="2" height="'.-$rep.'" alt="'.$altText.'" /></td>';
      $posRow .= '<td></td>';
    }
    if($month==0)
    {
      $labelRow.='<td>|</td>';
    }
    else
    {
      $labelRow.='<td></td>';
    }
      }
      $rep += $$row{weight};
      @prevDate = @curDate;
      $year = $prevDate[5];
      $month = $prevDate[4];
    }
    $altText = ($curDate[4]+1).'/'.($curDate[5]+1900).' - Rep: '.$rep;
    if($rep>=0)
    {
      $posRow .= '<td valign="bottom" title="'.$altText.'"><img src="http://www.pitt.edu/~rttaylor/e2/0c0.gif" width="2" height="'.$rep.'" alt="'.$altText.'" /></td>';
      $negRow .= '<td></td>';
    }
    else
    {
      $negRow .= '<td valign="top" title="'.$altText.'"><img src="http://www.pitt.edu/~rttaylor/e2/f00.gif" width="2" height="'.-$rep.'" alt="'.$altText.'" /></td>';
      $posRow .= '<td></td>';
    }
    if($month==0)
    {
      $labelRow.='<td>|</td>';
    }
    else
    {
      $labelRow.='<td></td>';
    }

    $str .= '<style type="text/css">
      .Negative img{border-top:2px solid #f88;border-left:2px solid #f88;border-bottom:2px solid #800;border-right:2px solid #800;}
      .Positive img{border-top:2px solid #5a5;border-left:2px solid #5a5;border-bottom:2px solid #050;border-right:2px solid #050;}
      .Positive td{border-bottom:1px dotted #ccc;}
      .Negative td{border-top:1px dotted #ccc;}
      .GraphLabel{font-weight:bold;font-size:80%;}
      </style>';


    $str .= '<p style="text-align:center;font-size:80%">Hover your mouse over any of the bars on the graph to see the date and reputation for each month.</p>
      <table cellspacing="1" cellpadding="0" align="center">
      <tr class="Positive">'.$posRow.'</tr>
      <tr class="Negative">'.$negRow.'</tr>
      <tr class="GraphLabel">'.$labelRow.'</tr>
      </table>';

    if($isRoot)
    {
      $str .= '<p style="text-align:center;font-size:80%">NOTE: Admins can view the graph of any writeup by simply appending &quot;&id=&lt;writeup_id&gt;&quot; to the end of the URL</p>';
    }

    return $str;
    }

sub reputation_graph {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    # Alright, so this might be a [lot|little] hacky to any of you perl gurus who are looking
    # at this. My plea is that I'm an Object Oriented programmer who is used to using languages
    # with true built in methods for working with dates.

    my $writeupId = int($query->param('id'));
    my $writeup = getNodeById($writeupId);
    return "<p>Not a valid node. Try clicking the &quot;Rep Graph&quot; link from a writeup you have already voted on.</p>" unless $writeup;

    my $str = '<p>You are viewing the monthly reputation graph for the following writeup:<br />'.linkNode($writeup).' by '.linkNode($$writeup{author_user}).'</p>';

    if ($$writeup{type_nodetype} != 117)
    {
      return "<p>You can only view the reputation graph for writeups. Try clicking on the &quot;Rep Graph&quot; link from a writeup you have already voted on.</p>";
    }

    my $queryText;
    my $csr;

    # let logged in admins see graph even if they haven't voted
    my $isRoot = $APP->isAdmin($USER);
    my $canView = $isRoot;
    # users can view the graphs of their own writeups
    if (!$canView)
    {
      $canView = ($$writeup{author_user} == $$USER{node_id});
    }
    # if not an admin, see if user has voted on the writeup
    if (!$canView)
    {
      $queryText = 'SELECT weight FROM vote WHERE vote_id='.$writeupId.' AND voter_user='.$$USER{node_id};
      $csr = $DB->{dbh}->prepare($queryText);
      $csr->execute();
      if($csr->rows>0){$canView=1;}
    }

    if (!$canView)
    {
      return "<p>You haven't voted on that writeup, so you are not allowed to see its reputation. Try clicking on the &quot;Rep Graph&quot; link from a writeup you have already voted on.</p>";
    }

    my @prevDate = strptime($$writeup{publishtime});
    my $year = $prevDate [5];
    my $month = $prevDate [4];

    $queryText = "SELECT weight,votetime,revotetime FROM vote WHERE vote_id=$writeupId ORDER BY GREATEST(revotetime,votetime)";
    $csr = $DB->{dbh}->prepare($queryText);
    $csr->execute();
    my @curDate;
    my $dt;
    my $uv = 0;
    my $dv = 0;

    $str .= '<table cellspacing="0" cellpadding="0" align="center" class="Chart">
         <tr>
         <th>Date</th>
         <th colspan="2">Downvotes</th>
         <th colspan="2">Upvotes</th>
         <th>Reputation</th>
         </tr>';

    while(my $row = $csr->fetchrow_hashref)
    {
      $dt = $$row{votetime};
      if ($APP->convertDateToEpoch($$row{revotetime}) > $APP->convertDateToEpoch($dt) ) {
    $dt = $$row{revotetime};
      }
      @curDate = strptime($dt);

      while($curDate[5]>$year || ($curDate[5]==$year && $curDate[4]>$month))
      {
    # date label
    $str .= '<tr>
             <td class="DateLabel">';
    if ($month==0)
    {
      $str .= '<b>'.($month+1).'/'.($year+1900).'</b>';
    }
    else
    {
      $str .= ($month+1).'/'.($year+1900);
    }
    $str .= '</td>';

    # downvote label and graph
    $str .= '<td class="DownvoteLabel">'.$dv.'</td>
             <td class="DownvoteGraph">';
    if($dv<0)
    {
      $str .= '<span class="NegativeGraph" style="padding-right:'.(-$dv).'px">&nbsp;</span>';
    }
    $str .= '</td>';

    # upvote graph and label then reputation
    $str .= '<td class="UpvoteGraph">';
    if ($uv>0)
    {
      $str .= '<span class="PositiveGraph" style="padding-right:'.($uv).'px">&nbsp;</span>';
    }
    $str .= '</td>
             <td class="UpvoteLabel">+'.$uv.'</td>
             <td class="ReputationLabel">'.($uv+$dv).'</td>
             </tr>';

    $month++;
    if($month>11)
    {
      $month = 0;
      $year++;
    }
      }

      if ($prevDate[5] > $curDate[5] || ($prevDate[5] >= $curDate[5] && $prevDate[4] > $prevDate[4]))
      {
    # date label
    $str .= '<tr>
             <td class="DateLabel">';
    if ($curDate[4]==0)
    {
      $str .= '<b>'.($curDate[4]+1).'/'.($curDate[5]+1900).'</b>';
    }
    else
    {
      $str .= ($curDate[4]+1).'/'.($curDate[5]+1900);
    }
    $str .= '</td>';

    # downvote label and graph
    $str .= '<td class="DownvoteLabel">'.$dv.'</td>
             <td class="DownvoteGraph">';
    if($dv<0)
    {
      $str .= '<span class="NegativeGraph" style="padding-right:'.(-$dv).'px">&nbsp;</span>';
    }
    $str .= '</td>';

    # upvote graph and label then reputation
    $str .= '<td class="UpvoteGraph">';
    if ($uv>0)
    {
      $str .= '<span class="PositiveGraph" style="padding-right:'.($uv).'px">&nbsp;</span>';
    }
    $str .= '</td>
             <td class="UpvoteLabel">+'.$uv.'</td>
             <td class="ReputationLabel">'.($uv+$dv).'</td>
             </tr>';
      }
      if($$row{weight}>0)
      {
    $uv += $$row{weight};
      }
      elsif($$row{weight}<0)
      {
    $dv += $$row{weight};
      }

      @prevDate = @curDate;
      $year = $prevDate[5];
      $month = $prevDate[4];
    }
    # date label
    $str .= '<tr>
         <td class="DateLabel">';
    if ($curDate[4]==0)
    {
      $str .= '<b>'.($curDate[4]+1).'/'.($curDate[5]+1900).'</b>';
    }
    else
    {
      $str .= ($curDate[4]+1).'/'.($curDate[5]+1900);
    }
    $str .= '</td>';

    # downvote label and graph
    $str .= '<td class="DownvoteLabel">'.$dv.'</td>
         <td class="DownvoteGraph">';
    if($dv<0)
    {
      $str .= '<span class="NegativeGraph" style="padding-right:'.(-$dv).'px">&nbsp;</span>';
    }
    $str .= '</td>';

    # upvote graph and label then reputation
    $str .= '<td class="UpvoteGraph">';
    if ($uv>0)
    {
      $str .= '<span class="PositiveGraph" style="padding-right:'.($uv).'px">&nbsp;</span>';
    }
    $str .= '</td>
         <td class="UpvoteLabel">+'.$uv.'</td>
         <td class="ReputationLabel">'.($uv+$dv).'</td>
         </tr>
         </table>';

    $str .= '<style type="text/css">
      .DateLabel{padding-right:20px;text-align:right;}
      .DownvoteLabel{text-align:right;}
      .DownvoteGraph{text-align:right;border-right:1px dotted #ccc;}
      .NegativeGraph{font-size:1px;background-color:#f00;border-top:2px solid #f88;border-left:2px solid #f88;border-bottom:2px solid #800;border-right:2px solid #800;}
      .PositiveGraph{font-size:1px;background-color:#0a0;border-top:2px solid #5a5;border-left:2px solid #5a5;border-bottom:2px solid #050;border-right:2px solid #050;}
      .ReputationLabel{text-align:right;}
      .Chart{font-size:65%;}
      </style>';

    if($isRoot)
    {
      $str .= '<p style="text-align:center;font-size:80%">NOTE: Admins can view the graph of any writeup by simply appending &quot;&id=&lt;writeup_id&gt;&quot; to the end of the URL</p>';
    }

    return $str;
    }

sub message_inbox_2 {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '<table>';

    my $user_id = getId($USER)||0;

    $str .= '<tr><td>If you had an account, you\'d get messages.</td></tr>' if $APP->isGuest($USER);
    return $str.'</table>' if $APP->isGuest($USER);
    
    my $isRoot = $APP->isAdmin($USER);
    
#N-Wing converted to using varcheckbox, and moved to options part
## if this page has been submitted...
#if(defined($query->param('message send'))) {
    #    #...any changes to the checkbox should be reflected in $VARS...
    #    if(defined($query->param('autofill'))) {
    #        $VARS->{autofillInbox} = 1;
    #    } else {
    #        delete $$VARS{autofillInbox};
    #    }
#} else {
    #    #...otherwise, let $VARS dictate the state of the checkbox
    #    if(exists($VARS->{autofillInbox})) {
    #        $query->param('autofill', 'on');
    #    }
#}
    
    my $showStart = 0;
    my $numShow = 0;
    my $foruser = '';
    my $olduser = '';
    
#$str.= htmlcode('openform').'&nbsp;&nbsp;&nbsp;&nbsp;'.htmlcode('varcheckbox','sortmyinbox,Sort my messages in message inbox').'<br /><input type="submit" value="Change Now"></form>';
    
    $str .= '<form name="message_inbox_form" method="POST"><input type="hidden" name="op" value="message">';
    $str .= '<input type="hidden" name="node_id" value="'.getId($NODE).'">';
    $str .= $query->hidden('sexisgood','1');    #so auto-VARS changing works
    {
        #for some reason, we're doing everything in a table; this at least make the options part a little easier
        my @opts;
    #    push @opts, $query->checkbox(-name=>'autofill', -label=>'Autofill Recipient');
        push @opts, htmlcode('varcheckbox','autofillInbox,Autofill recipient');
        push @opts, htmlcode('varcheckbox','sortmyinbox,Sort messages by usergroup');
        push @opts, 'only show from user '  . $query->textfield(-name=>'fromuser')  . ', or do the inverse: ' . $query->checkbox(-name=>'notuser' ,-label=>'hide from this user');
        push @opts, 'only show from group ' . $query->textfield(-name=>'fromgroup') . ', or do the inverse: ' . $query->checkbox(-name=>'notgroup',-label=>'hide to this group' );
    
#N-Wing made this sticky
    #    push @opts, 'archived/unarchived messages: '.$query->popup_menu(-name=>'arcunarc', -values=>['all','archived','unarchived'], -default=>'all');
        push @opts, 'archived/unarchived messages: ' . htmlcode('varsComboBox', 'msginboxUnArc,0, 0,all, 1,unarchived, 2,archived');
    
        $str .= '<tr><td colspan="4"><strong>Options</strong></td></tr>'."\n";
        foreach(@opts) {
            $str .= '<tr><td></td><td colspan="2">' . $_ . "</td></tr>\n";
        }
}
    
#show archived/unarchived things
    my $sqlFilterArc='';    #default of no filtering
    if( (exists $VARS->{msginboxUnArc}) && (defined $VARS->{msginboxUnArc}) ) {
        my $v=$VARS->{msginboxUnArc};
        if($v eq '1') {
            $sqlFilterArc=' AND archive=0';
        } elsif($v eq '2') {
            $sqlFilterArc=' AND archive!=0';
        }
}
    
    
    if($isRoot) {
    
    if(defined($query->param('spy_user'))) {
    
        #FIXME after the bot setting is set: get info from there instead
        my @okaytospy = ($$USER{title}, 'Webster 1913', 'EDB', 'Klaproth', 'Cool Man Eddie', 'Guest User', 'recipe', 'Grease Monkey', 'Content_Salvage');
        my $okay;
        $$okay{getId(getNode($_, 'user'))} = 1 foreach(@okaytospy);
    
        $foruser = getNode(scalar($query->param('spy_user')), 'user');
    
        unless(defined $foruser){
    
            $foruser = $USER;
            $str .= '<tr><td><small>(No such user ['.$query->param('spy_user').'])</small></tr></td>';
    
        }
    
        $foruser = $USER unless(exists $$okay{$$foruser{node_id}});
    
    } else {
        $foruser = $USER;
}
    
    
    
    $str .= '<tr><td colspan="3">Message Inbox for: <select name="spy_user"><option value="'.$$foruser{title}.'">'.$$foruser{title}.'</option>';
    
    if(getId($foruser) != $user_id){  $str .= '<option value="'.$$USER{title}.'">'.$$USER{title}.'</option>';}
    
    if(getId($foruser) != getId(getNode('Cool Man Eddie', 'user'))){ $str .= '<option value="Cool Man Eddie">Cool Man Eddie</option>';}
    
    if(getId($foruser) != getId(getNode('Guest User', 'user'))){ $str .= '<option value="Guest User">Guest User</option>';}
    
    if(getId($foruser) != getId(getNode('EDB', 'user'))){ $str .= '<option value="EDB">EDB</option>';}
    
    if(getId($foruser) != getId(getNode('Klaproth', 'user'))){ $str .='<option value="Klaproth">Klaproth</option>';}
    
    if(getId($foruser) != getId(getNode('Webster 1913', 'user'))){ $str .='<option value="Webster 1913">Webster 1913</option>';}
    
    if(getId($foruser) != getId(getNode('recipe', 'user'))){ $str .='<option value="Recipe">Recipe</option>';}
    
    if(getId($foruser) != getId(getNode('Grease Monkey', 'user'))){ $str .='<option value="Grease Monkey">Grease Monkey</option>';}
    
    if(getId($foruser) != getId(getNode('Content_Salvage', 'user'))){ $str .='<option value="Content_Salvage">Content_Salvage</option>';}
    
    $str .='</select></tr></td>';
    
    } else {
        $foruser = $USER;
}
#########originally All jay in here:
    
    my $sqlSortInboxNotUG='';    #non-usergroups
    if($$VARS{sortmyinbox}) {
        my $csr = $DB->sqlSelectMany('nodegroup_id', 'nodegroup', "node_id=$user_id");
    
        my $typ = getId(getType('usergroup'));
        my $groups;
    
        while( my $row = $csr->fetchrow_hashref) {
            my $n = getNodeById($$row{nodegroup_id});
            next unless($$n{type_nodetype} == $typ);
    
            $$groups{$$n{title}} = $$n{node_id};
        }
    
        $$groups{'Content Editors'} = getId(getNode('Content Editors', 'usergroup')) if $isRoot;
    
        my $sqlq;
    
        foreach(keys(%$groups)) {
    #        my $num = $DB->sqlSelect('count(*)', 'message', "for_user=$$foruser{user_id} AND for_usergroup=$$groups{$_} AND archive=0");
            $sqlq = "for_user=$$foruser{user_id} AND for_usergroup=$$groups{$_}";
            $sqlq .= $sqlFilterArc if length($sqlFilterArc);
            my $num = $DB->sqlSelect('count(*)', 'message', $sqlq);
    
            my $tempstr = "<small>$_: $num</small>";
    
            $tempstr = '<strong><big>'.$tempstr.'</big></strong>'; #if($num > 0);
            $str.= '<a href='.urlGen({'fromgroup'=>$_, 'node_id'=>$$NODE{node_id}}).">$tempstr</a><br />\n" if($num > 0);
        }
    
        #deal with non-usergroup for_usergroup stuff
        #this is rather ugly
        {
            #creates: (for_usergroup!=838015 AND for_usergroup!=923653 AND (etc.))
    
            $sqlq = "for_user=$$foruser{user_id}";
    
            if(scalar(keys(%$groups))) {
                        #jb says I removed the extra AND. we have one down below
                        #map in void context. Use foreach.
                        #Plus this doesn't form the string correctly
                $sqlSortInboxNotUG = join(' OR ', map{ 'for_usergroup='.$_ } values(%$groups));
                        #$sqlSortInboxNotUG.= " AND NOT for_usergroup=$_ ", foreach(values(%$groups)).' ';
    #        $sqlq .= $sqlSortInboxNotUG;
    
##ick, this is bad...
#$sqlSortInboxNotUG='';
#foreach(values(%$groups)) {
#$sqlSortInboxNotUG .= ' AND ' if length($sqlSortInboxNotUG);
#$sqlSortInboxNotUG .= 'for_usergroup!='.$_;
#}
    
                if(length($sqlSortInboxNotUG)) {
                    $sqlSortInboxNotUG = ' AND NOT (' . $sqlSortInboxNotUG.')';
                    $sqlq .= $sqlSortInboxNotUG;
                }
    
            }
    
            $sqlq .= $sqlFilterArc if length($sqlFilterArc);
    
#if($$USER{node_id}==9740) {
#$DB->sqlInsert('message',{'for_user'=>9740, 'msgtext'=>$sqlq, author_user=>$user_id});
#$DB->sqlInsert('message',{'for_user'=>9740, 'msgtext'=>substr($sqlq,255), author_user=>$user_id}) if length($sqlq)>255;
#$DB->sqlInsert('message',{'for_user'=>9740, 'msgtext'=>substr($sqlq,511), author_user=>$user_id}) if length($sqlq)>511;
#}
    
            my $num = $DB->sqlSelect('count(*)', 'message', $sqlq);
    
            my $tempstr = "<small>other: $num</small>";
    
            $tempstr = '<strong><big>'.$tempstr.'</big></strong>'; #if($num > 0);
            $str.= '<a href='.urlGen({'node_id'=>$$NODE{node_id}}).">$tempstr</a><br />\n" if($num > 0);
        }
    
    #    $str .= '('.linkNode($NODE, $DB->sqlSelect('count(*)', 'message', "for_user=$$foruser{user_id} AND archive=0")." unarchived messages total").")<br />\n";
        $sqlq = "for_user=$$foruser{user_id}";
        $sqlq .= $sqlFilterArc if length($sqlFilterArc);
        $str .= '('.linkNode($NODE, $DB->sqlSelect('count(*)', 'message', $sqlq).' messages total').")<br />\n";
    
        $str .= '<br />';
    
        #return $str;
}
    
    
    my $limits = 'for_user='.getId($foruser);
    
    
    
    my $colHeading = '<tr><th align="left">delete</th><th>send time</th><th colspan="2" align="right">&#91;un&#93;Archive</th></tr>'."\n";
    $str .= $colHeading;
    
#TODO have an htmlcode that constructs the query, so XML ticker and showmessages doesn't have to dupe code
    my $notUser =($query->param('notuser')  ? 1 : 0);
    my $notGroup=($query->param('notgroup') ? 1 : 0);
    my $filterUser;    #user object, or 0 if none
    my $filterGroup;    #group object, or 0 if none
    my $filterUID=0;    #user ID, or 0 if none
    my $filterGID=0;    #group ID, or 0 if none
    
    if($filterUser=$query->param('fromuser')) {
        $filterUser = getNode($filterUser, 'user');
        $filterUID = $$filterUser{node_id} if $filterUser;
}
    if($filterGroup=$query->param('fromgroup')) {
        $filterGroup = getNode($filterGroup, 'usergroup') || getNode($filterGroup, 'user');
        $filterGID = $$filterGroup{node_id} if $filterGroup;
}
    $filterUser ||= 0;
    $filterGroup ||= 0;
    $limits .= ' AND author_user'.($notUser?'!=':'=').$filterUID if $filterUser;
    $limits .= ' AND for_usergroup'.($notGroup?'!=':'=').$filterGID if ($filterGID || $notGroup);
#$limits .= ' AND for_usergroup=0' if (!($filterGID) && $$VARS{sortmyinbox});
    $limits .= $sqlSortInboxNotUG if $$VARS{sortmyinbox} && !$filterGID && length($sqlSortInboxNotUG);
    $limits .= $sqlFilterArc if length($sqlFilterArc);
    
#TODO - LIMIT x,y
    my $showLimit='LIMIT ';
    my $showMax = scalar($query->param('showmax')) || $$VARS{inboxMax} || 0;
    $showMax = 0 unless ($showMax =~ /[0-9]+/);
    $showLimit= ' LIMIT '.$showMax if $showMax;
    
#debugging here
#return "<p>$limits</p>";
    
    my $csr = $DB->sqlSelectMany('*', 'message', $limits, 'ORDER BY tstamp LIMIT 10');
    
    my $flag = 0;
    my $t;
    my @chkboxes;
    my $talker;    #author of current message
    my $ug;    #usergroup current message is for
    
    while(my $MSG = $csr->fetchrow_hashref) {
        ++$flag;
        my $text = $$MSG{msgtext};
        #FIXME show no user error message, like we do for bad usergroups (instead of just skipping the message)
        $talker = $$MSG{author_user};
        getRef($talker);
        next unless($talker);
    
        (my $name = $$talker{title}) =~ tr/ /_/;
    
        #this should prevent punctuation chars in nicks from breaking our HTML
    #    $text = encodeHTML($text);
        $text =~ s/\</&lt;/g;
        $text =~ s/\>/&gt;/g;
        $text =~ s/\[([^\]]*?)$/&#91;$1/;    #dangling [ fixer    #]
        $text =~ s/\[\]/\]/g;                     #parse [] glitch fixer
        $name = encodeHTML($name);
        my $chkboxname = 'deletemsg_'.$$MSG{message_id};
        push @chkboxes, $chkboxname;
    
        $str.= '<tr><td valign="top">'. #$query->checkbox($chkboxname, '', 'yup', ' ');
        '<input type="checkbox" name="'.$chkboxname.'" VALUE="yup">'; # $query->textbox creates a newline after the tag, which messes up the table
    #    $str.= "<td><a onmouseover='replyTo(\&quot;$name\&quot;)' onclick='replyTo(\&quot;$name\&quot;)' href='#box'>reply</a></td>";
    
#Jay's fix for usernames with a single quote in them...
    
    local *eddiereply = sub {
    my $splitStr1=getNodeById($user_id);
    $splitStr1=$$splitStr1{title}.', ';
    $splitStr1 =~ s/(\W)/\\$1/g; #weird chars in U/N were causing regex errs.  WTF? --N
    my $splitStr2=' just cooled';
    my @tempsplit = split($splitStr1,$text);
    @tempsplit= split($splitStr2,$tempsplit[1]);
    my $eddie = $tempsplit[0];
    $eddie =~ s/\[//g;
    $eddie =~ s/\]//g;
    return $eddie;
    };
    
    
    my $safename = $name;
    $safename = eddiereply() if ($safename eq "Cool_Man_Eddie");
    $safename =~ s/'/&#39;/g;
    $safename =~ s/"/&#34;/g;
    
    #    $str .= "<input type='button' value='Reply' onmouseover='replyTo(\&quot;$safename\&quot;, 0)' onClick='replyTo(\&quot;$safename\&quot;, 1)'></td><td><small>&nbsp;";
    
        $str.="(<a onmouseover='replyTo(\&quot;$safename\&quot;,0)' href='javascript:replyTo(\&quot;$safename\&quot;,1)'>r</a>)";
    $ug = $$MSG{for_usergroup} || 0;
    unless($ug==0) {
    getRef($ug);
    (my $safeug = $$ug{title}) =~ tr/ /_/;
    $safeug =~ s/'/&#39;/g;
    $safeug =~ s/"/&#34;/g;
    $str.="(<a onmouseover='replyTo(\&quot;$safeug\&quot;,0)' href='javascript:replyTo(\&quot;$safeug\&quot;,1)'>ra</a>)";
}
    $str.="</td><td><small>&nbsp;";
    
        $t = $$MSG{tstamp};
        $str .= substr($t,0,4).'.'.substr($t,5,2).'.'.substr($t,8,2).'&nbsp;at&nbsp;'.substr($t,11,2).':'.substr($t,14,2);
    
        $str .= '</small></td><td>';
    
        $ug = $$MSG{for_usergroup} || 0;
        unless($ug==0) {
            $ug = getNodeById($ug);
            if(defined $ug) {
                $str .= '('.linkNode($ug,0,{lastnode_id=>0}).') ';
            } else {
                $str .= '(no user or group with ID of '.$$MSG{for_usergroup}.') ';
            }
        }
    
        #changes literal '\n' into HTML breaks (slash, then n; not a newline)
        $text =~ s/\s+\\n\s+/<br \/>/g;
    
        #$str .= '<em>'.linkNode($talker).' says</em> '.parseLinks($text) . '</td>';
        $str .= '<em>'.linkNode($talker).' says</em> '.$text. '</td>';
    
        $str .= '<td><tt>'.($$MSG{archive}?'A':'&nbsp;').'</tt><input type="checkbox" value="yup" name="' . ($$MSG{archive} ? 'un' : '') . 'archive_' . $$MSG{message_id} . '" /></td>';
    
        $str .= "</tr>\n";
}
    $csr->finish();
    
    $str .= $colHeading;
    
    $str .= '<tr><td colspan="4">';
    if($flag) {
        #at least 1 message showing
        $str .= "You have $flag messages total";
        my @allFilters;    #all filters that are being used
        push( @allFilters, (($notUser? 'not':'').' from '         .linkNode($filterUser )) ) if $filterUser;
        push( @allFilters, (($notGroup?'not':'').' sent to group '.linkNode($filterGroup)) ) if $filterGroup;
        $str .= ' that are '.join(' and ',@allFilters) if scalar(@allFilters);
        $str .= '.';
    } else {
        #no messages showing
        $str .= '<em>You feel lonely.</em>';
}
    $str .= '</td></tr>';
    
    $str .= '<tr><td colspan="4">' . $query->reset('Clear All') . ' <input type="button" value="Clear Reply" onClick="clearReply();"><input type="button" value="Check All" onClick="checkAll();">';
    if( (exists $VARS->{msginboxUnArc}) && (defined $VARS->{msginboxUnArc}) ) {
    $str.='<input type="button" value="'.( $VARS->{msginboxUnArc} eq '2' ? 'Una' : 'A').'rchive All" onClick="ArchiveAll();"></td></tr>';
}
    
# don't use $query->textfield() here, because sticky forms make things
# really ugly if you happen to write something in the Chatterbox
# don't blame me, i'm just the babysitter
# N-Wing says: why not just clear it via $query->delete('message'); ?
    $str .= '<tr><td colspan="4"><i>'.$query->param('sentmessage').'</i></td></tr>' if $query->param('sentmessage');
    $str .= '<tr><td colspan="4"><a name="box">'.(($$VARS{mitextarea} == 1)?('<textarea name="message" rows="8" cols="35"></textarea>'):('<input type="text" name="message" value="" size="40" maxlength="255">')) unless $$VARS{'borged'};
    $str .= ' '.$query->submit('message send', 'submit') . "\n</td></tr>";
# $str .= '<tr><td>' . $query->reset('Clear All') . "</td><td></td><td></td></tr>";
    
    $str .= $query->end_form();
    
    $str .= '</table>';
    
    return $str;
}

sub iron_noder_progress {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time);
    my $currentYear = $year + 1900;
    my $dateMinInc = '' . $currentYear . '-11-01';
    my $dateMaxExc = '' . $currentYear . '-12-01';
    my $triggerAchievement = $query -> param('ironise'); # option to activate achievement if iron noder period is not one calendar month

    #constants
    my $user_id = getId($USER);
    my $isGuest = $APP->isGuest($USER);
    my $isRoot = $APP->isAdmin($USER);
    my $isCE = $APP->isEditor($USER);
    my $ironLeader;
    my $isIronLeader = 0;
    my $isIronNoder = 0;

    #if there are more iron noder things later, this section should be updated to select appropriate group
    #    ironnoders    2008 November
    my $groupTitle = 'ironnoders';
    my @groupTypes = ('usergroup');

    my $isDaylogNode = sub {

        my $checkNode = shift;
        my $parentTitle = $$checkNode{parenttitle};

        return 1
            if $parentTitle =~ m/^(?:January|February|March|April|May|June|July|
                                    August|September|October|November|December)\s
                                    [[:digit:]]{1,2},\s[[:digit:]]{4}$/ix;
        return 1
            if $parentTitle =~ m/^(dream|editor|root) Log:/i;
        return 1
            if $parentTitle =~ m/^letters to the editors:/i;
        return 0;

    };

    my $ug = undef;
    foreach(@groupTypes) {
        $ug = getNode($groupTitle, $_);
        last if defined $ug;
}

    if(!defined $ug) {
        return 'Sorry; unable to find a list of iron noders.';
}
    #return 'found group '.linkNode($ug);


    #contains iron noder information
    #    key is user node_id
    #    value is light node ref
    my %ironNoders;

    my $str = '<ul>
    ';

    my $u;
    my $ironID;
    foreach my $ironID (@{$$ug{group}}) {
        $u = getNodeById($ironID, 'light');

        if(!$u) {
            $str .= '(DEBUG: unable to get user ID '.$ironID.')';
            next;
        }

        $ironLeader = $ironID if !defined $ironLeader;

        $ironNoders{$ironID} = $u;

}

    # We don't use $isIronNoder presently, but it might be useful in the future
    #  if we want to show special things to the organizers/members
    $isIronNoder = (defined $ironNoders{$user_id});
    $isIronLeader = ($ironLeader == $user_id);
    #$isIronLeader = 1 if $$USER{title} eq 'DonJaime';

    #writeup information setup
    my $showWUs = 1;
    my $qh = undef;
    my $typeID = getId(getType('writeup')) || undef;
    if($showWUs && !$typeID) {
        $showWUs = 0;
        $str .= '(DEBUG: unable to get writeup type)';
}

    if($showWUs) {

        my $getWriteupQuery = qq|
    SELECT
        node.node_id, node.title
        , parent.title 'parenttitle', writeup.parent_e2node
        , writeup.publishtime
        , vote.vote_id, writeup.wrtype_writeuptype, writeup.writeup_id
        FROM node
        LEFT OUTER JOIN vote
            ON
                voter_user = $user_id
                AND vote_id = node.node_id
        JOIN writeup
            ON
                node.node_id = writeup.writeup_id
        LEFT OUTER JOIN node AS parent
            ON
                writeup.parent_e2node = parent.node_id
        WHERE
            node.type_nodetype = '$typeID'
            AND node.author_user =  ?
            AND writeup.publishtime  >= ?
            AND writeup.publishtime  <  ?
        ORDER BY
            writeup.publishtime ASC|;

        $qh = $DB->{dbh}->prepare($getWriteupQuery);

        if(!$qh) {
            undef $qh;
            $showWUs = 0;
            $str .= '(DEBUG: unable to construct query for writeups)';
        }
}


    #all iron noders
    #    key is what to sort by
    #    value is light node ref
    my %ironNodersBySortKey;
    my $sortKey;
    foreach(keys(%ironNoders)) {
        #sort by username (case insensitive), and break tie by appending something arbitrary but consistent
        $sortKey = lc($ironNoders{$_}->{title}) . $ironNoders{$_}->{node_id};
        #while(exists $ironNodersBySortKey{$sortKey}) { $sortKey .= '.'; }
        $ironNodersBySortKey{ $sortKey } = $ironNoders{$_};
}

    my @displayOrder = sort(keys(%ironNodersBySortKey));
    #TODO? maybe reverse half the time to not favor items? maybe randomly split list in half (so everyone has equal chance of being somewhere in list)

    my $BIGNUMBER = 99999;
    my $WUCOUNTFORIRON = 30;
    my $MAXDAYLOGCOUNT = 5;
    my $statTotalWU = 0;
    my $statTotalNoders = 0;
    my $statNonzeroNoders = 0;
    my $statIronNoders = 0;
    my $statUserWU;
    my $statMaxCount = -1;
    my $statMinCount = $BIGNUMBER;
    my $statMinCountPositive = $BIGNUMBER;
    my $statVotedWU = 0;
    my $statYourWU = 0;

    my $htmlListUser;

    my %functionMap = (
        votecheck => sub {
            my $N = shift;
            my $vote_str = '';
            if ($$N{vote_id}) {
                $vote_str .= 'hasvoted';
                $statVotedWU++;
            }
            return $vote_str;
        },
        title => sub {
            my $N = shift;
            return linkNode($N, $$N{parenttitle}, { -class => 'title' } );
        },
        titleForWu => sub {
            my $N = shift;
            return "[$$N{parenttitle}\[by $$u{title}]]";
        }
    );

    my $forWu = $isIronLeader && $query -> param('wuFormat') ? 'ForWu' : '';
    my $instructions = "<li class=\"&votecheck\">title$forWu";

    foreach my $sortKey (@displayOrder) {
        $u = $ironNodersBySortKey{$sortKey};
        $ironID = getId($u);
        unless($ironID) {
            $str .= '(DEBUG: unable to get ID for '.htmlEncode($sortKey).')';
            next;
        }

        $htmlListUser = '';

        $htmlListUser .= '<li>';
        if($showWUs) { $htmlListUser .= '<big>'; };
        $htmlListUser .= $forWu ? "[$$u{title}\[user]]" : linkNode($u);
        if($showWUs) { $htmlListUser .= '</big>'; };

        if($showWUs) {
            $statUserWU = 0;

            $qh->execute(getId($u),$dateMinInc,$dateMaxExc);
            my @userWUs = ();
            while(my $r=$qh->fetchrow_hashref) {
                push(@userWUs, $r);
            }
            $qh->finish();
            my $daylogCount = 0;
            my @validWUs = grep { !$APP->isMaintenanceNode($_) } @userWUs;
            @validWUs = grep { !&$isDaylogNode($_) || ++$daylogCount <= $MAXDAYLOGCOUNT } @validWUs;

            $statUserWU = scalar(@validWUs);
            if ($daylogCount > $MAXDAYLOGCOUNT) {
                my $excess = $daylogCount - $MAXDAYLOGCOUNT;
                my $plural = $excess > 1 ? 's' : '';
                $statUserWU .= " ignoring $excess daylog$plural above the $MAXDAYLOGCOUNT limit";
            }
            $htmlListUser .= ' (' . $statUserWU . ')';

            $htmlListUser .= "<ol>\n";

            $htmlListUser .= htmlcode('show content', \@validWUs, $instructions, %functionMap)
                . '</ol>'
                ;

            #update stats
            $statTotalNoders++;
            $statTotalWU += $statUserWU;
            if ($user_id == $ironID) { $statYourWU = $statUserWU; }
            if ($statUserWU > 0) { $statNonzeroNoders++; }
            if ($statUserWU >= $WUCOUNTFORIRON) {
                $statIronNoders++;
                htmlcode('hasAchieved', 'writeupsMonth30', $ironID, 1) if $triggerAchievement;
            }
            if($statUserWU < $statMinCount) { $statMinCount = $statUserWU; }
            if(($statUserWU < $statMinCountPositive) && ($statUserWU>0) ) { $statMinCountPositive = $statUserWU; }
            if($statUserWU > $statMaxCount) { $statMaxCount = $statUserWU; }

        }

        $htmlListUser .= "</li>\n";
        $str .= $htmlListUser;

}

    $str .= '</ul>';

    if ($forWu){
        $str =~ s/ class="[\w\s]+"//g;
        $str = $query -> textarea('text', $str, 40, 80);
        $str =~ s/\[/&#91;/g;
        return $str;
}

    #statistics
    if($showWUs) {
        $str .= '<p><strong>Current Year Statistics</strong>:<br />
    ';
        if ($statYourWU > 0) {
            $str .= 'your writeups: '.$statYourWU.'<br />
    ';
        }
        if ($statTotalWU - $statYourWU > 0) {
            $str .= 'you have voted on '.$statVotedWU.' writeups (' . int(100 * $statVotedWU / ($statTotalWU - $statYourWU)) . '%)<br />
    ';
        }
        if($statMinCount!=$BIGNUMBER) {
            $str .= 'minimum writeups: '.$statMinCount.'<br />
    ';
        }
        if($statMinCountPositive!=$BIGNUMBER) {
            $str .= 'positive minimum writeups: '.$statMinCountPositive.'<br />
    ';
        }
        if($statMaxCount>=0) {
            $str .= 'maximum writeups: '.$statMaxCount.'<br />
    ';
        }
        if ($statTotalNoders > 0) {
            $str .= 'average writeups: ' . sprintf('%.2f', $statTotalWU / $statTotalNoders) . '<br />
    ';
        }
        $str .= 'total writeups: '.$statTotalWU.'<br />
    ';
        $str .= 'total noders: '.$statTotalNoders.'<br />
    ';
        $str .= 'noders with at least one writeup: ' . $statNonzeroNoders . '<br />
    ';
        $str .= 'IRON NODERS: '.$statIronNoders.'
    </p>';
}

    my $leaderLink = $isIronLeader ? '<p> &#91; '.linkNode($NODE, 'Format for writeup', {wuFormat => 'yes'}).' ]</p>' : '';

    return "<h3>IRON NODER PROGRESS for $currentYear</h3>
    $leaderLink
    $str";
}

sub historical_iron_noder_stats {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $currentYear = '2013';
    my $dateMinInc = '' . $currentYear . '-11-01';
    my $dateMaxExc = '' . $currentYear . '-12-01';
    my $triggerAchievement = $query -> param('ironise'); # option to activate achievement if iron noder period is not one calendar month

    #constants
    my $user_id = getId($USER);
    my $isGuest = $APP->isGuest($USER);
    my $isRoot = $APP->isAdmin($USER);
    my $isCE = $APP->isEditor($USER);
    my $ironLeader;
    my $isIronLeader = 0;
    my $isIronNoder = 0;

    #if there are more iron noder things later, this section should be updated to select appropriate group
    #    ironnoders    2008 November
    my $groupTitle = 'ironnoders2013';
    my @groupTypes = ('usergroup');

    my $isDaylogNode = sub {

        my $checkNode = shift;
        my $parentTitle = $$checkNode{parenttitle};

        return 1
            if $parentTitle =~ m/^(?:January|February|March|April|May|June|July|
                                    August|September|October|November|December)\s
                                    [[:digit:]]{1,2},\s[[:digit:]]{4}$/ix;
        return 1
            if $parentTitle =~ m/^(dream|editor|root) Log:/i;
        return 1
            if $parentTitle =~ m/^letters to the editors:/i;
        return 0;

    };

    my $ug = undef;
    foreach(@groupTypes) {
        $ug = getNode($groupTitle, $_);
        last if defined $ug;
}

    if(!defined $ug) {
        return 'Sorry; unable to find a list of iron noders.';
}
    #return 'found group '.linkNode($ug);


    #contains iron noder information
    #    key is user node_id
    #    value is light node ref
    my %ironNoders;

    my $str = "<h3>IRON NODER PROGRESS for $currentYear</h3>";
    $str .= '<ul>
    ';

    my $u;
    my $ironID;
    foreach my $ironID (@{$$ug{group}}) {
        $u = getNodeById($ironID, 'light');

        if(!$u) {
            $str .= '(DEBUG: unable to get user ID '.$ironID.')';
            next;
        }

        $ironLeader = $ironID if !defined $ironLeader;

        $ironNoders{$ironID} = $u;

}

    # We don't use these presently, but it might be useful in the future
    #  if we want to show special things to the organizers/members
    $isIronNoder = (defined $ironNoders{$user_id});
    $isIronLeader = ($ironLeader == $user_id);

    #writeup information setup
    my $showWUs = 1;
    my $qh = undef;
    my $typeID = getId(getType('writeup')) || undef;
    if($showWUs && !$typeID) {
        $showWUs = 0;
        $str .= '(DEBUG: unable to get writeup type)';
}

    if($showWUs) {

        my $getWriteupQuery = qq|
    SELECT
        node.node_id, node.title
        , parent.title 'parenttitle', writeup.parent_e2node
        , writeup.publishtime
        , vote.vote_id, writeup.wrtype_writeuptype, writeup.writeup_id
        FROM node
        LEFT OUTER JOIN vote
            ON
                voter_user = $user_id
                AND vote_id = node.node_id
        JOIN writeup
            ON
                node.node_id = writeup.writeup_id
        LEFT OUTER JOIN node AS parent
            ON
                writeup.parent_e2node = parent.node_id
        WHERE
            node.type_nodetype = '$typeID'
            AND node.author_user =  ?
            AND writeup.publishtime  >= ?
            AND writeup.publishtime  <  ?
        ORDER BY
            writeup.publishtime ASC|;

        $qh = $DB->{dbh}->prepare($getWriteupQuery);

        if(!$qh) {
            undef $qh;
            $showWUs = 0;
            $str .= '(DEBUG: unable to construct query for writeups)';
        }
}


    #all iron noders
    #    key is what to sort by
    #    value is light node ref
    my %ironNodersBySortKey;
    my $sortKey;
    foreach(keys(%ironNoders)) {
        #sort by username (case insensitive), and break tie by appending something arbitrary but consistent
        $sortKey = lc($ironNoders{$_}->{title}) . $ironNoders{$_}->{node_id};
        #while(exists $ironNodersBySortKey{$sortKey}) { $sortKey .= '.'; }
        $ironNodersBySortKey{ $sortKey } = $ironNoders{$_};
}

    my @displayOrder = sort(keys(%ironNodersBySortKey));
    #TODO? maybe reverse half the time to not favor items? maybe randomly split list in half (so everyone has equal chance of being somewhere in list)

    my $BIGNUMBER = 99999;
    my $WUCOUNTFORIRON = 30;
    my $MAXDAYLOGCOUNT = 5;
    my $statTotalWU = 0;
    my $statTotalNoders = 0;
    my $statNonzeroNoders = 0;
    my $statIronNoders = 0;
    my $statUserWU;
    my $statMaxCount = -1;
    my $statMinCount = $BIGNUMBER;
    my $statMinCountPositive = $BIGNUMBER;
    my $statVotedWU = 0;
    my $statYourWU = 0;

    my $htmlListUser;

    foreach my $sortKey (@displayOrder) {
        $u = $ironNodersBySortKey{$sortKey};
        $ironID = getId($u);
        unless($ironID) {
            $str .= '(DEBUG: unable to get ID for '.htmlEncode($sortKey).')';
            next;
        }

        $htmlListUser = '';

        $htmlListUser .= '<li>';
        if($showWUs) { $htmlListUser .= '<big>'; };
        $htmlListUser .= linkNode($u);
        if($showWUs) { $htmlListUser .= '</big>'; };

        if($showWUs) {
            $statUserWU = 0;

            $qh->execute(getId($u),$dateMinInc,$dateMaxExc);
            my @userWUs = ();
            while(my $r=$qh->fetchrow_hashref) {
                push(@userWUs, $r);
            }
            $qh->finish();
            my $daylogCount = 0;
            my @validWUs = grep { !$APP->isMaintenanceNode($_) } @userWUs;
            @validWUs = grep { !&$isDaylogNode($_) || ++$daylogCount <= $MAXDAYLOGCOUNT } @validWUs;

            $statUserWU = scalar(@validWUs);
            if ($daylogCount > $MAXDAYLOGCOUNT) {
                my $excess = $daylogCount - $MAXDAYLOGCOUNT;
                my $plural = $excess > 1 ? 's' : '';
                $statUserWU .= " ignoring $excess daylog$plural above the $MAXDAYLOGCOUNT limit";
            }
            $htmlListUser .= ' (' . $statUserWU . ')';

            $htmlListUser .= "<ol>\n";
            my $instructions = '<li class="&votecheck">title';
            my %functionMap = (
                votecheck => sub {
                    my $N = shift;
                    my $vote_str = '';
                    if ($$N{vote_id}) {
                        $vote_str .= ' hasvoted';
                        $statVotedWU++;
                    }
                    return $vote_str;
                },
                title => sub {
                    my $N = shift;
                    return linkNode($N, $$N{parenttitle}, { -class => 'title' } );
                }
            );

            $htmlListUser .= htmlcode('show content', \@validWUs, $instructions, %functionMap)
                . '</ol>'
                ;

            #update stats
            $statTotalNoders++;
            $statTotalWU += $statUserWU;
            if ($user_id == $ironID) { $statYourWU = $statUserWU; }
            if ($statUserWU > 0) { $statNonzeroNoders++; }
            if ($statUserWU >= $WUCOUNTFORIRON) {
                $statIronNoders++;
                htmlcode('hasAchieved', 'writeupsMonth30', $ironID, 1) if $triggerAchievement;
            }
            if($statUserWU < $statMinCount) { $statMinCount = $statUserWU; }
            if(($statUserWU < $statMinCountPositive) && ($statUserWU>0) ) { $statMinCountPositive = $statUserWU; }
            if($statUserWU > $statMaxCount) { $statMaxCount = $statUserWU; }

        }

        $htmlListUser .= "</li>\n";
        $str .= $htmlListUser;

}

    $str .= '</ul>';


    #statistics
    if($showWUs) {
        $str .= '<p><strong>Current Year Statistics</strong>:<br />
    ';
        if ($statYourWU > 0) {
            $str .= 'your writeups: '.$statYourWU.'<br />
    ';
        }
        if ($statTotalWU - $statYourWU > 0) {
            $str .= 'you have voted on '.$statVotedWU.' writeups (' . int(100 * $statVotedWU / ($statTotalWU - $statYourWU)) . '%)<br />
    ';
        }
        if($statMinCount!=$BIGNUMBER) {
            $str .= 'minimum writeups: '.$statMinCount.'<br />
    ';
        }
        if($statMinCountPositive!=$BIGNUMBER) {
            $str .= 'positive minimum writeups: '.$statMinCountPositive.'<br />
    ';
        }
        if($statMaxCount>=0) {
            $str .= 'maximum writeups: '.$statMaxCount.'<br />
    ';
        }
        if ($statTotalNoders > 0) {
            $str .= 'average writeups: ' . sprintf('%.2f', $statTotalWU / $statTotalNoders) . '<br />
    ';
        }
        $str .= 'total writeups: '.$statTotalWU.'<br />
    ';
        $str .= 'total noders: '.$statTotalNoders.'<br />
    ';
        $str .= 'noders with at least one writeup: ' . $statNonzeroNoders . '<br />
    ';
        $str .= 'IRON NODERS: '.$statIronNoders.'
    </p>';
}


    return $str;
}

sub node_tracker {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '<p><em>Finally, its time had come.</em></p>

<p>This is essentially a port of [cow of doom]\'s node tracker.
Obviously there\'s been some interface modification since we\'ve got a
direct line to the e2 database, but he did most of the heavy lifting,
and should be lauded for his hard work, [pbuh].</p>

<p>This is in beta, and things may change at any moment. To that end,
I haven\'t really messed with any of the data being collected (or much of anything else),
so if there\'s a feature you would like here or something seems off (especially if things are broken!),
please let [kthejoker|me] know.  Thanks.</p>

<p>P.S.: Do <strong>not</strong> sit here and refresh this page constantly.
It\'s not the heaviest page on the site, but it\'s not exactly the lightest either, okay?
I will hunt you down. So just visit it every once in a while, marvel at your greatness,
hit "update" to save the new data, and then head back out into the nodegel. Cool? - k</p>

';

#'

return "Sorry, for logged in users only" if ($APP->isGuest($USER));

my $trackerStr;
my %info;
my %oldinfo;
my %node;
my %oldnode;
my %types;
my @reps;
my @wudata;
my $minmerit;
my $maxmerit;
my @nodes;
my $line=' 'x65;

my ($head, $didhead, $change);


local * uniq = sub {
# takes a list argument
# assumes the list is sorted (use sort() if not)
# returns that list with duplicates removed
# examples: @foo=uniq(@sorted); @foo=uniq(sort(@random));
  my (@list, @result);
  @list = @_; @result = ();
  foreach (@list) {
    if ((!@result) || ($result[-1] != $_)) {push(@result,$_);}
  }
  return(@result);
};

my $userid=$$USER{user_id};
#my $userid = $query->param('userid') if $query->param('userid');


local * getOldInfo = sub {
my $tData = $DB->sqlSelect("tracker_data","nodetracker","tracker_user=$userid limit 1");
return 0 unless $tData;
return 1 if ($tData eq 'data');
my @tD = split(/\n/,$tData);
my $iData = shift(@tD);
my $dStr;
($oldinfo{xp}, $oldinfo{nodes}, $oldinfo{cools}, $oldinfo{totalrep}, $oldinfo{merit},
         $oldinfo{devotion}, $oldinfo{average}, $oldinfo{median}, $oldinfo{upvotes}, $oldinfo{downvotes},
         $oldinfo{maxcools},$oldinfo{maxvotes})  = split(/:/,$iData);

    $oldinfo{xp} = $oldinfo{xp} || 0;
    $oldinfo{cools} = $oldinfo{cools} ||0;
    $oldinfo{totalrep} = $oldinfo{totalrep} || 0;
    $oldinfo{nodes} = $oldinfo{nodes} ||0;
    $oldinfo{merit} = $oldinfo{merit} || 0;
    $oldinfo{devotion} = $oldinfo{devotion} || 0;
    $oldinfo{average} = $oldinfo{average} || 0;
    $oldinfo{median} = $oldinfo{median} || 0;
    $oldinfo{upvotes} = $oldinfo{upvotes} || 0;
    $oldinfo{downvotes} = $oldinfo{downvotes} || 0;
    $oldinfo{maxcools} = $oldinfo{maxcools} || 0;
    $oldinfo{maxvotes} = $oldinfo{maxvotes} || 0;
    chomp($oldinfo{xp}, $oldinfo{nodes}, $oldinfo{cools}, $oldinfo{totalrep},$oldinfo{merit},
              $oldinfo{devotion}, $oldinfo{average}, $oldinfo{median}, $oldinfo{upvotes}, $oldinfo{downvotes},
              $oldinfo{maxcools},$oldinfo{maxvotes});
    if ($oldinfo{nodes}) {
            $oldinfo{wnf} = (($oldinfo{totalrep}+(10*$oldinfo{cools}))/$oldinfo{nodes});
            $oldinfo{nodefu} = $oldinfo{xp}/$oldinfo{nodes};
            $oldinfo{coolratio} = ($oldinfo{cools}*100)/$oldinfo{nodes};
        }

foreach (@tD) {
           chomp;
            if (/^(\d+):(-?\d+):(\d+):(.+):(\d+):(\d+)$/) {
                @{$oldnode{$1}} = ($2,$3,$4,$5,$6);
            }
            elsif (/^(\d+):(-?\d+):(\d+):(.*)$/) {
                @{$oldnode{$1}} = ($2,$3,$4,0,0);
            }

            if ($oldinfo{maxrep} <= 0) {$oldinfo{maxrep}=$oldinfo{minrep}=$2;}
            if ($2 > $oldinfo{maxrep}) {$oldinfo{maxrep}=$2;}
            if ($2 < $oldinfo{minrep}) {$oldinfo{minrep}=$2;}
}

$oldinfo{votes} = $oldinfo{upvotes} + $oldinfo{downvotes};

     return 1;

};

local * infodiff = sub {
   my $arg = $_[0];
    my $diff_str = $info{$arg};
    $oldinfo{$arg} = 0 unless defined($oldinfo{$arg});
 if ($oldinfo{$arg} != $info{$arg}) {
        $diff_str .= " (".($info{$arg}>$oldinfo{$arg}?'+':'');
        $diff_str .= ($info{$arg}-$oldinfo{$arg}).")";
    }
    return $diff_str;
};

local * infodiff_fp = sub {
    my $arg = $_[0];
    my $perc = $_[1];

    my $diff_str = sprintf "%1.2f", $info{$arg};
    if (defined($perc)) {$diff_str .= '%';}

    $oldinfo{$arg} = 0 unless defined($oldinfo{$arg});

    my $diff = $info{$arg} - $oldinfo{$arg};
    if (($diff > 0.001) || ($diff < -0.001)) {
        $diff_str .= " (";
        $diff_str .= "+" if ($diff > 0);
        $diff_str .= sprintf "%1.3f%s)", $diff, defined($perc) ? "%" : "";
    }
    return($diff_str);
};

local * MakeEven = sub{
    my ($aref) = @_;
    my $len = 0;
    my $pipetext = 0; # length of undisplayed pipe link text
    # find max length of the array contents
    # note that hard/pipe link code artificially extends this with undisplayed characters
    foreach (@$aref) {
        $pipetext = 0;
        if (m/\[(.*?\|)/) {
            $pipetext = length($1);
            }
        $len = (length($_) - $pipetext) if ((length($_) - $pipetext) > $len)
    }
    foreach (@$aref) {
        if (m/--$/) {
            $_ .= "-" x ($len - length($_)) if($len - length($_) > 0);
        }
        else {
            $_ .= " " x ($len - length($_)) if($len - length($_) > 0);
        }
        # hard link characters are counted but not displayed
        # add spaces too account for them
        if (m/\[/) {
            $_ .= " ";
            if (m/\]/) { $_ .= " "; }
        }
    }
};

local * getCurrentInfo = sub {

$info{xp} = $$USER{experience};
my $csr= $DB->sqlSelectMany(
  "node.node_id, node.reputation, writeup.cooled, parent_node.title, type_node.title AS type"
  , 'node
      JOIN writeup ON node.node_id = writeup.writeup_id
    JOIN node AS parent_node ON parent_node.node_id = writeup.parent_e2node
    JOIN node AS type_node ON  type_node.node_id = writeup.wrtype_writeuptype'
  , "node.author_user = $userid AND node.type_nodetype=117"
  , 'ORDER BY writeup.publishtime DESC'
);

my $nStr = 'test';
while (my $N = $csr->fetchrow_hashref) {
        my %n;

my ($name, $type) = ($$N{title}, $$N{type});

        if (($name eq "E2 Nuke Request") or
            ($name eq "Edit these E2 titles") or
            ($name eq "Nodeshells marked for destruction") or
            ($name eq "Broken Nodes")) {
                next;
        }

        $n{name} = $name;
        $n{type} = $type;
        $n{node_id} = $$N{node_id};
        $n{reputation} = $$N{reputation};
        $n{cooled} = $$N{cooled};

        my ($votescast) = $DB->sqlSelect('count(*)', 'vote', 'vote_id='.$$N{node_id});
        $n{upvotes} = ($votescast + $$N{reputation})/2;
        $n{downvotes} = ($votescast - $$N{reputation})/2;

        if (int($n{upvotes}) != $n{upvotes}) {
            $n{downvotes} = $DB->sqlSelect('count(*)', 'vote', 'vote_id='.$$N{node_id}.' and weight=-1');
            $n{upvotes} = $votescast - $n{downvotes};
            $n{reputation} = $n{upvotes} - $n{downvotes};
        }

        $n{votes} = $n{downvotes} + $n{upvotes};

        $types{$type} = 0 unless defined($types{$type});
        $types{$type}++;
        $info{nodes}++;

        push(@reps, $n{reputation});
        $info{totalrep} += $n{reputation};
        $info{cools} += $n{cooled};
        $info{downvotes} += $n{downvotes};
        $info{upvotes} += $n{upvotes};

        if ($info{nodes} == 1) {
            $info{maxrep}=$info{minrep}=$n{reputation};
            $info{maxvotes}=$n{votes};
            $info{maxcools}=$n{cooled};
        }

        if ($n{reputation} > $info{maxrep}) {$info{maxrep}=$n{reputation}}
        if ($n{reputation} < $info{minrep}) {$info{minrep}=$n{reputation}}
        if ($n{votes} > $info{maxvotes}) {$info{maxvotes} = $n{votes}}
        if ($n{cooled} > $info{maxcools}) {$info{maxcools} = $n{cooled}}

        $node{$n{node_id}} = [$n{reputation},$n{cooled},$name,$n{upvotes},$n{downvotes}];

    }
    $info{votes} = $info{upvotes} + $info{downvotes};

    return $nStr;

};

local * meritCalc = sub {

my @rep2 = sort {$a <=> $b} @reps;

my $sz = 0 + @rep2;
return unless $sz;
my $stt = int(($sz)/4);
my $stp = int(($sz*3)/4 + 0.5);
my $tot = 0;
my $tot2 = 0;

my @counts;

for (my $i=0; $i<500; ++$i) {
   push @counts, 0;
}

for (my $i=$stt; $i<$stp; ++$i) {
   my $rep = $rep2[$i];
   $tot += $rep;
   $counts[$rep]++ if ($rep >= 0);
}


for (my $i=0; $i<500; ++$i) {
   $counts[$i] = 0;
}
my $minrep = $rep2[0];

for (my $i=0; $i<$sz; ++$i) {
   my $rep = $rep2[$i];
   $tot2 += $rep;
   $counts[$rep - $minrep]++;
}


$info{average} = $tot2/$sz;
$info{median} = $rep2[$sz/2];
$info{merit} = $tot/($stp-$stt);
$info{devotion} = int($info{merit} * @rep2 + 0.5);
$minmerit = $rep2[$stt];
$maxmerit = $rep2[$stp-1];


if ($info{nodes}) {
  $info{wnf} = (($info{totalrep}+(10*$info{cools}))/$info{nodes});
  $info{nodefu} = $info{xp}/$info{nodes};
  $info{coolratio} = ($info{cools}*100)/$info{nodes};
}
};

local * trackerOverview = sub {
$trackerStr .= sprintf("
        E2 USER INFO: last update %s
\n",
       $DB->sqlSelect("lasttime","nodetracker","tracker_user=$userid limit 1"));



my @c1;
my @c2;
my @c3;

push @c1, "Nodes:     "    . infodiff('nodes');
push @c2, "XP:          "  . infodiff('xp');
push @c3, "Cools:       "  . infodiff('cools');

push @c1, "Max Rep:   "    . infodiff('maxrep');
push @c2, "Min Rep:     "  . infodiff('minrep');
push @c3, "Total Rep:   "  . infodiff('totalrep');

push @c1, "[Node-Fu]:   "  . infodiff_fp('nodefu');
push @c2, "[Node-Fu|WNF]:         "        . infodiff_fp('wnf');
push @c3, "Cool Ratio:  "  . infodiff_fp('coolratio', 'yes');

push @c1, "[Merit]:     "  . infodiff_fp('merit');
push @c2, "Average Rep: "  . infodiff_fp('average');
push @c3, "Median rep:  "  . infodiff('median');

push @c1, "Up votes:  "     . infodiff('upvotes');
push @c2, "[Devotion]:    " . infodiff('devotion');
push @c3, "Merit Range: $minmerit to $maxmerit";

push @c1, "Max Cools: "   . infodiff('maxcools');
push @c2, "Down votes:  " . infodiff('downvotes');
push @c3, "Votes:       " . infodiff('votes');

push @c1, "Max Votes: "   . infodiff('maxvotes');


MakeEven(\@c1);
MakeEven(\@c2);

for (my $i=0; $i<7; ++$i) {
    $trackerStr .= "$c1[$i]   $c2[$i]   $c3[$i]\n";
}

$trackerStr .= "\n</pre><tt>";
};





local * trackerNodes = sub {


if ($info{nodes}) {
  foreach (keys %types) {
    $trackerStr .= sprintf("%s: %3.1f%%  ",$_,(100 * $types{$_})/($info{nodes}));
  }
}


$trackerStr .= "\n$line\n</tt><pre>";

$head="
        Published/Removed/Renamed:
Change      Title\n$line\n";
$didhead = 0;

foreach (uniq(sort({$b<=>$a} keys(%node),keys(%oldnode)))) {
    if (!exists($oldnode{$_})) {
        if (!$didhead) {$trackerStr .= $head; $didhead = 1;}
        $trackerStr .= sprintf("Published | %s\n",$node{$_}->[2]);
        $oldnode{$_} = [0,0,$node{$_}->[2]];
        push @nodes, $_;
    } elsif (!exists($node{$_})) {
        if (!$didhead) {$trackerStr .= $head; $didhead = 1;}
        $trackerStr .= sprintf("Removed   | %s\n",$oldnode{$_}->[2]);
    } else {
        if ($node{$_}->[0] != $oldnode{$_}->[0]) {push (@nodes, $_);}
        if ($node{$_}->[1] != $oldnode{$_}->[1]) {push (@nodes, $_);}
        if ($node{$_}->[3] != $oldnode{$_}->[3]) {push (@nodes, $_);}
        if ($node{$_}->[4] != $oldnode{$_}->[4]) {push (@nodes, $_);}
        if ($node{$_}->[2] ne $oldnode{$_}->[2]) {
            if (!$didhead) {$trackerStr .= $head; $didhead = 1;}
            $trackerStr .= sprintf("Renamed   | %s->%s\n",$oldnode{$_}->[2],$node{$_}->[2]);
        }
    }
}
$change = undef;
if ($didhead) {$trackerStr .= $line."\n"; $change = 1;}
};

local * trackerRep = sub {

$head="
        Reputation Changes / Cools:\n";

$didhead = 0;
my (@a1, @a2, @a3, @a4, @a5, @a6);


foreach (uniq(@nodes)) {
  if (!$didhead) {
      $trackerStr .= $head;
      $didhead = 1;

      push @a1, "Rep";
      push @a1, "   ";
      push @a2, "+/-";
      push @a2, "   ";
      push @a3, "C!";
      push @a3, "  ";
      push @a4, "+/-";
      push @a4, "   ";
      push @a5, "Title";
      push @a5, "    ";
push @a6, " ";
push @a6, " ";
  }
  $oldnode{$_}->[3] = 0 unless defined($oldnode{$_}->[3]);
  $oldnode{$_}->[4] = 0 unless defined($oldnode{$_}->[4]);
  my $d  = $node{$_}->[0]-$oldnode{$_}->[0];
  my $d1 = $node{$_}->[3]-$oldnode{$_}->[3];
  my $d2 = $node{$_}->[4]-$oldnode{$_}->[4];
  my $dcool = $node{$_}->[1] - $oldnode{$_}->[1];
  if ($node{$_}->[3] && $node{$_}->[4]) {
      push @a1, sprintf "%+i (%+i/%+i)", $node{$_}->[0], $node{$_}->[3], -$node{$_}->[4];
  }
  else {
      push @a1, sprintf "%+i", $node{$_}->[0];
  }
  if ($d1 and $d2) {
      push @a2, sprintf "%+i (%+i/%+i)", $d, $d1, -$d2;
  }
  else {
      push @a2, sprintf "%+i", $d;
  }
  push @a3, sprintf "%i", $node{$_}->[1];
  if ($dcool) {
      push @a4, sprintf "%+i", $dcool;
  }
  else {
      push @a4, "";
  }
  push @a5, $node{$_}->[2];
push @a6, $_;
}

if ($didhead) {

    MakeEven(\@a1);
    MakeEven(\@a2);
    MakeEven(\@a3);
    MakeEven(\@a4);

    for (my $i=0; $i < @a1; ++$i) {
        $trackerStr .= "$a1[$i]  $a2[$i]  $a3[$i]  $a4[$i]  ";
        if ($a6[$i] ne " ") {
                $trackerStr .= linkNode($a6[$i],"$a5[$i]")."\n";
        }
        else {
                $trackerStr .= "$a5[$i] $a6[$i]\n";
        }
    }
    $trackerStr .= "\n";
}
elsif (!$change) {
  $trackerStr .= "No nodes changed.\n";
}
};

local * updateTracker = sub {

 my $tStr = "$info{xp}:$info{nodes}:$info{cools}:$info{totalrep}:".
  "$info{merit}:$info{devotion}:$info{average}:$info{median}:$info{upvotes}:$info{downvotes}:".
  "$info{maxcools}:$info{maxvotes}\n";
   foreach (sort {$b<=>$a} keys(%node)) {
    $tStr .= "$_:".join(":",@{$node{$_}})."\n";
  }
$DB->sqlUpdate("nodetracker",{tracker_data => $tStr, -lasttime => 'now()', -hits => 'hits + 1' },"tracker_user=$userid limit 1");

return $tStr;

};



my $hasOld = getOldInfo();
if (!$hasOld) {
$DB->sqlInsert("nodetracker",{tracker_user => $userid, tracker_data => 'data'});
}
getCurrentInfo();
meritCalc();

if ($query->param("update")) {
updateTracker();
getOldInfo();
}

trackerOverview();

trackerNodes();

trackerRep();

my $finalStr = "<pre>".$trackerStr."</pre>";

$finalStr .=htmlcode('openform');
$finalStr.=$query->submit("update","Update");
$finalStr.=$query->end_form;

return $str."<br /><br />".$finalStr;
}

sub e2_color_toy {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = qq|
<noscript>
<h3>JavaScript is not available in your browser.</h3>
<p>It may be disabled, or your browser may not support it at all.
<strong>Without JavaScript, this page will not work.</strong> We apologize. </p>
<hr>
</noscript>

<style type="text/css">
<!--
.gradcell {
    position: relative;
    visibility: show;
    margin: 0px;
    padding: 0px;
}
//-->
</style>
<script language="JavaScript">
// 2069767.js colorclass.js
// Unknown usage

//  JavaScript class for handling colors
//  1/24/02

//-----------------------------------------------------------------------------
//  Named colors
var NAMED = new Object();
//  Which of the named colors are fake.
var FAKE  = new Object();
initNamedColors();

//-----------------------------------------------------------------------------
//  These are IntRange instances. They are properly initalized below, after the
//  IntRange class is fully defined.
var RGBRange    = null; //  RGB values
var HueRange    = null; //  Hue
var SatBriRange = null; //  Saturation and brightness

//-----------------------------------------------------------------------------
function zpadl( s, digits ) {
    while ( s.length < digits )
        s = "0" + s;
    return s;
}


function toHex( x, digits ) {
    var n = parseInt( x.toString() );

    if ( digits == null )
        digits = 1;

    if ( isNaN( n ) )
        n = 0;

    return zpadl(n.toString( 16 ), 2 );
}


//-----------------------------------------------------------------------------
function IntRange( low, high, dflt ) {
    this.set( low, high, dflt );
}

IntRange.prototype.low      = 0;
IntRange.prototype.high     = 255;
IntRange.prototype.dflt     = 0;

IntRange.prototype.set = function( low, high, dflt ) {
    if ( low != null ) {
        this.low = parseInt( low );
        if ( isNaN( this.low ) )
            this.low = IntRange.prototype.low;
    }

    if ( high != null ) {
        this.high = parseInt( high );
        if ( isNaN( this.high ) )
            this.high = IntRange.prototype.high;
    }

    if ( dflt != null ) {
        this.dflt = parseInt( dflt );
        if ( isNaN( this.dflt ) )
            this.dflt = IntRange.prototype.dflt;
    }

    return this;
}

//  If n is a string that might not be base 10, provide a radix
IntRange.prototype.enforceOn = function( n, radix ) {
    n = parseInt( n, radix );

    if ( isNaN( n ) )
        return this.dflt;
    else if ( n < this.low )
        return this.low;
    else if ( n > this.high )
        return this.high;
    else
        return n;
}


//-----------------------------------------------------------------------------
//  Due to the weird JS object model, IntRange() exists before we define it.
//  This is because it is declared, so it exists as soon as the file is parsed.
//  Its member functions, however, aren not added until *execution* of the file
//  gets to that point: They are assignments rather than declarations. If we do
//  this before then, we get errors because the constructor calls
//  IntRange.prototype.set, which remains undefined until we assign a function
//  object to it.
RGBRange    = new IntRange( 0, 255, 0 );    //  RGB values
HueRange    = new IntRange( 0, 419, 0 );    //  Hue
SatBriRange = new IntRange( 0, 100, 0 );    //  Saturation and brightness


//-----------------------------------------------------------------------------
function htmlColor( r, g, b ) {
    return "#" + toHex(r, 2 ) + toHex(g, 2 ) + toHex(b, 2 );
}

function namedColorValue( s ) {
    var s = NAMED[ s ];

    return ( ( "" + s ) == "undefined" ) ? "#000000" : s;
}


//-----------------------------------------------------------------------------
//  This one is the whole point.
//  Constructor:
//      Color( a, b, c )    //  If all arguments are null, default to 0, 0, 0;
//                          //  If b or c is null but a is not, call
//                          //  this.fromString( a );
//                          //  Otherwise, call this.fromRGB( a, b, c ).
//
//  Members:
//      r, g, b             //  Red, green, and blue values.
//
//      fromString( s )     //  If the first character of s is "#", s is
//                          //  presumed to be an HTML hex color string.
//                          //  Otherwise, it is presumed to be a named HTML
//                          //  color.
//
//      toString()          //  return HTML hex color string: #RRGGBB
//      fromRGB( r, g, b )  //  Initialize from red, green, and blue values
//      fromHSB( h, s, b )  //  Initialize from hue, saturation, and brightness
//      toHSB()             //  return HSB object w/ h, s, and b members
//
//      getRGBSorted()      //  return an Object with min, max, and mid members.
//                          //  We use it internally.
//-----------------------------------------------------------------------------
function Color( a, b, c ) {
    if ( a != null ) {
        if ( b == null && c == null ) {
            this.fromString( a );
        } else {
            this.fromRGB( a, b, c );
        }
    }
}

Color.prototype.r   = 0;
Color.prototype.g   = 0;
Color.prototype.b   = 0;

Color.prototype.fromRGB = function( r, g, b ) {
    this.r = RGBRange.enforceOn( r );
    this.g = RGBRange.enforceOn( g );
    this.b = RGBRange.enforceOn( b );

    return this;
}

Color.prototype.toString = function() {
    return htmlColor( this.r, this.g, this.b );
}

Color.prototype.fromString = function( s ) {
    s = (s + "").toString();

    if ( s.substr( 0, 1 ) != "#" )
        s = namedColorValue( s );

    s = zpadl( s.replace( /^[^0-9a-f]/gi, "" ), 6 );

    var clrs = s.match( /([0-9a-f][0-9a-f])/gi );

    this.r = RGBRange.enforceOn( clrs[ 0 ], 16 );
    this.g = RGBRange.enforceOn( clrs[ 1 ], 16 );
    this.b = RGBRange.enforceOn( clrs[ 2 ], 16 );

    return this;
}

Color.prototype.fromHSB = function( hue, sat, bright ) {
    sat /= 100;
    bright /= 100;

    if ( sat == 0 ) {
        this.r = bright;
        this.g = bright;
        this.b = bright;

        return this;
    } else {
        hue = hue / 60;
        var i = Math.floor( hue );
        var f = hue - i;
        var p = bright * ( 1.0 - sat );
        var q = bright * ( 1.0 - sat * f );
        var t = bright * ( 1.0 - sat * ( 1.0 - f ) );

        bright *= 255;
        t *= 255;
        p *= 255;
        q *= 255;

        switch ( i ) {
            case 0:
                return this.fromRGB( bright, t, p );

            case 1:
                return this.fromRGB( q, bright, p );

            case 2:
                return this.fromRGB( p, bright, t );

            case 3:
                return this.fromRGB( p, q, bright );

            case 4:
                return this.fromRGB( t, p, bright );

            default:
                return this.fromRGB( bright, p, q );
        }
    }
}


Color.prototype.getRGBSorted = function() {
    var ary = new Array( this.r, this.b, this.g );

    //  Make sure we sort these as integers, not strings.
    //  According to Netscape JS documentation, the callback will not work with
    //  some pre-v4 versions of Netscape on some platforms. Or something. Maybe
    //  it was version 2.
    ary.sort( function( a, b ) { return parseInt( a ) - parseInt( b ); } );

    /*
    var rtn = new Object();

    rtn.min = ary[ 0 ];
    rtn.mid = ary[ 1 ];
    rtn.max = ary[ 2 ];

    alert( rtn.toSource() );

    return rtn;
    */

    //  Object literal. Ph334r my 1337 skillz.
    return { min: ary[ 0 ], mid: ary[ 1 ], max: ary[ 2 ] };
}


Color.prototype.toHSB = function() {
    var domainBase      = 0;
    var domainOffset    = 0;

    var hsb = new HSB();
    var mmm = this.getRGBSorted();

    if ( mmm.max == 0 ) {
        hsb.b = 0;
        hsb.s = 0;
    } else {
        hsb.b = mmm.max / 255;
        hsb.s = ( hsb.b - ( mmm.min / 255.0 ) ) / hsb.b;
    }

    var oneSixth = 1.0 / 6.0;

    domainOffset = ( mmm.mid - mmm.min ) / ( mmm.max - mmm.min ) / 6.0;

    if ( mmm.max == mmm.min ) {
        hsb.h = 0;
    } else {
        if ( this.r == mmm.max ) {
            if ( mmm.mid == this.g ) {
                domainBase = 0 / 6.0;
            } else {
                domainBase = 5 / 6.0;
                domainOffset = oneSixth - domainOffset;
            }
        } else if ( this.g == mmm.max ) {
            if ( mmm.mid == this.b ) {
                domainBase = 2 / 6.0;
            } else {
                domainBase = 1 / 6.0;
                domainOffset = oneSixth - domainOffset;
            }
        } else {
            if ( mmm.mid == this.r ) {
                domainBase = 4 / 6.0;
            } else {
                domainBase = 3 / 6.0;
                domainOffset = oneSixth - domainOffset;
            }
        }

        hsb.h = domainBase + domainOffset;
    }

    hsb.h = Math.round( hsb.h * 360 );
    hsb.s = Math.round( hsb.s * 100 );
    hsb.b = Math.round( hsb.b * 100 );

    return hsb.integerize();
}


//-----------------------------------------------------------------------------
//  This HSB class is primitive. Think of it as a struct with functions rather
//  than a real class. It exists only so Color.toHSB() has a type to return.
//-----------------------------------------------------------------------------
function HSB( h, s, b ) {
    this.h = h \|\| 0;
    this.s = s \|\| 0;
    this.b = b \|\| 0;
}

HSB.prototype.integerize = function() {
    this.h = parseInt( this.h );
    this.s = parseInt( this.s );
    this.b = parseInt( this.b );

    return this;
}

HSB.prototype.toString = function() {
    return this.toColor().toString();
}


HSB.prototype.toColor = function() {
    return new Color().fromHSB( this.h, this.s, this.b );
}


//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
function initNamedColors() {
    NAMED[ "snow" ]                 = "#fffafa";
    NAMED[ "ghostwhite" ]           = "#f8f8ff";
    NAMED[ "whitesmoke" ]           = "#f5f5f5";
    NAMED[ "gainsboro" ]            = "#dcdcdc";
    NAMED[ "floralwhite" ]          = "#fffaf0";
    NAMED[ "oldlace" ]              = "#fdf5e6";
    NAMED[ "linen" ]                = "#faf0e6";
    NAMED[ "antiquewhite" ]         = "#faebd7";
    NAMED[ "papayawhip" ]           = "#ffefd5";
    NAMED[ "blanchedalmond" ]       = "#ffebcd";
    NAMED[ "bisque" ]               = "#ffe4c4";
    NAMED[ "peachpuff" ]            = "#ffdab9";
    NAMED[ "navajowhite" ]          = "#ffdead";
    NAMED[ "moccasin" ]             = "#ffe4b5";
    NAMED[ "cornsilk" ]             = "#fff8dc";
    NAMED[ "ivory" ]                = "#fffff0";
    NAMED[ "lemonchiffon" ]         = "#fffacd";
    NAMED[ "seashell" ]             = "#fff5ee";
    NAMED[ "honeydew" ]             = "#f0fff0";
    NAMED[ "mintcream" ]            = "#f5fffa";
    NAMED[ "azure" ]                = "#f0ffff";
    NAMED[ "aliceblue" ]            = "#f0f8ff";
    NAMED[ "lavender" ]             = "#e6e6fa";
    NAMED[ "lavenderblush" ]        = "#fff0f5";
    NAMED[ "mistyrose" ]            = "#ffe4e1";
    NAMED[ "white" ]                = "#ffffff";
    NAMED[ "black" ]                = "#000000";
    NAMED[ "darkslategray" ]        = "#2f4f4f";
    NAMED[ "dimgray" ]              = "#696969";
    NAMED[ "slategray" ]            = "#708090";
    NAMED[ "lightslategray" ]       = "#778899";
    NAMED[ "gray" ]                 = "#bebebe";
    NAMED[ "lightgray" ]            = "#d3d3d3";
    NAMED[ "midnightblue" ]         = "#191970";
    NAMED[ "cornflowerblue" ]       = "#6495ed";
    NAMED[ "darkslateblue" ]        = "#483d8b";
    NAMED[ "slateblue" ]            = "#6a5acd";
    NAMED[ "mediumslateblue" ]      = "#7b68ee";
    NAMED[ "mediumblue" ]           = "#0000cd";
    NAMED[ "royalblue" ]            = "#4169e1";
    NAMED[ "blue" ]                 = "#0000ff";
    NAMED[ "dodgerblue" ]           = "#1e90ff";
    NAMED[ "deepskyblue" ]          = "#00bfff";
    NAMED[ "skyblue" ]              = "#87ceeb";
    NAMED[ "lightskyblue" ]         = "#87cefa";
    NAMED[ "steelblue" ]            = "#4682b4";
    NAMED[ "lightsteelblue" ]       = "#b0c4de";
    NAMED[ "lightblue" ]            = "#add8e6";
    NAMED[ "powderblue" ]           = "#b0e0e6";
    NAMED[ "paleturquoise" ]        = "#afeeee";
    NAMED[ "darkturquoise" ]        = "#00ced1";
    NAMED[ "mediumturquoise" ]      = "#48d1cc";
    NAMED[ "turquoise" ]            = "#40e0d0";
    NAMED[ "cyan" ]                 = "#00ffff";
    NAMED[ "lightcyan" ]            = "#e0ffff";
    NAMED[ "cadetblue" ]            = "#5f9ea0";
    NAMED[ "mediumaquamarine" ]     = "#66cdaa";
    NAMED[ "aquamarine" ]           = "#7fffd4";
    NAMED[ "darkgreen" ]            = "#006400";
    NAMED[ "darkolivegreen" ]       = "#556b2f";
    NAMED[ "darkseagreen" ]         = "#8fbc8f";
    NAMED[ "seagreen" ]             = "#2e8b57";
    NAMED[ "mediumseagreen" ]       = "#3cb371";
    NAMED[ "lightseagreen" ]        = "#20b2aa";
    NAMED[ "palegreen" ]            = "#98fb98";
    NAMED[ "springgreen" ]          = "#00ff7f";
    NAMED[ "lawngreen" ]            = "#7cfc00";
    NAMED[ "chartreuse" ]           = "#7fff00";
    NAMED[ "greenyellow" ]          = "#adff2f";
    NAMED[ "limegreen" ]            = "#32cd32";
    NAMED[ "forestgreen" ]          = "#228b22";
    NAMED[ "green" ]                = "#00ff00";
    NAMED[ "olivedrab" ]            = "#6b8e23";
    NAMED[ "yellowgreen" ]          = "#9acd32";
    NAMED[ "darkkhaki" ]            = "#bdb76b";
    NAMED[ "palegoldenrod" ]        = "#eee8aa";
    NAMED[ "lightgoldenrodyellow" ] = "#fafad2";
    NAMED[ "lightyellow" ]          = "#ffffe0";
    NAMED[ "yellow" ]               = "#ffff00";
    NAMED[ "gold" ]                 = "#ffd700";
    NAMED[ "goldenrod" ]            = "#daa520";
    NAMED[ "darkgoldenrod" ]        = "#b8860b";
    NAMED[ "rosybrown" ]            = "#bc8f8f";
    NAMED[ "indianred" ]            = "#cd5c5c";
    NAMED[ "saddlebrown" ]          = "#8b4513";
    NAMED[ "sienna" ]               = "#a0522d";
    NAMED[ "peru" ]                 = "#cd853f";
    NAMED[ "burlywood" ]            = "#deb887";
    NAMED[ "beige" ]                = "#f5f5dc";
    NAMED[ "wheat" ]                = "#f5deb3";
    NAMED[ "sandybrown" ]           = "#f4a460";
    NAMED[ "tan" ]                  = "#d2b48c";
    NAMED[ "chocolate" ]            = "#d2691e";
    NAMED[ "firebrick" ]            = "#b22222";
    NAMED[ "brown" ]                = "#a52a2a";
    NAMED[ "darksalmon" ]           = "#e9967a";
    NAMED[ "salmon" ]               = "#fa8072";
    NAMED[ "lightsalmon" ]          = "#ffa07a";
    NAMED[ "orange" ]               = "#ffa500";
    NAMED[ "darkorange" ]           = "#ff8c00";
    NAMED[ "coral" ]                = "#ff7f50";
    NAMED[ "lightcoral" ]           = "#f08080";
    NAMED[ "tomato" ]               = "#ff6347";
    NAMED[ "orangered" ]            = "#ff4500";
    NAMED[ "red" ]                  = "#ff0000";
    NAMED[ "hotpink" ]              = "#ff69b4";
    NAMED[ "deeppink" ]             = "#ff1493";
    NAMED[ "pink" ]                 = "#ffc0cb";
    NAMED[ "lightpink" ]            = "#ffb6c1";
    NAMED[ "palevioletred" ]        = "#db7093";
    NAMED[ "maroon" ]               = "#b03060";
    NAMED[ "mediumvioletred" ]      = "#c71585";
    NAMED[ "magenta" ]              = "#ff00ff";
    NAMED[ "violet" ]               = "#ee82ee";
    NAMED[ "plum" ]                 = "#dda0dd";
    NAMED[ "orchid" ]               = "#da70d6";
    NAMED[ "mediumorchid" ]         = "#ba55d3";
    NAMED[ "darkorchid" ]           = "#9932cc";
    NAMED[ "darkviolet" ]           = "#9400d3";
    NAMED[ "blueviolet" ]           = "#8a2be2";
    NAMED[ "purple" ]               = "#a020f0";
    NAMED[ "mediumpurple" ]         = "#9370db";
    NAMED[ "thistle" ]              = "#d8bfd8";
    //  fake
    NAMED[ "wharfkhaki" ]           = "#d5d1c1";
    NAMED[ "wharfolive" ]           = "#6e6d56";
    NAMED[ "jukkaback" ]            = "#ddddbb";
    NAMED[ "jukkaodd" ]             = "#cccc99";
    NAMED[ "jukkabrown" ]           = "#7e7e66";

    FAKE[ "wharfkhaki" ]        = true;
    FAKE[ "wharfolive" ]        = true;
    FAKE[ "jukkaback" ]         = true;
    FAKE[ "jukkaodd" ]          = true;
    FAKE[ "jukkabrown" ]        = true;
}

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

<!--
//  Named HTML colors
var IS_NS4      = (     navigator.appName == "Netscape"
                    &&  navigator.userAgent.indexOf( 'Mozilla/5' ) == -1 );
var obj_ref     = ( IS_NS4 ) ? ns_obj_ref : ie_obj_ref;
//  This should, obviously, be a member function. However, IE 5.5 seems to have
//  some kind of issue with that.
var setBGColor  = ( IS_NS4 ) ? ns_setBGColor : ie_setBGColor;

//------------------------------------------------------------------------------
function ie_obj_ref( parent, name ) {
    //  This works w/ Opera 5+ (dunno 'bout 4), Mozilla, and IE 5+ (dunno 'bout
    //  IE4; parent[ name ] is known to work with IE 4, but not with Mozilla)
    return parent.getElementById( name );
}

function ns_obj_ref( parent, name ) {
    return parent[ name ];
}

function ie_setBGColor( obj, clr ) {
    obj.style.backgroundColor = clr;
}

function ns_setBGColor( obj, clr ) {
    obj.bgColor = clr;
}

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

function on_use_HSB( frm ) {
    frm.hue.value       = HueRange.enforceOn( frm.hue.value );
    frm.sat.value       = SatBriRange.enforceOn( frm.sat.value );
    frm.bright.value    = SatBriRange.enforceOn( frm.bright.value );

    var clr = new Color().fromHSB( frm.hue.value, frm.sat.value, frm.bright.value );

    frm.r.value = clr.r;
    frm.g.value = clr.g;
    frm.b.value = clr.b;

    frm.hex.value = clr.toString();

    var cell = obj_ref( document, 'dechex' );
    setBGColor( cell, clr.toString() );
}

function on_use_RGB( frm ) {
    frm.r.value = RGBRange.enforceOn( frm.r.value );
    frm.g.value = RGBRange.enforceOn( frm.g.value );
    frm.b.value = RGBRange.enforceOn( frm.b.value );

    var clr = new Color( frm.r.value, frm.g.value, frm.b.value );
    frm.hex.value = clr;

    var hsb = clr.toHSB();
    frm.hue.value       = hsb.h;
    frm.sat.value       = hsb.s;
    frm.bright.value    = hsb.b;

    var cell = obj_ref( document, 'dechex' );
    setBGColor( cell, clr.toString() );
}

function on_use_hex( frm ) {
    var clr = new Color( frm.hex.value );

    if ( frm.nametohex.checked )
        frm.hex.value = clr;

    frm.r.value = clr.r;
    frm.g.value = clr.g;
    frm.b.value = clr.b;

    var hsb = clr.toHSB();
    frm.hue.value       = hsb.h;
    frm.sat.value       = hsb.s;
    frm.bright.value    = hsb.b;

    var cell = obj_ref( document, 'dechex' );
    setBGColor( cell, clr.toString() );
}

function use_in_grad( value, which ) {
    document.forms.grad[ which ].value = value;
    on_gengrad( document.forms.grad );
}

function on_gengrad( frm ) {
    var from    = new Color( frm.from.value );
    var to      = new Color( frm.to.value );
    var cell    = null;
    var inc     = new Object(); //  Signed increments for each color

    if ( frm.nametohex.checked ) {
        frm.from.value  = from;
        frm.to.value    = to;
    }

    inc.r   = ( to.r - from.r ) / 15;
    inc.g   = ( to.g - from.g ) / 15;
    inc.b   = ( to.b - from.b ) / 15;

    var clr = new Color( from );

    var hexes = '';

    for ( i = 0; i < 15; ++i ) {
        cell = obj_ref( document, 'grad' + i );
        setBGColor( cell, clr.toString() );
        hexes += clr.toString() + '\\n';
        clr.r += inc.r;
        clr.g += inc.g;
        clr.b += inc.b;
    }

    cell = obj_ref( document, 'grad' + i );
    setBGColor( cell, to.toString() );
    hexes += to.toString() + '\\n';

    frm.output.value = hexes;

    frm.output.select();
    frm.output.focus();
}
//-->
</script>

<form name="color">
<table border="0">

<tr valign="top">
<td>
<input type="button" value="Use" onclick="on_use_HSB( document.forms.color )" />
<small>Hue:</small> <input type="text" size="4" name="hue" value="0" />
<small>Saturation:</small> <input type="text" size="4" name="sat" value="0" />
<small>Brightness:</small> <input type="text" size="4" name="bright" value="0" />
</td>
<td><small><i>Hue must be 0..419; S/B values must be 0..100.</i></small></td>
</tr>

<tr valign="top">
<td>
<input type="button" value="Use" onclick="on_use_RGB( document.forms.color )" />
<small>Red:</small> <input type="text" size="4" name="r" value="0" />
<small>Green:</small> <input type="text" size="4" name="g" value="0" />
<small>Blue:</small> <input type="text" size="4" name="b" value="0" />
</td>
<td><small><i>R/G/B values must be 0..255.</i></small></td>
</tr>

<tr valign="top">
<td>
<input type="button" value="Use" onclick="on_use_hex( document.forms.color )" />
Hex/<a href="/index.pl?node=Named%20HTML%20Colors">named</a>:
<input type="text" size="12" name="hex" value="#000000" />
<br />
<input type="checkbox" name="nametohex" __checked>Convert named colors to hex</input>
</td>
<td><small><i>Hex fields will also accept <a href="/index.pl?node=Named%20HTML%20Colors">HTML color
names</a> like </i><tt>dodgerblue</tt><i> etc.</i></small></td>
</tr>

</table>

<input type="button" value="Use Hex for Gradient From"
    onclick="use_in_grad( document.forms.color.hex.value, 'from' );" />
<input type="button" value="Use Hex for Gradient To"
    onclick="use_in_grad( document.forms.color.hex.value, 'to' );" />

</form>

<div class="gradcell" id="dechex" width="64px" height="32px">
<img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="48" height="24" />
</div>

<hr>
<form name="grad">
From <input type="text" size="12" name="from" value="#ffffff" /> to
<input type="text" size="12" name="to" value="#000000" />
<input type="button" value="Generate Gradient" onclick="on_gengrad( document.forms.grad )" />
<br />
<input type="checkbox" name="nametohex" __checked>Convert named colors to hex</input>
<table cellpadding="0" cellspacing="0" border="0">
<tr>
<td><div class="gradcell" id="grad0" ><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad1" ><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad2" ><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad3" ><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad4" ><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad5" ><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad6" ><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad7" ><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad8" ><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad9" ><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad10"><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad11"><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad12"><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad13"><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad14"><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
<td><div class="gradcell" id="grad15"><img src="https://s3.amazonaws.com/static.everything2.com/dot.gif" width="24" height="24" /></div></td>
</tr>
<tr align="center">
<td>1</td><td>2</td><td>3</td><td>4</td>
<td>5</td><td>6</td><td>7</td><td>8</td>
<td>9</td><td>10</td><td>11</td><td>12</td>
<td>13</td><td>14</td><td>15</td><td>16</td>
</tr>
</table>

<textarea name="output" rows="17" cols="16"></textarea>

</form>

<p>Additional "fake" named colors: <tt>wharfkhaki, wharfolive, jukkaback,
jukkaodd, jukkabrown</tt>. </p>

<hr>
<script>
<!--
function on_bugrep( frm ) {
    function repl( m0, m1 ) {
        switch ( m1 ) {
            case '[':   return '&#91;';
            case ']':   return '&#93;';
            case '<':   return '&lt;';
            case '>':   return '&gt;';
            default:    return m1;
        }
    }

    var uastr = (navigator.userAgent + '').replace( /([\[\]<>])/g, repl );
    frm.message.value =   '/msg wharfinger &#91;' + uastr + '&#93; '
                        + frm.explain.value;

    return true;
}
//-->
</script>
<p>If you're having trouble with this page, explain briefly and click here:<br />|;

    $str .= htmlcode('openform2', 'bugrep');

    $str .= qq{
<input type="hidden" name="op" value="message" />
<input type="hidden" name="message" />
<input type="text" size="40" maxlength="150" name="explain" />
<input type="submit" name="message_send" value="Bug Report" onclick="return on_bugrep( document.forms.bugrep );"/>
</form>
</p>
<br /><br />
<p><i>Comments, complaints, offers one can't refuse, etc. all go
to <a href="/index.pl?node_id=470183">wharfinger</a>.</i> </p>

<p><i>In Opera 5, the hex and decimal values will be displayed, but
not the colors. See
<a href="http://www.opera.com/docs/specs/js/">Opera's DOM specs</a>:
They claim that as of version 6, they still don't support the</i>
<tt>backgroundColor</tt> <i>attribute. However, I've gotten reports
from Win32 Opera 6 users saying that the colors work fine. They're
definitely not working for me in Opera 5, though. That's a tough one
to work around, but I'll see what I can do. I never advise anybody
to "upgrade"; it's your life, use your own judgement. </i>
</p>

<p><i>Other than that, we seem to work properly with Mozilla 0.9.5
(K-Meleon), Netscape 4, and IE 5.5 (Win32 for all three). If you're
using IE4, or if you're using anything at all on Linux/UNIX, Mac,
BeOS, Amiga, CPM-80, 16-bit Windows, Multics, or the Timex Sinclair,
I'd like to hear from you.</i></p>

<p><i>[StarryNight] tells me that OmniWeb 4.0.6 on Mac is a no-go
with this. [cbustapeck] is seeing problems with [icab] pre2.6 on
MacOS 9.2.2 but not MacOS 10.1.2. A few weeks later: [cbustapeck]
just let me know that icab pre2.6 has expired, and all is well on
[icab] pre2.71, on MacOS 9.2.2 and X.
</i></p>};

    return $str;
}

sub e2_word_counter {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = q{
<script language="JavaScript">
<!--
function word_count( str ) {
//    var tagregex = new RegExp( '<\x5b^>\x5d*>', "g" );
    //   I get away with the square brackets because this is a superdocnolinks node.
    var tagregex = new RegExp( '<[^>]*>', "g" );
    str = str.replace( tagregex, ' ' );

    var words = str.split( /[ \t\r\n]+/ );
    alert( words.length + ' words in text.' );

    return false;
}
//-->
</script>

<noscript>
<p><font color="c00000"><strong>This won't work</strong> because
you either a) don't have JavaScript at all, or b) have it turned off. </p>
</noscript>

<p>This ignores HTML tags. If there's an HTML tag in the <em>middle</em>
of a word, that'll count as two words. Other than that, it splits words only by
whitespace, so if you're one of those "foo--bar" people with em-dashes,
you're <strong>doomed</strong>. It might be a couple words off anyway. </p>

<form name="wc">
<textarea cols="50" rows="20" name="text"></textarea><br />
<input type="button" value="Count the Words" onclick="word_count( document.forms.wc.text.value )"></input>
</form>};

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

sub the_killing_floor_ii {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '';

    $str .= htmlcode('openform');

    my $UID = getId($USER);
    return ($$USER{title} . ' ain\'t allowed ta squash nuttin\'!') unless $APP->isEditor($USER);
    my $NOPARENT = '<p><strong>Nothing to remove!</strong>
	(Either the writeups had been removed by the time you got here,
	or they were insured,
	or you forgot to check the little "axe" box on at least 1 writeup.)</p>';

    my $edLink = linkNode($USER,0,{lastnode_id=>0});

    $str .= 'Are ya shure ya wanna beat up on all thez perty writeups?
	<table border="1" cellpadding="5" cellspacing="0">
	<tr><th>shhh</th><th>reason</th><th>title</th><th>node_id</th>
	<th>author</th></tr>'."\n";

    my $alsoHTML = ($VARS->{killfloor_showlinks} ? 1 : 0);
    my $strHTML = ''; #contains version to copy and paste into editor logs

    my (@param) = $query->param;

    my $parent;
    my $nid;
    my $optNoPain;
    my $optInstant;
    my $t;
    my $wuaid;      #WU author ID
    my $wuAuthor;
    foreach(@param) {
        next unless /removenode(\d+)/;
        $nid = $1;
        next unless $query->param('removenode'.$nid); # just existing is not enough

        my $N = getNodeById($nid);
        next unless $N and $$N{type}{title} eq 'writeup';
        $str .= '<tr>';
        if($$N{publication_status}) {
            $str .= '<td colspan="8">' . linkNode($N) . ' by ' . linkNode($$N{author_user})
            .' is '.getNodeById($$N{publication_status})->{title};
            next;
        }
        $parent = $$N{parent_e2node};

        $optNoPain = defined $query->param('nopain'.$nid);
        $optInstant = $query->param('instakill'.$nid);
        $wuaid = $$N{author_user} || 0;
        $wuAuthor = getNodeById($wuaid);

        $str .= '<td>';
        $str .= '<input type="checkbox" name="noklapmsg'.$nid.'" value="1">' if $wuaid==$UID;

        $str .= '</td><td>';

        $str .= $query->textfield('removereason'.$nid,'',50).'</td><td>';
        $str.="<input type=\"hidden\" name=\"$_\" value=\"1\">";

        $str.="<input type=\"hidden\" name=\"instakill$nid\" value=\"1\">" if $optInstant;
        $str.= linkNode($N) . '</td><td>' . $$N{node_id} . '</td><td>' . ((defined $wuAuthor)
            ? linkNode($wuAuthor).' <small>('
             .htmlcode('timesince', $wuAuthor->{lasttime}.',1').')</small>'
            : '(deleted user; node_id='.$wuaid.')'
        )."</td></tr>\n";

        if($alsoHTML) {
            $strHTML .= '&lt;li&gt;&#91;';
            $t = $$N{title};
            if($t =~ /^(.*) \((\w+)\)$/) {
                $strHTML .= $1 . '&#93; ('. $2 .')';
            } else {
                $strHTML .= $t . '&#93;';
            }
            $strHTML .= (defined $wuAuthor)
                ? ' by &#91;'.($wuAuthor->{title}).'&#93;'
                : ' by a removed user (node_id='.$wuaid.')'
            ;
            $strHTML .= ' (mercifully)' if $optNoPain;
            $strHTML .= "&lt;/li&gt;\n";
        }
    }
    $str .= '</table><p><small>
<strong>shhh</strong>: If checked, no message is sent. This is only enabled if you\'re removing
your own writeup.<br>
<strong>reason</strong>: this optional message is sent by you, and the user gets it unless the
user disables kill notification in their '.linkNodeTitle('user settings').'; see '
.linkNodeTitle('E2 FAQ: Klaproth').' for more information
</small></p>';
    if($alsoHTML) {
        $str .= "<p>You can use this to copy-n-paste into an editor log:\n<br>
<textarea rows=\"10\" cols=\"65\">&lt;ul&gt;\n" . $strHTML . "&lt;/ul&gt;</textarea>\n";
    }
    return $NOPARENT . $str . $NOPARENT unless $parent;
    $str.='<p align="right">'.$query->submit('op','remove');
    $str.='<p>'.linkNode($parent, 'Changed my mind.');
    $str.=$query->end_form;

    return $str;
}

sub zenmastery {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = qq{
<h2>About this page</h2>

<p>Welcome to Zenmastery, the demonstration node where you can view staff-only options to
style them properly in your Zen Stylesheet.  The nodelets below are encased in a DIV
called <tt>id="zenmastery_sidebar"</tt>.  This will allow you to tinker with a false sidebar
DIV without interfering with the real sidebar on your layout.</p>

<p>For your convenience, the HTML has been cleaned up a bit to make it easier to find the IDs and
Classes you need to reference.  All forms are still intact but they are neutered, they can't
actually set or change anything.  All links go to the homepage.  These are for demonstration
purposes only.</p>

<p>Also see };

    $str .= linkNodeTitle('The Nodelets');

    $str .= q|
 for a list of all the available nodelets
that are not currently in your sidebar.

<h3>New Writeups</h3>

<p>The staff-only options in|;

    $str .= parseLinks('[New Writeups[nodelet]|New Writeups]');

    $str .= qq{
 are:
<dl>
<dt>R:-5<dd>Signals that a writeup currently has a negative rep (Not given a class)
<dt>(h?)<dd>Link to "hide" a writeup from New Writeups. Class: 'hide'
<dt>(H: un-h!)<dd>Link to "unhide" a writeup from new Writeups. Class: 'hide'
<dt>(X)<dd>Marks writeups that have been nuked (Not given a class)
</dl>
<p>(The same controls are also present in the };

    $str .= linkNodeTitle('[New Logs[nodelet]|New Logs nodelet]');

    $str .= qq{;
.)
</p>

<h3>Master Control</h3>

<p>Master Control is a staff-only nodelet.  Most of it is self-explanatory, but the Node Notes are
a special section that allows staff members to add commentary to a node to coordinate their
efforts so they don't accidentally work at cross-purposes to each other.  For example one editor
might note "I'm working with the author to improve this writeup." so another editor doesn't
nuke it.</p>

<h3>Front Page News/weblogs</h3>

<p>Staff may be shown who linked a writeup or other document to a weblog or to the front page news
if that person is not the author of the document. Imaginatively enough, the information is in a div
with class 'linkedby'. They also get a link allowing them to remove the document from the weblog, with
class 'remove'.
</p>

<div id="zenmastery_sidebar">

<div class='nodelet' id='newwriteups'>
	<h2 class="nodelet_title">New Writeups</h2>
	<div class='nodelet_content'>
		<form>
			<input type="hidden">
			<input type='hidden'>
			<input type="hidden">
			<select>
				<option value="1">1</option>
				<option value="5">5</option>
				<option value="10">10</option>
				<option value="15">15</option>
				<option value="20">20</option>
				<option value="25" selected="selected">25</option>
				<option value="30">30</option>
				<option value="40">40</option>
			</select>
			<input type="submit" value='show'>
			<label>
				<input type="checkbox" name="nw_nojunk" value="">
					No junk
			</label>
			<div>
				<input type="hidden">
			</div>
		</form>

		<ul class="infolist">
			<li class="contentinfo ">
				<a class="title" href="/">writeup1</a>
				<span class="type">(<a href="/">idea</a>)</span>
				<cite>by <a href="/" class="author">rootbeer277</a></cite>
				<span class="admin">
					<span class="hide">(<a href="/">h?</a>)</span>
				</span>
			</li>
			<li class="contentinfo ">
				<a class="title" href="/">writeup2</a>
				<span class="type">(<a href="/">fiction</a>)</span>
				<cite>by <a href="/" class="author">rootbeer277</a></cite>
				<span class="admin">
					<span class="hide">(<a href="/">h?</a>)</span>
				</span>
			</li>
			<li class="contentinfo ">
				<a class="title" href="/">writeup3</a>
				<span class="type">(<a href="/">person</a>)</span>
				<cite>by <a href="/" class="author">rootbeer277</a></cite>
				<span class="admin">
					<span class="hide">(<a href="/">h?</a>)</span>
				</span>
			</li>
			<li class="contentinfo ">
				<a class="title" href="/">writeup4</a>
				<span class="type">(<a href="/">log</a>)</span>
				<cite>by <a href="/" class="author">rootbeer277</a></cite>
				<span class="admin">
					<span class="hide">(<a href="/">h?</a>)</span>
				</span>
			</li>
			<li class="contentinfo ">
				<a class="title" href="/">writeup5</a>
				<span class="type">(<a href="/">person</a>)</span>
				<cite>by <a href="/" class="author">rootbeer277</a></cite>
				<span class="admin">
					R:-1
					<span class="hide">(<a href="/">h?</a>)</span>
				</span>
			</li>
			<li class="contentinfo ">
				<a class="title" href="/">writeup6</a>
				<span class="type">(<a href="/">person</a>)</span>
				<cite>by <a href="/" class="author">rootbeer277</a></cite>
				<span class="admin">
					R:-1
					<span class="hide">(<a href="/">h?</a>)</span>
				</span>
			</li>
			<li class="contentinfo ">
				<a class="title" href="/">writeup7</a>
				<span class="type">(<a href="/">idea</a>)</span>
				<cite>by <a href="/" class="author">rootbeer277</a></cite>
				<span class="admin">
					R:-1
					<span class="hide">(<a href="/">h?</a>)</span>
				</span>
			</li>
			<li class="contentinfo  hasvoted">
				<a class="title" href="/">writeup8</a>
				<span class="type">(<a href="/">person</a>)</span>
				<cite>by <a href="/" class="author">rootbeer277</a></cite>
				<span class="admin">
					<span class="hide">(<a href="/">h?</a>)</span>
				</span>
			</li>
			<li class="contentinfo  wu_hide">
				<a class="title" href="/">writeup9</a>
				<span class="type">(<a href="/">person</a>)</span>
				<cite>by <a href="/" class="author">rootbeer277</a></cite>
				<span class="admin">
					<span class="hide">(H: <a href="/">un-h!</a>)</span>
					(X)
				</span>
			</li>
			<li class="contentinfo ">
				<a class="title" href="/">writeup10</a>
				<span class="type">(<a href="/">review</a>)</span>
				<cite>by <a href="/" class="author">rootbeer277</a></cite>
				<span class="admin">
					<span class="hide">(<a href="/">h?</a>)</span>
				</span>
			</li>
			<li class="contentinfo  wu_hide">
				<a class="title" href="/">writeup11</a>
				<span class="type">(<a href="/">dream</a>)</span>
				<cite>by <a href="/" class="author">rootbeer277</a></cite>
				<span class="admin">
					R:-1
					<span class="hide">(H: <a href="/">un-h!</a>)</span>
				</span>
			</li>
			<li class="contentinfo ">
				<a class="title" href="/">writeup12</a>
				<span class="type">(<a href="/">idea</a>)</span>
				<cite>by <a href="/" class="author">rootbeer277</a></cite>
				<span class="admin">
					<span class="hide">(<a href="/">h?</a>)</span>
				</span>
			</li>
		</ul>

		<div class="nodeletfoot morelink">(<a href="/node/superdoc/Writeups+by+Type">more</a>)</div>

	</div>
</div>

<div class='nodelet' id='mastercontrol'>
	<h2 class="nodelet_title">Master Control</h2>
	<div class='nodelet_content'>

		<div class="nodelet_section">
			<h4 class="ns_title">Node Info</h4>
			<span class="rightmenu">
				<span class='var_label'>node_id:</span> <span class='var_value'>1986688</span>
				<span class='var_label'>nodetype:</span> <span class='var_value'><a href="/index.pl">superdocnolinks</a></span>
				<span class='var_label'>Server:</span> <span class='var_value'>web5</span>
				<p></p>

				<form>
					<label for ="node">Name:</label>
					<input type="text" name="node" value="zenmastery" size="18" maxlength="80" id="node">
					<input type="submit" value="go">
				</form>

				<form>
					<label for="node_id">ID:</label>
					<input type="text" name="node_id" value="1986688" size="12" maxlength="80" id="node_id">
					<input type="submit" value="go">
				</form>

			</span>
		</div>

		<div class='nodelet_section'>
			<h4 class='ns_title'>Node Toolset</h4>
			<ul>
				<li><a href='/index.pl'>Clone Node</a></li>
				<li><a href='/index.pl'>Edit Code</a></li>
				<li><a href="/index.pl">Node XML</a></li>
				<li><a href="/index.pl">Document Node?</a></li>
				<li style='list-style: none'><br></li>
				<li><a href='/index.pl'>Delete Node</a></li>
			</ul>
		</div>

		<div class="nodelet_section" id="nodenotes">
			<h4 class="ns_title">Node Notes <em>(0)</em></h4>
			<form>
				<input type="hidden">
				<input type="hidden">
				<p>
					<input type="checkbox">
					2009-05-15 <a href="/index.pl" class='populated' >rootbeer277</a>: Test chamber for <a href="/index.pl" class='populated' >zenmasters</a> to style staff features
				</p>
				<p align="right">
					<input type="hidden">
					<input type="hidden">
					<input type="hidden">
					<input type="text" name="notetext" maxlength="255" size="22"><br>
					<input type="submit" value="(un)note">
				</p>
			</form>
		</div>

		<div id="episection_admins" class="nodeletsection">
			<div class="sectionheading">
				[<a style="text-decoration: none;" class="ajax " href="/" title="collapse"><tt> - </tt></a>]
				<strong>Admin</strong>
			</div>

			<div class="sectioncontent">
				<ul>
					<li><a href='/index.pl'>Edit These E2 Titles</a></li>
					<li><a href='/index.pl'>Admin HOWTO</a></li>
				</ul>
			</div>
		</div>

		<div id="episection_ces" class="nodeletsection">
			<div class="sectionheading">
				[<a style="text-decoration: none;" class="ajax " href="/" title="collapse"><tt> - </tt></a>]
				<strong>CE</strong>
			</div>
			<div class="sectioncontent">
				<ul>
					<li><a href='/index.pl'>25</a> | <a href='/index.pl' >Everything New Nodes</a></li>
					<li><a href='/index.pl'>E2 Nuke Request</a></li>
					<li><a href='/index.pl'>Nodeshells</a></li>
					<li><a href='/index.pl'>Node Row</a></li>
					<li><a href='/index.pl'>Recent Node Notes</a></li>
					<li><a href='/index.pl'>Your insured writeups</a></li>
					<li><a href='/index.pl'>Make Unvotable</a></li>
					<li><a href='/index.pl'>Blind Voting Booth</a></li>
					<li><a href='/index.pl'>Group discussions</a></li>
					<li><a href='/index.pl'>Editor Log: May 2009</a></li>
					<li><a href='/index.pl'>The Oracle</a></li>
				</ul>
			</div>
		</div>

	</div>
</div>

</div>
<br><br><br>
<div class="weblog">
	<div class="item">
		<div class="contentinfo contentheader">
 			<a href="/" class="title">Welcome to Zenmastery</a>
			<cite>by <a href="/" class="author">rootbeer277</a></cite>
			<span class="date">Wed May 27 2009 at 9:56:10</span>
			<div class="linkedby">linked by <a href="/">DonJaime</a></div>
			<a class="remove" href="/">remove</a>
		</div>
		<div class="content">
			<p>Content goes here.</p>
		</div>
	</div>
	<div class="item">
		<div class="contentinfo contentheader">
			<a href="/" class="title">Zenmastery now Updated!</a>
			<cite>by <a href="/" class="author">DonJaime</a></cite>
			<span class="date">Sun May 17 2009 at 4:00:50</span>
			<a class="remove" href="/">remove</a>
		</div>
		<div class="content">
			<p>Content goes here.</p>
		</div>
	</div>
</div>};

    return $str;
}

sub bestow_cools {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '';

    $str .= htmlcode('openform');
    $str .= 'User ' . $query->textfield("myuser", "", 30) . "\n";
    $str .= 'gets ' . $query->textfield("mycools", "", 3, 3) . "\n";
    $str .= 'cools.' . "\n";
    $str .= htmlcode('closeform');
    $str .= "<p>\n";

    my $user = $query->param("myuser");
    my $cools = $query->param("mycools");

    return $str unless $APP->isAdmin($USER);

    return $str unless $user and $cools;
    return $str . "invalid cools" unless $cools =~ /^\d+$/;

    my $U = getNode($user, 'user');
    return $str . "<i>No user \"$user\" exists!</i>" unless $U;

    # Check if bestowing on yourself - need to modify in-scope variables
    # to avoid being overwritten when the page saves $USER and $VARS
    my $is_self = ($$U{node_id} == $$USER{node_id});

    if ($is_self) {
        # Modify the in-scope $VARS directly for current user
        $$VARS{cools} = ($$VARS{cools} || 0) + $cools;
        $$USER{karma} += 1;
        $APP->securityLog($NODE, $USER, "$$USER{title} bestowed $cools cools to themselves");
        $str .= qq|<strong>$cools cools were bestowed to you (now have $$VARS{cools} cools)</strong>|;
    } else {
        # Modifying another user - get their vars and update their node
        my $V = getVars($U);
        $$V{cools} = ($$V{cools} || 0) + $cools;
        setVars($U, $V);
        $$U{karma} += 1;
        updateNode($U, -1);
        $APP->securityLog($NODE, $USER, "$$U{title} was given $cools cools by $$USER{title}");
        $str .= qq|<strong>$cools cools were bestowed to |.linkNode($U).qq| (now has $$V{cools} cools)</strong>|;
    }

    return $str;
}

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

sub e2node_reparenter {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '';

    $str .= htmlcode('openform');

    $str .= "The node to reparent: ".$query->textfield("repare", "")."<p>";
    my $repare = $query->param('repare');

    return $str . htmlcode('closeform') unless $repare;

    my $N = getNode($repare, 'e2node');

    return $str . "can't find $repare e2node...<p>" . htmlcode('closeform') unless $N;

    my $id = getId($N);

    my $csr = $DB->sqlSelectMany("writeup_id", "writeup", "parent_e2node=$id");

    my @group;
    while (my ($wrid) = $csr->fetchrow) {
        push @group, $wrid;
    }

    replaceNodegroup($N, \@group, $USER);

    $str .= "The following nodes have been put into ".linkNode($N);

    foreach (@group) {
        my $W = getNodeById($_);
        $str .= "<li>".linkNode($W)." by ".linkNode($$W{author_user});
    }
    $str .= "<P>these may need to be reordered<P>";

    $str .= htmlcode('closeform');

    return $str;
}

sub enrichify {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '';

    # Process form submission first
    my @params = $query->param;
    my (@users, @gp);
    foreach (@params) {
        if(/^EnrichUsers(\d+)$/) {
            $users[$1] = $query->param($_);
        }
        if(/^BestowGP(\d+)$/) {
            $gp[$1] = $query->param($_);
        }
    }

    my $curGP;
    for(my $count=0; $count < @users; $count++) {
        next unless $users[$count] and $gp[$count];

        my ($U) = getNode ($users[$count], 'user');
        if (not $U) {
            $str .= "couldn't find user $users[$count]<br />";
            next;
        }

        $curGP = $gp[$count];

        unless ($curGP =~ /^\-?\d+$/) {
            $str .= "$curGP is not a valid GP value for user $users[$count]<br>";
            next;
        }

        my $signum = ($curGP>0) ? 1 : (($curGP<0) ? -1 : 0);

        $str .= "User $$U{title} was given $curGP GP.";
        $APP->securityLog($NODE, $USER, "$$U{title} was superblessed $curGP GP by $$USER{title}");
        if($signum!=0) {
            $$U{karma}+=$signum;
            $$U{GP}+=$curGP;
            updateNode($U,-1);


        } else {
            $str .= ', so nothing was changed';
        }
        $str .= "<br />\n";
    }

    # Now display the form
    $str .= htmlcode('openform');
    $str .= '<table border="1">';

    if (!$APP->isAdmin($USER)) {
        $str .= '<TR><TH>You want to be supercursed? No? Then play elsewhere.</TH></TR>';
    } else {
        my $count = 10;

        $str .= "<tr><th>Bestow user</th><th>with GP</th></tr> ";

        for (my $i = 0; $i < $count; $i++) {
            $query->param("EnrichUsers$i", '');
            $query->param("BestowGP$i", '');
            $str .= "<tr><td>";
            $str .= $query->textfield("EnrichUsers$i", '', 40, 80);
            $str .= "</td><td>";
            $str .= $query->textfield("BestowGP$i", '', 4, 5);
            $str .= "</td></tr>";
        }
    }

    $str .= '</table>';
    $str .= htmlcode('closeform');

    return $str;
}

sub everything_s_richest_noders {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $rows;
    my $str = '';
    my $queryText = '';
    my $limit = 1500;
    my $limit2 = 10;
    my $row;

    $queryText = 'SELECT SUM(GP) FROM user';
    $rows = $DB->{dbh}->prepare($queryText)
        or return $rows->errstr;
    $rows->execute()
        or return $rows->errstr;
    my $totalGP = $rows->fetchrow_array();

    $queryText = 'SELECT user_id,gp FROM user ORDER BY gp DESC LIMIT '.$limit;
    $rows = $DB->{dbh}->prepare($queryText)
        or return $rows->errstr;
    $rows->execute()
        or return $rows->errstr;

    $str .= '<h3>'.$limit.' Richest Noders</h3>';
    $str .= '<ol>';
    while($row = $rows->fetchrow_arrayref)
    {
        $str .= '<li>'.linkNode($$row[0]).' ('.$$row[1].'GP)</li>';
    }
    $str .= '</ol><hr />';

    $queryText = 'SELECT user_id,gp FROM user WHERE gp<>0 ORDER BY gp LIMIT '.$limit2;
    $rows = $DB->{dbh}->prepare($queryText)
        or return $rows->errstr;
    $rows->execute()
        or return $rows->errstr;
    $str .= '<h3>'.$limit2.' Poorest Noders (ignore 0GP)</h3>';
    $str .= '<ol>';
    while($row = $rows->fetchrow_arrayref)
    {
        $str .= '<li>'.linkNode($$row[0]).' ('.$$row[1].'GP)</li>';
    }
    $str .= '</ol><hr />';

    $queryText = 'SELECT user_id,gp FROM user ORDER BY gp DESC LIMIT '.$limit2;
    $rows = $DB->{dbh}->prepare($queryText)
        or return $rows->errstr;
    $rows->execute()
        or return $rows->errstr;
    $str .= '<h3>'.$limit2.' Richest Noders</h3>';
    $str .= '<ol>';
    my $richestUsersGP = 0;
    while($row = $rows->fetchrow_arrayref)
    {
        $str .= '<li>'.linkNode($$row[0]).' ('.$$row[1].'GP)</li>';
        $richestUsersGP += $$row[1];
    }
    $str .= '</ol>';

    $str .= '<p><b>Total GP in circulation:</b> ' . $totalGP . '</p>';

    $str .= '<p>The top ' . $limit2 . ' users hold ' . ($richestUsersGP / $totalGP * 100) . '% of all the GP</p>';

    return $str;
}

sub faq_editor {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my  $faqData = {};

    my $fID = $query->param("faq_id") || 0;

    if ($query->param("sexisgood")) {
        if ($query->param("edit_faq")) {
            $fID = $query->param("edit_faq");
            $DB->sqlUpdate("faq",{question => $query->param("faq_question"), answer => $query->param("faq_answer"), keywords => $query->param("faq_keywords")},"faq_id = $fID");
        }
        else {
            $DB->sqlInsert("faq",{question => $query->param("faq_question"), answer => $query->param("faq_answer"), keywords => $query->param("faq_keywords")});
        }
    }

    if ($fID) {
        $faqData = $DB->sqlSelectHashref("*","faq","faq_id = $fID");
    }

    my $str = '';

    $str .= htmlcode('openform');

    $str .= $query->hidden("edit_faq",$fID) if $fID;

    $str .= "<p>Question: </p>

<textarea rows='6' cols='40' name='faq_question'>
".$$faqData{question}."
</textarea>

<p>Answer: </p>

<textarea rows='6' cols='40' name='faq_answer'>
".$$faqData{answer}."
</textarea>

<p>Keywords (separated by commas):</p>

<textarea rows='1' cols='40' name='faq_keywords'>
".$$faqData{keywords}."
</textarea>";


    $str .= htmlcode('closeform');

    return $str;
}

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

sub gp_optouts {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $queryText = '';
    my $rows;
    my $dbrow;
    my $str = '';
    my @list = ();

    $queryText = "SELECT user.user_id,user.GP FROM setting,user WHERE setting.setting_id=user.user_id AND setting.vars LIKE '%GPoptout=1%'";

    $rows = $DB->{dbh}->prepare($queryText)
        or return $rows->errstr;
    $rows->execute()
        or return $rows->errstr;

    while($dbrow = $rows->fetchrow_arrayref)
    {
        push(@list, linkNode($$dbrow[0]) . ' - Level: ' . $APP->getLevel($$dbrow[0]) . '; GP: ' . $$dbrow[1]);
    }

    $str .= '<h3>Users who have opted out of the GP system</h3>';
    $str .= '<ol style="margin-left:55px">';
    foreach my $key (sort { lc($a) cmp lc($b) } @list)
    {
        $str .= '<li>'.$key.'</li>';
    }
    $str .= '</ol>';

    return $str;
}

sub ip_blacklist {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    local $SIG{__WARN__} = sub {};

    my $str = '<p>This page manages the IP addresses which are barred from <strong>creating new accounts</strong>.  Except for very extreme circumstances, we don\'t block pageloads as '.linkNode(getNode('Guest User','user')).'.</p>';
    $str .= '<p><strong>This tool should ONLY be used to block access at the IP level for users whose primary accounts have been locked if they continue to abuse our hospitality.</strong> Usually the \'Smite Spammer\' tool will do the job automatically for you when it needs to be done. </p>';
    $str .= '<h3>';

    # Helper subroutines
    my $intFromAddr = sub {
        my $addr = shift;
        return unless $addr =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
        return if $1 > 255 or $2 > 255 or $3 > 255 or $4 > 255;
        return (
            (int $1) * 256*256*256
            + (int $2) * 256 * 256
            + (int $3) * 256
            + (int $4)
        );
    };

    my $rangeMinMax = sub {
        my $cidrIP = shift;
        return () unless $cidrIP =~ m/^(\d{1,3}\.\d{1,3}.\d{1,3}\.\d{1,3})\s*\/(\d{1,2})$/;
        my $addr = $1;
        my $intAddr = &$intFromAddr($addr);
        return () unless $intAddr;
        my $bits = $2;
        return () unless $bits < 33 && $bits > 7;

        my $maxAddr = &$intFromAddr('255.255.255.255');
        my $mask = ($maxAddr << (32 - $bits)) & $maxAddr;

        my $validAddr = 1;
        my $addrMin   = $intAddr & $mask;
        my $addrMax   = $addrMin + ($maxAddr >> $bits);

        return ($validAddr, $addrMin, $addrMax);
    };

    # Remove an IP from the blacklist if requested
    if (my $idToRemove = $query->param("remove_ip_block_ref")) {

        $idToRemove = int $idToRemove;

        my $selectAddrFromBlacklistSQL = qq|
SELECT
	IFNULL(ipblacklist.ipblacklist_ipaddress,
		CONCAT(ipblacklistrange.min_ip, ' - ', ipblacklistrange.max_ip)
	) ipblacklist_ipaddress
	FROM ipblacklistref
	LEFT JOIN ipblacklist
		ON ipblacklistref.ipblacklistref_id =
			ipblacklist.ipblacklistref_id
	LEFT JOIN ipblacklistrange
		ON ipblacklistref.ipblacklistref_id =
			ipblacklistrange.ipblacklistref_id
	WHERE ipblacklistref.ipblacklistref_id = $idToRemove|;

        my @blacklistAddressArray =
            @ { $DB->{dbh}->selectall_arrayref($selectAddrFromBlacklistSQL) };
        my $blAddress = $blacklistAddressArray[0]->[0];

        my $removeFromBlacklistSQL = qq|
DELETE ipblacklist, ipblacklistref, ipblacklistrange
	FROM ipblacklistref
	LEFT JOIN ipblacklist
		ON ipblacklistref.ipblacklistref_id =
			ipblacklist.ipblacklistref_id
	LEFT JOIN ipblacklistrange
		ON ipblacklistref.ipblacklistref_id =
			ipblacklistrange.ipblacklistref_id
	WHERE ipblacklistref.ipblacklistref_id = $idToRemove|;

        my $saveRaise = $DB->{dbh}->{RaiseError};
        $DB->{dbh}->{RaiseError} = 1;
        eval { $DB->{dbh}->do($removeFromBlacklistSQL) };  ## no critic 'Perl::Critic::Policy::ErrorHandling::RequireCheckingReturnValueOfEval'
        $DB->{dbh}->{RaiseError} = $saveRaise;

        if($@){
            return $str . "There was an error removing this block from the database: "
                . $DB->{dbh}->errstr()
                ;
        }else{
            $APP->securityLog($NODE, $USER, "$$USER{title} removed $blAddress from the IP blacklist.");
            return $str . "The IP \"$blAddress\" was successfully removed from the blacklist.";
        }

    }

    # Add an IP to the blacklist if requested
    if($query->param("add_ip_block")){
        my $ipToAdd = $query->param("bad_ip");
        return $str . "You must list an IP to block." unless $ipToAdd;
        my ($isRangeAddr, $rangeMin, $rangeMax) = &$rangeMinMax($ipToAdd);

        my $blockReason = $query->param("block_reason");
        return $str . "You must give a reason to block this IP." unless $blockReason;

        return $str . htmlcode('blacklistIP', $ipToAdd, $blockReason) unless $isRangeAddr;

        $ipToAdd = $DB->quote($ipToAdd);
        $blockReason = $DB->quote($blockReason);

        my $addBlacklistRefSQL = q|INSERT INTO ipblacklistref () VALUES ()|;

        my $addBlacklistSQL = '';
        $addBlacklistSQL = qq|
INSERT INTO ipblacklistrange
	(banner_user_id, min_ip, max_ip, comment
	 , ipblacklistref_id)
	VALUES ($$USER{user_id}, $rangeMin, $rangeMax, $blockReason
		, LAST_INSERT_ID()) | if $isRangeAddr;

        my $saveRaise = $DB->{dbh}->{RaiseError};
        $DB->{dbh}->{RaiseError} = 1;
        eval {  ## no critic 'Perl::Critic::Policy::ErrorHandling::RequireCheckingReturnValueOfEval'
            $DB->{dbh}->do($addBlacklistRefSQL);
            $DB->{dbh}->do($addBlacklistSQL);
        };
        $DB->{dbh}->{RaiseError} = $saveRaise;

        if ($@){
            return $str . "There was an error adding this block to the database: "
                . "<pre>" . encodeHTML($addBlacklistSQL) . "</pre>"
                . $DB->{dbh}->errstr()
                ;
        }else{
            $ipToAdd = encodeHTML($ipToAdd);
            $APP->securityLog($NODE, $USER, "$$USER{title} added $ipToAdd to the IP blacklist: \"$blockReason.\"");

            return $str . "The IP \"$ipToAdd\" was successfully added to the blacklist.";
        }

    }

    $str .= '</h3>';

    # Form for blacklisting an IP
    $str .= '<h3>Blacklist an IP</h3>';

    my $bad_ip = $query->param("bad_ip") || '';

    $str .= htmlcode('openform');
    $str .= $query->hidden('node_id', getId($NODE));
    $str .= '<div><strong>IP Address</strong><br />';
    $str .= $query->textfield('bad_ip', $bad_ip, 20);
    $str .= '</div><br />';
    $str .= '<div><strong>Reason</strong><br />';
    $str .= $query->textfield('block_reason', '', 50);
    $str .= '</div><br />';
    $str .= $query->submit('add_ip_block', 'Please blacklist this IP.');
    $str .= htmlcode('closeform');

    # Display the list of blacklisted IPs
    $str .= htmlcode('blacklistedIPs');

    return $str;
}

sub ip_hunter {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = htmlcode('openform');
    $str .= "<table><tr>";
    $str .= "<td width=\"50\"><b>name:</b> </td>";
    $str .= "<td><input type=\"text\" name=\"hunt_name\"></td>";
    $str .= "</tr>";
    $str .= "<td></td><td><b> - or -</b></td>";
    $str .= "<tr><td><b>IP:</b></td>";
    $str .= "<td><input type=\"text\" name=\"hunt_ip\"></td></tr>";
    $str .= "<tr><td></td><td><input type=\"submit\" value=\"hunt\">";
    $str .= "</tr></table>";
    $str .= $query->end_form();
    $str .= "<br><hr><br>";

    my $TABLEHEAD = '<table border="1" cellspacing="0" cellpadding="2">' . "\n" . '<tr><th>#</th>';

    my $humanTime = sub {
        my $t = $_[0];
        return $t;
    };

    # Limit put in 2006 August 26 while N-Wing trying to get working again
    # maybe later this will be removed or user-runtime-settable
    # 50 is big enough for now
    my $resultLimit = 500;

    # Every log entry below this number is from 2003 or earlier - generally
    # not very useful for our hunting purposes. We'll exclude them from the search.
    my $lowID = 1500000;

    $TABLEHEAD = '(only showing ' . $resultLimit . ' most recent)
' . $TABLEHEAD;
    $resultLimit = 'LIMIT ' . $resultLimit;

    if($query->param('hunt_ip')) {
        my $ip = $APP->encodeHTML(scalar($query->param('hunt_ip')));
        $str .= "The IP ($ip) <small>(" . htmlcode('ip lookup tools', $ip) . ")</small> has been here and logged on as:";
        $str .= $TABLEHEAD . '<th colspan="2">Who (Hunt User)</th><th>When</th></tr>';

        my $csr = $DB->sqlSelectMany('iplog.*', 'iplog', "iplog_id > $lowID AND iplog_ipaddy = " . $DB->quote($ip) . " ORDER BY iplog_id DESC", $resultLimit);

        my $i = 0;
        while(my $ROW = $csr->fetchrow_hashref) {
            my $loggedUser = getNodeById($$ROW{iplog_user});
            my $loggedUserLink = '';
            my $loggedUserHuntLink = '';

            if ($loggedUser) {
                $loggedUserLink = linkNode($loggedUser, 0, {lastnode_id => 0});
                $loggedUserHuntLink = linkNode($NODE, 'hunt', {'hunt_name' => "$$loggedUser{title}"});
            } else {
                $loggedUserLink = "<strong>Deleted user</strong>";
                $loggedUserHuntLink = linkNode($NODE, 'hunt', {'hunt_name' => ""});
            }

            $str .= '<tr><td>' . (++$i) . '</td><td>' . $loggedUserLink . '</td><td align="right">' . $loggedUserHuntLink . '</td><td>' . $humanTime->($$ROW{iplog_time}) . "</td></tr>\n";
        }

        $str .= '</table>';
        return $str;
    }

    if (defined $query->param('hunt_name')) {
        my $username = $query->param('hunt_name');
        my $csr = undef;
        my $selectString = q|
	iplog.*
	, (SELECT ipblacklist.ipblacklistref_id
	    FROM ipblacklist
	    WHERE iplog.iplog_ipaddy = ipblacklist_ipaddress
	) 'banned'
	, (SELECT MAX(ipblacklistrange.ipblacklistref_id)
	    FROM ipblacklistrange
	    WHERE ip_to_uint(iplog.iplog_ipaddy) BETWEEN min_ip AND max_ip
	) 'banned_ranged'|;

        if ($username ne '') {
            my $usr = getNode($username, 'user');
            return $str . "<font color=\"red\">No such user!</font>" unless($usr);

            $str .= 'The user ' . linkNode($usr, 0, {lastnode_id => 0}) . ' has been here as IPs:' . $TABLEHEAD . '<th>IP</th><th>When</th><th>Look up</th></tr>';

            $csr = $DB->sqlSelectMany($selectString, 'iplog', "iplog_id > $lowID AND iplog_user = '$$usr{user_id}' ORDER BY iplog_id DESC", $resultLimit);
        } else {
            $str .= 'Deleted users have been here as IPs:' . $TABLEHEAD . '<th>IP</th><th>When</th><th>Look up</th></tr>';
            $csr = $DB->sqlSelectMany($selectString, 'iplog LEFT JOIN user ON iplog_user = user.user_id', "iplog_id > $lowID AND user.user_id IS NULL ORDER BY iplog_id DESC", $resultLimit);
        }

        my $i = 0;
        while(my $ROW = $csr->fetchrow_hashref) {
            my ($strike, $unstrike) = ('', '');
            ($strike, $unstrike) = ('<strike><b>', '</b></unstrike>') if $$ROW{banned} || $$ROW{banned_ranged};
            $str .= '<tr><td>' . (++$i) . '</td>' . '<td>' . $strike . linkNode($NODE, $$ROW{iplog_ipaddy}, {hunt_ip => $$ROW{iplog_ipaddy}}) . $unstrike . '</td>' . '<td>' . $humanTime->($$ROW{iplog_time}) . '</td>' . '<td>' . htmlcode('ip lookup tools', $$ROW{iplog_ipaddy}) . '</td>' . "</tr>\n";
        }

        $str .= '</table>';
        return $str;
    }

    $str .= 'Please enter an IP address or a name to continue';

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

sub mass_ip_blacklister {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '<div style="width:600px">';
    $str .= '<p>This page manages the IP addresses which are barred from <strong>creating new accounts</strong>.  Except for very extreme circumstances, we don\'t block pageloads as '.linkNode(getNode('Guest User','user')).'.</p>';
    $str .= '<p>This tool should be used to block access at the IP level based on externally maintained blacklists, until we implement a less hacky solution. - '.linkNode(getNode('Oolong', 'user')).'</p>';
    $str .= '</div>';

    ### Remove an IP from the blacklist if requested
    if(my $idToRemove = $query->param("remove_ip_block")){

        $idToRemove =~ s/(\\g|;|"|'|`|\s)//g;
        my $blacklistHash = $DB->sqlSelectHashref("ipblacklist_ipaddress", "ipblacklist", "ipblacklist_id = $idToRemove");

        my $removeFromBlacklistSQL = "delete from ipblacklist where ipblacklist_id = \"$idToRemove\";";

        eval { $DB->{dbh}->do($removeFromBlacklistSQL) };  ## no critic 'Perl::Critic::Policy::ErrorHandling::RequireCheckingReturnValueOfEval'
        if( $@ ){
            return $str . "There was an error adding this block to the database: " . $DB->{dbh}->errstr();
        }else{
            $APP->securityLog($NODE, $USER, "$$USER{title} removed $$blacklistHash{ipblacklist_ipaddress} from the IP blacklist.");
            return $str . "The IP \"$$blacklistHash{ipblacklist_ipaddress}\" was successfully removed from the blacklist.";
        }

    }

    ### Add an IP to the blacklist if requested
    if($query->param("add_ip_block")){
        my $ipList = $query->param("bad_ips") || '';
        $ipList =~ s/\s*\n\s*/NEXT/g;
        $ipList =~ s/(\\g|;|"|'|`|\s)//g;
        my @ipsToAdd = split( 'NEXT', $ipList );

        return $str . "You must list IPs to block." unless @ipsToAdd;

        my $blockReason = $query->param("block_reason") || '';
        $blockReason =~ s/(\\g|;|"|'|`)//g;
        return $str . "You must give a reason to block these IPs." unless $blockReason;
        $str .= "<ol>\n";
        foreach my $ipToAdd ( @ipsToAdd ) {
            next unless( $ipToAdd );
            my $addBlacklistSQL = "insert into ipblacklist (ipblacklist_user, ipblacklist_ipaddress, ipblacklist_comment) values (\"$$USER{user_id}\",\"$ipToAdd\",\"$blockReason\");";
            eval { $DB->{dbh}->do($addBlacklistSQL) };  ## no critic 'Perl::Critic::Policy::ErrorHandling::RequireCheckingReturnValueOfEval'

            if( $@ ){
                $str .= "<li>There was an error adding this block to the database: " . $DB->{dbh}->errstr() . "</li>";
            }else{
                $APP->securityLog($NODE, $USER, "$$USER{title} added $ipToAdd to the IP blacklist: \"$blockReason.\"");
                $str .= "<li>The IP \"$ipToAdd\" was successfully added to the blacklist.</li>\n";
            }
        }
        $str .= "</ol>";
        return $str;
    }

    $str .= '<h3>Blacklist IPs (one per line)</h3>';

    my $bad_ips = $query->param("bad_ips") || '';

    $str .= $query->start_form(-method=>'post');
    $str .= $query->hidden('node_id', getId($NODE));
    $str .= '<div><strong>IP Addresses</strong><br />';
    $str .= $query->textarea(-name=>'bad_ips', -default=>$bad_ips, -rows=>20, -columns=>40);
    $str .= '</div><br />';
    $str .= '<div><strong>Reason</strong><br />';
    $str .= $query->textfield('block_reason', '', 50);
    $str .= '</div><br />';
    $str .= $query->submit('add_ip_block', 'Please blacklist these IPs.');
    $str .= $query->end_form;
    $str .= htmlcode('blacklistedIPs');

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

sub node_cloner {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $SRCNODE = getNodeById(scalar($query->param("srcnode_id")));
    return 'No node to clone.' unless $SRCNODE;

    my $newname = $query->param("newname");
    return 'No name for cloned node.' unless $newname;

    my %DATA = (%$SRCNODE);

    # Delete the node id so that when we insert it, it gets a new id.
    delete $DATA{node_id};
    delete $DATA{type};
    delete $DATA{group} if(exists $DATA{group});
    delete $DATA{title}; # we want to use the new title.
    delete $DATA{_ORIGINAL_VALUES}; # so update doesn't fail in insertNode

    my $newid = $DB->insertNode($newname, $SRCNODE->{type}, $USER, \%DATA);

    my $str = '';
    if ($newid) {
        $str = "Node " . linkNode($SRCNODE) .
            ' has been cloned as ' . linkNode($newid);
    } else {
        $str = 'Ack! Clone failed.';
    }

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

sub node_heaven_title_search {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '';
    my $isAdmin = undef;
    my $filterTitle = undef;
    my $sqlStatement = undef;
    my $sortOrder = undef;
    my $csr = undef;
    my $count = undef;
    my $T = undef;
    my $selfkill = undef;
    my $N = undef;

    $str .= "<p>Welcome to Node Heaven, where you may sit and reconcile with your dear departed writeups.</p>\n\n";
    $str .= "<p><strong>Note:</strong> It takes <em>up to</em> 48 hours for a writeup that was deleted to turn up in Node Heaven. Remember: first they must be <em>judged</em>. For that 48 hours they are in purgatory...<strong><em>" . linkNode('copper starlight', 'sleeping') . "</em></strong>.</p>\n\n";

    if ($APP->isAdmin($USER)) {
        $str .= "<p><blockquote>\n";
        $str .= "Since you are a god, you can also see other nuked nodes.<br />\n";
        $str .= htmlcode('openform') . "\n";
        $str .= 'title: ' . $query->textfield(-name=>'heaventitle', -size=>32) . "<br />\n";
        $str .= htmlcode('closeform') . '</blockquote></p>';
    }

    $str .= "\n<p align=\"center\">Here are the little Angels:\n\n";

    $isAdmin = $APP->isAdmin($USER);  # only call database once

    if ($query->param('heaventitle') && $isAdmin) {
        $filterTitle = $query->param('heaventitle');
        $filterTitle =~ s/".*//;
    }

    return $str unless $filterTitle;

    return $str . '<em>not yet, you\'re not ready</em>' unless $APP->getLevel($USER) >= 1 || $APP->getParameter($USER, "node_heaven_guest") || $isAdmin;

    $str .= "<table width=\"100%\">\n";

    $sqlStatement = "title like \"" . $filterTitle . " (%\"" if $filterTitle;
    $sortOrder = 'createtime';
    $csr = $DB->sqlSelectMany('*', 'heaven', $sqlStatement, 'order by ' . $sortOrder);

    $str .= '<tr><th>' . linkNode($NODE, 'Create Time', {'orderby' => 'createtime'}) .
        '</th><th>' . linkNode($NODE, 'Writeup Title', {'orderby' => 'title'}) .
        '</th><th>' . linkNode($NODE, 'Rep', {'orderby' => 'rep'}) . '</th>';
    $str .= '<th>' . linkNode($NODE, 'Killa', {'orderby' => 'killerid'}) . '</th>' if $isAdmin;
    $str .= "</tr>\n";

    $count = 0;
    $T = getNode('Node Heaven Visitation', 'superdoc');
    $selfkill = 0;

    while ($N = $csr->fetchrow_hashref) {
        return $str . 'no nodes by this user have been nuked' if int($N) == -1;
        $count++;
        $str .= "<tr><td><small>$N->{createtime}</small></td><td>"
            . linkNode($T, $N->{title}, {visit_id => $N->{node_id}})
            . ' by ' . linkNode($N->{author_user}) . '</td><td>' . $N->{reputation} . '</td>';
        $str .= '<td>' . linkNode($N->{killa_user}) . '</td>' if $isAdmin && $N->{killa_user} != -1;
        ++$selfkill if ($N->{killa_user} == $USER->{node_id});
        $str .= "</tr>\n";
    }

    $str .= '</table>';

    if ($isAdmin) {
        $str .= '<p>' . $count . ' writeups, of which you killed ' . $selfkill . '.</p>';
    }

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

sub sql_prompt {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    $PAGELOAD->{noparsecodelinks} = 1;

    my $ut = $USER->{title};
    my $codePerson = 0;
    foreach ((
        'jaybonci',
        'root'
    )) {

        if ($_ eq $ut) {
            $codePerson = 1;
            last;
        }
    }
    return 'You really really shouldn\'t be playing with this.' unless $codePerson;

    my $str = undef;
    my $execstr = $query->param('sqlquery');

    $str = $query->start_multipart_form('POST', $ENV{script_name}) . "\n";
    $str .= $query->hidden('displaytype') . "\n";
    $str .= $query->hidden('node_id', getId($NODE)) . "\n";
    $str .= "SQL Query:\n";
    $str .= $query->textarea(-name => 'sqlquery', -cols => 60, -rows => 5, -class => "expandable");
    $str .= $query->submit('execsql', 'Execute') . "\n";
    $str .= 'text flow: ' . htmlcode('varsComboBox', 'sqlprompt_wrap,0, 0,PRE (default), 1,CODE, 2,variable width, 3,copy-n-paste (textarea)');
    $str .= htmlcode('varcheckboxinverse', 'sqlprompt_nocount,row count');
    $str .= '<input type="checkbox" name="hideresults" value="1" /> hide results';
    $str .= '<input type="hidden" name="sexisgood" value="1" /><br />
';
    $str .= $query->end_form;

    #TODO other boolean options (make varscheckboxmulti or something) (maybe make varsComboBox that operates on several bits (but that may get icky))
    #bit 1 = (currently sqlprompt_nocount)
    #(not sure about 2 and 3)
    #bit 2 = empty string produces empty string (only for table-based)
    #bit 3 = null produces empty string (only for table-based)

    #$str . '<p>new format option Feb 10, 2006 - textarea result for easy export</p>';

    $str .= "\n<p>\n";

    #Cleaner output of SQL Errors
    local $SIG{__WARN__} = sub { return };

    $execstr = $query->param('sqlquery');


    #if no SQL to run, then done
    return $str . "</p>\n" unless $execstr;


    my $thisdbh = $DB->getDatabaseHandle();
    my @start = Time::HiRes::gettimeofday;
    my $cursor = eval { $thisdbh->prepare($execstr) };
    return $str . 'Bad SQL: ' . $thisdbh->errstr . "($@)\n</p>\n" if $@;

    unless ($cursor->execute()) {
        return $str . $thisdbh->errstr . "</p>\n";
    }

    #
    # format options
    #

    my $codeOpen = undef;
    my $codeClose = undef;

    #defaults are for table-based formats, because they are the most common
    my $grandOpen = '<table border="1">
';
    my $grandClose = "</table>\n";
    my $recordOpen = " <tr>\n";
    my $recordClose = " </tr>\n";
    my $columnHeaderOpen = '  <td align="center" bgcolor="#CC99CC">';
    my $columnHeaderClose = "</td>\n";
    my $datumOpen = '<td>';
    my $datumClose = '</td>';

    my $linkifyValues = 1;
    my $changeValueNull = '';  # '&empty;'
    my $changeValueBlank = '&nbsp;';


    my $formatStyle = $VARS->{'sqlprompt_wrap'} || 0;

    if ($formatStyle eq '1') {
        $codeOpen = '<code>';
        $codeClose = '</code>';
    } elsif ($formatStyle eq '2') {
        #variable width
        $codeOpen = '';
        $codeClose = '';
    } elsif ($formatStyle eq '3') {
        $grandOpen = '<strong>N-Wing added this display method on Friday, February 10, 2006; it seems to work, but let me know if something is funny for you</strong><br />
<textarea name="dummy" rows="30" cols="80" wrap="virtual">' . "\n";
        #TODO maybe there is some htmlcode for this (i.e., custom size)
        $grandClose = '</textarea>';
        $recordOpen = '';
        $recordClose = "\n";
        $columnHeaderOpen = '';
        $columnHeaderClose = "\t";
        $datumOpen = '';
        $datumClose = "\t";
        $linkifyValues = 0;
        $changeValueNull = '';
        $changeValueBlank = '';
    } else {
        #formatStyle 0 or something invalid
        $codeOpen = '<pre>';
        $codeClose = '</pre>';
    }
    my $showRowCount = $VARS->{'sqlprompt_nocount'} ? 0 : 1;

    #SELECT reputation, COUNT(*) FROM node WHERE type_nodetype=117 AND node_id < 50000 GROUP BY reputation











    #
    # get results and dump out
    #

    my $results = '';
    my $rowCount = $cursor->rows();

    if ($showRowCount && !$cursor->{Active} && $rowCount && $rowCount != -1) {
        my $plural = '';
        $plural = 's' if $rowCount > 1;
        $results .= "$rowCount row$plural affected.";
    }

    my $ROW = undef;
    my $hdr = $grandOpen;
    my $rowNum = 0;

    $results .= $query->param('hideresults');

    #N-Wing removed, because it gives Server Error! when no rows returned
    ##N-Wing added 2006-04-11, so column order is same as what is specified in query
    #my @columns = @{$cursor->{NAME}};

    my $ordered_columns = [];

    while ($ROW = $cursor->fetchrow_hashref()) {
        next if $query->param('hideresults');
        if ($results eq '') {
            $hdr .= $recordOpen;
            $hdr .= $columnHeaderOpen . '#' . $columnHeaderClose if $showRowCount;
            #foreach(@columns) {
            foreach (keys %$ROW) {
                $_ = $changeValueBlank if ((not defined $_) || ($_ eq ''));
                $hdr .= $columnHeaderOpen . $_ . $columnHeaderClose;
                push @$ordered_columns, $_;
            }
            $hdr .= $recordClose;
        }

        $results .= $recordOpen;
        if ($showRowCount) {
            $results .= $datumOpen . $rowNum . $datumClose;
            ++$rowNum;
        }
        my ($k, $v);

        foreach (@$ordered_columns) {
            $k = $_;
            $v = $ROW->{$_};
            if (defined $v) {
                $v = encodeHTML($v, 1);
                if ($linkifyValues) {
                    $v = linkNode($v, $v) if (($k =~ /_/) && (not($v =~ /\D/)));
                }
                $v = $changeValueBlank if ((!defined $v) || ($v eq ''));
            } else {
                $v = $changeValueNull;
            }
            $results .= $datumOpen . $codeOpen . $v . $codeClose . $datumClose;
        }
        $results .= $recordClose;
    }
    $cursor->finish();

    $hdr = '<p>Elapsed time: ' . Time::HiRes::tv_interval(\@start, [Time::HiRes::gettimeofday]) . ' seconds</p>' . $hdr;

    $results ||= '<tr><td><em>No results found</em></td></tr>';

    $results = $hdr . $results . $grandClose;

    return $str . $results . "</p>\n";
}

sub yet_another_secret_laboratory {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = htmlcode('openform')
        . "<table><tr>"
        . "<td width=\"50\"><b>name:</b> </td>"
        . "<td><input type=\"text\" name=\"hunt_name\"></td>"
        . "</tr>"
        . "<td></td><td><b> - or -</b></td>"
        . "<tr><td><b>IP:</b></td>"
        . "<td><input type=\"text\" name=\"hunt_ip\"></td></tr>"
        . "<tr><td></td><td><input type=\"submit\" value=\"hunt\">"
        . "</tr></table>"
        . $query->end_form()
        . "<br><hr><br>"
        ;

    my $TABLEHEAD = '<table border="1" cellspacing="0" cellpadding="2">'
        . "\n"
        . '<tr><th>#</th>'
        ;
    my $humanTime = sub {
        my $t = $_[0];
        return $t;  #N-Wing maybe this is problem
    };

    #limit put in 2006 August 26 while N-Wing trying to get working again
    #maybe later this will be removed or user-runtime-setable
    #50 is big enough for now
    my $resultLimit = 500;

    #every log entry below this number is from 2003 or earlier - generally
    #not very useful for our hunting purposes. We'll exclude them from the search.
    my $lowID = 1500000;

    $TABLEHEAD = '(only showing ' . $resultLimit . ' most recent)
' . $TABLEHEAD;
    $resultLimit = 'LIMIT ' . $resultLimit;

    if ($query->param('hunt_ip')) {
        my $ip = encodeHTML($query->param('hunt_ip'));
        $str .= "The IP ($ip) <small>("
            . htmlcode('ip lookup tools', $ip)
            . ")</small> has been here and logged on as:"
            . $TABLEHEAD
            . '<th colspan="2">Who (Hunt User)</th><th>When</th></tr>'
            ;
        my $csr = $DB->sqlSelectMany('iplog.*'
            , 'iplog'
            , "iplog_id > $lowID AND "
                . " iplog_ipaddy = " . $DB->quote($ip)
                . " ORDER BY iplog_id DESC"
            , $resultLimit
        );  #fast - iplog_id key field

        my $i = 0;
        while (my $ROW = $csr->fetchrow_hashref) {
            my $loggedUser = getNodeById($ROW->{iplog_user});
            my $loggedUserLink = undef;
            my $loggedUserHuntLink = undef;

            if ($loggedUser) {
                $loggedUserLink = linkNode($loggedUser, 0, {lastnode_id => 0});
                $loggedUserHuntLink = linkNode($NODE, 'hunt', {'hunt_name' => "$loggedUser->{title}"});
            }

            if (!$loggedUser) {
                $loggedUserLink = "<strong>Deleted user</strong>";
                $loggedUserHuntLink =
                    linkNode($NODE, 'hunt', {'hunt_name' => ""});
            }

            $str .= '<tr><td>'
                . $loggedUserLink
                . '</td></tr>\n'
                ;
        }

        $str .= '</table>';

        return $str;

    }

    if (defined $query->param('hunt_name')) {
        my $username = $query->param('hunt_name');
        my $csr = undef;
        my $selectString = qq|
	iplog.*
	, (SELECT ipblacklist.ipblacklistref_id
	    FROM ipblacklist
	    WHERE iplog.iplog_ipaddy = ipblacklist_ipaddress
	) 'banned'
	, (SELECT MAX(ipblacklistrange.ipblacklistref_id)
	    FROM ipblacklistrange
	    WHERE ip_to_uint(iplog.iplog_ipaddy) BETWEEN min_ip AND max_ip
	) 'banned_ranged' |;

        if ($username ne '') {

            my $usr = getNode($username, 'user');
            return "<font color=\"red\">No such user!</font>" unless ($usr);

            $str .= 'The user '
                . linkNode($usr, 0, {lastnode_id => 0})
                . ' has been here as IPs:'
                . $TABLEHEAD
                . '<th>IP</th><th>When</th><th>Look up</th></tr>'
                ;

            $csr = $DB->sqlSelectMany(
                $selectString
                , 'iplog'
                , "iplog_id > $lowID "
                    . " AND iplog_user = '$usr->{user_id}' "
                    . " ORDER BY iplog_id DESC"
                , $resultLimit
            );  #fast - iplog_id key field

        } else {

            $str .= 'Deleted users have been here as IPs:'
                . $TABLEHEAD
                . '<th>IP</th><th>When</th><th>Look up</th></tr>'
                ;
            $csr = $DB->sqlSelectMany(
                $selectString
                , 'iplog LEFT JOIN user ON iplog_user = user.user_id'
                , "iplog_id > $lowID AND user.user_id IS NULL"
                    . " ORDER BY iplog_id DESC"
                , $resultLimit
            );  #fast - iplog_id key field

        }

        my $i = 0;
        while (my $ROW = $csr->fetchrow_hashref) {
            my ($strike, $unstrike) = ('', '');
            ($strike, $unstrike) = ('<strike><b>', '</b></unstrike>')
                if $ROW->{banned} || $ROW->{banned_ranged};
            $str .= '<tr><td>' . (++$i) . '</td>'
                . '<td>'
                . $strike
                . linkNode(
                    $NODE
                    , $ROW->{iplog_ipaddy}
                    , {hunt_ip => $ROW->{iplog_ipaddy}}
                )
                . $unstrike
                . '</td>'
                . '<td>' . $humanTime->($ROW->{iplog_time}) . '</td>'
                . '<td>' . htmlcode('ip lookup tools', $ROW->{iplog_ipaddy}) . '</td>'
                . "</tr>\n"
                ;
        }

        $str .= '</table>';

        return $str;

    }

    $str .= 'Please enter an IP address or a name to continue';
    return $str;
}

sub usergroup_message_archive_manager {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<p>\n";
    $str .= "This simple-minded doc just makes it easy to set if usergroups have their messages automatically archived. Users can read the messages at the <a href=\""
        . htmlcode('urlGen', {'node' => 'usergroup message archive', 'type' => 'superdoc'})
        . "\">usergroup message archive</a> superdoc.\n";
    $str .= "<br /><small>Complain to N-Wing about problems and/or error messages you get.</small>\n";
    $str .= "</p>\n";
    $str .= "<p>Note: to make a change, you must choose what you want from the dropdown menu <strong><big>and</big> check the checkbox next to it</strong>. (This is to help reduce accidental changes.)</p>\n";
    $str .= "<p>\n";

    my $uID = getId($USER);
    return 'Ack! You don\'t exist!' unless $uID;
    return 'Ack! You shouldn\'t see this!' unless $APP->isAdmin($USER);

    my $usergroup_list = [];

    my $csr = $DB->sqlSelectMany("node_id", "node", "type_nodetype=" . getId(getType('usergroup')));
    while (my $ug = $csr->fetchrow_arrayref) {
        push @$usergroup_list, $ug->[0];
    }

    #change setting information
    #things to do:
    #	0 = nothing
    #	1 = delete key
    #	2 = add key with value 1

    my @whatDid = ();
    my @origQueryParams = $query->param;
    foreach (@origQueryParams) {
        next unless /^umam_sure_id_(.+)$/ && ($query->param($_) eq '1');
        my $ug_id = $1;
        my $valName = 'umam_what_id_' . $ug_id;
        my $parm = $query->param($valName);

        $query->delete($_);  #don't want sticky settings
        $query->delete($valName);  #don't want sticky settings

        unless ((defined $parm) && length($parm) && ($parm ne '0')) {
            #don't do anything if user doesn't want a change
            next;
        }
        my $ug = getNodeById($ug_id);

        if ($parm eq '1') {
            #disable archiving for a usergroup
            $APP->delParameter($ug_id, $USER, 'allow_message_archive');
            push(@whatDid, 'Disabled auto-archive for <a href=' . htmlcode('urlGen', {'node_id' => $ug_id}) . '>' . encodeHTML($ug->{title}, 1) . '</a>.');
        } elsif ($parm eq '2') {
            #enable archiving for a usergroup
            $APP->setParameter($ug_id, $USER, 'allow_message_archive', 1);
            push(@whatDid, 'Enabled auto-archive for <a href=' . htmlcode('urlGen', {'node_id' => $ug_id}) . '>' . encodeHTML($ug->{title}, 1) . '</a>.');
        }
    }

    #display what changes were made
    $str = '';
    if (scalar(@whatDid)) {
        $str = 'Made ' . scalar(@whatDid) . ' change' . (scalar(@whatDid) == 1 ? '' : 's') . ':</p><ul>
<li>' . join('</li>
<li>', @whatDid) . '</li>
</ul><p>
';

    }


    #table header
    $str .= htmlcode('openform') . '
<table border="1" cellpadding="1" cellspacing="0">
';
    $str .= '<tr><th>change this</th><th>usergroup</th><th>current status</th><th><code>/msg</code>s</th></tr>
';

    my $genDoWhat = sub {
        my $ug_id = shift;
        my %disps = ();
        my $formName = undef;
        my $ug_archiving = $APP->getParameter($ug_id, 'allow_message_archive');

        if ($ug_archiving) {
            $disps{0} = '(stay archiving)';
        } else {
            $disps{0} = '(stay not archiving)';
        }
        $disps{1} = 'no archiving';
        $disps{2} = 'start archiving';
        $formName = 'id_' . $ug_id;

        my @vals = sort(keys(%disps));
        return '<input type="checkbox" name="umam_sure_' . $formName . '" value="1" />' . $query->popup_menu('umam_what_' . $formName, \@vals, 0, \%disps);
    };


    #show valid usergroups
    $str .= '<tr><th colspan="4">u s e r g r o u p s</th></tr>';
    my $numArchive = 0;
    my $numNotArchive = 0;
    foreach my $s (@$usergroup_list) {

        my $ug = getNodeById($s);
        my $title = $ug->{title};

        $str .= '<tr><td>' . $genDoWhat->($ug->{node_id});
        $str .= '</td><td><a href=' . htmlcode('urlGen', {'node_id' => $ug->{node_id}}) . '>' . $title . '</a></td><td>';
        if ($APP->getParameter($ug->{node_id}, "allow_message_archive")) {
            ++$numArchive;
            $str .= 'archiving';
        } else {
            ++$numNotArchive;
            $str .= 'not archiving';
        }
        $str .= '</td><td><a href=' . htmlcode('urlGen', {'node' => 'usergroup message archive', 'type' => 'superdoc', 'viewgroup' => $title}) . '>(view)</a></td></tr>
';
    }


    #table footer
    $str .= '</table>
' . htmlcode('closeform');

    #stats
    my $stats = 'Stats:</p><ul>';
    $stats .= '<li>' . $numNotArchive . ' usergroup' . ($numNotArchive == 1 ? '' : 's') . ' not archiving</li>
' if $numNotArchive;
    $stats .= '<li>' . $numArchive . ' usergroup' . ($numArchive == 1 ? '' : 's') . ' archiving</li>
' if $numArchive;
    $stats .= '</ul><p>
';


    return $stats . $str . "</p>\n";
}

sub usergroup_press_gang {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '';
    my $usernames = '';
    my $groopname = '';
    my $ugroop = undef;
    my $count = 0;

    # Check if we're processing a submission
    if (defined $query->param('usernames') && defined $query->param('groupname')) {
        $usernames = $query->param('usernames');
        $groopname = $query->param('groupname');
        $ugroop = getNode($groopname, 'usergroup');

        if (!$ugroop) {
            return '<p><font color="#c00000">Group <b>"' . $groopname . '"</b> does not exist.</font></p>';
        } else {
            $str .= "<p>Adding users to group <b>" . linkNode($ugroop->{node_id}) . ":</b></p>\n";
        }

        # Remove whitespace from beginning and end of each line
        $usernames =~ s/\s*\n\s*/\n/g;

        my @users = split('\n', $usernames);

        $str .= "<ol>\n";

        $count = 0;

        foreach my $username (@users) {
            my $user = getNode($username, 'user') || getNode($username, 'usergroup');

            if ($user) {
                $DB->insertIntoNodegroup($ugroop, -1, [getId($user)]);

                $str .= '<li>' . linkNode($user->{node_id}) . "</li>\n";
            } else {
                $str .= "<li><font color=\"#c00000\">User <b>\"" . $username . "\"</b> does not exist.</font></li>\n";
            }

            ++$count;
        }

        $str .= "</ol>\n";

        $str .= "<p>No users specified.</p>\n" if ($count == 0);

        return $str;
    }

    # Not processing, show the form
    $str = "<p>This thing adds a list of users to a given usergroup. It's a <strike>little bit </strike><ins>lot</ins> more convenient than the node bucket. </p>\n\n";

    # If there's a group_id param, that takes precedence over a
    # groupname. It's not likely that we'll have both: group_id
    # is here so we can link from a usergroup display or edit
    # page.
    # We just pop the name in the edit and then get the usergroup
    # node all over again when the user submits. Oh, well.
    if (defined $query->param('group_id')) {
        $ugroop = getNodeById($query->param('group_id'));
        $query->param('groupname', $ugroop->{title});
    }

    $usernames = $query->param('usernames') || '';

    $str .= htmlcode('openform2', 'pressgang');
    $str .= "<table>\n";
    $str .= "<tr><td valign=\"top\" align=\"right\" width=\"80\">\n";
    $str .= "<p>Add user(s)</p>\n";
    $str .= "<p><i>Put each username on its own line, and don't hardlink them.</i></p>\n";
    $str .= "</td>\n";
    $str .= "<td>\n";
    # I cannot for the life of me figure out how $query->textarea( ) is supposed to work.
    $str .= "<textarea name=\"usernames\" rows=\"20\" cols=\"30\">$usernames</textarea>\n";
    $str .= "</td>\n";
    $str .= "</tr>\n";
    $str .= "<tr><td valign=\"top\" align=\"right\">to usergroup</td> <td>\n";
    $str .= $query->textfield('groupname');
    $str .= "</td></tr>\n";
    $str .= "<tr><td valign=\"top\" colspan=\"2\" align=\"right\">";
    $str .= htmlcode('closeform');
    $str .= "</td></tr>\n";
    $str .= "</table>\n\n";

    $str .= "<br />\n";
    $str .= "<hr />\n\n";

    return $str;
}

sub node_notes_by_editor {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $targetStr = '';
    my $targetUser = undef;
    my $targetVars = undef;

    $targetStr .= "<label>Editor Username:"
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

    my $str = $query->start_form('get');
    $str .= $targetStr;
    $str .= $query->submit('gotime', 'Go!');
    $str .= $query->end_form();

    if ($query->param('gotime')) {
        my $uid = getId($targetUser);
        my $where = "noter_user=" . $uid;
        my %linkpram = ();

        my $start = $query->param('start') || '0';
        my $limit = $query->param('limit') || '50';
        my $prev = '';
        my $next = '';
        my $end = $limit;

        my $count = $DB->sqlSelect('count(*)', 'nodenote', $where);

        if ($start) { ## PREV
            my $prevstart = $start - $limit;
            $prevstart = 0 if $prevstart < 0;
            $prev = '<th nowrap="nowrap">( '
                . linkNode($NODE, "prev", {'start' => $prevstart, %linkpram}) . ' )</th>';
            $end = $start + $limit;
            $end = $count if $end > $count;
        }

        if ($start + $limit < $count) { ## NEXT
            $next = '<th nowrap="nowrap">( '
                . linkNode($NODE, "next", {'start' => $start + $limit, %linkpram}) . ' )</th>';
        }

        my $csr = $DB->sqlSelectMany(
            'node_id, type_nodetype, author_user, notetext, timestamp'
            , 'nodenote JOIN node ON node.node_id=nodenote.nodenote_nodeid'
            , $where
            , " ORDER BY timestamp DESC
            LIMIT $start,$limit"
        ) || return "$!";

        my $paging = '';

        if ($prev or $next) {
            $paging = "<table width='95%'>\n\t<tr>$prev"
                . "\n\t<th width='100%'>Viewing $start through $end of $count</th>"
                . "$next</tr>\n</table><br>";
        }

        $str = "$paging
            <table width='95%'><tr><th>Node</th><th>Note</th><th>Time</th></tr>";

        my $writeup = getId(getType('writeup'));
        my $draft = getId(getType('draft'));

        while (my $ref = $csr->fetchrow_hashref()) {
            next unless $ref->{node_id};
            my $note = $ref->{notetext};
            $note =~ s/</&lt;/g;
            my $time = htmlcode('parsetimestamp', "$ref->{timestamp},128");
            my $link = linkNode($ref->{node_id});
            my $author = '';

            if ($ref->{type_nodetype} == $writeup || $ref->{type_nodetype} == $draft) {
                $author = ' <cite>by '
                    . linkNode($ref->{author_user})
                    . '</cite>';
            }

            $str .= "\n\n\t<tr><td>$link$author</td><td>$note</td><td nowrap>$time</td></tr>";
        }

        $csr->finish();

        $str .= "\n</table><br>$paging";
    } else {
        return $str;
    }

    return $str;
}

sub nodetype_changer {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '';

    if ($query->param("new_nodetype")) {
        $DB->sqlUpdate('node', {type_nodetype => $query->param("new_nodetype")}, 'node_id=' . $query->param("change_id"));
    }

    if ($query->param("oldtype_id")) {
        my $N = getNodeById($query->param("oldtype_id"));

        return '' unless $N;

        $str .= "<P>" . $N->{title} . " is currently a: " . getNodeById($N->{type_nodetype}, 'light')->{title} . "</p>";

        $str .= htmlcode('openform');

        my (@NTYPES) = $DB->getNodeWhere({type_nodetype => getId(getType('nodetype'))});

        $str .= "<select name='new_nodetype'>";
        foreach (@NTYPES) {
            my $t = $_->{title};
            $str .= "<option value='$_->{node_id}'>$t</option>";
        }
        $str .= "</select>";
        $str .= $query->hidden("change_id", $query->param("oldtype_id"));
        $str .= $query->submit("sexisgood", "update");
    } else {
        $str .= htmlcode('openform');
        $str .= "Node Id: " . $query->textfield("oldtype_id", "", 20);
        $str .= " " . $query->submit("sexisgood", "get data");
    }

    return $str;
}

sub raw_node_editor {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "Sometimes we need fire to fight fire... \n<p>This allows you to edit a node and all its fields directly. \n";

    $str .= htmlcode('openform');
    $str .= "\n";

    $str .= 'id: ' . $query->textfield('editnode') . ' or name and type: ' . $query->textfield('editnodetitle') . ', ' . $query->textfield('editnodetype');

    $str .= "\n<p>\n";

    my $EDITNODE = getNodeById(scalar $query->param('editnode'));
    my $name = $query->param('editnodetitle');
    my $title = $query->param('editnodetype');

    if ($name and $title) {
        $EDITNODE ||= getNode($name, $title);
    }

    $str .= '<br />';

    if($EDITNODE)
    {
        my $fields_str = '';

        foreach my $field (keys %$EDITNODE) {
            next if $field eq "passwd";
            $fields_str .= "$field:";
            $fields_str .= $query->textfield($field, encodeHTML($EDITNODE->{$field}), 40);
            $fields_str .= "<br />\n";
        }

        $str .= $fields_str;
    }else{
      $str .= "(no node)" 
    }

    $str .= htmlcode('closeform');
    return $str;
}

sub the_borg_clinic {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $borg_victim = '';

    if (defined($query->param('clinic_user'))) {
        $borg_victim = $query->param('clinic_user');
    } else {
        $borg_victim = $USER->{title};
    }

    my $str = 'Circle circle, dot dot, now you\'ve got your borg shot!<br><br>
Who needs to be looked at?<br>
<form method="post">
<input type="hidden" name="node_id" value="1142758">
<input type="text" name="clinic_user" value="' . $borg_victim . '">';

    my $borged_user = getNode($borg_victim, 'user');

    if (defined($borged_user)) {
        my $borged_vars = getVars($borged_user);
        my $num = $borged_vars->{numborged};

        if (defined($query->param('clinic_borgcount'))) {
            if ($USER->{title} eq $borged_user->{title}) {
                $VARS->{numborged} = $query->param('clinic_borgcount');
                $num = $VARS->{numborged};
            } else {
                $borged_vars->{numborged} = $query->param('clinic_borgcount');
                setVars($borged_user, $borged_vars);
                $num = $borged_vars->{numborged};
            }
        }

        if (defined($query->param('clinic_user'))) {
            $str .= '<br><small>borg count:</small><br><input type="text" name="clinic_borgcount" value="' . $num . '"><br><small>Users stay borged for 4 minutes plus two minutes times this number. (4 + (2 * x))<br><ul>Quick math (should it ever come to this):<li>28 is an hour<li>714 is a day<li>5038 is a week</ul><br>Negative numbers are "borg insurance", meaning that you pop out instantly.</small><br><br>[The Borg Clinic|I\'d like another patient]<br><br>';
        }

        $str .= '<br><br>';
    } else {
        $str .= '<br><br>You need a patient!  I can\'t find a user "' . $query->param('clinic_user') . '" on the system!';
    }

    $str .= '<br><input type="submit" value="Do it!">';
    $str .= '</form>';

    return $str;
}

sub the_killing_floor {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = htmlcode('openform');

    # DEPRECATED: this is used instead: [the killing floor II]
    # return 'You\'re in the wrong section, buddy!';

    $str .= 'Are ya shure ya wanna kill all these perty nodes?<p><ol>';

    return $USER->{title} . " ain't allowed ta kill nuttin'!" unless (Everything::isApproved($USER, getNode('Content Editors', 'usergroup')) || $APP->isAdmin($USER));

    my (@param) = $query->param;

    my $parent = undef;

    foreach (@param) {
        next unless /killnode(\d+)/;
        my $N = getNodeById($1);

        if (!$parent) {
            $parent = $N->{parent_e2node};
        }

        $str .= "<input type=\"hidden\" name=$_ value=\"1\">";
        $str .= "<input type=hidden name=nopain" . getId($N) . " value=1>" if defined $query->param('nopain' . getId($N));
        $str .= "<input type=hidden name=noderow" . getId($N) . " value=1>" if defined $query->param('noderow' . getId($N));
        $str .= '<li>' . linkNode($N) . ' by ' . linkNode($N->{author_user});
        $str .= ' (mercifully)' if defined $query->param("nopain" . getId($N));
        $str .= ' (node row)' if defined $query->param("noderow" . getId($N));
        $str .= "</li>\n";
    }

    return '(empty)' unless $parent;

    $str .= '<p align="right">' . $query->submit('op', 'massacre');
    $str .= '<p>' . linkNode($parent, 'Changed my mind.');
    $str .= $query->end_form;

    $str .= '</ol>';

    return $str;
}

sub viewvars {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '';

    foreach (keys %$VARS) {
        $str .= "$_ : $VARS->{$_}<br>";
    }

    return $str;
}

sub who_killed_what {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    return '' unless $APP->isAdmin($USER);

    my $str = htmlcode('openform');
    $str .= 'And what has' . $query->textfield('heavenuser') . ' been up to?<br />';

    my @offset = (0..25);
    foreach (@offset) { $_ *= 200 }
    $str .= 'offset: ' . $query->popup_menu('offset', \@offset);

    my @limit = (1..10);
    foreach (@limit) { $_ *= 50 }
    $str .= 'limit: ' . $query->popup_menu('limit', \@limit);

    $str .= htmlcode('closeform');

    $str .= "\n\n\n<table width=\"100%\">\n";
    $str .= "<tr><th>Time</th><th>Title</th><th>Author User</th><th>Rep</th></tr>\n";

    return $str unless $APP->isAdmin($USER);

    my $offset = int($query->param('offset'));
    $offset ||= 0;
    my $limit = int($query->param('limit'));
    $limit ||= 100;
    my $U = $USER;

    if ($query->param('heavenuser') and $APP->isAdmin($USER)) {
        $U = getNode($query->param('heavenuser'), 'user');
    }

    $U or return 'Hmm... no user.  You loser.';

    my $csr = $DB->sqlSelectMany('*', 'heaven', 'type_nodetype=' . getId(getType('writeup')) . ' and killa_user=' . getId($U), "order by title limit $offset, $limit");
    my $num = $DB->sqlSelect('count(*)', 'heaven', 'type_nodetype=' . getId(getType('writeup')) . ' and killa_user=' . getId($U));

    my $results_str = '';
    my $count = 0;
    my $T = getNode('Node Heaven Visitation', 'superdoc');

    while (my $N = $csr->fetchrow_hashref) {
        $count++;
        $results_str .= "<tr><td>$N->{createtime}</td><td>"
            . linkNode($T, $N->{title}, {visit_id => $N->{node_id}})
            . '</td><td>' . linkNode($N->{author_user}) . '</td><td>' . $N->{reputation} . "</td><tr>\n";
    }

    $str .= "<tr><td>Kill count: $num</td></tr>" . $results_str;

    $str .= "</table>";

    return $str;
}

sub the_node_crypt {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "Here is where the nodes come to rest, after being\nskillfully slain by an editor or god.  \n/Tell them, if you believe this\naction was unjust...  for nodes may live again.<p>\n\n\n<p>\n\n";

    if (defined $query->param('opencoffin')) {
        my $node_id = $query->param('opencoffin');
        $str .= '<h2 align="center">' . linkNode($NODE, 'close the coffin') . "</h2>";

        # Check if node has already been resurrected
        my $existing = $DB->getNodeById($node_id);
        if ($existing) {
            $str .= '<h2 align="center" style="color: green;">This node has already been resurrected!</h2>';
            $str .= '<p align="center">View it here: ' . linkNode($existing) . '</p>';
        } else {
            my $LAB = getNode("dr. nate's secret lab", 'restricted_superdoc');
            $str .= '<h2 align="center">' . linkNode($LAB, 'RESURRECT', {olde2nodeid => $node_id}) . '</h2>';
        }

        my $N = $DB->sqlSelectHashref('*', 'tomb', 'node_id=' . $DB->{dbh}->quote($node_id));
        return "uh, nope -- $node_id didn't work" unless $N;

        my $DATA = safe_deserialize_dumper('my ' . $N->{data});
        return "uh, nope -- deserialization failed for $node_id" unless $DATA;

        @$N{keys %$DATA} = values %$DATA;
        delete $N->{data};

        $str .= '<p>items: ' . scalar(keys(%$N)) . '</p>';
        $str .= '<table width="100%"><tr><th>Field</th><th>Value</th></tr>
';
        foreach (keys %$N) {
            $str .= '<tr><td valign="top"><strong>' . $_ . '</strong></td><td>';
            if (/\_/ and $N->{$_} != -1) {
                $str .= linkNode($N->{$_});
            } else {
                $str .= $N->{$_};
            }
            $str .= '</td></tr>
';
        }
        $str .= '</table>';

        return $str;
    }

    $str .= '<table border="1" cellpadding="2" cellspacing="0"><tr><th>Node Title</th><th>Type</th><th>Author</th><th>Killa</th></tr>';

    my $csr = $DB->sqlSelectMany('title, type_nodetype, author_user, killa_user, node_id', 'tomb');

    my $numItems = 0;

    while (my $N = $csr->fetchrow_hashref()) {
        if ($N->{killa_user} == -1) { $N->{killa_user} = 0 }

        $str .= '<tr><td>' . linkNode($NODE, $N->{title}, {opencoffin => $N->{node_id}}) . '</td><td>' . linkNode($N->{type_nodetype}, '', {lastnode_id => 0}) . '</td><td>';
        if ($N->{author_user} == -1) {
            $str .= 'none';
        } else {
            $str .= linkNode($N->{author_user}, '', {lastnode_id => 0});
        }
        $str .= '</td><td>' . linkNode($N->{killa_user}, '', {lastnode_id => 0}) . '</td></tr>
';
        ++$numItems;
    }

    $csr->finish;

    $str .= '</table></p>
<p>number of items: ' . $numItems . '</p>';
    $str .= '<p align="right"><i>In pace requiescant.</i></p>';

    return $str;
}

sub the_oracle_classic {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    return '' unless $APP->isAdmin($USER);

    # Handle variable editing/updating first
    if (defined($query->param("new_value"))) {
        my $u = getNode($query->param("new_user"), "user");
        my $v = getVars($u);

        $v->{$query->param("new_var")} = $query->param("new_value");
        setVars($u, $v);

        if ($u->{user_id} == $USER->{user_id}) {
            $VARS = $v;
        }

        getVars($u);

        return $v->{$query->param("new_var")};
    }

    # Handle individual variable editing form
    my $varEdit = $query->param("varEdit");
    if ($varEdit and $query->param('userEdit')) {
        my $orasubj = $query->param('userEdit');
        my $oraref = getNode($orasubj, 'user');
        my $v = getVars($oraref);

        my $str = '';
        $str .= htmlcode('openform');
        $str .= "Editing " . $orasubj . " - var <b>$varEdit</b><br />";
        $str .= "<b>Old Value:</b> " . $v->{$varEdit} . "<br />";
        $str .= "<b>New Value:</b> " . $query->textfield('new_value', "", 50);
        $str .= $query->hidden("new_user", $orasubj);
        $str .= $query->hidden("new_var", $varEdit);
        $str .= htmlcode('closeform');

        return $str;
    }

    # Handle display of all variables for a user
    my $orasubj = $query->param('the_oracle_subject');
    if ($orasubj) {
        my $oraref = getNode($orasubj, 'user');
        my $hash = getVars($oraref);
        my $return = '';

        $return = '<table border="0" cellpadding="2" cellspacing="1">';
        foreach (sort(keys(%{$hash}))) {
            next if ($_ eq 'noteletRaw');
            next if ($_ eq 'noteletScreened');
            $hash->{$_} = "&nbsp;" if (!$hash->{$_});
            $return .= '<tr><td>' . $_ . '</td><td>=</td><td>' . $hash->{$_};
            $return .= " " . linkNode($NODE, "edit", {userEdit => $orasubj, varEdit => $_}) . " ";
            if ($_ eq 'ipaddy') {
                $return .= linkNode(getNode('IP Hunter', 'restricted_superdoc'), "check other users with this IP", {hunt_ip => $hash->{$_}});
            }
            $return .= '</td></tr>';
        }
        $return .= '</table>';

        return $return;
    }

    # Default: show welcome form
    my $welcome = 'Welcome to the User Oracle. Please enter a user name<br>';
    $welcome .= htmlcode('openform');
    $welcome .= $query->textfield('the_oracle_subject');
    $welcome .= htmlcode('closeform');

    return $welcome;
}

sub typeversion_controls {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = 'Do-na-touch!

';
    $str .= htmlcode('openform');
    $str .= '<INPUT type="hidden" name="confirmpage" value="1">';

    my @nodetypes = $DB->getNodeWhere({type_nodetype => 1}, "nodetype");
    my %TVERSIONS = ();
    my %NEWVERSIONS = ();

    if (my $csr = $DB->sqlSelectMany("*", 'typeversion')) {
        while (my $N = $csr->fetchrow_hashref) {
            $TVERSIONS{$N->{typeversion_id}} = 1;
        }
        $csr->finish;
    }

    if (defined $query->param('confirmpage')) {
        foreach ($query->param) {
            next unless /^typeify_(\d+)$/;
            my $n_id = $1;
            $NEWVERSIONS{$n_id} = 1;
            if (not $TVERSIONS{$n_id}) {
                $DB->sqlInsert("typeversion", {typeversion_id => $n_id, version => 1});
            }
        }

        foreach (keys %TVERSIONS) {
            if (!exists $NEWVERSIONS{$_}) {
                $DB->sqlDelete("typeversion", "typeversion_id=$_");
            }
        }
    } else {
        %NEWVERSIONS = %TVERSIONS;
    }

    foreach (@nodetypes) {
        $str .= $query->checkbox('typeify_' . getId($_), exists($NEWVERSIONS{getId($_)}), 1, $_->{title}) . "<br>";
    }

    $str .= htmlcode('closeform');

    return $str;
}

sub user_statistics {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $csr = $DB->getDatabaseHandle()->prepare("select count(user_id) from user where unix_timestamp(lasttime)>(unix_timestamp(now())-3600*24)");
    $csr->execute or return "SHIT";
    my ($userslast24) = $csr->fetchrow_array;

    $csr = $DB->getDatabaseHandle()->prepare("select count(user_id) from user where unix_timestamp(lasttime)>(unix_timestamp(now())-3600*24*7)");
    $csr->execute or return "SHIT";
    my ($userslastweek) = $csr->fetchrow_array;

    $csr = $DB->getDatabaseHandle()->prepare("select count(user_id) from user where unix_timestamp(lasttime)>(unix_timestamp(now())-3600*24*7*2)");
    $csr->execute or return "SHIT";
    my ($userslast2weeks) = $csr->fetchrow_array;

    $csr = $DB->getDatabaseHandle()->prepare("select count(user_id) from user where unix_timestamp(lasttime)>(unix_timestamp(now())-3600*24*7*4)");
    $csr->execute or return "SHIT";
    my ($userslast4weeks) = $csr->fetchrow_array;

    $csr = $DB->getDatabaseHandle()->prepare("select count(user_id) from user");
    $csr->execute or return "SHIT";
    my ($totalusers) = $csr->fetchrow_array;

    $csr = $DB->getDatabaseHandle()->prepare("select count(user_id) from user where lasttime not like \"0%\"");
    $csr->execute or return "SHIT";
    my ($userseverloggedin) = $csr->fetchrow_array;

    return "<TABLE>
    <TR><TD align=right><B>$totalusers</B></TD><TD> total users registered</TD></TR>
    <TR><TD align=right><B>$userseverloggedin</B></TD><TD> unique users logged in ever</TD></TR>
    <TR><TD align=right><B>$userslast4weeks</B></TD><TD> users logged in within the last 4 weeks</TD></TR>
    <TR><TD align=right><B>$userslast2weeks</B></TD><TD> users logged in within the last 2 weeks</TD></TR>
    <TR><TD align=right><B>$userslastweek</B></TD><TD> users logged in within the last week</TD></TR>
    <TR><TD align=right><B>$userslast24</B></TD><TD> users logged in within the last 24 hours</TD></TR>
    </TABLE>
   ";
}

sub usergroup_attendance_monitor {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    return '' unless $APP->isAdmin($USER);

    my $people = {};
    my $str = '';
    my $csr = $DB->sqlSelectMany("node_id", "node", "type_nodetype=" . getId(getType("usergroup")));

    while (my $row = $csr->fetchrow_hashref) {
        my $N = getNodeById($row->{node_id});
        foreach (@{$N->{group}}) {
            $people->{$_} ||= "";
            $people->{$_} .= $N->{node_id} . ",";
        }
    }

    foreach my $uid (keys %$people) {
        my $p = $DB->sqlSelect("user_id", "user", "user_id=$uid and TO_DAYS(NOW()) - TO_DAYS(lasttime) > 365");
        next unless $p;
        $str .= "<li>" . linkNode(getNodeById($p)) . " (<small>";
        my @grps = ();
        foreach (split(",", $people->{$p})) {
            my $ministr = linkNode($_);
            if ($DB->sqlSelect("messageignore_id", "messageignore", "messageignore_id=$p and ignore_node=$_")) {
                $ministr .= "-ignored";
            }
            push @grps, $ministr;
        }
        $str .= join ",", @grps;
        $str .= "</small>)";
    }

    return "Users that haven't been here in 30 days.  I propose that we auto remove someone who hasn't been to the site in 30 days unless they choose to ignore a certain usergroup's messages (with the exception of: [gods] and [content editors]).  With usergroup ownership, it is now much easier for people to be able to manage those groups. For now, here is an active, automatic list.
<br><br><p align=\"center\"><hr width=\"30%\"></p><br>
<ul>$str</ul>";
}

sub users_with_infravision {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $queryText = "SELECT user.user_id,user.GP FROM setting,user WHERE setting.setting_id=user.user_id AND setting.vars LIKE '%infravision=1%'";

    my $rows = $DB->{dbh}->prepare($queryText);
    return "Database prepare error" unless $rows;

    $rows->execute() or return "Database execute error";

    my @list = ();
    while (my $dbrow = $rows->fetchrow_arrayref) {
        push(@list, linkNode($dbrow->[0]));
    }

    my $str = '';
    $str .= '<h3>Users with infravision</h3>';
    $str .= '<ol style="margin-left:55px">';
    foreach my $key (sort { lc($a) cmp lc($b) } @list) {
        $str .= '<li>' . $key . '</li>';
    }
    $str .= '</ol>';

    return $str;
}

sub voting_data {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '';

    if ($query->param("voteday")) {
        my $vd = $query->param("voteday");
        my $vd2 = $query->param("voteday2") || $vd;
        my $vc = $DB->sqlSelect("count(*)", "vote", "votetime>='$vd 00:00:00' and votetime<='$vd2 23:59:59'");
        $str .= "<p>Vote Results: $vc</p>";
    }

    if ($query->param("votemonth")) {
        my $vm = $query->param("votemonth");
        my $vy = $query->param("voteyear");
        for (my $x = 1; $x <= 31; $x++) {
            my $checkdate = $vy . "-" . $vm . "-" . sprintf("%02s", $x);
            my $vc = $DB->sqlSelect("count(*)", "vote", "votetime>='$checkdate 00:00:00' and votetime<='$checkdate 23:59:59'");
            $str .= $checkdate . " : " . $vc . "<br />";
        }
    }

    $str .= htmlcode('openform');
    $str .= "Start Date: " . $query->textfield("voteday", "", 10) . "<br />";
    $str .= "Finish Date: " . $query->textfield("voteday2", "", 10) . "<br />";
    $str .= "<p><b>Month Breakdown</b></p>

Year: " . $query->textfield("voteyear", "", 10) . "<br />
Month: " . $query->textfield("votemonth", "", 10) . "<br />";

    $str .= htmlcode('closeform');

    return $str;
}

sub altar_of_sacrifice {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '<p>Welcome to the mountaintop. Don\'t mind the blood.
</p>

<p><strong>N.B.:</strong> If you used the previous version of this page, be aware that this tool has been sharpened: it <em>will</em> remove the writeups you select.
</p>

<h2>Instructions
</h2>

<ol>
<li>Enter a user\'s name in the box. Sumbit.
</li>
<li>Choose which writeups to spare (if any) from the list provided, or choose to remove all writeups at once.
</li>
<li>Confirm that you really want to do this.
</li>
<li>Repeat as necessary.
</li>
<li>Shed a tear, keep a minute\'s silence, then hold up the bloody heart to the crowd.
</li>
</ol>

';

    $str .= htmlcode('openform');
    $str .= '<fieldset><legend>

';

    my $userName = $query->param('author');
    my $user = 0;
    my $tmpStr = '';

    if ($userName) {
        $user = getNode($userName, 'user');
        if (!$user) {
            $tmpStr = $query->escapeHTML($userName) . ' is not a user.<br>';
        }
    }

    if (!$user) {
        return $str . "Step 1: the victim</legend>
	$tmpStr<label>User name:"
            . $query->textfield('author')
            . '</label>'
            . $query->submit('submit', 'sumbit');
    }

    my $wuType = getType('writeup');

    my ($list, $navigation, $count, $offset, $last) = htmlcode('show paged content', 'title, node_id', 'node', "type_nodetype=$wuType->{node_id} AND author_user=$user->{node_id}", 'ORDER BY title LIMIT 100', '<tr class="&oddrow">axe, "<td>", title, "</td>"', axe => sub {
        $_[0]->{type} = $wuType;
        return $query->td({align => 'center'}, $query->checkbox(-name => "removenode$_[0]->{node_id}", value => 1, label => '', checked => 1));
    });

    if (!$count) {
        return $str . ($query->param('op') eq 'remove' ? 'Step 5' : 'Nothing to do') . "</legend>$user->{title} has no writeups.";
    }

    my $page = $query->param('page') || 1;
    if (($page - 1) || $count > $last) {
        $page = ": page $page";
    } else {
        $page = '';
    }

    $tmpStr = 'Step '
        . ($query->param('op') eq 'remove' ? 4 : 2)
        . ': show mercy (or not)</legend>'
        . $query->hidden('author')
        . $query->h2(linkNode($user) . "'s writeups$page")
        . '<table><tr><th>axe</th><th>title</th>
	' . $list . '
	</table>
	' . $navigation . '
	<input type="hidden" name="op" value="remove">'
        . $query->p($query->label('Reason for removal (optional):' . $query->textfield(-name => 'removereason', size => 50)));

    if ($page) {
        $tmpStr .= $query->p($query->checkbox(-name => 'removeauthor', value => 1, label => "remove all of $user->{title}'s writeups"));
    }

    return $str . $tmpStr . $query->p('<button type="submit" name="confirmop" value="remove"
	title="remove these writeups">Let the axe fall</button>');
}

sub everything2_user_relations__e2contact_and_chanops {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '<p align="center"><h2>E2contact (e2c) and chanops</h2></p>

<p><h3>What is e2c?</h3></p>

<p>' . linkNode('e2contact') . ' is a subset of everything2\'s editorial staff dedicated to user relations, for both new and existing users.</p>

<p><h3>Why is e2c necessary?</h3></p>

<p>e2 is a diverse and complicated community, which presents challenges for both new and established users. In addition to the technical learning curve that new users are expected to climb, they must also tackle the social and cultural element of the site, which can present as hostile or overwhelming initially. As with any community, there exist tensions and relationship issues between established users. By creating a team of staff dedicated to user relations, to help new users navigate their paths through their first weeks and to help established users get the most out of the site, it is hoped to improve e2\'s user experience, thereby allowing for a more creative and productive site.</p>

<p><h3>Who operates e2c?</h3></p>

<p>e2c is currently led by ' . linkNode('mauler') . ', everything2\'s Director of User Relations, who reports into ' . linkNode('Tem42') . ' as everything2\'s Director of Operations.</p>

<p>They are supported by:
<ul></li>
<li>' . linkNode('Dimview') . '</li>
<li>' . linkNode('karma debt') . '</li>
<li>' . linkNode('TheDeadGuy') . '</li>
<li>' . linkNode('vandewal') . '</li>
</ul></p>

<p>The ' . linkNode('chanops') . ' group, which acts similarly to IRC channel operators, falls under e2c\'s umbrella. Following the devolution of catbox powers in May 2009, some gods opted to retain their catbox operational facilities, and joined chanops, too. More on their work can be found under \'Catbox drama\' in this document.</p>

<p>The present members of chanops are:
<ul>
<li>' . linkNode('BookReader') . '</li>
<li>' . linkNode('GhettoAardvark') . '</li>
<li>' . linkNode('moosemanmoo') . '
<li>' . linkNode('NanceMuse') . '</li>
<li>' . linkNode('Oolong') . '</li>
<li>' . linkNode('riverrun') . '.</li></ul></p>

<p>All members of e2c and chanops have the ability to flush the chatterbox and drag users into other rooms as necessary.</p>


<p><h3>What are e2c\'s fields of operation?</h3></p>

<p>e2c has four primary spheres of operation:
<ol><li>New user interaction</li>
<li>Existing user relations</li>
<li>Catbox drama</li>
<li>The mentoring system</li></ol></p>

<p><h5>New user interaction</h5>
Until recently, new users to the site were greeted by an array of automated or rehearsed messages, directing them to the FAQs. e2c has adopted a more simplified approach to greeting new users, sending messages only when a new user has begun to interact with the site in some way – for example by speaking in the catbox – and then only to say hello and ask if she or he would like any help. We would rather that new users have the opportunity to explore, than us bombard and overwhelm their first experiences here. For users who weren\'t welcomed or greeted by a member of staff, you\'ll remember that part if the wonder was being able to wander.</p>

<p>Members of e2c will be available to offer both technical assistance and help of a more abstract nature, for example helping new users to understand e2\'s culture. In particular, e2c intends to help new users learn what it is that e2 looks for in a writeup. However, the aim is to be personal and personable, rather than just directing someone to the FAQs.</p>

<p>If a new user submits a writeup that is questionable, borderline or otherwise isn\'t to the standards and expectations of the site, she or he will be asked to use the scratchpad facility and have her or his draft proofed by an editor prior to submission. New users should also be urged towards the mentoring programme. Any persistently difficult or troublesome users should be referred directly to either TheDeadGuy or mauler.</p>

<p>Troublesome users are a fact of the site; they are always going to be there. Those users whose actions are clearly detrimental to the site and show no willingness or ability to contribute in a positive way should be encouraged to move along. However, it is also important to try to see through the bravura, the bluster, and the general ignorance of some of these people. Never forget that new users have no real vested interest in the site in the way established users do and have no real reason to submit their \'good material\' unless they are given a reason to. Users need to be encouraged, respected, and listened to by staff. For example, just because a user submits a series of ridiculous, stupid, or silly writeups does not mean they are incapable of more. She or he may very well be incapable of more than that, but many may just land on the site thinking: \'What fun! I can submit random shit!\' That\'s what TheDeadGuy did when he first came to e2.</p>

<p><h5>Existing user relations</h5>
e2 is a community. All communities have dynamics, points of inertia, tensions, conflicts, tragedies, and celebrations. e2 is no different from any other community in this respect. Relationships between users, and between users and site management, can therefore on occasion become strained or difficult. For example, it is possible that two users can come into conflict with each other, or an existing user can feel unhappy about a change to site policy. Without wanting to be seen as some form of marriage guidance counselling service, e2c can be made available to help bring some calm and some dialogue in these situations.</p>

<p>There has been a recent suggestion by some older users that the site is not as respectful towards them and their concerns as it should be. Quite specifically, there have been accusations that their contributions are not valued as much as those of newer and more prolific writers. e2c is aimed at user relations, and these concerns are just as valid as the learning experiences of a new user; therefore, e2c should be prepared to listen to these points and to act on them as appropriate.</p>

<p><h5>Catbox drama</h5>
From time-to-time, users choose to play out their personal dramas in the public forum of the catbox. This can and does distress and arouse alarm in other users. Whilst e2c or chanops can have no formal powers of intervention in such situations, there are protocols laid down for dealing with situations where users are threatening suicide, and guidance for young users is in development. Remaining calm and minimising the situation is key in these instances and members of e2c and chanops are expected to act appropriately as such occasions arise.</p>

<p>In addition to site administrators, members of e2c and chanops also have the ability to drag users who are behaving inappropriately or offensively in the catbox from the main room to the debriefing room. Once dragged to the debriefing room, users are held there for 30 minutes. It is not expected for these users to be left alone there, but for she or he to be accompanied by a member of staff and the rationale for expulsion explicated. This feature has proved effective so far and it is expected for e2c and chanops operators to use it at their discretion.</p>

<p><h5>The mentoring system</h5>
Also falling in e2c\'s remit will be the mentoring system, which is planned for a revamp. Members of e2c may be asked to volunteer their time and effort into that programme. In the past, the mentoring system was an effective mechanism for guiding new users through the site, which has fallen into relative disuse recently. There is no reason why it can\'t operate successfully again. New users who indicate a desire or show a need for one-on-one guidance will be encouraged towards the mentoring programme.</p>

<p>The mentoring programme is designed to offer longer-term attention to newer users; whereas e2c is intended to provide them with more immediate and short-term support.</p>

<p><h3>And finally…</h3></p>

<p>Throughout everything that we do, it is worth remembering that e2 is people. If we take care of the people, the content will take care of itself. That comes from alex, but it has never seemed more apt.</p>
';

    return $str;
}

sub fresh_blood {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $usertype = getId(getType('user'));

    my $sql = "select count(*) from `node` where `type_nodetype` = $usertype and `createtime` > date_sub(now(), interval 1 week)";
    my $usr = $DB->{dbh}->prepare($sql);
    $usr->execute or return 'Oh dear. Database oops';
    my ($numUser) = $usr->fetchrow();

    $sql = "select count(*) from `user`, `node` where `user_id` = `node_id` and `createtime` > date_sub(now(), interval 1 week) and `lasttime` > 0";
    $usr = $DB->{dbh}->prepare($sql);
    $usr->execute or return 'Oh dear. Database oops';
    my ($numLoggedIn) = $usr->fetchrow();

    return 'nobody ever comes this way' if ($numLoggedIn == 0 || $numUser == 0);

    my $start = int($query->param('start'));
    $start ||= 0;

    $sql = qq|

SELECT `user_id`, `nick`, `title`,`createtime`, `lasttime`
  , (SELECT `notetext`
      FROM nodenote
      WHERE nodenote_nodeid = user_id LIMIT 1
    ) 'notetext'
  FROM `node`
  JOIN `user`
    ON `node_id`=`user_id`
  WHERE `createtime` > date_sub(now(), interval 1 week)
  ORDER BY createtime
  DESC LIMIT ?, 50 |;

    $usr = $DB->{dbh}->prepare($sql);
    $usr->execute($start) or return 'Oh dear. Database oops';

    my $row = 1;
    my $last = $start + 50;
    if ($last > $numUser) {
        $last = $numUser;
    }

    my $str = "<p>In the past week, $numUser users enrolled. Of those $numLoggedIn logged-in.</p>";
    my $nav = "<p style='text-align: center'>";

    if ($start > 0) {
        $nav .= '&laquo ' . linkNode($NODE, 'Later', {'start' => $start - 50}) . ' ';
    }

    for (my $i = 0; $i < $numUser; $i += 50) {
        $nav .= ($i == $start) ? "<b>$i</b>" : linkNode($NODE, $i ? $i : 1, {'start' => $i});
        $nav .= ' ';
    }

    if ($last < $numUser) {
        $nav .= linkNode($NODE, 'Earlier', {'start' => $start + 50}) . ' &raquo;</p>';
    }

    $str .= $nav;

    $str .= "<table style='width: 100%; border-top: 1px gray solid'><tr><th>Joined</th><th>User</th><th>Last logged in</th><th>Node note</th></tr>\n";
    $usr->fetchrow_hashref;
    while (my $N = $usr->fetchrow_hashref) {
        my $login = htmlcode('timesince', $N->{lasttime});
        my $create = htmlcode('timesince', $N->{createtime});

        $str .= sprintf("\t<tr class='%s'><td>%s</td><td><a href=%s>%s</a></td><td>%s</td><td>%s</td></tr>\n",
            $row ? 'oddrow' : 'evenrow',
            $create,
            "/node/$N->{user_id}",
            $N->{title},
            $login eq '?' ? 'never' : $login,
            $N->{notetext},
        );
        $row = !$row;
    }
    $str .= '</table>' . $nav;

    return $str;
}

sub freshly_bloodied {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $usertype = getId(getType('user'));

    my $sql = "select count(*) from `node` where `type_nodetype` = $usertype and `createtime` > date_sub(now(), interval 1 week)";
    my $usr = $DB->{dbh}->prepare($sql);
    $usr->execute or return 'Oh dear. Database oops';
    my ($numUser) = $usr->fetchrow();

    $sql = "select count(*) from `user`, `node` where `user_id` = `node_id` and `createtime` > date_sub(now(), interval 1 week) AND `acctlock` != 0";
    $usr = $DB->{dbh}->prepare($sql);
    $usr->execute or return 'Oh dear. Database oops';
    my ($numLocked) = $usr->fetchrow();

    return 'nobody ever comes this way' if ($numLocked == 0 || $numUser == 0);

    my $start = int($query->param('start'));
    $start ||= 0;

    $sql = qq|

SELECT `user`.`user_id`, `user`.`nick`
  , `node`.`createtime`, `user`.`validemail`, `user`.`lasttime`
  , `locker`.`node_id` AS locker_id
  , `locker`.`title` AS locker_name
  , (SELECT `notetext`
      FROM `nodenote`
      WHERE `nodenote_nodeid` = `user`.`user_id` LIMIT 1
    ) 'notetext'
  FROM `node`
  JOIN `user`
    ON `node`.`node_id` = `user`.`user_id`
  JOIN `node` AS `locker`
    ON `locker`.`node_id` = `user`.`acctlock`
  WHERE `node`.`createtime` > date_sub(now(), interval 1 week)
    AND `user`.`acctlock` != 0
  ORDER BY `node`.`createtime`
  DESC LIMIT ?, 50|;

    $usr = $DB->{dbh}->prepare($sql);
    $usr->execute($start) or return 'Oh dear. Database oops';

    my $row = 1;
    my $last = $start + 50;
    if ($last > $numLocked) {
        $last = $numLocked;
    }

    my $str = "<p>In the past week, $numUser users enrolled. Of those $numLocked were locked.</p>";
    my $nav = "<p style='text-align: center'>";

    if ($start > 0) {
        $nav .= '&laquo ' . linkNode($NODE, 'Later', {'start' => $start - 50}) . ' ';
    }

    for (my $i = 0; $i < $numLocked; $i += 50) {
        $nav .= ($i == $start) ? "<b>$i</b>" : linkNode($NODE, $i ? $i : 1, {'start' => $i});
        $nav .= ' ';
    }

    if ($last < $numLocked) {
        $nav .= linkNode($NODE, 'Earlier', {'start' => $start + 50}) . ' &raquo;</p>';
    }

    $str .= $nav;

    $str .= "<table style='width: 100%; border-top: 1px gray solid'><tr><th>Joined</th><th>User</th><th>Last logged in</th><th>Node note</th><th>Locked By</th><th>Validated</th></tr>\n";
    $usr->fetchrow_hashref;
    while (my $N = $usr->fetchrow_hashref) {
        my $login = htmlcode('timesince', $N->{lasttime});
        my $create = htmlcode('timesince', $N->{createtime});

        $str .= sprintf("\t<tr class='%s'><td>%s</td><td><a href=%s>%s</a></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n",
            $row ? 'oddrow' : 'evenrow',
            $create,
            "/node/$N->{user_id}",
            $N->{nick},
            $login eq '?' ? 'never' : $login,
            linkNode(getNodeById($N->{locker_id}), $N->{locker_name}),
            $N->{notetext},
            $N->{validemail}
        );
        $row = !$row;
    }
    $str .= '</table>' . $nav;

    return $str;
}

sub homenode_inspector {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $gonetime = $query->param('gonetime') eq '0' ? 0 : $query->param('gonetime') || 0;
    my $goneunit = $query->param('goneunit') || 'MONTH';
    my $showlength = $query->param('showlength') || 1000;
    my $maxwus = $query->param('maxwus') || 0;

    return 'Parameter error' unless
        $maxwus == int($maxwus)
        && $gonetime == int($gonetime)
        && $showlength == int($showlength)
        && $goneunit =~ /year|month|week|day/i;

    my $filter = "doctext != ''";

    $filter .= " AND lasttime < DATE_SUB(NOW(), INTERVAL $gonetime $goneunit)";
    $filter .= " AND numwriteups <= $maxwus";
    $filter .= " AND doctext LIKE '%[http%'" if $query->param('extlinks');
    $filter .= " AND doctext != '...'" unless $query->param('dotstoo');

    my $optionsform = $query->fieldset($query->legend('Options')
        . $query->label('Max writeups:' . $query->textfield('maxwus', $maxwus, 2))
        . '<br>' . $query->label('Not logged in for:' . $query->textfield('gonetime', $gonetime, 2))
        . $query->popup_menu('goneunit', ['year', 'month', 'week', 'day'], 'month')
        . '<br>' . $query->checkbox(-name => 'extlinks'
        , -checked => 0
        , -value => 1
        , -label => 'Only homenodes with external links')
        . '<br>' . $query->checkbox(-name => 'dotstoo'
        , -checked => 0
        , -value => 1
        , -label => 'Include "..." homenodes')
        . '<br>' . $query->label('Only show' . $query->textfield('showlength', $showlength, 3) . 'characters')
        . '<br>' . $query->submit('Go')
    );

    my $smite = sub {
        my $verify = htmlcode('verifyRequestHash', 'polehash');
        return linkNode(getNode('The Old Hooked Pole', 'restricted_superdoc')
            , 'Smite Spammer'
            , {%$verify
            , confirmop => 'remove'
            , removeauthor => 1
            , author => $_[0]{title}
            , -title => 'detonate this noder, blank their homenode, remove their writeups, blacklist their IP where appropriate'
            , -class => 'action'}
        );
    };

    return htmlcode('widget'
        , $optionsform
        , 'form'
        , 'Options'
        , {showwidget => 'optionsform'}
    )
        . htmlcode('show paged content', 'title, node_id, user_id AS author_user, doctext', 'node JOIN user on node_id=user_id JOIN document ON node_id=document_id', $filter, 'ORDER BY lasttime DESC LIMIT 10', "author, $showlength, smite", ('smite' => $smite));
}

sub node_parameter_editor {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '<p>This is a temporary ghetto tool to edit node parameters, and do a bit of testing until we have full parameter support built into the application, with the full removal of $VARS. We\'ll get there, but this isn\'t bad for now.  </p>
<br /><br /><hr width="20%" /><br /><br />
Available types of parameters:
';

    my $for_node = $query->param('for_node');
    if (not defined($for_node)) {
        $str .= "No node to check the parameters for. Use this from the C_E tools menu in Master Control.";
    } else {
        my $f_node = getNodeById($for_node);
        return "No such node_id \'$for_node\'" unless defined $f_node;
        my $all_params_for_type = $APP->getParametersForType($f_node->{type});

        $str .= "<ul>";
        foreach my $param (sort { $a cmp $b } keys %$all_params_for_type) {
            $str .= "<li> $param - " . $all_params_for_type->{$param}->{description} . "</li>\n";
            $str .= '<br />' . htmlcode("openform") . qq|<input type="hidden" name="op" value="parameter"><input type="hidden" name="for_node" value="$f_node->{node_id}"><input type="hidden" name="paramname" value="$param"><input type="text" name="paramvalue"><input type="submit" value="add"></form>|;
        }
        $str .= "</ul>";
    }

    $str .= '<br /><br /><hr width="20%" /><br /><br />';

    $for_node = $query->param('for_node');
    if (not defined($for_node)) {
        $str .= "No node to check the parameters for. Use this from the C_E tools menu in the epicenter";
    } else {
        my $f_node = getNodeById($for_node);
        return "No such node_id \'$for_node\'" unless defined $f_node;
        my $return = "<h3>Node: $f_node->{title} / $f_node->{type}{title}</h3>(node_id: $f_node->{node_id})<br />";
        $return .= "<br /><br />";
        my $params = $DB->getNodeParams($f_node);
        if (scalar(keys %$params) == 0) {
            $return .= "<em>No node parameters</em><br />";
        } else {
            $return .= "<table>";
            $return .= '<tr><td width="30%"><strong>Parameter name</strong></td><td width="50%"><strong>Parameter value</strong></td><td>X</td></tr>';

            foreach my $key (keys %$params) {
                $return .= "<tr><td>" . encodeHTML($key) . "</td><td>" . encodeHTML($params->{$key}) . "</td><td>" . htmlcode("openform") . qq|<input type="hidden" name="op" value="parameter"><input type="hidden" name="for_node" value="$f_node->{node_id}"><input type="hidden" name="paramname" value="$key"><input type="hidden" name="action" value="delete"><input type="submit" value="del"></form></td></tr>|;
            }
            $return .= "</table>";
        }
        $str .= $return;
    }

    return $str;
}

sub renunciation_chainsaw {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '';

    if(    $query->param( 'user_name_from' )
        && $query->param( 'user_name_to' )
        && $query->param( 'namelist' ) )
    {
        my $names    = $query->param( 'namelist' );
        my $userfrom = getNode( $query->param( 'user_name_from' ), 'user' );
        my $userto   = getNode( $query->param( 'user_name_to' ), 'user' );

        return 'There was no user: "'.$query->param('user_name_from').'" back to the '.linkNode($NODE, $NODE->{title}) unless( $userfrom );

        return 'There was no user: "'.$query->param('user_name_to').'" back to the '.linkNode($NODE, $NODE->{title}) unless( $userto );

        my $userfrom_id = $userfrom->{ node_id };
        my $userto_id   = $userto->{ node_id };

        $names =~ s/\s*\n\s*/\n/g;

        my @namelist = split( '\n', $names );

        my $reparent   = '';   # Names of reparented writeups
        my $totalcount = 0;    # Total writeups reparented

        # Realistic error conditions
        my $nonexist   = '';   # The node doesn\'t exist.
        my $nowriteup  = '';   # The node exists, but bonehead has no writeup there.

        # Unlikely error conditions
        my $badowner   = '';   # This is bad: We queried for nodes with a given
                              #   author_user and got some with a different one.
        my $badtype    = '';   # This is bad, too. We queried for writeups and got
                              #   something else.

        foreach my $parentnode ( @namelist )
        {
            next unless( $parentnode );

            my $pnode = getNode( $parentnode, 'e2node' );

            if ( ! $pnode ) {
                $nonexist .= "<dd>[" . $parentnode . "]</dd>\n";
            } else {
                my $csr = $DB->{dbh}->prepare(  'SELECT * FROM node LEFT JOIN writeup '
                                      . 'ON node.node_id = writeup.writeup_id '
                                      . 'where writeup.parent_e2node='
                                      . $pnode->{ node_id } . ' AND node.author_user='
                                      . $userfrom->{ node_id } . ' ' );

                $csr->execute();

                my $count   = 0;
                my $writeup;

                while ( my $ROW = $csr->fetchrow_hashref() )
                {
                    $writeup = getNode( $ROW->{ node_id } );
                    ++$count;

                    if ( $writeup->{ type_nodetype } != 117 ) {
                        $badtype .= "<dd>[" . $parentnode . "]</dd>\n";
                    } elsif ( $writeup->{ author_user } != $userfrom_id ) {
                        $badowner .= "<dd>[" . $parentnode . "]</dd>\n";
                    } else {
                        $writeup->{ author_user } = $userto_id;
                        updateNode( $writeup, $USER );
                        ++$totalcount;
                        $reparent .= "<dd>[" . $parentnode . "]</dd>\n";
                    }
                }

                if ( ! $count ) {
                    $nowriteup .= "<dd>[" . $parentnode . "]</dd>\n";
                }

                $csr->finish();
            }
        }

        $str .= "<dl>\n";

        if ( $reparent ) {
            my $varsfrom = getVars( $userfrom );
            my $varsto   = getVars( $userto );

            my $wuctfrom = int( $varsfrom->{ numwriteups } || 0 );
            my $wuctto   = int( $varsto->{ numwriteups } || 0 );

            $varsfrom->{ numwriteups } = '' . ($wuctfrom - int( $totalcount ));
            $varsto->{ numwriteups }   = '' . ($wuctto + int( $totalcount ));

            setVars( $userfrom, $varsfrom );
            setVars( $userto, $varsto );

            updateNode( $userfrom, $USER );
            updateNode( $userto, $USER );

            $str .=  "<dt><b>" . $totalcount . " writeups re-ownered from "
                   . linkNode( $userfrom_id ) . " to "
                   . linkNode( $userto_id ) . ":</b></dt>\n"
                   . $reparent;
        }

        $str .= "<font color=\"#c00000\">\n";

        if ( $nonexist ) {
            $str .=   "<dt>&nbsp;</dt>";
            $str .=   "<dt><b>Nonexistent nodes:</b> (if you provided "
                    . "writeup titles, they may differ from their "
                    . "parent node titles due to the parent nodes "
                    . "having been renamed)</dt>\n"
                    . $nonexist . "\n";
        }

        if ( $badowner ) {
            $str .=   "<dt>&nbsp;</dt>";
            $str .=   "<dt><b>Wrong <code>author_user</code> "
                    . "(SQL problem; talk to nate):</b></dt>\n"
                    . $badowner . "\n";
        }

        if ( $badtype ) {
            $str .=   "<dt>&nbsp;</dt>";
            $str .=   "<dt><b>Wrong <code>type_nodetype</code> "
                    . "(SQL problem; talk to nate):</b></dt>\n"
                    . $badtype . "\n";
        }

        if ( $nowriteup ) {
            $str .=   "<dt>&nbsp;</dt>";
            $str .=   "<dt><b>" . linkNode( $userfrom_id )
                    . " has nothing here:</b></dt>\n"
                    . $nowriteup . "\n";
        }

        $str .= "</font>\n";
        $str .= "</dl>\n";

        $str .= "&#91; " . linkNode( $NODE->{ node_id }, 'back' ) . " &#93;\n";
    }
    else
    {
        # wharf: this is a usability fix from me:
        my $wu;
        my @foo = ("", "");
        if($query->param('wu_id')){
            $wu = getNodeById($query->param('wu_id'));
            if($wu->{type_nodetype} == getId(getType('writeup')))
            {
                my $auth = getNodeById($wu->{author_user});
                $foo[0] = $auth->{title};
                $auth = getNodeById($wu->{parent_e2node});
                $foo[1] = $auth->{title};
            }
        }

        $str =
        htmlcode( 'openform' ) .
        '
Change ownership of writeups from user
<input type="text" name="user_name_from" value="'.$foo[0].'"><br />
to user
<input type="text" name="user_name_to" ><br />
<br />
The writeups in question:<br />
<textarea name="namelist" rows="20" cols="50">'
        . $foo[1] . $query->param( 'namelist' ) .
        '</textarea><br />
<input type="submit" value="Do It" />
</form>
';
    }

    $str .='
<br /><br />
<hr />
<p><i>Consider this in beta. </i> </p>
<br /><br />
';

    $str .= '<br><br><hr><br>' . htmlcode('openform') . 'Gen nodelist: <input type="text" name="nodes_for">' . htmlcode('closeform');

    my $nodesfor = $query->param("nodes_for");
    if($nodesfor) {
        my $usr = getNode($nodesfor, "user");
        if($usr) {
            my $csr = $DB->sqlSelectMany("node_id", "node", "type_nodetype=".getId(getType("writeup"))." and author_user=$usr->{node_id}");

            $str .= "<ul>";

            while(my $row = $csr->fetchrow_hashref)
            {
                $str.= "<li>".linkNode(getNodeById(getNodeById($row->{node_id})->{parent_e2node}));
            }

            $str.="</ul>";
        } else {
            $str .= "Ack! No user!";
        }
    }

    return $str;
}

sub security_monitor {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $sec = {
        "Kill reasons" => getId(getNode("massacre","opcode")),
        "Password resets" => getId(getNode("Reset password", "superdoc")),
        "Suspensions" => getId(getNode("Suspension Info", "superdoc")),
        "Resurrections" => getId(getNode("Dr. Nate\'s Secret Lab", "restricted_superdoc")),
        "Blessings" => getId(getNode("bless","opcode")),
        "SuperBless" => getId(getNode("superbless","superdoc")),
        "Vote bestowings" => getId(getNode("bestow","opcode")),
        "C! bestowings" => getId(getNode("bestow cools","restricted_superdoc")),
        "Stars Awarded" => getId(getNode('The Gift of Star', 'node_forward')),
        "Votes Given Away" => getId(getNode('The Gift of Votes', 'node_forward')),
        "Chings Given Away" => getId(getNode('The Gift of Ching', 'node_forward')),
        "Chings Bought" => getId(getNode('Buy Chings', 'node_forward')),
        "Votes Bought" => getId(getNode('Buy Votes', 'node_forward')),
        "Account Lockings" => getId(getNode("lockaccount","opcode")),
        "Account Unlockings" => getId(getNode("unlockaccount","opcode")),
        "Node Notes" => getId(getNode("Recent Node Notes","superdoc")),
        "Writeup reparentings" => getId(getNode("Magical Writeup Reparenter","superdoc")),
        "Topic changes" => getId(getNode("E2 Gift Shop","superdoc")),
        "IP Blacklist" => getId(getNode("IP Blacklist", "restricted_superdoc")),
        "User Signup" => getId(getNode("Sign up", "superdoc")),
        "Writeup insurance" => getId(getNode("insure", "opcode")),
        "XP SuperBless" => getId(getNode("XP Superbless","restricted_superdoc")),
        "XP Recalculations" => getId(getNode("Recalculate XP","superdoc")),
        "Sanctifications" => getId(getNode("Sanctify user","superdoc")),
        "User Deletions" => getId(getNode("The Old Hooked Pole","restricted_superdoc")),
        "Catbox flushes" => getId(getNode("flushcbox","opcode")),
        "Parameter changes" => getId(getNode("parameter","opcode")),
    };


    ### Generate the selection table
    my $str="<p align=\"center\"><table width=\"90%\"><tr>";

    my $index = 0;
    foreach(sort {lc($a) cmp lc($b)} keys %$sec){
        next unless $sec->{$_};
        $str.="<td align=\"center\"><div style=\"margin:0.5em; padding:0.5em; border:1px solid #555\">"
            .linkNode($NODE, $_, {sectype=>$sec->{$_}})."<br />\n"
            ."<small>("
            .$DB->sqlSelect("count(*)", "seclog", "seclog_node=$sec->{$_}")." entries)"
            ."</small>"
            ."</div></td>";
        if($index % 5 == 4){
            $str .= "</tr><tr>";
        }
        $index++;
    }

    $str.="</tr></table></p>\n";



    ### Generate the log table if one is requested
    my $sectype = $query->param("sectype");
    $sectype =~ s/[^0-9]//g;
    if($sectype){

        $str.="<style type=\"text/css\">\n";
        $str.="    table.logtable th, table.logtable td{ ";
        $str.="       padding: 0.5em 1em; border-bottom:1px solid #AAA; marin:0px";
        $str.="    }\n";
        $str.="    table.logtable th{ text-align:left; }";
        $str.="</style>\n";
        $str.="<p align=\"center\"><table class=\"logtable\" cellspacing=\"0\" cellpadding=\"0\"><tr>\n";
        $str.="   <th><strong>$_</strong></th>\n" foreach("Node","User","Time","Details");
        $str.="</tr>\n";

        my $startat= $query->param("startat");
        $startat =~ s/[^0-9]//g;
        $startat ||= 0;

        my $csr = $DB->sqlSelectMany('*', 'seclog', "seclog_node=$sectype order by seclog_time DESC limit $startat,50");

        while(my $row = $csr->fetchrow_hashref){
            $str.="<tr>\n";
            $str.="   <td>".linkNode(getNodeById($row->{seclog_node}))."</td>\n";
            $str.="   <td>".linkNode(getNodeById($row->{seclog_user}))."</td>\n";
            $str.="   <td><small>$row->{seclog_time}</small></td>\n";
            $str.="   <td>".$row->{seclog_details}."</td>\n";
            $str.="</tr>\n";
        }

        $str.="</table></p><br><p align=\"center\"><hr width=\"300\"></p>";



        ### Generate the pager
        my $cnt = $DB->sqlSelect("count(*)", "seclog", "seclog_node=$sectype");
        my $firststr = "$startat-".($startat+50);
        $str.="<p align=\"center\"><table width=\"70%\"><tr>";
        $str.="<td width=\"50%\" align=\"center\">";
        if(($startat-50) >= 0){
            $str.=linkNode($NODE,$firststr,{"startat" => ($startat-50), "sectype" => $sectype});
        }else{
            $str.=$firststr;
        }
        $str.="</td>";
        $str.="<td width=\"50%\" align=\"center\">";
        my $secondstr = ($startat+50)."-".(($startat + 100 < $cnt)?($startat+100):($cnt));

        if(($startat+50) <= ($cnt)){
            $str.=linkNode($NODE,$secondstr,{"startat" => ($startat+50), "sectype" => $sectype});
        }else{
            $str.="(end of list)";
        }
        $str .= '</tr></table>';
    }

    return $str;
}

sub server_telemetry {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '<h1>Apache Processes</h1><pre>';
    $str .= `ps aux | grep apache2 | grep -v grep`;
    $str .= "\n";
    $str .= "Apache threads running: ".`ps aux | grep apache2 | grep -v grep | wc -l`;
    $str .= '</pre><h1>VM Stat</h1><pre>';
    $str .= `vmstat`;
    $str .= '</pre><h1>Uptime</h1><pre>';
    $str .= `uptime`;
    $str .= '</pre><h1>Cloud Health Check</h1><tt>';
    $str .= `/var/everything/tools/container-health-check.pl --debug-cloudwatch 2>&1`;
    $str .= '</tt><h1>Apache config</h1><pre>';
    $str .= `cat /etc/apache2/everything.conf`;
    $str .= '</pre>';

    return $str;
}

sub the_oracle {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    ##########
    # This section creates the user search field - always displayed
    my $str = "";
    unless($query->param("userEdit"))
    {

        $str .= qq(Welcome to the User Oracle. Please enter a user name<br>);
        $str .= htmlcode('openform');
        $str .= $query->textfield('the_oracle_subject');
        $str .= htmlcode('closeform');

        ##########
        # This section lists the variables if a username is given and we\'re not editing a variable

        # The below is for allowing gods to check what CEs are allowed to see

        my $orasubj = $query->param('the_oracle_subject');
        if ($orasubj)
        {
            my $oraref = getNode($orasubj, 'user');
            my $hash = getVars($oraref);

            # message to content editors explaining what this is
            $str .= '<p>As a content editor, you can view an abbreviated list of user settings.
    <br>Any given variable will not be displayed unless the user has turned it on at least once. 1=on, 0 or blank=off</p>
    <dl>
    <dt>browser</dt><dd>the web browser and operating system the noder is using</dd>
    <dt>easter_eggs</dt><dd>how many easter eggs the noder has</dd>
    <dt>nodelets</dt><dd>list of nodelets the noder has turned on, node_id and name</dd>
    <dt>settings_useTinyMCE</dt><dd>whether or not the noder has tinyMCE turned on.</dd>
    <dt>userstyle</dt><dd>the Zen stylesheet the noder has active</dd>
    <dt>wuhead</dt><dd>the code for displaying the writeupheader</dd>
    </dl>' if ($APP->isEditor($USER) and not $APP->isAdmin($USER));

            my $oddeven = 0; # tracks odd rows for .oddrow class color
            my $oddrowclass = ""; # blank if even row, contains .oddrow class color if odd row

            $str .= qq(<table border=0 cellpadding=2 cellspacing=1>);
            foreach(sort(keys(%{$hash}))) {
                next if ($_) eq 'noteletRaw'; # notelet can run code that breaks the page
                next if ($_) eq 'noteletScreened';
                # Allow content editors to view an abbreviated list
                unless ($_ eq 'settings_useTinyMCE'
                    || $_ eq "easter_eggs"
                    || $_ eq "nodelets"
                    || $_ eq "userstyle"
                    || $_ eq "wuhead"
                    || $_ eq "browser")
                {
                    next if $APP->isEditor($USER) && !$APP->isAdmin($USER);
                }
            
                # replace undefined values with a blank
                ${$hash}{$_} = "&nbsp;" if(!${$hash}{$_});
                if ($oddeven%2 == 0)
                {
                    $oddrowclass = ' class="oddrow"';
                } else { 
                    $oddrowclass = ' class="evenrow"';
                }

                # first special case: style defacer code to be listed in PRE tags
                # personal nodelet should be linked
                # CSV lists should have extra space between variables to prevent page stretching
                if ($_ eq 'customstyle') {
                    $str .= qq(\n\n<tr$oddrowclass><td>$_</td><td>=</td><td><pre><small>${$hash}{$_}</small></pre>);
                } elsif ($_ eq 'personal_nodelet') {
                    $str .= qq(\n\n<tr$oddrowclass><td>$_</td><td>=</td><td>);
                    unless ($hash->{$_} eq '&nbsp;') {
                        my @items_list = split(/<br>/,$hash->{$_});
                        foreach my $i (@items_list) {
                            $str .= qq(\n[$i]<br>) if $i;
                        }
                    }
                } else {
                    my $cleancsv = ${$hash}{$_};
                    $cleancsv =~ s/,/, /g;
                    $str .= qq(\n\n<tr$oddrowclass><td>$_</td><td>=</td><td>$cleancsv);
                }

                # don\'t let CEs perform an IP hunt
                $str .= " ".linkNode($NODE,"edit",{userEdit => $orasubj, varEdit => $_})." " unless ($APP->isEditor($USER) and not $APP->isAdmin($USER));
                if ($_ eq 'ipaddy') {
                    $str .= linkNode(getNode('IP Hunter', 'restricted_superdoc'), "<br><tt>(check other users with this IP)</tt> ", {hunt_ip => $hash->{$_}})
                }

                # second special case: fetch node titles for these node_ids to be human-readable
                if ($_ eq 'userstyle'
                    || $_ eq 'lastnoded'
                    || $_ eq 'current_nodelet'
                    || $_ eq 'group') {
                    # undefined hash values are replaced with \'&nbsp;\'
                    unless ($hash->{$_} eq '&nbsp;') {
                        # check to make sure node exists before grabbing its title
                        if (getNodeById($hash->{$_})) {
                            $str .= " <br><tt>(" . linkNode($hash->{$_},getNodeById($hash->{$_})->{title}) . ")</tt> ";
                        } else {
                            $str .= " <br><tt>(" . linkNode($hash->{$_},'<b style="color:red;">ERROR:</b> Node not found!)</tt>');
                        }
                    }
                }

                # third special case: fetch node titles for these CSV lists of node_ids to be human-readable
                if ($_ eq 'nodelets'
                    || $_ eq 'bookbucket'
                    || $_ eq 'favorite_noders'
                    || $_ eq 'emailSubscribedusers'
                    || $_ eq 'nodetrail'
                    || $_ eq 'nodebucket'
                    || $_ eq 'can_weblog') {
                    unless ($hash->{$_} eq '&nbsp;') {
                        my @items_list = split(/,/,$hash->{$_});
                        foreach my $i (@items_list) {
                            # check to make sure node exists before grabbing its title
                            if (getNodeById($i)) {
                                $str .= "\n<br>" . linkNode($i,getNodeById($i)->{title}) if $i;
                            } else {
                                $str .= "\n<br>(" . linkNode($i,'<b style="color:red;">ERROR:</b> Node not found!)') if $i;
                            }
                        }
                    }
                }

                # fourth special case: get titles of notifications_nodelet items
                # assumption: \'settings\' will have more than just the notifications in it some day
                # therefore, look for "notifications": and return the list that comes after it.
                # this technique can be applied to other hypothetical things saved in \'settings\'
                if ($_ eq 'settings') {
                    unless ($hash->{$_} eq '&nbsp;') {
                        my @items_list1 = split(/{|}/,$hash->{$_});
                        for (my $j=0; $j <= $#items_list1; $j++) {
                            if ($items_list1[$j] eq '"notifications":') {
                                my @items_list2 = split(/,/,$items_list1[$j+1]);
                                foreach my $i (@items_list2) {
                                    $i =~ /\"(\d*)\\":\d/;
                                    $str .= "\n<br>" . getNodeById($1)->{title} if $1;
                                }
                            }
                        }
                    }
                }

                $oddeven++;
                $str .= "</td></tr>";
            }
            $str .= qq(</table>);
        }
    }
    
    # This section is for pulling up the variable edits
    if($APP->isAdmin($USER))
    {
        if (defined($query->param("new_value")))
        {
            my $u = getNode($query->param("new_user"),"user");
            my $v = getVars($u);

            $v->{$query->param("new_var")} = $query->param("new_value");
            setVars($u, $v);

            if ($u->{user_id} == $USER->{user_id})
            {
                $VARS = $v;
            }

            getVars($u);
            $str .= $v->{$query->param("new_var")};

        }
    }

    my $varEdit = $query->param("varEdit");
    return $str unless $varEdit;

    my $orasubj2 = $query->param('userEdit');
    return $str unless($orasubj2);

    my $oraref2 = getNode($orasubj2, 'user');
    my $v = getVars($oraref2);

    $str .= htmlcode('openform');
    $str .= "Editing ".$orasubj2." - var <b>$varEdit</b><br />";
    $str .= "<b>Old Value:</b> ".$v->{$varEdit}."<br />";
    $str .= "<b>New Value:</b> ".$query->textfield('new_value',"",50);
    $str .= $query->hidden("new_user",$orasubj2);
    $str .= $query->hidden("new_var",$varEdit);
    $str .= htmlcode('closeform');

    return $str;
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

    if ($mode eq 'annotate') {

        my $action = $query->param("action");
        return unless $action;

        if ($action eq 'delete') {
            my $aNode = $query->param("annotation_id");
            my $aLoc = $query->param("location");
            return unless ($aNode && $aLoc);
            $DB->sqlDelete("annotation",{ann_node => $aNode, ann_location => $aLoc});
            return "annotation deleted";
        }

        if ($action eq 'retrieve') {
            my $aNode = $query->param("annotation_id");
            return unless $aNode;
            my $commentList = $DB->sqlSelectMany("ann_text, ann_location","annotation","ann_node = $aNode");
            my $cSet = '';
            while (my $c = $commentList->fetchrow_hashref) {
                $cSet.=$$c{ann_location}.",".$$c{ann_text}.",";
            }
            return $cSet;

        }

        if ($action eq 'add') {
            my $aNode = $query->param("annotation_id");
            my $aText = $query->param("comment");
            my $aLoc = $query->param("location");
            return unless ($aNode && $aText && $aLoc);
            $DB->sqlInsert("annotation",{ann_node => $aNode, ann_text => $aText, ann_location => $aLoc});
            return "annotation added";
        }
    }

    if ($mode eq 'update') {
        return '"update" mode retired for security reasons:<br>
            see e2.ajax.update code for current implementation';
    }

    if ($mode eq 'getlastmessage') {
        return $DB->sqlSelect('max(message_id)', 'message use index(foruser_tstamp) ', "for_user=0 and room=0", "");
    }


    if ($mode eq 'markNotificationSeen') {
        htmlcode('ajaxNotificationSeen',$query->param("notified_id"));
    }

    if ($mode eq 'checkNotifications') {
        return to_json(htmlcode('notificationsJSON'));
    }


    if ($mode eq 'checkCools') {
        return to_json(htmlcode('coolsJSON'));
    }

    if ($mode eq 'checkMessages') {
        return to_json(htmlcode('showchatterJSON'));
    }

    if ($mode eq 'checkFeedItems') {
        return to_json(htmlcode('userFeedJSON'));
    }

    if ($mode eq 'deleteFeedItem') {
        return unless $query->param('feeditem_nodeid');
        nukeNode(getNodeById($query->param('feeditem_nodeid')), $USER);
    }



    $NODE = getNodeById(124);

    return '';
}

sub chatterbox_xml_ticker {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $room = $$USER{in_room};
    $room ||= 0;
    my $RNODE = getNodeById($room);
    my $str = '';
    my $XG = XML::Generator->new();

    my $oldUA = $query->user_agent();
    if (index($oldUA,'JChatter/0.1.12.1beta')!=-1) {
        $oldUA = 1;
    } else {
        $oldUA = 0;
    }

    my $csr = $DB->sqlSelectMany('*', 'message', "for_user=0 and room=$room and tstamp > date_sub(now(), interval 500 second)", 'order by tstamp');

    my @msgs = ();
    while (my $MSG = $csr->fetchrow_hashref) {
        push @msgs, $MSG;
    }

    my $V = getVars(getNode('room topics','setting'));
    my $topic = '';
    if (exists $$V{$room}) {
        $topic = $$V{$room};
        $topic = $query->escape($topic);
    }

    $str.=$XG->INFO({site => $Everything::CONF->site_url, sitename => $Everything::CONF->site_name, servertime=>scalar(localtime(time)), room => $$RNODE{title}, topic => $topic}, "Rendered by the Chatterbox XML Ticker, which has been deprecated since 2002. Use the universal message xml ticker instead.");

    my $m = '';
    my $mTime = '';
    foreach my $MSG (@msgs) {
        my $FUSER = getNodeById($$MSG{author_user});
        $m = $$MSG{msgtext};

        $m =~ s/\[([^\]]*?)$/&#91;$1/;

        $m = Everything::XML::makeXmlSafe($m);

        $mTime = $$MSG{tstamp};
        if ($oldUA) {
            if ($mTime =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) {
                $mTime = $1.$2.$3.$4.$5.$6;
            } else {
                $mTime .= ' no';
            }
        }

        $str.= "\n".$XG->message({
            author => Everything::XML::makeXmlSafe($$FUSER{title}),
            time => $mTime,
        }, "\n".$m);
    }

    return "\n".$XG->CHATTER($str."\n");
}

sub chatterlight {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = '';
    $str = '	<link rel="stylesheet" id="zensheet" type="text/css" href="'
                 . htmlcode('linkStylesheet', $$VARS{userstyle}||$Everything::CONF->default_style,'serve')
                 . '" media="screen,tv,projection">' ;
    $str .= "   \t<style type='text/css'>\n\n\t" . $APP->htmlScreen($$VARS{customstyle}) . "\n\n\t</style>"
        if ($$VARS{customstyle});

    my $html = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
"http://www.w3.org/TR/html4/loose.dtd">
<html>
	<head>
	<title>'.$$NODE{title}.'</title>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
	<style type="text/css">#message { width: 97%; }</style>
	<link rel=\'stylesheet\' id=\'basesheet\' type=\'text/css\' href=\'/node/stylesheet/basesheet?displaytype=view\'>
'.$str.'
	</head>
<body id="chatterlight">
<div id="e2-react-root"></div>
	<div id="chatterlight_mainbody">

		<div id="links">
			<p>';

    $html .= linkNodeTitle("E2 Bouncer")." | " if $APP->isAdmin($USER);

    $html .= '
				<a href="/node/superdoc/Drafts" title="Your drafts">Drafts</a> |
				'.linkNode($USER,0,{lastnode_id=>0}).' |
				'.htmlcode('bookmarkit').' |
				<a href="/" title="E2\'s Front Page">The front door</a> |
                                     <a href="/?node_id='.$$NODE{node_id}.'" title="Refresh Private Messages">refresh private msgs</a> |
				<b>server time:</b> '.localtime().'
			</p>
		</div> <!-- end links -->

			<div id=\'chatterbox_nodelet\'>

				'.insertNodelet( getNode( 'Chatterbox', 'nodelet' ) ).'

				<div id="chatterlight_rooms">
 					<p><span title="What chatroom you are in">Now talking in: '.(linkNode($$USER{in_room}) || "outside").' </span> '.htmlcode('changeroom').'
					<p><a href="javascript:replyToCB(\'';

    my $name = $$USER{title};
    $name =~ s/'/\\'/g;
    $name =~ s/ /_/g;

    $html .= $name.'\')" title="send a private message to yourself">Talk to yourself</a></p>
				</div> <!-- close chatterlight_rooms -->

			</div> <!-- close chatterbox_nodelet -->

		<div id="chatterlight_search">
			'.htmlcode('zensearchform').'
		</div>

			<div id="chatterlight_credit">
				<p><small>'.linkNodeTitle('chatterlight').' Original credit goes to wharfinger.</small></p>
			</div> <!-- close chatterlight_credit -->

		<div id="chatterlight_hints">
			<p>To make chatterlight look nice, try adding the following to [Style Defacer] or your stylesheet:
			<br />#chatterlight_mainbody { float: left; width: 750px; margin-left: 10px; }
			<br />#chatterlight_NW       { float: left; width: 190px; }
			<br />#chatterlight_hints    { display: none; }
		</p></div> <!-- end chatterlight_hints -->

	</div> <!-- close chatterlight_mainbody -->
';

    my $nodeletString = $$VARS{nodelets};
    my %nodelets = ();
    %nodelets = map { $_ => 1 } split(',', $nodeletString) if $nodeletString;
    my $notificationsNodelet = getNode('Notifications', 'nodelet');
    if ($notificationsNodelet && $nodelets{$$notificationsNodelet{node_id}}) {
        my $str2 = insertNodelet($notificationsNodelet);
        $str2 = <<ENDHTML;
			<div id=\"chatterlight_Notifications\">
			$str2
			</div>
ENDHTML
        $html .= $str2;
    }

    $html .= '
	<div id="chatterlight_NW">
		'.insertNodelet( getNode( 'New Writeups', 'nodelet' )).'
	</div> <!-- close chatterlight_NW -->
'.htmlcode('static javascript').'
</body>
</html>';

    return $html;
}

sub chatterlight_classic {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $styleId = $$VARS{userstyle} || $Everything::CONF->default_style;
    my $str = "";
    $str = "<link rel='stylesheet' id='zensheet' type='text/css' href='/?node_id=$styleId&amp;displaytype=serve'>";

    my $customstyle = '';
    if (exists($$VARS{customstyle}) && defined($$VARS{customstyle})) {
        $customstyle = "   \t<style type='text/css'>\n\n\t" . $APP->htmlScreen($$VARS{customstyle}) . "\n\n\t</style>";
    }

    my $name = $$USER{title};
    $name =~ s/'/\\'/g;
    $name =~ s/ /_/g;

    my $html = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml/transitional.dtd">
<html>
	<head>
	<title>'.$$NODE{title}.'</title>
'.$str.'
'.$customstyle.'
	'.htmlcode('static javascript').'
	</head>
	<body>
	<div id="links">
		<p>
			<a href="/?node_id='.$$NODE{node_id}.'&amp;op=bookmark">bookmark</a> |
			<a href="/">The front door</a> |
			<b>server time:</b>'.localtime().'
		</p>
	</div>
	<div style=\'width: 100%;\'>
		<div id=\'chatterbox_nodelet\' style=\'width: 73%; float: left; margin-right: 0px\'>
			'.insertNodelet( getNode( 'Chatterbox', 'nodelet' ) ).'

			<p><a href="javascript:replyToCB(\''.$name.'\')">Talk to yourself</a></p>

			<p>Now talking in: '.(linkNode($$USER{in_room}) || "outside").'<br />('.linkNode(getNode("Available Rooms", "superdoc"), "change room").')</p>

		</div>

		<div style=\'width: 25%; float: left\'>
			'.insertNodelet( getNode( 'New Writeups', 'nodelet' )).'

		</div>
	</div>
	<div style="clear: both">

		'.htmlcode('zensearchform','noendform').'
		<br /><br />
		<p style=\'text-align: right\'>'.linkNodeTitle('chatterlight').' Original credit goes to wharfinger.</p>
	</div>
<script>
new PeriodicalExecuter(function() { if ($F(\'message\') == \'\') {updateTalk();}},10);
new PeriodicalExecuter(function() { if ($(\'message\').size != "70") {$(\'message\').size="70"; $(\'message\').focus();}},0.2);
new PeriodicalExecuter(function() {E2AJAX.updateNodelet(\'263\',\'New Writeups\');},180);
$(\'message\').size="70";
$(\'message\').focus();
</script>
</body>
</html>';

    return $html;
}

sub cool_nodes_xml_ticker {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $cache = $DB->stashData("coolnodes");

    my $xml = '';
    my $XG = XML::Generator->new();

    my $count = 15;
    my %used = ();

    foreach my $CW (@$cache) {
        next if exists $used{$$CW{coolwriteups_id}};
        $used{$$CW{coolwriteups_id}} = 1;
        $xml .="\t".$XG->cooled({node_id => $$CW{coolwriteups_id},
            parent_e2node => $$CW{parentNode},
            author_user => $$CW{wu_author},
            cooledby_user => $$CW{cooluser}},
            $$CW{parentTitle})."\n";
        last unless (--$count);
    }

    $xml = $XG->COOLEDNODES(
        $XG->INFO({site => $Everything::CONF->site_url, sitename => $Everything::CONF->site_name,  servertime => scalar(localtime(time))}, 'Rendered by the Cool Nodes XML Ticker')
        . "\n".$xml . "\n");

    return $xml;
}

sub eqs_nohtml {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my @wit = (

"No [Viet Cong] ever called me a [nigger].
<br>
<br>--[Muhammad Ali], on why he would not go to [Vietnam]",

"[Love] wakes men, once a [lifetime] each;<br>
They lift their heavy [eyelid|lids], and look;<br>
And, lo, what [textbook|one sweet page] can teach,<br>
They read with [joy], then shut the [book].<br>
And some give thanks, and some [blaspheme],<br>
And most [forget]; but either way,<br>
That and the child's unheeded [dream]<br>
Is all the [light] of all their day.
<br>
<br>--[Uncle Gabby], <i>[Tony Millionaire's The Adventures of Sock Monkey|The Adventures of Tony Millionaire's Sock Monkey]</i>",

"There is no such thing as a 'self-made' man. [interpersonality in Tamil Nadu|We are made up of thousands of others].
<br>Everyone who has ever done a kind deed for us, or spoken one word of [encouragement] to us, has entered into
<br>the make-up of our character and of our thoughts.
<br>
<br>--[George Matthew Adams]",

"<i>Men never start from humble beginnings,</i> I thought. <i>They seem to come
out of the womb seeking a woman's approval.</i>
<br>
<br>--[Templeton], [04/03/00: tether me to the real]",

"Have some [tact] for breakfast!  It's helpful in avoiding the [eat crow|crow] you've got coming for dinner.<br><br>--[dem bones]",

"You can get more with a kind word and a gun than you can with a kind word alone.
<br>
<br>--[Al Capone]",

"If you're going to put your time into this, do [something worth doing].
<br>
<br>- [ideath] -",

"As an adolescent I aspired to lasting [fame], I craved factual certainty, and I thirsted for [a meaningful vision of human life] -- so I became a [scientist]. This is like becoming an archbishop so you can meet girls.
<br>
<br>--[Matt Cartmill]",

"I know not with what [weapons] [World War III] will be fought, but [World War IV] will be fought with [sticks and stones].
<br>
<br>--[Albert Einstein]",

"Flow with whatever is happening and [let your mind be free].
<br>Stay centered by accepting whatever you are doing. This is the ultimate.
<br>
<br>--[Chuang Tzu]",

"It's the Tarantino script of confessions - [chinoodle] in
[Chatterbox] in response to [everyone]'s [Genital Home Wart Removal] node
<br>
<br>",

"[Theatre] is [Life]. [Cinema] is [Art]. [TV] is [Furniture].",

"I am not the first to point out that [capitalism], having defeated [communism], now seems about to do the same to [democracy]. The [market] is doing splendidly, yet we are not.
<br>
<br>--[Ian Frazier]",

"Eat your pets",

"I don't crack the door too far for anyone who's [pushing too hard on me].
<br>
<br>[Liz Phair]",
"Just remember, [math without numbers] scares people, and [people without numbers] scares math.<br><br>--[ameoba], [Amy's drug addled rantings: 11-10-97]",
"This is my '[depressed stance]'. When you're [depressed], it makes a lot of difference how you stand. The [worst] thing you can do is straighten up and hold your head high because then you'll start to [feel better]. If you're going to get any [joy] out of being depressed, you've got to stand like this.<br><br>--[Charlie Brown]",
"No matter how [cynical] I get, I can't keep up.<br><br>--[Lily Tomlin]",
"The [computer] can't tell you the [emotional] story. It can give you the exact [mathematical design], but what's missing is the [eyebrows].<br><br>--[Frank Zappa]",
"Hoping to goodness is not theologically sound.<br><br>--[Charles Schulz], [Peanuts]",
"The majority of the [stupid] is invincible and [guaranteed for all time]. The terror of their [tyranny], however, is alleviated by their lack of [consistency].<br><br>--[Albert Einstein]",
"The [wide world] is all about you; you can [fence] yourselves in, but you cannot for ever fence it out.<br><br>--[Gildor], [The Fellowship Of The Ring], by [J.R.R. Tolkien]",
"So much to do, so much to do...Maybe later I'll go [kick God's ass]...  Oh, wait. [I forgot]. <b>I CAN'T.</b><br><br>--[Satan]",
"He who makes a [beast] of himself gets rid of the [pain] of being a [man].<br><br>--[Hunter S. Thompson]",
"[Survivor2: Journal of the Bones (Endgame)|They say she done them, all of them, in.  <br>They say she done it with an axe.]",
"As far as I'm concerned, being any [gender] is a [drag].
<br>
<br>[Patti Smith]",

"A title like [recreational surgery] is false advertising!  I was expecting something far more depraved!<br><br>--[Uberfetus], in the [chatterbox]",

"Those with the greatest [faith] have the greatest [crises].
<br>
<br>Zed Saeed (a guy [ideath] met on the train, going into New York)",

"..did you know that [friends come in boxes]..
<br>
<br>--[Gary Numan]",

"We try hard to make it work the way it does in movies.
<br>
<br>--The [Gnutella] Support Team",

"Regret for the things we did can be tempered by time; it is [regret] for the things we did not do that is inconsolable.
<BR>
<br>--[Sydney J. Harris]",

"There are very few things I take seriously in life, and my [sense of humor] is one of them.
<br>
<br>--[CaptainSpam]",

"When you have [eliminate]d [everything] that is [impossible], what remains, however [improbable], is the [truth].
<br>
<br>--[Sherlock Holmes|S. Holmes]",


"Highest are those who are born wise. Next are those who become wise by learning. After them come those who have to work hard in order to acquire learning. Finally, to the lowest class of the common people belong those who work hard without ever managing to learn.
<br>
<br>--[Confucius]",


"The oldest and strongest emotion of mankind is [fear] and the oldest and strongest kind of fear is [fear of the unknown].
<br>
<br>--[H. P. Lovecraft]",

"I have been fortunate to be born with a [restless and efficient brain], with a capacity of [clear thought] and an ability to put that thought into words ... I am the lucky beneficiary of a lucky break in the [genetic sweepstakes].
<br>
<br>--[Isaac Asimov]",

"It was funny how people were people everywhere you went, even if the people
concerned weren't the people the people who made up the phrase <i>people are
people everywhere</i> had traditionally thought of as people.
<br>
<br>--[Terry Pratchett], <i>[The Fifth Elephant]</i>",

"Sometimes you just need the clear [epiphany] that an [ass kicking] provides.
<br>
<br>--[Nathan Regener]",

"You Live and Learn or you don't Live long.
<br>
<br>[Lazarus Long]",

"[King Kong died for your sins]
<br>
<br>[Principia Discordia]",

"This book is a [mirror]. When a [monkey] looks in, no apostle looks out.
<br>
<br>Lichtenberg, [Principia Discordia]",

"[Surrealism] aims at the total transformation of the mind and all that resembles it.
<br>
<br>Breton",

"[Bullshit] makes the flowers grow, and that is [beautiful].
<br>
<br>[Principia Discordia]",

"The preferred method of entering a building is to use a tank [main gun round], direct fire [artillery round], or [TOW], [Dragon], or [Hellfire missile] to clear the first room.
<br>
<br>--THE [RANGER HANDBOOK], [U.S. Army], 1992",

"If you want to get into a [fight], there is only one good choice of targets. [Pacifist]s. They don't fight back.
<br>
<br>--[Buster Crash], The [Flametrick Subs]",

"There are no differences but differences of [degree]
<br>between different [degrees of difference]
<br>and no [difference].
<br>
<br>--[William James], under [nitrous oxide], 1882",

"Nobody steps on a church in my town.<br><br>--[Ghostbusters]",

"[Things fall apart...it's scientific.]",

"I don't want to run a company, I'm not good at managing people. You have a problem with the guy in the next
  cubicle? I don't care. Shoot him or something.<br><br>[Marc Andreessen], May 1997",

"You know how you feel right now is how [wimps|pussies] feel all the time.<br><br>--[dem bones], after a serious bout of [dune running]",

"Some see it as a glass [pessimist|half empty], some see it as a glass [optimist|half full].
<br>I prefer to see it as a glass that's twice as big as it needs to be.
<br><br>--[George Carlin]",

"Whoever is fundamentally a [teacher] takes things -- including himself  --
seriously only as they affect his [student]s.
<br><br>--[Friedrich Nietzsche], <i>[Beyond Good and Evil]</i>",

"[Life] is a series of [small awakening]s.<br><br>[Electric Mollusk], <i>[Someone please kill me]</i>",

"I don't know the meaning of the word [surrender]!
<br>I mean, I know it, I'm not dumb... just not in this [context].
<br><br>--[The Tick]",

"[Withdrawal] in [disgust] is not the same as [apathy].<br><br>--[Richard Linklater]",

"To eat were best done at [home].<br><br>--[Macbeth|Lady Macbeth]",

"[Tragedy] is if I cut my finger; [comedy] is if you walk into an open sewer and die.<br><br>--[Mel Brooks]",

"[Work] is [Worship].",

"[Memory] is like a train; you can see it getting [smaller] as it pulls away...<br><br>--[Tom Waits]",

"[N-Wing] hasn't tasted [urine] yet.<br><br>--[N-Wing] in Chatterbox",

"[Obscenity] is whatever gives a [moralist] an [erection].",

"Amicus Plato amicus Aristoteles magis amica veritas <i>Plato is my friend, Aristotle is my friend, but my best friend is truth</i>. --Sir Isaac Newton",

"<i>Knifegirl nods gravely</i><br><br>--[Knifegirl] (obviously) as [zot-fot-piq] went on and on in the [Chatterbox]",

"The [law], in its equality, forbids the [eat the rich|rich] as well as the [kill the poor|poor] to [sleep] under bridges, to [beg] in the streets, and to [steal] bread.<br><br>--[Anatole France]",

"To man the [World] is [twofold], in accordance with his [twofold attitude].--Martin Buber, [I & Thou]",

"Life is a gift of [nature], but beautiful living is the gift of [wisdom].
<br><br>--[Greek] [adage]",

"[Friendship] is one [soul] in two bodies.
<br><br>--[Aristotle]",

"I thought of how odd it is for billions of people to be [alive], yet not one of them is really quite sure what makes people people.
 The only activities I could think of that have no other animal equivalent were [smoking], [body-building], and [writing]. That's not
 much, considering how [special] we seem to think we are.
 <br><br>--[Douglas Coupland], [Life After God]",

"Time ticks by; we grow older. Before we know it, too much time has passed and we've missed the chance to have had other
 people [hurt] us. To a younger me this sounded like [luck]; to an older me this sounds like a [quiet] [tragedy].
<br><br>--[Douglas Coupland], [Life After God]",

"Approach [life] and [cooking] with reckless abandon.
<br><br>--the Dalai Lama",

"Take into account that great [love] and great [achievements] involve great [risk].
<br><br>--The [Dalai Lama]",


"I shall come to you [in the night] and we shall see who is stronger--a [little girl] who won't eat her dinner or a [great big man] with
[cocaine] in his veins.<br><br>--[Sigmund Freud] (in a letter to his fiancee)",

"What a marketing gimmick:  [ass-flavoured yogurt]!  It's low in [fat] and it tastes like [ass] so you eat less! <br><br>--[hoopy frood]",

"Have you any idea what the numbers for the [Theory of Everything] look like?<br><br>--[God] to [Jim Morrison], Doc Holliday], et al, in the book [Jim Morrison's Adventures in the Afterlife].",

"Groups and individuals contain [microfascisms] just waiting to [crystallize].<br><br>--[Deleuze & Guattari]",

"The basic difference between [classical music] and [jazz] is that in the former the music is always greater than its
performance--whereas the way jazz is [performed] is always more important than what is being played.<br><br>--[Andre Previn]",

"[God] created the [Integers]; all the rest is the work of [Man].<br><br>--[L. Kronecker]",

"We have a saying around here [senator]: Don't [piss] down my back and tell me it's [raining].<br><br>--Fletcher, [The Outlaw Josey Wales]",

"Sometimes people say, 'She's no great [talent]<br>
                                 I could [write] like she does'.<br> They are right. <br>
                                         They could; but I do.<br><br>--[Elizabeth Wurtzel]",

"You were [born]. And so you're [free]. So [Happy Birthday].<br><br>--[Laurie Anderson]",

"Either get busy [living] or get busy [dying].<br><br>[The Shawshank Redemption]",

"I cannot and will not cut my [conscience] to fit this year's [fashion|fashions].<br><br>--[Lillian Hellman], [HUAC], 1954",

"Why should I drink [Tequila] in Mexico, when I can get such good [kerosene] in the U.S.? <br><br>--[John Barrymore]",

"[Undead] are my specialty, really.<br><br>--[TheFez]",

"That's all it is: [information]. Even a dream or simulated experience is simultaneous [reality] and [fantasy]. Any way you look at it, all the information a person acquires in a lifetime is just [a drop in the bucket].<br><br>--Batou, [Ghost in the Shell]",

"Like flies to wanton boys, are we to the [gods].
They kill us for their [sport].<br><br>--[Gloucester], [King Lear]",

"Those who will not reason, are [bigots], those who cannot, are [fools], and those who dare not, are [slaves].<br><br>--[George Gordon Noel Byron]",

"The urge to [perform] is not an indication of [talent], and don't you ever forget it.
<br><br>--[Garrison Keillor]",

"There is hopeful [symbolism] in the fact that flags do not wave in a vacuum.<br><br>--[Arthur C. Clarke]
",

"Highly developed spirits often encounter resistance from [mediocre] minds.
<br><br>--[Albert Einstein]",

"[Nature] has given [women] so much power that the [law] has wisely given them very little
<br><br>[Samuel Johnson]",

"I think [polygamy] is absolutely [splendid].<br><br>--[Adam West]",

"To live is to war with trolls in [heart] and [soul]. To write is to sit in judgement on oneself.
<br><br>[Henrik Ibsen]",

"By the time you swear that you are his,<br>
shivering and sighing, <br>
and he promises his [passion] is,<br>
[infinite], undying,<br>
Lady, make a note of this:<br>
one of you is [lying].<br><br>--[Dorothy Parker]",

"A [computer] lets you make more mistakes faster than any invention in human history--with the possible exceptions of
  [handguns] and [tequila].<br><br>--[Mitch Ratliffe], [Technology Review]",

"May you get fucked by a [donkey]! May your wife get fucked by a donkey! May your child fuck your wife!<br><br>--[Egyptian] legal [curse], c. 950 [BC]",

"May you dig up your [father] by moonlight and make [soup] of his [bones].<br><br>--[Fiji Islands] [curse]",

"We [praise] the man who is [angry] on the right grounds, against the right persons, in the right manner, at the right moment, and for the right length of time.<br><br>--[Aristotle], [Nicomachean Ethics], IV",

"Every man with a belly full of the [classics] is an enemy of the human race.<br><br>--[Henry Miller]",

"In my work<br>
  I will take the blame for what is [wrong]<br>
  For that which is clearly mine.<br>
  But what is [right] I can not comprehend.<br><br>
  --[James Hubbell]",

"I prefer the [wicked] rather than the [foolish]. The wicked sometimes rest.<br><br>--[Alexandre Dumas]",

"There's a [truism] that the road to [Hell] is often paved with good intentions. The corollary is that [evil] is best known not by its motives but by its <i>methods</i>.<br><br>--[Eric S. Raymond]",

"Now, now my good man, this is no time for making [enemies]. <br><br>--[Voltaire], on his deathbed, in response to a priest asking that he renounce [Satan]",

"<i>That's a lot of [douche].</i><br><br>--[moJoe], [feminine hygiene products never cease to amaze]",

"I'm a member of an [monkey|ape-like] race at the [end|asshole-end] of the twentieth century...<br><br>--[James], [Low]",

"Shut your [Multifarious postings of Deborah909|multifarious] ass up, [dem bones|bones].<br>
<br>--[knifegirl], [Chatterbox]",

"[Abandon all hope ye who enter here]",

"God made [night] but man made [darkness].<br><br>--[Spike Milligan]",

"If I die in [war] you remember me. If I live in [peace] you don't.<br><br>--[Spike Milligan]",

"The trouble with us in [America] isn't that [the poetry of life] has turned to prose,
but that it has turned to [advertising] copy.<br><br>-- [Louis Kronenberger], [1954]",

"It is harder to fight against [pleasure] than against [anger].<br><br>-- [Aristotle]",

"A [critic] is a bundle of biases held loosely together by [a sense of taste].<br><br>--
[Whitney Balliett]",

"I'm out of your [back door] and into another<br>
Your [boyfriend] doesn't know about me and your [mother]
<br><br>--[The Beastie Boys], [3-Minute Rule]",

"We'll cut the [thick] and break the [thin]...<br><br>--[Peter Murphy], [Cuts You Up]",

"I live with [desertion]...and eight million people.<br><br>
--[The Cure], [Other Voices]",

"A [prayer] can't travel so far these days...<br><br>
--[David Bowie], [A Small Plot Of Land]",

"Give me back the [Berlin wall]<br>
Give me [Joseph Stalin|Stalin] and [St. Paul]<br>
Give me [Christ]<br>
Or give me [Hiroshima]...<br><br>--[Leonard Cohen], [The Future]",

"[Who By Fire?]<br><br>--[Leonard Cohen]",

"Your [money] talks but my [genius] walks...<br><br>--[They Might Be Giants], [You'll Miss Me]",

"[the alphabet is a playground (overview)|The alphabet is a playground]",

"Breathe in...then squeeze the trigger on the [exhale].
<br><br>--[TheFez]",

"Blessed are the [insane|cracked], for they shall let in the [light].",

"I'm allergic to [power]...<br><br>--[Nate]",

"[This aggression will not stand...man.]<br><br>--[The Big Lebowski]",

"[Liberty] without [socialism] is [privilege] and [injustice]; [socialism] without [liberty] is [slavery] and [brutality].<br><br>--[Mikhail Bakunin]",

"If [God] really existed, it would be necessary to [abolish] him.<br><br>--[Mikhail Bakunin]",

"[Skepticism] is the agent of [truth].<br><br>--[Joseph Conrad]",

"What is a [rebel]?  A [man] who says [no].<br><br>
--[Albert Camus]",

"If a man really wants to make a [million dollars], the best way would be to start his own [religion].<br><br>
--[L. Ron Hubbard]",

"If [God] does not [exist], [everything] is permitted.
<br><br>--[Fyodor Dostoyevsky]",

"The [distinction] between [past], [present], and [future] is only a stubbornly persistent [illusion].<br><br>--[Albert Einstein]",

"If the [law] is of such a [nature] that it requires you to be an agent of [injustice] to another, then I say, [breaking the law|break the law].<br><br>--[Henry David Thoreau]",

"You must realize that the [computer] has it in for you. The irrefutable [proof] of this is that the [computer] always does what you tell it to do.",

"Political [language]...is designed to make [lies] sound truthful and [murder] respectable, and to give an appearance of [solidity] to pure wind.<br><br>--[George Orwell]",

"The entire sum of [existence] is the [magic] of being needed by just one person.<br><br>--[Vii Putnam]",

"A ship in harbor is [safe], but that's not what ships are built for.<br><br>--[John Shedd]",

"An [Error] does not become [Truth] by reason of multiplied propagation, nor does Truth become Error just because nobody sees it.<br><br>--[Mohandas Gandhi]",

"When people are [free] to do as they please, they usually [imitate] each other.<br><br>--[Eric Hoffer]",

"[The following addresses had permanent fatal errors...]",

"Give a man a [fire] and he's [warm] for a day, but set fire to him and he's warm for the rest of his [life].<br><br>
--[Terry Pratchett]",

"Just because it's [not nice] doesn't mean it's not [miraculous].<br><br>--[Terry Pratchett]",

"He was said to have the [body] of a twenty-five year old, although no one knew where he kept it...<br><br>--[Terry Pratchett]",

"You can take a [horticulture] but you can't make her think
<br><br>--[Groucho Marx]",

"I'm Great [Me]<br><br>--[Rhys Lewis], Personal Statement on a job application",

"EDB is a dirty [slut].<br><br>--[ohe]",

"For what shall it [profit] a man, if he shall gain the whole world, and lose his own [soul]?<br><br>--[Matthew 16:26]",

"The [faith] that stands on [authority] is not faith.<br><br>--[Ralph Waldo Emerson]",

"So far as I can remember, there is not one word in [the Gospels] in praise of [intelligence].<br><br>--[Bertrand Russell]",

"We should take care not to make the [intellect] our god; it has, of course, powerful muscles, but no [personality].<br><br>--[Albert Einstein]",

"Only two things are [infinite], the [Universe] and human stupidity, and I'm not sure about the former.<br><br>--[Albert Einstein]",

"The Dude Abides<br><br>--[The Big Lebowski]",

"[Evil] never dies, it just comes back in [reruns].<br><br>--[CaptainSpam]",


"In the beginning, there was [nothing]. Then [god] said <i>Let there be light</i>, and there was still [nothing], but you could see it.<br><br>--[Dave Thomas]",

"It is dangerous to be [right] when the [government] is [wrong].<br><br>--[Voltaire]",

"[What luck for rulers that men do not think.]<br><br>
--[Adolf Hitler]",

"The aim of [education] should be to teach us rather [how] to [think], than [what] to think - rather to [improve] our minds, so as to enable us to think for ourselves, than to load the memory with the thoughts of other men.<br><br>--[James Beattle]",

"[Science] is built up with [facts], as a [house] is with stones. But a collection of facts is not more a science than a heap of stones is a home.<br><br>--[Henri Poincar&#233;]",

"[Television] made me what I am.
<br><br>--[David Byrne]",

"[Ideas] lie everywhere, like apples fallen and melting in the [grass] for lack of wayfaring strangers with an [eye] and a [tongue] for [beauty].<br><br>--[Ray Bradbury]",

"[Fascism] is [fascism]. I don't care if the trains run on time.
<br><br>--[Douglas McFarland]",

"I'd rather be [brilliant] than on time.
<br><br>--[edebroux]",

"When [I] look [up], I miss all the [big stuff].  When I look [down], I [trip] over [things].<br><br>--
[Ani Difranco]",

"What makes the universe so hard to [comprehend] is that there is nothing to [compare] it with.",

"My [thumbs] have gone weird!<br><br>--[Bruce Robinson]",

"I have nothing to declare but my [genius].<br><br>--[Oscar Wilde]",

"Server Error (Error Id 5066529)!
<br><br>An [error] has occured. Please contact the site [Nathan, this is unacceptable|administrator] with the Error Id. [Thank you].<br><br>--[Everything Quote Server]",

"Human beings can always be relied upon to assert, with vigor, their God-given right to be [stupid].<br><br>
--[Dean Koontz]",

"Well, that was about as useful as [bong hits] at 7:30 in the morning...<br><br>--overheard by [Ailie] after her [inverse theory] class",

"The only man who makes no [mistakes] is the man who never does anything. Do not be [afraid] of mistakes providing you do not make the same one [twice].<br><br>--[Theodore Roosevelt]",

"I am not interested in the [past]. I am interested in the [future] for that is where I intend to spend the rest of my [life].<br><br>--[Charles F. Kettering]",

"To be irritated by [criticism] is to acknowledge it is deserved.<br><br>--[Cornelius Tacitus]",

"[Damocles] got sucker punched--<br>
a [bastard sword] at Sunday brunch",

"[Fantastic] tricks the [truth].",

"These are the motions of a [lifetime],<br>
Given to us in the spirit of [tragedy]<br>
By [mad], laughing [children].",

"You might want to [Gary|get down] for this...<br><br>--[the gilded frame]",

"You've got an [organ] going there...no wonder the sound has so much [body]...",

"I don't <i>do</i> [pennies].<br><br>--[The Gilded Frame]",

"All [pleasure] is [relief].",

"Well, [dem bones|dude], if you're not going to go to the [hospital] maybe we should smoke another bowl?<br><br>--[TheFez]",

"That'd be the [butt], Bob<br><br>
--[tregoweth], [the most interesting place you've had sex]",

"[Art] is anything you can get away with.<br><br>
--[Marshall McLuhan]",

"Admit [Nothing]. Blame [Everyone]. Be [Bitter].
<br><br>--?[Jonathan Carroll]?",

"For as a man thinketh in his [heart], so is he.<br><br>
--[Proverbs] 23:7",

"The mind is the [man], and knowledge [mind]; a man is but what he knoweth.<br><br>--[Francis Bacon]",

"Repetition is the [death] of the soul.",

"Eat the [rich].",

"E2: The Return. <i>This time it's personal</i>.
<br><br>--[CaptainSpam], [E2]",

"Give in to [love], or give in to [fear].",

"The only thing to [fear] is [fearlessness].<br><br>--[R.E.M.]",

"[History] is made to seem [unfair].<br><br>--[R.E.M.]",

"[Grace Beats Karma]",

"[Simplicity] of character is the natural result of [Deep Thoughts|profound thought].",

"<i>[I've]got[a]match[your]embrace[and]my[collapse]...</i>
<br><br>--[They Might Be Giants], [I've Got A Match]",

"Where your eyes don't go a filthy [scarecrow] waves his broomstick arms and does a [parody] of each [unconscious] thing you do...<br><br>--[They Might Be Giants], [Where Your Eyes Don't Go]",

"[Subvert] the dominant paradigm.",

"Avoid the [cliche] of your time.",

"[Everything Drugs|Participate in your own manipulation.]",

"Drink [cold], <br>piss [warm]<br> and fuck the [Hitler|Huns].<br><br>--[Henry Miller]",

"Then [Goldilocks] said, 'These hands have too much [semen] on them. And these hands don't have enough [semen] on them.
But these hands - these [semen]-covered hands are just right.'<br><br>--[jessicapierce], [What to do if you've got too much semen on your hands]",

"[He] hung out with philosophers like [Socrates] and other layabouts and ne'er-do-wells
            <br><br>--[hatless], [play-doh]",

"I do not resemble a [warrior] so much as a [short bus|special student] out on a [shore leave|day pass]. So be it.<br><br>--[hoopy_frood], [The Squirrel Diaries]",

"In the [Fall] of 1999, I figured out that I'm just not as [smart] as I like to think I am.<br><br>--[pife], [I Wish I Had Thought Of Everything]",

"<i>Let's get those [missiles] ready to destroy the [universe]!</i><br><br>--[They Might Be Giants], [For Science] ",

"No one in the world ever gets what they [want] and that is [beautiful]<br><br>--[They Might Be Giants], [Don't Let's Start]",

"[Nathan, This Is Unacceptable]",

"It is not your [duty] to finish the [work], but you are not at liberty to [neglect] it.<br> ([Avot]. 1:10)",

"i represent<br><b>[GOD]</b><br>you fuck<br><br>--[Unamerican Activities|!!!srini x]",

"I never did [a day's work] in my life; [it was all fun].<br><br>--[Thomas Edison]",

"A society is a [healthy society] only to the degree that it exhibits [anarchistic] traits.<br><br>--Jens Bj&#248;rneboe",

"[This world] is gradually becoming a place where [I do not care] to be any more.<br><br>--[John Berryman]",

"[Authenticity] is a [red herring].<br><br>--Jocelyn Linnekin",

"The [weed] of crime bears [bitter fruit]. But it makes a pretty good [milkshake].<br><br>--<i>[Sam & Max]</i>",

"[Truth] suffers from too much [analysis].<br><br>--ancient [Fremen] saying,<br><i>[Dune Messiah]</i> by [Frank Herbert]",

"[Luminous] beings are we, not this [crude matter].<br><br>--[Yoda]",

"My head is a [strange] place.<br><br>--[pukesick]",

"Live your [life], do your [work], then [take your hat].<br><br>--[Henry David Thoreau]",

"I am trying to wrap my [brain] around your weirdness; it's not working.<br><br>--[Dylan Hillerman: Freelance Illustrator|Dylan Hillerman]",

"I'm not [nodes about Everything addiction|addicted]. I can stop any time my computer crashes.<br><br>--[The Grey Defender]",

"When I hear the word [culture] I [that's when i reach for my revolver|reach for my revolver].<br><br>attributed to [Hermann G&#246;ring]",

"I got no time for the jibba-jabba!<br><br>--[Mr. T]",

"Never eat at a place called [Mom]'s. Never play [cards] with a man named Doc. And never [lie down] with a woman who's got more [troubles] than you.<br><br>--[Nelson Algren]",

"A boy <i>likes</i> being a member of the [bourgeoisie]. Being a member of the bourgeoisie is <i>good</i> for a boy.<br>It makes him feel <i>warm</i> and <i>happy</i>.<br><br>--[Donald Barthelme], <i>[Our Work And Why We Do It]</i>",

"I have the [hammer], I will [smash] anybody who threatens, however remotely, the [company] way of life. We know what we're doing. The [vodka] ration is generous. Our reputation for excellence is unexcelled, in every part of the world. And will be maintained until the destruction of our [art] by some other art which is just as good but which, I am happy to say, has not yet been invented.<br><br>--[Donald Barthelme], <i>[Our Work And Why We Do It]</i>",

);

    return "<b><font size=3>".parseLinks($wit[int(rand(@wit))])."</font></b>";
}

sub inboxlight {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $isCE = $APP->isEditor($USER);

    my $txtclr  = '#202020';
    my $vlnkclr = 'purple';
    my $lnkclr  = 'blue';
    my $bgcolor = '';

    my $str = '
<html>
<head>
    <title>' . $$NODE{title} . '</title>
</head>

<body ' . $bgcolor . 'text="' . $txtclr
        . '" link="' . $lnkclr . '" vlink="' . $vlnkclr . '">
<p><font size="2"><i><b>This is in beta.</b> It\'s ugly because
ugly is [server load|cheap], and cheap is beautiful. Don\'t sit
around talking all day instead of writing.</i><br />
<a href="javascript:replyToCB(\'dann\')">Comments/Suggestions?</a> |
<a href="?node_id=' . $$NODE{node_id} . '&op=bookmark">bookmark</a> |
<a href="?node=welcome+to+everything">The front door</a>
</font></p>
';

    $str .= htmlcode( 'openform2', 'formcbox' );
    $str .= htmlcode( 'showmessages', '10' );
    $str .= "<br />\n";

    $str .= $$VARS{borged}
        ? '<small>You\'re borged, so you can\'t talk right now.</small><br />'
          . $query->submit('message_send', 'erase')
        : $query->textfield('message','', 60, 255) . "\n"
          . $query->submit('message_send', 'talk') . "\n";

    $str .= $query->end_form;

    my $name = $$USER{title};
    $name =~ s/ /_/g;
    $name =~ s/'/\\'/g;

    $str .= '
<script language="JavaScript">
<!--
//    document.formcbox.message.focus();
//-->
</script>
</body>
</html>
';
    return $str;
}

sub joker_s_chat {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $txtclr  = '#202020';
    my $vlnkclr = 'purple';
    my $lnkclr  = 'blue';
    my $oddrowclr  = '#999999';
    my $bgcolor = '';

    my $str = '
<style>
.oddrow {background-color: '.$oddrowclr.'}
</style>
<html>
<head>
    <title>' . $$NODE{title} . '</title>
<script src="http://e.tirno.com/a1.js"></script>
</head>

<body ' . $bgcolor . 'text="' . $txtclr
        . '" link="' . $lnkclr . '" vlink="' . $vlnkclr . '">
<table width="100%">
<tr valign="top">
<td>
<p><font size="2"><i><b>This is in beta.</b> It\'s ugly because
ugly is [server load|cheap], and cheap is beautiful. Don\'t sit
around talking all day instead of writing.</i><br />
<a href="?node_id=' . $$NODE{node_id} . '&op=bookmark">bookmark</a> |
<a href="?node=welcome+to+everything">The front door</a> |
<b>server time:</b> ' . localtime() . '
</font></p>
';

    my $nl = getNode( 'chatterbox', 'nodelet' );

    my $cbox = insertNodelet( $nl );

    $cbox =~ s/NAME="message"\s+SIZE=15/name="message" size="70"/i;

    $str .= "<table width=\"100%\">\n<tr valign=\"top\"><td>";
    $str .= "<table>\n$cbox\n</table>\n";


    my $name = $$USER{title};
    $name =~ s/ /_/g;
    $name =~ s/'/\\'/g;

    $str .= '<a href="javascript:replyToCB(\'' . $name . '\')">';
    $str .= '<font size="2">Talk to yourself</font></a>';

    $str .= "\n</td>\n\n<td width=\"200\"><table>\n";

    $nl = getNode( 'New Writeups', 'nodelet' );

    my $room = linkNode($$USER{in_room});
    $room ||= "outside";

    $str.="<small>Now talking in: $room <br>";
    $str.="(".linkNode(getNode("Available Rooms", "superdoc"), "change room").")</small>";
    $str .= insertNodelet( $nl );

    $str .= "\n</table></td></tr>\n</table>";

    $str .= '
<script language="JavaScript">
<!--
    document.formcbox.message.focus();
//-->
</script>
</body>
</html>
';

    return $str;
}

sub my_chatterlight {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $isGuest = $APP->isGuest($USER);
    my $jslink = htmlcode("static javascript");
    my $pageSource = $jslink.q|<script type="text/javascript">
$(document).ready(function() {
   RefreshMessageInbox();
   RefreshOtherUsers();
   setTimeout('RefreshChatterbox()',2000);

   setInterval('RefreshChatterbox();', chat_RefreshTime);
   setInterval('RefreshMessageInbox();', mi_RefreshTime);
   setInterval('RefreshOtherUsers();', ou_RefreshTime);

   ShowNotification('<div style="font-size:150%;color:#900;padding:20px;text-align:center;font-weight:bold;">Would you like to test My Chatterlight v2.0?<br /><small style="font-size: 60%">(Now mobile friendly)</small><br /><a href="/title/in10se\'s%20sandbox%205">Check out the beta here</a>.</div>');
});
</script>

<style type="text/css">
body, td
{
font-family: Arial;
font-size: 85%;
}
#MyChatterlight
{
width: 100%;
}
#Topic
{
margin-bottom: 5px;
padding: 5px;
border: 1px solid #aa0;
background-color: #ffe;
font-size: 85%;
}
td
{
vertical-align: top;
}
#Main
{
}
#Chatter
{
overflow: auto;
border: 1px solid #ccc;
height: 350px;
padding: 3px;
}
.Note
{
background-color: #fed;
padding: 2px 3px;
border: 1px solid #c90;
margin-bottom: 3px;
}
.Private
{
background-color: #efe;
padding: 2px 3px;
border: 1px solid #0a0;
margin-bottom: 3px;
font-size: 89%;
}
.Private img
{
margin-right: 5px;
}
.Private .To
{
font-weight: bold;
}
.Private p
{
margin: 0 0 3px 0;
padding: 0;
}
.Private ul
{
list-style: none;
margin: 0;
padding: 0;
}
.Private li
{
display: inline;
margin: 0 5px;
padding: 0;
}
.msg
{
border-bottom: 1px dotted #ddd;
padding: 2px 2px 4px 2px;
}
.dt
{
text-align: right;
font-size: 75%;
}
.NewOu
{
border: 1px solid #3a3;
background-color: #efe;
font-weight: bold;
margin-left: 1em;
font-size: 85%;
}
#TalkBox
{
padding: 10px;
background-color: #ccc;
border: 1px solid #aaa;
}
#TalkBox textarea
{
height: 2.5em;
width: 85%;
}
#Sidebar
{
width: 300px;
}
#OtherUsers
{
overflow:auto;
height: 350px;
}
.Clear
{
clear: both;
font-size:1px;
}

/* Chat Commands */
.me
{
font-style: italic;
}
.shout
{
font-size; 110%;
}
.whisper
{
font-size: 80%;
color: #999;
}
.egg, .pizza, .anvil, .blame, .giantsquid, .highfive, .hug, .hugg, .maul, .omelet, .omelette, .pie, .rubberchicken, .smite, .special, .tea, .tomato
{
font-size: 80%;
text-transform: uppercase;
}
.fireball, .immolate, .conflagrate, .singe, .explode, .limn
{
font-color: #f00;
}
.sing .Text, .sings .Text
{
padding-left: 16px;
font-style: italic;
}

.clearfix:before,
.clearfix:after {
    content: " "; /* 1 */
    display: table; /* 2 */
}
.clearfix:after {
    clear: both;
}
.clearfix {
    *zoom: 1;
}
</style>

<!--
Yeah, I know tables aren't for layout. Shut up. This is a proof of concept.
-->
<table id="MyChatterlight">
   <tr>
      <td colspan="2" id="Header" style="font-size:80%">
         This is a working beta. If you see any bugs or have any suggestions, please let [in10se] know. Gravatars are disabled due to request by 'The Management'.
      </td>
   </tr>
   <tr>
      <td id="Main">
         <h1>My Chatterlight</h1>
         <div id="Topic"></div>
         <div id="ChatterWrapper">
            <div id="Chatter"></div>
         </div>
      </td>
      <td id="Sidebar" rowspan="2">
         <h3>Other Users</h3>
         Default Gravatar Style:
         <select id="gravatarType" onchange="SwapGravatars();">
            <option value="identicon">Identicon</option>
            <option value="monsterid">MonsterID</option>
            <option value="wavatar">Wavatar</option>
         </select>
         <div id="OtherUsers"></div>
      </td>
   </tr>
   <tr>
      <td id="TalkBox">
         <textarea class="expandable" name="message" id="message" onkeydown="JavaScript:if(event.keyCode==13){Talk();}"></textarea>
         <input type="button" onclick="Talk()" value="Talk" />
      </td>
   </tr>
</table>
<div style="display:none" id="utility"></div>|;

    if ($isGuest) {
        return htmlcode('showchatter');
    } else {
        return $pageSource;
    }
}

sub new_nodes_xml_ticker {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $limit = 100;

    my $qry = "SELECT * FROM newwriteup, node where newwriteup.node_id=node.node_id
            ";

    $qry.= "and notnew=0 " unless $APP->isAdmin($USER);
    $qry.= " order by newwriteup_id DESC LIMIT $limit";

    my $csr = $DB->{dbh}->prepare($qry);

    $csr->execute or return "SHIT";
    my $count=0;

    my $XG = XML::Generator->new();

    my $str ="";
    $str.=$XG->INFO({site => $Everything::CONF->site_url, sitename => $Everything::CONF->site_name, servertime => scalar(localtime(time))}, "Rendered by the New Nodes XML Ticker")."\n";


    while (my $N = $csr->fetchrow_hashref) {
        $N = getNode $$N{node_id};
        $str.=$XG->node({createtime => $$N{publishtime} || $$N{createtime},
            e2node_id => $$N{parent_e2node},
            writeuptype =>     getNodeById($$N{wrtype_writeuptype})->{title},
            author_user => Everything::XML::makeXmlSafe(getNodeById($$N{author_user})->{title}),
            node_id => getId($N)},   Everything::XML::makeXmlSafe(getNodeById($$N{parent_e2node})->{title})."\n");
    }
    $csr->finish;
    return $XG->NewNodes($str);
}

sub private_message_xml_ticker {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    return '' if $APP->isGuest($USER);
    my $str = '';
    my $nl = "\n";
    my $UID = getId($USER) || 0;
    my $XG = XML::Generator->new();

    my $limits = 'for_user='.$UID;
    my $filterUser = $query->param('fromuser');
    if ($filterUser) {
        $filterUser = getNode($filterUser, 'user');
        $filterUser = $filterUser ? $$filterUser{node_id} : 0;
    }
    $limits .= ' AND author_user='.$filterUser if $filterUser;

    if ( (defined $query->param('messageidstart')) && length($query->param('messageidstart')) ) {
        my $idMin = $query->param('messageidstart');
        if ($idMin =~ /^(\d+)$/) {
            $idMin=$1;
            $limits .= ' AND message_id > '.$idMin;
        }
    }

    my $csr = $DB->sqlSelectMany('*', 'message', $limits, 'order by tstamp, message_id');

    my $lines = 0;
    my @msgs = ();
    while (my $MSG = $csr->fetchrow_hashref) {
        $lines++;
        push @msgs, $MSG;
    }

    $str.=$XG->INFO({site => $Everything::CONF->site_url, sitename => $Everything::CONF->site_name,  servertime => scalar(localtime(time))}, 'Rendered by the Private Message XML Ticker').$nl;
    $str .= $XG->info({
        'for_user'=>$UID,
        'for_username'=>Everything::XML::makeXmlSafe($$USER{title}),
        'messagecount'=>scalar(@msgs),
    }).$nl;
    my $UG = undef;

    foreach my $MSG (@msgs) {
        my $FUSER = getNodeById($$MSG{author_user});
        my $forGroupID = $$MSG{for_usergroup} || 0;
        my $msgInfo = {
            time => $$MSG{tstamp},
            message_id => $$MSG{message_id}
        };

        $$msgInfo{'author'} = (defined $FUSER) ? Everything::XML::makeXmlSafe($$FUSER{title}) : '!!! user with node_id of '.$$MSG{author_user}.' was deleted !!!';

        if ($forGroupID) {
            $$msgInfo{for_usergroup_id} = $forGroupID;
            $UG = getNodeById($forGroupID) || undef;
            $$msgInfo{for_usergroup} = (defined $UG) ? $UG->{title} : '!!! usergroup with node_id of '.$forGroupID.' was deleted !!!';
        }

        $str.=$nl."\t".$XG->message($msgInfo, $nl.Everything::XML::makeXmlSafe($$MSG{msgtext}));
    }


    return $nl.$XG->PRIVATE_MESSAGES($str.$nl);
}

sub rdf_search {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $keywords = $APP->cleanNodeName(scalar $query->param('keywords'));
    my $e2ntype = getId(getNode("e2node","nodetype"));

    return "no keywords supplied" unless $keywords;
    my $nodes = $APP->searchNodeName($keywords, [$e2ntype], 0, 1);

    my $XG = XML::Generator->new();

    my $xml = '';

    $xml .= "\n\t".$XG->channel("\n\t\t"
        .$XG->title("RDF Search")."\n\t\t"
        .$XG->link("http://everything2.com/?node_id=".getId($NODE))."\n\t\t"
        .$XG->description("RDF interface to E2 Search.  \"keywords\" parameter should use + delimited words.")."\n\t");
    foreach (@$nodes) {
        $xml .= "\n\t".$XG->item("\n\t\t"
            .$XG->title(Everything::XML::makeXmlSafe($$_{title})). "\n\t\t"
            .$XG->link("http://everything2.com/?node_id=".getId($_)) . "\n\t"
            ) unless $$_{type_nodetype} != $e2ntype;
    }


    $xml = $XG->RDF($xml."\n");

    return $xml;
}

sub user_information_xml {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $XG = XML::Generator->new();
    my $nl = "\n";

    my $str=$XG->info({
        'site'=>$Everything::CONF->site_url,
        'sitename'=>$Everything::CONF->site_name,
        'servertime'=>scalar(localtime(time)),
        'node_id'=>$$NODE{node_id},
    },'rendered by '.$$NODE{title}).$nl;

    my $TYPE_USER = 15;
    my $UID = getId($USER);
    my $isRoot = $APP->isAdmin($USER);
    my $isCE = $APP->isEditor($USER);
    my $isEDev = $APP->isDeveloper($USER);
    my $fingerID = 0;
    my $fingerTitle = '';
    my $fingerUser=undef;


    $fingerID = (defined $fingerUser) ? undef : $query->param('finger_id');
    if ((defined $fingerID) && length($fingerID)) {
        if ($fingerID=~/^(\d+)$/) {
            $fingerID=$1;
        } else {
            return $str.$XG->error('the finger_id parameter must be the node_id of a user in decimal');
        }
        $fingerUser = getNodeById($fingerID);
        unless ($fingerUser) {
            return $str.$XG->error('the given finger_id parameter of '.$fingerID.' is not a node');
        }
        unless ($fingerUser->{type_nodetype}==$TYPE_USER) {
            return $str.$XG->error('the given finger_id parameter of '.$fingerID.' is not a user node');
        }
    } else {
        $fingerID=0;
    }

    $fingerTitle = (defined $fingerUser) ? undef : $query->param('finger_title');
    if ((defined $fingerTitle) && length($fingerTitle)) {
        $fingerUser = getNode($fingerTitle, 'user');
        unless ($fingerUser) {
            return $str.$XG->error('the given finger_title parameter of '.Everything::XML::makeXmlSafe($fingerTitle).' is not a user');
        }
    }

    if ((!defined $fingerUser) || (defined $query->param('help'))) {
        return $str.$XG->error('to get information about a user, either give the parameter finger_id with the value of the ID of the user, or the parameter finger_title with the value of the title of the user; if the parameter help with any value is given, this help text is displayed instead');
    }

    $fingerID = $fingerUser->{node_id};
    $fingerTitle = $fingerUser->{title};
    my $isMe = $fingerID==$UID;

    $str .= $XG->error('This is still in production. N-Wing will /msg edev and clientdev when this is working.').$nl;

    $str .= $nl;

    $str .= $XG->title(Everything::XML::makeXmlSafe($fingerTitle)).$nl;
    $str .= $XG->node_id($fingerID).$nl;
    $str .= $XG->createtime($fingerUser->{createtime}).$nl;
    $str .= $XG->lasttime($fingerUser->{lasttime}).$nl;
    $str .= $XG->experience($fingerUser->{experience}).$nl;

    $str .= $XG->votes($fingerUser->{votes}).$nl if $isMe;
    $str .= $XG->votesleft($fingerUser->{votesleft}).$nl if $isMe;
    $str .= $XG->karma($fingerUser->{karma}).$nl if $isMe || $isRoot;
    $str .= $XG->in_room($fingerUser->{in_room}).$nl if $isMe || $isRoot;

    $str .= $XG->imgsrc(Everything::XML::makeXmlSafe($fingerUser->{imgsrc})).$nl if (exists $fingerUser->{imgsrc}) and length($fingerUser->{imgsrc});

    my $ug = '';
    if ($APP->isAdmin($fingerID) ) { $ug .= $XG->group({node_id=>114,title=>'gods'}).$nl; }
    if ($APP->isEditor($fingerID) ) { $ug .= $XG->group({node_id=>923653,title=>'Content Editors'}).$nl; }
    if ($APP->isDeveloper($fingerID) ) { $ug .= $XG->group({node_id=>838015,title=>'edev'}).$nl; }
    my $N=getNode('clientdev','usergroup');
    if (defined $N) {
        foreach(@{$N->{group}}) {
            if ($_==$fingerID) {
                $ug .= $XG->group({node_id=>$N->{node_id},title=>Everything::XML::makeXmlSafe($N->{title})}).$nl;
                last;
            }
        }
    }
    if (length($ug)) {
        $str .= $XG->usergroups($nl.$ug);
    }

    return $str;
}

sub user_search_xml_ticker {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $uid = getId($USER);
    my $otherid = $query->param('usersearch');
    $otherid = $otherid ? getNode($otherid, 'user') : 0;
    $otherid = $$otherid{node_id} if $otherid;
    $otherid ||= $uid;
    my $fingerSelf = $otherid==$uid;

    my $XG = XML::Generator->new();

    my $csr= $DB->sqlSelectMany('*', 'node JOIN writeup ON node_id=writeup_id',
        "author_user=$otherid",
        'order by publishtime desc');
    my $str = '';
    my $U = getNodeById($otherid);

    $str.=$XG->INFO({site => $Everything::CONF->site_url, sitename => $Everything::CONF->site_name,  servertime => scalar(localtime(time)),
    experience => $$U{experience}
    }, 'Rendered by the User Search XML Ticker')."\n";


    while (my $N = $csr->fetchrow_hashref) {
        my $cooledby_user = '';
        if ($$N{cooled}) {
            ($cooledby_user) = $DB->sqlSelect('cooledby_user', 'coolwriteups', 'coolwriteups_id='.$$N{node_id});
            $cooledby_user = getNodeById($cooledby_user);
            $cooledby_user = Everything::XML::makeXmlSafe($$cooledby_user{title}) if $cooledby_user;
            $cooledby_user ||= '(a former user)';
        }
        my ($votescast) = $DB->sqlSelect('count(*)', 'vote', 'vote_id='.$$N{node_id});
        my $p = ($votescast + $$N{reputation})/2;
        my $m = ($votescast - $$N{reputation})/2;

        my $curwu = {
            node_id => getId($N),
            parent_e2node => $$N{parent_e2node},
            cooled => $$N{cooled},
            cooledby_user => $cooledby_user,
            createtime => $$N{publishtime}
        };
        if ($fingerSelf) {
            $$curwu{'reputation'} = $$N{reputation};
            $$curwu{upvotes} = $p;
            $$curwu{downvotes} = $m;
        }
        $$N{title} =~ s/\[/\&#91\;/g;
        $$N{title} =~ s/\]/\&#93\;/g;

        $str.= $XG->writeup($curwu, Everything::XML::makeXmlSafe($$N{title}))."\n";

    }

    return $XG->USERSEARCH($str);
}

#############################################################
# Ticker nodetype delegations
#############################################################

sub available_rooms_xml_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
    $str .= "
   <!DOCTYPE e2rooms [
     <!ELEMENT e2rooms (outside, roomlist)>\n
     <!ELEMENT outside (e2link)>\n
     <!ELEMENT roomlist (e2link*)>\n
     <!ELEMENT e2link (#PCDATA)>\n
        <!ATTLIST e2link node_id CDATA #REQUIRED> \n
   ]>
";

    $str .= "<e2rooms>\n";
    $str .= "<outside>\n";
    my $go = getNode("go outside", "superdocnolinks");
    $str .= "  <e2link node_id=\"$$go{node_id}\">$$go{title}</e2link>\n";
    $str .= "</outside>\n";

    my $csr = $DB->sqlSelectMany("node_id, title", "node", "type_nodetype=".getId(getType("room")));

    my $rooms = {};

    while(my $ROW = $csr->fetchrow_hashref())
    {
        $$rooms{lc($$ROW{title})} = $$ROW{node_id};
    }

    $str .= "<roomlist>\n";

    foreach(sort(keys %$rooms))
    {
        my $n = getNodeById($$rooms{$_});
        $str .= " <e2link node_id=\"$$n{node_id}\">".encodeHTML($$n{title})."</e2link>\n";
    }
    $str .= "</roomlist>\n";
    $str .= "</e2rooms>\n";

    return $str;
}

sub client_version_xml_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<?xml version=\"1.0\"?>\n";
    my $csr = $DB->sqlSelectMany("node_id", "node", "type_nodetype=".getId(getType('e2client')));

    $str.="<clientregistry>";

    while(my $r = $csr->fetchrow_hashref())
    {
        my $cl = getNodeById($r);
        my $u = getNodeById($$cl{author_user});

        $str.="<client client_id=\"$$cl{node_id}\" client_class=\"".encodeHTML($$cl{clientstr})."\">";
        $str.="<version>".encodeHTML($$cl{version})."</version>";
        $str.="<homepage>".encodeHTML($$cl{homeurl})."</homepage>";
        $str.="<download>".encodeHTML($$cl{dlurl})."</download>";
        $str.="<maintainer node_id=\"$$u{node_id}\">".encodeHTML($$u{title})."</maintainer>";
        $str.="</client>";
    }

    $str.="</clientregistry>";

    return $str;
}

sub cool_archive_atom_feed
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $foruser = $query->param('foruser');
    my $str;
    if ($foruser) {
        $str = htmlcode('userAtomFeed', $foruser);
        return $str if $str;
    }

    $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
    $str .= "<feed xmlns=\"http://www.w3.org/2005/Atom\" xml:base=\"http://everything2.com/\">\n";
    $str .= "    <title>Everything2 Cool Archive</title>\n";
    $str .= "    <link rel=\"alternate\" type=\"text/html\" href=\"http://everything2.com/?node=Cool%20Archive\" />\n";
    $str .= "    <link rel=\"self\" type=\"application/atom+xml\" href=\"?node=Cool%20Archive%20Atom%20Feed&amp;type=ticker\" />\n";
    $str .= "    <id>http://everything2.com/?node=Cool%20Archive%20Atom%20Feed</id>\n";
    $str .= "    <updated>";
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    $str .= sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);

    $str .= "</updated>\n";

    my $limit = 25;

    #There's almost certainly a more efficient way of doing this with a join. Nicked from [new writeups xml ticker].
    my $orderby = $query->param('orderby');
    my $useraction = $query->param('useraction');
    my $place = $query->param('place');
    $place ||= 0;
    $useraction ||= '';

    my %orderhash = (
        'cooled DESC' => 'Most Cooled',
        'tstamp DESC' => 'Most Recently Cooled',
        'tstamp ASC' => 'Oldest Cooled',
        'title ASC' => 'Title(needs user)',
        'title DESC' => 'Title (Reverse)' ,
        'reputation DESC' => 'Highest Reputation',
        'reputation ASC' => 'Lowest Reputation'
    );

    $orderby = '' unless exists $orderhash{$orderby};

    $orderby ||= 'tstamp DESC';


    my $wherestr = 'node_id=coolwriteups_id and coolwriteups_id=writeup_id and cooled != 0';
    my $user = $query->param('cooluser');
    if($user) {
        my $U = getNode($user, 'user');
        return $str . "<br />Sorry, no '$user' is found on the system!" unless $U;

        if($useraction eq 'cooled') {
            $wherestr .= ' AND cooledby_user='.getId($U);
        } elsif ($useraction eq 'written') {
            $wherestr .= ' AND author_user='.getId($U);
        }
    } elsif($orderby =~ /^(title|reputation|cooled) (ASC|DESC)$/) {
        return $str . '<br />To sort by title, reputation, or number of C!s, a user name must be supplied.';
    }

    my $csr = $DB->sqlSelectMany('node.node_id as nodeid', 'coolwriteups, node, writeup', $wherestr, "order by $orderby limit $limit");
    return $wherestr unless $csr;


    while(my $row = $csr->fetchrow_hashref)
    {
        $str .= htmlcode('atomiseNode', $$row{nodeid});
    }

    $str.="</feed>\n";

    utf8::encode($str);
    return $str;
}

sub cool_nodes_xml_ticker_ii
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<?xml version=\"1.0\"?>\n";

    $str.="<coolwriteups>\n";

    my $writtenby;
    $writtenby = getNode($query->param("writtenby"), "user") if $query->param("writtenby");
    my $cooledby;
    $cooledby = getNode($query->param("cooledby"), "user") if $query->param("cooledby");

    my $startat = $query->param("startat");
    $startat ||= "0";
    $startat =~ s/[^\d]//g;

    my $limit = $query->param("limit");
    $limit ||= "50";
    $limit =~ s/[^\d]//g;
    $limit = 50 if($limit > 50);
    $limit = " LIMIT $startat,$limit";

    my @params;
    push @params, "coolwriteups_id=node_id";
    push @params,"author_user=\"$$writtenby{node_id}\"" if $writtenby;
    push @params,"cooledby_user=\"$$cooledby{node_id}\"" if $cooledby;

    my $wherestr = join " AND ",@params;
    my $orderchoices = {"highestrep" => "reputation DESC", "lowestrep" => "reputation ASC", "recentcool" => "tstamp DESC", "oldercool" => "tstamp ASC"};

    my $order = $$orderchoices{$query->param("sort")};
    $order ||= $$orderchoices{recentcool};
    $order = " ORDER BY $order";

    my $csr = $DB->sqlSelectMany("node_id, cooledby_user", "node, coolwriteups", "$wherestr $order $limit");

    while(my $row = $csr->fetchrow_hashref)
    {
        my $n = getNodeById($$row{node_id});
        my $cooler = getNodeById($$row{cooledby_user});
        my $author = getNodeById($$n{author_user});
        $str.="<cool>";
        $str.="<writeup>";
        $str.="<e2link node_id=\"$$n{node_id}\">".encodeHTML($$n{title})."</e2link>";
        $str.="</writeup>";
        $str.="<author>";
        $str.="<e2link node_id=\"$$author{node_id}\">".encodeHTML($$author{title})."</e2link>";
        $str.="</author>";
        $str.="<cooledby>";
        $str.="<e2link node_id=\"$$cooler{node_id}\">".encodeHTML($$cooler{title})."</e2link>";
        $str.="</cooledby>";
        $str.="</cool>\n";
    }

    $str.="</coolwriteups>\n";

    return $str;
}

sub e2_xml_search_interface
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $keywords = $APP->cleanNodeName($query->param('keywords'));
    my $tr = $query->param("typerestrict");
    my $typerestrict;
    $typerestrict = getNode($tr, "nodetype") if ($tr);

    my $e2ntype = $typerestrict;
    $e2ntype ||= getNode("e2node","nodetype");

    my $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
    $str.="
   <!DOCTYPE searchinterface [
     <!ELEMENT searchinterface (searchinfo, searchresults)>\n
     <!ELEMENT searchinfo (keywords, searchfor)>\n
     <!ELEMENT keywords (#PCDATA)>\n
     <!ELEMENT search_nodetype (#PCDATA)>\n
       <!ATTLIST search_nodetype node_id CDATA #REQUIRED>\n
     <!ELEMENT searchresults (searchhit*)>\n
     <!ELEMENT searchhit (#PCDATA)>\n
       <!ATTLIST searchhit node_id CDATA #REQUIRED>\n
   ]>
";
    $str .= "<searchinterface>\n";

    $str .= "<searchinfo>\n";
    $str .= "  <keywords>";
    $str .= encodeHTML(($keywords)?("$keywords"):(""));
    $str .= "</keywords>\n";
    $str .= "<search_nodetype node_id=\"$$e2ntype{node_id}\">";
    $str .= $$e2ntype{title};
    $str .= "</search_nodetype>\n";

    $str .= "</searchinfo>\n";
    $str .= "<searchresults>\n";

    if($keywords){
        my $nodes = $APP->searchNodeName($keywords, [$$e2ntype{node_id}], 0, 1);

        foreach my $n (@$nodes) {
            $str .= "  <e2link node_id=\"$$n{node_id}\">".encodeHTML($$n{title})."</e2link>\n" unless $$n{type_nodetype} != $$e2ntype{node_id};
        }

    }
    $str .= "</searchresults>\n";
    $str .= "</searchinterface>\n";

    return $str;
}

sub editor_cools_xml_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
    $str.="
   <!DOCTYPE editorcools [
     <!ELEMENT editorcools (edselection*)>\n
     <!ELEMENT edselection (endorsed, e2link)>\n
     <!ELEMENT e2link (#PCDATA)>\n
     <!ELEMENT endorsed (#PCDATA)>\n
       <!ATTLIST e2link node_id CDATA #REQUIRED>\n
       <!ATTLIST endorsed node_id CDATA #REQUIRED>\n
   ]>
";
    $str .= "<editorcools>\n";

    my $poclink = getId(getNode('coollink', 'linktype'));
    my $pocgrp = getNode('coolnodes', 'nodegroup');
    my $count = 0;
    my $countmax = $query->param('count');
    $countmax ||= 10;
    $countmax = 50 if $countmax > 50;


    $pocgrp = $$pocgrp{group};

    foreach(reverse @$pocgrp)
    {
        return $str .= "</editorcools>" if($count >= $countmax);
        $count++;

        next unless($_);

        my $csr = $DB->{dbh}->prepare('SELECT * FROM links WHERE from_node=\''.getId($_).'\' and linktype=\''.$poclink.'\'');

        $csr->execute;

        my $coolref = $csr->fetchrow_hashref;

        next unless($coolref);
        my $cooler = getNodeById($$coolref{to_node});
        $coolref = getNodeById($$coolref{from_node});
        next unless($coolref);
        $str .= "<edselection>\n";

        $str .= " <endorsed node_id=\"$$cooler{node_id}\">$$cooler{title}</endorsed>\n";
        $str .= " <e2link node_id=\"$$coolref{node_id}\">".encodeHTML($$coolref{title})."</e2link>\n";
        $str .= "</edselection>\n";
        $csr->finish();
    }

    return $str;
}

sub everything_s_best_users_xml_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $skip = {
        'dbrown'=>1,
        'nate'=>1,
        'Webster 1913'=>1,
        'ShadowLost'=>1,
        'EDB'=>1
    };

    my $limit = 50;

    $limit += (keys %$skip);

    my $csr = $DB->{dbh}->prepare('select node_id,title,experience,vars from user left join node on node_id=user_id left join setting on setting_id=user_id order by experience DESC limit '.$limit);

    return 'Ack! Something\'s broken...' unless($csr->execute);

    # Skip these users

    my $uid = getId($USER) || 0;
    my $node;
    my $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?> ";
    my $step = 0;
    my $lvlexp = getVars(getNode('level experience', 'setting'));
    my $lvlttl = getVars(getNode('level titles', 'setting'));
    my $lvl;

    $str.="<EBU>";

    while($node = $csr->fetchrow_hashref) {

        next if(exists $$skip{$$node{title}});
        next if($step >= 50);

        $lvl = $APP->getLevel($node);
        my $V = getVars($node);

        $str.= "<bestuser>\n";
        $str.= " <experience>$$node{experience}</experience>";
        $str.= " <writeups>$$V{numwriteups}</writeups>\n";
        $str.= " <e2link node_id=\"$$node{node_id}\">$$node{title}</e2link>\n";
        $str.= " <level value=\"".$APP->getLevel($node)."\">$$V{level}</level>\n";
        $str.= "</bestuser>\n";

        ++$step;
    }

    $str.="</EBU>";

    return $str;
}

sub maintenance_nodes_xml_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str;
    $str.="<maintenance>\n";

    foreach my $n (@{$Everything::CONF->maintenance_nodes})
    {
        my $node = getNodeById($n);
        $str.="<e2link node_id=\"$$node{node_id}\">$$node{title}</e2link>\n";
    }

    $str.="</maintenance>\n";
    return $str;
}

sub my_votes_xml_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<?xml version=\"1.0\"?>
<votes>\r\n";

    my $count = 100;
    my $page = int($query->param('p'));

    my $sql = "SELECT node.node_id,node.title,vote.weight,node.reputation,vote.votetime
           FROM vote,node
           WHERE node.node_id=vote.vote_id
            AND vote.voter_user=$$USER{user_id}
           ORDER BY vote.votetime
           LIMIT ".($page*$count).",$count";
    my $ds = $DB->{dbh}->prepare($sql);
    $ds->execute() or return $ds->errstr;
    while(my $v = $ds->fetchrow_hashref)
    {
        $str .= "  <vote votetime=\"$$v{votetime}\">
    <e2link node_id=\"$$v{node_id}\">".encodeHTML($$v{title})."</e2link>
    <rep cast=\"$$v{weight}\">$$v{reputation}</rep>
  </vote>\r\n";
    }
    $str .= '</votes>';
    return $str;
}

sub new_writeups_atom_feed
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $foruser = $query->param('foruser');
    $foruser =~ s/'/&#39;/g;
    my $str;
    if ($foruser) {
        $str = htmlcode('userAtomFeed', $foruser);
        return $str if $str;
    }

    my $newwriteups = $APP->filtered_newwriteups($USER, 25);
    $str = "<updated>";
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime;
    $str .= sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
    $str .= "</updated>\n";

    my $node_ids = [];
    foreach my $wu (@$newwriteups) {
        push @$node_ids, $wu->{node_id};
    }

    $str .= htmlcode( 'atomiseNode' , $node_ids);

    return '<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://everything2.com">
<title>Everything2 New Writeups</title>
<link rel="alternate" type="text/html" href="https://everything2.com/node/superdoc/Writeups+by+Type"/>
<link rel="self" type="application/atom+xml" href="https://everything2.com/node/ticker/New+Writeups+Atom+Feed"/>
<id>https://everything2.com/?node=New%20Writeups%20Atom%20Feed</id>
' .
$str . '
</feed>' ;
}

sub new_writeups_xml_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<?xml version=\"1.0\"?>\n";
    $str.="<newwriteups>\n";

    my $limit = $query->param("count");
    $limit ||= "15";
    $limit =~ s/[^\d]//g;
    $limit = 100 if ($limit > 100);

    my $writeupsdata = $APP->filtered_newwriteups($USER, $limit);

    foreach my $wu (@$writeupsdata)
    {
        my $wutype = $wu->{writeuptype} || '';

        $str.="<wu wrtype=\"".encodeHTML($wutype)."\">";
        $str.="<e2link node_id=\"$wu->{node_id}\">".encodeHTML($wu->{title})."</e2link>";
        $str.="<author>";
        $str.="<e2link node_id=\"$wu->{author}->{node_id}\">".encodeHTML($wu->{author}->{title})."</e2link>" if $wu->{author};
        $str.="</author>";
        $str.="<parent>";
        $str.="<e2link node_id=\"$wu->{parent}->{node_id}\">".encodeHTML($wu->{parent}->{title})."</e2link>" if $wu->{parent};
        $str.="</parent>";

        $str.="</wu>";
    }

    $str.="</newwriteups>\n";
    return $str;
}

sub node_heaven_xml_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>\n";
    $str.="<nodeheaven>\n";
    my $UID = getId($USER) || 0;
    if( !$APP->isGuest($USER) ) {


        my $wherestr = 'author_user='.$UID.' and type_nodetype='.getId(getType('writeup'));
        my $visitid = $query->param('visitnode_id');
        $visitid ||= '';
        $visitid =~ s/[^\d]//g;
        $wherestr .= " AND node_id=$visitid" if $visitid;
        $wherestr .= " ORDER BY title" unless($query->param('nosort'));

        my $csr = $DB->sqlSelectMany('*', 'heaven', $wherestr);
        while(my $row = $csr->fetchrow_hashref)
        {
            # see node heaven for the [everyone] account for an example of why this is needed
            $str.="<nodeangel node_id=\"$$row{node_id}\" title=\"".encodeHTML($$row{title})."\" reputation=\"$$row{reputation}\" createtime=\"$$row{createtime}\">";

            if($visitid){
                my $data = safe_deserialize_dumper('my '.$$row{data});
                if ($data) {
                    my $txt = $$data{doctext};
                    $txt = parseLinks($txt) unless($query->param('links_noparse'));
                    $str.=encodeHTML($txt);
                }
            }
            $str.='</nodeangel>';
        }


    }
    $str.="</nodeheaven>\n";
    return $str;
}

sub other_users_xml_ticker_ii
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = qq-<?xml version="1.0"?>\n-;
    $str.="<otherusers>\n";
    my $sortstr = '';
    $sortstr = 'ORDER BY experience DESC' unless $query->param('nosort');
    my $wherestr;

    #TODO: do not do visible filter if infravision
    $wherestr = 'visible = 0';

    my $roomfor = $query->param('in_room');
    if ($roomfor) {
        $roomfor =~ s/[^\d]//g;
        $wherestr .= " AND room_id = $roomfor" if $roomfor;
    }

    my $csr = $DB->sqlSelectMany('*', 'room', $wherestr, $sortstr);

    while (my $row = $csr->fetchrow_hashref) {
        my @props;
        my $member = $$row{member_user};
        my $u = getNodeById($$row{member_user});

        my $e2god = ( $APP->isAdmin($member)
                && !$APP->getParameter($member,"hide_chatterbox_staff_symbol") )?(1):(0);
        push @props, qq-e2god="$e2god"-;

        my $committer = $APP->inUsergroup($member, '%%', 'nogods');
        push @props, qq-committer="$committer"-;

        my $chanop = $APP->isChanop($member, 'nogods');
        push @props, qq-chanop="$chanop"-;

        my $ce = ($APP->isEditor($member,"nogods") && !$APP->isAdmin($USER) && !$APP->getParameter($member,"hide_chatterbox_staff_symbol") )?(1):(0);
        push @props, qq-ce="$ce"-;

        my $edev = ($APP->isDeveloper($member,"nogods")?(1):(0));
        push @props, qq-edev="$edev"-;

        my $xp = $$u{experience};
        push @props, qq-xp="$xp"-;

        my $borged = $$row{borgd};
        $borged ||=0;
        push @props, qq-borged="$borged"-;

        my $md5 = htmlcode('getGravatarMD5', $member);
        my $userTitle = encodeHTML($$u{title});

        $str .= '<user ' . join(' ', @props) . " >\n";
        $str .= qq-<e2link node_id="$$u{node_id}" md5="$md5">$userTitle</e2link>\n-;
        my $r = getNodeById($$row{room_id});
        if ($r) {
            my $roomTitle = encodeHTML($$r{title});
            $str .= qq-<room node_id="$$r{node_id}">$roomTitle</room>-;
        }
        $str .= "</user>\n";
    }

    $str .= "</otherusers>\n";
    return $str;
}

sub personal_session_xml_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<?xml version=\"1.0\"?>
<e2session>
";
    $str .= "<currentuser user_id=\"$$USER{user_id}\">".encodeHTML($$USER{title})."</currentuser>\n".
        "<servertime time=\"".scalar(time)."\">".asctime(localtime)."</servertime>";

    return $str . "
</e2session>" if $APP->isGuest($USER);

    my $catch = htmlcode('borgcheck');

    $str.="<borgstatus value=\"".(($$VARS{borged})?("1"):("0"))."\">".(($$VARS{borged})?("borged"):("unborged"))."</borgstatus>";

    my $rm = getNodeById($$USER{in_room});
    $str.="<in_room>".(($$USER{in_room} == 0)?(""):("<e2link node_id=\"$$rm{node_id}\">$$rm{title}</e2link>"))."</in_room>";

    $str.="<personalnodes>";
    foreach(split('<br>',$$VARS{personal_nodelet}))
    {
        next unless $_;
        $str.="<pn>".encodeHTML($_)."</pn>"
    }
    $str.="</personalnodes>";
    $str.=htmlcode("shownewexp", "TRUE,xml");
    $str.="<cools>".(($$VARS{cools})?($$VARS{cools}):("0"))."</cools>";
    $str.="<votesleft>$$USER{votesleft}</votesleft>";
    $str.="<karma>$$USER{karma}</karma>";
    $str.="<experience>$$USER{experience}</experience>";
    $str.="<numwriteups>".(($$VARS{numwriteups})?($$VARS{numwriteups}):("0"))."</numwriteups>";


    my $userlock = $DB->sqlSelectHashref('*', 'nodelock', "nodelock_node=$$USER{user_id}");
    $str.="<forbiddance>";
    $str.=encodeHTML($$userlock{nodelock_reason})if ($userlock);
    $str.="</forbiddance>";


    return $str . "
</e2session>";
}

sub podcast_rss_feed
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
    $str .= "<rss xmlns:itunes=\"http://www.itunes.com/dtds/podcast-1.0.dtd\" version=\"2.0\">";

    $str .= "\t<channel>\n";
    $str .= "\t\t<title>Everything2 Podcast</title>\n";
    $str .= "\t\t<description>Users of Everything2 read out writeups and maybe ramble a bit</description>\n";
    $str .= "\t\t<link>http://everything2.com/title/Podcaster</link>\n";

    $str .= "\t\t<language>en</language>\n"; # Reluctant to say en-us since it varies

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    $str .= "\t\t<copyright>Copyright ";


    $str.=strftime("%a, %d %b %Y %H:%M:%S %z", localtime(time()));
    $str.="</copyright>\n";


    $str .= "\t\t<lastBuildDate>";
    $str .= strftime("%a, %d %b %Y %H:%M:%S %z", localtime(time()));
    $str .= "</lastBuildDate>\n";

    $str .= "\t\t<pubDate>";
    $str .= strftime("%a, %d %b %Y %H:%M:%S %z", localtime(time())); # Not sure if this is quite what we want here?
    $str .= "</pubDate>\n"; # This and maybe also the previous should probably be from latest podcast node...

    $str .= "\t\t<docs>http://blogs.law.harvard.edu/tech/rss</docs>\n";
    $str .= "\t\t<webMaster>e2webmaster\@everything2.com</webMaster>\n";

    $str .= "\t\t<itunes:author>podpeople \@ Everything2</itunes:author>\n";
    $str .= "\t\t<itunes:subtitle>The E2 Podcast is a collection of nodes from everything2.com, read aloud by noders. </itunes:subtitle>\n";
    $str .= "\t\t<itunes:summary>The Everything2 Podcast is a collection of writeups from Everything2.com, read aloud by various volunteers from the E2 community.</itunes:summary>\n";
    $str .= "\t\t<itunes:owner>
\t\t\t<itunes:name>podpeople</itunes:name>
\t\t\t<itunes:email>podcast\@everything2.com</itunes:email>
\t\t</itunes:owner>\n";

    $str .= "\t\t<itunes:explicit>Yes</itunes:explicit>\n";
    $str .= "\t\t<itunes:image href=\"http://e2podcast.spunkotronic.com/images/podcastlogo.jpg\"/>\n"; # We should probably get this on-site really

    $str .= "\t\t<itunes:category text=\"Arts\">
\t\t\t<itunes:category text=\"Literature\"/>
\t\t</itunes:category>\n";


    # Begin proper code - as per [Podcaster]

    my $csr=$DB->sqlSelectMany ("link, title, podcast_id, pubDate AS UNIX_TIMESTAMP", "podcast JOIN node ON podcast_id = node_id", "1", "LIMIT 100");

    return unless $csr->rows;


    while (my $pod = $csr->fetchrow_hashref) {
        $str.="\n<item>
\t<title>$$pod{title}</title>
\t<link>http://everything2.com/node/$$pod{podcast_id}</link>
\t<guid>$$pod{link}</guid>
\t<description>";

        # From [atomiseNode]:
        my $text;
        my $HTML = getVars(getNode('approved HTML tags', 'setting'));
        my $full = 0;
        if (length($$pod{description}) < 1024) {
            $text = parseLinks($APP->htmlScreen($$pod{description}, $HTML));
            $full = 1;
        } else {
            $text = substr($$pod{description},0, 1024);
            $text =~ s/\s+\w*$//gs;
            $text = parseLinks($APP->htmlScreen($text, $HTML));
            $text =~ s/\[.*?$//;
        }
        $text = encodeHTML($text);


        $str.="$text</description>
\t<enclosure url=\"$$pod{link}\" type=\"audio/mpeg\"/>\n"; # Generate 'length'...?
        $str.="\t<category>Podcasts</category>\n";
        $str.="\t<pubDate>";
        $str.=strftime("%a, %d %b %Y %H:%M:%S %z",localtime($$pod{pubdate}));
        $str.="</pubDate>\n";
        $str.="</item>\n";

    }

    $str .= "</channel>\n</rss>";

    utf8::encode($str);
    return $str;
}

sub random_nodes_xml_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my @phrase = (
        'Nodes your grandma would have liked:',
        'After stirring Everything, these nodes rose to the top:',
        'Look at this mess the Death Borg made!',
        'Just another sprinking of indeterminacy',
        'The best nodes of all time:'
    );

    my $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
    $str.="
   <!DOCTYPE randomnodes [
     <!ELEMENT randomnodes (wit, e2link*)>\n
     <!ELEMENT wit (#PCDATA)>\n
     <!ELEMENT e2link (#PCDATA)>\n
        <!ATTLIST e2link node_id CDATA #REQUIRED> \n
   ]>

";

    $str.="<randomnodes>\n";
    $str.='<wit>'.$phrase[rand(int(@phrase))]."</wit>\n";

    my $randomnodes = $DB->stashData("randomnodes");

    foreach my $N (@$randomnodes) {
        $str.="  <e2link node_id=\"$$N{node_id}\">".encodeHTML($$N{title})."</e2link>\n";
    }

    $str.="</randomnodes>\n";
    return $str;
}

sub raw_vars_xml_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<vars>";

    unless($APP->isGuest($USER) ){
        my $ev = getVars(getNode("exportable vars","setting"));

        foreach(keys %$ev)
        {
            next unless $$VARS{$_};
            $str.="<key name=\"$_\">$$VARS{$_}</key>\n";
        }
    }

    $str.="</vars>";
    return $str;
}

sub time_since_xml_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str="<timesince>";


    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    $year+=1900;
    $mon+=1;

    $mon = sprintf("%02d", $mon);
    $mday = sprintf("%02d", $mday);
    $hour = sprintf("%02d", $hour);
    $min = sprintf("%02d", $min);
    $sec = sprintf("%02d", $sec);

    my $now = "$year-$mon-$mday $hour:$min:$sec";
    my @users;

    if($query->param("user"))
    {
        push @users, getNode($_, "user") foreach(split(',',$query->param("user")));
    }elsif($query->param("user_id"))
    {
        push @users, getNodeById($_) foreach(split(",",$query->param("user_id")));
    }else
    {
        @users = ($USER);
    }

    $str.="<now>$now</now>\n";
    $str.="<lasttimes>\n";
    foreach(@users){
        next unless($_ and $$_{type}{title} eq "user");
        $str.="<user lasttime=\"$$_{lasttime}\">\n<e2link node_id=\"$$_{node_id}\">$$_{title}</e2link>\n</user>";
    }
    $str.="</lasttimes>\n";
    $str.="</timesince>";
    return $str;
}

sub universal_message_xml_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $msglimit = int($query->param("msglimit")); # to prevent against nasty SQL injection attacks. mkb thanks call
    if ($msglimit !~ /^[0-9]*$/)
    {
        $msglimit = 0;
    }

    my $for_node = $query->param("for_node");
    my $backtime = $query->param("backtime");
    my $nosort = $query->param("nosort");
    my $lnp = $query->param("links_noparse");

    $for_node = $$USER{user_id} if ($for_node eq "me");

    $nosort ||= 0;
    $for_node ||= 0;
    $msglimit ||= 0; #not actually necessary due to call's fix above, but better safe than sorry -- tmw
    $backtime ||= 0;
    my $recip = getNodeById($for_node);

    if ($for_node == 0)
    {
        $$recip{type_nodetype} = getId(getType('room'));
        $$recip{node_id} = 0;
        $$recip{title} = "outside";
        $$recip{criteria} = "1;";
    }

    my $limits = "";
    my $secs;
    my $room;
    my $messages = {};

    if ($$recip{type_nodetype} == getId(getType('room')))
    {
        if ($APP->canEnterRoom($recip, $USER, $VARS)
            and ((!$APP->isGuest($USER))
            or getVars(getNode("public rooms", "setting"))->{$$recip{node_id}})
            )
        {
            $room = getVars(getNode("room topics", "setting"));
            my $topic = $$room{$$recip{node_id}};
            unless ($lnp == 1)
            {
                if ($query->param('do_the_right_thing'))
                {
                    $topic = $APP->escapeAngleBrackets($topic);
                }
                $topic = parseLinks($topic);
            }

            $messages -> {room} = {room_id => $$recip{node_id},
                                content => $$recip{title}
                                };

            $messages -> {topic} = {content => $topic};

            if ($backtime != 5 && $backtime != 10)
            {
                $backtime = 5;
            }

            $secs = $backtime * 60;

            if ($$USER{in_room} == $$recip{node_id} || $$USER{user_id} == getId(getNode("Guest User", "user")))
            {
                # Use interval here to avoid a table scan -- [call]
                $limits = "message_id > $msglimit AND room='$$recip{node_id}' AND for_user='0'"
                    . " AND tstamp >= date_sub(now(), interval $secs second)";
            }
            else
            {
                $limits = "";
            }
        }
    }
    elsif ($$recip{type_nodetype} == getId(getType('user')))
    {
        $secs = $backtime * 60;

        if ($$USER{user_id} == $$recip{node_id})
        {
            $limits = "message_id > $msglimit AND for_user='$$USER{user_id}' AND room='0'";
            # Avoid a table scan here, too. -- [call]
            $limits.= " AND tstamp >= date_sub(now(), interval $secs second)" if($secs > 0);
        }
        else
        {
            $limits = "";
        }
    }

    $limits .=" ORDER BY message_id" unless($nosort == 1 || $limits eq "");
    $limits = " message_id is NULL LIMIT 0" if($limits eq "");
    my $csr = $DB->sqlSelectMany("*", "message use index(foruser_tstamp)", $limits);

    my $gu = getNode("Guest User", "user");
    my $username;
    my $costume;
    my $msglist = [];

    unless ($$recip{node_id} == $$gu{node_id})
    {
        while (my $row = $csr->fetchrow_hashref())
        {
            my $msg = {};
            $msg -> {msg_id} = $$row{message_id};
            $msg -> {msg_time} = $$row{tstamp};
            $msg -> {archive} = 1 if($$row{archive} == 1);

            my $frm=getNodeById($$row{author_user});
            my $grp=getNodeById($$row{for_usergroup});
            $username = $$frm{title};

            if (htmlcode('isSpecialDate','halloween') && $room)
            {
                $costume = '';
                $costume = getVars($frm)->{costume} if (getVars($frm)->{costume});
                $costume =~ s/\t//g;

                if ($costume gt '')
                {
                    $username = $costume;
                }
            }

            #properly encode usernames
            utf8::encode($username);

            if($frm)
            {
                #This weird way of putting the form data is because we're using
                #<from> tags without any attributes, and XML::Simple will only
                #allow this for grouping tags.
                my $frmdata = [];
                my $md5 = htmlcode('getGravatarMD5', $frm);
                push @$frmdata, {node_id => $$frm{node_id},
                            content => $username,
                            md5 => $md5
                            };
                $msg -> {from} = $frmdata;
            }

            if($grp)
            {
                $msg -> {grp} = {type    => $$grp{type}{title},
                            e2link  => {node_id => $$grp{node_id},
                                        content => $$grp{title}
                                        },
                            };
            }

            my $txt = encodeHTML($$row{msgtext});
            unless ($lnp == 1)
            {
                $txt = parseLinks($txt);
            }

            $msg -> {txt} = {content => $txt};
            push @$msglist,  $msg;
        }
    }

    $messages -> {msglist} = { msg => $msglist };

    # For reason behind options, see
    # http://perldesignpatterns.com/?XmlSimple, as well as the XML::Simple
    # documentation.

    my $xmls = XML::Simple->new(
        RootName => undef,
        KeepRoot => 1,
        ForceArray => 1,
        ForceContent => 1,
        XMLDecl => 1,
        GroupTags => {from => 'e2link'}, #Hack to get <from> tags without attributes
    );
    my $xml = $xmls -> XMLout({"messages" => $messages});
    return $xml;
}

sub user_search_xml_ticker_ii
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<?xml version=\"1.0\"?>\n";

    my $searchuser = $query->param("searchuser");
    $searchuser = getNode($searchuser, "user") if defined($searchuser);
    $searchuser ||= $USER;
    my $startat = $query->param("startat");
    $startat ||= "0";
    $startat =~ s/[^\d]//g;
    my $limit;
    $limit = $query->param("count");
    $limit ||= "50";
    $limit =~ s/[^\d]//g;
    $limit = " LIMIT $startat,$limit ";
    $limit = "" if $query->param("nolimit");

    my $o = " ORDER BY ";

    my $sortchoices = {
        'rep' => "$o reputation DESC",
        'rep_asc' => "$o reputation",
        'title' => "$o title",
        'creation' => "$o publishtime DESC",
        'creation_asc' => "$o publishtime",
        'publication' => "$o publishtime DESC",
        'publication_asc' => "$o publishtime"
    };
    my $sort = $$sortchoices{$query->param("sort")};
    $sort ||= $$sortchoices{creation};
    $sort = "" if $query->param("nosort");

    my $wuCount = $DB->sqlSelect('count(*)','node',
        "author_user=$$searchuser{node_id} AND type_nodetype=117");

    my $nr = getId(getNode("node row", "oppressor_superdoc"));

    my $csr = $DB->sqlSelectMany("node_id", "node JOIN writeup ON node_id=writeup_id",
        "author_user=$$searchuser{node_id} $sort $limit");

    $str.='<usersearch user="'.encodeHTML($$searchuser{title}).'" writeupCount="'.$wuCount.'">';

    while(my $row = $csr->fetchrow_hashref)
    {
        my $n = getNodeById($$row{node_id});
        next unless $n;
        my $parent = getNodeById($$n{parent_e2node});
        my @props;
        my $ct = $$n{publishtime};
        push @props, "createtime=\"$ct\"";

        my $marked = (($DB->sqlSelect('linkedby_user', 'weblog', "weblog_id=$nr and to_node=$$n{node_id}")?(1):(0)));
        push @props, "marked=\"$marked\"" if($$searchuser{node_id} == $$USER{node_id});

        my $hidden = $$n{notnew};
        $hidden ||= 0;
        push @props, "hidden=\"$hidden\"" if($$searchuser{node_id} == $$USER{node_id});

        my $c = $DB->sqlSelect("count(*)", "coolwriteups", "coolwriteups_id=$$n{node_id}");
        $c ||= 0;

        push @props, "cools=\"$c\"";

        my $wrtype = getNodeById($$n{wrtype_writeuptype});
        push @props, "wrtype=\"$$wrtype{title}\"";

        my $up = $DB->sqlSelect("count(*)", "vote", "vote_id=$$n{node_id} AND weight=1");
        my $down = $DB->sqlSelect("count(*)", "vote", "vote_id=$$n{node_id} AND weight=-1");
        $str.="<wu ".join(" ", @props).">";
        $str.="<rep up=\"$up\" down=\"$down\">$$n{reputation}</rep>" if($$searchuser{node_id} == $$USER{node_id});
        $str.="<e2link node_id=\"$$n{node_id}\">".encodeHTML($$n{title})."</e2link>";
        $str.="<parent>";
        $str.="<e2link node_id=\"$$parent{node_id}\">".encodeHTML($$parent{title})."</e2link>";
        $str.="</parent>";
        $str.="</wu>";
    }
    $str.="</usersearch>";

    return $str;
}

sub xml_interfaces_ticker
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<?xml version=\"1.0\" ?>";
    $str.="<xmlcaps>\n";
    $str.="<this node_id=\"$$NODE{node_id}\">$$NODE{title}</this>\n";
    my $ifaces = getVars(getNode("XML exports", "setting"));

    foreach(keys %$ifaces)
    {
        my $i = $_;
        my $n = getNodeById($$ifaces{$i});

        $str.=" <xmlexport iface=\"$i\" node_id=\"$$n{node_id}\">".encodeHTML($$n{title})."</xmlexport>\n";
    }

    $str.="</xmlcaps>";
    return $str;
}

#############################################################################
# universal_message_json_ticker
#
# Chatterbox JSON message ticker for fetching room/private messages
# Migrated from jsonexport node (2025-11-20)
#############################################################################

sub universal_message_json_ticker
{
    my $DB = shift;
    my $query = shift;
    my $NODE = shift;
    my $USER = shift;
    my $VARS = shift;
    my $PAGELOAD = shift;
    my $APP = shift;

    my $msglimit = int($query->param("msglimit")); # to prevent against nasty SQL injection attacks. mkb thanks call
    if ($msglimit !~ /^[0-9]*$/)
    {
        $msglimit = 0;
    }

    my $for_node = $query->param("for_node");
    my $backtime = $query->param("backtime");
    my $nosort = $query->param("nosort");
    my $lnp = $query->param("links_noparse");

    $for_node = $$USER{user_id} if ($for_node eq "me");

    $nosort ||= 0;
    $for_node ||= 0;
    $msglimit ||= 0; #not actually necessary due to call's fix above, but better safe than sorry -- tmw
    $backtime ||= 0;
    my $recip = getNodeById($for_node);

    if ($for_node == 0)
    {
        $$recip{type_nodetype} = getId(getType('room'));
        $$recip{node_id} = 0;
        $$recip{title} = "outside";
        $$recip{criteria} = "1;";
    }

    my $limits = "";
    my $secs;
    my $room;
    my $messages = {};

    if ($$recip{type_nodetype} == getId(getType('room')))
    {
        # Check room access using delegation instead of eval()
        my $roomTitle = $$recip{title} || '';
        $roomTitle =~ s/[\s\-]/_/g;  # Replace spaces and hyphens with underscores
        $roomTitle = lc($roomTitle);

        my $hasAccess = 1;  # Default to allow (public room)

        # Check if room has delegation function for access control
        my $roomDelegation = Everything::Delegation::room->can($roomTitle);
        if ($roomDelegation)
        {
            $hasAccess = $roomDelegation->($USER, $VARS, $APP);
        }

        if ($hasAccess
            and (!$APP->isGuest($USER)
            || getVars(getNode("public rooms", "setting"))->{$$recip{node_id}})
            )
        {
            $room = getVars(getNode("room topics", "setting"));
            my $topic = $$room{$$recip{node_id}};
            unless ($lnp == 1)
            {
                if ($query->param('do_the_right_thing'))
                {
                    $topic = $APP->escapeAngleBrackets($topic);
                }
                $topic = parseLinks($topic);
            }

            $messages -> {room} = {room_id => $$recip{node_id},
                                   content => $$recip{title}
                                  };

            $messages -> {topic} = {content => $topic};

            if ($backtime != 5 && $backtime != 10)
            {
                $backtime = 5;
            }

            $secs = $backtime * 60;

            if ($$USER{in_room} == $$recip{node_id} || $APP->isGuest($USER))
            {
                # Use interval here to avoid a table scan -- [call]
                $limits = "message_id > $msglimit AND room='$$recip{node_id}' AND for_user='0'"
                        . " AND tstamp >= date_sub(now(), interval $secs second)";
            }
            else
            {
                $limits = "";
            }
        }
    }
    elsif ($$recip{type_nodetype} == getId(getType('user')))
    {
        $secs = $backtime * 60;

        if ($$USER{user_id} == $$recip{node_id})
        {
            $limits = "message_id > $msglimit AND for_user='$$USER{user_id}' AND room='0'";
            # Avoid a table scan here, too. -- [call]
            $limits.= " AND tstamp >= date_sub(now(), interval $secs second)" if($secs > 0);
        }
        else
        {
            $limits = "";
        }
    }

    $limits .=" ORDER BY message_id" unless($nosort == 1 || $limits eq "");
    $limits = " message_id is NULL LIMIT 0" if($limits eq "");
    my $csr = $DB->sqlSelectMany("*", "message use index(foruser_tstamp)", $limits);

    my $username;
    my $costume;
    my $msglist = [];

    unless ($APP->isGuest($$recip{node_id}))
    {
        while (my $row = $csr->fetchrow_hashref())
        {
            my $msg = {};
            $msg -> {msg_id} = $$row{message_id};
            $msg -> {msg_time} = $$row{tstamp};
            $msg -> {archive} = 1 if($$row{archive} == 1);

            my $frm=getNodeById($$row{author_user});
            my $grp=getNodeById($$row{for_usergroup});
            $username = $$frm{title};


            #properly encode usernames
            utf8::encode($username);

            if($frm)
            {

                my $frmdata = [];
                push @$frmdata, {node_id => $$frm{node_id},
                                 content => $username,
                                };
                $msg -> {from} = $frmdata;
            }

            if($grp)
            {
                $msg -> {grp} = {type    => $$grp{type}{title},
                                 e2link  => {node_id => $$grp{node_id},
                                             content => $$grp{title}
                                            },
                                };
            }

            my $txt = $$row{msgtext};
            if($lnp != 1) {
                $txt = parseLinks($txt);
            }

            $msg -> {txt} = {content => $txt};
            push @$msglist,  $msg;
        }
    }

    $messages -> {msglist} = { msg => $msglist };

    return encode_json({"messages" => $messages});
}

1;
