PERLVER=5.26.3
MAGICKVER=6.9.11-22
CMAKEVER=3.18.0-rc2
MYSQLVER=8.0.20
BOOSTVER=1_70_0
CPANMVER=1.7044
P7ZIPVER=16.02
LIBXMLVER=2.9.10

INSTALL=$(shell pwd)/install
PERL=$(INSTALL)/bin/perl
CMAKE=$(INSTALL)/bin/cmake
P1CACHE=$(shell pwd)/cache/phase1.zip
BOOSTUNZIP=$(shell pwd)/build/boost_1_70_0/README.md


P7ZIPCOPYFILE=

ifeq ($(shell /usr/bin/sw_vers 2>/dev/null),)
  P7ZIPCOPYFILE=linux_any_cpu
else
  P7ZIPCOPYFILE=macosx_llvm_64bits
endif

e2serverless.zip: deps.build p7zip.build
	echo "Cleaning for distribution"
	rm -rf $(INSTALL)/share $(INSTALL)/include $(INSTALL)/man $(INSTALL)/lib/*.a $(INSTALL)/lib/pkgconfig $(INSTALL)/doc $(INSTALL)/share/cmake* $(INSTALL)/README $(INSTALL)/LICENSE
	for file in Magick++-config Magick-config MagickCore-config MagickWand-config Wand-config animate ccmake cmake comp_err compare composite config_data conjure convert corelist cpack cpan crc32 ctest dateparse dbilogstrip dbiprof dbiproxy display enc2xs encguess findrule flamegraph.pl h2ph h2xs identify import instmodsh json_pp libnetcfg lwp-download lwp-dump lwp-mirror lwp-request lz4_decompress mason.pl mogrify montage moose-outdated my_print_defaults mysql mysql_config mysql_config_editor mysql_secure_installation mysql_ssl_rsa_setup mysqladmin mysqlbinlog mysqlcheck mysqldump mysqlimport mysqlpump mysqlshow mysqlslap mysqltest nytprofcalls nytprofcg nytprofcsv nytprofhtml nytprofmerge nytprofpf open_aws_console package-stash-conflicts paws paws_make_testcase perl5.26.3 perlbug perlcritic perldoc perlivp perlthanks perltidy perror piconv pl2pm pm_which pod2html pod2man pod2text pod2usage podchecker podselect podspell prove ptar ptardiff ptargrep s3cl scandeps.pl shasum splain stream test-yaml use-devel-checklib xsubpp zipdetails zlib_decompress; do \
		rm -f $(INSTALL)/bin/$$file ; \
	done
	find $(INSTALL) -name "libperl.a" -type f -exec rm -f {} \;
	cd $(INSTALL) && zip ../perlbase.zip -r -y -9 * && cd ..
	cp $(INSTALL)/bin/7za .
	chmod +x bootstrap handler.pl 7za
	zip ./e2serverless.zip -9 bootstrap handler.pl perlbase.zip 7za
	touch $@

codepipeline.build: e2serverless.zip
	aws s3 cp e2serverless.zip s3://perllambdabase.everything2.com
	aws lambda update-function-code --function-name=perl-lambda-base --s3-bucket=perllambdabase.everything2.com --s3-key=e2serverless.zip
	aws lambda publish-layer-version --content=S3Bucket=perllambdabase.everything2.com,S3Key=e2serverless.zip --layer-name=e2-perl-layer --description="Perl layer for E2" --compatible-runtimes provided
	aws lambda invoke --function-name=cicd-codebuild-perl-layer-publisher ./perl-publisher.log
	touch $@

$(PERL): 3rd/perl-$(PERLVER).tar.bz2
ifneq ("","$(wildcard $(P1CACHE))")
	cd $(INSTALL) && unzip -n $(P1CACHE) && cd ..
else
	echo "Could not find cache: $(P1CACHE)"
	mkdir -p build && cd build && tar xjvf ../3rd/perl-$(PERLVER).tar.bz2
	cd build/perl-$(PERLVER)/ && ./Configure -d -e -Dotherlibdirs=.../../lib/perl5 -Dman1dir=none -Dman3dir=none -Dinstallprefix=/ -Duserelocatableinc -Dusethreads -Dprefix=/ && make && make install DESTDIR=$(INSTALL)
	rm $(INSTALL)/*.0
	rm -rf $(INSTALL)/lib/perl5/$(PERLVER)/Test*
endif
	touch $@


mysql.build: $(CMAKE) 3rd/mysql-boost-$(MYSQLVER).tar.gz $(BOOSTUNZIP)
ifneq ("","$(wildcard $(P1CACHE))")
	cd $(INSTALL) && unzip -n $(P1CACHE) && cd ..
else
	mkdir -p build && cd build && tar xzf ../3rd/mysql-boost-$(MYSQLVER).tar.gz && cd mysql-$(MYSQLVER) && $(CMAKE) -DDOWNLOAD_BOOST_TIMEOUT=6000 -DWITHOUT_SERVER=1 -DFORCE_INSOURCE_BUILD=1 -DCMAKE_INSTALL_PREFIX=$(INSTALL) -DLOCAL_BOOST_DIR=../boost_$(BOOSTVER) ../mysql-$(MYSQLVER) && make && make install
	touch $@
endif

$(CMAKE): 3rd/cmake-$(CMAKEVER).tar.gz
ifneq ("","$(wildcard $(P1CACHE))")
	cd $(INSTALL) && unzip -n $(P1CACHE) & cd ..
else
	mkdir -p build && cd build && tar xzf ../3rd/cmake-$(CMAKEVER).tar.gz && cd cmake-$(CMAKEVER) && ./configure --prefix=$(INSTALL) && make && make install
	touch $@
endif

$(BOOSTUNZIP): 3rd/boost_$(BOOSTVER).tar.gz
	mkdir -p build && cd build && tar zxvf ../3rd/boost_$(BOOSTVER).tar.gz
	touch $@

3rd/boost_$(BOOSTVER).tar.gz:
	mkdir -p 3rd && cd 3rd && wget https://dl.bintray.com/boostorg/release/1.70.0/source/boost_$(BOOSTVER).tar.gz
	touch $@

libxml2.build: 3rd/libxml2-$(LIBXMLVER).tar.gz
	mkdir -p build && cd build && tar zxvf ../3rd/libxml2-$(LIBXMLVER).tar.gz && cd libxml2-$(LIBXMLVER) && ./configure --prefix=$(INSTALL) --without-python && make && make install
	touch $@

3rd/libxml2-$(LIBXMLVER).tar.gz:
	mkdir -p 3rd && cd 3rd && wget ftp://xmlsoft.org/libxml2/libxml2-$(LIBXMLVER).tar.gz
	touch $@

magick.build: 3rd/ImageMagick-$(MAGICKVER).tar.gz $(PERL)
	mkdir -p build && cd build && tar xzf ../3rd/ImageMagick-$(MAGICKVER).tar.gz && cd ImageMagick-$(MAGICKVER) && ./configure --prefix=$(INSTALL) --with-perl=$(PERL) && make && make install && $(PERL) -MImage::Magick -le 'print Image::Magick->QuantumDepth'
	touch $@

$(P1CACHE): $(PERL) mysql.build libxml2.build magick.build
	cd $(INSTALL) && zip ../cache/phase1.zip -r -y -9 * && cd ..
	touch $@

deps.build: $(P1CACHE)
	rm -rf $(INSTALL)/*
	cd $(INSTALL) && unzip -n ../cache/phase1.zip && cd ..
	PATH=$(INSTALL)/bin/:$(PATH) $(PERL) ../tools/createdeps.pl --depfile=$(shell pwd)/deplists/app.json --dldir=$(shell pwd)/3rd --installdir=$(shell pwd)/install --builddir=$(shell pwd)/build && touch $@

p7zip.build: 3rd/p7zip_$(P7ZIPVER)_src_all.tar.bz2
	echo "Using p7zip makefile: $(P7ZIPCOPYFILE)"
	mkdir -p build && cd build && tar xjvf ../3rd/p7zip_$(P7ZIPVER)_src_all.tar.bz2 && cd p7zip_$(P7ZIPVER) && cp makefile.$(P7ZIPCOPYFILE) makefile.machine && make -f makefile && cp bin/7za $(INSTALL)/bin
	touch $@

3rd/p7zip_$(P7ZIPVER)_src_all.tar.bz2:
	mkdir -p 3rd && cd 3rd && wget https://gigenet.dl.sourceforge.net/project/p7zip/p7zip/16.02/p7zip_16.02_src_all.tar.bz2
	touch $@

3rd/perl-$(PERLVER).tar.bz2:
	mkdir -p 3rd && cd 3rd && wget https://www.cpan.org/src/5.0/perl-$(PERLVER).tar.bz2
	touch $@

3rd/ImageMagick-$(MAGICKVER).tar.gz:
	mkdir -p 3rd && cd 3rd && wget https://imagemagick.org/download/releases/ImageMagick-$(MAGICKVER).tar.gz
	touch $@

3rd/cmake-$(CMAKEVER).tar.gz:
	mkdir -p 3rd && cd 3rd && wget https://github.com/Kitware/CMake/releases/download/v$(CMAKEVER)/cmake-$(CMAKEVER).tar.gz
	touch $@

3rd/mysql-boost-$(MYSQLVER).tar.gz:
	mkdir -p 3rd && cd 3rd && wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-boost-$(MYSQLVER).tar.gz
	touch $@

lightclean:
	rm -rf install/* *.build nytprof.* *.log inc *.unzip *.zip

clean: lightclean
	rm -rf build/* 7za

cacheclean: clean
	rm -rf cache/*

distclean: clean
	rm -rf 3rd/*
