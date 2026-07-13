package Everything::API::caja_de_arena;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::caja_de_arena - admin report: homenodes of long-gone users (sibling of homenode_inspector)

=head1 DESCRIPTION

Admin tool for finding potentially spammy homenodes from users gone for a while (by default only
zero-writeup users). Moved out of C<Everything::Page::caja_de_arena>'s buildReactData (#4526): the
Page is a pure gate, React reads the filters off the URL and calls this.

  GET /api/caja_de_arena?gonesince=<n UNIT>&showlength=<n>&published=<0|1>&extlinks=<0|1>&page=<n>

Admin-only. Ships data + an error C<state> ('admin'); the copy lives in React. C<gonesince> is
re-parsed into a number + whitelisted unit before it reaches the DATE_SUB INTERVAL.

=cut

my %UNIT = map { $_ => uc } qw(year month week day);

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'admin' }] unless $USER->is_admin;

    # gonesince: "<n> <UNIT>". Re-parse into an int + a whitelisted unit; fall back to "1 YEAR".
    my $raw = $REQUEST->param('gonesince') || '1 YEAR';
    my ($gonesince, $gnum, $gunit);
    if ($raw =~ /^(\d+)\s+(year|month|week|day)$/i) {
        ($gnum, $gunit) = (int($1), $UNIT{lc($2)});
    } else {
        ($gnum, $gunit) = (1, 'YEAR');
    }
    $gonesince = "$gnum $gunit";

    my $showlength = int($REQUEST->param('showlength') // 1000);
    $showlength = 1000 if $showlength < 100 || $showlength > 5000;
    my $published = $REQUEST->param('published') ? 1 : 0;
    my $extlinks  = $REQUEST->param('extlinks') ? 1 : 0;
    my $page = int($REQUEST->param('page') || 1);
    $page = 1 if $page < 1;

    my $pole = $DB->getNode('The Old Hooked Pole', 'restricted_superdoc');
    my $pole_id = $pole ? int($pole->{node_id}) : undef;

    # $gnum is an int and $gunit is whitelisted -> injection-safe interpolation.
    my $filter = "doctext != ''";
    $filter .= " AND lasttime < DATE_SUB(NOW(), INTERVAL $gnum $gunit)";
    $filter .= " AND numwriteups = 0" unless $published;
    $filter .= " AND doctext LIKE '%[http%'" if $extlinks;

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
            gonesince => $gonesince, showlength => $showlength,
            published => $published, extlinks => $extlinks,
        },
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
