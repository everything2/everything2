package MockRequest;

use strict;
use warnings;
use MockUser;
use JSON;

=head1 NAME

MockRequest - Mock request object for API testing

=head1 SYNOPSIS

    use lib "$FindBin::Bin/lib";
    use MockRequest;

    my $request = MockRequest->new(
        node_id => 123,
        title => 'testuser',
        is_admin_flag => 1,
        postdata => { key => 'value' }
    );

    my $user = $request->user;
    my $data = $request->JSON_POSTDATA;

=head1 DESCRIPTION

MockRequest provides a lightweight mock implementation of the Everything::Request
interface for use in API tests. It wraps a MockUser and provides access to
POST data.

=head1 METHODS

=head2 new(%args)

Creates a new MockRequest instance. Accepts all MockUser arguments plus:

Additional Arguments:
    postdata - Hashref or string of POST data (default: {})
    request_method - HTTP method (default: 'GET')
    cookie - Hashref of cookies (default: undef)

All other arguments are passed through to MockUser->new().

Example:
    my $request = MockRequest->new(
        node_id => 123,
        title => 'testuser',
        is_guest_flag => 0,
        is_admin_flag => 1,
        postdata => { title => 'Test Node' }
    );

=cut

sub new {
    my ($class, %args) = @_;

    # Extract mock-specific arguments (don't delete vars - MockUser needs it too)
    my $postdata = delete $args{postdata} // {};
    my $request_method = delete $args{request_method} // 'GET';
    my $cookie = delete $args{cookie};
    my $query_params = delete $args{query_params} // {};
    my $vars = $args{vars} // {};  # Don't delete - pass to MockUser as well

    return bless {
        user => MockUser->new(%args),
        postdata => $postdata,
        request_method => $request_method,
        cookie => $cookie,
        query_params => $query_params,
        vars => $vars,
    }, $class;
}

=head2 user()

Returns the MockUser instance for this request.

Example:
    my $user = $request->user;
    if ($user->is_admin) {
        # Admin operations
    }

=cut

sub user {
    return shift->{user};
}

=head2 is_guest()

Convenience method that delegates to the user object.

Returns true if the request is from a guest user.

Example:
    if ($request->is_guest) {
        return [401, { error => 'Unauthorized' }];
    }

=cut

sub is_guest {
    return shift->{user}->is_guest;
}

=head2 set_postdata($data)

Sets the POST data for this request. Useful for testing multiple
operations with different data on the same request object.

Example:
    $request->set_postdata({ title => 'New Title' });

=cut

sub set_postdata {
    my ($self, $data) = @_;
    $self->{postdata} = $data;
}

=head2 JSON_POSTDATA()

Returns the POST data hashref for this request.

This simulates the parsed JSON POST data that would come from
a real HTTP request.

Example:
    my $data = $request->JSON_POSTDATA;
    my $title = $data->{title};

=cut

sub JSON_POSTDATA {
    return shift->{postdata};
}

=head2 POSTDATA()

Returns the raw POST data string for this request.

This simulates the raw request body that would come from
a real HTTP request, before JSON parsing.

Example:
    my $raw = $request->POSTDATA;
    my $data = JSON::decode_json($raw);

=cut

sub POSTDATA {
    my $self = shift;
    # If postdata is already a string, return it
    # Otherwise, it's a hashref from JSON_POSTDATA and we need to encode it
    return ref($self->{postdata}) ? JSON::encode_json($self->{postdata}) : $self->{postdata};
}

=head2 request_method()

Returns the HTTP request method (GET, POST, etc.).

Example:
    if ($request->request_method() eq 'POST') {
        # Handle POST
    }

=cut

sub request_method {
    return shift->{request_method};
}

=head2 VARS()

Returns the VARS hashref for this request.

Example:
    my $vars = $request->VARS;
    my $nodelets = $vars->{nodelets};

=cut

sub VARS {
    return shift->{vars};
}

=head2 param($name)

Returns a query parameter by name.

Example:
    my $offset = $request->param('offset');

=cut

sub param {
    my ($self, $name) = @_;
    return $self->{query_params}{$name};
}

=head2 cgi()

Returns a mock CGI object for cookie access.

Example:
    my $cookie = $request->cgi->cookie('cookiename');

=cut

sub cgi {
    my $self = shift;

    # Return a mock CGI object that supports cookie() and param() methods
    return bless {
        _cookies => $self->{cookie} || {},
        _params => $self->{query_params} || {}
    }, 'MockRequest::CGI';
}

package MockRequest::CGI;

sub cookie {
    my ($self, $name) = @_;
    return $self->{_cookies}{$name};
}

sub param {
    my ($self, $name) = @_;
    return $self->{_params}{$name};
}

package MockRequest;

=head1 USAGE EXAMPLES

=head2 Guest Request with No Data

    my $request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1
    );

=head2 Admin Request with POST Data

    my $request = MockRequest->new(
        node_id => 113,
        title => 'root',
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $root_hashref,
        postdata => {
            title => 'New E2node',
            createtime => time()
        }
    );

=head2 Request with Preference Updates

    my $request = MockRequest->new(
        node_id => 123,
        title => 'testuser',
        is_guest_flag => 0,
        vars => { vit_hidenodeinfo => 0 },
        postdata => {
            vit_hidenodeinfo => 1,
            collapsedNodelets => 'epicenter!'
        }
    );

=head2 Updating POST Data

Since postdata is just a hashref, you can update it directly:

    my $request = MockRequest->new(
        node_id => 123,
        title => 'testuser',
        is_guest_flag => 0
    );

    # Later in the test, change the POST data
    $request->{postdata} = { new_key => 'new_value' };

=head1 COMMON PATTERNS

=head2 Testing Authorization

    my $guest_request = MockRequest->new();  # Guest by default

    my $result = $api->some_method($guest_request);
    is($result->[0], $api->HTTP_UNAUTHORIZED, 'Guest gets 401');

=head2 Testing Input Validation

    my $request = MockRequest->new(
        node_id => 123,
        is_guest_flag => 0,
        postdata => { invalid_key => 'bad_value' }
    );

    my $result = $api->create($request);
    is($result->[0], $api->HTTP_BAD_REQUEST, 'Invalid input rejected');

=head2 Testing Permissions

    my $normal_request = MockRequest->new(
        node_id => 123,
        is_guest_flag => 0,
        is_admin_flag => 0
    );

    my $admin_request = MockRequest->new(
        node_id => 113,
        is_guest_flag => 0,
        is_admin_flag => 1
    );

    my $result1 = $api->delete($normal_request, $node_id);
    is($result1->[0], 403, 'Normal user cannot delete');

    my $result2 = $api->delete($admin_request, $node_id);
    is($result2->[0], 200, 'Admin can delete');

=head1 SEE ALSO

L<MockUser>, L<Everything::Request>

=head1 AUTHOR

Generated for Everything2 API testing infrastructure

=cut

1;
