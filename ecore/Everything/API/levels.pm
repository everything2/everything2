package Everything::API::levels;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 Everything::API::levels

API for retrieving user level information.

=cut

sub routes
{
    return {
        "get_levels" => "get_levels"
    };
}

=head2 get_levels

Get level data for a specified range.

GET /api/levels/get_levels?first_level=0&second_level=12

Returns level titles, XP requirements, writeup requirements, votes, and cools.

=cut

sub get_levels
{
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;

    # Get level range parameters (default to 0-12)
    my $fstLvl = int($REQUEST->param('first_level') || 0);
    my $sndLvl = int($REQUEST->param('second_level') || 12);

    # Limit to 100 levels max
    if (($sndLvl - $fstLvl) > 99) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Cannot display more than 100 levels at a time. Please choose fewer levels.'
        }];
    }

    # Get level settings from database
    my $EXP = $APP->getVars($DB->getNode('level experience', 'setting'));
    my $WRP = $APP->getVars($DB->getNode('level writeups', 'setting'));
    my $VTS = $APP->getVars($DB->getNode('level votes', 'setting'));
    my $C = $APP->getVars($DB->getNode('level cools', 'setting'));
    my $TTL = $APP->getVars($DB->getNode('level titles', 'setting'));

    my $userLevel = $APP->getLevel($USER);

    # Build level data array
    my @levels;
    for (my $i = $fstLvl; $i <= $sndLvl; $i++) {
        my $level_data = {
            level => $i,
            is_user_level => ($i == $userLevel) ? 1 : 0
        };

        if ($i < -3) {
            # Archdemon levels
            $level_data->{title} = 'Archdemon';
            $level_data->{xp} = 1000000 * $i;
            $level_data->{writeups} = 0;
            $level_data->{votes} = 10000;
            $level_data->{cools} = 1000;
        }
        elsif ($i == -3) {
            $level_data->{title} = 'Demon';
            $level_data->{xp} = -3000000;
            $level_data->{writeups} = 0;
            $level_data->{votes} = 1000;
            $level_data->{cools} = 100;
        }
        elsif ($i == -2) {
            $level_data->{title} = 'Master Arcanist';
            $level_data->{xp} = -2000000;
            $level_data->{writeups} = 0;
            $level_data->{votes} = 500;
            $level_data->{cools} = 50;
        }
        elsif ($i == -1) {
            $level_data->{title} = 'Arcanist';
            $level_data->{xp} = -1000000;
            $level_data->{writeups} = 0;
            $level_data->{votes} = 'NONE';
            $level_data->{cools} = 'NONE';
        }
        elsif ($i < 100) {
            # Normal levels (0-99)
            $level_data->{title} = $TTL->{$i} || '';
            # Use numeric check to avoid warnings on 'NONE' string values in settings
            my $xp_val = $EXP->{$i};
            my $wrp_val = $WRP->{$i};
            my $vts_val = $VTS->{$i};
            my $c_val = $C->{$i};
            $level_data->{xp} = (defined $xp_val && $xp_val =~ /^-?\d+$/) ? int($xp_val) : 0;
            $level_data->{writeups} = (defined $wrp_val && $wrp_val =~ /^-?\d+$/) ? int($wrp_val) : 0;
            $level_data->{votes} = (defined $vts_val && $vts_val =~ /^-?\d+$/) ? int($vts_val) : $vts_val || 0;
            $level_data->{cools} = (defined $c_val && $c_val =~ /^-?\d+$/) ? int($c_val) : $c_val || 0;
        }
        else {
            # Transcendent levels (100+)
            $level_data->{title} = 'Transcendent';
            $level_data->{xp} = $i * 2500 - 30000;
            $level_data->{writeups} = $i * 5;
            $level_data->{votes} = 50;
            $level_data->{cools} = int($C->{100} || 0);
        }

        push @levels, $level_data;
    }

    return [$self->HTTP_OK, {
        success => 1,
        levels => \@levels,
        first_level => $fstLvl,
        second_level => $sndLvl,
        user_level => $userLevel
    }];
}

__PACKAGE__->meta->make_immutable;

1;
