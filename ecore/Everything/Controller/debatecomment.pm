package Everything::Controller::debatecomment;

use Moose;
extends 'Everything::Controller';

use Everything qw(getNodeById);
use CGI;

# Controller for debatecomment nodes (usergroup discussions)
# Debatecomments are threaded discussion nodes with:
# - Usergroup-restricted access (only members can view/post)
# - Nested reply structure (parent_debatecomment, root_debatecomment)
# - Read/unread tracking via lastreaddebate table
# - Display modes: full, compact

# Check if user can access the debatecomment based on root's restricted field
sub _check_access {
    my ($self, $user, $node) = @_;

    # Admins always have access
    return 1 if $user->is_admin;

    # Get root debatecomment to check restriction
    my $root_id = $node->NODEDATA->{root_debatecomment} || $node->node_id;
    my $root = $self->APP->node_by_id($root_id);
    return 0 unless $root;

    # Get the restricted usergroup (default to CE for legacy nodes)
    my $restricted_id = $root->NODEDATA->{restricted} || 923653;

    # Handle legacy magic numbers
    if ($restricted_id == 0) {
        $restricted_id = 923653;  # Content Editors
    } elsif ($restricted_id == 1) {
        $restricted_id = 114;     # gods
    }

    my $group = $self->DB->getNodeById($restricted_id);
    return 0 unless $group;

    return $self->APP->inUsergroup($user->NODEDATA, $group);
}

# Update the last read timestamp for this discussion
sub _update_last_read {
    my ($self, $user_id, $root_id) = @_;

    my $DB = $self->DB;

    # Check if entry exists
    my $lastread = $DB->sqlSelect("dateread", "lastreaddebate",
        "user_id=$user_id AND debateroot_id=$root_id");

    if ($lastread) {
        $DB->sqlUpdate("lastreaddebate", {-dateread => "NOW()"},
            "user_id=$user_id AND debateroot_id=$root_id");
    } else {
        $DB->sqlInsert("lastreaddebate", {
            user_id => $user_id,
            debateroot_id => $root_id,
            -dateread => "NOW()"
        });
    }
    return;
}

