def load_current_resource

  @installer = Chef::Resource::CpanClient.new(new_resource.name)
  @installer.name(new_resource.name)
  @installer.install_base(new_resource.install_base)
  @installer.dry_run(new_resource.dry_run)
  @installer.reload_cpan_index(new_resource.reload_cpan_index)
  @installer.inc(new_resource.inc)
  @installer.install_type(new_resource.install_type)
  @installer.cwd(new_resource.cwd)
  @installer.from_cookbook(new_resource.from_cookbook)
  @installer.force(new_resource.force)
  @installer.install_path(new_resource.install_path)
  @installer.user(new_resource.user)
  @installer.group(new_resource.group)
  @installer.version(new_resource.version)
  @installer.environment(new_resource.environment)
  nil
end

def header 

  user = @installer.user
  group = @installer.group
  dry_run = @installer.dry_run
  install_type = @installer.install_type
  version = @installer.version
  cwd = @installer.cwd
  
  ruby_block 'info' do 
    block do
      print "#{dry_run == true ? 'DRYRUN' : 'REAL' } install #{install_type} #{installed_module} "
      print "cpan_client has started with rights: user=#{user} group=#{group} "
      print "install-base : #{install_base_print} "
      print "cwd : #{cwd} "
      print "install_version : #{version} "
      print "install_base: #{local_lib_stack} "
      print "perl5lib stack: #{perl5lib_stack} "
      print "install path : #{get_install_path} " unless get_install_path.empty?
      print "install_perl_code : #{install_perl_code} "
      print "environment : #{cpan_env_print} "
      print "install log file #{install_log_file} "
    end
  end
  
end


def cpan_env
  c_env = @installer.environment
  c_env['HOME'] = get_home
  c_env['MODULEBUILDRC'] = '/tmp/local-lib/.modulebuildrc'        
  c_env['PERL5LIB'] = perl5lib_stack unless perl5lib_stack.nil?
  c_env['PERL5LIB'] = "PERL_MB_OPT=$PERL_MB_OPT' #{get_install_path}'" unless get_install_path.empty?
  c_env
end

def cpan_env_print
  st = ''
  cpan_env.each {|key, value| st << "#{key}  #{value}\n" }
  st
end

def install_log_file 
  "/tmp/local-lib/#{installed_module}-install.log"
end

def install_log 

  my_installed_module = installed_module
  ruby_block 'install-log' do
    block do
        print " *** #{my_installed_module} *** "
        IO.foreach(install_log_file) do |l|
            print l if /\s--\s(OK|NOT OK)/.match(l)
            print l if /Writing.*for/.match(l) 
            print l if /Going to build/.match(l)
            print l if /^Warning:/.match(l)
            
        end
        print " *** "
    end
  end
end


def install_perl_code install_thing = '$ARGV[0]'
 cmd = nil
 if @test_mode.nil?
  if @installer.force == true
    cmd = "CPAN::Shell->force(\"install\",#{install_thing})"
  else
    cmd = "CPAN::Shell->install(#{install_thing})" 
 end 
 else
   cmd = "CPAN::Shell->test(#{install_thing})" 
 end
 cmd
end

def get_home 
  user = @installer.user
  group = @installer.group
  home = user == 'root' ? "/root/" : "/home/#{user}/"
  return home
end 

def perl5lib_stack

  perl5lib = Array.new
  perl5lib += node.cpan_client.default_inc
  perl5lib += @installer.inc
  perl5lib.join(':')
  
end

def local_lib_stack
  stack = nil
  unless  @installer.install_base.nil?
   stack = "eval $(perl -Mlocal::lib=#{real_install_base}); "
  end
  return stack
end

def real_install_base
   install_base = @installer.install_base
   install_base.gsub!('\s','')
   install_base.chomp!
   unless /^\//.match(install_base)
     install_base = "#{@installer.cwd}/#{install_base}"
   end
   return install_base
end

def install_base_print 
 @installer.install_base.nil? ? 'default::install::base' : real_install_base
end

