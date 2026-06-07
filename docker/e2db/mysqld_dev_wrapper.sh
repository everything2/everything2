#!/bin/bash

if [ ! -e /etc/everything/dev_db_ready ]
then
  usermod -d /var/lib/mysql/ mysql
  cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysqld.cnf.old
# Removed sql_mode="ALLOW_INVALID_DATES" workaround (#2210) -- the zero-date
# default family is fixed, so dev now runs MySQL's default strict sql_mode
# (incl. NO_ZERO_DATE) to catch any zero-date regression before 8.4.
# echo 'general_log=1' >> /etc/mysql/mysql.conf.d/mysqld.cnf
# echo 'general_log_file=/var/log/mysql/general.log' >> /etc/mysql/mysql.conf.d/mysqld.cnf
  echo 'wait_timeout=31536000' >> /etc/mysql/mysql.conf.d/mysqld.cnf
  echo 'interactive_timeout=31536000' >> /etc/mysql/mysql.conf.d/mysqld.cnf
  sed -i "s/bind-address.*/bind-address = 0.0.0.0/g" /etc/mysql/mysql.conf.d/mysqld.cnf
  # Ubuntu 26.04 / MySQL 8.4 dropped the SysV init.d script, so the old
  # `/etc/init.d/mysql start` no longer exists -- the bootstrap silently ran
  # every CREATE/GRANT/qareload against a dead socket (ERROR 2002), everyuser
  # never got created, and the app 500'd with "Host not allowed to connect".
  # Start the bootstrap server directly in the background instead, then block
  # until it actually answers a query before bootstrapping.
  mysqld_safe &
  for i in $(seq 1 60); do
    echo 'SELECT 1' | mysql --user=root >/dev/null 2>&1 && break
    sleep 1
  done
  echo "development" > /etc/everything/override_configuration
  echo "CREATE DATABASE everything DEFAULT CHARACTER SET=utf8mb4 COLLATE utf8mb4_0900_ai_ci;" | mysql --user=root
  # Explicit caching_sha2_password WITH a real password so dev fully mirrors the
  # MySQL 8.4 target auth -- the plugin AND the full-auth / RSA-over-TLS handshake
  # a real password triggers, not an empty-password short-circuit. The app and
  # qareload read the matching password from database_password_secret (#4122).
  echo "CREATE USER 'everyuser'@'%' IDENTIFIED WITH caching_sha2_password BY 'blah'; " | mysql --user=root
  echo "GRANT ALL ON *.* to 'everyuser'@'%';" | mysql --user=root
  # Matching secret for qareload's connection below. No trailing newline --
  # _filesystem_default() slurps the file verbatim, so a newline would corrupt it.
  printf 'blah' > /etc/everything/database_password_secret
  cp /var/everything/etc/development.json /var/everything/etc/development.json.old
  cp /var/everything/etc/docker-mysql-development.json /var/everything/etc/development.json
  /var/everything/tools/qareload.pl
  touch /etc/everything/dev_db_ready
  mv /var/everything/etc/development.json.old /var/everything/etc/development.json
  # Shut the bootstrap server down cleanly (init.d 'stop' is gone on 26.04) and
  # wait for the socket to disappear before the foreground server takes over,
  # so the two mysqld instances don't fight over the datadir/socket.
  mysqladmin --user=root shutdown
  for i in $(seq 1 60); do
    [ -S /var/run/mysqld/mysqld.sock ] || break
    sleep 1
  done
fi

mysqld_safe
