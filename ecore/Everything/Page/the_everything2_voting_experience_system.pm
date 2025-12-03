package Everything::Page::the_everything2_voting_experience_system;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::the_everything2_voting_experience_system

React page for the E2 Voting/Experience System help document.

Explains how voting, XP, GP, and leveling work on Everything2.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;

    # Get level range parameters (default to 0-12)
    my $fstLvl = int($REQUEST->param('fstlevel') || 0);
    my $sndLvl = int($REQUEST->param('sndlevel') || 12);

    # Limit to 100 levels max
    if (($sndLvl - $fstLvl) > 99) {
        $sndLvl = $fstLvl + 99;
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
            $level_data->{xp} = $EXP->{$i} || 0;
            $level_data->{writeups} = $WRP->{$i} || 0;
            $level_data->{votes} = $VTS->{$i} || 0;
            $level_data->{cools} = $C->{$i} || 0;
        }
        else {
            # Transcendent levels (100+)
            $level_data->{title} = 'Transcendent';
            $level_data->{xp} = $i * 2500 - 30000;
            $level_data->{writeups} = $i * 5;
            $level_data->{votes} = 50;
            $level_data->{cools} = $C->{100} || 0;
        }

        push @levels, $level_data;
    }

    return {
        type => 'voting_experience_system',
        levels => \@levels,
        first_level => $fstLvl,
        second_level => $sndLvl,
        user_level => $userLevel
    };
}

__PACKAGE__->meta->make_immutable;

1;
