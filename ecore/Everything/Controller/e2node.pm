package Everything::Controller::e2node;

use Moose;
extends 'Everything::Controller';
use List::Util qw(shuffle);

# Controller for e2node nodes
# Builds React data directly without a Page class intermediary.
# All e2nodes use this single controller regardless of their title.

sub display {
    my ( $self, $REQUEST, $node ) = @_;
    return $self->_render_e2node($REQUEST, $node);
}

sub edit {
    my ( $self, $REQUEST, $node ) = @_;
    # Permissions handled by nodetype system - e2nodes owned by Content Editors
    return $self->_render_e2node($REQUEST, $node, { start_with_tools_modal_open => \1 });
}

# Shared rendering logic for display and edit
sub _render_e2node {
    my ( $self, $REQUEST, $node, $extra_content_data ) = @_;

    my $user = $REQUEST->user;

    # Build e2node data using Node methods (includes all writeups, softlinks, etc.)
    my $e2node = $node->json_display($user);

    # Build user permissions data
    my $VARS = $user->VARS;
    my $user_data = {
        node_id              => $user->node_id,
        title                => $user->title,
        is_guest             => $user->is_guest ? 1 : 0,
        is_editor            => $user->is_editor ? 1 : 0,
        can_vote             => ( !$user->is_guest && ( $user->votesleft || 0 ) > 0 ) ? 1 : 0,
        can_cool             => ( !$user->is_guest && ( $user->coolsleft || 0 ) > 0 ) ? 1 : 0,
        coolsleft            => $user->coolsleft || 0,
        votesafety           => int($VARS->{votesafety} || 0),
        coolsafety           => int($VARS->{coolsafety} || 0),
        info_authorsince_off => int($VARS->{info_authorsince_off} || 0)
    };

    # Check if user has an existing draft for this e2node title
    my $existing_draft;
    if ( !$user->is_guest ) {
        my $DB         = $self->DB;
        my $draft_type = $DB->getType('draft');
        if ($draft_type) {
            my $draft_row = $DB->{dbh}->selectrow_hashref(
                q|SELECT node.node_id, node.title, document.doctext
                  FROM node
                  JOIN document ON document.document_id = node.node_id
                  WHERE node.title = ?
                  AND node.type_nodetype = ?
                  AND node.author_user = ?
                  LIMIT 1|,
                {},
                $node->title,
                $draft_type->{node_id},
                $user->node_id
            );
            if ($draft_row) {
                $existing_draft = {
                    node_id => $draft_row->{node_id},
                    title   => $draft_row->{title},
                    doctext => $draft_row->{doctext} // ''
                };
            }
        }
    }

    # Get categories containing this e2node (with prev/next navigation)
    my $categories = $self->APP->get_node_categories($node->node_id);

    # Build contentData for React
    my $content_data = {
        type       => 'e2node',
        e2node     => $e2node,
        user       => $user_data,
        categories => $categories
    };

    # Add existing draft if found
    $content_data->{existing_draft} = $existing_draft if $existing_draft;

    # For guest users viewing nodeshells (e2nodes with no writeups),
    # provide best recent entries to suggest browsing
    my $writeup_count = $e2node->{group} ? scalar(@{$e2node->{group}}) : 0;
    if ($user->is_guest && $writeup_count == 0) {
        my $DB = $self->DB;
        my $best_recent = $DB->stashData("bestrecentnodes");
        if ($best_recent && ref($best_recent) eq 'ARRAY' && @$best_recent) {
            # Shuffle and take 10 entries
            my @shuffled = shuffle(@$best_recent);
            my @selected = splice(@shuffled, 0, 10);

            my @best_entries;
            foreach my $entry (@selected) {
                push @best_entries, {
                    node_id => $entry->{parent_e2node},
                    writeup_id => $entry->{writeup_id},
                    title => $entry->{parent_title},
                    author => {
                        node_id => $entry->{author_user},
                        title => $entry->{author_name}
                    },
                    excerpt => $entry->{snippet}
                };
            }
            $content_data->{best_entries} = \@best_entries;
        }
    }

    # Merge in any extra content data (e.g., start_with_tools_modal_open)
    if ($extra_content_data) {
        $content_data = { %$content_data, %$extra_content_data };
    }

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $self->APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi,
        $REQUEST
    );

    # Override contentData with our directly-built data
    $e2->{contentData}   = $content_data;
    $e2->{reactPageMode} = \1;

    # Use react_page layout (includes sidebar/header/footer)
    my $html = $self->layout( '/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node );
    return [ $self->HTTP_OK, $html ];
}

