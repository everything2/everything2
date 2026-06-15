package Everything::Request::PlackQuery;

use strict;
use warnings;
use Moose;
use namespace::autoclean;

## no critic (ProhibitBuiltinHomonyms)
# `delete` and `print` deliberately mirror the CGI query-object method names so
# this stays a drop-in; the homonyms are intentional, not bugs.

use Plack::Request;
use URI::Escape qw(uri_escape);
use Everything::Response;   # the response authority: header/redirect/cookie-gen.
                            # No CGI dependency remains in the request layer.

=head1 NAME

Everything::Request::PlackQuery - a Plack-backed drop-in for the CGI query object

=head1 DESCRIPTION

This replaces the C<CGI> object that used to back C<< Everything::Request->cgi >>
(and the C<$query> global). The request is parsed entirely by L<Plack::Request>
-- CGI.pm is out of the request path. The full set of CGI methods E2 actually
calls on the query object is reimplemented here over Plack:

  reads     param (first-value scalar / list / names), multi_param, Vars,
            cookie(read), request_method, script_name, path_info, url,
            user_agent
  mutation  param(set), delete, delete_all   (a CGI-faithful mutable param table)
  uploads   upload, uploadInfo               (Plack::Request uploads)
  util      escape
  output    header, redirect, print, cookie(gen), and the CGI form-helpers
            (hidden/submit/checkbox/textfield/start_form) -- delegated to an
            empty CGI used purely as a formatter.

Parity with CGI's read surface is pinned by t/123; this object's own surface
(first-value param, mutation, Vars \0-join, uploads, formatter delegation) is
pinned by t/124.

=cut

# The parsed request. Required -- always built from the PSGI env.
has 'req' => (is => 'ro', isa => 'Plack::Request', required => 1);

# CGI-faithful mutable per-request param table: { name => [values...] } plus an
# ordered name list. Initialized from Plack's parse (identical parsing, proven by
# t/123); thereafter param(set)/delete/delete_all mutate THIS, exactly as CGI
# mutates its own per-request table. This is not "emulating the mess" -- CGI's
# param table IS mutable and per-request; we mirror that contract over Plack.
has '_params' => (is => 'rw', isa => 'HashRef', lazy => 1, builder => '_build_params');
has '_order'  => (is => 'rw', isa => 'ArrayRef', lazy => 1, default => sub { [] });

sub _build_params
{
    my $self = shift;
    my @flat = $self->req->parameters->flatten;   # k,v,k,v... order preserved
    my (%tbl, @order);
    while (@flat) {
        my $k = shift @flat;
        my $v = shift @flat;
        push @order, $k unless exists $tbl{$k};
        push @{ $tbl{$k} }, $v;
    }
    $self->_order(\@order);
    return \%tbl;
}

#############################################################################
# READS + MUTATION (the mutable param table)
#############################################################################

# param()            -> list of parameter names (CGI order)
# param($name)       -> scalar: FIRST value (CGI scalar semantics); list: all
# param($name, @vs)  -> SET (replace); returns the new value(s)
sub param
{
    my $self = shift;

    unless (@_) {
        # No args: the parameter names. Touch _params so _order is populated.
        $self->_params;
        return @{ $self->_order };
    }

    my $name = shift;

    if (@_) {
        # SET. CGI accepts param(name => @values) or param(name => \@values).
        my @vals = @_;
        @vals = @{ $vals[0] } if @vals == 1 && ref($vals[0]) eq 'ARRAY';
        push @{ $self->_order }, $name unless exists $self->_params->{$name};
        $self->_params->{$name} = [@vals];
        return wantarray ? @vals : $vals[0];
    }

    # READ.
    my $vals = $self->_params->{$name};
    return wantarray ? () : undef unless $vals && @$vals;
    return wantarray ? @$vals : $vals->[0];
}

sub multi_param
{
    my $self = shift;
    # No args: the parameter names (CGI semantics, e.g. truncated_params).
    return $self->param unless @_;
    my $name = shift;
    return @{ $self->_params->{$name} || [] };
}

