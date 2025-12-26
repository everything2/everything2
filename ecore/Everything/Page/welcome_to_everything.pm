package Everything::Page::welcome_to_everything;

use Moose;
extends 'Everything::Page';

# Welcome to Everything - the main page content for logged-in users
#
# Shows: Logs (dayloglinks), Cool User Picks (coolnodes), Staff Picks (staffpicks),
#        Cream of the Cool (creamofthecool), News for Noders (frontpagenews)
# Type: superdocnolinks (renders within standard page layout)

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;
    my $VARS = $REQUEST->user->VARS;

    my $is_guest = $APP->isGuest($USER);

    my $data = {
        type => 'welcome_to_everything',
        is_guest => $is_guest ? 1 : 0
    };

    # Load daylog links (Logs section)
    my $daylog_data = $DB->stashData("dayloglinks");
    if ($daylog_data && ref($daylog_data) eq 'ARRAY') {
        my @daylogs;
        foreach my $block (@$daylog_data) {
            push @daylogs, {
                title => $block->[0],
                display => $block->[1]
            };
        }
        $data->{daylogs} = \@daylogs;
    }

    # Load coolnodes data (Cool User Picks)
    my $coolnodes_data = $DB->stashData("coolnodes");
    if ($coolnodes_data && ref($coolnodes_data) eq 'ARRAY') {
        my @coolnodes;
        my %used;
        my $count = 15;
        foreach my $cw (@$coolnodes_data) {
            next if exists $used{$cw->{coolwriteups_id}};
            $used{$cw->{coolwriteups_id}} = 1;
            push @coolnodes, {
                node_id => $cw->{coolwriteups_id},
                title => $cw->{parentTitle}
            };
            last unless (--$count);
        }
        $data->{coolnodes} = \@coolnodes;
    }

    # Load staffpicks data (Staff Picks)
    unless ($is_guest) {
        my $staffpicks_data = $DB->stashData("staffpicks");
        if ($staffpicks_data && ref($staffpicks_data) eq 'ARRAY') {
            my @staffpicks;
            foreach my $sp (@$staffpicks_data) {
                my $n = $DB->getNodeById($sp);
                if ($n) {
                    push @staffpicks, {
                        node_id => $n->{node_id},
                        title => $n->{title}
                    };
                }
            }
            $data->{staffpicks} = \@staffpicks;
        }
    }

    # Load Cream of the Cool content
    my $cotc_data = $DB->stashData("creamofthecool");
    if ($cotc_data && ref($cotc_data) eq 'ARRAY') {
        my @creamofthecool;
        foreach my $item (@$cotc_data) {
            my $parent = $item->{parent_e2node} ? $DB->getNodeById($item->{parent_e2node}) : undef;
            my $author = $item->{author_user} ? $DB->getNodeById($item->{author_user}) : undef;

            # Truncate content to 512 chars for display
            # Send raw doctext - React will parse E2 links client-side
            my $content = $item->{doctext} || '';
            my $truncated = 0;
            if (length($content) > 512) {
                $content = substr($content, 0, 512);
                $content =~ s/\s+\w*$//; # Don't break words
                $truncated = 1;
            }

            push @creamofthecool, {
                node_id => $item->{node_id},
                parent => $parent ? {
                    node_id => $parent->{node_id},
                    title => $parent->{title}
                } : undef,
                author => $author ? {
                    node_id => $author->{node_id},
                    title => $author->{title}
                } : undef,
                type => $item->{type_title},
                content => $content,
                truncated => $truncated ? 1 : 0
            };
        }
        $data->{creamofthecool} = \@creamofthecool;
    }

    # Load News for Noders (frontpagenews)
    unless ($is_guest) {
        my $news_data = $DB->stashData("frontpagenews");
        if ($news_data) {
            $news_data = [$news_data] unless ref($news_data) eq 'ARRAY';
            my @news;
            foreach my $entry (@$news_data) {
                my $n = $DB->getNodeById($entry->{to_node});
                # Skip removed nodes and drafts
                next unless $n && $n->{type}{title} ne 'draft';

                my $author = $n->{author_user} ? $DB->getNodeById($n->{author_user}) : undef;

                # Get document text for news items
                # Send raw doctext - React will parse E2 links client-side
                my $doc = $DB->sqlSelectHashref('doctext', 'document', "document_id = $entry->{to_node}");
                my $content = $doc->{doctext} || '';

                push @news, {
                    node_id => $n->{node_id},
                    title => $n->{title},
                    author => $author ? {
                        node_id => $author->{node_id},
                        title => $author->{title}
                    } : undef,
                    content => $content,
                    linkedby => $entry->{linkedby},
                    createtime => $n->{createtime}
                };
            }
            $data->{news} = \@news;
        }
    }

    return $data;
}

__PACKAGE__->meta->make_immutable;
1;
