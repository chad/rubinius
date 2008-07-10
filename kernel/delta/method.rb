# depends on: class.rb

##
# Method objects are essentially detached, freely passed-around methods. The
# Method is a copy of the method on the object at the time of extraction, so
# if the method itself is changed, overridden, aliased or removed from the
# object, the Method object still contains the old functionality. In addition,
# the call itself is not in any way stored so it will reflect the state of the
# object at the time of calling.
#
# Methods are normally bound to a particular object but it is possible to use
# Method#unbind to create an UnboundMethod object for the purpose of
# re-binding to a different object.

class Method

  ##
  # Takes and stores the receiver object, the method's bytecodes and the
  # Module that the method is defined in.

  def initialize(receiver, defined_in, compiled_method)
    @receiver         = receiver
    @pulled_from      = receiver.__class__
    @defined_in       = defined_in
    @compiled_method  = compiled_method
  end

  attr_reader :receiver
  attr_reader :pulled_from
  attr_reader :defined_in
  attr_reader :compiled_method
  protected   :receiver
  protected   :pulled_from

  ##
  # Method objects are equal if they have the same body and are bound to the
  # same object.

  def ==(other)
    return true if other.class == Method and
                   @receiver.equal?(other.receiver) and
                   @compiled_method == other.compiled_method

    false
  end

  ##
  # Indication of how many arguments this method takes. It is defined so that
  # a non-negative Integer means the method takes that fixed amount of
  # arguments (up to 1024 currently.) A negative Integer is used to indicate a
  # variable argument count. The number is ((-n) - 1), where n is the number
  # of required args. Blocks are not counted.
  #
  #   def foo();             end   # arity => 0
  #   def foo(a, b);         end   # arity => 2
  #   def foo(a, &b);        end   # arity => 1
  #   def foo(a, b = nil);   end   # arity => ((-1) -1) => -2
  #   def foo(*a);           end   # arity => ((-0) -1) => -1
  #   def foo(a, b, *c, &d); end   # arity => ((-2) -1) => -3

  def arity()
    @compiled_method.required
  end

  ##
  # Execute the method. This works exactly like calling a method with the same
  # code on the receiver object. Arguments and a block can be supplied
  # optionally.

  def call(*args, &block)
    @compiled_method.activate(@receiver, @defined_in, args, &block)
  end

  alias_method :[], :call

  ##
  # String representation of this Method includes the method name, the Module
  # it is defined in and the Module that it was extracted from.

  def inspect()
    "#<#{self.class}: #{@pulled_from}##{@compiled_method.name} (defined in #{@defined_in})>"
  end

  alias_method :to_s, :inspect

  ##
  # Location gives the file and line number of the start of this method's
  # definition.

  def location()
    "#{@compiled_method.file}, near line #{@compiled_method.first_line}"
  end

  ##
  # Returns a Proc object corresponding to this Method.

  def to_proc()
    env = Method::AsBlockEnvironment.new self
    Proc.__from_block__(env)
  end

  ##
  # Detach this Method from the receiver object it is bound to and create an
  # UnboundMethod object. Populates the UnboundMethod with the method data as
  # well as the Module it is defined in and the Module it was extracted from.
  #
  # See UnboundMethod for more information.

  def unbind()
    UnboundMethod.new(@defined_in, @compiled_method, @pulled_from)
  end

end

##
# Wraps the Method into a BlockEnvironment, for use with Method#to_proc.

class Method::AsBlockEnvironment < BlockEnvironment
  def initialize(method)
    @method = method
  end
  def method; @method.compiled_method; end
  def file; method.file; end
  def line; method.first_line; end
  def redirect_to(obj)
    @method = @method.unbind.bind(obj)
  end
  def call(*args); @method.call(*args); end
  def call_on_instance(obj, *args)
    redirect_to(obj).call(*args)
  end
  def arity; @method.arity; end
end

##
# UnboundMethods are similar to Method objects except that they are not
# connected to any particular object. They cannot be used standalone for this
# reason, and must be bound to an object first. The object must be kind_of?
# the Module in which this method was originally defined.
#
# UnboundMethods can be created in two ways: first, any existing Method object
# can be sent #unbind to detach it from its current object and return an
# UnboundMethod instead. Secondly, they can be directly created by calling
# Module#instance_method with the desired method's name.
#
# The UnboundMethod is a copy of the method as it existed at the time of
# creation. Any subsequent changes to the original will not affect any
# existing UnboundMethods.

class UnboundMethod

  ##
  # Accepts and stores the Module where the method is defined in as well as
  # the CompiledMethod itself. Class of the object the method was extracted
  # from can be given but will not be stored. This is always used internally
  # only.

  def initialize(mod, compiled_method, pulled_from = nil)
    @defined_in       = mod
    @compiled_method  = compiled_method
    @pulled_from      = pulled_from
  end

  attr_reader :compiled_method
  attr_reader :defined_in

  ##
  # UnboundMethod objects are equal if and only if they refer to the same
  # method. One may be an alias for the other or both for a common one. Both
  # must have been extracted from the same class or subclass. Two from
  # different subclasses will not be considered equal.

  def ==(other)
    return true if other.kind_of? UnboundMethod and
                   @defined_in == other.defined_in and
                   @compiled_method == other.compiled_method

    false
  end

  ##
  # See Method#arity.

  def arity()
    @compiled_method.required
  end

  ##
  # Creates a new Method object by attaching this method to the supplied
  # receiver. The receiver must be kind_of? the Module that the method in
  # question is defined in.
  #
  # Notably, this is a difference from MRI which requires that the object is
  # of the exact Module the method was extracted from. This is safe because
  # any overridden method will be identified as being defined in a different
  # Module anyway.

  def bind(receiver)
    if @defined_in.kind_of? MetaClass
      unless @defined_in.attached_instance == receiver
        raise TypeError, "Must be bound to #{@defined_in.attached_instance.inspect} only"
      end
    else
      unless receiver.__kind_of__ @defined_in
        raise TypeError, "Must be bound to an object of kind #{@defined_in}"
      end
    end
    Method.new receiver, @defined_in, @compiled_method
  end

  ##
  # Convenience method for #binding to the given receiver object and calling
  # it with the optionally supplied arguments.

  def call_on_instance(obj, *args)
    bind(obj).call(*args)
  end

  ##
  # String representation for UnboundMethod includes the method name, the
  # Module it is defined in and the Module that it was extracted from.

  def inspect()
    "#<#{self.class}: #{@pulled_from}##{@compiled_method.name} (defined in #{@defined_in})>"
  end

  alias_method :to_s, :inspect

end
