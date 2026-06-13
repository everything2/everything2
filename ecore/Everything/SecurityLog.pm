package Everything::SecurityLog;

use strict;
use warnings;

=head1 NAME

Everything::SecurityLog - canonical registry of security-log event types

=head1 DESCRIPTION

The security log (C<seclog>) historically keyed every event off C<seclog_node>, a
node id used as the event category. That ties the log to node identity: nuking a
node orphans its rows and can silently stop logging. This module replaces that with
a stable enum stored in C<seclog.seclog_event>.

The registry is B<append-only>. The C<id> of each event is persisted in ~2M rows --
B<never renumber an id and never reuse one>. Retire an event by leaving its id in
place, not by deleting the row.

Each event carries:

  id     - the smallint written to seclog.seclog_event. STABLE / append-only.
  key    - symbolic constant (exported as SECLOG_<KEY>) for writers.
  desc   - human label shown by the security monitor.
  group  - monitor section.
  titles - node titles (env-stable) used to map a legacy node arg -> event in code.
  nodes  - PROD seclog_node ids (from the data tree) used by the one-time backfill ONLY.

See docs/seclog-decoupling-design.md for the full mapping and rollout (#4272).

=cut

# id 0 is reserved for LEGACY_UNKNOWN (the seclog_event column default), so every
# pre-backfill row is validly "unclassified".
my @EVENTS = (
  { id => 0,  key => 'LEGACY_UNKNOWN',    desc => 'Legacy / unclassified', group => 'legacy',   titles => [],                              nodes => [] },
  { id => 1,  key => 'USER_SIGNUP',       desc => 'User Signup',           group => 'accounts', titles => ['Sign up'],                     nodes => [2072173, 1690592] },
  { id => 2,  key => 'USER_DELETION',     desc => 'User Deletions',        group => 'accounts', titles => ['The Old Hooked Pole'],         nodes => [2108998, 2015009] },
  { id => 3,  key => 'ACCOUNT_LOCK',      desc => 'Account Lockings',      group => 'accounts', titles => ['lockaccount'],                 nodes => [1203049] },
  { id => 4,  key => 'ACCOUNT_UNLOCK',    desc => 'Account Unlockings',    group => 'accounts', titles => ['unlockaccount'],               nodes => [1203054] },
  { id => 5,  key => 'MASSACRE',          desc => 'Kill reasons',          group => 'content',  titles => ['massacre'],                    nodes => [648516] },
  { id => 6,  key => 'PASSWORD_RESET',    desc => 'Password resets',       group => 'accounts', titles => ['Reset password'],              nodes => [2072175] },
  { id => 7,  key => 'WHEEL_OF_SURPRISE', desc => 'Wheel of Surprise',     group => 'giftshop', titles => ['Wheel of Surprise'],          nodes => [1874886] },
  { id => 8,  key => 'IP_BLACKLIST',      desc => 'IP Blacklist',          group => 'abuse',    titles => ['IP Blacklist'],               nodes => [1948146] },
  { id => 9,  key => 'IP_BLACKLIST_MASS', desc => 'Mass IP Blacklist',     group => 'abuse',    titles => ['Mass IP Blacklister'],        nodes => [2007188] },
  { id => 10, key => 'NODENOTE',          desc => 'Node Notes',            group => 'content',  titles => ['Recent Node Notes'],          nodes => [1429619] },
  { id => 11, key => 'VOTES_PURCHASED',   desc => 'Votes Bought',          group => 'giftshop', titles => ['Buy Votes'],                  nodes => [1962460] },
  { id => 12, key => 'VOTES_GIVEN',       desc => 'Votes Given Away',      group => 'giftshop', titles => ['The Gift of Votes'],          nodes => [1962436] },
  { id => 13, key => 'VOTES_REFILL',      desc => 'Vote refills',          group => 'xp',       titles => [],                              nodes => [1162681] },
  { id => 14, key => 'CHINGS_PURCHASED',  desc => 'Chings Bought',         group => 'giftshop', titles => ['Buy Chings'],                 nodes => [1962461] },
  { id => 15, key => 'CHING_GIVEN',       desc => 'Chings Given Away',     group => 'giftshop', titles => ['The Gift of Ching'],          nodes => [1962435] },
  { id => 16, key => 'STARS_AWARDED',     desc => 'Stars Awarded',         group => 'giftshop', titles => ['The Gift of Star'],           nodes => [1988325] },
  { id => 17, key => 'EGGS_GIVEN',        desc => 'Eggs Given Away',       group => 'giftshop', titles => ['The Gift of Eggs'],           nodes => [1962437] },
  { id => 18, key => 'BLESS',             desc => 'Blessings',             group => 'xp',       titles => ['bless'],                       nodes => [444704] },
  { id => 19, key => 'BESTOW_VOTES',      desc => 'Vote bestowings',       group => 'xp',       titles => ['bestow'],                      nodes => [444712] },
  { id => 20, key => 'COOLS_BESTOWED',    desc => 'C! bestowings',         group => 'xp',       titles => ['bestow cools'],               nodes => [605785] },
  { id => 21, key => 'SUPERBLESS',        desc => 'SuperBless',            group => 'xp',       titles => ['Superbless', 'superbless'],    nodes => [453574] },
  { id => 22, key => 'XP_SUPERBLESS',     desc => 'XP SuperBless',         group => 'xp',       titles => ['XP Superbless'],              nodes => [1959718, 1080591] },
  { id => 23, key => 'XP_RECALC',         desc => 'XP Recalculations',     group => 'xp',       titles => ['Recalculate XP'],             nodes => [1959368] },
  { id => 24, key => 'SANCTIFY',          desc => 'Sanctifications',       group => 'xp',       titles => ['Sanctify user'],              nodes => [1927889] },
  { id => 25, key => 'RESURRECTION',      desc => 'Resurrections',         group => 'content',  titles => ["Dr. Nate's Secret Lab"],      nodes => [850865, 1668580] },
  { id => 26, key => 'PARAMETER_CHANGE',  desc => 'Parameter changes',     group => 'system',   titles => ['parameter'],                  nodes => [2071202] },
  { id => 27, key => 'CATBOX_FLUSH',      desc => 'Catbox flushes',        group => 'chat',     titles => ['flushcbox'],                  nodes => [1328318] },
  { id => 28, key => 'WRITEUP_INSURANCE', desc => 'Writeup insurance',     group => 'content',  titles => ['insure'],                     nodes => [1179550] },
  { id => 29, key => 'WRITEUP_REPARENT',  desc => 'Writeup reparentings',  group => 'content',  titles => ['Magical Writeup Reparenter'], nodes => [1138488, 1983796] },
  { id => 30, key => 'SUSPENSION',        desc => 'Suspensions',           group => 'accounts', titles => ['Suspension Info'],            nodes => [1399999] },
  { id => 31, key => 'GIFTSHOP_TOPIC',    desc => 'Topic changes',         group => 'giftshop', titles => ['E2 Gift Shop'],               nodes => [1872678] },
  { id => 32, key => 'WEBSTERBLESS',      desc => 'Websterbless',          group => 'xp',       titles => ['Websterbless'],               nodes => [1526847] },
  { id => 33, key => 'ENRICHIFY',         desc => 'Enrichify',             group => 'xp',       titles => ['Enrichify'],                  nodes => [1956191] },
  { id => 34, key => 'NODE_REMOVE',       desc => 'Node removals',         group => 'content',  titles => ['remove'],                     nodes => [2047058] },
  { id => 35, key => 'PUNCH_THYSELF',     desc => 'Self-punches (GP sink)',group => 'xp',       titles => ['punch thyself'],              nodes => [716619] },
);

my (%BY_ID, %BY_KEY, %TITLE_TO_ID, %NODE_TO_ID);
for my $e (@EVENTS) {
  $BY_ID{ $e->{id} }   = $e;
  $BY_KEY{ $e->{key} } = $e;
  $TITLE_TO_ID{$_} = $e->{id} for @{ $e->{titles} || [] };
  $NODE_TO_ID{$_}  = $e->{id} for @{ $e->{nodes}  || [] };
}

sub all { return @EVENTS }

sub by_id  { my ($class, $id)  = @_; return $BY_ID{ $id  // -1 } }
sub by_key { my ($class, $key) = @_; return $BY_KEY{ $key // '' } }

sub id_for_key { my ($class, $key) = @_; my $e = $BY_KEY{ $key // '' }; return defined $e ? $e->{id} : undef }

sub description { my ($class, $id) = @_; my $e = $BY_ID{ $id // -1 }; return defined $e ? $e->{desc}  : 'Unknown' }
sub group       { my ($class, $id) = @_; my $e = $BY_ID{ $id // -1 }; return defined $e ? $e->{group} : 'legacy'  }

# Map a node TITLE (env-stable) -> event id. Used by the transitional securityLog()
# so it works in dev and prod regardless of differing node ids. Unknown -> LEGACY_UNKNOWN(0).
sub event_for_title { my ($class, $title) = @_; my $id = $TITLE_TO_ID{ $title // '' }; return defined $id ? $id : 0 }

# Map a PROD seclog_node id -> event id. For the one-time prod backfill ONLY
# (dev node ids differ). Unknown -> LEGACY_UNKNOWN(0).
sub event_for_node { my ($class, $node_id) = @_; my $id = $NODE_TO_ID{ $node_id // -1 }; return defined $id ? $id : 0 }

# --- exported SECLOG_<KEY> constants for writers ---------------------------------
# Built from the registry via constant->import (no symbol-table poking / no `no strict`).
use Exporter 'import';
use constant ();   ## no critic (ProhibitConstantPragma)
our (@EXPORT_OK, %EXPORT_TAGS);
for my $e (@EVENTS) {
  my $name = "SECLOG_$e->{key}";
  constant->import( $name => $e->{id} );
  push @EXPORT_OK, $name;
}
$EXPORT_TAGS{events} = [ @EXPORT_OK ];

1;