# CGI Vars: a hash of name => value, multi-values joined with \0. Returns the
# hash in list context, a hashref in scalar context (E2 uses both shapes).
sub Vars
{
    my $self = shift;
    $self->_params;
    my %out;
    for my $k (@{ $self->_order }) {
        # guard undef values in the param list (avoids an uninitialized warning
        # in join on multi-valued params that carry an undef element) (#4307)
        $out{$k} = join("\0", map { $_ // '' } @{ $self->_params->{$k} });
    }
    return wantarray ? %out : \%out;
}

sub delete
{
    my ($self, $name) = @_;
    delete $self->_params->{$name};
    $self->_order([ grep { $_ ne $name } @{ $self->_order } ]);
    return;
}

sub delete_all
{
    my $self = shift;
    $self->_params({});
    $self->_order([]);
    return;
}

#############################################################################
# REQUEST METADATA (straight from Plack)
#############################################################################

sub request_method { return $_[0]->req->method }
sub script_name    { return $_[0]->req->script_name }
sub path_info      { return $_[0]->req->path_info }
sub user_agent     { return $_[0]->req->user_agent }

# cookie('name')         -> read a cookie value (Plack)
# cookie(-name=>..., ...) -> GENERATE a Set-Cookie string (Everything::Response)
sub cookie
{
    my $self = shift;
    if (@_ == 1 && (!defined $_[0] || $_[0] !~ /^-/)) {
        return $self->req->cookies->{ $_[0] };
    }
    return Everything::Response->format_cookie(@_);
}

# CGI->url: no args -> full URL (no query string); -absolute=>1 -> the path.
# E2 uses url(-absolute=>1) (APIRouter routing) and url() (error logging).
sub url
{
    my ($self, %opts) = @_;
    my $req = $self->req;
    if ($opts{-absolute}) {
        my $p = $req->script_name . $req->path_info;
        $p = '/' if $p eq '';
        return $p;
    }
    # Full URL without the query string, to match CGI->url().
    return $req->base->as_string =~ s{/$}{}r . ( $req->path_info // '' );
}

#############################################################################
# UPLOADS (Plack::Request uploads; the homenode-image path, API/user.pm)
#############################################################################

# CGI->upload returned a filehandle that stringified to the filename and was
# passed to uploadInfo. With Plack we return the Plack::Request::Upload object,
# which exposes ->path / ->fh / ->content_type / ->filename / ->size. The one
# caller (API/user.pm) is migrated to that interface alongside this flip.
sub upload
{
    my ($self, $field) = @_;
    my $u = $self->req->uploads->{$field};
    return unless $u;
    return $u;
}

sub uploadInfo
{
    my ($self, $u) = @_;
    return unless ref($u) && $u->can('content_type');
    return { 'Content-Type' => $u->content_type };
}

#############################################################################
# OUTPUT (via Everything::Response -- the CGI-free response authority) + util
#############################################################################

sub header   { my $self = shift; return Everything::Response->cgi_header(@_); }
sub redirect { my $self = shift; return Everything::Response->cgi_redirect(@_); }
sub escape   { my $self = shift; return _uri_escape_e2( $_[0] ); }

# CGI::escape parity (UTF-8-encode wide strings only, then escape) -- see
# Everything::Application::_uri_escape_e2 for why both shapes must be handled.
sub _uri_escape_e2 {
    my $s = shift;
    return '' unless defined $s;
    utf8::encode($s) if utf8::is_utf8($s);
    return uri_escape($s);
}

# $query->print(...) wrote to the (selected) STDOUT, which under PSGI is the
# capture. Mirror that.
sub print    { my $self = shift; return CORE::print(@_); }

# Minimal HTML attribute-value escaper for the hand-rolled form-helpers below.
sub _esc {
    my $v = shift;
    $v = '' unless defined $v;
    $v =~ s/&/&amp;/g;
    $v =~ s/"/&quot;/g;
    $v =~ s/</&lt;/g;
    $v =~ s/>/&gt;/g;
    return $v;
}

# CGI form-helpers, hand-rolled (legacy htmlcode presentation: settings form,
# link-trimming admin tools, XSRF nonce). No CGI dependency. hidden() with no
# explicit value falls back to the request's own param (the CGI behaviour).
sub hidden {
    my ($self, $name, @vals) = @_;
    @vals = $self->multi_param($name) unless @vals;
    return join( '', map { '<input type="hidden" name="' . _esc($name) . '" value="' . _esc($_) . '" />' } @vals );
}

sub submit {
    my ($self, $name, $value) = @_;
    return '<input type="submit"'
        . ( defined $name  ? ' name="' . _esc($name) . '"'   : '' )
        . ( defined $value ? ' value="' . _esc($value) . '"' : '' )
        . ' />';
}

sub checkbox {
    my ($self, $name, $checked, $value, $label) = @_;
    $value = 'on' unless defined $value;
    my $input = '<input type="checkbox" name="' . _esc($name) . '" value="' . _esc($value) . '"'
        . ( $checked ? ' checked="checked"' : '' ) . ' />';
    return '<label>' . $input . ( defined $label && length $label ? _esc($label) : '' ) . '</label>';
}

sub textfield {
    my ($self, $name, $value, $size) = @_;
    return '<input type="text" name="' . _esc($name) . '" value="' . _esc($value) . '"'
        . ( defined $size ? ' size="' . _esc($size) . '"' : '' ) . ' />';
}

sub start_form {
    my ($self, %opts) = @_;
    my $action = defined $opts{-action} ? $opts{-action} : ( $opts{action} // '' );
    my $method = defined $opts{-method} ? $opts{-method} : ( $opts{method} // 'post' );
    return '<form method="' . _esc($method) . '" action="' . _esc($action) . '" enctype="multipart/form-data">';
}

sub end_form { return '</form>'; }

__PACKAGE__->meta->make_immutable;

1;
