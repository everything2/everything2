package Everything::SecurityLog;

use strict;
use warnings;

=head1 NAME

Everything::SecurityLog - canonical registry of security-log event types

=head1 DESCRIPTION

The security log (C<seclog>) historically keyed every event off C<seclog_node>, a
node id used as the event category. That tied the log to node identity: nuking a
node orphaned its rows and could silently stop logging. This module replaces that
with a stable enum stored in C<seclog.seclog_event>; writers pass a C<SECLOG_*>
constant.

The registry is B<append-only>. The C<id> of each event is persisted in ~2M rows --
B<never renumber an id and never reuse one>. Retire an event by leaving its id in
place, not by deleting the row.

Each event carries:

  id     - the smallint written to seclog.seclog_event. STABLE / append-only.
  key    - symbolic constant (exported as SECLOG_<KEY>) for writers.
  desc   - human label shown by the security monitor.
  group  - monitor section.

(The transitional C<titles>/C<nodes> mapping fields and C<event_for_title> /
C<event_for_node> were removed in #4272 once every caller passed a SECLOG_* constant
directly -- see docs/seclog-decoupling-design.md.)

=cut

# id 0 is reserved for LEGACY_UNKNOWN (the seclog_event column default), so every
# pre-backfill row is validly "unclassified".
my @EVENTS = (
  { id => 0,  key => 'LEGACY_UNKNOWN',        desc => 'Legacy / unclassified', group => 'legacy'   },
  { id => 1,  key => 'USER_SIGNUP',           desc => 'User Signup',           group => 'accounts' },
  { id => 2,  key => 'USER_DELETION',         desc => 'User Deletions',        group => 'accounts' },
  { id => 3,  key => 'ACCOUNT_LOCK',          desc => 'Account Lockings',      group => 'accounts' },
  { id => 4,  key => 'ACCOUNT_UNLOCK',        desc => 'Account Unlockings',    group => 'accounts' },
  { id => 5,  key => 'MASSACRE',              desc => 'Kill reasons',          group => 'content'  },
  { id => 6,  key => 'PASSWORD_RESET',        desc => 'Password resets',       group => 'accounts' },
  { id => 7,  key => 'WHEEL_OF_SURPRISE',     desc => 'Wheel of Surprise',     group => 'giftshop' },
  { id => 8,  key => 'IP_BLACKLIST',          desc => 'IP Blacklist',          group => 'abuse'    },
  { id => 9,  key => 'IP_BLACKLIST_MASS',     desc => 'Mass IP Blacklist',     group => 'abuse'    },
  { id => 10, key => 'NODENOTE',              desc => 'Node Notes',            group => 'content'  },
  { id => 11, key => 'VOTES_PURCHASED',       desc => 'Votes Bought',          group => 'giftshop' },
  { id => 12, key => 'VOTES_GIVEN',           desc => 'Votes Given Away',      group => 'giftshop' },
  { id => 13, key => 'VOTES_REFILL',          desc => 'Vote refills',          group => 'xp'       },
  { id => 14, key => 'CHINGS_PURCHASED',      desc => 'Chings Bought',         group => 'giftshop' },
  { id => 15, key => 'CHING_GIVEN',           desc => 'Chings Given Away',     group => 'giftshop' },
  { id => 16, key => 'STARS_AWARDED',         desc => 'Stars Awarded',         group => 'giftshop' },
  { id => 17, key => 'EGGS_GIVEN',            desc => 'Eggs Given Away',       group => 'giftshop' },
  { id => 18, key => 'BLESS',                 desc => 'Blessings',             group => 'xp'       },
  { id => 19, key => 'BESTOW_VOTES',          desc => 'Vote bestowings',       group => 'xp'       },
  { id => 20, key => 'COOLS_BESTOWED',        desc => 'C! bestowings',         group => 'xp'       },
  { id => 21, key => 'SUPERBLESS',            desc => 'SuperBless',            group => 'xp'       },
  { id => 22, key => 'XP_SUPERBLESS',         desc => 'XP SuperBless',         group => 'xp'       },
  { id => 23, key => 'XP_RECALC',             desc => 'XP Recalculations',     group => 'xp'       },
  { id => 24, key => 'SANCTIFY',              desc => 'Sanctifications',       group => 'xp'       },
  { id => 25, key => 'RESURRECTION',          desc => 'Resurrections',         group => 'content'  },
  { id => 26, key => 'PARAMETER_CHANGE',      desc => 'Parameter changes',     group => 'system'   },
  { id => 27, key => 'CATBOX_FLUSH',          desc => 'Catbox flushes',        group => 'chat'     },
  { id => 28, key => 'WRITEUP_INSURANCE',     desc => 'Writeup insurance',     group => 'content'  },
  { id => 29, key => 'WRITEUP_REPARENT',      desc => 'Writeup reparentings',  group => 'content'  },
  { id => 30, key => 'SUSPENSION',            desc => 'Suspensions',           group => 'accounts' },
  { id => 31, key => 'GIFTSHOP_TOPIC',        desc => 'Topic changes',         group => 'giftshop' },
  { id => 32, key => 'WEBSTERBLESS',          desc => 'Websterbless',          group => 'xp'       },
  { id => 33, key => 'ENRICHIFY',             desc => 'Enrichify',             group => 'xp'       },
  { id => 34, key => 'NODE_REMOVE',           desc => 'Node removals',         group => 'content'  },
  { id => 35, key => 'PUNCH_THYSELF',         desc => 'Self-punches (GP sink)',group => 'xp'       },
  { id => 36, key => 'NODE_EDIT',             desc => 'Node edits (admin)',    group => 'system'   },
  { id => 37, key => 'USER_IMAGE_MODERATION', desc => 'User image moderation', group => 'content'  },
);

my (%BY_ID, %BY_KEY);
for my $e (@EVENTS) {
  $BY_ID{ $e->{id} }   = $e;
  $BY_KEY{ $e->{key} } = $e;
}

sub all { return @EVENTS }

sub by_id  { my ($class, $id)  = @_; return $BY_ID{ $id  // -1 } }
sub by_key { my ($class, $key) = @_; return $BY_KEY{ $key // '' } }

sub id_for_key { my ($class, $key) = @_; my $e = $BY_KEY{ $key // '' }; return defined $e ? $e->{id} : undef }

sub description { my ($class, $id) = @_; my $e = $BY_ID{ $id // -1 }; return defined $e ? $e->{desc}  : 'Unknown' }
sub group       { my ($class, $id) = @_; my $e = $BY_ID{ $id // -1 }; return defined $e ? $e->{group} : 'legacy'  }

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
