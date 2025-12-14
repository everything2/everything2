package Everything::Page::security_monitor;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::security_monitor - Security audit log viewer

=head1 DESCRIPTION

Admin tool for viewing security-related actions across the site.
Shows categorized logs for various security events like kills, suspensions,
blessings, account lockings, etc.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;
    my $q    = $REQUEST->cgi;

    # Admin-only page
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'security_monitor',
            error => 'This page is restricted to administrators.'
        };
    }

    my $node_id = $REQUEST->node->node_id;

    # Define security log categories
    my @categories = (
        { name => 'Account Lockings',      node_title => 'lockaccount',                   node_type => 'opcode' },
        { name => 'Account Unlockings',    node_title => 'unlockaccount',                 node_type => 'opcode' },
        { name => 'Blessings',             node_title => 'bless',                         node_type => 'opcode' },
        { name => 'C! bestowings',         node_title => 'bestow cools',                  node_type => 'restricted_superdoc' },
        { name => 'Catbox flushes',        node_title => 'flushcbox',                     node_type => 'opcode' },
        { name => 'Chings Bought',         node_title => 'Buy Chings',                    node_type => 'node_forward' },
        { name => 'Chings Given Away',     node_title => 'The Gift of Ching',             node_type => 'node_forward' },
        { name => 'IP Blacklist',          node_title => 'IP Blacklist',                  node_type => 'restricted_superdoc' },
        { name => 'Kill reasons',          node_title => 'massacre',                      node_type => 'opcode' },
        { name => 'Node Notes',            node_title => 'Recent Node Notes',             node_type => 'superdoc' },
        { name => 'Parameter changes',     node_title => 'parameter',                     node_type => 'opcode' },
        { name => 'Password resets',       node_title => 'Reset password',                node_type => 'superdoc' },
        { name => 'Resurrections',         node_title => "Dr. Nate's Secret Lab",         node_type => 'restricted_superdoc' },
        { name => 'Sanctifications',       node_title => 'Sanctify user',                 node_type => 'superdoc' },
        { name => 'Stars Awarded',         node_title => 'The Gift of Star',              node_type => 'node_forward' },
        { name => 'SuperBless',            node_title => 'superbless',                    node_type => 'superdoc' },
        { name => 'Suspensions',           node_title => 'Suspension Info',               node_type => 'superdoc' },
        { name => 'Topic changes',         node_title => 'E2 Gift Shop',                  node_type => 'superdoc' },
        { name => 'User Deletions',        node_title => 'The Old Hooked Pole',           node_type => 'restricted_superdoc' },
        { name => 'User Signup',           node_title => 'Sign up',                       node_type => 'superdoc' },
        { name => 'Vote bestowings',       node_title => 'bestow',                        node_type => 'opcode' },
        { name => 'Votes Bought',          node_title => 'Buy Votes',                     node_type => 'node_forward' },
        { name => 'Votes Given Away',      node_title => 'The Gift of Votes',             node_type => 'node_forward' },
        { name => 'Writeup insurance',     node_title => 'insure',                        node_type => 'opcode' },
        { name => 'Writeup reparentings',  node_title => 'Magical Writeup Reparenter',    node_type => 'superdoc' },
        { name => 'XP Recalculations',     node_title => 'Recalculate XP',                node_type => 'superdoc' },
        { name => 'XP SuperBless',         node_title => 'XP Superbless',                 node_type => 'restricted_superdoc' },
    );

    # Build category data with counts
    my @category_data = ();
    foreach my $cat (@categories) {
        my $cat_node = $DB->getNode($cat->{node_title}, $cat->{node_type});
        next unless $cat_node;

        my $cat_id = $cat_node->{node_id};
        my $count = $DB->sqlSelect('COUNT(*)', 'seclog', "seclog_node=$cat_id") || 0;

        push @category_data, {
            name    => $cat->{name},
            node_id => int($cat_id),
            count   => int($count)
        };
    }

    my $result = {
        type       => 'security_monitor',
        node_id    => $node_id,
        categories => \@category_data
    };

    # Check if viewing a specific log type
    my $sectype = $q->param('sectype');
    if ($sectype && $sectype =~ /^\d+$/) {
        my $startat = $q->param('startat') || 0;
        $startat =~ s/[^0-9]//g;
        $startat = int($startat);

        # Get log entries
        my $csr = $DB->sqlSelectMany(
            '*',
            'seclog',
            "seclog_node=$sectype ORDER BY seclog_time DESC",
            "LIMIT $startat, 50"
        );

        my @entries = ();
        while (my $row = $csr->fetchrow_hashref) {
            my $log_node = $DB->getNodeById($row->{seclog_node}, 'light');
            my $log_user = $DB->getNodeById($row->{seclog_user}, 'light');

            push @entries, {
                node_id     => $log_node ? int($log_node->{node_id}) : 0,
                node_title  => $log_node ? $log_node->{title} : 'Unknown',
                user_id     => $log_user ? int($log_user->{node_id}) : 0,
                user_title  => $log_user ? $log_user->{title} : 'Unknown',
                time        => $row->{seclog_time},
                details     => $row->{seclog_details} || ''
            };
        }
        $csr->finish;

        # Get total count for pagination
        my $total = $DB->sqlSelect('COUNT(*)', 'seclog', "seclog_node=$sectype") || 0;

        $result->{viewing_type} = int($sectype);
        $result->{entries}      = \@entries;
        $result->{startat}      = $startat;
        $result->{total}        = int($total);
        $result->{page_size}    = 50;
    }

    return $result;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
