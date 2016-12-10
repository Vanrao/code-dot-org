Feature: Concurrency Test

Scenario: Test
  Given I am on "http://localhost:8080"
  And I reload the page
  And I reload the page
  And I reload the page
  And I wait to see "#runButton"
