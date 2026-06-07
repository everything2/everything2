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
  /etc/init.d/mysql start
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
  /etc/init.d/mysql stop
fi

mysqld_safe
