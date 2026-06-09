requires 'Carp';
requires 'Clone';
requires 'Compress::Zlib';
requires 'Data::Dumper';
requires 'DateTime';
requires 'DateTime::Format::Strptime';
requires 'DBD::mysql';
requires 'DBI';
requires 'Devel::Caller';
requires 'Digest::MD5';
requires 'Digest::SHA';
requires 'Encode';
requires 'File::Copy';
requires 'HTML::Defang';
requires 'HTML::Scrubber';
requires 'HTTP::Cookies';
requires 'HTTP::Request';
requires 'IO::Compress::Brotli';
requires 'IO::Compress::Deflate';
requires 'IO::Compress::Zstd';
requires 'JSON';
requires 'JSON::XS';
requires 'LWP::UserAgent';
requires 'Module::Pluggable';
requires 'Moose';

# Handled by Ubuntu LTS for now
# requires 'Image::Magick';

# Paws requirements
requires 'Ref::Util::XS';
requires 'Cpanel::JSON::XS';
requires 'JSON::MaybeXS';
requires 'Mozilla::CA';
requires 'Paws';

requires 'Test::Deep::NoTest';
requires 'Time::Local';
requires 'Try::Tiny';
requires 'URI';
requires 'XML::Generator';
requires 'XML::Parser';
requires 'XML::Simple';
requires 'namespace::autoclean';

# PSGI/Plack stack — pre-positioned for the mod_perl -> Starman migration.
# Apache::DBI was removed here (#4228); connection persistence is now DBI-native
# (connect_cached), which carries forward to PSGI unchanged.
requires 'Plack';
requires 'Starman';
requires 'Server::Starter';

#Development Only
requires 'Devel::NYTProf';
requires 'Devel::Cover';
requires 'Perl::Tidy';
requires 'Perl::Critic';

# Memory-leak profiling for the PSGI/Starman soak (leak hunting that mod_perl's
# Apache2::SizeLimit used to mask). Test::LeakTrace = CI leak tests; Gladiator =
# arena census; Cycle = circular-ref finder; MAT(::Dumper) = heap-dump + offline
# analysis. Dev/staging only -- never loaded on the prod hot path.
requires 'Test::LeakTrace';
requires 'Devel::Gladiator';
requires 'Devel::Cycle';
requires 'Devel::MAT::Dumper';
requires 'Devel::MAT';
