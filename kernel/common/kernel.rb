#!/usr/bin/ruby
##
# Namespace for coercion functions between various ruby objects.

module Type

  ##
  # Returns an object of given class. If given object already is one, it is
  # returned. Otherwise tries obj.meth and returns the result if it is of the
  # right kind. TypeErrors are raised if the conversion method fails or the
  # conversion result is wrong.
  #
  # Uses Type.obj_kind_of to bypass type check overrides.
  #
  # Equivalent to MRI's rb_convert_type().

  def self.coerce_to(obj, cls, meth)
    return obj if self.obj_kind_of?(obj, cls)

    begin
      ret = obj.__send__(meth)
    rescue Exception => e
      raise TypeError, "Coercion error: #{obj.inspect}.#{meth} => #{cls} failed:\n" \
                       "(#{e.message})"
    end

    return ret if self.obj_kind_of?(ret, cls)

    raise TypeError, "Coercion error: obj.#{meth} did NOT return a #{cls} (was #{ret.class})"
  end
end


module Kernel

  def Float(obj)
    raise TypeError, "can't convert nil into Float" if obj.nil?

    if obj.is_a?(String)
      if obj !~ /^(\+|\-)?\d+$/ && obj !~ /^(\+|\-)?(\d_?)*\.(\d_?)+$/ && obj !~ /^[-+]?\d*\.?\d*e[-+]\d*\.?\d*/
        raise ArgumentError, "invalid value for Float(): #{obj.inspect}"
      end
    end

    Type.coerce_to(obj, Float, :to_f)
  end
  module_function :Float

  def Integer(obj)
    return obj.to_inum(0, true) if obj.is_a?(String)
    method = obj.respond_to?(:to_int) ? :to_int : :to_i
    Type.coerce_to(obj, Integer, method)
  end
  module_function :Integer

  def Array(obj)
    if obj.respond_to?(:to_ary)
      Type.coerce_to(obj, Array, :to_ary)
    elsif obj.respond_to?(:to_a)
      Type.coerce_to(obj, Array, :to_a)
    else
      [obj]
    end
  end
  module_function :Array

  def String(obj)
    Type.coerce_to(obj, String, :to_s)
  end
  module_function :String

  ##
  # MRI uses a macro named StringValue which has essentially the same
  # semantics as obj.coerce_to(String, :to_str), but rather than using that
  # long construction everywhere, we define a private method similar to
  # String().
  #
  # Another possibility would be to change String() as follows:
  #
  #   String(obj, sym=:to_s)
  #
  # and use String(obj, :to_str) instead of StringValue(obj)

  def StringValue(obj)
    Type.coerce_to(obj, String, :to_str)
  end
  private :StringValue

  ##
  # MRI uses a macro named NUM2DBL which has essentially the same semantics as
  # Float(), with the difference that it raises a TypeError and not a
  # ArgumentError. It is only used in a few places (in MRI and Rubinius).
  #--
  # If we can, we should probably get rid of this.

  def FloatValue(obj)
    begin
      Float(obj)
    rescue
      raise TypeError, 'no implicit conversion to float'
    end
  end
  private :FloatValue

  def warn(warning)
    $stderr.write "#{warning}\n" unless $VERBOSE.nil?
    nil
  end
  module_function :warn


  def exit(code=0)
    code = 0 if code.equal? true
    raise SystemExit.new(code)
  end
  module_function :exit

  def exit!(code=0)
    Process.exit(code)
  end
  module_function :exit!

  def abort(msg=nil)
    Process.abort(msg)
  end
  module_function :abort

  def puts(*a)
    $stdout.puts(*a)
    return nil
  end
  module_function :puts

  # For each object given, prints obj.inspect followed by the
  # system record separator to standard output (thus, separator
  # cannot be overridden.) Prints nothing if no objects given.
  def p(*a)
    return nil if a.empty?
    a.each { |obj| $stdout.puts obj.inspect }
    nil
  end
  module_function :p

  def print(*args)
    args.each do |obj|
      $stdout.write obj.to_s
    end
    nil
  end
  module_function :print

  def open(path, *rest, &block)
    path = StringValue(path)

    if path.kind_of? String and path.prefix? '|'
      return IO.popen(path[1..-1], *rest, &block)
    end

    File.open(path, *rest, &block)
  end
  module_function :open

  def loop
    raise LocalJumpError, "no block given" unless block_given?

    while true
      yield
    end
  end
  module_function :loop

  def test(cmd, file1, file2=nil)
    case cmd
    when ?d
      File.directory? file1
    when ?e
      File.exist? file1
    when ?f
      File.file? file1
    else
      false
    end
  end
  module_function :test


  def trap(sig, prc=nil, &block)
    Signal.trap(sig, prc, &block)
  end
  module_function :trap

  def initialize_copy(other)
    return self
  end
  private :initialize_copy

  alias_method :__id__, :object_id

  alias_method :==,   :equal?


  # The "sorta" operator, also known as the case equality operator.
  # Generally while #eql? and #== are stricter, #=== is often used
  # to denote an acceptable match or inclusion. It returns true if
  # the match is considered to be valid and false otherwise. It has
  # one special purpose: it is the operator used by the case expression.
  # So in this expression:
  #
  #   case obj
  #   when /Foo/
  #     ...
  #   when "Hi"
  #     ...
  #   end
  #
  # What really happens is that `/Foo/ === obj` is attempted and so
  # on down until a match is found or the expression ends. The use
  # by Regexp is very illustrative: while obj may satisfy the pattern,
  # it may not be the only option.
  #
  # The default #=== operator checks if the other object is #equal?
  # to this one (i.e., is the same object) or if #== returns true.
  # If neither is true, false is returned instead. Many classes opt
  # to override this behaviour to take advantage of its use in a
  # case expression and to implement more relaxed matching semantics.
  # Notably, the above Regexp as well as String, Module and many others.
  def ===(other)
    equal?(other) || self == other
  end

  ##
  # Regexp matching fails by default but may be overridden by subclasses,
  # notably Regexp and String.

  def =~(other)
    false
  end

  alias_method :eql?, :equal?

  ##
  # Returns true if this object is an instance of the given class, otherwise
  # false. Raises a TypeError if a non-Class object given.
  #
  # Module objects can also be given for MRI compatibility but the result is
  # always false.

  def instance_of?(cls)
    if cls.class != Class and cls.class != Module
      # We can obviously compare against Modules but result is always false
      raise TypeError, "instance_of? requires a Class argument"
    end

    self.class == cls
  end

  alias_method :send, :__send__

  def to_a
    if self.kind_of? Array
      self
    else
      [self]
    end
  end

  def autoload(name, file)
    Object.autoload(name, file)
  end
  private :autoload

  def autoload?(name)
    Object.autoload?(name)
  end
  private :autoload?

  def getc
    $stdin.getc
  end
  module_function :getc

  def putc(int)
    $stdin.putc(int)
  end
  module_function :putc

  def gets(sep=$/)
    # HACK. Needs to use ARGF first.
    $stdin.gets(sep)
  end
  module_function :gets

  def readline(sep)
    $stdin.readline(sep)
  end
  module_function :readline
  
  def readlines(sep)
    $stdin.readlines(sep)
  end
  module_function :readlines

  # Perlisms.

  def chomp(string=$/)
    ensure_last_read_string
    $_ = $_.chomp(string)
  end
  module_function :chomp
  
  def chomp!(string=$/)
    ensure_last_read_string
    $_.chomp!(string)
  end
  module_function :chomp!

  def chop(string=$/)
    ensure_last_read_string
    $_ = $_.chop(string)
  end
  module_function :chop
  
  def chop!(string=$/)
    ensure_last_read_string
    $_.chop!(string)
  end
  module_function :chop!

  def gsub(pattern, rep=nil, &block)
    ensure_last_read_string
    $_ = $_.gsub(pattern, rep, &block)
  end
  module_function :gsub
  
  def gsub!(pattern, rep=nil, &block)
    ensure_last_read_string
    $_.gsub!(pattern, rep, &block)
  end
  module_function :gsub!

  def sub(pattern, rep=nil, &block)
    ensure_last_read_string
    $_ = $_.sub(pattern, rep, &block)
  end
  module_function :sub
  
  def sub!(pattern, rep=nil, &block)
    ensure_last_read_string
    $_.sub!(pattern, rep, &block)
  end
  module_function :sub!

  def scan(pattern, &block)
    ensure_last_read_string
    $_.scan(pattern, &block)
  end
  module_function :scan

  def select(*args)
    IO.select(*args)
  end
  module_function :select

  def split(*args)
    ensure_last_read_string
    $_.split(*args)
  end
  module_function :split

  # Checks whether the "last read line" $_ variable is a String,
  # raising a TypeError when not.
  def ensure_last_read_string
    unless $_.kind_of? String
      cls = $_.nil? ? "nil" : $_.class
      raise TypeError, "$_ must be a String (#{cls} given)"
    end
  end
  module_function :ensure_last_read_string
  private :ensure_last_read_string

end

class SystemExit < Exception
  def initialize(status)
    @status = status
  end

  attr_reader :status

  def message
    "System is exiting with code '#{status}'"
  end
end