# Build nested children structure recursively
sub _build_children {
    my ($self, $node, $display_mode) = @_;

    my @children;
    my $group = $node->NODEDATA->{group} || [];

    foreach my $child_id (@$group) {
        my $child = $self->APP->node_by_id($child_id);
        next unless $child;

        my $author = $self->APP->node_by_id($child->NODEDATA->{author_user});

        my $child_data = {
            node_id => int($child_id),
            title => $child->title,
            createtime => $child->NODEDATA->{createtime},
            author => $author ? {
                node_id => int($child->NODEDATA->{author_user}),
                title => $author->title
            } : undef,
        };

        # Include doctext for full display mode
        if ($display_mode eq 'full') {
            $child_data->{doctext} = $child->NODEDATA->{doctext} || '';
        }

        # Recursively get children's children
        $child_data->{children} = $self->_build_children($child, $display_mode);

        push @children, $child_data;
    }

    return \@children;
}

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $user_id = $user->node_id;
    my $cgi = $REQUEST->cgi;

    # Check access
    my $can_access = $self->_check_access($user, $node);

    unless ($can_access) {
        # Return permission denied
        my $content_data = {
            type => 'debatecomment',
            permission_denied => 1,
            user => {
                node_id => $user_id,
                title => $user->title,
                is_guest => $user->is_guest ? 1 : 0,
                is_admin => $user->is_admin ? 1 : 0
            }
        };

        $REQUEST->node($node);

        my $e2 = $self->APP->buildNodeInfoStructure(
            $node->NODEDATA,
            $user->NODEDATA,
            $user->VARS,
            $cgi,
            $REQUEST
        );

        $e2->{contentData} = $content_data;
        $e2->{reactPageMode} = \1;

        my $html = $self->layout('/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node);
        return [$self->HTTP_OK, $html];
    }

    # Determine display mode
    my $display_mode = 'full';

    # Get root and parent info
    my $root_id = $node->NODEDATA->{root_debatecomment} || $node->node_id;
    my $root = $self->APP->node_by_id($root_id);
    my $parent_id = $node->NODEDATA->{parent_debatecomment};
    my $parent = $parent_id ? $self->APP->node_by_id($parent_id) : undef;

    # Get usergroup info
    my $restricted_id = $root ? ($root->NODEDATA->{restricted} || 923653) : 923653;
    if ($restricted_id == 0) { $restricted_id = 923653; }
    elsif ($restricted_id == 1) { $restricted_id = 114; }
    my $usergroup = $self->DB->getNodeById($restricted_id);

    # Update last read timestamp if viewing root node
    if ($node->node_id == $root_id && !$user->is_guest) {
        $self->_update_last_read($user_id, $root_id);
    }

    # Get author info
    my $author = $self->APP->node_by_id($node->NODEDATA->{author_user});

    # Build children recursively
    my $children = $self->_build_children($node, $display_mode);

    # Can edit if author or admin
    my $can_edit = $user->is_admin ||
        (!$user->is_guest && $node->NODEDATA->{author_user} == $user_id);

    # Build content data
    my $content_data = {
        type => 'debatecomment',
        debatecomment => {
            node_id => int($node->node_id),
            title => $node->title,
            doctext => $node->NODEDATA->{doctext} || '',
            createtime => $node->NODEDATA->{createtime},
            parent_debatecomment => int($parent_id || 0),
            root_debatecomment => int($root_id),
            restricted => int($restricted_id),
            author => $author ? {
                node_id => int($node->NODEDATA->{author_user}),
                title => $author->title
            } : undef
        },
        root => $root ? {
            node_id => int($root_id),
            title => $root->title,
            restricted => int($root->NODEDATA->{restricted} || 923653)
        } : undef,
        usergroup => $usergroup ? {
            node_id => int($restricted_id),
            title => $usergroup->{title}
        } : undef,
        parent => $parent ? {
            node_id => int($parent_id),
            title => $parent->title
        } : undef,
        children => $children,
        can_access => 1,
        can_edit => $can_edit ? 1 : 0,
        can_reply => ($can_access && !$user->is_guest) ? 1 : 0,
        display_mode => $display_mode,
        is_root => ($node->node_id == $root_id) ? 1 : 0,
        user => {
            node_id => $user_id,
            title => $user->title,
            is_guest => $user->is_guest ? 1 : 0,
            is_admin => $user->is_admin ? 1 : 0
        }
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $self->APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $user->NODEDATA,
        $user->VARS,
        $cgi,
        $REQUEST
    );

    $e2->{contentData} = $content_data;
    $e2->{reactPageMode} = \1;

    my $html = $self->layout('/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node);
    return [$self->HTTP_OK, $html];
}

sub compact {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $user_id = $user->node_id;
    my $cgi = $REQUEST->cgi;

    # Check access
    my $can_access = $self->_check_access($user, $node);

    unless ($can_access) {
        # Same permission denied as display
        return $self->display($REQUEST, $node);
    }

    # Get root and parent info
    my $root_id = $node->NODEDATA->{root_debatecomment} || $node->node_id;
    my $root = $self->APP->node_by_id($root_id);
    my $parent_id = $node->NODEDATA->{parent_debatecomment};
    my $parent = $parent_id ? $self->APP->node_by_id($parent_id) : undef;

    # Get usergroup info
    my $restricted_id = $root ? ($root->NODEDATA->{restricted} || 923653) : 923653;
    if ($restricted_id == 0) { $restricted_id = 923653; }
    elsif ($restricted_id == 1) { $restricted_id = 114; }
    my $usergroup = $self->DB->getNodeById($restricted_id);

    # Update last read timestamp if viewing root node
    if ($node->node_id == $root_id && !$user->is_guest) {
        $self->_update_last_read($user_id, $root_id);
    }

    # Get author info
    my $author = $self->APP->node_by_id($node->NODEDATA->{author_user});

    # Build children recursively (compact mode - no doctext)
    my $children = $self->_build_children($node, 'compact');

    # Can edit if author or admin
    my $can_edit = $user->is_admin ||
        (!$user->is_guest && $node->NODEDATA->{author_user} == $user_id);

    # Build content data (no doctext in compact mode)
    my $content_data = {
        type => 'debatecomment',
        debatecomment => {
            node_id => int($node->node_id),
            title => $node->title,
            createtime => $node->NODEDATA->{createtime},
            parent_debatecomment => int($parent_id || 0),
            root_debatecomment => int($root_id),
            restricted => int($restricted_id),
            author => $author ? {
                node_id => int($node->NODEDATA->{author_user}),
                title => $author->title
            } : undef
        },
        root => $root ? {
            node_id => int($root_id),
            title => $root->title,
            restricted => int($root->NODEDATA->{restricted} || 923653)
        } : undef,
        usergroup => $usergroup ? {
            node_id => int($restricted_id),
            title => $usergroup->{title}
        } : undef,
        parent => $parent ? {
            node_id => int($parent_id),
            title => $parent->title
        } : undef,
        children => $children,
        can_access => 1,
        can_edit => $can_edit ? 1 : 0,
        can_reply => ($can_access && !$user->is_guest) ? 1 : 0,
        display_mode => 'compact',
        is_root => ($node->node_id == $root_id) ? 1 : 0,
        user => {
            node_id => $user_id,
            title => $user->title,
            is_guest => $user->is_guest ? 1 : 0,
            is_admin => $user->is_admin ? 1 : 0
        }
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $self->APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $user->NODEDATA,
        $user->VARS,
        $cgi,
        $REQUEST
    );

    $e2->{contentData} = $content_data;
    $e2->{reactPageMode} = \1;

    my $html = $self->layout('/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node);
    return [$self->HTTP_OK, $html];
}

sub edit {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $user_id = $user->node_id;
    my $cgi = $REQUEST->cgi;

    # Check access
    my $can_access = $self->_check_access($user, $node);

    # Check if user can edit (author or admin)
    my $can_edit = $user->is_admin ||
        (!$user->is_guest && $node->NODEDATA->{author_user} == $user_id);

    unless ($can_access && $can_edit) {
        # Return permission denied
        my $content_data = {
            type => 'debatecommentEdit',
            permission_denied => 1,
            mode => 'edit',
            user => {
                node_id => $user_id,
                title => $user->title,
                is_guest => $user->is_guest ? 1 : 0,
                is_admin => $user->is_admin ? 1 : 0
            }
        };

        $REQUEST->node($node);

        my $e2 = $self->APP->buildNodeInfoStructure(
            $node->NODEDATA,
            $user->NODEDATA,
            $user->VARS,
            $cgi,
            $REQUEST
        );

        $e2->{contentData} = $content_data;
        $e2->{reactPageMode} = \1;

        my $html = $self->layout('/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node);
        return [$self->HTTP_OK, $html];
    }

    # Get root and usergroup info
    my $root_id = $node->NODEDATA->{root_debatecomment} || $node->node_id;
    my $root = $self->APP->node_by_id($root_id);

    my $restricted_id = $root ? ($root->NODEDATA->{restricted} || 923653) : 923653;
    if ($restricted_id == 0) { $restricted_id = 923653; }
    elsif ($restricted_id == 1) { $restricted_id = 114; }
    my $usergroup = $self->DB->getNodeById($restricted_id);

    # Get author info
    my $author = $self->APP->node_by_id($node->NODEDATA->{author_user});

    # Build content data
    my $content_data = {
        type => 'debatecommentEdit',
        mode => 'edit',
        debatecomment => {
            node_id => int($node->node_id),
            title => $node->title,
            doctext => $node->NODEDATA->{doctext} || '',
            author => $author ? {
                node_id => int($node->NODEDATA->{author_user}),
                title => $author->title
            } : undef
        },
        root => $root ? {
            node_id => int($root_id),
            title => $root->title
        } : undef,
        usergroup => $usergroup ? {
            node_id => int($restricted_id),
            title => $usergroup->{title}
        } : undef,
        user => {
            node_id => $user_id,
            title => $user->title,
            is_guest => $user->is_guest ? 1 : 0,
            is_admin => $user->is_admin ? 1 : 0
        }
    };

    $REQUEST->node($node);

    my $e2 = $self->APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $user->NODEDATA,
        $user->VARS,
        $cgi,
        $REQUEST
    );

    $e2->{contentData} = $content_data;
    $e2->{reactPageMode} = \1;

    my $html = $self->layout('/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node);
    return [$self->HTTP_OK, $html];
}

sub replyto {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $user_id = $user->node_id;
    my $cgi = $REQUEST->cgi;

    # Check access
    my $can_access = $self->_check_access($user, $node);

    # Guests can't reply
    if ($user->is_guest || !$can_access) {
        my $content_data = {
            type => 'debatecommentReplyto',
            permission_denied => 1,
            mode => 'replyto',
            user => {
                node_id => $user_id,
                title => $user->title,
                is_guest => $user->is_guest ? 1 : 0,
                is_admin => $user->is_admin ? 1 : 0
            }
        };

        $REQUEST->node($node);

        my $e2 = $self->APP->buildNodeInfoStructure(
            $node->NODEDATA,
            $user->NODEDATA,
            $user->VARS,
            $cgi,
            $REQUEST
        );

        $e2->{contentData} = $content_data;
        $e2->{reactPageMode} = \1;

        my $html = $self->layout('/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node);
        return [$self->HTTP_OK, $html];
    }

    # Get root and usergroup info
    my $root_id = $node->NODEDATA->{root_debatecomment} || $node->node_id;
    my $root = $self->APP->node_by_id($root_id);

    my $restricted_id = $root ? ($root->NODEDATA->{restricted} || 923653) : 923653;
    if ($restricted_id == 0) { $restricted_id = 923653; }
    elsif ($restricted_id == 1) { $restricted_id = 114; }
    my $usergroup = $self->DB->getNodeById($restricted_id);

    # Get parent author info
    my $author = $self->APP->node_by_id($node->NODEDATA->{author_user});

    # Build content data - parent is the node we're replying to
    my $content_data = {
        type => 'debatecommentReplyto',
        mode => 'replyto',
        debatecomment => {
            node_id => int($node->node_id),
            title => $node->title,
            doctext => $node->NODEDATA->{doctext} || '',
            author => $author ? {
                node_id => int($node->NODEDATA->{author_user}),
                title => $author->title
            } : undef
        },
        parent => {
            node_id => int($node->node_id),
            title => $node->title,
            doctext => $node->NODEDATA->{doctext} || '',
            author => $author ? {
                node_id => int($node->NODEDATA->{author_user}),
                title => $author->title
            } : undef
        },
        root => $root ? {
            node_id => int($root_id),
            title => $root->title
        } : undef,
        usergroup => $usergroup ? {
            node_id => int($restricted_id),
            title => $usergroup->{title}
        } : undef,
        user => {
            node_id => $user_id,
            title => $user->title,
            is_guest => $user->is_guest ? 1 : 0,
            is_admin => $user->is_admin ? 1 : 0
        }
    };

    $REQUEST->node($node);

    my $e2 = $self->APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $user->NODEDATA,
        $user->VARS,
        $cgi,
        $REQUEST
    );

    $e2->{contentData} = $content_data;
    $e2->{reactPageMode} = \1;

    my $html = $self->layout('/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node);
    return [$self->HTTP_OK, $html];
}

# Generate Atom feed for a debatecomment thread
sub atom {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;

    # Check access
    my $can_access = $self->_check_access($user, $node);

    unless ($can_access) {
        # Return 403 for atom feeds
        return [$self->HTTP_FORBIDDEN, "Access denied", {type => 'text/plain'}];
    }

    # Get root debatecomment
    my $root_id = $node->NODEDATA->{root_debatecomment} || $node->node_id;
    my $root = $self->APP->node_by_id($root_id);

    unless ($root) {
        return [$self->HTTP_NOT_FOUND, "Discussion not found", {type => 'text/plain'}];
    }

    # Get usergroup info for feed title
    my $restricted_id = $root->NODEDATA->{restricted} || 923653;
    if ($restricted_id == 0) { $restricted_id = 923653; }
    elsif ($restricted_id == 1) { $restricted_id = 114; }
    my $usergroup = $self->DB->getNodeById($restricted_id);
    my $usergroup_title = $usergroup ? $usergroup->{title} : 'Discussion';

    # Get all children recursively and flatten
    my $group = $root->NODEDATA->{group} || [];
    my @all_comments = $self->APP->getCommentChildren(@$group);

    # Sort by createtime descending (newest first)
    my @sorted = sort { $b <=> $a } @all_comments;

    # Add the root node at the end
    push @sorted, $root_id;

    # Build Atom feed
    my $host = $ENV{HTTP_HOST} || $Everything::CONF->canonical_web_server || "everything2.com";
    $host = "https://$host";

    my $feed_url = "$host/?node_id=$root_id&displaytype=atom";
    my $html_url = "$host/?node_id=$root_id";

    # Get the most recent update time
    my $latest_update = $root->NODEDATA->{createtime};
    if (@sorted > 1) {
        my $first_comment = $self->DB->getNodeById($sorted[0]);
        if ($first_comment && $first_comment->{createtime}) {
            $latest_update = $first_comment->{createtime};
        }
    }

    my $updated_timestamp = $self->_format_atom_date($latest_update);

    my $xml = qq{<?xml version="1.0" encoding="UTF-8"?>\n};
    $xml .= qq{<feed xmlns="http://www.w3.org/2005/Atom" xml:base="$host/">\n};
    $xml .= qq{  <title>} . $self->_xml_escape($usergroup_title . ": " . $root->title) . qq{</title>\n};
    $xml .= qq{  <link rel="alternate" type="text/html" href="$html_url"/>\n};
    $xml .= qq{  <link rel="self" type="application/atom+xml" href="$feed_url"/>\n};
    $xml .= qq{  <id>$html_url</id>\n};
    $xml .= qq{  <updated>$updated_timestamp</updated>\n};

    # Add entries for each comment
    foreach my $comment_id (@sorted) {
        my $comment = $self->DB->getNodeById($comment_id);
        next unless $comment;

        $xml .= $self->_build_atom_entry($comment, $host);
    }

    $xml .= qq{</feed>\n};

    # Return XML with proper content type
    return [$self->HTTP_OK, $xml, {type => 'application/atom+xml', charset => 'utf-8'}];
}

# Format datetime for Atom feed (ISO 8601)
sub _format_atom_date {
    my ($self, $timestamp) = @_;

    return '' unless $timestamp;

    # Parse MySQL datetime format: YYYY-MM-DD HH:MM:SS
    if ($timestamp =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/) {
        return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $1, $2, $3, $4, $5, $6);
    }

    return $timestamp;
}

# Escape XML special characters
sub _xml_escape {
    my ($self, $text) = @_;

    return '' unless defined $text;

    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/"/&quot;/g;
    $text =~ s/'/&apos;/g;

    return $text;
}

# Build an Atom entry for a comment
sub _build_atom_entry {
    my ($self, $comment, $host) = @_;

    my $node_id = $comment->{node_id};
    my $url = "$host/?node_id=$node_id";

    my $author = $self->DB->getNodeById($comment->{author_user});
    my $author_name = $author ? $author->{title} : 'Unknown';
    my $author_url = $author ? "$host/user/" . CGI::escape($author->{title}) : '';

    my $timestamp = $comment->{publishtime} || $comment->{createtime};
    my $formatted_time = $self->_format_atom_date($timestamp);

    my $title = $self->_xml_escape($comment->{title});
    my $doctext = $comment->{doctext} || '';

    # Truncate content if too long (1024 chars)
    my $max_len = 1024;
    if (length($doctext) > $max_len) {
        $doctext = substr($doctext, 0, $max_len) . '...';
    }

    my $entry = qq{  <entry>\n};
    $entry .= qq{    <title>$title</title>\n};
    $entry .= qq{    <link rel="alternate" type="text/html" href="$url"/>\n};
    $entry .= qq{    <id>$url</id>\n};
    $entry .= qq{    <author>\n};
    $entry .= qq{      <name>$author_name</name>\n};
    $entry .= qq{      <uri>$author_url</uri>\n} if $author_url;
    $entry .= qq{    </author>\n};
    $entry .= qq{    <published>$formatted_time</published>\n};
    $entry .= qq{    <updated>$formatted_time</updated>\n};

    if ($doctext) {
        $entry .= qq{    <content type="html">} . $self->_xml_escape($doctext) . qq{</content>\n};
    }

    $entry .= qq{  </entry>\n};

    return $entry;
}

__PACKAGE__->meta->make_immutable();
1;