sub xml {
    my ($self, $REQUEST, $node) = @_;

    # E2node XML outputs all writeups in the group, excluding reputation
    my $except = ['reputation'];

    my $xml = "";
    foreach my $writeup_id (@{ $node->NODEDATA->{group} || [] }) {
        my $writeup = $self->APP->node_by_id($writeup_id);
        next unless $writeup;
        $xml .= $writeup->to_xml($except) . "\n";
    }

    my $content = qq|<?xml version="1.0" standalone="yes"?>\n$xml|;

    return [$self->HTTP_OK, $content, {type => 'application/xml'}];
}

sub softlinks {
    my ($self, $REQUEST, $node) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $user = $REQUEST->user;
    my $VARS = $user->VARS;
    my $NODE = $node->NODEDATA;

    # Build XML header with node info
    my $node_id       = $NODE->{node_id};
    my $type_nodetype = $NODE->{type_nodetype};
    my $createtime    = $NODE->{publishtime} || $NODE->{createtime};
    my $title         = $APP->encodeHTML($NODE->{title});

    # Get nodetype title
    my $ntype       = $DB->getNodeById($type_nodetype);
    my $type_title  = $ntype ? $APP->encodeHTML($ntype->{title}) : '';

    # Build schema location
    my $schema_row = $DB->sqlSelect("schema_id", "xmlschema", "schema_extends=$type_nodetype");
    $schema_row  ||= $DB->sqlSelect("schema_id", "xmlschema", "schema_extends=0");
    my $schema_attr = qq| xmlns="https://www.everything2.com" xmlns:xsi="https://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="https://www.everything2.com/?node_id=$schema_row"|;

    # Build softlinks XML
    my $softlinks_xml = $self->_build_softlinks_xml($node, $user);

    # Assemble full XML
    my $xml = qq|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n|;
    $xml .= qq|<node node_id="$node_id" createtime="$createtime" type_nodetype="$type_nodetype"$schema_attr>\n|;
    $xml .= qq|<type>$type_title</type>\n| if $type_title;
    $xml .= qq|<title>$title</title>\n|;
    $xml .= qq|<softlinks>\n$softlinks_xml</softlinks>\n|;
    $xml .= qq|</node>|;

    return [$self->HTTP_OK, $xml, {type => 'application/xml'}];
}

# Build softlinks XML for an e2node
sub _build_softlinks_xml {
    my ($self, $node, $user) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $VARS = $user->VARS;

    # Check if user has softlinks disabled
    return "" if $VARS->{noSoftLinks};

    my $node_id = $node->node_id;

    # Check if this is an unlinkable maintenance node
    my %unlinkables = map { $_ => 1 } @{ $Everything::CONF->maintenance_nodes || [] };
    return "" if $unlinkables{$node_id};

    # Determine limit based on user type
    my $limit;
    if ($user->is_guest) {
        $limit = 24;
    } elsif ($user->is_editor) {
        $limit = 64;
    } else {
        $limit = 48;
    }

    # Fetch softlinks ordered by hits
    my $csr = $DB->{dbh}->prepare(qq|
        SELECT node.type_nodetype, node.title, links.hits, links.to_node
        FROM links USE INDEX (linktype_fromnode_hits), node
        WHERE links.from_node = ?
          AND links.to_node = node.node_id
          AND links.linktype = 0
        ORDER BY links.hits DESC
        LIMIT $limit
    |);
    $csr->execute($node_id);

    my @nodelinks;
    while (my $link = $csr->fetchrow_hashref) {
        push @nodelinks, $link;
    }
    $csr->finish;

    return "" unless @nodelinks;

    # Find which linked nodes are filled (have writeups)
    my @e2node_ids = map { $_->{to_node} } @nodelinks;
    my %fillednode_ids;
    if (@e2node_ids) {
        my $placeholders = join(", ", ("?") x @e2node_ids);
        my $filled = $DB->{dbh}->selectcol_arrayref(
            "SELECT DISTINCT nodegroup_id FROM nodegroup WHERE nodegroup_id IN ($placeholders)",
            {},
            @e2node_ids
        );
        %fillednode_ids = map { $_ => 1 } @$filled;
    }

    # Build XML for each softlink
    my $xml = "";
    for my $link (@nodelinks) {
        my $to_node = $link->{to_node};
        my $tn = $DB->getNodeById($to_node, 'light');
        next unless $tn;

        my $filled = exists $fillednode_ids{$to_node} ? '1' : '0';
        my $title  = $APP->encodeHTML($tn->{title});
        my $weight = $link->{hits};

        $xml .= qq|<e2link node_id="$to_node" weight="$weight" filled="$filled">$title</e2link>\n|;
    }

    return $xml;
}

__PACKAGE__->meta->make_immutable();
1;
