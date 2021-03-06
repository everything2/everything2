module E2
  def is_webhead?
    Chef::Log.info("E2 chef debug / Recipe List: #{node.recipe_list}")
    Chef::Log.info("E2 chef debug / Runlist recipes: #{node.primary_runlist.recipe_names}")
    Chef::Log.info("E2 chef debug / Runlist: #{node.primary_runlist.to_s}")
    return 1 if node.primary_runlist.include?('recipe[e2web]') or node.primary_runlist.include?('role[e2development]')
    return nil
  end
end
