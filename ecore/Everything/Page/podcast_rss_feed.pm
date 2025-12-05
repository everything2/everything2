package Everything::Page::podcast_rss_feed;

use Moose;
use POSIX qw(strftime);
use XML::Generator;
use utf8;

extends 'Everything::Page';

has 'mimetype' => (default => 'application/rss+xml', is => 'ro');

=head1 NAME

Everything::Page::podcast_rss_feed - Podcast RSS Feed

=head1 DESCRIPTION

Returns RSS 2.0 feed with iTunes extensions for the Everything2 Podcast.
Lists the latest 100 podcast episodes with audio enclosures.

=head1 METHODS

=head2 display($REQUEST, $node)

Generates RSS feed for podcasts using XML::Generator.

=cut

sub display {
    my ($self, $REQUEST, $node) = @_;

    # XML::Generator with namespace support
    my $XG = XML::Generator->new(':pretty');

    # Get podcast data
    my $csr = $self->DB->sqlSelectMany(
        "link, title, podcast_id, description, pubDate",
        "podcast JOIN node ON podcast_id = node_id",
        "1",
        "ORDER BY pubDate DESC LIMIT 100"
    );

    my $now_str = strftime("%a, %d %b %Y %H:%M:%S %z", localtime(time()));

    # Build channel header
    my $channel_content =
        $XG->title('Everything2 Podcast') .
        $XG->description('Users of Everything2 read out writeups and maybe ramble a bit') .
        $XG->link('http://everything2.com/title/Podcaster') .
        $XG->language('en') .
        $XG->copyright("Copyright $now_str") .
        $XG->lastBuildDate($now_str) .
        $XG->pubDate($now_str) .
        $XG->docs('http://blogs.law.harvard.edu/tech/rss') .
        $XG->webMaster('e2webmaster@everything2.com') .
        '<itunes:author>podpeople @ Everything2</itunes:author>' .
        '<itunes:subtitle>The E2 Podcast is a collection of nodes from everything2.com, read aloud by noders.</itunes:subtitle>' .
        '<itunes:summary>The Everything2 Podcast is a collection of writeups from Everything2.com, read aloud by various volunteers from the E2 community.</itunes:summary>' .
        '<itunes:owner><itunes:name>podpeople</itunes:name><itunes:email>podcast@everything2.com</itunes:email></itunes:owner>' .
        '<itunes:explicit>Yes</itunes:explicit>' .
        '<itunes:image href="http://e2podcast.spunkotronic.com/images/podcastlogo.jpg"/>' .
        '<itunes:category text="Arts"><itunes:category text="Literature"/></itunes:category>';

    # Build items
    my $items = '';
    if ($csr->rows) {
        my $approved_html = $self->DB->getNode('approved HTML tags', 'setting');
        my $HTML = $self->APP->getVars($approved_html);

        while (my $pod = $csr->fetchrow_hashref) {
            # Process description text
            my $text;
            if (length($$pod{description}) < 1024) {
                $text = $self->APP->parseLinks($self->APP->htmlScreen($$pod{description}, $HTML));
            } else {
                $text = substr($$pod{description}, 0, 1024);
                $text =~ s/\s+\w*$//gs;
                $text = $self->APP->parseLinks($self->APP->htmlScreen($text, $HTML));
                $text =~ s/\[.*?$//;
            }
            # XML::Generator auto-escapes, no need for encodeHTML

            my $pub_date_str = strftime("%a, %d %b %Y %H:%M:%S %z", localtime($$pod{pubdate} || time()));

            $items .= $XG->item(
                $XG->title($$pod{title}) .
                $XG->link("http://everything2.com/node/$$pod{podcast_id}") .
                $XG->guid($$pod{link}) .
                $XG->description($text) .
                $XG->enclosure({url => $$pod{link}, type => 'audio/mpeg'}) .
                $XG->category('Podcasts') .
                $XG->pubDate($pub_date_str)
            );
        }
    }

    my $xml = qq{<?xml version="1.0" encoding="UTF-8"?>\n};
    $xml .= '<rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" version="2.0">';
    $xml .= '<channel>' . $channel_content . $items . '</channel>';
    $xml .= '</rss>';

    utf8::encode($xml);

    return [$self->HTTP_OK, $xml, {type => $self->mimetype}];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
