package Everything::Page::recalculate_xp;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

use Readonly;
Readonly my $WRITEUP_BONUS => 5;
Readonly my $COOL_BONUS => 20;
Readonly my $CUTOFF_NODE_ID => 1960662;  # October 29, 2008

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $USER = $REQUEST->user;
    my $VARS = $USER->VARS;

    my $is_admin = $USER->is_admin;

    # Check eligibility (for the current user)
    my $can_recalculate = 1;
    my $ineligible_reason = '';

    if ($USER->node_id > $CUTOFF_NODE_ID) {
        $can_recalculate = 0;
        $ineligible_reason = 'This service is only needed by and available to users who joined E2 prior to October 29, 2008. Your XP was earned under the present system.';
    } elsif ($VARS->{hasRecalculated}) {
        $can_recalculate = 0;
        $ineligible_reason = 'Our records show that you have already recalculated your XP. You are only allowed to recalculate your XP once.';
    }

    # Get stats for current user
    my $stats = $self->_get_user_stats($USER->node_id);

    return {
        recalculateXp => {
            isAdmin          => $is_admin ? \1 : \0,
            canRecalculate   => $can_recalculate ? \1 : \0,
            ineligibleReason => $ineligible_reason,
            username         => $USER->title,
            currentXP        => $stats->{currentXP},
            writeupCount     => $stats->{writeupCount},
            upvotesReceived  => $stats->{upvotesReceived},
            coolsReceived    => $stats->{coolsReceived},
            recalculatedXP   => $stats->{recalculatedXP},
            gpBonus          => $stats->{gpBonus},
            writeupBonus     => $WRITEUP_BONUS,
            coolBonus        => $COOL_BONUS,
        }
    };
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

    # Cached upvotes and cools from deleted stuff
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
