package Everything::Page::cache_dump;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::cache_dump - Display node cache contents

=head1 DESCRIPTION

Admin tool showing the current state of the node cache for this httpd process.
Displays cached nodes, their types, permanent status, and group memberships.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    # Admin only
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type => 'cache_dump',
            error => 'This page is restricted to administrators.'
        };
    }

    my $cache = $DB->getCache();
    my $cache_entries = $cache->dumpCache();
    my $cache_size = $cache->getCacheSize();
    my $max_size = $cache->{maxSize};
    my $num_permanent = $cache->{nodeQueue}->{numPermanent};

    my @nodes;
    my %type_counts;

    foreach my $cache_entry (@$cache_entries) {
        next unless $cache_entry;

        my $item = $cache_entry->[0];
        my $meta = $cache_entry->[1];
        my $type_title = $item->{type}{title} || 'unknown';

        $type_counts{$type_title}++;

        my $node_info = {
            node_id    => int($item->{node_id}),
            title      => $item->{title},
            type       => $type_title,
            permanent  => $meta->{permanent} ? 1 : 0,
        };

        # Check for group data
        if (exists $item->{group}) {
            $node_info->{group_size} = scalar(@{$item->{group}});
        }

        # Check for groupCache data
        if (exists $cache->{groupCache}{$item->{node_id}}) {
            $node_info->{group_cache_size} = scalar(keys %{$cache->{groupCache}{$item->{node_id}}});
        }

        push @nodes, $node_info;
    }

    # Sort type counts for display
    my @type_stats = map {
        { type => $_, count => $type_counts{$_} }
    } sort keys %type_counts;

    # Build groupCache details - shows which groups have cached membership data
    my @group_cache_entries;
    foreach my $group_id (sort { $a <=> $b } keys %{$cache->{groupCache}}) {
        my $group_node = $DB->getNodeById($group_id);
        next unless $group_node;

        my @member_ids = sort { $a <=> $b } keys %{$cache->{groupCache}{$group_id}};
        my @members;
        foreach my $member_id (@member_ids) {
            my $member_node = $DB->getNodeById($member_id);
            if ($member_node) {
                push @members, {
                    node_id => int($member_id),
                    title   => $member_node->{title},
                    type    => $member_node->{type}{title} || 'unknown'
                };
            } else {
                push @members, {
                    node_id => int($member_id),
                    title   => "(deleted node $member_id)",
                    type    => 'unknown'
                };
            }
        }

        push @group_cache_entries, {
            group_id    => int($group_id),
            group_title => $group_node->{title},
            group_type  => $group_node->{type}{title} || 'unknown',
            member_count => scalar(@members),
            members     => \@members
        };
    }

    return {
        type => 'cache_dump',
        process_id => $$,
        cache_size => $cache_size,
        max_size => $max_size,
        num_permanent => $num_permanent,
        nodes => \@nodes,
        type_stats => \@type_stats,
        group_cache => \@group_cache_entries,
        group_cache_size => scalar(@group_cache_entries)
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::NodeCache>

=cut
