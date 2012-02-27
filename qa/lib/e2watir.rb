require 'watir-webdriver'
require 'webform'
require 'json'

require 'pp'

$site = 'http://localhost:8888/'

$pages =
{
	"default" => "",
	"login" => "title/Login",
}

$users =
{
	"administrative" => 
	{
		"username" => "root",
		"password" => "blah",
	},
	"editor" =>
	{
		"username" => "testeditor",
		"password" => "blah",
	},
	"normal" => 
	{
		"username" => "testnormal",
		"password" => "blah"
	},
}

class E2watir

  def initialize()
  	@browser = Watir::Browser.new :firefox
  end

  def goto_page(thispage)
	@browser.goto($site + $pages[thispage]) 
  end 

  def clear_cookies()
	@browser.cookies.clear()
  end

  def close()
	@browser.close
  end

  def form_validate(formname)
     formname[0] = formname[0].upcase
     webformclass = Kernel.const_get(formname).new(@browser)
     webformclass.validate()
  end

  def assert_page_is_node_id(node_id)
     e2json = nil
     found = false
     @browser.scripts.each do |script|
	if script.id == "nodeinfojson"
          found = true
	  # such a hack, but watir is bugged
	  htmlblob = script.html
	  htmlblob = htmlblob.sub(/<script.*?>/i, "")
	  htmlblob = htmlblob.sub(/<\/script>/i,"")
	  htmlblob = htmlblob.sub(/^[\n\t]+/,"")
	  htmlblob = htmlblob.sub(/e2\s?=\s?/,"")
	  htmlblob = htmlblob.sub(/[\n\t\;]+$/,"")
	  e2json = JSON.parse(htmlblob)
	end
     end
     if !found
       raise "Could not get node info from page (no nodeinfojson script)"
     end
     if e2json.nil?
       raise "Could not parse json from page to get node information"
     end
     if e2json["node_id"].nil?
       raise "No node_id found in json blob in page"
     end
     if Integer(e2json["node_id"]) != Integer(node_id)
       raise "The specified node_id: '#{node_id}' does not match json node_id #{e2json['node_id']}"
     end
  end
end
