package Everything::DataStash::bestrecentnodes;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

# Run daily (86400 seconds = 24 hours)
has '+interval' => (default => 86400);
has '+lengthy' => (default => 1);

sub generate
{
  my ($this) = @_;

  # Get badwords list from configuration
  my $badwords = $this->CONF->google_ads_badwords;

  # Build regex pattern for badwords matching
  # We check both title and a snippet of doctext
  my $badwords_pattern = join('|', map { quotemeta($_) } @$badwords);

  # Get the highest rated writeups from the last 3 months
  # We fetch more than 100 to account for filtering
  my $csr = $this->DB->sqlSelectMany(
    'wu.node_id as writeup_id,
     wu.title as writeup_title,
     wu.reputation,
     wu.author_user,
     author.title as author_name,
     writeup.parent_e2node,
     parent.title as parent_title,
     SUBSTRING(document.doctext, 1, 500) as snippet,
     writeup.publishtime',
    'node wu
     JOIN writeup ON writeup.writeup_id = wu.node_id
     JOIN document ON document.document_id = wu.node_id
     JOIN node parent ON parent.node_id = writeup.parent_e2node
     JOIN node author ON author.node_id = wu.author_user',
    "wu.type_nodetype = (SELECT node_id FROM node WHERE title = 'writeup' AND type_nodetype = 1)
     AND writeup.publishtime > DATE_SUB(CURDATE(), INTERVAL 90 DAY)
     AND wu.reputation > 0",
    "ORDER BY wu.reputation DESC LIMIT 500"
  );

  my @results;
  my $count = 0;
  my $max_results = 100;

  while (my $row = $csr->fetchrow_hashref()) {
    last if $count >= $max_results;

    # Check title for badwords
    my $title_clean = 1;
    if ($badwords_pattern && $row->{parent_title} =~ /\b($badwords_pattern)/i) {
      $title_clean = 0;
    }
    if ($badwords_pattern && $row->{writeup_title} =~ /\b($badwords_pattern)/i) {
      $title_clean = 0;
    }

    # Check snippet for badwords
    my $snippet_clean = 1;
    if ($badwords_pattern && $row->{snippet} && $row->{snippet} =~ /\b($badwords_pattern)/i) {
      $snippet_clean = 0;
    }

    # Skip if contains badwords
    next unless $title_clean && $snippet_clean;

    # Strip HTML from snippet for storage
    my $clean_snippet = $row->{snippet} || '';
    $clean_snippet =~ s/<[^>]+>//g;
    $clean_snippet =~ s/\s+/ /g;
    $clean_snippet =~ s/^\s+|\s+$//g;

    # Truncate snippet to reasonable length
    if (length($clean_snippet) > 200) {
      $clean_snippet = substr($clean_snippet, 0, 200);
      $clean_snippet =~ s/\s+\S*$/.../;
    }

    push @results, {
      writeup_id => $row->{writeup_id},
      writeup_title => $row->{writeup_title},
      parent_e2node => $row->{parent_e2node},
      parent_title => $row->{parent_title},
      author_user => $row->{author_user},
      author_name => $row->{author_name},
      reputation => $row->{reputation},
      snippet => $clean_snippet,
      publishtime => $row->{publishtime},
    };

    $count++;
  }

  return $this->SUPER::generate(\@results);
}

__PACKAGE__->meta->make_immutable;
1;
