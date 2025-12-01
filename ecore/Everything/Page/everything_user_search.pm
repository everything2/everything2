package Everything::Page::everything_user_search;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $query = $REQUEST->cgi;

    # Get parameters from URL (usersearch comes from Apache rewrite rule)
    my $username = $query->param('usersearch') || '';
    my $orderby  = $query->param('orderby') || 'publishtime_desc';

    # Convert legacy orderby format to new format
    my %orderby_map = (
        'writeup.publishtime DESC'       => 'publishtime_desc',
        'writeup.publishtime ASC'        => 'publishtime_asc',
        'node.title ASC'                 => 'title_asc',
        'node.title DESC'                => 'title_desc',
        'node.reputation DESC'           => 'reputation_desc',
        'node.reputation ASC'            => 'reputation_asc',
        'writeup.wrtype_writeuptype ASC' => 'type_asc',
        'writeup.wrtype_writeuptype DESC'=> 'type_desc',
        'node.hits DESC'                 => 'hits_desc',
        'node.hits ASC'                  => 'hits_asc',
        'RAND()'                         => 'random',
        'node.createtime DESC'           => 'publishtime_desc',
        'node.createtime ASC'            => 'publishtime_asc'
    );

    $orderby = $orderby_map{$orderby} if exists $orderby_map{$orderby};

    my $page = int( $query->param('page') || 1 );
    my $filter_hidden = int( $query->param('filterhidden') || 0 );

    return {
        initialUsername  => $username,
        initialOrderby   => $orderby,
        initialPage      => $page,
        initialFilterHidden => $filter_hidden
    };
}

__PACKAGE__->meta->make_immutable;

1;
