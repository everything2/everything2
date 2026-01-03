package Everything::API::xp;

use Moose;
extends 'Everything::API';

use Readonly;
Readonly my $WRITEUP_BONUS => 5;
Readonly my $COOL_BONUS => 20;
Readonly my $CUTOFF_NODE_ID => 1960662;  # October 29, 2008

sub routes {
    return {
        'recalculate' => 'recalculate',
        'stats'       => 'get_stats',
    };
}

sub get_stats {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Login required'}]
        if $user->is_guest;

    my $data = $REQUEST->JSON_POSTDATA;
    my $target_username = $data->{username};

    my $target_user;
    if ($target_username && $user->is_admin) {
        $target_user = $self->DB->getNode($target_username, 'user');
        return [$self->HTTP_OK, {success => 0, error => "User '$target_username' not found"}]
            unless $target_user;
    } else {
        $target_user = $user->NODEDATA;
    }

    my $uid = $target_user->{node_id};
    my $vars = $self->APP->getVars($target_user);

    # Check eligibility
    my $can_recalculate = 1;
    my $ineligible_reason = '';

    if ($uid > $CUTOFF_NODE_ID) {
        $can_recalculate = 0;
        $ineligible_reason = 'User joined after October 29, 2008';
    } elsif ($vars->{hasRecalculated}) {
        $can_recalculate = 0;
        $ineligible_reason = 'Already recalculated';
    }

    my $stats = $self->_get_user_stats($uid);

    return [$self->HTTP_OK, {
        success => 1,
        username => $target_user->{title},
        canRecalculate => $can_recalculate ? \1 : \0,
        ineligibleReason => $ineligible_reason,
        %$stats,
    }];
}

sub recalculate {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Login required'}]
        if $user->is_guest;

    my $APP = $self->APP;
    my $DB = $self->DB;

    my $data = $REQUEST->JSON_POSTDATA;
    my $confirmed = $data->{confirmed};
    my $target_username = $data->{username};

    return [$self->HTTP_OK, {success => 0, error => 'You must confirm you understand the recalculation is permanent'}]
        unless $confirmed;

    # Determine target user
    my $target_user;
    my $target_vars;

    if ($target_username && $user->is_admin && $target_username ne $user->title) {
        $target_user = $DB->getNode($target_username, 'user');
        return [$self->HTTP_OK, {success => 0, error => "User '$target_username' not found"}]
            unless $target_user;
        $target_vars = $APP->getVars($target_user);
    } else {
        $target_user = $user->NODEDATA;
        $target_vars = $user->VARS;

        # Non-admins can only recalculate themselves and must meet eligibility
        if ($target_user->{node_id} > $CUTOFF_NODE_ID) {
            return [$self->HTTP_OK, {success => 0, error => 'You are not eligible for XP recalculation'}];
        }
        if ($target_vars->{hasRecalculated}) {
            return [$self->HTTP_OK, {success => 0, error => 'You have already recalculated your XP'}];
        }
    }

    my $uid = $target_user->{node_id};
    my $stats = $self->_get_user_stats($uid);

    my $current_xp = $stats->{currentXP};
    my $new_xp = $stats->{recalculatedXP};
    my $gp_bonus = $stats->{gpBonus};

    # Perform recalculation
    $APP->securityLog($user->NODEDATA, $target_user,
        $user->title . " recalculated " . $target_user->{title} . "'s XP");

    # Adjust XP
    $APP->adjustExp($target_user, -$current_xp);
    $APP->adjustExp($target_user, $new_xp);

    # Mark as recalculated
    $target_vars->{hasRecalculated} = 1;

    # Clear cache
    $DB->sqlDelete('xpHistoryCache', "xpHistoryCache_id=$uid");

    # Award GP bonus if applicable
    if ($gp_bonus > 0) {
        $target_user->{GP} += $gp_bonus;
        $DB->updateNode($target_user, -1);
        $target_vars->{oldexp} = $target_user->{experience};
    }

    # Save vars to the target user
    # For admin recalculating another user, use Everything::setVars
    # For self-recalculation, use the user object's set_vars
    if ($target_username && $user->is_admin && $target_username ne $user->title) {
        # Admin recalculating another user
        Everything::setVars($target_user, $target_vars);
        $DB->updateNode($target_user, -1);
    } else {
        # Self recalculation - target_vars is user's VARS, save via set_vars
        $user->set_vars($target_vars);
    }

    return [$self->HTTP_OK, {
        success => 1,
        message => "Recalculation complete!",
        newXP => int($new_xp),
        newGP => int($target_user->{GP} || 0),
        gpBonus => int($gp_bonus),
    }];
}

sub _get_user_stats {
    my ($self, $uid) = @_;

    my $DB = $self->DB;
    my $dbh = $DB->{dbh};

    # Current XP
    my ($xp) = $DB->sqlSelect('experience', 'user', "user_id=$uid");
    $xp //= 0;

    # Writeup count
    my ($writeup_count) = $DB->sqlSelect(
        'COUNT(*)',
        'node, writeup',
        "node.node_id=writeup.writeup_id AND node.author_user=$uid"
    );
    $writeup_count //= 0;

    # Total upvotes from drafts
    my $upvotes = 0;
    my $sth = $dbh->prepare(q{
        SELECT node_id FROM node
        JOIN draft ON node_id=draft_id
        WHERE node.author_user=?
    });
    $sth->execute($uid);

    my $vote_sth = $dbh->prepare('SELECT COUNT(vote_id) FROM vote WHERE weight>0 AND vote_id=?');
    while (my ($node_id) = $sth->fetchrow_array) {
        $vote_sth->execute($node_id);
        my ($count) = $vote_sth->fetchrow_array;
        $upvotes += ($count // 0);
    }

    # Heaven reputation
    my ($heaven_rep) = $DB->sqlSelect(
        'SUM(heaven.reputation)',
        'heaven',
        "heaven.type_nodetype=117 AND heaven.author_user=$uid"
    );
    $heaven_rep //= 0;
    $heaven_rep = 0 if $heaven_rep < 0;

    # Cool count
    my ($cool_count) = $DB->sqlSelect(
        'COUNT(*)',
        'node, coolwriteups',
        "node_id=coolwriteups_id AND node.author_user=$uid"
    );
    $cool_count //= 0;

    # Node heaven cool count
    my ($heaven_cool_count) = $DB->sqlSelect(
        'COUNT(*)',
        'coolwriteups, heaven',
        "coolwriteups_id=node_id AND author_user=$uid"
    );
    $heaven_cool_count //= 0;

    # Cached upvotes and cools
    my ($upcache, $coolcache) = $DB->sqlSelect(
        'upvotes, cools',
        'xpHistoryCache',
        "xpHistoryCache_id=$uid"
    );
    $upcache //= 0;
    $coolcache //= 0;

    my $total_upvotes = $upvotes + $upcache + $heaven_rep;
    my $total_cools = $cool_count + $coolcache + $heaven_cool_count;

    my $recalculated_xp = ($writeup_count * $WRITEUP_BONUS) + $total_upvotes + ($total_cools * $COOL_BONUS);

    my $gp_bonus = ($xp > $recalculated_xp) ? ($xp - $recalculated_xp) : 0;

    return {
        currentXP       => int($xp),
        writeupCount    => int($writeup_count),
        upvotesReceived => int($total_upvotes),
        coolsReceived   => int($total_cools),
        recalculatedXP  => int($recalculated_xp),
        gpBonus         => int($gp_bonus),
    };
}

__PACKAGE__->meta->make_immutable;

1;
