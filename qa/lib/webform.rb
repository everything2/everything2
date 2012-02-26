class Webform
  def initialize(browser)
    @browser = browser
    self.assert_form_exists()
  end

  def validate
    raise "Base webform validation error. No validate method defined"
  end

  def assert_form_exists
    form = self.get_this_form
    formname = self.class.name.downcase
    if(!form.exists?)
      raise "Form not found on page"
    end
  end

  def get_this_form
     formname = self.class.name.downcase
     form = @browser.form(:id => formname)
     return form
  end

  def assert_element_exists(name,type)
     form = self.get_this_form
     thistype = form.send(type + "s")
     found = 0
     thistype.each do |element_name|
        if element_name.name == name
          found = 1
        end
     end

     if(!found)
       raise "Form element #{name} does not exist in form #{form}"
     end
  end
end

class Loginform < Webform
  def validate
    	self.assert_element_exists('user', 'input')
        self.assert_element_exists('passwd','input')
	self.assert_element_exists('checkbox','input')
	self.assert_element_exists('expires','input')
	self.assert_element_exists('login','input')
  end	
end


