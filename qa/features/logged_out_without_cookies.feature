Feature: Users are not logged in when they have no cookies
  When users do not have an authentication cookie, they are not logged in
  
  Scenario: User can see the login form
	Given I am on the default page
	When my cookies are cleared
	Then the loginform form is present

