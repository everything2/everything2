require 'watir-webdriver'
require 'webform'

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
end
