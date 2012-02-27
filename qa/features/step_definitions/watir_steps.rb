begin require 'rspec/expectations'; end 
require 'cucumber/formatter/unicode'
$:.unshift(File.dirname(__FILE__) + '/../../lib')

require 'e2watir'

Before do
  @browser = E2watir.new
end

After do
  @browser.close
end

Given /I am on the (\S+) page/ do |page|
  @browser.goto_page(page)
end

When /^my cookies are cleared$/ do
  @browser.clear_cookies()
end

Then /^the (.*?) form is present$/ do |formname|
  @browser.form_validate(formname)
end

Then /^the page is node_id (\d+)$/ do |node_id|
  @browser.assert_page_is_node_id(node_id)
end

