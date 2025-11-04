#!/bin/bash

if [ ! -e /etc/everything/dev_db_ready ]
then
  usermod -d /var/lib/mysql/ mysql
  cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysqld.cnf.old
  echo 'sql_mode="ALLOW_INVALID_DATES"' >> /etc/mysql/mysql.conf.d/mysqld.cnf
#  echo 'general_log=1' >> /etc/mysql/mysql.conf.d/mysqld.cnf
  echo 'general_log_file=/var/log/mysql/general.log' >> /etc/mysql/mysql.conf.d/mysqld.cnf
  echo 'wait_timeout=31536000' >> /etc/mysql/mysql.conf.d/mysqld.cnf
  echo 'interactive_timeout=31536000' >> /etc/mysql/mysql.conf.d/mysqld.cnf
  sed -i "s/bind-address.*/bind-address = 0.0.0.0/g" /etc/mysql/mysql.conf.d/mysqld.cnf
  /etc/init.d/mysql start
  echo "development" > /etc/everything/override_configuration
  echo "CREATE DATABASE everything DEFAULT CHARACTER SET=utf8mb4 COLLATE utf8mb4_0900_ai_ci;" | mysql --user=root
  echo "CREATE USER 'everyuser'@'%'; " | mysql --user=root
  echo "GRANT ALL ON *.* to 'everyuser'@'%';" | mysql --user=root
  cp /var/everything/etc/development.json /var/everything/etc/development.json.old
  cp /var/everything/etc/docker-mysql-development.json /var/everything/etc/development.json
  /var/everything/tools/qareload.pl
  touch /etc/everything/dev_db_ready
  mv /var/everything/etc/development.json.old /var/everything/etc/development.json
  /etc/init.d/mysql stop
fi

mysqld_safe
