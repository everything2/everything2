package Everything::Page::guest_front_page;

use Moose;
extends 'Everything::Page';

# Guest Front Page - the landing page for non-authenticated users
#
# Shows: Best of The Week (altfrontpagecontent), News for Noders
# Type: fullpage (renders complete HTML document with header, sidebar, footer)

# Use the guest_front_page template which includes full layout
sub template { return 'guest_front_page'; }

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;
    my $VARS = $REQUEST->user->VARS;

    # Ensure guest users have nodelets configured for proper e2 config generation
    unless ($VARS->{nodelets}) {
        my $guest_nodelets = $Everything::CONF->guest_nodelets;
        if ($guest_nodelets && ref($guest_nodelets) eq 'ARRAY' && @$guest_nodelets) {
            $VARS->{nodelets} = join(',', @$guest_nodelets);
        }
    }

    # Get nodelet IDs for sidebar
    my $sign_in_id = $DB->getNode('Sign in', 'nodelet')->{node_id};
    my $rec_reading_id = $DB->getNode('Recommended Reading', 'nodelet')->{node_id};
    my $new_writeups_id = $DB->getNode('New Writeups', 'nodelet')->{node_id};

    # Witty taglines for the welcome message
    my @wit = (
        "Defying definition since 1999",
        "Literary Karaoke",
        "Writing everything about everything.",
        "E2, Brute?",
        "Our fiction is more entertaining than Wikipedia's.",
        "You will never find a more wretched hive of ponies and buttercups.",
        "Please try to make more sense than our blurbs.",
        "Words arranged in interesting ways",
        "Remove lid. Add water to fill line. Replace lid. Microwave for 1 1/2 minutes. Let cool for 3 minutes.",
        "Welcome to the rebirth of your desire to write.",
        "Don't know where this \"writers' site\" crap came from but it sure as hell isn't in the prospectus.",
        "Read, write, enjoy.",
        "Everything2.com has baked you a pie! (Do not eat it.)"
    );

    my $data = {
        type => 'guest_front_page',
        is_guest => 1,
        tagline => $wit[int(rand(@wit))],
        pagenodelets => [$sign_in_id, $rec_reading_id, $new_writeups_id]
    };

    # Load Best of The Week (altfrontpagecontent)
    my $altcontent_data = $DB->stashData("altfrontpagecontent");
    if ($altcontent_data && ref($altcontent_data) eq 'ARRAY') {
        my @bestofweek;
        foreach my $node_id (@$altcontent_data) {
            my $n = $DB->getNodeById($node_id);
            next unless $n;

            # Get writeup info
            my $writeup = $DB->sqlSelectHashref('*', 'writeup', "writeup_id = $node_id");
            next unless $writeup;

            my $parent = $writeup->{parent_e2node} ? $DB->getNodeById($writeup->{parent_e2node}) : undef;
            my $author = $n->{author_user} ? $DB->getNodeById($n->{author_user}) : undef;
            my $type_node = $writeup->{wrtype_writeuptype} ? $DB->getNodeById($writeup->{wrtype_writeuptype}) : undef;

            # Get document text
            my $doc = $DB->sqlSelectHashref('doctext', 'document', "document_id = $node_id");
            my $content = $doc->{doctext} || '';

            # Truncate to ~1024 chars for display
            # Send raw doctext - React will parse E2 links client-side
            my $truncated = 0;
            if (length($content) > 1024) {
                $content = substr($content, 0, 1024);
                $content =~ s/\s+\w*$//;
                $truncated = 1;
            }

            push @bestofweek, {
                node_id => $node_id,
                parent => $parent ? {
                    node_id => $parent->{node_id},
                    title => $parent->{title}
                } : undef,
                author => $author ? {
                    node_id => $author->{node_id},
                    title => $author->{title}
                } : undef,
                type => $type_node ? $type_node->{title} : undef,
                content => $content,
                truncated => $truncated
            };
        }
        $data->{bestofweek} = \@bestofweek;
    }

    # Load News for Noders (frontpagenews)
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

    return $data;
}

__PACKAGE__->meta->make_immutable;
1;
