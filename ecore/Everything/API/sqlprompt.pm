package Everything::API::sqlprompt;

use Moose;
extends 'Everything::API';

use Time::HiRes qw(gettimeofday tv_interval);
use Everything::HTML;

# POST /api/sqlprompt/query -- executor for the root-only SQL console (#4442, Refs
# #4298). Replaces the render-time SQL execution in Everything::Page::sql_prompt so
# that page becomes a pure React view. Gated to the SAME username whitelist the page
# enforced (jaybonci, root) -- deliberately NOT is_admin. This is the same capability
# the page already had, just API-shaped; keep the gate byte-identical.

my @SQL_PROMPT_USERS = qw(jaybonci root);

sub routes {
    return { 'query' => 'run_query' };
}

sub run_query {
    my ($self, $REQUEST) = @_;

    my $username = $REQUEST->user->title;
    return [$self->HTTP_OK, {success => 0, error => 'unauthorized'}]
        unless grep { $_ eq $username } @SQL_PROMPT_USERS;

    my $data         = $REQUEST->JSON_POSTDATA;
    my $sql          = $data->{query};
    my $hide_results = $data->{hide_results} ? 1 : 0;

    unless (defined $sql && length $sql) {
        return [$self->HTTP_OK, {success => 0, error => 'No query provided'}];
    }

    return [$self->HTTP_OK, {
        success => 1,
        results => $self->_run_sql($sql, {hide_results => $hide_results}),
    }];
}

# Moved verbatim from the former Everything::Page::sql_prompt::execute_query (#4442):
# run the query with our own error handling and return a display-ready result set.
# The returned hash carries error => 0|1, so a bad query is a successful API call
# with a SQL-level error inside (mirrors the prior page behaviour the React expects).
sub _run_sql {
    my ($self, $sql, $options) = @_;

    my $dbh   = $self->DB->getDatabaseHandle();
    my @start = gettimeofday;

    my $old_print_error = $dbh->{PrintError};
    my $old_raise_error = $dbh->{RaiseError};
    $dbh->{PrintError} = 0;
    $dbh->{RaiseError} = 0;

    my $cursor;
    my $prepare_ok = eval {
        local $SIG{__WARN__} = sub { return };
        $cursor = $dbh->prepare($sql);
        1;
    };
    if (!$prepare_ok || !$cursor) {
        my $error_msg = $@ || $dbh->errstr || 'Unknown error';
        $dbh->{PrintError} = $old_print_error;
        $dbh->{RaiseError} = $old_raise_error;
        return {
            error        => 1,
            error_type   => 'prepare',
            message      => "Bad SQL: $error_msg",
            elapsed_time => tv_interval(\@start, [gettimeofday]),
        };
    }

    my $execute_result;
    my $execute_ok = eval {
        local $SIG{__WARN__} = sub { return };
        $execute_result = $cursor->execute();
        1;
    };
    if (!$execute_ok || !$execute_result) {
        my $error_msg = $@ || $dbh->errstr || 'Query execution failed';
        $dbh->{PrintError} = $old_print_error;
        $dbh->{RaiseError} = $old_raise_error;
        return {
            error        => 1,
            error_type   => 'execute',
            message      => $error_msg,
            elapsed_time => tv_interval(\@start, [gettimeofday]),
        };
    }

    $dbh->{PrintError} = $old_print_error;
    $dbh->{RaiseError} = $old_raise_error;

    my $row_count    = $cursor->rows();
    my @rows         = ();
    my @columns      = ();
    my $rows_fetched = 0;

    unless ($options->{hide_results}) {
        @columns = @{$cursor->{NAME}} if $cursor->{NAME};

        while (my $row = $cursor->fetchrow_hashref()) {
            my $processed_row = {};
            foreach my $col (@columns) {
                my $value = $row->{$col};
                if (defined $value) {
                    $value = Everything::HTML::encodeHTML($value, 1);
                    # Auto-linkify node ids (columns with an underscore + numeric value)
                    if ($col =~ /_/ && $value =~ /^\d+$/) {
                        $processed_row->{$col} = {value => $value, is_node_id => 1};
                    } else {
                        $processed_row->{$col} = {value => $value, is_node_id => 0};
                    }
                } else {
                    $processed_row->{$col} = {value => undef, is_null => 1};
                }
            }
            push @rows, $processed_row;
            $rows_fetched++;
        }
    }

    $cursor->finish();
    my $elapsed_time = tv_interval(\@start, [gettimeofday]);

    return {
        error        => 0,
        columns      => \@columns,
        rows         => \@rows,
        row_count    => $row_count,
        rows_fetched => $rows_fetched,
        elapsed_time => sprintf('%.4f', $elapsed_time),
        affected_rows => ($cursor->{Active} ? 0 : ($row_count > 0 ? $row_count : 0)),
    };
}

__PACKAGE__->meta->make_immutable;

1;
