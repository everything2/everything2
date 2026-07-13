package Everything::API::everything_s_best_users;

use Moose;
use namespace::autoclean;
use Time::Local ();

extends 'Everything::API';

=head1 NAME

Everything::API::everything_s_best_users - the "best users" leaderboard (by XP / devotion / addiction)

=head1 DESCRIPTION

Public leaderboard of top users, rankable by experience, devotion (XP per writeup) or addiction
(writeups per day of membership), with new-user and hide-fled toggles. Moved out of
C<Everything::Page::everything_s_best_users>'s buildReactData (#4526): the Page is a pure gate, React
reads the toggles off the URL and calls this.

  GET /api/everything_s_best_users?ebu_showdevotion=1&ebu_showaddiction=1&ebu_newusers=1&ebu_showrecent=1

Ships data only (the ranked users + the echoed toggle flags).

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $APP = $self->APP;
    my $DB  = $self->DB;

    my $showDevotion  = $REQUEST->param('ebu_showdevotion')  || 0;
    my $showAddiction = $REQUEST->param('ebu_showaddiction') || 0;
    my $showNewUsers  = $REQUEST->param('ebu_newusers')      || 0;
    my $showRecent    = $REQUEST->param('ebu_showrecent')    || 0;

    my $skip = { map { $_ => 1 } ('dbrown', 'nate', 'Webster 1913', 'ShadowLost', 'EDB') };

    my $lvlttl = $APP->getVars($DB->getNode('level titles', 'setting'));

    my $limit = 200;   # fetch extra for filtering/sorting; hardcoded (no injection)
    my $two_years = 2 * 365 * 24 * 60 * 60;
    my $two_years_ago = time() - $two_years;

    my $dbh = $DB->getDatabaseHandle();
    my $sth = $dbh->prepare(qq{
        SELECT node.node_id, node.title, node.createtime,
               user.experience, user.lasttime, user.numwriteups, setting.vars
        FROM user
        LEFT JOIN node ON node_id = user_id
        LEFT JOIN setting ON setting_id = user_id
        ORDER BY user.experience DESC
        LIMIT $limit
    });
    $sth->execute();

    my @all_users;
    while (my $row = $sth->fetchrow_hashref()) {
        next if exists $skip->{ $row->{title} };

        my $vars = $APP->getVars($row);
        my $writeup_count = $vars->{numwriteups} || $row->{numwriteups} || 0;

        if ($showNewUsers) {
            my $createtime = $row->{createtime};
            next if !$createtime || $createtime =~ /^0000-/;
            if ($createtime =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/) {
                my $ts = Time::Local::timegm($6, $5, $4, $3, $2 - 1, $1);
                next if $ts < $two_years_ago;
            }
        } else {
            next if $writeup_count < 25;
        }

        if ($showRecent) {
            my $lasttime = $row->{lasttime};
            next if !$lasttime || $lasttime =~ /^0000-/;
            if ($lasttime =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/) {
                my $ts = Time::Local::timegm($6, $5, $4, $3, $2 - 1, $1);
                next if (time() - $ts) > $two_years;
            } else {
                next;
            }
        }

        my $level_value = $APP->getLevel($row);
        my $level_title = $lvlttl->{$level_value} || 'Initiate';

        my $devotion = $writeup_count > 0 ? int($row->{experience} / $writeup_count) : 0;

        my $addiction = 0;
        my $created = $vars->{created_on} || 0;
        if ($created > 0) {
            my $days = int((time() - $created) / (24 * 60 * 60));
            $addiction = $writeup_count / $days if $days > 0;
        }

        push @all_users, {
            node_id       => int($row->{node_id}),
            title         => $row->{title},
            experience    => int($row->{experience} || 0),
            devotion      => $devotion,
            addiction     => $addiction,
            writeup_count => $writeup_count,
            level_value   => $level_value,
            level_title   => $level_title,
        };
    }
    $sth->finish();

    my @sorted;
    if    ($showDevotion)  { @sorted = sort { $b->{devotion}   <=> $a->{devotion}   } @all_users }
    elsif ($showAddiction) { @sorted = sort { $b->{addiction}  <=> $a->{addiction}  } @all_users }
    else                   { @sorted = sort { $b->{experience} <=> $a->{experience} } @all_users }

    my @users = splice(@sorted, 0, 50);

    return [$self->HTTP_OK, {
        success       => 1,
        users         => \@users,
        showDevotion  => $showDevotion  ? 1 : 0,
        showAddiction => $showAddiction ? 1 : 0,
        showNewUsers  => $showNewUsers  ? 1 : 0,
        showRecent    => $showRecent    ? 1 : 0,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
