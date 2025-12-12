package Everything::Page::the_old_hooked_pole;

use Moose;
extends 'Everything::Page';

use Everything qw(getId getNode getNodeById getType getVars setVars getRef updateNode nukeNode);
use Everything::HTML qw(encodeHTML htmlcode);

=head1 Everything::Page::the_old_hooked_pole

React page for The Old Hooked Pole - editor tool for mass user account management.
Checks if users are safe to delete or locks them.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;
    my $NODE  = $REQUEST->node;

    # Editor check
    unless ( $APP->isEditor( $USER->NODEDATA ) ) {
        return {
            type       => 'the_old_hooked_pole',
            is_editor  => 0,
            message    => "You've got other things to snoop on, don't ya."
        };
    }

    my $ip_trauma = '1 MONTH';
    my @results = ();
    my @saved_users = ();

    my $smite = ( $query->param('op') eq 'remove' ) ? 1 : 0;
    my $username_string = $smite ? $query->param('author') : $query->param('usernames');
    $smite ||= $query->param('smite') ? 1 : 0;
    my $detonate = $query->param('detonate') ? 1 : 0;

    # Verify request hash for security
    my $hash_valid = htmlcode('verifyRequest', 'polehash') ? 1 : 0;

    if ( $username_string ) {
        my $type_id_user = getType('user')->{node_id};
        my $type_id_writeup = getType('writeup')->{node_id};
        my $type_id_e2node = getType('e2node')->{node_id};

        $username_string =~ s/[\[\]]//g;
        my @usernames = split( /\s*[\n\r]\s*/, $username_string );

        my $ordinal = 1;
        my $input_table = join "\n    UNION ALL\n",
            map { "    SELECT " . $DB->quote($_) . " AS title, " . ($ordinal++) . " AS ordinal" } @usernames;

        my $user_query = qq|
SELECT input.title 'input', node.title, node.node_id, user.lasttime
  , user.acctlock
  , (SELECT COUNT(writeups.node_id)
      FROM node writeups
      WHERE node.node_id = writeups.author_user
      AND writeups.type_nodetype = $type_id_writeup)
     'writeup_count'
  , (SELECT COUNT(nodeshells.node_id)
      FROM node AS nodeshells
      WHERE node.node_id = nodeshells.author_user
      AND nodeshells.type_nodetype = $type_id_e2node)
     'nodeshell_count'
  , input.ordinal
  FROM (
$input_table
  ) input
  LEFT JOIN node
    ON node.title = input.title
    AND node.type_nodetype = $type_id_user
  LEFT JOIN user
    ON node.node_id = user.user_id
  GROUP BY input.title
  ORDER BY input.ordinal|;

        my $users_to_nail = $DB->{dbh}->selectall_hashref( $user_query, 'ordinal' );

        foreach my $ordinal ( sort { $a <=> $b } keys %$users_to_nail ) {
            my $target = $users_to_nail->{$ordinal};
            my $target_name = encodeHTML( $target->{input} );
            my $safe_to_whack = 1;
            my $safe_to_lock = 1;
            my @reasons = ();

            if ( !$target->{node_id} ) {
                push @reasons, "$target_name isn't a valid user";
                $safe_to_whack = 0;
                $safe_to_lock = 0;
            }

            if ( $target->{lasttime} && $target->{lasttime} ne "0" && $target->{lasttime} ne "" ) {
                push @reasons, "Logged in at $target->{lasttime}!";
                $safe_to_whack = 0;
            }

            if ( $target->{nodeshell_count} && $target->{nodeshell_count} > 0 ) {
                push @reasons, "Has $target->{nodeshell_count} nodeshells!";
                $safe_to_whack = 0;
            }

            if ( $target->{writeup_count} && $target->{writeup_count} > 0 ) {
                push @reasons, "Has $target->{writeup_count} writeups!";
                $safe_to_whack = 0;
            }

            if ( !$hash_valid ) {
                push @reasons, "Security hash verification failed.";
                $safe_to_whack = 0;
                $safe_to_lock = 0;
            }

            my $action = '';
            if ( $safe_to_whack ) {
                nukeNode( $target->{node_id}, $USER->NODEDATA );
                $action = 'deleted';
            } elsif ( $safe_to_lock ) {
                if ( !$target->{acctlock} ) {
                    htmlcode( 'lock user account', $target->{node_id} );
                    push @reasons, "Locked account.";
                } else {
                    push @reasons, "Account already locked.";
                }

                # Smite spammer if requested
                if ( $smite && $target->{node_id} ) {
                    my $spammer = getNodeById( $target->{node_id} );
                    if ( $spammer ) {
                        $spammer->{doctext} = '';
                        updateNode( $spammer, -1 );
                        my $uservars = getVars( $spammer );
                        $uservars = { ipaddy => $uservars->{ipaddy} };
                        setVars( $spammer, $uservars );
                        push @reasons, "Blanked homenode";
                        my $user_title = $USER->title;
                        htmlcode( 'addNodenote', $target->{node_id}, "Spammer: smitten by [$user_title\[user\]]" );

                        # Check for bad IP
                        my $bad_ip = $DB->sqlSelect(
                            'myIP.iplog_ipaddy',
                            "iplog myIP JOIN iplog badIP JOIN user
                                ON myIP.iplog_ipaddy = badIP.iplog_ipaddy
                                AND myIP.iplog_ipaddy != 'unknown'
                                AND user_id = badIP.iplog_user
                                AND user_id != myIP.iplog_user",
                            "myIP.iplog_user = $target->{node_id}
                                AND acctlock != 0
                                AND lasttime > DATE_SUB(NOW(), INTERVAL $ip_trauma)"
                        );
                        if ( $bad_ip ) {
                            my $blacklist_result = htmlcode( 'blacklistIP', $bad_ip,
                                "Spammer $target->{input} using same IP as recently locked account" );
                            push @reasons, "Blacklisted IP: $bad_ip" if $blacklist_result;
                        }
                    }
                }

                $action = 'locked';
                push @saved_users, $target->{input};
            } else {
                $action = 'skipped';
                push @saved_users, $target->{input};
            }

            push @results, {
                input          => $target_name,
                node_id        => $target->{node_id} || 0,
                title          => $target->{title} || '',
                action         => $action,
                reasons        => \@reasons,
                writeup_count  => $target->{writeup_count} || 0,
                nodeshell_count => $target->{nodeshell_count} || 0
            };
        }
    }

    return {
        type           => 'the_old_hooked_pole',
        is_editor      => 1,
        results        => \@results,
        saved_users    => \@saved_users,
        smite          => $smite,
        detonate       => $detonate,
        show_form      => !$smite && !$detonate,
        node_id        => $NODE->NODEDATA->{node_id}
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut
