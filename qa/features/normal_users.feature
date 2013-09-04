Feature: Logging in as a normal user works
  You can log in as a normal user, in this case the user everyone

  Scenario: Normal user login is not a guest
    Given I am logged in as a normal user
    Then I am not a guest

  Scenario: User sees the regular homepage when logged in
    Given I am logged in as a normal user
    When I go to the home page
    Then the page is node_id 124
