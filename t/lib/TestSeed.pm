package TestSeed;

use strict;
use warnings;
use Everything;

=head1 NAME

TestSeed - dedicated throwaway users for prove -j4 isolation (#4267)

=head1 SYNOPSIS

    use lib "$FindBin::Bin/lib";
    use TestSeed;

    my $author = TestSeed::make_user($DB, $APP, label => 'author', experience => 50000, numwriteups => 100, GP => 100);
    my $voter  = TestSeed::make_user($DB, $APP, label => 'voter',  votesleft => 100, experience => 50000);

    END { TestSeed::cleanup($DB); }

=head1 DESCRIPTION

Tests must not mutate shared seed users (normaluser1..30, root, genericdev,
Cool Man Eddie, e2e_*, ...) -- under C<prove -j4> two workers touching the same
user race each other. This helper hands out uniquely-named throwaway users
(name includes the PID so concurrent workers never collide) and nukes them all
in one C<cleanup> call.

See C<t/README.md> for the full rationale and gotchas.

=head2 make_user($DB, $APP, %opts)

Creates a real, dedicated user node and returns its (hashref) node. Options:

    label       - short tag woven into the unique title (default 'u')
    GP          - starting GP            (user-table column)
    experience  - starting experience    (user-table column; drives level)
    votesleft   - starting votesleft     (user-table column)
    numwriteups - VARS numwriteups       (also drives level)
    online      - if true, insert a room row so online-only delivery reaches it

Only the user-table PK is NOT NULL-without-default, so the partial insert is
safe; every other column defaults to 0 and lasttime is NULL (never-logged-in).

=head2 cleanup($DB)

Nukes every user make_user created this run (skip_maintenance so user_delete
doesn't securityLog the unset global USER) and clears side rows. Idempotent.

=cut

my @CREATED;
my $SEQ = 0;

sub make_user {
    my ($DB, $APP, %o) = @_;
    my $label = $o{label} // 'u';
    my $root  = $DB->getNode('root', 'user');

    # Hyphens (not underscores) so the name is /msg-addressable: the /msg command
    # converts underscores to spaces, which would break delivery to these users.
    # Callers can override with title => '...'.
    my $title = $o{title} // "e2eseed-${label}-${$}-" . $SEQ++;
    my $uid   = $DB->insertNode($title, 'user', $root, undef, 1);
    return undef unless $uid;
    push @CREATED, $uid;

    # Materialize the user row explicitly (insertNode is unreliable cold).
    $DB->sqlDelete('user', "user_id=$uid");
    my %row = (user_id => $uid);
    $row{GP}         = $o{GP}         if defined $o{GP};
    $row{experience} = $o{experience} if defined $o{experience};
    $row{votesleft}  = $o{votesleft}  if defined $o{votesleft};
    $DB->sqlInsert('user', \%row);

    $DB->sqlInsert('room', { member_user => $uid }) if $o{online};

    $DB->getNodeById($uid, 'force');
    my $n = $DB->getNode($uid);

    if ($o{numwriteups}) {
        my $v = $APP->getVars($n);
        $v->{numwriteups} = $o{numwriteups};
        Everything::setVars($n, $v);
        $DB->updateNode($n, -1);
    }

    return $DB->getNode($n->{node_id});
}

sub created_ids { return @CREATED; }

sub cleanup {
    my ($DB) = @_;
    return unless $DB;
    for my $uid (@CREATED) {
        my $n = $DB->getNodeById($uid, 'force');
        $DB->nukeNode($n, -1, 0, 1) if $n;
        $DB->sqlDelete('user', "user_id=$uid");
        $DB->sqlDelete('room', "member_user=$uid");
        $DB->sqlDelete('message',       "for_user=$uid OR author_user=$uid");
        $DB->sqlDelete('messageignore', "messageignore_id=$uid OR ignore_node=$uid");
    }
    @CREATED = ();
    return;
}

1;
