package Everything::API::everything_publication_directory;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::everything_publication_directory - E2 Publications debate directory

=head1 DESCRIPTION

Lists the Publications debates, most-recently-commented first. Moved out of
C<Everything::Page::everything_publication_directory>'s buildReactData (#4557): the Page is a pure
gate, so this API is the real boundary.

The node is an C<oppressor_superdoc>, whose type default is editor-only, but this page has always
carried its own narrower gate in code -- C<thepub> usergroup OR admin -- so that is what is enforced
here. The type rule is the fallback for pages that dropped their gate; an explicit gate wins.
Each debate is additionally filtered through C<isApproved> against its own restricted group (passed
the user's NODEDATA hashref), so a member only sees the debates their groups can
read.

  GET /api/everything_publication_directory

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;

    # Both predicates take the NODEDATA hashref (codebase convention for Application predicates).
    unless ($APP->inUsergroup($user->NODEDATA, 'thepub') || $APP->isAdmin($user->NODEDATA)) {
        return [$self->HTTP_OK, { success => 0, state => 'permission' }];
    }

    # Debate roots carrying restricted=114, newest comment first.
    my $csr = $DB->sqlSelectMany(
        'root_debatecomment', 'debatecomment', 'restricted=114', 'ORDER BY debatecomment_id DESC');

    my (%seen, @debate_ids);
    while (my $row = $csr->fetchrow_hashref) {
        my $root_id = $row->{root_debatecomment};
        next if $seen{$root_id}++;
        push @debate_ids, $root_id;
    }

    # 3/7/2026 from 2026-03-07 -- the legacy display format, preserved.
    my $fmt = sub {
        my ($ts) = @_;
        return '' unless defined $ts;
        $ts =~ s/^(\d+)-(\d+)-(\d+).*$/$2\/$3\/$1/;
        $ts =~ s/(^|\/)0/$1/g;
        return $ts;
    };

    my @debates;
    foreach my $debate_id (@debate_ids) {
        my $debate = $DB->getNodeById($debate_id);
        next unless $debate;

        my $restricted_id = $debate->{restricted} || 923653;
        $restricted_id = 114 if $restricted_id == 1;   # backwards compatibility
        my $restricted_group = $DB->getNodeById($restricted_id, 'light');

        # isApproved takes the NODEDATA hashref, not the blessed user.
        next unless $DB->isApproved($user->NODEDATA, $restricted_group);

        my $author = $DB->getNodeById($debate->{author_user}, 'light');

        my $latest_comment_id = $DB->sqlSelect(
            'MAX(debatecomment_id)', 'debatecomment', "root_debatecomment=" . int($debate_id));
        my $latest_time = '';
        if ($latest_comment_id) {
            my $latest = $DB->getNodeById($latest_comment_id, 'light');
            $latest_time = $fmt->($latest->{createtime}) if $latest;
        }

        push @debates, {
            node_id          => int($debate->{node_id}),
            title            => $debate->{title},
            author_id        => $author ? int($author->{node_id}) : 0,
            author_title     => $author ? $author->{title} : 'Unknown',
            created          => $fmt->($debate->{createtime}),
            latest_time      => $latest_time || '(none)',
            restricted_id    => $restricted_group ? int($restricted_group->{node_id}) : 0,
            restricted_title => $restricted_group ? $restricted_group->{title} : 'thepub',
        };
    }

    # can_create was a hardcoded 1 -- the create affordance is React config now (the real gate is
    # /api/node/create), so it does not ship from here.
    return [$self->HTTP_OK, { success => 1, debates => \@debates }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
