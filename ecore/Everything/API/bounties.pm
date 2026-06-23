package Everything::API::bounties;

use Moose;
use Everything qw(getVars setVars getNode);
use Digest::MD5 qw(md5_hex);
extends 'Everything::API';

=head1 NAME

Everything::API::bounties - Everything's Most Wanted bounty system

=head1 DESCRIPTION

The API backing the "Everything's Most Wanted" page. Replaces the server-side
C<op=>-style form processing the page used to do in C<_process_form> (guarded by
the C<verifyRequest>/C<verifyRequestHash> form-CSRF htmlcodes). All mutations
are now editor/level-gated API calls with their own auth, so those htmlcodes can
be retired (#4198).

Bounty data lives in a handful of C<setting> nodes:
  bounty order   -> { <number> => <sheriff title> }   ordered list
  outlaws        -> { <sheriff> => "[outlaw node]" }
  bounties       -> { <sheriff> => <reward GP or 'N/A'> }
  bounty comments-> { <sheriff> => <comment> }
  bounty number  -> { 1 => <max bounty #>, justice => <max justice #> }
  justice served -> { <number> => <citation> }

=head2 Endpoints

  GET  /api/bounties            -> read model (bounties, justice, current_bounty, limits)
  POST /api/bounties            -> post a new bounty       { outlaw, reward, comment }
  POST /api/bounties/remove     -> remove your own bounty
  POST /api/bounties/reward     -> award the GP bounty     { winner }
  POST /api/bounties/award      -> award a custom prize    { winner, prize }
  POST /api/bounties/yank       -> sheriff/admin removal   { removee }

=cut

my $MIN_LEVEL = 3;

sub routes {
    return {
        ''       => 'list_or_create',
        'remove' => 'remove_bounty',
        'reward' => 'reward_bounty',
        'award'  => 'award_bounty',
        'yank'   => 'yank_bounty',
    };
}

# ---------------------------------------------------------------------------
# Read model -- shared by GET /api/bounties and the page's buildReactData.
# $USER is a user NODEDATA hashref.
# ---------------------------------------------------------------------------
sub build_state {
    my ($DB, $APP, $USER) = @_;

    my $vars = $APP->getVars($USER);

    my $user_level = $APP->getLevel($USER);
    my $is_sheriff = $APP->inUsergroup($USER, 'sheriffs') ? 1 : 0;
    my $is_admin   = $APP->isAdmin($USER) ? 1 : 0;
    my $user_gp    = $USER->{GP} || 0;

    my $has_bounty = $vars->{Bounty} ? 1 : 0;

    my $order_node    = $APP->node_by_name('bounty order', 'setting');
    my $outlaws_node  = $APP->node_by_name('outlaws', 'setting');
    my $bounties_node = $APP->node_by_name('bounties', 'setting');
    my $comments_node = $APP->node_by_name('bounty comments', 'setting');
    my $max_node      = $APP->node_by_name('bounty number', 'setting');
    my $justice_node  = $APP->node_by_name('justice served', 'setting');

    my $REQ = $order_node    ? $APP->getVars($order_node->NODEDATA)    : {};
    my $OUT = $outlaws_node  ? $APP->getVars($outlaws_node->NODEDATA)  : {};
    my $REW = $bounties_node ? $APP->getVars($bounties_node->NODEDATA) : {};
    my $COM = $comments_node ? $APP->getVars($comments_node->NODEDATA) : {};
    my $MAX = $max_node      ? $APP->getVars($max_node->NODEDATA)      : {};

    my $current_bounty;
    if ($has_bounty) {
        $current_bounty = {
            outlaw => $OUT->{ $USER->{title} } || '',
            reward => $REW->{ $USER->{title} } || 0,
        };
    }

    my $bounty_total = $MAX->{1} || 0;
    my @bounties;
    for my $i (1 .. $bounty_total) {
        next unless exists $REQ->{$i};
        my $requester = $REQ->{$i};
        push @bounties, {
            number    => $i,
            requester => $requester,
            outlaw    => $OUT->{$requester} || '',
            reward    => $REW->{$requester} || 'N/A',
            comment   => $COM->{$requester} || '',
        };
    }

    my $justice_vars = $justice_node ? $APP->getVars($justice_node->NODEDATA) : {};
    my $justice_max  = $MAX->{justice} || 0;
    my @justice_served;
    for my $i (reverse($justice_max - 4 .. $justice_max)) {
        next if $i < 1;
        next unless $justice_vars->{$i};
        push @justice_served, $justice_vars->{$i};
    }

    return {
        user_level     => $user_level,
        min_level      => $MIN_LEVEL,
        is_sheriff     => $is_sheriff,
        is_admin       => $is_admin,
        user_gp        => $user_gp,
        bounty_limit   => int($user_gp / 10),
        has_bounty     => $has_bounty,
        current_bounty => $current_bounty,
        gp_optout      => $vars->{GPoptout} ? 1 : 0,
        bounties       => \@bounties,
        justice_served => \@justice_served,
        can_post       => ($user_level >= $MIN_LEVEL || $is_sheriff || $is_admin) ? 1 : 0,
    };
}

# GET -> read model; POST -> post a new bounty.
sub list_or_create {
    my ($self, $REQUEST) = @_;

    if (lc($REQUEST->request_method()) eq 'post') {
        return $self->_create_bounty($REQUEST);
    }

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {
        success => 1,
        %{ build_state($self->DB, $self->APP, $user->NODEDATA) },
    }];
}

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

sub _create_bounty {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $user = $REQUEST->user;

    my $gate = $self->_require_poster($user);
    return $gate if $gate;

    my $USER    = $user->NODEDATA;
    my $sheriff = $USER->{title};
    my $data    = $REQUEST->JSON_POSTDATA || {};

    my $outlaw = $APP->encodeHTML($data->{outlaw} // '');
    return $self->_fail('You must specify a node or nodeshell to be filled.') unless $outlaw;

    my $reward = $data->{reward} // 0;
    $reward = 0 if $reward eq '' || $reward eq 'N/A';
    $reward = int($reward);

    my $comment = $APP->encodeHTML($data->{comment} // '');
    $comment = '&nbsp;' if $comment eq '';

    return $self->_fail("No such node! Your 'Outlaw Node' must be a valid node or nodeshell.")
        unless $DB->getNode($outlaw, 'e2node');

    my $bounty_limit = int(($USER->{GP} || 0) / 10);
    return $self->_fail('Your bounty is too high! Bounties cannot be greater than 10% of your total GP.')
        if $reward > $bounty_limit;
    return $self->_fail('You must enter a bounty of 0 or greater.') if $reward < 0;

    my $order_node    = $APP->node_by_name('bounty order', 'setting');
    my $max_node      = $APP->node_by_name('bounty number', 'setting');
    my $bounties_node = $APP->node_by_name('bounties', 'setting');
    my $outlaws_node  = $APP->node_by_name('outlaws', 'setting');
    my $comments_node = $APP->node_by_name('bounty comments', 'setting');
    return $self->_fail('System error: bounty settings not found.')
        unless $order_node && $max_node && $bounties_node && $outlaws_node && $comments_node;

    # Deduct the staked GP up front.
    $APP->adjustGP($USER, -$reward) if $reward > 0;

    my $ORDER = $APP->getVars($order_node->NODEDATA) || {};
    my $MAX   = $APP->getVars($max_node->NODEDATA)   || {};

    my $bounty_num = ($MAX->{1} || 0) + 1;
    $MAX->{1} = $bounty_num;
    $ORDER->{$bounty_num} = $sheriff;
    setVars($order_node->NODEDATA, $ORDER);
    setVars($max_node->NODEDATA, $MAX);

    my $vars = $APP->getVars($USER);
    $vars->{Bounty}       = 1;
    $vars->{BountyNumber} = $bounty_num;
    setVars($USER, $vars);

    my $REW = $APP->getVars($bounties_node->NODEDATA) || {};
    $REW->{$sheriff} = $reward || 'N/A';
    setVars($bounties_node->NODEDATA, $REW);

    my $OUT = $APP->getVars($outlaws_node->NODEDATA) || {};
    $OUT->{$sheriff} = "[$outlaw]";
    setVars($outlaws_node->NODEDATA, $OUT);

    my $COM = $APP->getVars($comments_node->NODEDATA) || {};
    $COM->{$sheriff} = $comment;
    setVars($comments_node->NODEDATA, $COM);

    return $self->_ok('Your bounty has been posted!');
}

sub remove_bounty {
    my ($self, $REQUEST) = @_;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    my $gate = $self->_require_poster($user);
    return $gate if $gate;

    my $USER    = $user->NODEDATA;
    my $sheriff = $USER->{title};

    my $reward = $self->_reward_for($sheriff);

    $APP->adjustGP($USER, $reward) if $reward > 0;
    $self->_clear_bounty($USER);

    my $msg = 'Your bounty has been removed';
    $msg .= ", and the bounty you posted of $reward GP has been returned to your account" if $reward > 0;
    return $self->_ok("$msg.");
}

sub reward_bounty {
    my ($self, $REQUEST) = @_;
    return $self->_pay_out($REQUEST, 'reward');
}

sub award_bounty {
    my ($self, $REQUEST) = @_;
    return $self->_pay_out($REQUEST, 'award');
}

# reward (GP only) and award (GP + custom prize) share almost everything.
sub _pay_out {
    my ($self, $REQUEST, $kind) = @_;
    my $APP = $self->APP;
    my $DB  = $self->DB;
    my $user = $REQUEST->user;

    my $gate = $self->_require_poster($user);
    return $gate if $gate;

    my $USER    = $user->NODEDATA;
    my $sheriff = $USER->{title};
    my $data    = $REQUEST->JSON_POSTDATA || {};

    my $winner = $APP->encodeHTML($data->{winner} // '');
    my $prize  = $kind eq 'award' ? $APP->encodeHTML($data->{prize} // '') : '';

    return $self->_fail("You must name a winner.") unless $winner;
    my $target = $DB->getNode($winner, 'user');
    return $self->_fail("The user '$winner' doesn't exist!") unless $target;
    return $self->_fail('You cannot reward yourself!') if $sheriff eq $winner;

    my $reward = $self->_reward_for($sheriff);
    my $OUT    = $self->_outlaws_vars;
    my $outlaw = $OUT->{$sheriff} || 'unknown';

    $APP->adjustGP($target, $reward) if $reward > 0;
    $self->_clear_bounty($USER);

    my ($citation, $msg);
    if ($kind eq 'award') {
        $citation = "[$winner] rounded up $outlaw and earned a bounty from [$sheriff] of $prize";
        $citation .= " and $reward GP" if $reward > 0;
        $citation .= "!";
        $msg = "User [$winner] has been awarded a bounty of $prize";
        $msg .= " and $reward GP" if $reward > 0;
        $msg .= "!";
    } else {
        $citation = "[$winner] tracked down $outlaw and earned $reward GP from [$sheriff]!";
        $msg = "User [$winner] has been rewarded the bounty of $reward GP.";
    }
    $self->_record_justice($citation);

    return $self->_ok($msg);
}

sub yank_bounty {
    my ($self, $REQUEST) = @_;
    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $user = $REQUEST->user;

    my $USER = $user->NODEDATA;
    unless ($APP->inUsergroup($USER, 'sheriffs') || $APP->isAdmin($USER)) {
        return $self->_fail('Only sheriffs or admins can remove another user\'s bounty.');
    }

    my $data    = $REQUEST->JSON_POSTDATA || {};
    my $removee = $APP->encodeHTML($data->{removee} // '');
    return $self->_fail('You must name a user.') unless $removee;

    my $target = $DB->getNode($removee, 'user');
    return $self->_fail("The user '$removee' doesn't exist!") unless $target;

    my $refund = $self->_reward_for($removee);
    $APP->adjustGP($target, $refund) if $refund > 0;
    $self->_clear_bounty($target);

    my $msg = "[$removee]'s bounty has been removed";
    $msg .= " and $refund GP has been returned to their account" if $refund > 0;
    return $self->_ok("$msg.");
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Clear a user's bounty: drop their Bounty var and remove their slot from the
# bounty order. $USER is a NODEDATA hashref.
sub _clear_bounty {
    my ($self, $USER) = @_;
    my $APP = $self->APP;

    my $vars       = $APP->getVars($USER);
    my $bounty_num = $vars->{BountyNumber};
    $vars->{Bounty} = 0;
    setVars($USER, $vars);

    my $order_node = $APP->node_by_name('bounty order', 'setting');
    if ($order_node) {
        my $ORDER = $APP->getVars($order_node->NODEDATA) || {};
        delete $ORDER->{$bounty_num} if $bounty_num;
        setVars($order_node->NODEDATA, $ORDER);
    }
    return;
}

# The GP reward staked on a sheriff's bounty (0 if none / 'N/A').
sub _reward_for {
    my ($self, $sheriff) = @_;
    my $node = $self->APP->node_by_name('bounties', 'setting');
    my $REW  = $node ? $self->APP->getVars($node->NODEDATA) : {};
    my $reward = $REW->{$sheriff} || 0;
    $reward = 0 if $reward eq 'N/A';
    return $reward;
}

sub _outlaws_vars {
    my ($self) = @_;
    my $node = $self->APP->node_by_name('outlaws', 'setting');
    return $node ? $self->APP->getVars($node->NODEDATA) : {};
}

sub _record_justice {
    my ($self, $citation) = @_;
    my $APP = $self->APP;

    my $justice_node = $APP->node_by_name('justice served', 'setting');
    my $number_node  = $APP->node_by_name('bounty number', 'setting');
    return unless $justice_node && $number_node;

    my $JUST = $APP->getVars($justice_node->NODEDATA) || {};
    my $NUM  = $APP->getVars($number_node->NODEDATA)  || {};

    my $cites_num = ($NUM->{justice} || 0) + 1;
    $JUST->{$cites_num} = $citation;
    $NUM->{justice} = $cites_num;
    setVars($justice_node->NODEDATA, $JUST);
    setVars($number_node->NODEDATA, $NUM);
    return;
}

# Returns an error response if the user can't post a bounty, else undef.
sub _require_poster {
    my ($self, $user) = @_;
    my $APP = $self->APP;

    return $self->_fail('You must be logged in.') if $user->is_guest;

    my $USER = $user->NODEDATA;
    my $can = ($APP->getLevel($USER) >= $MIN_LEVEL)
        || $APP->inUsergroup($USER, 'sheriffs')
        || $APP->isAdmin($USER);
    return $self->_fail('You are not yet eligible to post bounties.') unless $can;
    return;
}

sub _ok   { return [$_[0]->HTTP_OK, { success => 1, message => $_[1] }]; }
sub _fail { return [$_[0]->HTTP_OK, { success => 0, error => $_[1] }]; }

__PACKAGE__->meta->make_immutable;

1;
