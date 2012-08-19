execute "e2_stylesheet_gen" do
  command "/var/everything/ecore/bin/generateStylesheets.pl"
  cwd "/var/everything/ecore/bin"
  creates "/var/everything/www/stylesheets"
end

execute "e2_gu_js_gen" do
  command "/var/everything/ecore/bin/generateGuestJavascript.pl; touch /etc/chef_setup/e2_gu_js_gen"
  cwd "/var/everything/ecore/bin"
  creates "/etc/chef_setup/e2_gu_js_gen"
end
