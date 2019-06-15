#!/usr/bin/ruby

hostname = %x{hostname}.chomp
prefixdir = "/etc/apache2"
exec "openssl req -x509 -nodes -days 365 -newkey rsa:4096 -batch -keyout #{prefixdir}/e2.key -out #{prefixdir}/e2.cert -subj '/C=US/ST=MA/L=Maynard/O=Everything2.com/OU=edev/CN=#{hostname}.deploy.everything2.com'"

