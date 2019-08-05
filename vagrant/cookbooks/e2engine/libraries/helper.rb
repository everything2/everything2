module E2
  def is_webhead?
    return 1 if node.primary_runlist.include?('role[e2bastion]') or node.primary_runlist.include?('recipe[e2cron]') or node.primary_runlist.include?('role[e2development]')
    return nil
  end
end
