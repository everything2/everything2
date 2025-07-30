#!/bin/bash

killall /usr/sbin/apache2
sleep 3
mkdir /var/everything/www/nytprof
chmod 0755 /var/everything/www/nytprof
chown www-data /var/everything/www/nytprof
PATH=/var/libraries/bin:$PATH PERL5LIB=/var/libraries/lib/perl5 nytprofmerge --out /tmp/nytprof-merged /tmp/nytprof.*
PATH=/var/libraries/bin:$PATH PERL5LIB=/var/libraries/lib/perl5 nytprofhtml -o /var/everything/www/nytprof -f /tmp/nytprof-merged
/usr/sbin/apachectl -k start