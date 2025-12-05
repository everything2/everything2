package Everything::Page::new_writeups_atom_feed;

use Moose;
use utf8;

extends 'Everything::Page';

has 'mimetype' => (default => 'application/atom+xml', is => 'ro');

=head1 NAME

Everything::Page::new_writeups_atom_feed - New Writeups Atom Feed

=head1 DESCRIPTION

Returns Atom feed for recent writeups, filtered by user preferences.

Query parameters:
- foruser: Generate user-specific feed

=head1 METHODS

=head2 display($REQUEST, $node)

Generates Atom feed for new writeups.

=cut

sub display {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;

    my $foruser = $query->param('foruser');
    $foruser =~ s/'/&#39;/g if $foruser;
    my $str;
    if ($foruser) {
        $str = Everything::HTML::htmlcode('userAtomFeed', $foruser);
        return [$self->HTTP_OK, $str, {type => $self->mimetype}] if $str;
    }

    my $newwriteups = $self->APP->filtered_newwriteups($USER, 25);
    $str = "<updated>";
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime;
    $str .= sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
    $str .= "</updated>\n";

    my $node_ids = [];
    foreach my $wu (@$newwriteups) {
        push @$node_ids, $wu->{node_id};
    }

    $str .= Everything::HTML::htmlcode( 'atomiseNode' , $node_ids);

    my $feed = '<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://everything2.com">
<title>Everything2 New Writeups</title>
<link rel="alternate" type="text/html" href="https://everything2.com/node/superdoc/Writeups+by+Type"/>
<link rel="self" type="application/atom+xml" href="https://everything2.com/node/ticker/New+Writeups+Atom+Feed"/>
<id>https://everything2.com/?node=New%20Writeups%20Atom%20Feed</id>
' .
$str . '
</feed>';

    return [$self->HTTP_OK, $feed, {type => $self->mimetype}];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
