package Everything::Page::the_recommender;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::the_recommender - Bookmark-based writeup recommendation engine

=head1 DESCRIPTION

"The Recommender" is a recommendation system that finds writeups you might like
based on your bookmarks and the cooling patterns of users with similar taste.

Unlike "Do you C! what I C?" which requires the user to have cooled writeups,
The Recommender uses bookmarks which are accessible to everyone.

Algorithm:
1. Pick up to 100 things you've bookmarked (e2nodes or writeups)
2. Find everyone who has cooled those things (top 20 "best friends")
3. Find writeups that have been cooled by your "best friends" the most
4. Show top 10 that you haven't voted on and have less than maxcools C!s

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns recommendation data based on user's bookmark history.

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
    my $num_bookmarks = 100;
    my $num_friends = 20;
    my $num_writeups = 10;

    # Get the bookmark linktype ID
    my $bookmark_linktype = $DB->getNode('bookmark', 'linktype');
    return {
        error => 'system_error',
        message => 'Could not find bookmark linktype'
    } unless $bookmark_linktype;

    my $linktype_id = $bookmark_linktype->{node_id};

    # Step 1: Get random sample of user's bookmarked writeups
    # Bookmarks can link to either writeups directly or to e2nodes (parent of writeups)
    # We need to find the writeups in either case
    my $bookmark_list = $DB->sqlSelectMany(
        "writeup.writeup_id",
        "links INNER JOIN writeup ON writeup.parent_e2node = links.to_node OR writeup.writeup_id = links.to_node",
        "links.from_node = $target_user_id AND links.linktype = $linktype_id",
        "ORDER BY RAND() LIMIT $num_bookmarks"
    );

    unless ($bookmark_list && $bookmark_list->rows) {
        return {
            error => 'no_bookmarks',
            pronoun => $pronoun,
            target_user => $target_user_title,
            maxcools => $maxcools
        };
    }

    my @writeup_ids = ();
    while (my $w = $bookmark_list->fetchrow_hashref) {
        push @writeup_ids, $w->{writeup_id};
    }
    my $writeup_str = join(',', @writeup_ids);

    # Step 2: Find "best friends" - users who cooled the bookmarked writeups
    my $user_list = $DB->sqlSelectMany(
        "COUNT(cooledby_user) as ucount, cooledby_user",
        "coolwriteups",
        "coolwriteups_id IN ($writeup_str) AND cooledby_user != $target_user_id",
        "GROUP BY cooledby_user ORDER BY ucount DESC LIMIT $num_friends"
    );

    unless ($user_list && $user_list->rows) {
        return {
            error => 'no_friends',
            pronoun => $pronoun,
            target_user => $target_user_title,
            maxcools => $maxcools,
            num_bookmarks_sampled => scalar(@writeup_ids)
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
        next if $APP->hasVoted($node, $user->NODEDATA);
        next if $node->{author_user} == 176726;  # Don't show Webster 1913's writeups
        next if ($node->{cooled} || 0) > $maxcools;

        my $parent = $DB->getNodeById($node->{parent_e2node});

        push @recommendations, {
            node_id => $node->{node_id},
            title => $node->{title},
            parent_title => $parent ? $parent->{title} : '',
            parent_id => $parent ? $parent->{node_id} : 0,
            cooled => $node->{cooled} || 0,
            coolcount => $r->{coolcount}
        };

        $count++;
        last if $count >= $num_writeups;
    }

    return {
        recommendations => \@recommendations,
        target_user => $target_user_title,
        target_username => $target_username,
        pronoun => $pronoun,
        maxcools => $maxcools,
        num_bookmarks_sampled => scalar(@writeup_ids),
        num_friends => scalar(@friend_ids)
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>
L<Everything::Page::do_you_c_what_i_c>

=cut
