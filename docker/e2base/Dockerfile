FROM everything2/e2lib

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata perl apache2 libalgorithm-diff-perl libarchive-zip-perl libcgi-pm-perl libcache-perl libapache2-mod-perl2 libdbi-perl libdate-calc-perl libdatetime-perl libdatetime-format-strptime-perl libhtml-tiny-perl libheap-perl libio-string-perl perlmagick libjson-perl libxml-generator-perl libxml-simple-perl libyaml-perl libapache-dbi-perl libclone-perl libtest-deep-perl libdevel-caller-perl libdbd-mysql-perl libnet-smtp-ssl-perl libauthen-sasl-perl libxml-rss-perl libmoose-perl libnamespace-autoclean-perl libwww-perl libperl-critic-perl libmason-perl libmason-plugin-htmlfilters-perl libtry-tiny-perl yui-compressor libapache-db-perl libdevel-nytprof-perl libdevel-cycle-perl collectd mysql-client ruby

ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN cd /var && git clone https://github.com/everything2/everything2.git everything

RUN mkdir -p /etc/everything /var/mason /var/log/everything
RUN chown root:root /etc/everything
RUN chown www-data:www-data /var/mason /var/log/everything
RUN chmod 0755 /var/mason

RUN gem install aws-sdk-rds aws-sdk-elasticloadbalancingv2 aws-sdk-iam aws-sdk-secretsmanager aws-sdk-ses aws-sdk-opsworks aws-sdk-ec2 aws-sdk-lambda

