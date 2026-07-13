package Everything::API::recent_node_notes;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::recent_node_notes - recent node notes (editorial feedback), filterable + paginated

=head1 DESCRIPTION

Staff report: the most recent node notes, optionally only the viewer's own or with automated
lifecycle breadcrumbs hidden. Moved out of C<Everything::Page::recent_node_notes>'s buildReactData
(#4528): the Page is a pure gate, React reads the toggles/page off the URL and calls this.

  GET /api/recent_node_notes?onlymynotes=<0|1>&hidesystemnotes=<0|1>&page=<n>

Editor-only (the page carried C<Everything::Security::StaffOnly>). Ships data only; the copy for the
gate lives in React.

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'staff' }] unless $USER->is_editor;

    my $onlymynotes = ($REQUEST->param('onlymynotes')) ? 1 : 0;
    # "Hide automated notes" defaults ON; an explicit hidesystemnotes=0 turns it off.
    my $hs = $REQUEST->param('hidesystemnotes');
    my $hidesystemnotes = defined($hs) ? ($hs ? 1 : 0) : 1;
    my $page = int($REQUEST->param('page') || 0);
    $page = 0 if $page < 0;

    my $where = "1=1 ";
    if ($onlymynotes) {
        $where = "(noter_user=" . $USER->node_id . " OR notetext like " . $DB->quote("[" . $USER->title . "]%") . ")";
    } elsif ($hidesystemnotes) {
        $where = "noter_user != 0 AND " . $APP->nodenote_editorial_sql;
    }

    my $from = "nodenote JOIN node ON node.node_id = nodenote.nodenote_nodeid";
    my $total = $DB->sqlSelect("count(*)", $from, $where);

    my $limit = 50;
    my $startat = $page * $limit;
    my $csr = $DB->sqlSelectMany("nodenote.*, node.title", $from,
        $where . " ORDER by nodenote.timestamp DESC LIMIT $startat,$limit");

    my @notes;
    while (my $row = $csr->fetchrow_hashref) {
        my $noter_user = $row->{noter_user} // 0;
        my $noter;
        if ($noter_user > 1) {
            my $nu = $DB->getNodeById($noter_user);
            $noter = $nu->{title} if $nu;
        }
        my $is_auto = ($noter_user == 0) || $APP->nodenote_is_lifecycle($row->{notetext});

        push @notes, {
            node      => { node_id => int($row->{nodenote_nodeid}), title => $row->{title} },
            timestamp => $row->{timestamp},
            note      => $row->{notetext},
            noter     => $noter,
            kind      => $is_auto ? 'auto' : 'editorial',
        };
    }

    return [$self->HTTP_OK, {
        success         => 1,
        onlymynotes     => $onlymynotes,
        hidesystemnotes => $hidesystemnotes,
        total           => int($total),
        page            => $page,
        perpage         => $limit,
        notes           => \@notes,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
