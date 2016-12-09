Feature: Concurrency Test

Background:
  Given I am on "http://127.0.0.1:8080"
  And I reload the page
  And I reload the page
  And I reload the page
  And I wait to see "#runButton"