def get_install_path
  install_path = ''
  @installer.install_path.each do |i|
    install_path << " --install_path #{i} "
  end
  install_path
end


action :reload_cpan_index do

  user = @installer.user
  group = @installer.group
  cwd = @installer.cwd
  home = get_home

  log 'reload cpan index'
  execute "reload cpan index" do
    command 'perl -MCPAN -e "CPAN::Index->reload"'
    action :run
    user user
    group group
    cwd cwd
    environment ({'HOME' => home , 'MODULEBUILDRC' => '/tmp/local-lib/.modulebuildrc' }) 
  end

end

action :install do

  @test_mode = nil
  user = @installer.user
  group = @installer.group
  cwd = @installer.cwd
  home = get_home
  
  header
  @installer.dry_run == true ? install_dry_run : install_real
  new_resource.updated_by_last_action(true)

end

action :test do

  @test_mode = 1

  header
  log 'don*t install, run tests only'

  install_real

end


def install_dry_run
 return install_dry_run_tarball if @installer.from_cookbook
 return install_dry_run_cpan_module if @installer.install_type == 'cpan_module'
 return install_dry_run_cpan_module if @installer.install_type == 'cpan_module'
 return install_dry_run_application if @installer.install_type == 'application'
 raise 'should set install_type as (cpan_module|application) or from_cookbook parameter'
end

def install_real
 return install_tarball if @installer.from_cookbook
 return install_cpan_module if @installer.install_type == 'cpan_module'
 return install_cpan_module if @installer.install_type == 'cpan_module'
 return install_application if @installer.install_type == 'application'
 raise 'should set install_type as (cpan_module|application) or from_cookbook parameter'
end

def installed_module
  unless @installer.from_cookbook
    installed_module = @installer.name
    installed_module.gsub!(' ','-')
  else
    mat = /([a-z\d\.-]+)\.tar\.gz$/i.match(@installer.name)
    installed_module = mat[1]
  end
  return installed_module
end

def install_dry_run_cpan_module
  text = Array.new
  text << "WOULD install cpan module #{@installer.name}"
  ruby_block 'info' do
    block do
	print text.join("\n")
    end      
  end
end

def install_dry_run_tarball
  
  text = Array.new
  text << "WOULD copy cookbook file #{@installer.from_cookbook}::#{@installer.name} to /tmp/local-lib/install/"
  text << "WOULD cd to /tmp/local-lib/install/"
  text << "WOULD tar -zxf #{@installer.name}"
  text << "WOULD cd to #{installed_module}"
  text << "WOULD install via #{install_perl_code} ."
  
  ruby_block 'info' do
    block do
	print text.join("\n")
    end      
  end
end


def install_dry_run_application

  cwd = @installer.cwd
  user = @installer.user
  group = @installer.group

  text = Array.new
  text << "WOULD install application"
  ruby_block 'info' do
    block do
	print text.join("\n")
    end      
  end

  cmd = Array.new
  cmd << local_lib_stack
  cmd << 'if test -f Build.PL; then'
  cmd << 'perl Build.PL && ./Build'
  cmd << " echo './Build fakeinstall' > #{install_log_file}"
  cmd << " ./Build fakeinstall >> #{install_log_file}"
  cmd << " echo './Build prereq_report' >> #{install_log_file}"
  cmd << " ./Build prereq_report >> #{install_log_file}"
  cmd << 'else'
  cmd << 'perl Makefile.PL && make'
  cmd << "echo ' -- OK dry-run mode only enabled for Module::Build based distributions' > #{install_log_file}"
  cmd << 'fi'

  execute "install_dry_run_application" do
    user user
    group group
    cwd cwd
    code cmd.join("\n")
    environment cpan_env
  end

  ruby_block 'prereq_report' do 
    block do
        IO.foreach(install_log_file) do |l|
            print l unless /^Skipping /.match(l)
        end
    end
  end

end


