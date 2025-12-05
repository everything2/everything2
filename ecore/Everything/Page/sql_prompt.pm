package Everything::Page::sql_prompt;

use Moose;
extends 'Everything::Page';

use Time::HiRes qw(gettimeofday tv_interval);
use Everything::HTML;

=head1 NAME

Everything::Page::sql_prompt - SQL Query Interface for Administrators

=head1 DESCRIPTION

Restricted superdoc that provides a SQL query interface for root-level administrators.
Includes error handling, multiple output formats, and execution timing.

Only accessible to: root, jaybonci

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with SQL query form and results.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $query = $REQUEST->cgi;
    my $user = $REQUEST->user;
    my $VARS = $REQUEST->VARS;

    # Strict access control - only specific users
    my $username = $user->title;
    my $is_authorized = 0;
    foreach my $allowed_user ('jaybonci', 'root') {
        if ($allowed_user eq $username) {
            $is_authorized = 1;
            last;
        }
    }

    unless ($is_authorized) {
        return {
            type => 'sql_prompt',
            error => 'unauthorized',
            message => 'You really really shouldn\'t be playing with this.'
        };
    }

    # Get form parameters
    my $sql_query = $query->param('sqlquery') || '';
    my $hide_results = $query->param('hideresults') || 0;

    # Handle format style - read from form if submitted, otherwise from saved vars
    my $format_style = $query->param('sqlprompt_wrap');
    if (defined $format_style) {
        # Save to user vars for persistence
        $VARS->{sqlprompt_wrap} = $format_style;
        $DB->updateNode($user, -1);
    } else {
        $format_style = $VARS->{sqlprompt_wrap} || 0;
    }

    # Get current node
    my $node = $REQUEST->node;
    my $node_id = $node ? $DB->getId($node) : 0;

    # Initialize response
    my $response = {
        type => 'sql_prompt',
        node_id => $node_id,
        formatStyle => $format_style,
        hideResults => $hide_results,
    };

    # If no query submitted, return form only
    unless ($sql_query) {
        return $response;
    }

    # Execute SQL query with error handling
    my $results = $self->execute_query($sql_query, {
        hide_results => $hide_results,
    });

    $response->{query} = $sql_query;
    $response->{results} = $results;

    return $response;
}

=head2 execute_query($sql, $options)

Executes SQL query and returns formatted results with error handling.

=cut

sub execute_query {
    my ($self, $sql, $options) = @_;

    my $DB = $self->DB;
    my $dbh = $DB->getDatabaseHandle();

    # Start timing
    my @start = gettimeofday;

    # Save original DBI error handling settings
    my $old_print_error = $dbh->{PrintError};
    my $old_raise_error = $dbh->{RaiseError};

    # Disable DBI error printing - we'll handle errors ourselves
    $dbh->{PrintError} = 0;
    $dbh->{RaiseError} = 0;

    # Prepare query with error handling
    my $cursor;
    my $prepare_ok = eval {
        local $SIG{__WARN__} = sub { return };  # Suppress warnings
        $cursor = $dbh->prepare($sql);
        1;  # Return true if successful
    };

    if (!$prepare_ok || !$cursor) {
        my $error_msg = $@ || $dbh->errstr || 'Unknown error';
        # Restore DBI error handling settings
        $dbh->{PrintError} = $old_print_error;
        $dbh->{RaiseError} = $old_raise_error;
        return {
            error => 1,
            error_type => 'prepare',
            message => "Bad SQL: $error_msg",
            elapsed_time => tv_interval(\@start, [gettimeofday])
        };
    }

    # Execute query with error handling
    my $execute_result;
    my $execute_ok = eval {
        local $SIG{__WARN__} = sub { return };  # Suppress warnings
        $execute_result = $cursor->execute();
        1;  # Return true if successful
    };

    if (!$execute_ok || !$execute_result) {
        my $error_msg = $@ || $dbh->errstr || 'Query execution failed';
        # Restore DBI error handling settings
        $dbh->{PrintError} = $old_print_error;
        $dbh->{RaiseError} = $old_raise_error;
        return {
            error => 1,
            error_type => 'execute',
            message => $error_msg,
            elapsed_time => tv_interval(\@start, [gettimeofday])
        };
    }

    # Restore DBI error handling settings after successful execution
    $dbh->{PrintError} = $old_print_error;
    $dbh->{RaiseError} = $old_raise_error;

    # Get results
    my $row_count = $cursor->rows();
    my @rows = ();
    my @columns = ();
    my $rows_fetched = 0;

    # Fetch all rows unless hidden
    unless ($options->{hide_results}) {
        # Get column names in order from DBI
        @columns = @{$cursor->{NAME}} if $cursor->{NAME};

        while (my $row = $cursor->fetchrow_hashref()) {

            # Process row data
            my $processed_row = {};
            foreach my $col (@columns) {
                my $value = $row->{$col};

                # Handle nulls and encode HTML
                if (defined $value) {
                    $value = Everything::HTML::encodeHTML($value, 1);

                    # Auto-linkify node IDs (columns ending in _id or _user)
                    if ($col =~ /_/ && $value =~ /^\d+$/) {
                        $processed_row->{$col} = {
                            value => $value,
                            is_node_id => 1
                        };
                    } else {
                        $processed_row->{$col} = {
                            value => $value,
                            is_node_id => 0
                        };
                    }
                } else {
                    $processed_row->{$col} = {
                        value => undef,
                        is_null => 1
                    };
                }
            }

            push @rows, $processed_row;
            $rows_fetched++;
        }
    }

    $cursor->finish();

    # Calculate elapsed time
    my $elapsed_time = tv_interval(\@start, [gettimeofday]);

    # Return results
    return {
        error => 0,
        columns => \@columns,
        rows => \@rows,
        row_count => $row_count,
        rows_fetched => $rows_fetched,
        elapsed_time => sprintf('%.4f', $elapsed_time),
        affected_rows => ($cursor->{Active} ? 0 : ($row_count > 0 ? $row_count : 0))
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=head1 SECURITY

This page is restricted to root-level administrators only. Access control is enforced
via username whitelist in buildReactData().

=cut
