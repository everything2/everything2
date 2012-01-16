default.cpan_client.default_inc = []
default.cpan_client.bootstrap.deps = [
 { :module => 'local::lib', :version => '0' }, 
 { :module => 'CPAN::Version', :version => '0' }, 
 { :module => 'ExtUtils::MakeMaker' , :version => '6.31' },   
 { :module => 'CPAN::Meta::YAML' , :version => '0' },
 { :module =>  'File::Path' , :version => '2.08' },  
 { :module =>  'Dist::Metadata' , :version => '0' }, 
 { :module => 'Module::Build' , :version => '0.36_17' }
]

default.cpan_client.bootstrap.install_base = nil
default.cpan_client.minimal_version = '1.9800'
default.cpan_client.download_url = 'http://search.cpan.org/CPAN/authors/id/A/AN/ANDK/CPAN-1.9800.tar.gz'


