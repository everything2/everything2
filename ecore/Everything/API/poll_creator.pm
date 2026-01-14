package Everything::API::poll_creator;

use Moose;
use namespace::autoclean;
use JSON;
use Encode qw(decode_utf8);
extends 'Everything::API';

=head1 NAME

Everything::API::poll_creator - Poll creation API

=head1 DESCRIPTION

Handles creation of new e2poll nodes.

=head1 ENDPOINTS

=head2 POST /api/poll_creator/create

Create a new poll.

Request body (JSON):
{
    "title": "Poll title",
    "question": "The poll question",
    "options": ["Option 1", "Option 2", ...]
}

=cut

sub routes {
    return {
        '/create' => 'create_poll'
    };
}

sub create_poll {
    my ($self, $REQUEST) = @_;

    # Guests can't create polls
    return [$self->HTTP_OK, {
        success => 0,
        error => 'You must be logged in to create polls'
    }] if $REQUEST->user->is_guest;

    # do NOT decode_utf8 - decode_json expects UTF-8 bytes
    my $postdata = $REQUEST->POSTDATA;

    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };
    return [$self->HTTP_OK, {
        success => 0,
        error => 'invalid_json'
    }] unless $json_ok && $data;

    my $title = $data->{title} || '';
    my $question = $data->{question} || '';
    my $options_ref = $data->{options} || [];

    # Validation
    return [$self->HTTP_OK, {
        success => 0,
        error => 'Poll title is required'
    }] unless $title =~ /\S/;

    return [$self->HTTP_OK, {
        success => 0,
        error => 'Poll question is required'
    }] unless $question =~ /\S/;

    return [$self->HTTP_OK, {
        success => 0,
        error => 'At least 2 answer options are required'
    }] unless @$options_ref >= 2;

    # Check title length
    return [$self->HTTP_OK, {
        success => 0,
        error => 'Poll title must be 64 characters or less'
    }] if length($title) > 64;

    # Check question length
    return [$self->HTTP_OK, {
        success => 0,
        error => 'Question must be 255 characters or less'
    }] if length($question) > 255;

    # Check each option length
    for my $opt (@$options_ref) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Each option must be 255 characters or less'
        }] if length($opt) > 255;
    }

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;

    # Clean the title
    my $clean_title = $APP->cleanNodeName($title);

    # Check for duplicate title
    my $existing = $DB->getNode($clean_title, 'e2poll');
    return [$self->HTTP_OK, {
        success => 0,
        error => "A poll with the title '$clean_title' already exists"
    }] if $existing;

    # Get e2poll type
    my $poll_type = $DB->getType('e2poll');
    return [$self->HTTP_OK, {
        success => 0,
        error => 'e2poll node type not found'
    }] unless $poll_type;

    # Create the poll node
    # Poll options are stored as newline-separated text in document.doctext
    # "None of the above" is automatically added
    # Skip maintenance (5th param = 1) to avoid e2poll_create which requires CGI query params

    # Build options text (double newline-separated, matches legacy maintenance)
    my @filled_options = grep { $_ =~ /\S/ } @$options_ref;
    push @filled_options, 'None of the above';
    my $options_text = join("\n\n", @filled_options);

    # Initialize vote counts (all zeros, comma-separated)
    my $vote_count = scalar(@filled_options);
    my $initial_results = join(',', ('0') x $vote_count);

    # Create the node with skip_maintenance=1 (matches seeds.pl pattern)
    my $poll_id = $DB->insertNode($clean_title, $poll_type, $USER, {}, 1);

    unless ($poll_id) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Failed to create poll node'
        }];
    }

    # Get the poll node and set the poll_author to creator
    my $poll_node = $DB->getNodeById($poll_id);

    # Set poll_author to creator, then transfer ownership to Content Editors
    # (matches legacy e2poll_create maintenance behavior)
    my $content_editors = $DB->getNode('Content Editors', 'usergroup');

    # Use sqlUpdate to set all poll fields directly (avoid maintenance)
    $DB->sqlUpdate('e2poll', {
        question => $question,
        e2poll_results => $initial_results,
        poll_status => 'new',
        poll_author => $USER->{node_id}
    }, "e2poll_id = $poll_id");

    # Update node author to Content Editors
    $DB->sqlUpdate('node', {
        author_user => $content_editors->{node_id}
    }, "node_id = $poll_id");

    # Set the poll options in document table
    $DB->sqlUpdate('document', {
        doctext => $options_text
    }, "document_id = $poll_id");

    return [$self->HTTP_OK, {
        success => 1,
        poll_id => $poll_id,
        poll_title => $clean_title,
        message => 'Poll created successfully. It will appear in the poll queue.'
    }];
}

around ['create_poll'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;

1;
