require File.dirname(__FILE__) + '/../../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "Thread#[]" do
  it "should give access to thread local values" do
    th = Thread.new do
      Thread.current[:value] = 5
    end
    th.join
    th[:value].should == 5
    Thread.current[:value].should == nil
  end

  it "should not be shared across threads" do
    t1 = Thread.new do
      Thread.current[:value] = 1
    end
    t2 = Thread.new do
      Thread.current[:value] = 2
    end
    [t1,t2].each {|x| x.join}
    t1[:value].should == 1
    t2[:value].should == 2
  end

  it "should be accessable using strings or symbols" do
    t1 = Thread.new do
      Thread.current[:value] = 1
    end
    t2 = Thread.new do
      Thread.current["value"] = 2
    end
    [t1,t2].each {|x| x.join}
    t1[:value].should == 1
    t1["value"].should == 1
    t2[:value].should == 2
    t2["value"].should == 2
  end

  it "should raise exceptions on the wrong type of keys" do
    lambda { Thread.current[nil] }.should raise_error(TypeError)
    lambda { Thread.current[5] }.should raise_error(ArgumentError)
  end
end