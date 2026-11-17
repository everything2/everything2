#!/usr/bin/perl -w
# Random values: Application::random_bytes / random_hex, password salts and backup file names.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use File::Temp ();
use POSIX ();
use Everything;
use Everything::API::nodebackup;

initEverything('development-docker');
my $APP = $Everything::APP;

subtest 'random_bytes / random_hex' => sub {
    is( length( $APP->random_bytes(32) ), 32, 'random_bytes returns the requested length' );
    isnt( $APP->random_bytes(16), $APP->random_bytes(16), 'two draws differ' );
    like( $APP->random_hex, qr/^[0-9a-f]{32}$/, 'random_hex defaults to 16 bytes as 32 hex digits' );
    like( $APP->random_hex(4), qr/^[0-9a-f]{8}$/, 'random_hex(4) is 8 hex digits' );
};

subtest 'password salts' => sub {
    my @salts = map { $APP->new_password_salt } 1 .. 500;
    my @bad = grep { !/^\$6\$[A-Za-z0-9.\/]{20}$/ } @salts;
    is( scalar(@bad), 0, 'every salt is $6$ plus 20 crypt-alphabet characters' );
    my %seen;
    $seen{$_}++ for @salts;
    is( scalar( keys %seen ), 500, '500 salts, all different' );

    my %symbols;
    $symbols{$_}++ for map { split //, substr( $_, 3 ) } @salts;
    is( scalar( keys %symbols ), 64, 'all 64 symbols get used' );

    # Process state must not decide the salt: the same seed must not give the same salt.
    srand(42);
    my $first = $APP->new_password_salt;
    srand(42);
    isnt( $APP->new_password_salt, $first, 'independent of srand' );

    my ( $hash, $salt ) = $APP->saltNewPassword('correct horse');
    is( $APP->hashString( 'correct horse', $salt ), $hash, 'a new salt still verifies its password' );
};

subtest 'backup file names' => sub {
    my $name = Everything::API::nodebackup::backup_filename( $APP, 'some_user', 'text-html', '2026-11-17' );
    like( $name, qr/^some_user\.text-html\.[0-9a-f]{32}\.2026-11-17\.zip$/, 'user.format.<32 hex>.date.zip' );

    srand(42);
    my $first = Everything::API::nodebackup::backup_filename( $APP, 'some_user', 'text', '2026-11-17' );
    srand(42);
    isnt( Everything::API::nodebackup::backup_filename( $APP, 'some_user', 'text', '2026-11-17' ), $first,
        'independent of srand' );
};

# --- The source itself -----------------------------------------------------------------
# These guard against the platform changing under us (a new base image, kernel or Perl):
# the bytes must still look random, differ between forked workers, and a broken source must
# stop the caller rather than quietly hand back something weaker. Thresholds are the
# published FIPS 140-2 bounds (or similarly wide ones), so a healthy source essentially
# never trips them.

# FIPS 140-2 tests on 2,500 bytes (20,000 bits). Returns the checks that failed, each as
# "name: value (bounds)"; empty means it passed.
sub fips_failures {
    my ($bytes) = @_;
    my $bits = unpack( 'B*', $bytes );
    return ('input is not 20,000 bits') unless length($bits) == 20000;
    my @failed;

    my $ones = ( $bits =~ tr/1// );
    push @failed, "monobit: $ones (9725-10275)" unless $ones > 9725 && $ones < 10275;

    my %nibble;
    $nibble{$_}++ for unpack( '(A4)*', $bits );
    my $sum = 0;
    $sum += $_**2 for values %nibble;
    my $poker = ( 16 / 5000 ) * $sum - 5000;
    push @failed, sprintf( 'poker: %.2f (2.16-46.17)', $poker ) unless $poker > 2.16 && $poker < 46.17;

    my %bounds = ( 1 => [ 2315, 2685 ], 2 => [ 1114, 1386 ], 3 => [ 527, 723 ],
                   4 => [ 240, 384 ], 5 => [ 103, 209 ], 6 => [ 103, 209 ] );
    my %runs;
    my $longest = 0;
    while ( $bits =~ /((.)\2*)/g ) {
        my ( $len, $bit ) = ( length($1), $2 );
        $longest = $len if $len > $longest;
        $runs{$bit}{ $len > 6 ? 6 : $len }++;
    }
    for my $bit ( 0, 1 ) {
        for my $len ( 1 .. 6 ) {
            my $n = $runs{$bit}{$len} || 0;
            my ( $lo, $hi ) = @{ $bounds{$len} };
            push @failed, "runs of ${bit}s length $len: $n ($lo-$hi)" unless $n >= $lo && $n <= $hi;
        }
    }
    push @failed, "long run: $longest (< 26)" unless $longest < 26;
    return @failed;
}

# Chi-square of the byte counts (255 degrees of freedom: mean 255, sd ~22.6) and how many of
# the 256 values appear. Too high is biased; too low is too even to be random (a counter or a
# repeating pattern).
sub byte_distribution {
    my ($bytes) = @_;
    my @count = (0) x 256;
    $count[$_]++ for unpack( 'C*', $bytes );
    my $expected = length($bytes) / 256;
    my $chi2 = 0;
    $chi2 += ( $_ - $expected )**2 / $expected for @count;
    return ( $chi2, scalar( grep { $_ } @count ) );
}
sub distribution_ok { my ( $chi2, $values ) = @_; return $values == 256 && $chi2 > 140 && $chi2 < 400 }

subtest 'statistical quality (FIPS 140-2 tests on 20,000 bits)' => sub {
    my @failed = fips_failures( $APP->random_bytes(2500) );
    is_deeply( \@failed, [], 'monobit, poker, runs and long-run tests all pass' ) or diag( join( "\n", @failed ) );
};

subtest 'byte distribution over 256 KB' => sub {
    my ( $chi2, $values ) = byte_distribution( $APP->random_bytes(262144) );
    is( $values, 256, 'every byte value appears' );
    ok( distribution_ok( $chi2, $values ), sprintf( 'chi-square %.1f (140-400)', $chi2 ) );
};

subtest 'the quality checks reject non-random input' => sub {
    # Without these, a check that passed everything would look the same as a healthy source.
    # Each check alone has blind spots (FIPS 140-2 passes a repeating byte counter), so the
    # requirement is that the two together reject every one of these.
    my %bad = (
        'all zero bytes'              => sub { "\0" x $_[0] },
        'a repeating 0..255 counter'  => sub { substr( pack( 'C*', 0 .. 255 ) x ( $_[0] / 256 + 1 ), 0, $_[0] ) },
        'random bytes with the top bit cleared' => sub { pack( 'C*', map { $_ & 0x7f } unpack( 'C*', $APP->random_bytes( $_[0] ) ) ) },
        'random bytes, every 4th zeroed' => sub { my $b = $APP->random_bytes( $_[0] ); substr( $b, $_ * 4, 1, "\0" ) for 0 .. int( $_[0] / 4 ) - 1; $b },
    );
    for my $name ( sort keys %bad ) {
        my @fips = fips_failures( $bad{$name}->(2500) );
        my $dist_ok = distribution_ok( byte_distribution( $bad{$name}->(262144) ) );
        ok( @fips || !$dist_ok, "rejected: $name" )
            or diag("FIPS and byte distribution both passed $name");
    }
};

subtest 'forked workers each get their own values' => sub {
    # Production forks preloaded Starman workers from one parent; each must draw independently.
    my @values = ( $APP->random_hex );
    for ( 1 .. 4 ) {
        pipe( my $reader, my $writer ) or die "pipe: $!";
        my $pid = fork();
        die "fork: $!" unless defined $pid;
        if ( $pid == 0 ) {
            close($reader);
            print {$writer} $APP->random_hex, "\n";
            close($writer);
            POSIX::_exit(0);    # skip END blocks and DESTROY, which would touch the parent's DB handle
        }
        close($writer);
        chomp( my $value = <$reader> // '' );
        close($reader);
        waitpid( $pid, 0 );
        push @values, $value;
    }
    is( scalar( grep { /^[0-9a-f]{32}$/ } @values ), 5, 'parent and 4 children each produced a value' );
    my %seen;
    $seen{$_}++ for @values;
    is( scalar( keys %seen ), 5, 'all five differ' );
};

subtest 'a broken source fails closed' => sub {
    {
        local $Everything::Application::RANDOM_SOURCE = '/nonexistent/random-source';
        ok( !eval { $APP->random_bytes(16); 1 }, 'missing source: random_bytes dies' );
        like( $@, qr/cannot open/, '... saying it cannot open the source' );
        ok( !eval { $APP->new_password_salt; 1 }, 'missing source: no salt is produced' );
    }
    {
        my $empty = File::Temp->new;
        local $Everything::Application::RANDOM_SOURCE = $empty->filename;
        ok( !eval { $APP->random_bytes(16); 1 }, 'short read: random_bytes dies' );
        like( $@, qr/short read/, '... saying the read came up short' );
    }
    ok( eval { length( $APP->random_bytes(16) ) == 16 }, 'the real source works again afterwards' );
};

done_testing();
