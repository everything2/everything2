package Everything::Page::renunciation_chainsaw;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::renunciation_chainsaw - Bulk transfer writeup ownership

=head1 DESCRIPTION

Admin tool for transferring ownership of multiple writeups from one user
to another. Used when a user renounces their writeups or when content
needs to be reassigned.

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
            type  => 'renunciation_chainsaw',
            error => 'This page is restricted to administrators.'
        };
    }

    my $node_id = $REQUEST->node->node_id;

    my $result = {
        type    => 'renunciation_chainsaw',
        node_id => $node_id
    };

    # Check for pre-filled writeup
    my $wu_id = $q->param('wu_id');
    if ($wu_id && $wu_id =~ /^\d+$/) {
        my $writeup_type = $DB->getType('writeup');
        my $wu = $DB->getNodeById($wu_id);
        if ($wu && $wu->{type_nodetype} == $writeup_type->{node_id}) {
            my $author = $DB->getNodeById($wu->{author_user}, 'light');
            my $parent = $DB->getNodeById($wu->{parent_e2node}, 'light');
            $result->{prefill_user} = $author ? $author->{title} : '';
            $result->{prefill_node} = $parent ? $parent->{title} : '';
        }
    }

    # Handle form submission
    my $user_from = $q->param('user_name_from');
    my $user_to   = $q->param('user_name_to');
    my $namelist  = $q->param('namelist');

    if ($user_from && $user_to && $namelist) {
        my $from_user = $DB->getNode($user_from, 'user');
        my $to_user   = $DB->getNode($user_to, 'user');

        unless ($from_user) {
            $result->{error} = "No such user: \"$user_from\"";
            return $result;
        }

        unless ($to_user) {
            $result->{error} = "No such user: \"$user_to\"";
            return $result;
        }

        my $from_id = $from_user->{node_id};
        my $to_id   = $to_user->{node_id};

        # Clean up name list
        $namelist =~ s/\s*\n\s*/\n/g;
        my @names = grep { $_ } split(/\n/, $namelist);

        my @reparented  = ();
        my @nonexistent = ();
        my @no_writeup  = ();
        my @bad_owner   = ();
        my @bad_type    = ();

        my $writeup_type_id = $DB->getType('writeup')->{node_id};

        foreach my $parent_title (@names) {
            my $e2node = $DB->getNode($parent_title, 'e2node');

            unless ($e2node) {
                push @nonexistent, { title => $parent_title };
                next;
            }

            # Find writeups by this author under this e2node
            my $csr = $DB->{dbh}->prepare(
                'SELECT * FROM node LEFT JOIN writeup ON node.node_id = writeup.writeup_id ' .
                'WHERE writeup.parent_e2node = ? AND node.author_user = ?'
            );
            $csr->execute($e2node->{node_id}, $from_id);

            my $found = 0;
            my $node_info = {
                node_id => int($e2node->{node_id}),
                title   => $e2node->{title}
            };

            while (my $row = $csr->fetchrow_hashref) {
                $found = 1;
                my $writeup = $DB->getNodeById($row->{node_id});

                if ($writeup->{type_nodetype} != $writeup_type_id) {
                    push @bad_type, $node_info;
                } elsif ($writeup->{author_user} != $from_id) {
                    push @bad_owner, $node_info;
                } else {
                    # Do the reparenting
                    $writeup->{author_user} = $to_id;
                    $DB->updateNode($writeup, $USER->NODEDATA);
                    push @reparented, $node_info;
                }
            }
            $csr->finish;

            push @no_writeup, $node_info unless $found;
        }

        # Update writeup counts if any were reparented
        if (@reparented) {
            my $count = scalar(@reparented);

            my $from_vars = $APP->getVars($from_user);
            my $to_vars   = $APP->getVars($to_user);

            my $from_count = int($from_vars->{numwriteups} || 0);
            my $to_count   = int($to_vars->{numwriteups} || 0);

            $from_vars->{numwriteups} = $from_count - $count;
            $to_vars->{numwriteups}   = $to_count + $count;

            Everything::setVars($from_user, $from_vars);
            Everything::setVars($to_user, $to_vars);

            $DB->updateNode($from_user, -1);
            $DB->updateNode($to_user, -1);
        }

        $result->{processed}   = 1;
        $result->{from_user}   = { id => int($from_id), title => $from_user->{title} };
        $result->{to_user}     = { id => int($to_id), title => $to_user->{title} };
        $result->{reparented}  = \@reparented;
        $result->{nonexistent} = \@nonexistent;
        $result->{no_writeup}  = \@no_writeup;
        $result->{bad_owner}   = \@bad_owner;
        $result->{bad_type}    = \@bad_type;
    }

    # Handle node list generation
    my $nodes_for = $q->param('nodes_for');
    if ($nodes_for) {
        my $list_user = $DB->getNode($nodes_for, 'user');
        if ($list_user) {
            my $writeup_type = $DB->getType('writeup');
            my $csr = $DB->sqlSelectMany(
                'node_id',
                'node',
                "type_nodetype=$writeup_type->{node_id} AND author_user=$list_user->{node_id}"
            );

            my @node_list = ();
            while (my $row = $csr->fetchrow_hashref) {
                my $writeup = $DB->getNodeById($row->{node_id}, 'light');
                next unless $writeup;
                my $parent = $DB->getNodeById($writeup->{parent_e2node}, 'light');
                push @node_list, {
                    node_id => int($parent->{node_id}),
                    title   => $parent->{title}
                } if $parent;
            }
            $csr->finish;

            $result->{generated_list} = {
                user_id    => int($list_user->{node_id}),
                user_title => $list_user->{title},
                nodes      => \@node_list
            };
        } else {
            $result->{list_error} = "No such user: \"$nodes_for\"";
        }
    }

    return $result;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
