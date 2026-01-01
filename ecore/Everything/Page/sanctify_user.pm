package Everything::Page::sanctify_user;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $user = $REQUEST->user;
    my $USER = $user->NODEDATA;
    my $VARS = $user->VARS;
    my $APP = $self->APP;

    my $level = $APP->getLevel($USER);
    my $is_editor = $APP->isEditor($USER);

    my $min_level = 11;
    my $sanctify_amount = 10;

    my $can_sanctify = 1;
    my $reason = '';

    if ($VARS->{GPoptout}) {
        $can_sanctify = 0;
        $reason = 'You have opted out of the GP system.';
    } elsif ($level < $min_level && !$is_editor) {
        $can_sanctify = 0;
        $reason = "You must be at least Level $min_level to sanctify users.";
    } elsif ($USER->{GP} < $sanctify_amount) {
        $can_sanctify = 0;
        $reason = "You need at least $sanctify_amount GP to sanctify a user.";
    }

    return {
        sanctify => {
            canSanctify => $can_sanctify ? \1 : \0,
            reason => $reason,
            gp => int($USER->{GP} || 0),
            level => $level,
            sanctifyAmount => $sanctify_amount,
            minLevel => $min_level,
            gpOptOut => $VARS->{GPoptout} ? \1 : \0,
            userSanctity => int($USER->{sanctity} || 0),
        }
    };
}

__PACKAGE__->meta->make_immutable;

1;
