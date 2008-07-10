# depends on: kernel.rb module.rb

##
# Mixin used to identify classes which have no memory storage.

module ImmediateValue
  def singleton_methods(all=true)
    []
  end

  def taint
    false
  end

  def tainted?
    false
  end

  def freeze
    false
  end

  def frozen?
    false
  end

  def dup
    raise TypeError, "can't dup #{self.class.name}"
  end
end

class NilClass
  include ImmediateValue
end

class FalseClass
  include ImmediateValue
end

class TrueClass
  include ImmediateValue
end

##
# Class for Qundef.
#--
# FIXME Is UndefClass used anymore?  Maybe I should be deleted!

class UndefClass
  include ImmediateValue
end

class Symbol
  include ImmediateValue
end

class Fixnum
  include ImmediateValue
end

