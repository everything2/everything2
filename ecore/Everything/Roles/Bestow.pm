package Everything::Roles::Bestow;

use Moose::Role;

# Shared server-side logic for the "bestow" admin tools (#4497, Refs #4298). Pilot for the
# vertical per-module rationalization: the genuinely server-side work a Page and its API twin
# both need lives here, so the Page stops reaching into storage and the lookup exists once.
#
# websterbless is the first member. superbless / xp_superbless fold in next -- they share the
# "bless a recipient" write (adjustGP + karma + checkAchievementsByType + securityLog, visible
# in Everything::API::superbless), which lands here with that migration.
#
# Consumers must provide DB() and APP() (Everything::Page and Everything::API both do, via Globals).
requires qw(DB APP);

# --- websterbless reads ----------------------------------------------------

# The Webster 1913 user node. Shared by the page (for webster_id / the profile link) and the
# API (as the PM sender). getNode is NodeBase-cached, so repeated calls in a request are cheap;
# Webster 1913 is a nodepack-pinned account, so the by-name lookup resolves to a stable node.
sub webster_user {
    my ($self) = @_;
    return $self->DB->getNode('Webster 1913', 'user');
}

# How many messages Webster 1913 has received -- the "N corrections" count the page links to.
sub webster_message_count {
    my ($self) = @_;
    my $webster = $self->webster_user or return 0;
    return $self->DB->sqlSelect('COUNT(*)', 'message', "for_user=$webster->{node_id}") || 0;
}

# The websterbless page's read payload: { webster_id, msg_count }, or { error } if the Webster
# 1913 account is missing. This is the data the page used to assemble inline off $DB; the page
# now just gates + calls this + adds the prefill param.
sub webster_payload {
    my ($self) = @_;
    my $webster = $self->webster_user
        or return { error => 'Webster 1913 user not found in database.' };
    return {
        webster_id => $webster->{node_id},
        msg_count  => $self->webster_message_count,
    };
}

# --- shared bless-write -----------------------------------------------------

# Bump a recipient's karma by $delta, persist it, and run the karma achievement check -- the
# shared "bless a recipient's karma" write behind superbless grant_gp/grant_xp and the
# websterbless thank-you (#4500). $delta of 0 is a no-op (matches the old `if $signum != 0`
# guard in the grant paths). $target is a raw user hashref (the APIs work in hashrefs).
# Returns the new karma total.
sub award_karma {
    my ($self, $target, $delta) = @_;
    return $target->{karma} unless $delta;
    $target->{karma} = ($target->{karma} || 0) + $delta;
    $self->DB->updateNode($target, -1);
    $self->APP->checkAchievementsByType('karma', $target->{user_id});
    return $target->{karma};
}

1;
