package Everything::API::homenode_inspector;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::homenode_inspector - admin report: homenodes of long-gone, low-writeup users

=head1 DESCRIPTION

Admin tool for finding potentially spammy homenodes -- users inactive for a while with few writeups,
optionally only those with external links. Moved out of C<Everything::Page::homenode_inspector>'s
buildReactData (#4526): the Page is a pure gate, React reads the filters off the URL and calls this.

  GET /api/homenode_inspector?gonetime=<n>&goneunit=<year|month|week|day>&maxwus=<n>&showlength=<n>&extlinks=<0|1>&dotstoo=<0|1>&page=<n>

Admin-only. Ships data + an error C<state> ('admin' / 'param'); the copy lives in React. C<goneunit>
is whitelisted (it's interpolated into a DATE_SUB INTERVAL).

=cut

my %GONEUNIT = map { $_ => uc } qw(year month week day);   # lowercased input -> canonical SQL unit

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'admin' }] unless $USER->is_admin;

    my $gonetime   = $REQUEST->param('gonetime');
    $gonetime = 0 if defined($gonetime) && $gonetime eq '0';
    $gonetime //= 0;
    my $goneunit   = lc($REQUEST->param('goneunit') || 'month');
    my $showlength = $REQUEST->param('showlength') // 1000;
    my $maxwus     = $REQUEST->param('maxwus') // 0;
    my $extlinks   = $REQUEST->param('extlinks') ? 1 : 0;
    my $dotstoo    = $REQUEST->param('dotstoo') ? 1 : 0;
    my $page       = $REQUEST->param('page') || 1;

    unless ("$maxwus" =~ /^\d+$/ && "$gonetime" =~ /^\d+$/ && "$showlength" =~ /^\d+$/ && $GONEUNIT{$goneunit}) {
        return [$self->HTTP_OK, { success => 0, state => 'param' }];
    }

    $maxwus     = int($maxwus);
    $gonetime   = int($gonetime);
    $showlength = int($showlength);
    $page       = int($page);
    $page = 1 if $page < 1;
    my $unit = $GONEUNIT{$goneunit};   # canonical, whitelisted SQL keyword

    my $pole = $DB->getNode('The Old Hooked Pole', 'restricted_superdoc');
    my $pole_id = $pole ? int($pole->{node_id}) : undef;

    # All interpolated values are ints or the whitelisted $unit -> injection-safe.
    my $filter = "doctext != ''";
    $filter .= " AND lasttime < DATE_SUB(NOW(), INTERVAL $gonetime $unit)";
    $filter .= " AND numwriteups <= $maxwus";
    $filter .= " AND doctext LIKE '%[http%'" if $extlinks;
    $filter .= " AND doctext != '...'" unless $dotstoo;

    my $from = 'node JOIN user ON node_id=user_id JOIN document ON node_id=document_id';
    my $total = $DB->sqlSelect('COUNT(*)', $from, $filter) || 0;

    my $per_page = 10;
    my $offset = ($page - 1) * $per_page;
    my $csr = $DB->sqlSelectMany(
        'title, node_id, user_id AS author_user, doctext', $from, $filter,
        "ORDER BY lasttime DESC LIMIT $offset, $per_page"
    );

    my @items;
    while (my $row = $csr->fetchrow_hashref) {
        my $doctext = $row->{doctext} || '';
        my $truncated = length($doctext) > $showlength ? substr($doctext, 0, $showlength) . '...' : $doctext;
        push @items, {
            node_id     => int($row->{node_id}),
            title       => $row->{title},
            doctext     => $truncated,
            full_length => length($doctext),
        };
    }
    $csr->finish;

    return [$self->HTTP_OK, {
        success     => 1,
        items       => \@items,
        total       => int($total),
        per_page    => $per_page,
        total_pages => int(($total + $per_page - 1) / $per_page),
        page        => $page,
        pole_id     => $pole_id,
        filters     => {
            gonetime => $gonetime, goneunit => $unit, showlength => $showlength,
            maxwus => $maxwus, extlinks => $extlinks, dotstoo => $dotstoo,
        },
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
