package Everything::Page::new_user_images;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::StaffOnly';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;

    # Get pending user images
    my $csr = $DB->sqlSelectMany(
        '*',
        'newuserimage',
        '1 = 1',
        'order by tstamp desc LIMIT 20'
    );

    my @images;
    while (my $row = $csr->fetchrow_hashref()) {
        my $user_id = $row->{newuserimage_id};
        my $user_node = $APP->node_by_id($user_id);

        next unless $user_node;

        my $imgsrc = $user_node->NODEDATA->{imgsrc} || '';

        push @images, {
            id        => int($user_id),
            userId    => int($user_id),
            userName  => $user_node->title,
            imageUrl  => $imgsrc ? "https://s3-us-west-2.amazonaws.com/hnimagew.everything2.com$imgsrc" : '',
            timestamp => $row->{tstamp},
        };
    }
    $csr->finish;

    return {
        newUserImages => {
            images => \@images,
            count  => scalar(@images),
        }
    };
}

__PACKAGE__->meta->make_immutable;

1;
