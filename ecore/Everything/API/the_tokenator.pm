package Everything::API::the_tokenator;

use Moose;
extends 'Everything::API';

use Everything qw(setVars);

# POST /api/the_tokenator/tokenate -- admin-only (#4455, Refs #4298). Gives users a
# "token" (usable to reset the chatterbox topic): per user, sends a Cool Man Eddie
# notification and increments the user's `tokens` var. Replaces the render-time
# tokenateUser<N> loop in Everything::Page::the_tokenator's buildReactData.

sub routes {
    return { 'tokenate' => 'give_tokens' };
}

sub give_tokens {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Access denied. Admins only.'}]
        unless $user->is_admin;

    my $data  = $REQUEST->JSON_POSTDATA;
    my $users = $data->{users};
    return [$self->HTTP_OK, {success => 0, error => 'No users to tokenate'}]
        unless (ref $users eq 'ARRAY' && @$users);

    my $cme = $self->DB->getNode('Cool Man Eddie', 'user');

    my @results;
    foreach my $username (@$users) {
        $username =~ s/^\s+|\s+$//g if defined $username;
        next unless (defined $username && length $username);    # skip blank rows

        my $target = $self->DB->getNode($username, 'user');
        unless ($target) {
            push @results, {success => 0, username => $username, message => "Couldn't find user $username"};
            next;
        }

        # Notify via Cool Man Eddie. Route through sendPrivateMessage so
        # message_forward_to / messageignore apply uniformly (#4142).
        if ($cme) {
            $self->APP->sendPrivateMessage($cme, $target,
                'Whoa! Somebody has given you a [token]! Use it to [E2 Gift Shop|reset the chatterbox topic].');
        }

        # +1 token in the user's vars.
        my $v = $self->APP->getVars($target);
        $v->{tokens} = ($v->{tokens} || 0) + 1;
        setVars($target, $v);

        push @results, {success => 1, username => $target->{title},
            message => "User $target->{title} was given one token"};
    }

    return [$self->HTTP_OK, {success => 1, results => \@results}];
}

__PACKAGE__->meta->make_immutable;

1;
