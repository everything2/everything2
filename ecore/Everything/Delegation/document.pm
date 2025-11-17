package Everything::Delegation::document;

use strict;
use warnings;

# Used in: advanced_settings, settings
use DateTime;

# Used in: findings_
use Time::HiRes;

BEGIN {
    *getNode       = *Everything::HTML::getNode;
    *getNodeById   = *Everything::HTML::getNodeById;
    *getVars       = *Everything::HTML::getVars;
    *getId         = *Everything::HTML::getId;
    *urlGen        = *Everything::HTML::urlGen;
    *linkNode      = *Everything::HTML::linkNode;
    *htmlcode      = *Everything::HTML::htmlcode;
    *parseCode     = *Everything::HTML::parseCode;
    *parseLinks    = *Everything::HTML::parseLinks;
    *isNodetype    = *Everything::HTML::isNodetype;
    *getRef        = *Everything::HTML::getRef;
    *insertNodelet = *Everything::HTML::insertNodelet;
    *getType       = *Everything::HTML::getType;
    *updateNode    = *Everything::HTML::updateNode;
    *setVars       = *Everything::HTML::setVars;
    *linkNodeTitle = *Everything::HTML::linkNodeTitle;
    *canUpdateNode = *Everything::HTML::canUpdateNode;
    *updateLinks   = *Everything::HTML::updateLinks;
    *canReadNode   = *Everything::HTML::canReadNode;
    *encodeHTML    = *Everything::HTML::encodeHTML;
}

# Used by e2_sperm_counter
use POSIX qw(ceil);

# Used by your_gravatar, recent_users
use Digest::MD5;

# Used by Log Archive
use DateTime;

