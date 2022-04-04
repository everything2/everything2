FROM everything2/e2base

RUN rm -f /etc/apache2/mods-enabled/mpm_event.*
RUN rm -rf /etc/apache2/sites-enabled /etc/apache2/sites-available /etc/apache2/ports.conf /etc/apache2/conf.d /etc/apache2/conf-enabled /etc/apache2/conf-available
RUN for i in deflate rewrite authz_core proxy proxy_http ssl perl mpm_prefork socache_shmcb; do ln -sf ../mods-available/$i.load /etc/apache2/mods-enabled/$i.load; done
RUN /var/everything/tools/write_apache_config.rb
RUN /var/everything/tools/generate-self-signed-cert.rb
COPY apache2_wrapper.rb /etc/everything
RUN chmod +x /etc/everything/apache2_wrapper.rb

EXPOSE 80
EXPOSE 443

CMD ["/etc/everything/apache2_wrapper.rb"]
