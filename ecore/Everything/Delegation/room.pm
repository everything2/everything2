package Everything::Delegation::room;

use strict;
use warnings;

# Valhalla - Gods/admins only
# Note: Admins are allowed by canEnterRoom before delegation is called
sub valhalla
{
    my ( $USER, $VARS, $APP ) = @_;

    return 0;
}

# Political Asylum - Open to all (no delegation needed, falls back to default allow)

# Debriefing Room - Chanops only
sub debriefing_room
{
    my ( $USER, $VARS, $APP ) = @_;

    return 0 unless $APP->inUsergroup( $USER->{user_id}, 'chanops' );
    return 1;
}

# M-Noder Washroom - Users with 1000+ writeups
# Note: Admins are allowed by canEnterRoom before delegation is called
sub m_noder_washroom
{
    my ( $USER, $VARS, $APP ) = @_;

    my $numwr = undef;

    $numwr = $VARS->{numwriteups} || 0;
    return 0 unless $numwr >= 1000;
    return 1;
}

# Noders Nursery - New users (level 3 and below) or high level (6+) or editors
sub noders_nursery
{
    my ( $USER, $VARS, $APP ) = @_;

    my $level = undef;

    return 1 if $APP->isEditor($USER);

    $level = $APP->getLevel($USER);
    return 1 if $level <= 3 or $level >= 6;

    return 0;
}

1;
