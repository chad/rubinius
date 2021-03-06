require 'complex'
require File.dirname(__FILE__) + '/../fixtures/classes'

shared :complex_math_cos do |obj|
  describe "Math#{obj == Math ? '.' : '#'}cos" do
    it "returns the cosine of the argument expressed in radians" do    
      obj.send(:cos, Math::PI).should be_close(-1.0, TOLERANCE)
      obj.send(:cos, 0).should be_close(1.0, TOLERANCE)
      obj.send(:cos, Math::PI/2).should be_close(0.0, TOLERANCE)    
      obj.send(:cos, 3*Math::PI/2).should be_close(0.0, TOLERANCE)
      obj.send(:cos, 2*Math::PI).should be_close(1.0, TOLERANCE)
    end

    it "returns the cosine for Complex numbers" do
      obj.send(:cos, Complex(0, Math::PI)).should be_close(Complex(11.5919532755215, 0.0), TOLERANCE)
      obj.send(:cos, Complex(3, 4)).should be_close(Complex(-27.0349456030742, -3.85115333481178), TOLERANCE)
    end
  end
end

shared :complex_math_cos_bang do |obj|
  describe "Math#{obj == Math ? '.' : '#'}cos!" do
    it "returns the cosine of the argument expressed in radians" do    
      obj.send(:cos!, Math::PI).should be_close(-1.0, TOLERANCE)
      obj.send(:cos!, 0).should be_close(1.0, TOLERANCE)
      obj.send(:cos!, Math::PI/2).should be_close(0.0, TOLERANCE)    
      obj.send(:cos!, 3*Math::PI/2).should be_close(0.0, TOLERANCE)
      obj.send(:cos!, 2*Math::PI).should be_close(1.0, TOLERANCE)
    end  

    it "raises a TypeError when passed a Complex number" do    
      lambda { obj.send(:cos!, Complex(3, 4)) }.should raise_error(TypeError)
    end
  end
end