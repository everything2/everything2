package Everything::API::polls;

use Moose;
use namespace::autoclean;
use JSON;
extends 'Everything::API';

=head1 NAME

Everything::API::polls - Poll listing and management API

=head1 DESCRIPTION

Handles listing and management of e2poll nodes.

=head1 ENDPOINTS

=head2 GET /api/polls/list

List polls with filtering and pagination.

Query parameters:
- status: filter by poll_status ('new', 'current', 'closed', or 'active' for non-closed)
- startat: pagination offset (default: 0)
- limit: number of polls to return (default: 8 for directory, 10 for archive)

Response (JSON):
{
    "success": 1,
    "polls": [{
        "poll_id": 123,
        "title": "Poll title",
        "question": "The poll question",
        "poll_author": {
            "node_id": 456,
            "title": "author username"
        },
        "poll_status": "new|current|closed",
        "totalvotes": 42,
        "options": ["Option 1", "Option 2", ...],
        "results": [10, 15, ...],
        "user_vote": 0 (or null if not voted)
    }, ...],
    "has_more": true/false,
    "total": 123
}

=head2 POST /api/polls/set_current

Set a poll as the current poll (admin only).

Request body (JSON):
{
    "poll_id": 123
}

=cut

sub routes {
    return {
        '/list'        => 'list_polls',
        '/set_current' => 'set_current_poll',
        '/delete'      => 'delete_poll'
    };
}

sub list_polls {
    my ( $self, $REQUEST ) = @_;

    my $DB   = $self->DB;
    my $USER = $REQUEST->user->NODEDATA;

    # Get query parameters
    my $status = $REQUEST->param('status')
      || 'active';    # 'active', 'new', 'current', 'closed'
    my $startat = int( $REQUEST->param('startat') || 0 );
    my $limit   = int( $REQUEST->param('limit')   || 8 );

    # Build filter
    my $filter = {};
    if ( $status eq 'active' ) {

        # Active = not closed (for Directory)
        $filter = { 'poll_status !' => 'closed' };
    }
    elsif ( $status eq 'closed' ) {

        # Closed polls (for Archive)
        $filter = { poll_status => 'closed' };
    }
    elsif ( $status =~ /^(new|current)$/ ) {
        $filter = { poll_status => $status };
    }

    # Get polls with pagination
    my @polls = $DB->getNodeWhere( $filter, 'e2poll',
        "e2poll_id DESC LIMIT $startat, $limit" );

    # Get total count for pagination
    my $where_clause = '';
    if ( $status eq 'active' ) {
        $where_clause = "poll_status != 'closed'";
    }
    elsif ( $status =~ /^(new|current|closed)$/ ) {
        $where_clause = "poll_status = '$status'";
    }
    my ($total) = $DB->sqlSelect( 'COUNT(*)', 'e2poll', $where_clause );

    # Format poll data for JSON
    my @formatted_polls;
    foreach my $poll (@polls) {
        my $poll_id = $poll->{node_id};

        # Get user's vote if exists
        my ($user_vote) = $DB->sqlSelect( 'choice', 'pollvote',
            "voter_user=$USER->{node_id} AND pollvote_id=$poll_id" );

        # Get poll author
        my $author = $DB->getNodeById( $poll->{poll_author} );

        # Parse options from doctext
        # Handle both legacy format (single \n) and new format (double \n\n)
        my $doctext = $poll->{doctext} || '';
        my @options = split /\s*\n+\s*/, $doctext;

        # Parse results (comma-separated vote counts)
        my @results = split /,/, ( $poll->{e2poll_results} || '' );

        push @formatted_polls,
          {
            poll_id     => $poll_id,
            title       => $poll->{title},
            question    => $poll->{question},
            poll_author => {
                node_id => $author->{node_id},
                title   => $author->{title}
            },
            poll_status => $poll->{poll_status},
            totalvotes  => $poll->{totalvotes} || 0,
            options     => \@options,
            results     => \@results,
            user_vote   => defined($user_vote) ? int($user_vote) : undef
          };
    }

    my $has_more =
      ( scalar(@polls) == $limit && ( $startat + $limit ) < $total );

    return [
        $self->HTTP_OK,
        {
            success  => 1,
            polls    => \@formatted_polls,
            has_more => $has_more,
            total    => int($total),
            startat  => $startat,
            limit    => $limit
        }
    ];
}

sub set_current_poll {
    my ( $self, $REQUEST ) = @_;

    # Check admin permission
    my $APP  = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;

    return [
        $self->HTTP_OK,
        {
            success => 0,
            error   => 'Admin access required'
        }
      ]
      unless $APP->isAdmin($USER);

    my $postdata = $REQUEST->POSTDATA();
    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };

    return [
        $self->HTTP_OK,
        {
            success => 0,
            error   => 'Invalid JSON'
        }
      ]
      unless $json_ok && $data;

    my $poll_id = $data->{poll_id};

    return [
        $self->HTTP_OK,
        {
            success => 0,
            error   => 'poll_id required'
        }
      ]
      unless $poll_id;

    my $DB = $self->DB;

    # Verify poll exists
    my $poll = $DB->getNodeById($poll_id);
    return [
        $self->HTTP_OK,
        {
            success => 0,
            error   => 'Poll not found'
        }
      ]
      unless $poll && $poll->{type}{title} eq 'e2poll';

    # Close current poll(s)
    $DB->sqlUpdate( 'e2poll', { poll_status => 'closed' },
        "poll_status='current'" );

    # Set new current poll
    $DB->sqlUpdate( 'e2poll', { poll_status => 'current' },
        "e2poll_id=$poll_id" );

    # Add notification
    $APP->add_notification( 'e2poll', '', { e2poll_id => $poll_id } );

    return [
        $self->HTTP_OK,
        {
            success => 1,
            message => 'Poll set as current',
            poll_id => $poll_id
        }
    ];
}

sub delete_poll {
    my ( $self, $REQUEST ) = @_;

    # Check admin permission
    my $APP  = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;

    return [
        $self->HTTP_OK,
        {
            success => 0,
            error   => 'Admin access required'
        }
      ]
      unless $APP->isAdmin($USER);

    my $postdata = $REQUEST->POSTDATA();
    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };

    return [
        $self->HTTP_OK,
        {
            success => 0,
            error   => 'Invalid JSON'
        }
      ]
      unless $json_ok && $data;

    my $poll_id = $data->{poll_id};

    return [
        $self->HTTP_OK,
        {
            success => 0,
            error   => 'poll_id required'
        }
      ]
      unless $poll_id;

    my $DB = $self->DB;

    # Verify poll exists
    my $poll = $DB->getNodeById($poll_id);
    return [
        $self->HTTP_OK,
        {
            success => 0,
            error   => 'Poll not found'
        }
      ]
      unless $poll && $poll->{type}{title} eq 'e2poll';

    # Delete all votes for this poll
    $DB->sqlDelete( 'pollvote', "pollvote_id=$poll_id" );

    # Delete the poll node
    my $result = $DB->nukeNode( $poll, -1 );

    return [
        $self->HTTP_OK,
        {
            success => 1,
            message => 'Poll deleted successfully',
            poll_id => $poll_id
        }
    ];
}

__PACKAGE__->meta->make_immutable;

1;
