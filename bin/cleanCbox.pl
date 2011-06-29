#!/usr/bin/perl -w -I /var/everything/ecore

use Everything;
initEverything 'everything';

my $messageSaveSQL = <<ENDSQL;
INSERT INTO publicmessages
  (message_id, msgtext, tstamp, author_user)
  SELECT message_id, msgtext, tstamp, author_user
    FROM message
    WHERE (NOW() - 500) > tstamp
      AND for_user = 0
    ORDER BY tstamp ASC
  ON DUPLICATE KEY UPDATE
    publicmessages.tstamp = message.tstamp
ENDSQL
my $dbh = $DB->getDatabaseHandle();
$dbh->do($messageSaveSQL);

$DB->sqlDelete("message", "for_user=0 AND (NOW() - 500) > tstamp");
#clean up the chatterbox table


