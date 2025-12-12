package Everything::Page::everything_s_most_wanted;

use Moose;
extends 'Everything::Page';

use Everything qw(getVars setVars getNode);
use Everything::HTML qw(encodeHTML htmlcode);
use Digest::MD5 qw(md5_hex);

=head1 Everything::Page::everything_s_most_wanted

React page for Everything's Most Wanted - bounty system for filling nodeshells.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    my $USERVARS = $APP->getVars( $USER->NODEDATA );

    # Process form submissions first
    my $message = $self->_process_form( $REQUEST, $USERVARS );

    # Re-fetch VARS after processing (may have changed)
    my $VARS = $APP->getVars( $USER->NODEDATA );

    my $min_level   = 3;
    my $user_level  = $APP->getLevel( $USER->NODEDATA );
    my $is_sheriff  = $APP->inUsergroup( $USER->NODEDATA, 'sheriffs' );
    my $is_admin    = $APP->isAdmin( $USER->NODEDATA );
    my $user_gp     = $USER->NODEDATA->{GP} || 0;
    my $bounty_limit = int( $user_gp / 10 );

    my $has_bounty    = $VARS->{Bounty} ? 1 : 0;
    my $bounty_number = $VARS->{BountyNumber} || 0;
    my $gp_optout     = $VARS->{GPoptout} ? 1 : 0;

    # Get current bounty info if user has one
    my $current_bounty;
    if ($has_bounty) {
        my $outlaw_node = $APP->node_by_name( 'outlaws', 'setting' );
        my $bounty_node = $APP->node_by_name( 'bounties', 'setting' );
        my $outlaw_vars = $outlaw_node ? $APP->getVars( $outlaw_node->NODEDATA ) : {};
        my $bounty_vars = $bounty_node ? $APP->getVars( $bounty_node->NODEDATA ) : {};
        $current_bounty = {
            outlaw => $outlaw_vars->{ $USER->NODEDATA->{title} } || '',
            reward => $bounty_vars->{ $USER->NODEDATA->{title} } || 0
        };
    }

    # Get all bounties for display
    # Note: node_by_name returns blessed objects, getVars expects hashrefs (NODEDATA)
    my $bounty_order_node = $APP->node_by_name( 'bounty order', 'setting' );
    my $outlaws_node = $APP->node_by_name( 'outlaws', 'setting' );
    my $bounties_node = $APP->node_by_name( 'bounties', 'setting' );
    my $comments_node = $APP->node_by_name( 'bounty comments', 'setting' );
    my $max_node = $APP->node_by_name( 'bounty number', 'setting' );

    my $REQ = $bounty_order_node ? $APP->getVars( $bounty_order_node->NODEDATA ) : {};
    my $OUT = $outlaws_node ? $APP->getVars( $outlaws_node->NODEDATA ) : {};
    my $REW = $bounties_node ? $APP->getVars( $bounties_node->NODEDATA ) : {};
    my $COM = $comments_node ? $APP->getVars( $comments_node->NODEDATA ) : {};
    my $MAX = $max_node ? $APP->getVars( $max_node->NODEDATA ) : {};

    my $bounty_total = $MAX->{1} || 0;
    my @bounties;

    for my $i ( 1 .. $bounty_total ) {
        next unless exists $REQ->{$i};
        my $requester = $REQ->{$i};
        push @bounties, {
            number    => $i,
            requester => $requester,
            outlaw    => $OUT->{$requester} || '',
            reward    => $REW->{$requester} || 'N/A',
            comment   => $COM->{$requester} || ''
        };
    }

    # Get recent justice served
    my $justice_node = $APP->node_by_name( 'justice served', 'setting' );
    my $justice_vars = $justice_node ? $APP->getVars( $justice_node->NODEDATA ) : {};
    my $justice_max  = $MAX->{justice} || 0;
    my @justice_served;
    for my $i ( reverse( $justice_max - 4 .. $justice_max ) ) {
        next if $i < 1;
        next unless $justice_vars->{$i};
        push @justice_served, $justice_vars->{$i};
    }

    # Generate CSRF token for forms
    my $csrf_seed = int( rand(999999999) );
    my $csrf_nonce = md5_hex( $USER->NODEDATA->{passwd} . ' ' . $USER->NODEDATA->{email} . $csrf_seed );

    return {
        type           => 'everything_s_most_wanted',
        user_level     => $user_level,
        min_level      => $min_level,
        is_sheriff     => $is_sheriff ? 1 : 0,
        is_admin       => $is_admin ? 1 : 0,
        user_gp        => $user_gp,
        bounty_limit   => $bounty_limit,
        has_bounty     => $has_bounty,
        bounty_number  => $bounty_number,
        current_bounty => $current_bounty,
        gp_optout      => $gp_optout,
        bounties       => \@bounties,
        justice_served => \@justice_served,
        can_post       => ( $user_level >= $min_level || $is_sheriff || $is_admin ) ? 1 : 0,
        message        => $message,
        csrf_nonce     => $csrf_nonce,
        csrf_seed      => $csrf_seed
    };
}

