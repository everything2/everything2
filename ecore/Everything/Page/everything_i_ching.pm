package Everything::Page::everything_i_ching;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::everything_i_ching

React page for Everything I Ching - generates I-Ching hexagrams using coin method.

=cut

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $DB  = $self->DB;
    my $APP = $self->APP;

    # I-Ching hexagram mappings
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

    # Coin method - generate hexagrams
    my @pset = qw(B F B F);
    my @sset = qw(F F B B);

    my $primary   = '';
    my $secondary = '';
    while ( length($primary) < 6 ) {
        my $coins = int( rand(2) ) + int( rand(2) ) + int( rand(2) );
        $primary   .= $pset[$coins];
        $secondary .= $sset[$coins];
    }

    # Get primary hexagram node and writeup
    my $primary_name = $figures{$primary};
    my $pnode        = $DB->getNode( $primary_name, 'e2node' );
    unless ( $pnode && $pnode->{group} && $pnode->{group}[0] ) {
        return {
            type  => 'everything_i_ching',
            error =>
"The I-Ching hexagram writeups are not available in this database. This page requires the 64 hexagram writeup nodes to function."
        };
    }

    my $pwriteup = $DB->getNodeById( $pnode->{group}[0] );

    # Get secondary hexagram node and writeup
    my $secondary_name = $figures{$secondary};
    my $snode          = $DB->getNode( $secondary_name, 'e2node' );
    unless ( $snode && $snode->{group} && $snode->{group}[0] ) {
        return {
            type  => 'everything_i_ching',
            error =>
"The I-Ching hexagram writeups are not available in this database. This page requires the 64 hexagram writeup nodes to function."
        };
    }

    my $swriteup = $DB->getNodeById( $snode->{group}[0] );

    return {
        type    => 'everything_i_ching',
        primary => {
            name    => $primary_name,
            node_id => $pnode->{node_id},
            title   => $pnode->{title},
            pattern => $primary,
            text    => $pwriteup->{doctext}
        },
        secondary => {
            name    => $secondary_name,
            node_id => $snode->{node_id},
            title   => $snode->{title},
            pattern => $secondary,
            text    => $swriteup->{doctext}
        }
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut
