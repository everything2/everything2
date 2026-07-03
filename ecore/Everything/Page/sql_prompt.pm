package Everything::Page::sql_prompt;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::sql_prompt - SQL Query Interface for Administrators

=head1 DESCRIPTION

Restricted superdoc that provides a SQL query interface for root-level administrators.

Only accessible to: root, jaybonci

As of #4442 (Refs #4298) this controller is pure-render: it no longer executes SQL
or writes user vars off query params during rendering. The SQL execution moved to
C<POST /api/sqlprompt/query> (L<Everything::API::sqlprompt>, same root/jaybonci gate),
and the C<sqlprompt_wrap> display preference to the allowlisted C<POST /api/preferences>.
The React component (SQLPrompt.js) drives both; this just seeds the form with the
saved display format.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns the (read-only) React data: the access gate and the saved display format.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB   = $self->DB;
    my $user = $REQUEST->user;
    my $VARS = $REQUEST->VARS;

    # Strict access control - only specific users. Mirrors the identical gate in
    # Everything::API::sqlprompt (deliberately a username whitelist, not is_admin).
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
            type    => 'sql_prompt',
            error   => 'unauthorized',
            message => 'You really really shouldn\'t be playing with this.'
        };
    }

    my $node    = $REQUEST->node;
    my $node_id = $node ? $DB->getId($node) : 0;

    return {
        type        => 'sql_prompt',
        node_id     => $node_id,
        formatStyle => ($VARS->{sqlprompt_wrap} || 0),
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::API::sqlprompt>

=head1 SECURITY

Restricted to root-level administrators (username whitelist). The same gate is
enforced independently by L<Everything::API::sqlprompt>, which does the actual
query execution -- this page rendering carries no execution or mutation.

=cut
