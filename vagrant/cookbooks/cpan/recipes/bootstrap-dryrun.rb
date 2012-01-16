include_recipe 'cpan'

node.cpan_client.bootstrap.deps.each  do |m|
 cpan_client m[:module] do
  user 'root'
  group 'root'
  install_type 'cpan_module'
  version m[:version]
  action 'install'
  install_base node.cpan_client.bootstrap.install_base
  dry_run true
 end
end

