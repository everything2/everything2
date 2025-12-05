package Everything::XMLTicker;

use Moose::Role;
use XML::Generator;

=head1 NAME

Everything::XMLTicker - Role for XML ticker Page classes

=head1 SYNOPSIS

    package Everything::Page::my_xml_ticker;
    use Moose;
    extends 'Everything::Page';
    with 'Everything::XMLTicker';

    sub generate_xml {
        my ($self, $REQUEST) = @_;
        my $XG = $self->xml_generator;
        return $XG->root($XG->item('content'));
    }

=head1 DESCRIPTION

This role provides common functionality for XML ticker Page classes:
- XML::Generator instance with proper configuration
- XML declaration helper
- Standard MIME type handling

=head1 ATTRIBUTES

=head2 xml_generator

Lazy-built XML::Generator instance used for generating XML content.

=cut

has 'xml_generator' => (
    is => 'ro',
    isa => 'XML::Generator',
    lazy => 1,
    default => sub { XML::Generator->new() }
);

=head1 METHODS

=head2 xml_header($version, $encoding)

Returns an XML declaration header.

    $self->xml_header();           # <?xml version="1.0"?>
    $self->xml_header('1.0', 'UTF-8');  # <?xml version="1.0" encoding="UTF-8"?>

=cut

sub xml_header {
    my ($self, $version, $encoding) = @_;
    $version ||= '1.0';

    my $declaration = qq{<?xml version="$version"};
    $declaration .= qq{ encoding="$encoding"} if $encoding;
    $declaration .= qq{?>\n};

    return $declaration;
}

=head2 display($REQUEST, $node)

Standard display method for XML tickers. Calls generate_xml() and returns
the XML with proper MIME type headers.

Subclasses should implement generate_xml() to produce XML content.

=cut

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $xml = $self->generate_xml($REQUEST, $node);

    return [
        $self->HTTP_OK,
        $xml,
        {type => $self->mimetype}
    ];
}

=head1 REQUIRED METHODS

Consuming classes must implement:

=head2 generate_xml($REQUEST)

Generate and return the XML content for this ticker.

    sub generate_xml {
        my ($self, $REQUEST) = @_;
        my $XG = $self->xml_generator;

        # Build XML content
        my $content = $XG->item('data');

        # Return with XML declaration
        return $self->xml_header() . $XG->root($content);
    }

=cut

requires 'generate_xml';

1;

=head1 SEE ALSO

L<Everything::Page>, L<XML::Generator>

=cut
