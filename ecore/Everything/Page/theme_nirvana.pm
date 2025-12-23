package Everything::Page::theme_nirvana;

use Moose;
extends 'Everything::Page';

# Theme Nirvana - displays popular stylesheets
# Migrated from Everything::Delegation::document::theme_nirvana

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;
    my $VARS = $REQUEST->user->VARS;
    my $query = $REQUEST->cgi;

    my $is_guest = $APP->isGuest($USER);

    # Handle clear vandalism (custom style reset)
    if (defined($query->param('clearVandalism'))) {
        delete($VARS->{customstyle});
        $APP->setVars($USER, $VARS);
    }

    # Get user's current style
    my $userstyle_id = $VARS->{userstyle} || 0;
    my $userstyle_node;
    if ($userstyle_id) {
        $userstyle_node = $DB->getNodeById($userstyle_id);
    }

    my $current_style = undef;
    if ($userstyle_node) {
        $current_style = {
            node_id => $userstyle_node->{node_id},
            title => $userstyle_node->{title}
        };
    }

    my $has_custom_style = length($VARS->{customstyle} || '') > 0;

    # Get popular stylesheets - same logic as original delegation
    # Only show themes for "active" users (lastseen within 6 months)
    my ($sec, $min, $hour, $mday, $mon, $year) = gmtime(time - 15778800); # 365.25*24*3600/2
    my $cutoffDate = ($year + 1900) . '-' . ($mon + 1) . "-$mday";

    my $default_style_node = $DB->getNode($Everything::CONF->default_style, "stylesheet");
    my $default_style_id = $default_style_node ? $default_style_node->{node_id} : 0;

    # Count style usage
    my %styles;

    my $rows = $DB->sqlSelectMany('setting.setting_id,setting.vars',
        'setting,user',
        "setting.setting_id=user.user_id
            AND user.lasttime>='$cutoffDate'
            AND setting.vars LIKE '%userstyle=%'
            AND setting.vars NOT LIKE '%userstyle=$default_style_id%'");

    while (my $dbrow = $rows->fetchrow_arrayref) {
        if ($dbrow->[1] =~ m/userstyle=([0-9]+)/) {
            $styles{$1} = ($styles{$1} || 0) + 1;
        }
    }
    $rows->finish;

    # Sort by popularity and prepend default
    my @keys = sort { $styles{$b} <=> $styles{$a} } (keys %styles);
    unshift(@keys, $default_style_id);

    # Mark default with special count
    $styles{$default_style_id} = '[default]';

    # Build stylesheets list
    my @stylesheets;
    for my $style_id (@keys) {
        my $n = $DB->getNodeById($style_id);
        next unless $n;

        my $author = $DB->getNodeById($n->{author_user});
        my $user_count = $styles{$style_id};

        push @stylesheets, {
            node_id => $n->{node_id},
            title => $n->{title},
            author => $author ? {
                node_id => $author->{node_id},
                title => $author->{title}
            } : undef,
            user_count => $user_count
        };
    }

    return {
        type => 'theme_nirvana',
        stylesheets => \@stylesheets,
        current_style => $current_style,
        has_custom_style => $has_custom_style ? 1 : 0,
        is_guest => $is_guest ? 1 : 0
    };
}

__PACKAGE__->meta->make_immutable;
1;
