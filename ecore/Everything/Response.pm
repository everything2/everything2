package Everything::Response;

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use Plack::Response;
use Cookie::Baker qw(bake_cookie);

## no critic (ProhibitMagicNumbers ProhibitEscapedCharacters)

=head1 NAME

Everything::Response - the response authority for E2 (replaces CGI's response side)

=head1 DESCRIPTION

E2's response formatting (the page/header/cookie/redirect emission) used to run
through CGI.pm. This class owns it instead, with no CGI dependency:

  * a CGI-compatible adapter surface (C<cgi_header>, C<cgi_redirect>,
    C<format_cookie>) that produces byte-equivalent output to the old
    C<$query-E<gt>header(...)> / C<-E<gt>cookie(-name=E<gt>...)> calls, so the
    existing print/STDOUT-capture flow is a drop-in (Everything::Request::PlackQuery
    delegates to these);
  * a clean object surface (C<status>/C<content_type>/C<set_header>/C<set_cookie>/
    C<redirect>/C<body>) backed by L<Plack::Response>, plus C<finalize> (a real PSGI
    triple) -- the foundation for return-based responses that retire the STDOUT
    capture (see docs/api-driven-architecture.md).

Cookie + Set-Cookie formatting is delegated to L<Cookie::Baker> (the same
library Plack uses) -- value url-encoding matches CGI, and the C<+1y>/C<-1d>
relative expires are parsed for us. The expires date renders in Netscape
(dashed) form rather than CGI's RFC1123 (spaced) form; both are browser-valid
(byte-identity is not required). t/126 pins the equivalence.

=cut

# Strip a leading '-' and lowercase a cookie attribute name.
sub _norm_cookie_args {
    my @in = @_;
    my %out;
    while (@in) {
        my $k = shift @in;
        my $v = shift @in;
        ( my $nk = $k ) =~ s/^-//;
        $out{ lc $nk } = $v;
    }
    return %out;
}

=head2 format_cookie(-name => ..., -value => ..., -expires => ..., -path => ..., -samesite => ...)

Returns a Set-Cookie *value* string, byte-equivalent to CGI's C<cookie(...)>.
Class or instance method. Accepts CGI-style C<-key> or plain C<key> args.

=cut

sub format_cookie {
    my $self = shift;
    my %o    = _norm_cookie_args(@_);

    my $name = defined $o{name} ? $o{name} : '';
    my %spec;
    for my $k (qw(value path domain samesite httponly secure)) {
        $spec{$k} = $o{$k} if defined $o{$k};
    }
    # CGI used '' to mean "session cookie, no expiry"; Cookie::Baker wants the
    # key absent in that case.
    $spec{expires} = $o{expires} if defined $o{expires} && $o{expires} ne '';
    $spec{value} = '' unless defined $spec{value};

    return bake_cookie( $name, \%spec );
}

# Parse CGI-style header() args (a hashref or a list, -key or plain key) into a
# normalized structure.
sub _parse_header_args {
    my $self = shift;
    my %h = ( @_ == 1 && ref $_[0] eq 'HASH' ) ? %{ $_[0] } : @_;

    my %p = ( type => undef, status => undef, charset => undef,
        content_length => undef, content_encoding => undef, cookies => [], custom => [] );

    for my $k ( keys %h ) {
        ( my $nk = $k ) =~ s/^-//;
        my $lk = lc $nk;
        my $v  = $h{$k};
        next unless defined $v;
        if    ( $lk eq 'type' )    { $p{type}    = $v }
        elsif ( $lk eq 'status' )  { $p{status}  = $v }
        elsif ( $lk eq 'charset' ) { $p{charset} = $v }
        elsif ( $lk eq 'content_length' || $lk eq 'content-length' ) { $p{content_length} = $v }
        elsif ( $lk eq 'content_encoding' || $lk eq 'content-encoding' ) { $p{content_encoding} = $v }
        elsif ( $lk eq 'cookie' ) { push @{ $p{cookies} }, ref $v eq 'ARRAY' ? @$v : $v }
        elsif ( $lk eq 'nph' || $lk eq 'target' || $lk eq 'attachment' ) { next }    # CGI niceties E2 doesn't need
        else {
            # Custom header: underscores -> hyphens, preserve the rest of the case.
            ( my $hn = $nk ) =~ s/_/-/g;
            push @{ $p{custom} }, [ $hn, $v ];
        }
    }
    return \%p;
}

# Build the CGI-style header BLOCK ("Key: Value\r\n...\r\n\r\n") that the
# print/STDOUT-capture flow expects. Behaviourally equivalent to CGI's output
# for E2's calls (the served headers are clean UTF-8; Apache supplies Date).
sub cgi_header {
    my $self = shift;
    my $p    = $self->_parse_header_args(@_);

    my @lines;
    push @lines, 'Status: ' . $p->{status} if defined $p->{status};
    push @lines, 'Set-Cookie: ' . $_ for @{ $p->{cookies} };
    push @lines, $_->[0] . ': ' . $_->[1] for @{ $p->{custom} };
    push @lines, 'Content-Encoding: ' . $p->{content_encoding} if defined $p->{content_encoding};
    push @lines, 'Content-Length: ' . $p->{content_length} if defined $p->{content_length};

    my $type = defined $p->{type} ? $p->{type} : 'text/html';
    if ( defined $p->{charset} && length $p->{charset} && $type !~ /charset=/i ) {
        $type .= '; charset=' . $p->{charset};
    }
    push @lines, 'Content-Type: ' . $type;

    return join( "\r\n", @lines ) . "\r\n\r\n";
}

# CGI-style redirect() -> the redirect header block. Accepts -uri/-url/-location
# + -status (default 302) + custom headers (e.g. -Cache_Control).
sub cgi_redirect {
    my $self = shift;
    my %h = ( @_ == 1 && !ref $_[0] ) ? ( uri => $_[0] ) : ( @_ == 1 && ref $_[0] eq 'HASH' ) ? %{ $_[0] } : @_;

    my ( $uri, $status, @custom );
    for my $k ( keys %h ) {
        ( my $nk = $k ) =~ s/^-//;
        my $lk = lc $nk;
        my $v  = $h{$k};
        next unless defined $v;
        if    ( $lk eq 'uri' || $lk eq 'url' || $lk eq 'location' ) { $uri    = $v }
        elsif ( $lk eq 'status' )                                   { $status = $v }
        elsif ( $lk eq 'nph' )                                      { next }
        else { ( my $hn = $nk ) =~ s/_/-/g; push @custom, [ $hn, $v ] }
    }
    $status //= 302;

    my @lines = ( 'Status: ' . $status );
    push @lines, $_->[0] . ': ' . $_->[1] for @custom;
    push @lines, 'Location: ' . ( defined $uri ? $uri : '' );
    return join( "\r\n", @lines ) . "\r\n\r\n";
}

#############################################################################
# Clean object surface (Plack::Response-backed) -- the return-based future.
#############################################################################

has 'res' => (
    is      => 'ro',
    lazy    => 1,
    default => sub { Plack::Response->new(200) },
    handles => { status => 'status', body => 'body', finalize => 'finalize' },
);

sub content_type {
    my $self = shift;
    $self->res->content_type(@_) if @_;
    return $self->res->content_type;
}

sub set_header {
    my ( $self, $k, $v ) = @_;
    $self->res->header( $k => $v );
    return $self;
}

# Set a cookie on the response. $spec: { value, expires, path, samesite, ... }.
# Stored as the formatted Set-Cookie string (CGI-exact) so finalize and the
# capture path agree.
sub set_cookie {
    my ( $self, $name, $spec ) = @_;
    $spec = { value => $spec } unless ref $spec eq 'HASH';
    my $cookie = $self->format_cookie( -name => $name, %$spec );
    $self->res->headers->push_header( 'Set-Cookie' => $cookie );
    return $self;
}

sub redirect {
    my ( $self, $url, $status ) = @_;
    $self->res->redirect( $url, $status // 302 );
    return $self;
}

sub json {
    my ( $self, $data, $status ) = @_;
    $self->res->status( $status // 200 );
    $self->res->content_type('application/json; charset=utf-8');
    $self->res->body($data);   # caller encodes; kept symmetric with html()
    return $self;
}

sub html {
    my ( $self, $markup, $status ) = @_;
    $self->res->status( $status // 200 );
    $self->res->content_type('text/html; charset=utf-8');
    $self->res->body($markup);
    return $self;
}

=head2 from_cgi_parts(\%header_args, $body_bytes)

The return-based twin of C<cgi_header>: build a finalize-able response from the
same CGI-style header args that C<cgi_header> consumes (C<-type>/C<-status>/
C<-charset>/C<-cookie>/custom C<-Foo> keys), plus an already-encoded body. Where
C<cgi_header> emits a header-block *string* for the STDOUT-capture flow, this
populates a L<Plack::Response> whose C<finalize> is a real PSGI triple -- so the
API path can return a response that app.psgi finalizes directly, bypassing the
capture (the #4237 capture-poisoning class). Both consume the SAME parse
(C<_parse_header_args>), so the emitted fields are identical; t/131 pins it.

Class or instance method. C<\%header_args> may be a hashref or an arrayref of
pairs; C<$body_bytes> is the raw (already UTF-8-encoded) body, or undef for a
header-only response.

=cut

sub from_cgi_parts {
    my ( $proto, $args, $body ) = @_;
    my $self = ref $proto ? $proto : $proto->new;
    my @list = ref $args eq 'HASH' ? %$args : ref $args eq 'ARRAY' ? @$args : ();
    my $p    = $self->_parse_header_args(@list);
    my $r    = $self->res;

    # Status: CGI emits "Status: NNN"; the capture parser pulls the 3-digit code.
    # Mirror that (a bare integer or an "NNN Reason" string both reduce to NNN).
    my ($code) = defined $p->{status} ? $p->{status} =~ /(\d{3})/ : ();
    $r->status( $code || 200 );

    # Content-Type (+ charset) assembled exactly as cgi_header does.
    my $type = defined $p->{type} ? $p->{type} : 'text/html';
    if ( defined $p->{charset} && length $p->{charset} && $type !~ /charset=/i ) {
        $type .= '; charset=' . $p->{charset};
    }
    $r->content_type($type);

    $r->headers->push_header( 'Set-Cookie' => $_ ) for @{ $p->{cookies} };
    $r->header( $_->[0] => $_->[1] ) for @{ $p->{custom} };
    $r->header( 'Content-Encoding' => $p->{content_encoding} ) if defined $p->{content_encoding};
    $r->header( 'Content-Length'   => $p->{content_length} )   if defined $p->{content_length};

    $r->body($body) if defined $body;
    return $self;
}

__PACKAGE__->meta->make_immutable;

1;
