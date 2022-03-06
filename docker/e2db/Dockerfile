FROM everything2/e2base
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install mysql-server -y
RUN mkdir /var/run/mysqld 
RUN chown mysql:mysql /var/run/mysqld
COPY mysqld_dev_wrapper.sh /var/everything
RUN chmod +x /var/everything/mysqld_dev_wrapper.sh

EXPOSE 3306
CMD ["/var/everything/mysqld_dev_wrapper.sh"]
