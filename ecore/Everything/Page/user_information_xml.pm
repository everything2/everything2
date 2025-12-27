package Everything::Page::user_information_xml;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::user_information_xml - User Information XML

=head1 DESCRIPTION

Returns XML with detailed user information including experience, votes,
karma, usergroups, etc. Requires either finger_id or finger_title parameter.

Supports query parameters:
- finger_id: User node ID to query
- finger_title: Username to query
- help: Show help text

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML with user information.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;
    my $XG = $self->xml_generator;

    my $nl = "\n";

    my $str=$XG->info({
        'site'=>$Everything::CONF->site_url,
        'sitename'=>$Everything::CONF->site_name,
        'servertime'=>scalar(localtime(time)),
        'node_id'=>$$node{node_id},
    },'rendered by '.($$node{title} // 'unknown')).$nl;

    my $TYPE_USER = 15;
    my $UID = $self->DB->getId($USER);
    my $isRoot = $self->APP->isAdmin($USER);
    my $isCE = $self->APP->isEditor($USER);
    my $isEDev = $self->APP->isDeveloper($USER);
    my $fingerID = 0;
    my $fingerTitle = '';
    my $fingerUser=undef;


    $fingerID = (defined $fingerUser) ? undef : $query->param('finger_id');
    if ((defined $fingerID) && length($fingerID)) {
        if ($fingerID=~/^(\d+)$/) {
            $fingerID=$1;
        } else {
            return $str.$XG->error('the finger_id parameter must be the node_id of a user in decimal');
        }
        $fingerUser = $self->DB->getNodeById($fingerID);
        unless ($fingerUser) {
            return $str.$XG->error('the given finger_id parameter of '.$fingerID.' is not a node');
        }
        unless ($fingerUser->{type_nodetype}==$TYPE_USER) {
            return $str.$XG->error('the given finger_id parameter of '.$fingerID.' is not a user node');
        }
    } else {
        $fingerID=0;
    }

    $fingerTitle = (defined $fingerUser) ? undef : $query->param('finger_title');
    if ((defined $fingerTitle) && length($fingerTitle)) {
        $fingerUser = $self->DB->getNode($fingerTitle, 'user');
        unless ($fingerUser) {
            # Note: makeXmlSafe not needed with XML::Generator - it escapes automatically
            return $str.$XG->error('the given finger_title parameter of '.$fingerTitle.' is not a user');
        }
    }

    if ((!defined $fingerUser) || (defined $query->param('help'))) {
        return $str.$XG->error('to get information about a user, either give the parameter finger_id with the value of the ID of the user, or the parameter finger_title with the value of the title of the user; if the parameter help with any value is given, this help text is displayed instead');
    }

    $fingerID = $fingerUser->{node_id};
    $fingerTitle = $fingerUser->{title};
    my $isMe = $fingerID==$UID;

    $str .= $XG->error('This is still in production. N-Wing will /msg edev and clientdev when this is working.').$nl;

    $str .= $nl;

    $str .= $XG->title($fingerTitle).$nl;
    $str .= $XG->node_id($fingerID).$nl;
    $str .= $XG->createtime($fingerUser->{createtime}).$nl;
    $str .= $XG->lasttime($fingerUser->{lasttime}).$nl;
    $str .= $XG->experience($fingerUser->{experience}).$nl;

    $str .= $XG->votes($fingerUser->{votes}).$nl if $isMe;
    $str .= $XG->votesleft($fingerUser->{votesleft}).$nl if $isMe;
    $str .= $XG->karma($fingerUser->{karma}).$nl if $isMe || $isRoot;
    $str .= $XG->in_room($fingerUser->{in_room}).$nl if $isMe || $isRoot;

    $str .= $XG->imgsrc($fingerUser->{imgsrc}).$nl if (exists $fingerUser->{imgsrc}) and length($fingerUser->{imgsrc});

    my $ug = '';
    if ($self->APP->isAdmin($fingerID) ) { $ug .= $XG->group({node_id=>114,title=>'gods'}).$nl; }
    if ($self->APP->isEditor($fingerID) ) { $ug .= $XG->group({node_id=>923653,title=>'Content Editors'}).$nl; }
    if ($self->APP->isDeveloper($fingerID) ) { $ug .= $XG->group({node_id=>838015,title=>'edev'}).$nl; }
    my $N=$self->DB->getNode('clientdev','usergroup');
    if (defined $N) {
        foreach(@{$N->{group}}) {
            if ($_==$fingerID) {
                $ug .= $XG->group({node_id=>$N->{node_id},title=>$N->{title}}).$nl;
                last;
            }
        }
    }
    if (length($ug)) {
        $str .= $XG->usergroups($nl.$ug);
    }

    return $self->xml_header() . $str;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut
