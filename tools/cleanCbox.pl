#!/usr/bin/perl -w -I /var/everything/ecore

use Everything;
initEverything 'everything';

my $expireInSeconds = 500;

my $messageSaveSQL = <<ENDSQL;
INSERT INTO publicmessages
  (message_id, msgtext, tstamp, author_user)
  SELECT message_id, msgtext, tstamp, author_user
    FROM message
    WHERE TIMESTAMPADD(SECOND, -$expireInSeconds, NOW()) > tstamp
      AND for_user = 0
    ORDER BY tstamp ASC
  ON DUPLICATE KEY UPDATE
    publicmessages.tstamp = message.tstamp
ENDSQL
$DB->{dbh}->do($messageSaveSQL);

$DB->sqlDelete("message", "for_user=0 AND TIMESTAMPADD(SECOND, -$expireInSeconds, NOW()) > tstamp");
#clean up the chatterbox table


