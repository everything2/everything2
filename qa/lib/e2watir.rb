require 'watir-webdriver'
require 'webform'
require 'json'

require 'pp'

$site = 'http://localhost:8888/'

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
    client = Selenium::WebDriver::Remote::Http::Default.new
    client.timeout = 180
    @browser = Watir::Browser.new :firefox, :http_client => client
  end

  def goto_page(type,title)
    @browser.goto($site + type + '/' + title)
  end

  def goto_home()
    @browser.goto($site)
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

  def assert_page_contains(idorname,tagtype,thisstring,negation)
    if @browser.send(tagtype.to_sym, idorname.to_sym => thisstring).exists?
      if !negation.nil?
        raise "Found #{tagtype} of #{idorname} #{thisstring} after all"
      end
    else
      if !negation 
        raise "Could not find #{tagtype} of #{idorname} #{thisstring}"
      end
    end
  end

  def assert_page_is_node_id(node_id)
    e2json = nil
    htmlblob = @browser.script(:id => 'nodeinfojson').html

    # For some reason .html returns the outerhtml, not the inner html
    # despite what the docs say
  
    if htmlblob.nil?
      raise "Could not get node info from page (no nodeinfojson script)"
    end
    
    htmlblob = htmlblob.sub(/<script.*?>/i, "")
    htmlblob = htmlblob.sub(/<\/script>/i,"")
    htmlblob = htmlblob.sub(/^[\n\t]+/,"")
    htmlblob = htmlblob.sub(/e2\s?=\s?/,"")
    htmlblob = htmlblob.sub(/[\n\t\;]+$/,"")

    e2json = JSON.parse(htmlblob)    

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
