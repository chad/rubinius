# depends on: module.rb kernel.rb

module Kernel
  ##
  #--
  # HACK :: added due to broken constant lookup rules
  #++

  def raise(exc=Undefined, msg=nil, trace=nil)
    skip = false
    if exc.equal? Undefined
      exc = $!
      if exc
        skip = true
      else
        exc = RuntimeError.new("No current exception")
      end
    elsif exc.respond_to? :exception
      exc = exc.exception msg
      raise ::TypeError, 'exception class/object expected' unless exc.kind_of?(::Exception)
      exc.set_backtrace trace if trace
    elsif exc.kind_of? String or !exc
      exc = ::RuntimeError.exception exc
    else
      raise ::TypeError, 'exception class/object expected'
    end

    if $DEBUG and $VERBOSE != nil
      sender = MethodContext.current.sender
      STDERR.puts "Exception: `#{exc.class}' #{sender.location} - #{exc.message}"
    end

    unless skip
      exc.context = MethodContext.current.sender unless exc.context
    end
    Rubinius.asm(exc) { |e| e.bytecode(self); raise_exc }
  end
  module_function :raise

  alias_method :fail, :raise
  module_function :fail
  def printf(target, *args)
    if target.kind_of? IO
      target.printf(*args)
    elsif target.kind_of? String
      $stdout << Sprintf.new(target, *args).parse
    else
      raise TypeError, "The first arg to printf should be an IO or a String"
    end
    nil
  end
  module_function :printf

  def sprintf(str, *args)
    Sprintf.new(str, *args).parse
  end
  alias_method :format, :sprintf
  module_function :sprintf
  module_function :format
  module_function :abort

  #--
  # NOTE: This isn't quite MRI compatible.
  # We don't seed the RNG by default with a combination of time, pid and
  # sequence number
  #++

  def srand(seed)
    cur = Kernel.current_srand
    Platform::POSIX.srand(seed.to_i)
    Kernel.current_srand = seed.to_i
    return cur
  end
  module_function :srand

  @current_seed = 0
  def self.current_srand
    @current_seed
  end

  def self.current_srand=(val)
    @current_seed = val
  end

  def rand(max=nil)
    max = max.to_i.abs
    x = Platform::POSIX.rand
    # scale result of rand to a domain between 0 and max
    if max.zero?
      x / 0x7fffffff.to_f
    else
      if max < 0x7fffffff
        x / (0x7fffffff / max)
      else
         x * (max / 0x7fffffff)
      end
    end
  end
  module_function :rand

  #
  # Rubinius only
  def endian?(order)
    order == Rubinius::ENDIAN
  end
  module_function :endian?

  def block_given?
    if MethodContext.current.sender.block
      return true
    end

    return false
  end
  module_function :block_given?

  alias_method :iterator?, :block_given?
  module_function :iterator?

  def lambda
    block = block_given?
    raise ArgumentError, "block required" if block.nil?

    block.disable_long_return!

    return Proc::Function.__from_block__(block)
  end
  alias_method :proc, :lambda
  module_function :lambda
  module_function :proc

  def caller(start=1)
    frame = MethodContext.current.sender
    frame.stack_trace_starting_at(start)
  end
  module_function :caller

  def global_variables
    Globals.variables.map { |i| i.to_s }
  end
  module_function :global_variables

  ##
  # Sleeps the current thread for +duration+ seconds.

  def sleep(duration = Undefined)
    start = Time.now
    chan = Channel.new
    # No duration means we sleep forever. By not registering anything with
    # Scheduler, the receive call will effectively block until someone
    # explicitely wakes this thread.
    unless duration.equal?(Undefined)
      raise TypeError, 'time interval must be a numeric value' unless duration.kind_of?(Numeric)
      duration = Time.at duration
      Scheduler.send_in_seconds(chan, duration.to_f, nil)
    end
    chan.receive
    return (Time.now - start).round
  end
  module_function :sleep

  def at_exit(&block)
    Rubinius::AtExit.unshift(block)
  end
  module_function :at_exit

  def class_variable_get(sym)
    self.class.class_variable_get sym
  end

  def class_variable_set(sym, value)
    self.class.class_variable_set sym, value
  end

  def class_variables(symbols = false)
    self.class.class_variables(symbols)
  end

  ##
  # \_\_const_set__ is emitted by the compiler for const assignment
  # in userland.
  #
  # This is the catch-all version for unwanted values
  # rubinius only
  def __const_set__(name, obj)
    raise TypeError, "#{self} is not a class/module"
  end

  ##
  # Activates the singleton Debugger instance, and sets a breakpoint
  # immediately after the call site to this method.
  #--
  # TODO: Have method take an options hash to configure debugger behavior,
  # and perhaps a block containing debugger commands to be executed when the
  # breakpoint is hit.
  # rubinius only
  def debugger
    require 'debugger/debugger'
    dbg = Debugger.instance

    unless dbg.interface
      # Default to command-line interface if nothing registered
      require 'debugger/interface'
      Debugger::CmdLineInterface.new
    end

    ctxt = MethodContext.current.sender
    cm = ctxt.method
    ip = ctxt.ip
    bp = dbg.get_breakpoint(cm, ip)
    if bp
      bp.enable unless bp.enabled?
    else
      bp = dbg.set_breakpoint(cm, ip)
    end

    # Modify send site not to call this method again
    bc = ctxt.method.bytecodes
    
    Breakpoint.encoder.replace_instruction(bc, ip-4, [:noop])
    Breakpoint.encoder.replace_instruction(bc, ip-2, [:noop])

    ctxt.reload_method
  end

  alias_method :breakpoint, :debugger


  def extend(*modules)
    modules.reverse_each do |mod|
      mod.extend_object(self)
      mod.send(:extended, self)
    end
    self
  end

  def inspect(prefix=nil, vars=nil)
    return "..." if RecursionGuard.inspecting?(self)

    iv = __ivars__()

    return self.to_s unless iv

    if (iv.is_a?(Hash) or iv.is_a?(Tuple)) and iv.empty?
      return self.to_s
    end

    prefix = "#{self.class}:0x#{self.object_id.to_s(16)}" unless prefix
    parts = []

    RecursionGuard.inspect(self) do

      if iv.is_a?(Hash)
        iv.each do |k,v|
          next if vars and !vars.include?(k)
          parts << "#{k}=#{v.inspect}"
        end
      else
        0.step(iv.size - 1, 2) do |i|
          if k = iv[i]
            next if vars and !vars.include?(k)
            v = iv[i+1]
            parts << "#{k}=#{v.inspect}"
          end
        end
      end

    end

    if parts.empty?
      "#<#{prefix}>"
    else
      "#<#{prefix} #{parts.join(' ')}>"
    end
  end

  ##
  # :call-seq:
  #   obj.instance_exec(arg, ...) { |var,...| block }  => obj
  #
  # Executes the given block within the context of the receiver +obj+. In
  # order to set the context, the variable +self+ is set to +obj+ while the
  # code is executing, giving the code access to +obj+'s instance variables.
  #
  # Arguments are passed as block parameters.
  #
  #   class Klass
  #     def initialize
  #       @secret = 99
  #     end
  #   end
  #   
  #   k = Klass.new
  #   k.instance_exec(5) {|x| @secret+x }   #=> 104

  def instance_exec(*args, &prc)
    raise ArgumentError, "Missing block" unless block_given?
    env = prc.block.redirect_to self
    env.method.staticscope = StaticScope.new(metaclass, env.method.staticscope)
    env.call(*args)
  end

  def instance_variable_get(sym)
    sym = instance_variable_validate(sym)
    get_instance_variable(sym)
  end

  def instance_variable_set(sym, value)
    sym = instance_variable_validate(sym)
    set_instance_variable(sym, value)
  end

  def remove_instance_variable(sym)
    # HACK
    instance_variable_set(sym, nil)
  end
  private :remove_instance_variable

  def instance_variables
    vars = get_instance_variables
    return [] if vars.nil?

    # CSM awareness
    if vars.kind_of? Tuple
      out = []
      0.step(vars.size - 1, 2) do |i|
        k = vars[i]
        if k
          k = k.to_s
          out << k
        else
          return out
        end
      end
      return out
    end
    return vars.keys.collect { |v| v.to_s }
  end

  def instance_variable_defined?(name)
    name = instance_variable_validate(name)

    vars = get_instance_variables
    return false unless vars

    # CSM awareness
    if vars.kind_of? Tuple
      out = []
      0.step(vars.size - 1, 2) do |i|
        k = vars[i]
        return true if k == name
      end

      return false
    end

    return vars.key?(name)
  end

  # Both of these are for defined? when used inside a proxy obj that
  # may undef the regular method. The compiler generates __ calls.
  alias_method :__instance_variable_defined_eh__, :instance_variable_defined?
  alias_method :__respond_to_eh__, :respond_to?

  def singleton_method_added(name)
  end
  private :singleton_method_added

  def singleton_method_removed(name)
  end
  private :singleton_method_removed

  def singleton_method_undefined(name)
  end
  private :singleton_method_undefined

  alias_method :is_a?, :kind_of?

  def method(name)
    cm = __find_method__(name)

    if cm
      return Method.new(self, cm[1], cm[0])
    else
      raise NameError, "undefined method `#{name}' for #{self.inspect}"
    end
  end

  def nil?
    false
  end

  def method_missing_cv(meth, *args)
    # Exclude method_missing from the backtrace since it only confuses
    # people.
    myself = MethodContext.current
    ctx = myself.sender

    if myself.send_private?
      raise NameError, "undefined local variable or method `#{meth}' for #{inspect}"
    elsif self.__kind_of__ Class or self.__kind_of__ Module
      raise NoMethodError.new("No method '#{meth}' on #{self} (#{self.__class__})", ctx, args)
    else
      raise NoMethodError.new("No method '#{meth}' on an instance of #{self.__class__}.", ctx, args)
    end
  end

  private :method_missing_cv

  def methods(all=true)
    names = singleton_methods(all)
    names |= self.class.instance_methods(true) if all
    return names
  end

  def private_methods(all=true)
    names = private_singleton_methods
    names |= self.class.private_instance_methods(all)
    return names
  end

  def private_singleton_methods
    metaclass.method_table.private_names.map { |meth| meth.to_s }
  end

  def protected_methods(all=true)
    names = protected_singleton_methods
    names |= self.class.protected_instance_methods(all)
    return names
  end

  def protected_singleton_methods
    metaclass.method_table.protected_names.map { |meth| meth.to_s }
  end

  def public_methods(all=true)
    names = singleton_methods(all)
    names |= self.class.public_instance_methods(all)
    return names
  end

  def singleton_methods(all=true)
    mt = metaclass.method_table
    if all
      return mt.keys.map { |m| m.to_s }
    else
      (mt.public_names + mt.protected_names).map { |m| m.to_s }
    end
  end

  def to_s
    "#<#{self.__class__}:0x#{self.__id__.to_s(16)}>"
  end

  def set_trace_func(*args)
    raise NotImplementedError
  end
  module_function :set_trace_func
  
  def syscall(*args)
    raise NotImplementedError
  end
  module_function :syscall

  def trace_var(*args)
    raise NotImplementedError
  end
  module_function :trace_var

  def untrace_var(*args)
    raise NotImplementedError
  end
  module_function :untrace_var


  # From bootstrap
  private :get_instance_variable
  private :get_instance_variables
  private :set_instance_variable
  
  # rubinius only
  def self.after_loaded
    alias_method :method_missing, :method_missing_cv

    # Add in $! in as a hook, to just do $!. This is for accesses to $!
    # that the compiler can't see.
    get = proc { $! }
    Globals.set_hook(:$!, get, nil)

    # Same as $!, for any accesses we might miss.
    # HACK. I doubt this is correct, because of how it will be called.
    get = proc { Regex.last_match }
    Globals.set_hook(:$~, get, nil)

    get = proc { ARGV }
    Globals.set_hook(:$*, get, nil)

    get = proc { $! ? $!.backtrace : nil }
    Globals.set_hook(:$@, get, nil)

    get = proc { Process.pid }
    Globals.set_hook(:$$, get, nil)
  end

end


