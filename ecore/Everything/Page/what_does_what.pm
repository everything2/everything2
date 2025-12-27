package Everything::Page::what_does_what;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::StaffOnly';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $DB = $self->DB;

  # Get documentation settings
  my $doc_setting = $self->APP->node_by_name('superdoc documentation', 'setting');
  my $documentation = $doc_setting ? $self->APP->getVars($doc_setting->NODEDATA) : {};
  $documentation ||= {};

  # Determine which types to show (admins get more)
  my @types = ('superdoc', 'oppressor_superdoc');
  push @types, ('restricted_superdoc', 'setting') if $self->APP->isAdmin($REQUEST->user);

  my @sections;

  foreach my $type_name (@types) {
    my $type = $DB->getType($type_name);
    next unless $type;

    my $csr = $DB->sqlSelectMany(
      'node_id',
      'node',
      "type_nodetype = $type->{node_id}",
      'ORDER BY title'
    );

    my @nodes;
    while (my $row = $csr->fetchrow_hashref) {
      my $node = $self->APP->node_by_id($row->{node_id});
      next unless $node;

      push @nodes, {
        node_id => $node->id,
        title => $node->title,
        documentation => $documentation->{$node->id} || undef
      };
    }

    # Get the type-specific documentation setting for edit link
    my $type_doc_setting = $self->APP->node_by_name("$type_name documentation", 'setting');

    push @sections, {
      type => $type_name,
      nodes => \@nodes,
      docSettingId => $type_doc_setting ? $type_doc_setting->id : undef
    };
  }

  # Get the main documentation setting node for edit link
  my $main_doc_id = $doc_setting ? $doc_setting->id : undef;

  return {
    sections => \@sections,
    mainDocSettingId => $main_doc_id,
    isAdmin => $self->APP->isAdmin($REQUEST->user) ? \1 : \0
  };
}

__PACKAGE__->meta->make_immutable;

1;
