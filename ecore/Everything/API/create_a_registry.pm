package Everything::API::create_a_registry;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::create_a_registry - the create-registry gate (level 8+)

=head1 DESCRIPTION

Reports whether the caller may create a registry (level 8+) and their current level, so the React
form can show itself, the level warning, or the guest message. Moved out of
C<Everything::Page::create_a_registry>'s buildReactData (#4550): the Page is a pure gate; the
input-style options are React config now.

  GET  /api/create_a_registry           -- the gate (can_create / current_level)
  POST /api/create_a_registry/create    -- create the registry

Creation lives here rather than on the generic C<POST /api/node/create> because a registry needs its
own fields set (C<input_style>, and the description in C<document.doctext>). The generic endpoint
only takes type+title and silently dropped both, so a registry created through it always came back
as a free-text one no matter which answer style you picked (#4554). Keeping the generic endpoint
generic also avoids letting callers write arbitrary type columns through it.

This route is also the real level-8 boundary: C<POST /api/node/create> checks only canCreateNode, so
the level rule was advisory (React hid the form; a direct POST still worked).

=cut

# The answer styles a registry may be created with. Whitelisted -- input_style is written to the
# registry row, so never take the client's string on trust. 'text' is the free-text default, which
# Everything::Controller::registry also falls back to when the column is NULL/empty.
my @INPUT_STYLES = qw(text yes/no date);

sub routes { return { "/" => "list", "/create" => "create_registry" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;

    my $level_required = 8;
    my $level = $APP->getLevel($user->NODEDATA);

    return [$self->HTTP_OK, {
        success        => 1,
        can_create     => ($level >= $level_required ? \1 : \0),
        current_level  => int($level),
        level_required => $level_required,
    }];
}

sub create_registry {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;

    my $level_required = 8;
    return [$self->HTTP_OK, { success => 0, state => 'permission', level_required => $level_required }]
        if $APP->getLevel($user->NODEDATA) < $level_required;

    my $data        = $REQUEST->JSON_POSTDATA || {};
    my $title       = defined $data->{title} ? $data->{title} : '';
    my $description = defined $data->{description} ? $data->{description} : '';
    my $input_style = defined $data->{input_style} ? $data->{input_style} : 'text';

    $title =~ s/^\s+|\s+$//g;
    return [$self->HTTP_OK, { success => 0, error => 'A title is required' }] unless length $title;

    return [$self->HTTP_OK, { success => 0, error => 'Unknown answer style' }]
        unless grep { $_ eq $input_style } @INPUT_STYLES;

    my $type = $DB->getType('registry');
    return [$self->HTTP_OK, { success => 0, error => 'registry node type not found' }] unless $type;

    my $clean_title = $APP->cleanNodeName($title, 1);
    return [$self->HTTP_OK, { success => 0, error => "A registry called '$clean_title' already exists" }]
        if $DB->getNode($clean_title, 'registry');

    my $node_id = $DB->insertNode($clean_title, $type, $user->node_id);
    return [$self->HTTP_OK, { success => 0, error => 'Failed to create the registry' }] unless $node_id;

    # Set the registry-specific fields the generic node-create endpoint could not. Go through
    # updateNode (not raw sqlUpdate): registry extends document, so this writes both tables and
    # keeps the node cache/version consistent -- the same path tools/seeds.pl uses for its
    # registries. input_style is whitelisted above.
    $node_id = int($node_id);
    my $node = $DB->getNodeById($node_id, 'force');
    if ($node) {
        $node->{input_style} = $input_style;
        $node->{doctext}     = $description;
        $DB->updateNode($node, -1);
    }

    return [$self->HTTP_OK, {
        success     => 1,
        node_id     => $node_id,
        title       => $clean_title,
        input_style => $input_style,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
