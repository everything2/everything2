FROM everything2/e2app
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install mysql-server -y
RUN mkdir -p /var/run/mysqld 
RUN chown mysql:mysql /var/run/mysqld
COPY docker/e2db/mysqld_dev_wrapper.sh /var/everything
RUN chmod +x /var/everything/mysqld_dev_wrapper.sh

EXPOSE 3306
CMD ["/var/everything/mysqld_dev_wrapper.sh"]
