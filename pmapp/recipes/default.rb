include_recipe 'cpan'

cpan_client "Env::C" do
 action 'install'
 install_type 'cpan_module'
 user 'root'
 group 'root'
end
