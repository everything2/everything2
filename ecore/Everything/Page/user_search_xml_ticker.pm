package Everything::Page::user_search_xml_ticker;

use Moose;
extends 'Everything::Page';

use XML::Generator;

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::user_search_xml_ticker - User Search XML Ticker

=head1 DESCRIPTION

Returns writeups by a specific user in XML format. Shows reputation and vote
details for the authenticated user viewing their own writeups.

Query parameters:
- usersearch: Username to search for (defaults to authenticated user)

=head1 METHODS

=head2 display($REQUEST, $node)

Returns XML feed of user's writeups.

=cut

sub display {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;

    my $uid = Everything::getId($USER);
    my $otherid = $query->param('usersearch');
    $otherid = $otherid ? Everything::getNode($otherid, 'user') : 0;
    $otherid = $otherid->{node_id} if $otherid;
    $otherid ||= $uid;
    my $fingerSelf = $otherid == $uid;

    my $XG = XML::Generator->new();

    my $csr = $self->DB->sqlSelectMany('*', 'node JOIN writeup ON node_id=writeup_id',
        "author_user=$otherid",
        'order by publishtime desc');
    my $str = '';
    my $U = $self->DB->getNodeById($otherid);

    $str .= $XG->INFO({
        site => $self->CONF->site_url,
        sitename => $self->CONF->site_name,
        servertime => scalar(localtime(time)),
        experience => $U->{experience}
    }, 'Rendered by the User Search XML Ticker') . "\n";

    while (my $N = $csr->fetchrow_hashref) {
        my $cooledby_user = '';
        if ($N->{cooled}) {
            ($cooledby_user) = $self->DB->sqlSelect('cooledby_user', 'coolwriteups', 'coolwriteups_id=' . $N->{node_id});
            $cooledby_user = $self->DB->getNodeById($cooledby_user);
            $cooledby_user = $self->APP->xml_escape($cooledby_user->{title}) if $cooledby_user;
            $cooledby_user ||= '(a former user)';
        }
        my ($votescast) = $self->DB->sqlSelect('count(*)', 'vote', 'vote_id=' . $N->{node_id});
        my $p = ($votescast + $N->{reputation}) / 2;
        my $m = ($votescast - $N->{reputation}) / 2;

        my $curwu = {
            node_id => Everything::getId($N),
            parent_e2node => $N->{parent_e2node},
            cooled => $N->{cooled},
            cooledby_user => $cooledby_user,
            createtime => $N->{publishtime}
        };
        if ($fingerSelf) {
            $curwu->{'reputation'} = $N->{reputation};
            $curwu->{upvotes} = $p;
            $curwu->{downvotes} = $m;
        }
        $N->{title} =~ s/\[/\&#91\;/g;
        $N->{title} =~ s/\]/\&#93\;/g;

        $str .= $XG->writeup($curwu, $self->APP->xml_escape($N->{title})) . "\n";
    }

    return [$self->HTTP_OK, qq{<?xml version="1.0"?>\n} . $XG->USERSEARCH($str), {type => $self->mimetype}];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
