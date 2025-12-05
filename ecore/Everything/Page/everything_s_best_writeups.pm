package Everything::Page::everything_s_best_writeups;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::StaffOnly';

=head1 NAME

Everything::Page::everything_s_best_writeups - Everything's Best Writeups (Most Cooled)

=head1 DESCRIPTION

Shows the top 50 writeups by cooled count. Editor+ access only.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with most cooled writeups.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;

    # Query top 50 most cooled writeups
    my $sql = qq{
        SELECT writeup_id, cooled
        FROM writeup
        ORDER BY cooled DESC
        LIMIT 50
    };

    my $dbh = $DB->getDatabaseHandle();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my @writeups;
    while (my $row = $sth->fetchrow_hashref()) {
        my $writeup = $DB->getNodeById($row->{writeup_id});
        next unless $writeup;

        my $parent = $DB->getNodeById($writeup->{parent_e2node});
        my $author = $DB->getNodeById($writeup->{author_user});

        push @writeups, {
            writeup_id => $writeup->{node_id},
            writeup_title => $writeup->{title},
            parent_id => $parent ? $parent->{node_id} : 0,
            parent_title => $parent ? $parent->{title} : '',
            author_id => $author ? $author->{node_id} : 0,
            author_title => $author ? $author->{title} : '',
            cooled => $row->{cooled} || 0
        };
    }

    $sth->finish();

    return {
        type => 'everything_s_best_writeups',
        writeups => \@writeups
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
