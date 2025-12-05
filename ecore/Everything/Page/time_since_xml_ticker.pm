package Everything::Page::time_since_xml_ticker;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::time_since_xml_ticker - Time Since XML Ticker

=head1 DESCRIPTION

Returns XML showing current server time and last seen time for users.

Supports query parameters:
- user: Comma-separated list of usernames
- user_id: Comma-separated list of user IDs
- (defaults to current user if no params)

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML with server time and user last-seen times.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;
    my $XG = $self->xml_generator;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    $year+=1900;
    $mon+=1;

    $mon = sprintf("%02d", $mon);
    $mday = sprintf("%02d", $mday);
    $hour = sprintf("%02d", $hour);
    $min = sprintf("%02d", $min);
    $sec = sprintf("%02d", $sec);

    my $now = "$year-$mon-$mday $hour:$min:$sec";
    my @users;

    if($query->param("user"))
    {
        push @users, $self->DB->getNode($_, "user") foreach(split(',',$query->param("user")));
    }elsif($query->param("user_id"))
    {
        push @users, $self->DB->getNodeById($_) foreach(split(",",$query->param("user_id")));
    }else
    {
        @users = ($USER);
    }

    my $user_list = '';
    foreach(@users){
        next unless($_ and $$_{type}{title} eq "user");
        $user_list .= $XG->user(
            {lasttime => $$_{lasttime}},
            "\n" . $XG->e2link({node_id => $$_{node_id}}, $$_{title}) . "\n"
        );
    }

    return $self->xml_header() . $XG->timesince(
        $XG->now($now) . "\n" .
        $XG->lasttimes("\n" . $user_list) . "\n"
    );
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut
