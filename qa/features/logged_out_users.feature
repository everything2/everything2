Feature: Users are not logged in when they have no cookies
  When users do not have an authentication cookie, they are not logged in
  
  Scenario: User is Guest User when not logged in
	Given cookies are cleared
	When I go to the home page
	Then I am a guest 

  Scenario: User sees Guest User homepage on '/' when not logged in
	Given cookies are cleared
	When I go to the home page
	Then the page is node_id 2030780 
	 
  Scenario: Guest User does not see an edit link on their homepage
	Given cookies are cleared
	When I go to the page for the 'user' named 'Guest User'
	Then the page does not contain an 'a' of id 'usereditlink'

