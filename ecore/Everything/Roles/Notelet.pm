package Everything::Roles::Notelet;

use Moose::Role;

# Shared notelet logic (#4479, Refs #4298). The pure-render Everything::Page::notelet_editor and
# the mutating Everything::API::notelet both compute the level-based max length + the display
# payload the same way, and the API's save/castrate writes live here so the page stays render-only.
#
# Consumers must provide APP() (Everything::Page and Everything::API both do, via Globals).
requires qw(APP);

# The Notelet nodelet's node_id -- notelet_enabled checks the user's nodelet list for it.
use constant NOTELET_NODELET_ID => 1290534;
# Hard cap on the raw source we store (matches the old buildReactData + the React maxLength).
use constant NOTELET_RAW_CAP => 32768;

# Level-based cap on how much of the raw text is *displayed* (screened). Extracted verbatim
# from the old Everything::Page::notelet_editor buildReactData.
sub notelet_max_length {
    my ($self, $user_nodedata) = @_;
    my $APP = $self->APP;

    my $max = ($APP->getLevel($user_nodedata) || 0) * 100;
    $max = 1000 if $max > 1000;
    $max = 500  if $max < 500;

    # Power users get more (order matters: admins first, since is_editor includes admins).
    if    ($APP->isAdmin($user_nodedata))     { $max = 32768; }
    elsif ($APP->isEditor($user_nodedata))    { $max += 100; }
    elsif ($APP->isDeveloper($user_nodedata)) { $max = 16384; }

    return $max;
}

# Strip <script> tags from raw text (XSS / JSON-injection guard); mirrors the client + the
# old page's server-side strip.
sub _strip_scripts {
    my ($self, $text) = @_;
    $text //= '';
    $text =~ s/<script[^>]*>.*?<\/script>//gis;
    $text =~ s/<script[^>]*>//gis;
    $text =~ s/<\/script>//gis;
    return $text;
}

# The read-only display payload -- used by the pure-render page AND returned by the API after a
# write so the client always re-renders from one shape.
sub notelet_payload {
    my ($self, $user) = @_;
    my $VARS = $user->VARS;

    my $raw      = $self->_strip_scripts($VARS->{noteletRaw} || '');
    my $screened = $VARS->{noteletScreened} || '';

    return {
        notelet_raw      => $raw,
        notelet_screened => $screened,
        char_count       => length($raw),
        max_length       => $self->notelet_max_length($user->NODEDATA),
        user_level       => $self->APP->getLevel($user->NODEDATA) || 0,
        notelet_enabled  => (index($VARS->{nodelets} || '', NOTELET_NODELET_ID) >= 0) ? 1 : 0,
        keep_comments    => $VARS->{nodeletKeepComments} ? 1 : 0,
    };
}

# Save the notelet source (the old ?makethechange write). Applies the level cap, handles the
# legacy personalRaw migration + the keep-comments flag, screens, and persists. Returns a
# truncation error string ('' if none).
sub save_notelet {
    my ($self, $user, $notelet_source, $keep_comments) = @_;
    my $APP  = $self->APP;
    my $VARS = $user->VARS;
    my $error = '';

    # Legacy personalRaw -> noteletRaw migration.
    $VARS->{noteletRaw} = $VARS->{personalRaw} if exists $VARS->{personalRaw};
    delete $VARS->{personalRaw};

    if ($keep_comments) { $VARS->{nodeletKeepComments} = 1; }
    else                { delete $VARS->{nodeletKeepComments}; }

    if (!defined $notelet_source || !length($notelet_source)) {
        delete $VARS->{noteletRaw};
    } else {
        $notelet_source = substr($notelet_source, 0, NOTELET_RAW_CAP)
            if length($notelet_source) > NOTELET_RAW_CAP;

        my $max = $self->notelet_max_length($user->NODEDATA);
        if (length($notelet_source) > $max) {
            $notelet_source = substr($notelet_source, 0, $max);
            $error = "Content was truncated to $max characters.";
        }
        $VARS->{noteletRaw} = $notelet_source;
    }

    # Screen (length-limit, strip comments/scripts) then persist.
    $APP->screen_notelet($user->NODEDATA, $VARS);
    $user->set_vars($VARS);

    return $error;
}

# Castrate the notelet (the old ?YesReallyCastrate write): comment out every line of JS, clear
# the screened copy, persist. Idempotent (#4479): an empty notelet stays empty, blank lines are
# left alone, and already-commented lines are not re-commented -- so repeated castration no
# longer keeps dumbly prepending '// ' markers.
sub castrate_notelet {
    my ($self, $user) = @_;
    my $VARS = $user->VARS;

    my $raw = defined $VARS->{noteletRaw} ? $VARS->{noteletRaw} : '';

    my @lines = split /\n/, $raw, -1;
    for my $line (@lines) {
        next unless $line =~ /\S/;       # leave blank lines empty
        next if     $line =~ m{^\s*//};  # already commented -> don't re-comment
        $line = '// ' . $line;
    }
    $raw = join "\n", @lines;

    $VARS->{noteletRaw}      = $raw;
    $VARS->{noteletScreened} = '';
    $user->set_vars($VARS);

    return;
}

1;
