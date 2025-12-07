package Everything::Page::cool_archive_atom_feed;

use Moose;
use utf8;

extends 'Everything::Page';

has 'mimetype' => (default => 'application/atom+xml', is => 'ro');

=head1 NAME

Everything::Page::cool_archive_atom_feed - Cool Archive Atom Feed

=head1 DESCRIPTION

Returns Atom feed for cool writeups with various sorting/filtering options.

Query parameters:
- foruser: Generate user-specific feed
- cooluser: Filter by user who cooled or wrote
- useraction: 'cooled' or 'written'
- orderby: Sort order (tstamp DESC, reputation DESC, etc.)

=head1 METHODS

=head2 display($REQUEST, $node)

Generates Atom feed for cool archive.

=cut

sub display {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;

    my $foruser = $query->param('foruser');
    my $str;
    if ($foruser) {
        $str = Everything::HTML::htmlcode('userAtomFeed', $foruser);
        return [$self->HTTP_OK, $str, {type => $self->mimetype}] if $str;
    }

    $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
    $str .= "<feed xmlns=\"http://www.w3.org/2005/Atom\" xml:base=\"http://everything2.com/\">\n";
    $str .= "    <title>Everything2 Cool Archive</title>\n";
    $str .= "    <link rel=\"alternate\" type=\"text/html\" href=\"http://everything2.com/?node=Cool%20Archive\" />\n";
    $str .= "    <link rel=\"self\" type=\"application/atom+xml\" href=\"?node=Cool%20Archive%20Atom%20Feed&amp;type=ticker\" />\n";
    $str .= "    <id>http://everything2.com/?node=Cool%20Archive%20Atom%20Feed</id>\n";
    $str .= "    <updated>";
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    $str .= sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);

    $str .= "</updated>\n";

    my $limit = 25;

    my $orderby = $query->param('orderby') // '';
    my $useraction = $query->param('useraction');
    my $place = $query->param('place');
    $place ||= 0;
    $useraction ||= '';

    my %orderhash = (
        'cooled DESC' => 'Most Cooled',
        'tstamp DESC' => 'Most Recently Cooled',
        'tstamp ASC' => 'Oldest Cooled',
        'title ASC' => 'Title(needs user)',
        'title DESC' => 'Title (Reverse)' ,
        'reputation DESC' => 'Highest Reputation',
        'reputation ASC' => 'Lowest Reputation'
    );

    $orderby = '' unless exists $orderhash{$orderby};

    $orderby ||= 'tstamp DESC';


    my $wherestr = 'node_id=coolwriteups_id and coolwriteups_id=writeup_id and cooled != 0';
    my $user = $query->param('cooluser');
    if($user) {
        my $U = $self->DB->getNode($user, 'user');
        return [$self->HTTP_OK, $str . "<br />Sorry, no '$user' is found on the system!</feed>", {type => $self->mimetype}] unless $U;

        if($useraction eq 'cooled') {
            $wherestr .= ' AND cooledby_user='.$self->DB->getId($U);
        } elsif ($useraction eq 'written') {
            $wherestr .= ' AND author_user='.$self->DB->getId($U);
        }
    } elsif($orderby =~ /^(title|reputation|cooled) (ASC|DESC)$/) {
        return [$self->HTTP_OK, $str . '<br />To sort by title, reputation, or number of C!s, a user name must be supplied.</feed>', {type => $self->mimetype}];
    }

    my $csr = $self->DB->sqlSelectMany('node.node_id as nodeid', 'coolwriteups, node, writeup', $wherestr, "order by $orderby limit $limit");
    return [$self->HTTP_OK, $str . "</feed>", {type => $self->mimetype}] unless $csr;


    while(my $row = $csr->fetchrow_hashref)
    {
        $str .= Everything::HTML::htmlcode('atomiseNode', $$row{nodeid});
    }

    $str.="</feed>\n";

    utf8::encode($str);
    return [$self->HTTP_OK, $str, {type => $self->mimetype}];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