def install_cpan_module

  cwd = @installer.cwd
  user = @installer.user
  group = @installer.group
  home = get_home

  file "#{install_log_file}" do
    action :touch
    owner user
    group group
  end

  cmd = Array.new
  cmd << local_lib_stack

  if @installer.version.nil? # not install if uptodate
      log 'version required : highest'
      cmd << 'perl -MCPAN -e \''
      cmd << 'unless(CPAN::Shell->expand("Module",$ARGV[0])->uptodate){'
      cmd << install_perl_code
      cmd << ' } '
      cmd << ' else { print $ARGV[0], " -- OK is uptodate : ".(CPAN::Shell->expand("Module",$ARGV[0])->inst_version) }'
      cmd << "' #{@installer.name}  2>&1 > #{install_log_file}"  
  elsif @installer.version == "0" # not install if any version already installed
      log 'version required : any'
      cmd << 'perl -MCPAN -e \''
      cmd << 'unless(CPAN::Shell->expand("Module",$ARGV[0])->inst_version) { '
      cmd << install_perl_code
      cmd << ' } '
      cmd << ' else { print $ARGV[0], " -- OK already installed " }'
      cmd << "' #{@installer.name}  2>&1 > #{install_log_file}"  
  elsif @installer.version != "0" # not install if have higher or equal version
      v = @installer.version
      log "version required : #{v}"
      cmd << 'perl -MCPAN -MCPAN::Version -e \''
      cmd << '$inst_v = CPAN::Shell->expand("Module",$ARGV[0])->inst_version;'
      cmd << 'unless ( CPAN::Version->vcmp($inst_v, $ARGV[1]) >=0 ) { '
      cmd << install_perl_code
      cmd << ' } '
      cmd << ' else { print $ARGV[0], " -- OK have higher or equal version [$inst_v]"  }'
      cmd << "' #{@installer.name} #{@installer.version}  2>&1 > #{install_log_file}"  
  else
      raise "bad version : #{@installer.version}"      
  end
  
  execute cmd.join(" ") do
    user user
    group group
    cwd cwd
    environment cpan_env
  end

  install_log

end

def install_tarball

  cwd = @installer.cwd
  user = @installer.user
  group = @installer.group
  home = get_home
  tarball_name = @installer.name
  from_cookbook = @installer.from_cookbook

  cookbook_file "/tmp/local-lib/install/#{@installer.name}" do
    action 'create_if_missing'
    mode "0644"
    cookbook from_cookbook
    owner user
    group group
  end

  execute "tar -zxf #{tarball_name}" do
    user user
    group group
    cwd "/tmp/local-lib/install/"
  end

  cmd = Array.new
  cmd << local_lib_stack
  cmd << 'perl -MCPAN::Version -MDist::Metadata -MCPAN -e \''
  cmd << 'my $dist = Dist::Metadata->new(file => $ARGV[0]);'
  cmd << 'my $dist_name = $dist->name;';
  cmd << '$cpan_dist = CPAN::Shell->expand("Distribution","/\/$dist_name-.*\.tar\.gz/");'
  cmd << 'eval{ for $m ($cpan_dist->containsmods) { $cpan_mod = CPAN::Shell->expand("Module", $m);'
  cmd << 'eval { $res = CPAN::Version->vcmp($dist->version,$cpan_mod->inst_version)}; next if $@;'
  cmd << 'if ($res == 0) { print " -- OK : exact version already installed \n"; exit(0) } } };'
  cmd << install_perl_code('"."')
  cmd << "' /tmp/local-lib/install/#{@installer.name} 2>&1 > #{install_log_file}"
  
  file "#{install_log_file}" do
    action :touch
    owner user
    group group
  end

        
  execute cmd.join(' ') do
    user user
    group group
    cwd "/tmp/local-lib/install/#{installed_module}"
    environment cpan_env
  end

  install_log

end

def install_application

  cwd = @installer.cwd
  user = @installer.user
  group = @installer.group
  home = get_home

  cmd = Array.new
  cmd << local_lib_stack
  cmd << "perl -MCPAN -e '"
  cmd << install_perl_code('"."')
  cmd << "' 2>&1 > #{install_log_file}"

  execute  cmd.join(" ") do
    user user
    group group
    cwd cwd
    environment cpan_env
  end

  install_log

end

