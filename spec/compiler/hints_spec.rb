require File.dirname(__FILE__) + "/spec_helper"

describe Compiler do
  it "compiles '1 + 1' using fastmath" do
    gen [:call, [:fixnum, 1], :+, [:array, [:fixnum, 1]]], [:fastmath] do |g|
      g.push 1
      g.push 1
      g.meta_send_op_plus
    end
  end
  
  it "compiles '1 - 1' using fastmath" do
    gen [:call, [:fixnum, 1], :-, [:array, [:fixnum, 1]]], [:fastmath] do |g|
      g.push 1
      g.push 1
      g.meta_send_op_minus
    end
  end
  
  it "compiles '1 == 1' using fastmath" do
    gen [:call, [:fixnum, 1], :==, [:array, [:fixnum, 1]]], [:fastmath] do |g|
      g.push 1
      g.push 1
      g.meta_send_op_equal
    end
  end
  
  it "compiles '1 != 1' using fastmath" do
    gen [:call, [:fixnum, 1], :"!=", [:array, [:fixnum, 1]]], [:fastmath] do |g|
      g.push 1
      g.push 1
      g.meta_send_op_nequal
    end
  end

  it "compiles '1 === 1' using fastmath" do
    gen [:call, [:fixnum, 1], :===, [:array, [:fixnum, 1]]], [:fastmath] do |g|
      g.push 1
      g.push 1
      g.meta_send_op_tequal
    end
  end

  it "compiles '1 < 1' using fastmath" do
    gen [:call, [:fixnum, 1], :<, [:array, [:fixnum, 1]]], [:fastmath] do |g|
      g.push 1
      g.push 1
      g.meta_send_op_lt
    end
  end

  it "compiles '1 > 1' using fastmath" do
    gen [:call, [:fixnum, 1], :>, [:array, [:fixnum, 1]]], [:fastmath] do |g|
      g.push 1
      g.push 1
      g.meta_send_op_gt
    end
  end
  
  it "compiles '1 / 1' using :/ without safemath" do
    gen [:call, [:fixnum, 1], :/, [:array, [:fixnum, 1]]] do |g|
      g.push 1
      g.push 1
      g.send :/, 1, false
    end
  end
  
  it "compiles '1 / 1' using :divide with safemath" do
    gen [:call, [:fixnum, 1], :/, [:array, [:fixnum, 1]]], [:safemath] do |g|
      g.push 1
      g.push 1
      g.send :divide, 1, false
    end
  end
  
end
