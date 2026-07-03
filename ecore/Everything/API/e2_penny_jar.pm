package Everything::API::e2_penny_jar;

use Moose;
extends 'Everything::API';

# POST /api/e2_penny_jar/give | /take -- the community "penny jar", a shared GP pot
# (#4451-stacked, Refs #4298). Any logged-in, non-GP-opted-out user gives a penny (1 GP)
# into the jar or takes one out. Replaces the render-time give/take mutation that ran off
# query params in Everything::Page::e2_penny_jar's buildReactData. The jar count lives in
# the 'penny jar' setting node's vars under key '1'.

sub routes {
    return {
        'give' => 'give_penny',
        'take' => 'take_penny',
    };
}

sub give_penny { my ($self, $REQUEST) = @_; return $self->_touch_penny($REQUEST, 'give'); }
sub take_penny { my ($self, $REQUEST) = @_; return $self->_touch_penny($REQUEST, 'take'); }

sub _touch_penny {
    my ($self, $REQUEST, $action) = @_;

    my $user = $REQUEST->user;

    # Hard preconditions (also gated at the page: guests/opt-outs never see the buttons).
    return [$self->HTTP_OK, {success => 0, error => 'You must be logged in to touch the pennies.'}]
        if $user->is_guest;

    my $USER = $user->NODEDATA;
    my $vars = $self->APP->getVars($USER);
    return [$self->HTTP_OK,
        {success => 0, error => 'Sorry, it seems you are not interested in pennies right now.'}]
        if $vars->{GPoptout};

    my $pennynode = $self->DB->getNode('penny jar', 'setting');
    return [$self->HTTP_OK, {success => 0, error => 'The penny jar is missing.'}]
        unless $pennynode;

    my $pennies = $self->APP->getVars($pennynode);
    my $count   = $pennies->{1} || 0;
    my $user_gp = $USER->{GP} || 0;

    # Soft guards return success=0 + a message but leave state unchanged, so the React
    # can re-sync its count/GP display without treating it as a hard error.
    if ($action eq 'give') {
        return [$self->HTTP_OK, {success => 0, message => 'Sorry, you do not have any GP to give!',
            pennies_in_jar => int($count), user_gp => int($user_gp)}]
            if $user_gp < 1;
        $pennies->{1} = $count + 1;
    } else {    # take
        return [$self->HTTP_OK, {success => 0,
            message => 'Sorry, there are no more pennies in the jar! Would you like to donate one?',
            pennies_in_jar => 0, user_gp => int($user_gp)}]
            if $count < 1;
        $pennies->{1} = $count - 1;
    }

    # Read-modify-write the whole vars hash (a bare setVars of one key wipes the rest).
    Everything::setVars($pennynode, $pennies);
    $self->DB->updateNode($pennynode, -1);
    $self->APP->adjustGP($USER, $action eq 'give' ? -1 : 1);    # mutates $USER->{GP} in place

    return [$self->HTTP_OK, {
        success        => 1,
        message        => $action eq 'give' ? 'You gave a penny to the jar!' : 'You took a penny from the jar!',
        pennies_in_jar => int($pennies->{1}),
        user_gp        => int($USER->{GP} || 0),
    }];
}

__PACKAGE__->meta->make_immutable;

1;
