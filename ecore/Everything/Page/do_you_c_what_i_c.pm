package Everything::Page::do_you_c_what_i_c;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::do_you_c_what_i_c - Cool-based writeup recommendation engine

=head1 DESCRIPTION

"Do you C! what I C?" is a recommendation system that finds writeups you might like
based on your cooling patterns and the cooling patterns of users with similar taste.

Algorithm:
1. Pick up to 100 things you've cooled
2. Find everyone else who has cooled those things (top 20 "best friends")
3. Find writeups that have been cooled by your "best friends" the most
4. Show top 10 that you haven't voted on and have less than maxcools C!s

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns recommendation data based on user's cooling history.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $query = $REQUEST->cgi;
    my $user = $REQUEST->user;

    # Parameters
    my $target_username = $query->param('cooluser') || '';
    my $maxcools = $query->param('maxcools') || 10;

    # Validate maxcools
    unless ($maxcools =~ /^\d+$/ && $maxcools > 0 && $maxcools <= 100) {
        $maxcools = 10;
    }

    my $target_user_id = $user->NODEDATA->{user_id};
    my $pronoun = 'You';
    my $target_user_title = $user->title;

    # Handle custom user lookup
    if ($target_username) {
        my $target_user = $DB->getNode($target_username, 'user');
        unless ($target_user) {
            return {
                type => 'do_you_c_what_i_c',
                error => 'user_not_found',
                target_username => $target_username,
                maxcools => $maxcools
            };
        }
        $target_user_id = $target_user->{user_id};
        $pronoun = 'They';
        $target_user_title = $target_user->{title};
    }

    # Constants
    my $num_cools = 100;
    my $num_friends = 20;
    my $num_writeups = 10;

    # Step 1: Get random sample of user's cools
    my $cool_list = $DB->sqlSelectMany(
        'coolwriteups_id',
        'coolwriteups',
        "cooledby_user=$target_user_id",
        "ORDER BY RAND() LIMIT $num_cools"
    );

    unless ($cool_list->rows) {
        return {
            type => 'do_you_c_what_i_c',
            error => 'no_cools',
            pronoun => $pronoun,
            target_user => $target_user_title,
            maxcools => $maxcools
        };
    }

    my @cool_ids = ();
    while (my $c = $cool_list->fetchrow_hashref) {
        push @cool_ids, $c->{coolwriteups_id};
    }
    my $cool_str = join(',', @cool_ids);

    # Step 2: Find "best friends" - users who also cooled those writeups
    my $user_list = $DB->sqlSelectMany(
        "count(cooledby_user) as ucount, cooledby_user",
        "coolwriteups",
        "coolwriteups_id IN ($cool_str) AND cooledby_user != $target_user_id",
        "GROUP BY cooledby_user ORDER BY ucount DESC LIMIT $num_friends"
    );

    unless ($user_list->rows) {
        return {
            type => 'do_you_c_what_i_c',
            error => 'no_friends',
            pronoun => $pronoun,
            target_user => $target_user_title,
            maxcools => $maxcools
        };
    }

    my @friend_ids = ();
    while (my $u = $user_list->fetchrow_hashref) {
        push @friend_ids, $u->{cooledby_user};
    }
    my $friend_str = join(',', @friend_ids);

    # Step 3: Find recommended writeups cooled by best friends
    # Find writeups that: 1) user hasn't cooled, 2) user didn't author, 3) were cooled by friends
    my $rec_set = $DB->sqlSelectMany(
        "COUNT(coolwriteups_id) as coolcount, coolwriteups_id",
        "coolwriteups",
        "(SELECT COUNT(*) FROM coolwriteups AS c1 WHERE c1.coolwriteups_id = coolwriteups.coolwriteups_id AND c1.cooledby_user = $target_user_id) = 0 " .
        "AND (SELECT author_user FROM node WHERE node_id = coolwriteups_id) != $target_user_id " .
        "AND cooledby_user IN ($friend_str)",
        "GROUP BY coolwriteups_id HAVING coolcount > 1 ORDER BY coolcount DESC LIMIT 300"
    );

    my @recommendations = ();
    my $count = 0;

    while (my $r = $rec_set->fetchrow_hashref) {
        my $node = $DB->getNodeById($r->{coolwriteups_id});
        next unless $node;
        next unless $node->{type}{title} eq 'writeup';
        next if $APP->hasVoted($node, $user);
        next if $node->{author_user} == 176726;  # Don't show Webby's writeups
        next if $node->{cooled} > $maxcools;

        my $parent = $DB->getNodeById($node->{parent_e2node});

        push @recommendations, {
            node_id => $node->{node_id},
            title => $node->{title},
            parent_title => $parent ? $parent->{title} : '',
            parent_id => $parent ? $parent->{node_id} : 0,
            cooled => $node->{cooled},
            coolcount => $r->{coolcount}
        };

        $count++;
        last if $count >= $num_writeups;
    }

    return {
        type => 'do_you_c_what_i_c',
        recommendations => \@recommendations,
        target_user => $target_user_title,
        pronoun => $pronoun,
        maxcools => $maxcools,
        num_cools_sampled => scalar(@cool_ids),
        num_friends => scalar(@friend_ids)
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
