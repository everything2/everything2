package Everything::API::recommendations;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::recommendations - "people like you also cooled" writeup recommendations

=head1 DESCRIPTION

Backs both recommendation documents, which run the same algorithm and differ only in the initial
"signal" (#4539):

  * signal=cool     -- "Do you C! what I C?" -- seeds from the target's cools
  * signal=bookmark -- "The Recommender"     -- seeds from the target's bookmarks

Algorithm: sample up to 100 of the target's signalled writeups; find the 20 users who most cooled
those ("best friends"); recommend the writeups those friends cooled that the target hasn't cooled
and didn't author, capped at C<maxcools> C!s.

  GET /api/recommendations?signal=cool|bookmark&cooluser=<name>&maxcools=<n>

Public. Ships data + an error C<state> ('user_not_found' / 'no_signal' / 'no_friends' /
'system_error'); the copy lives in React.

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    my $signal = $REQUEST->param('signal') || 'cool';
    $signal = 'cool' unless $signal eq 'cool' || $signal eq 'bookmark';

    my $target_username = $REQUEST->param('cooluser');
    $target_username = defined($target_username) ? $target_username : '';

    my $maxcools = $REQUEST->param('maxcools') || 10;
    $maxcools = 10 unless $maxcools =~ /^\d+$/ && $maxcools > 0 && $maxcools <= 100;

    my $target_user_id    = $user->NODEDATA->{user_id};
    my $pronoun           = 'You';
    my $target_user_title = $user->title;

    if ($target_username ne '') {
        my $target = $DB->getNode($target_username, 'user');
        return [$self->HTTP_OK, {
            success => 0, state => 'user_not_found',
            target_username => $target_username, maxcools => int($maxcools),
        }] unless $target;
        $target_user_id    = $target->{user_id};
        $pronoun           = 'They';
        $target_user_title = $target->{title};
    }
    $target_user_id = int($target_user_id);

    my $num_signal  = 100;
    my $num_friends = 20;
    my $num_writeups = 10;

    my $no_signal = sub {
        return [$self->HTTP_OK, {
            success => 0, state => 'no_signal', signal => $signal,
            pronoun => $pronoun, target_user => $target_user_title, maxcools => int($maxcools),
        }];
    };

    # --- Step 1: the target's signalled writeups (the only signal-specific query) ---
    my @signal_ids;
    if ($signal eq 'bookmark') {
        my $bookmark_linktype = $DB->getNode('bookmark', 'linktype');
        return [$self->HTTP_OK, { success => 0, state => 'system_error' }] unless $bookmark_linktype;
        my $linktype_id = int($bookmark_linktype->{node_id});
        # Bookmarks can point at a writeup directly or at its parent e2node.
        my $csr = $DB->sqlSelectMany(
            'writeup.writeup_id',
            'links INNER JOIN writeup ON writeup.parent_e2node = links.to_node OR writeup.writeup_id = links.to_node',
            "links.from_node = $target_user_id AND links.linktype = $linktype_id",
            "ORDER BY RAND() LIMIT $num_signal"
        );
        return $no_signal->() unless $csr && $csr->rows;
        while (my $w = $csr->fetchrow_hashref) { push @signal_ids, $w->{writeup_id}; }
    }
    else {
        my $csr = $DB->sqlSelectMany(
            'coolwriteups_id', 'coolwriteups',
            "cooledby_user=$target_user_id", "ORDER BY RAND() LIMIT $num_signal"
        );
        return $no_signal->() unless $csr && $csr->rows;
        while (my $c = $csr->fetchrow_hashref) { push @signal_ids, $c->{coolwriteups_id}; }
    }
    my $signal_str = join(',', map { int($_) } @signal_ids);

    # --- Step 2: "best friends" -- users who most cooled those writeups (shared) ---
    my $user_list = $DB->sqlSelectMany(
        'count(cooledby_user) as ucount, cooledby_user', 'coolwriteups',
        "coolwriteups_id IN ($signal_str) AND cooledby_user != $target_user_id",
        "GROUP BY cooledby_user ORDER BY ucount DESC LIMIT $num_friends"
    );
    return [$self->HTTP_OK, {
        success => 0, state => 'no_friends', pronoun => $pronoun,
        target_user => $target_user_title, maxcools => int($maxcools),
        num_signal_sampled => scalar(@signal_ids),
    }] unless $user_list && $user_list->rows;

    my @friend_ids;
    while (my $u = $user_list->fetchrow_hashref) { push @friend_ids, $u->{cooledby_user}; }
    my $friend_str = join(',', map { int($_) } @friend_ids);

    # --- Step 3: writeups those friends cooled that the target hasn't (shared) ---
    my $rec_set = $DB->sqlSelectMany(
        'COUNT(coolwriteups_id) as coolcount, coolwriteups_id', 'coolwriteups',
        "(SELECT COUNT(*) FROM coolwriteups AS c1 WHERE c1.coolwriteups_id = coolwriteups.coolwriteups_id AND c1.cooledby_user = $target_user_id) = 0 " .
        "AND (SELECT author_user FROM node WHERE node_id = coolwriteups_id) != $target_user_id " .
        "AND cooledby_user IN ($friend_str)",
        "GROUP BY coolwriteups_id HAVING coolcount > 1 ORDER BY coolcount DESC LIMIT 300"
    );

    my @recommendations;
    my $count = 0;
    while (my $r = $rec_set->fetchrow_hashref) {
        my $node = $DB->getNodeById($r->{coolwriteups_id});
        next unless $node;
        next unless $node->{type}{title} eq 'writeup';
        next if $APP->hasVoted($node, $user->NODEDATA);
        next if $node->{author_user} == 176726;              # skip Webster 1913's bot writeups
        next if ($node->{cooled} || 0) > $maxcools;

        my $parent = $DB->getNodeById($node->{parent_e2node});
        push @recommendations, {
            node_id      => int($node->{node_id}),
            title        => $node->{title},
            parent_title => $parent ? $parent->{title} : '',
            parent_id    => $parent ? int($parent->{node_id}) : 0,
            cooled       => int($node->{cooled} || 0),
            coolcount    => int($r->{coolcount}),
        };
        $count++;
        last if $count >= $num_writeups;
    }

    return [$self->HTTP_OK, {
        success            => 1,
        signal             => $signal,
        recommendations    => \@recommendations,
        target_user        => $target_user_title,
        pronoun            => $pronoun,
        maxcools           => int($maxcools),
        num_signal_sampled => scalar(@signal_ids),
        num_friends        => scalar(@friend_ids),
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
