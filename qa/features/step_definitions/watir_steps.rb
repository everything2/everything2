begin require 'rspec/expectations'; end 
require 'cucumber/formatter/unicode'
$:.unshift(File.dirname(__FILE__) + '/../../lib')

require 'e2watir'

Before do
  @e2 = E2watir.new
end

After do
  @e2.close
end

When /^I go to the home page/ do 
  @e2.goto_home
end

When /^I go to the page for the '(.+?)' named '(.+?)'/ do |type,title|
  @e2.goto_page(type,title)
end

Given /^cookies are cleared$/ do
  @e2.clear_cookies()
end

Then /^the (.*?) form is present$/ do |formname|
  @e2.form_validate(formname)
end

Then /^the page is node_id (\d+)$/ do |node_id|
  @e2.assert_page_is_node_id(node_id)
end

Then /^the page does( not)? contain an? '(.*?)' of (id|name) '(.+?)'/ do |negative,tagtype,idorname,thisstring|
  @e2.assert_page_contains(idorname,tagtype,thisstring,negative)
end
