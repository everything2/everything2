PERLVER=5.26.3
MAGICKVER=6.9.11-22
CMAKEVER=3.18.0-rc2
MYSQLVER=8.0.20
BOOSTVER=1_70_0
CPANMVER=1.7044

INSTALL=$(shell pwd)/install
PERL=$(INSTALL)/bin/perl
CMAKE=$(INSTALL)/bin/cmake


all.build: $(PERL) magick.build deps.build
	echo "Cleaning for distribution"
	rm -rf $(INSTALL)/share/doc $(INSTALL)/doc $(INSTALL)/share/cmake* $(INSTALL)/man $(INSTALL)/bin/ctest $(INSTALL)/README $(INSTALL)/LICENSE
	touch $@

$(PERL): 3rd/perl-$(PERLVER).tar.bz2
	mkdir -p build && cd build && tar xjvf ../3rd/perl-$(PERLVER).tar.bz2
	cd build/perl-$(PERLVER)/ && ./Configure -d -e -Dotherlibdirs=.../../lib/perl5 -Dman1dir=none -Dman3dir=none -Dinstallprefix=/ -Duserelocatableinc -Dusethreads -Dprefix=/ && make && make install DESTDIR=$(INSTALL)
	rm $(INSTALL)/*.0
	rm -rf $(INSTALL)/lib/perl5/$(PERLVER)/Test*
	touch $@

mysql.build: $(CMAKE) 3rd/mysql-boost-$(MYSQLVER).tar.gz boost.unzip
	mkdir -p build && cd build && tar xzvf ../3rd/mysql-boost-$(MYSQLVER).tar.gz && cd mysql-$(MYSQLVER) && $(CMAKE) -DDOWNLOAD_BOOST_TIMEOUT=6000 -DWITHOUT_SERVER=1 -DFORCE_INSOURCE_BUILD=1 -DCMAKE_INSTALL_PREFIX=$(INSTALL) -DLOCAL_BOOST_DIR=../boost_$(BOOSTVER) ../mysql-$(MYSQLVER) && make && make install
	touch $@

$(CMAKE): 3rd/cmake-$(CMAKEVER).tar.gz
	mkdir -p build && cd build && tar xzvf ../3rd/cmake-$(CMAKEVER).tar.gz && cd cmake-$(CMAKEVER) && ./configure --prefix=$(INSTALL) && make && make install
	touch $@

boost.unzip: 3rd/boost_$(BOOSTVER).tar.gz
	mkdir -p build && cd build && tar zxvf ../3rd/boost_$(BOOSTVER).tar.gz
	touch $@

3rd/boost_$(BOOSTVER).tar.gz:
	mkdir -p 3rd && cd 3rd && wget https://dl.bintray.com/boostorg/release/1.70.0/source/boost_$(BOOSTVER).tar.gz
	touch $@

magick.build: 3rd/ImageMagick-$(MAGICKVER).tar.gz $(PERL)
	mkdir -p build && cd build && tar xzvf ../3rd/ImageMagick-$(MAGICKVER).tar.gz && cd ImageMagick-$(MAGICKVER) && ./configure --prefix=$(INSTALL) --with-perl=$(PERL) && make && make install && $(PERL) -MImage::Magick -le 'print Image::Magick->QuantumDepth'
	touch $@

deps.build: $(PERL) mysql.build
	PATH=$(INSTALL)/bin/:$(PATH) $(PERL) ../tools/createdeps.pl --depfile=./deplists/app.json 2>&1 | tee deps.log && touch $@

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

cpanm.build: $(PERL) 3rd/App-cpanminus-$(CPANMVER).tar.gz
	mkdir -p build && cd build && tar xzvf ../3rd/App-cpanminus-$(CPANMVER).tar.gz && cd App-cpanminus-$(CPANMVER) && $(PERL) Makefile.PL PREFIX=$(INSTALL) && make && make install
	touch $@

3rd/App-cpanminus-$(CPANMVER).tar.gz:
	mkdir -p 3rd && cd 3rd && wget https://cpan.metacpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-1.7044.tar.gz
	touch $@

altmodules.build: $(PERL)
	$(PERL) $(INSTALL)/bin/cpanm --local-lib=$(INSTALL) Moose LWP::UserAgent
	touch $@

clean:
	rm -rf build/* install/* *.build nytprof.* *.log inc *.unzip

distclean: clean
	rm -rf 3rd/*