# Used by Node Backup
use Everything::S3;
use IO::Compress::Zip;
use utf8;

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
        and $DB->isGod($USER) )
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
    #	60*60*24*365*100=3153600000=100 years ago, 365 days/year
    #	60*60*24*25=2160000=25 extra leap days; adjustment to 26: Feb 29, 2004
    #week in future:
    #	60*60*24*7=604800=week

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

    $str .= '</table><p style="text-align:right">Bugs to [in10se]</p>';

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
        and not $DB->isGod($USER)
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
        $NODE = $Everything::HTML::GNODE =
          getNodeById( $Everything::CONF->not_found_node );
        return parseCode( $$NODE{doctext} );
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

    $text .=
        "<table border='1' width='100%' cellpadding='3'>"
      . "<tr><th>Node</th><th>Time</th><th>Linker</th>"
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
        #	next if $protected{$row -> {node_id}};
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
  my $types = [qw(superdoc restricted_superdoc superdocnolinks oppressor_superdoc fullpage htmlcode htmlpage nodelet)];

  foreach my $type (@$types)
  {
    my $nt = getType($type);
    my $csr = $DB->sqlSelectMany('node_id','node LEFT JOIN document on node.node_id=document.document_id',"type_nodetype=$nt->{node_id} AND doctext IS NOT NULL AND doctext!=''");
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
    my $isRoot = $DB->isGod($USER);
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

    if($DB->isGod($USER))
    {
        $str .= q|For noder: |.$query->textfield(-name => 'for_noder').q| <em>(admin only)</em><br />|;
    }
	$str .= htmlcode('closeform', 'Create backup');
    return $str unless $query->param('sexisgood');

    my $e2parse = $query->param('e2parse');
    my $targetNoder = undef;

    if ($query->param('for_noder') && $DB->isGod($USER)) {
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

            #	' LIMIT 1,50'  #comment this out after debug
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
    #	user, e2node, writeup - a zillion of them
    #	ditto, plus privacy
    #	restricted_superdoc - admins only
    #	bug - ?
    #	oppressor_superdoc - editors only
    #	debate, debatecomment - like writeups/e2nodes - eventually a zillion of them

    my %skips;
    @skips{qw(user e2node writeup draft)} = ();    #later filter useralias
    delete $skips{'user'}
        if $USER->{node_id} == 9740 || 1306028 || 1390290
        ;    #2005 August new user create bug - N-Wing wants easy way to get these
             #and Two Sheds and Wiccanpiper wanted to list users for other reasons.

    #not sure about collaboration - is that supposed to be a group private thing, or public thing that only certain people can edit?

    if ($isRoot)
    {
        #	@skips{qw()} = ();
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
        #	next unless canReadNode($USER, getNode($nid));

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

            #		'chosen_type'=>$selection,	#stored in VARS now
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
    use Everything::FormMenu;

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

    # Disable parseCode link parsing
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
    $str .= <<'END_HTML';
<p align="right">Last updated Thursday March 21, 2002</p>
<!--
  This is mblase's edevdoc. Howdy.
  All JavaScript code is copyright 2000 by me.
  Please /msg with any changes, suggestions, etc.
-->
<p>
This is intended to be the E2 Text Formatter to end all Text Formatters.
It will [E2 Paragraph Tagger|insert paragraphs].
It will [Wharfinger's Linebreaker|insert line breaks].
It will [E2 Source Code Formatter|escape special characters].
It will [E2 List Formatter|format lists of items].
And it will add styles, interpret horizontal rules,
and indent using the markup tags of your choice,
all thanks to the power of [regular expression|regular expressions].
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
<a href="#" onClick="return clearBox()">Clear the box</a>
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
    Convert &#91;brackets&#93; to HTML symbols<br />
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
    if (myradio.checked) { text = addStyles("\\/", myradio.value, text); }
  }
  for (var i=0; i<myform.starred.length; i++) {
    var myradio = getRadio("starred", i);
    if (myradio.checked) { text = addStyles("\\*", myradio.value, text); }
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
    if (myradio.checked) { text = addGenericList(ob+"\\*\\."+cb+" ", "li", myradio.value, text); }
  }
  for (var i=0; i<myform.dashlist.length; i++) {
    var myradio = getRadio("dashlist", i);
    if (myradio.checked) { text = addGenericList("\\-\\-?", "li", myradio.value, text); }
  }
  for (var i=0; i<myform.numberlist.length; i++) {
    var myradio = getRadio("numberlist", i);
    if (myradio.checked) { text = addGenericList("\\d+"+ob+"\\.\\) "+cb, "li", myradio.value, text);}
  }
  for (var i=0; i<myform.indent.length; i++) {
    var myradio = getRadio("indent", i);
    if (myradio.checked) { text = addGenericList("(\\t+|  +) *", "", myradio.value, text); }
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
  var reg1 = new RegExp("\\"+ob+"("+ob+"^\\|\\"+cb+cb+"*)"+"|"+"("+ob+"^\\"+cb+cb+"*)\\"+cb, "g"); // pipe link
  var reg2 = new RegExp("\\"+ob+"("+ob+"^\\"+cb+cb+"*)\\"+cb, "g");   // hard link
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
    str = str.replace(reg, "&#"+i+";");
  }
  return str;
}
// replace brackets with HTML-safe characters
function encodeBrackets(str) {
  var reg1 = new RegExp("\\"+ob, "g");
  var reg2 = new RegExp("\\"+cb, "g");
  str = str.replace(reg1, "&#91;");
  str = str.replace(reg2, "&#93;");
  return str;
}
// create <hr> tags from ASCII rules
function addHorizRule(str) {
  var reg1 = new RegExp("(<p>|\\n<br \\/>)?\\n"+ob+" \\t"+cb+"*"+ob+"\\-_="+cb+"{5,}"+ob+" \\t"+cb+"*(\\n<\\/p>|<br \\/>\\n|\\n)?", "g");
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
  var reg1 = new RegExp("\\n\\s*"+match+"\\s*", "g");
  str = str.replace(reg1, listtag);
  var reg2 = new RegExp("^\\s*"+match+"\s*", "g");
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
</script>
END_HTML

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
    $str .= '</p>

<p align="right"><small>(bugs to ' . linkNode( getNode( 'N-Wing', 'user' ) ) . ')</small></p>';

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

1;
