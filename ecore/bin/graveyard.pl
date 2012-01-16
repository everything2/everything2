#!/usr/bin/perl -w
#a short script to keep the tomb table clean

use strict;
use lib "/var/everything/ecore";
use Everything;
initEverything 'everything';

my ($user,$pass) = ($CONFIG{'everyuser'}, $CONFIG{'everypass'});
my $dbserv = $CONFIG{'everything_dbserv'};
my @date = localtime(time);
my $datestr = ($date[4]+1)."-".sprintf("%02d",$date[3])."-".(1900+$date[5]);

$datestr = "/var/everything/graveyard/".$datestr.".gz";

`/usr/bin/mysqldump -t -h $dbserv -u $user -p$pass everything tomb | gzip > $datestr`;
$dbh->do("delete from tomb");
#`/bin/zcat $datestr | /usr/bin/perl -pe "s/INSERT INTO \`tomb\`/INSERT INTO \`heaven\`/g" | /usr/bin/mysql -h $dbserv -u $user -p$pass -f everything`
`/bin/zcat $datestr | \
/usr/bin/perl -pe "s/INSERT INTO \\\`tomb\\\`/INSERT INTO \\\`heaven\\\`/g" | \
/usr/bin/perl -pe "s/LOCK TABLES \\\`tomb\\\`/LOCK TABLES \\\`heaven\\\`/g" | \
/usr/bin/perl -pe "s/ALTER TABLE \\\`tomb\\\`/ALTER TABLE \\\`heaven\\\`/g" | \
/usr/bin/mysql -h $dbserv -u $user -p$pass -f everything`