sub _process_form
{
    my ( $self, $REQUEST, $VARS ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    my $sheriff = $USER->NODEDATA->{title};
    my $user_gp = $USER->NODEDATA->{GP} || 0;
    my $bounty_limit = int( $user_gp / 10 );

    # Verify request for all POST operations
    return unless $query->request_method eq 'POST';
    return unless htmlcode( 'verifyRequest', 'emw' );

    # Sheriff/admin removing someone else's bounty
    if ( $query->param('yankify') && $query->param('removee') ) {
        my $removee = encodeHTML( $query->param('removee') );
        my $target_user = $DB->getNode( $removee, 'user' );
        return "The user '$removee' doesn't exist!" unless $target_user;

        my $rewardnode = $APP->node_by_name( 'bounties', 'setting' );
        my $REF = $rewardnode ? getVars($rewardnode->NODEDATA) : {};
        my $refund = $REF->{$removee} || 0;
        $refund = 0 if $refund eq 'N/A';
        $APP->adjustGP( $target_user, $refund ) if $refund > 0;

        my $target_vars = getVars($target_user);
        my $bounty_num = $target_vars->{BountyNumber};
        $target_vars->{Bounty} = 0;
        setVars( $target_user, $target_vars );

        # Remove from bounty order
        my $deletenode = $APP->node_by_name( 'bounty order', 'setting' );
        if ($deletenode) {
            my $deletevars = getVars($deletenode->NODEDATA) || {};
            delete $deletevars->{$bounty_num} if $bounty_num;
            setVars( $deletenode->NODEDATA, $deletevars );
        }

        my $msg = "[$removee]'s bounty has been removed";
        $msg .= " and $refund GP has been returned to their account" if $refund > 0;
        return $msg . ".";
    }

    # User posting a new bounty
    if ( $query->param('Yes') && $query->param('outlaw') ) {
        my $outlaw = encodeHTML( $query->param('outlaw') );
        my $bounty_reward = $query->param('bountyreward') // 0;
        $bounty_reward = 0 if $bounty_reward eq '' || $bounty_reward eq 'N/A';
        my $comment = encodeHTML( $query->param('bountycomment') // '' );
        $comment = '&nbsp;' if $comment eq '';

        # Validation
        return "You must specify a node or nodeshell to be filled." unless $outlaw;

        my $isNode = $DB->getNode( $outlaw, 'e2node' );
        return "No such node! Your 'Outlaw Node' must be a valid node or nodeshell." unless $isNode;

        return "Your bounty is too high! Bounties cannot be greater than 10% of your total GP."
            if $bounty_reward > $bounty_limit;

        return "You must enter a bounty of 0 or greater." if $bounty_reward < 0;

        # Deduct GP
        $APP->adjustGP( $USER->NODEDATA, -$bounty_reward ) if $bounty_reward > 0;

        # Get next bounty number
        my $ordernode = $APP->node_by_name( 'bounty order', 'setting' );
        my $maxnode = $APP->node_by_name( 'bounty number', 'setting' );
        return "System error: bounty settings not found." unless $ordernode && $maxnode;

        my $BNT = getVars($ordernode->NODEDATA) || {};
        my $MAX = getVars($maxnode->NODEDATA) || {};

        my $bounty_num = ( $MAX->{1} || 0 ) + 1;
        $MAX->{1} = $bounty_num;
        $BNT->{$bounty_num} = $sheriff;
        setVars( $ordernode->NODEDATA, $BNT );
        setVars( $maxnode->NODEDATA, $MAX );

        # Update user vars
        $VARS->{Bounty} = 1;
        $VARS->{BountyNumber} = $bounty_num;
        setVars( $USER->NODEDATA, $VARS );

        # Store bounty details
        my $settingsnode = $APP->node_by_name( 'bounties', 'setting' );
        my $outlawnode = $APP->node_by_name( 'outlaws', 'setting' );
        my $commentsnode = $APP->node_by_name( 'bounty comments', 'setting' );
        return "System error: bounty settings not found." unless $settingsnode && $outlawnode && $commentsnode;

        my $bountySettings = getVars($settingsnode->NODEDATA) || {};
        $bountySettings->{$sheriff} = $bounty_reward || 'N/A';
        setVars( $settingsnode->NODEDATA, $bountySettings );

        my $outlawvars = getVars($outlawnode->NODEDATA) || {};
        $outlawvars->{$sheriff} = "[$outlaw]";
        setVars( $outlawnode->NODEDATA, $outlawvars );

        my $commentsvars = getVars($commentsnode->NODEDATA) || {};
        $commentsvars->{$sheriff} = $comment;
        setVars( $commentsnode->NODEDATA, $commentsvars );

        return "Your bounty has been posted!";
    }

    # User removing their own bounty
    if ( $query->param('Remove') ) {
        my $rewardnode = $APP->node_by_name( 'bounties', 'setting' );
        my $REW = $rewardnode ? getVars($rewardnode->NODEDATA) : {};
        my $reward = $REW->{$sheriff} || 0;
        $reward = 0 if $reward eq 'N/A';

        # Refund GP
        $APP->adjustGP( $USER->NODEDATA, $reward ) if $reward > 0;

        # Clear bounty
        my $bounty_num = $VARS->{BountyNumber};
        $VARS->{Bounty} = 0;
        setVars( $USER->NODEDATA, $VARS );

        # Remove from order
        my $deletenode = $APP->node_by_name( 'bounty order', 'setting' );
        if ($deletenode) {
            my $deletevars = getVars($deletenode->NODEDATA) || {};
            delete $deletevars->{$bounty_num} if $bounty_num;
            setVars( $deletenode->NODEDATA, $deletevars );
        }

        my $msg = "Your bounty has been removed";
        $msg .= ", and the bounty you posted of $reward GP has been returned to your account" if $reward > 0;
        return $msg . ".";
    }

    # User rewarding GP only
    if ( $query->param('Reward') && $query->param('rewardee') ) {
        my $winner = encodeHTML( $query->param('rewardee') );
        my $target_user = $DB->getNode( $winner, 'user' );
        return "The user '$winner' doesn't exist!" unless $target_user;
        return "You cannot reward yourself!" if $sheriff eq $winner;

        my $rewardnode = $APP->node_by_name( 'bounties', 'setting' );
        my $REW = $rewardnode ? getVars($rewardnode->NODEDATA) : {};
        my $reward = $REW->{$sheriff} || 0;
        $reward = 0 if $reward eq 'N/A';

        my $outlawnode = $APP->node_by_name( 'outlaws', 'setting' );
        my $OUT = $outlawnode ? getVars($outlawnode->NODEDATA) : {};
        my $outlaw = $OUT->{$sheriff} || 'unknown';

        # Pay winner
        $APP->adjustGP( $target_user, $reward ) if $reward > 0;

        # Clear bounty
        my $bounty_num = $VARS->{BountyNumber};
        $VARS->{Bounty} = 0;
        setVars( $USER->NODEDATA, $VARS );

        # Remove from order
        my $deletenode = $APP->node_by_name( 'bounty order', 'setting' );
        if ($deletenode) {
            my $deletevars = getVars($deletenode->NODEDATA) || {};
            delete $deletevars->{$bounty_num} if $bounty_num;
            setVars( $deletenode->NODEDATA, $deletevars );
        }

        # Record justice served
        my $citation = "[$winner] tracked down $outlaw and earned $reward GP from [$sheriff]!";
        $self->_record_justice($citation);

        return "User [$winner] has been rewarded the bounty of $reward GP.";
    }

    # User awarding with custom prize
    if ( $query->param('Award') && $query->param('awardee') ) {
        my $winner = encodeHTML( $query->param('awardee') );
        my $prize = encodeHTML( $query->param('awarded') // '' );
        my $target_user = $DB->getNode( $winner, 'user' );
        return "The user '$winner' doesn't exist!" unless $target_user;
        return "You cannot reward yourself!" if $sheriff eq $winner;

        my $rewardnode = $APP->node_by_name( 'bounties', 'setting' );
        my $REW = $rewardnode ? getVars($rewardnode->NODEDATA) : {};
        my $reward = $REW->{$sheriff} || 0;
        $reward = 0 if $reward eq 'N/A';

        my $outlawnode = $APP->node_by_name( 'outlaws', 'setting' );
        my $OUT = $outlawnode ? getVars($outlawnode->NODEDATA) : {};
        my $outlaw = $OUT->{$sheriff} || 'unknown';

        # Pay winner GP portion
        $APP->adjustGP( $target_user, $reward ) if $reward > 0;

        # Clear bounty
        my $bounty_num = $VARS->{BountyNumber};
        $VARS->{Bounty} = 0;
        setVars( $USER->NODEDATA, $VARS );

        # Remove from order
        my $deletenode = $APP->node_by_name( 'bounty order', 'setting' );
        if ($deletenode) {
            my $deletevars = getVars($deletenode->NODEDATA) || {};
            delete $deletevars->{$bounty_num} if $bounty_num;
            setVars( $deletenode->NODEDATA, $deletevars );
        }

        # Record justice served
        my $citation = "[$winner] rounded up $outlaw and earned a bounty from [$sheriff] of $prize";
        $citation .= " and $reward GP" if $reward > 0;
        $citation .= "!";
        $self->_record_justice($citation);

        my $msg = "User [$winner] has been awarded a bounty of $prize";
        $msg .= " and $reward GP" if $reward > 0;
        return $msg . "!";
    }

    return;
}

sub _record_justice
{
    my ( $self, $citation ) = @_;
    my $APP = $self->APP;

    my $justicenode = $APP->node_by_name( 'justice served', 'setting' );
    my $numbernode = $APP->node_by_name( 'bounty number', 'setting' );
    return unless $justicenode && $numbernode;

    my $justicevars = getVars($justicenode->NODEDATA) || {};
    my $numbervar = getVars($numbernode->NODEDATA) || {};

    my $cites_num = ( $numbervar->{justice} || 0 ) + 1;
    $justicevars->{$cites_num} = $citation;
    $numbervar->{justice} = $cites_num;
    setVars( $justicenode->NODEDATA, $justicevars );
    setVars( $numbernode->NODEDATA, $numbervar );

    return;
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut
