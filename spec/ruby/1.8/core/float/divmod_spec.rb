require File.dirname(__FILE__) + '/../../spec_helper'

describe "Float#divmod" do
  it "returns an [quotient, modulus] from dividing self by other" do
    values = 3.14.divmod(2)
    values[0].should == 1
    values[1].should be_close(1.14, TOLERANCE)
    values = 2.8284.divmod(3.1415)
    values[0].should == 0
    values[1].should be_close(2.8284, TOLERANCE)
    values = -1.0.divmod(0xffffffff)
    values[0].should == -1
    values[1].should be_close(4294967294.0, TOLERANCE)
  end

  platform_is :version => '1.8.5'..'1.8.6' do
    it "raises FloatDomainError if other is zero" do
      lambda { 1.0.divmod(0)   }.should raise_error(FloatDomainError)
      lambda { 1.0.divmod(0.0) }.should raise_error(FloatDomainError)
    end
  end
end