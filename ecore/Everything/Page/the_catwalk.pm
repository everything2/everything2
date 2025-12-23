package Everything::Page::the_catwalk;

use Moose;
extends 'Everything::Page';

# The Catwalk - browser for all stylesheets/themes on E2
# Migrated from Everything::Delegation::document::the_catwalk
# Features sorting, filtering by author, and testing themes

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;
    my $VARS = $REQUEST->user->VARS;
    my $query = $REQUEST->cgi;

    my $is_guest = $APP->isGuest($USER);

    # Guest users get simple message
    if ($is_guest) {
        return {
            type => 'the_catwalk',
            is_guest => 1,
            message => 'This page will allow you to customize your view of the site if you sign up for an account.'
        };
    }

    # Handle clear vandalism (custom style reset)
    if (defined($query->param('clearVandalism'))) {
        delete($VARS->{customstyle});
        $APP->setVars($USER, $VARS);
    }

    # Get user's current style
    my $userstyle_id = $VARS->{userstyle} || 0;
    my $userstyle_node;
    if ($userstyle_id) {
        $userstyle_node = $DB->getNodeById($userstyle_id);
    }

    my $current_style = undef;
    if ($userstyle_node) {
        $current_style = {
            node_id => $userstyle_node->{node_id},
            title => $userstyle_node->{title}
        };
    }

    my $has_custom_style = length($VARS->{customstyle} || '') > 0;

    # Get sorting preference from vars
    my $sort_key = $VARS->{ListNodesOfType_Sort} || '0';

    # Handle filter parameters
    my $filter_user = $query->param('filter_user') || '';
    my $filter_user_not = $query->param('filter_user_not') ? 1 : 0;
    my $filter_user_id = 0;
    my $filter_user_name = '';

    if ($filter_user) {
        my $fu = $DB->getNode($filter_user, 'user') || $DB->getNode($filter_user, 'usergroup');
        if ($fu) {
            $filter_user_id = $fu->{node_id};
            $filter_user_name = $fu->{title};
        }
    }

    # Get pagination
    my $page_size = 100;
    my $offset = int($query->param('next') || 0);
    $offset = 0 if $offset < 0;

    # Build SQL
    my $stylesheet_nodetype = 1854352;  # Stylesheet nodetype

    # Mapping of sort options
    my %mapVARStoSQL = (
        '0'       => 'title ASC',
        'nameA'   => 'title ASC',
        'nameD'   => 'title DESC',
        'createA' => 'createtime ASC',
        'createD' => 'createtime DESC',
    );
    my $sql_sort = $mapVARStoSQL{$sort_key} || 'title ASC';

    # Build filter clause
    my $filter_clause = '';
    if ($filter_user_id) {
        my $op = $filter_user_not ? '!=' : '=';
        $filter_clause = " AND author_user $op $filter_user_id";
    }

    # Get total count
    my ($total) = $DB->sqlSelect('COUNT(*)', 'node',
        "type_nodetype = $stylesheet_nodetype" . $filter_clause);

    # Get stylesheets for current page
    my $query_text = "SELECT node_id, title, author_user, createtime FROM node
                      WHERE type_nodetype = $stylesheet_nodetype
                      $filter_clause
                      ORDER BY $sql_sort
                      LIMIT $offset, $page_size";

    my $sth = $DB->{dbh}->prepare($query_text);
    $sth->execute();

    my @stylesheets;
    while (my $row = $sth->fetchrow_hashref) {
        my $author = $DB->getNodeById($row->{author_user});

        push @stylesheets, {
            node_id => $row->{node_id},
            title => $row->{title},
            author => $author ? {
                node_id => $author->{node_id},
                title => $author->{title}
            } : undef,
            createtime => $row->{createtime}
        };
    }
    $sth->finish;

    # Sort options for UI
    my @sort_options = (
        { value => '0',       label => '(no sorting)' },
        { value => 'nameA',   label => 'title, ascending (ABC)' },
        { value => 'nameD',   label => 'title, descending (ZYX)' },
        { value => 'createA', label => 'create time, ascending (oldest first)' },
        { value => 'createD', label => 'create time, descending (newest first)' },
    );

    return {
        type => 'the_catwalk',
        is_guest => 0,
        stylesheets => \@stylesheets,
        current_style => $current_style,
        has_custom_style => $has_custom_style ? 1 : 0,
        pagination => {
            offset => $offset,
            limit => $page_size,
            total => $total
        },
        sort_options => \@sort_options,
        current_sort => $sort_key,
        filter => {
            user_name => $filter_user_name,
            user_id => $filter_user_id,
            is_not => $filter_user_not
        }
    };
}

__PACKAGE__->meta->make_immutable;
1;
