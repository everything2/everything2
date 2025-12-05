package Everything::Page::everything_s_best_users_xml_ticker;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::everything_s_best_users_xml_ticker - Everything's Best Users XML Ticker

=head1 DESCRIPTION

Returns XML listing the top 50 users by experience (excluding certain system/legacy users).
Includes experience, writeup count, level value and title.

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML listing Everything's best users by experience.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $USER = $REQUEST->user->NODEDATA;
    my $XG = $self->xml_generator;

    my $skip = {
        'dbrown'=>1,
        'nate'=>1,
        'Webster 1913'=>1,
        'ShadowLost'=>1,
        'EDB'=>1
    };

    my $limit = 50;

    $limit += (keys %$skip);

    my $csr = $self->DB->{dbh}->prepare('select node_id,title,experience,vars from user left join node on node_id=user_id left join setting on setting_id=user_id order by experience DESC limit '.$limit);

    return 'Ack! Something\'s broken...' unless($csr->execute);

    # Skip these users

    my $uid = $self->DB->getId($USER) || 0;
    my $user_node;
    my $step = 0;
    my $lvlexp_node = $self->DB->getNode('level experience', 'setting');
    my $lvlttl_node = $self->DB->getNode('level titles', 'setting');
    my $lvlexp = $self->APP->getVars($lvlexp_node);
    my $lvlttl = $self->APP->getVars($lvlttl_node);
    my $lvl;

    my $users = '';
    while($user_node = $csr->fetchrow_hashref) {

        next if(exists $$skip{$$user_node{title}});
        next if($step >= 50);

        $lvl = $self->APP->getLevel($user_node);
        my $V = $self->APP->getVars($user_node);

        $users .= $XG->bestuser(
            "\n " .
            $XG->experience($$user_node{experience}) .
            " " .
            $XG->writeups($$V{numwriteups}) .
            "\n " .
            $XG->e2link({node_id => $$user_node{node_id}}, $$user_node{title}) .
            "\n " .
            $XG->level({value => $self->APP->getLevel($user_node)}, $$V{level}) .
            "\n"
        ) . "\n";

        ++$step;
    }

    return qq{<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n} . $XG->EBU($users);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut
