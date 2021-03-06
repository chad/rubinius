require File.dirname(__FILE__) + '/../../spec_helper'
require 'mspec/runner/formatters/summary'
require 'mspec/runner/example'

describe SummaryFormatter, "#after" do
  before :each do
    $stdout = @out = IOStub.new
    @formatter = SummaryFormatter.new
    @formatter.register
    @state = ExampleState.new("describe", "it")
  end

  after :each do
    $stdout = STDOUT
  end

  it "does not print anything" do
    exc = ExceptionState.new @state, nil, ExpectationNotMetError.new("disappointing")
    @formatter.exception exc
    exc = ExceptionState.new @state, nil, MSpecExampleError.new("painful")
    @formatter.exception exc
    @formatter.after(@state)
    @out.should == ""
  end
end
