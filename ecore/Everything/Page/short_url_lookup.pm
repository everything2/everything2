package Everything::Page::short_url_lookup;

use Moose;
extends 'Everything::Page';
with 'Everything::HTTP';

=head1 Everything::Page::short_url_lookup

Short URL redirect handler. Decodes a short URL string and issues a 302 redirect
to the target node. Uses 302 (not 303 or 301) to prevent browser caching.

If the short URL is valid, redirects to the target node.
If invalid or the node doesn't exist, redirects to the "nothing found" page.

=cut

# Character set for base-49 encoding (excludes similar-looking characters)
my @ENCODE_CHARS = qw/
    a   c d e f   h     k   m n o     r s t u   w x   z
    A B C D E F G H   J K L M N   P Q R   T U V W X Y Z
      2 3 4     7 8 9
/;

my %DECODE_CHARS;
for my $i (0 .. $#ENCODE_CHARS) {
    $DECODE_CHARS{$ENCODE_CHARS[$i]} = $i;
}

sub _decode_short_string {
    my ($self, $short_string) = @_;

    return unless defined $short_string && $short_string ne '';

    my $base = scalar(@ENCODE_CHARS);
    my $result = 0;

    for my $char (split //, $short_string) {
        my $char_value = $DECODE_CHARS{$char};
        return unless defined $char_value;  # Invalid character
        $result = $result * $base + $char_value;
    }

    return $result;
}

# Override display() to always return a redirect response
sub display {
    my ($self, $REQUEST) = @_;

    my $short_string = $REQUEST->param('short_string') // '';
    my $node_id = $self->_decode_short_string($short_string);

    if ($node_id) {
        my $target_node = $self->APP->node_by_id($node_id);

        if ($target_node) {
            # Valid short URL - return 302 redirect (not cached by browsers)
            my $redirect_url = $target_node->canonical_url;
            return [$self->HTTP_FOUND, '', {'Location' => $redirect_url}];
        }
    }

    # Invalid or node doesn't exist - redirect to nothing found page
    # Use 302 to prevent browser caching in case the node is created later
    my $not_found_node_id = $Everything::CONF->not_found_node;
    my $not_found_node = $self->APP->node_by_id($not_found_node_id);
    my $not_found_url = $not_found_node ? $not_found_node->canonical_url : '/';

    return [$self->HTTP_FOUND, '', {'Location' => $not_found_url}];
}

# buildReactData is no longer called since display() always redirects
sub buildReactData {
    my ($self, $REQUEST) = @_;
    return {};
}

__PACKAGE__->meta->make_immutable;

1;
