package Everything::Page::guest_front_page;

use Moose;
extends 'Everything::Page';

# Guest Front Page - the landing page for non-authenticated users
#
# Shows: Best of The Week (altfrontpagecontent), News for Noders
# Type: fullpage (renders complete HTML document with header, sidebar, footer)

# Use HTMLShell for HTML generation (no template needed)
# This gives us the React header and unified page layout
sub template { return ''; }

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

    # Hero section content
    my $hero = {
        headline => 'Everything2',
        tagline => 'A community-driven writing platform since 1999',
        description => 'Our writers explore everything from personal narratives to technical deep-dives, fiction to philosophy, book reviews to recipes, travel journals to dream logs - all in a space that values craft, curiosity, and genuine human expression.',
        cta => {
            text => 'Start Reading',
            url => '/title/Cool%20Archive'
        }
    };

    my $data = {
        type => 'guest_front_page',
        is_guest => 1,
        hidePageHeader => 1,
        hero => $hero,
        pagenodelets => [$sign_in_id, $rec_reading_id, $new_writeups_id]
    };

    # Build badwords pattern for filtering guest content
    my $badwords = $Everything::CONF->google_ads_badwords;
    my $badwords_pattern = '';
    if ($badwords && ref($badwords) eq 'ARRAY' && @$badwords) {
        $badwords_pattern = join('|', map { quotemeta($_) } @$badwords);
    }

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

            # Filter out content with badwords for guest users
            if ($badwords_pattern) {
                # Check parent title
                next if $parent && $parent->{title} =~ /\b($badwords_pattern)\b/i;
                # Check content excerpt
                next if $content =~ /\b($badwords_pattern)\b/i;
            }

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

            # Filter out news with badwords for guest users
            if ($badwords_pattern) {
                next if $n->{title} =~ /\b($badwords_pattern)\b/i;
                next if $content =~ /\b($badwords_pattern)\b/i;
            }

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
