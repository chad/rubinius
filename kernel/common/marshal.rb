class Object
  def to_marshal(ms, strip_ivars = false)
    out = ms.serialize_extended_object self
    out << Marshal::TYPE_OBJECT
    out << ms.serialize(self.class.name.to_sym)
    out << ms.serialize_instance_variables_suffix(self, true, strip_ivars)
  end
end

class Range
  def to_marshal(ms)
    super(ms, true)
  end
end

class NilClass
  def to_marshal(ms)
    Marshal::TYPE_NIL
  end
end

class TrueClass
  def to_marshal(ms)
    Marshal::TYPE_TRUE
  end
end

class FalseClass
  def to_marshal(ms)
    Marshal::TYPE_FALSE
  end
end

class Class
  def to_marshal(ms)
    raise TypeError, "can't dump anonymous class #{self}" if self.name == ''
    Marshal::TYPE_CLASS + ms.serialize_integer(name.length) + name
  end
end

class Module
  def to_marshal(ms)
    raise TypeError, "can't dump anonymous module #{self}" if self.name == ''
    Marshal::TYPE_MODULE + ms.serialize_integer(name.length) + name
  end
end

class Symbol
  def to_marshal(ms)
    if idx = ms.find_symlink(self) then
      Marshal::TYPE_SYMLINK + ms.serialize_integer(idx)
    else
      ms.add_symlink self

      str = to_s
      Marshal::TYPE_SYMBOL + ms.serialize_integer(str.length) + str
    end
  end
end

class String
  def to_marshal(ms)
    out = ms.serialize_instance_variables_prefix(self)
    out << ms.serialize_extended_object(self)
    out << ms.serialize_user_class(self, String)
    out << Marshal::TYPE_STRING
    out << ms.serialize_integer(self.length) << self
    out << ms.serialize_instance_variables_suffix(self)
  end
end

class Fixnum
  def to_marshal(ms)
    Marshal::TYPE_FIXNUM + ms.serialize_integer(self)
  end
end

class Bignum
  def to_marshal(ms)
    str = Marshal::TYPE_BIGNUM + (self < 0 ? '-' : '+')
    cnt = 0
    num = self.abs

    while num != 0
      str << ms.to_byte(num)
      num >>= 8
      cnt += 1
    end

    if cnt % 2 == 1
      str << "\0"
      cnt += 1
    end

    str[0..1] + ms.serialize_integer(cnt / 2) + str[2..-1]
  end
end

class Regexp
  def to_marshal(ms)
    str = self.source
    out = ms.serialize_instance_variables_prefix(self)
    out << ms.serialize_extended_object(self)
    out << ms.serialize_user_class(self, Regexp)
    out << Marshal::TYPE_REGEXP
    out << ms.serialize_integer(str.length) + str
    out << ms.to_byte(options & 0x7)
    out << ms.serialize_instance_variables_suffix(self)
  end
end

class Struct
  def to_marshal(ms)
    out =  ms.serialize_instance_variables_prefix(self)
    out << ms.serialize_extended_object(self)

    out << Marshal::TYPE_STRUCT

    out << ms.serialize(self.class.name.to_sym)
    out << ms.serialize_integer(self.length)

    self.each_pair do |name, value|
      out << ms.serialize(name)
      out << ms.serialize(value)
    end

    out << ms.serialize_instance_variables_suffix(self)
    out
  end
end

class Array
  def to_marshal(ms)
    out = ms.serialize_instance_variables_prefix(self)
    out << ms.serialize_extended_object(self)
    out << ms.serialize_user_class(self, Array)
    out << Marshal::TYPE_ARRAY
    out << ms.serialize_integer(self.length)
    unless empty? then
      each do |element|
        out << ms.serialize(element)
      end
    end
    out << ms.serialize_instance_variables_suffix(self)
  end
end

class Hash
  def to_marshal(ms)
    raise TypeError, "can't dump hash with default proc" if default_proc
    out = ms.serialize_instance_variables_prefix(self)
    out << ms.serialize_extended_object(self)
    out << ms.serialize_user_class(self, Hash)
    out << (self.default ? Marshal::TYPE_HASH_DEF : Marshal::TYPE_HASH)
    out << ms.serialize_integer(length)
    unless empty? then
      each_pair do |(key, val)|
        out << ms.serialize(key)
        out << ms.serialize(val)
      end
    end
    out << (default ? ms.serialize(default) : '')
    out << ms.serialize_instance_variables_suffix(self)
  end
end

class Float
  def to_marshal(ms)
    str = if nan? then
            "nan"
          elsif zero? then
            (1.0 / self) < 0 ? '-0' : '0'
          elsif infinite? then
            self < 0 ? "-inf" : "inf"
          else
            "%.*g" % [17, self] + ms.serialize_float_thing(self)
          end
    Marshal::TYPE_FLOAT + ms.serialize_integer(str.length) + str
  end
end

module Marshal

  MAJOR_VERSION = 4
  MINOR_VERSION = 8

  VERSION_STRING = "\x04\x08"

  TYPE_NIL = '0'
  TYPE_TRUE = 'T'
  TYPE_FALSE = 'F'
  TYPE_FIXNUM = 'i'

  TYPE_EXTENDED = 'e'
  TYPE_UCLASS = 'C'
  TYPE_OBJECT = 'o'
  TYPE_DATA = 'd'  # no specs
  TYPE_USERDEF = 'u'
  TYPE_USRMARSHAL = 'U'
  TYPE_FLOAT = 'f'
  TYPE_BIGNUM = 'l'
  TYPE_STRING = '"'
  TYPE_REGEXP = '/'
  TYPE_ARRAY = '['
  TYPE_HASH = '{'
  TYPE_HASH_DEF = '}'
  TYPE_STRUCT = 'S'
  TYPE_MODULE_OLD = 'M'  # no specs
  TYPE_CLASS = 'c'
  TYPE_MODULE = 'm'

  TYPE_SYMBOL = ':'
  TYPE_SYMLINK = ';'

  TYPE_IVAR = 'I'
  TYPE_LINK = '@'

  class State

    def initialize(stream, depth, proc)
      # shared
      @links = {}
      @symlinks = {}
      @symbols = []
      @objects = []

      # dumping
      @depth = depth

      # loading
      @stream = stream
      @consumed = 0

      consume 2 if @stream

      @modules = nil
      @has_ivar = []
      @proc = proc
      @call = true
    end

    def add_object(obj)
      return if obj.kind_of?(ImmediateValue)
      sz = @links.size
      @objects[sz] = obj
      @links[obj.object_id] = sz
    end

    def add_symlink(obj)
      sz = @symlinks.size
      @symbols[sz] = obj
      @symlinks[obj.object_id] = sz
    end

    def call(obj)
      @proc.call obj if @proc and @call
    end

    def construct(ivar_index = nil, call_proc = true)
      type = consume
      obj = case type
            when TYPE_NIL
              nil
            when TYPE_TRUE
              true
            when TYPE_FALSE
              false
            when TYPE_CLASS, TYPE_MODULE
              name = construct_symbol
              obj = Object.const_lookup name

              store_unique_object obj

              obj
            when TYPE_FIXNUM
              construct_integer
            when TYPE_BIGNUM
              construct_bignum
            when TYPE_FLOAT
              construct_float
            when TYPE_SYMBOL
              construct_symbol
            when TYPE_STRING
              construct_string
            when TYPE_REGEXP
              construct_regexp
            when TYPE_ARRAY
              construct_array
            when TYPE_HASH, TYPE_HASH_DEF
              construct_hash type
            when TYPE_STRUCT
              construct_struct
            when TYPE_OBJECT
              construct_object
            when TYPE_USERDEF
              construct_user_defined ivar_index
            when TYPE_USRMARSHAL
              construct_user_marshal
            when TYPE_LINK
              num = construct_integer
              obj = @objects[num]

              raise ArgumentError, "dump format error (unlinked)" if obj.nil?

              return obj
            when TYPE_SYMLINK
              num = construct_integer
              sym = @symbols[num]

              raise ArgumentError, "bad symbol" if sym.nil?

              return sym
            when TYPE_EXTENDED
              @modules ||= []

              name = get_symbol
              @modules << Object.const_lookup(name)

              obj = construct nil, false

              extend_object obj

              obj
            when TYPE_UCLASS
              name = get_symbol
              @user_class = name

              construct nil, false

            when TYPE_IVAR
              ivar_index = @has_ivar.length
              @has_ivar.push true

              obj = construct ivar_index, false

              set_instance_variables obj if @has_ivar.pop

              obj
            else
              raise ArgumentError, "load error, unknown type #{type}"
            end

      call obj if call_proc

      obj
    end

    def construct_array
      obj = @user_class ? get_user_class.new : []
      store_unique_object obj

      construct_integer.times do
        obj << construct
      end

      obj
    end

    def construct_bignum
      sign = consume == '-' ? -1 : 1
      size = construct_integer * 2

      result = 0

      data = consume size
      (0...size).each do |exp|
        result += (data[exp] * 2**(exp*8))
      end

      obj = result * sign

      store_unique_object obj
    end

    def construct_float
      s = get_byte_sequence

      if s == "nan"
        obj = 0.0 / 0.0
      elsif s == "inf"
        obj = 1.0 / 0.0
      elsif s == "-inf"
        obj = 1.0 / -0.0
      else
        obj = s.to_f
      end

      store_unique_object obj

      obj
    end

    def construct_hash(type)
      obj = @user_class ? get_user_class.allocate : {}
      store_unique_object obj

      construct_integer.times do
        key = construct
        val = construct
        obj[key] = val
      end

      obj.default = construct if type == TYPE_HASH_DEF

      obj
    end

    def construct_integer
      n = consume[0]

      if (n > 0 and n < 5) or n > 251
        size, signed = n > 251 ? [256 - n, 2**((256 - n)*8)] : [n, 0]

        result = 0
        data = consume size

        (0...size).each do |exp|
          result += (data[exp] * 2**(exp*8))
        end

        result - signed
      elsif n > 127
        (n - 256) + 5
      elsif n > 4
        n - 5
      else
        n
      end
    end

    def construct_object
      name = get_symbol
      klass = Object.const_lookup name
      obj = klass.allocate

      raise TypeError, 'dump format error' unless Object === obj

      store_unique_object obj
      set_instance_variables obj

      obj
    end

    def construct_regexp
      s = get_byte_sequence
      if @user_class
        obj = get_user_class.new s, consume[0]
      else
        obj = Regexp.new s, consume[0]
      end

      store_unique_object obj
    end

    def construct_string
      obj = get_byte_sequence
      obj = get_user_class.new obj if @user_class

      store_unique_object obj
    end

    def construct_struct
      symbols = []
      values = []

      name = get_symbol
      store_unique_object name

      klass = Object.const_lookup name
      members = klass.members

      obj = klass.allocate
      store_unique_object obj

      construct_integer.times do |i|
        slot = get_symbol
        unless members[i].intern == slot then
          raise TypeError, "struct %s is not compatible (%p for %p)" %
            [klass, slot, members[i]]
        end

        obj.instance_variable_set "@#{slot}", construct
      end

      obj
    end

    def construct_symbol
      obj = get_byte_sequence.to_sym
      store_unique_object obj

      obj
    end

    def construct_user_defined(ivar_index)
      name = get_symbol
      klass = Module.const_lookup name

      data = get_byte_sequence

      if ivar_index and @has_ivar[ivar_index] then
        set_instance_variables data
        @has_ivar[ivar_index] = false
      end

      obj = klass._load data

      store_unique_object obj

      obj
    end

    def construct_user_marshal
      name = get_symbol
      store_unique_object name

      klass = Module.const_lookup name
      obj = klass.allocate

      extend_object obj if @modules

      unless obj.respond_to? :marshal_load then
        raise TypeError, "instance of #{klass} needs to have method `marshal_load'"
      end

      store_unique_object obj

      data = construct
      obj.marshal_load data

      obj
    end

    def consume(bytes = 1)
      data = @stream[@consumed, bytes]
      @consumed += bytes
      data
    end

    def extend_object(obj)
      obj.extend(@modules.pop) until @modules.empty?
    end

    def find_link(obj)
      @links[obj.object_id]
    end

    def find_symlink(obj)
      @symlinks[obj.object_id]
    end

    def frexp(flt)
      ptr = MemoryPointer.new :int
      return Platform::Float.frexp(flt, ptr)
    ensure
      ptr.free if ptr
    end

    def get_byte_sequence
      size = construct_integer
      consume size
    end

    def get_module_names(obj)
      names = []
      sup = obj.metaclass.superclass

      while sup and [Module, IncludedModule].include? sup.class do
        names << sup.name
        sup = sup.superclass
      end

      names
    end

    def get_user_class
      cls = Module.const_lookup @user_class
      @user_class = nil
      cls
    end

    def get_symbol
      type = consume

      case type
      when TYPE_SYMBOL then
        @call = false
        obj = construct_symbol
        @call = true
        obj
      when TYPE_SYMLINK then
        num = construct_integer
        @symbols[num]
      else
        raise ArgumentError, "expected TYPE_SYMBOL or TYPE_SYMLINK, got #{type.inspect}"
      end
    end

    def ldexp(flt, exp)
      Platform::Float.ldexp flt, exp
    end

    def modf(flt)
      ptr = MemoryPointer.new :double

      flt = Platform::Float.modf flt, ptr
      num = ptr.read_float

      return flt, num
    ensure
      ptr.free if ptr
    end

    def prepare_ivar(ivar)
      ivar.to_s =~ /\A@/ ? ivar : "@#{ivar}".to_sym
    end

    def serialize(obj)
      raise ArgumentError, "exceed depth limit" if @depth == 0

      # How much depth we have left.
      @depth -= 1;

      if link = find_link(obj)
        str = TYPE_LINK + serialize_integer(link)
      else
        add_object obj

        if obj.respond_to? :_dump then
          str = serialize_user_defined obj
        elsif obj.respond_to? :marshal_dump then
          str = serialize_user_marshal obj
        else
          str = obj.to_marshal self
        end
      end

      @depth += 1

      return str
    end

    def serialize_extended_object(obj)
      str = ''
      get_module_names(obj).each do |mod_name|
        str << TYPE_EXTENDED + serialize(mod_name.to_sym)
      end
      str
    end

    def serialize_float_thing(flt)
      str = ''
      (flt, ) = modf(ldexp(frexp(flt.abs), 37));
      str << "\0" if flt > 0
      while flt > 0
        (flt, n) = modf(ldexp(flt, 32))
        n = n.to_i
        str << to_byte(n >> 24)
        str << to_byte(n >> 16)
        str << to_byte(n >> 8)
        str << to_byte(n)
      end
      str.chomp!("\0") while str[-1] == 0
      str
    end

    def serialize_instance_variables_prefix(obj)
      if obj.instance_variables.length > 0
        TYPE_IVAR + ''
      else
      ''
      end
    end

    def serialize_instance_variables_suffix(obj, force = false, strip_ivars = false)
      if force or obj.instance_variables.length > 0
        str = serialize_integer(obj.instance_variables.length)
        obj.instance_variables.each do |ivar|
          sym = ivar.to_sym
          val = obj.instance_variable_get(sym)
          unless strip_ivars then
            str << serialize(sym)
          else
            str << serialize(ivar[1..-1].to_sym)
          end
          str << serialize(val)
        end
        str
      else
      ''
      end
    end

    def serialize_integer(n)
      if n == 0
        s = to_byte(n)
      elsif n > 0 and n < 123
        s = to_byte(n + 5)
      elsif n < 0 and n > -124
        s = to_byte(256 + (n - 5))
      else
        s = "\0"
        cnt = 0
        4.times do
          s << to_byte(n)
          n >>= 8
          cnt += 1
          break if n == 0 or n == -1
        end
        s[0] = to_byte(n < 0 ? 256 - cnt : cnt)
      end
      s
    end

    def serialize_user_class(obj, cls)
      if obj.class != cls
        TYPE_UCLASS + serialize(obj.class.name.to_sym)
      else
      ''
      end
    end

    def serialize_user_defined(obj)
      str = obj._dump @depth
      raise TypeError, "_dump() must return string" if str.class != String
      out = serialize_instance_variables_prefix(str)
      out << TYPE_USERDEF + serialize(obj.class.name.to_sym)
      out << serialize_integer(str.length) + str
      out << serialize_instance_variables_suffix(str)
    end

    def serialize_user_marshal(obj)
      val = obj.marshal_dump

      add_object val

      out = TYPE_USRMARSHAL + serialize(obj.class.name.to_sym)
      out << val.to_marshal(self)
    end

    def set_instance_variables(obj)
      construct_integer.times do
        ivar = get_symbol
        value = construct
        obj.instance_variable_set prepare_ivar(ivar), value
      end
    end

    def store_unique_object(obj)
      if obj.kind_of? Symbol
        add_symlink obj
      else
        add_object obj
      end
      obj
    end

    def to_byte(n)
      [n].pack('C')
    end

  end

  def self.dump(obj, an_io=nil, limit=nil)
    if limit.nil?
      if an_io.kind_of? Fixnum
        limit = an_io
        an_io = nil
      else
        limit = -1
      end
    end

    depth = Type.coerce_to limit, Fixnum, :to_int
    ms = State.new nil, depth, nil

    if an_io and !an_io.respond_to? :write
      raise TypeError, "output must respond to write"
    end

    str = VERSION_STRING + ms.serialize(obj)

    if an_io
      an_io.write(str)
      return an_io
    end

    return str
  end

  def self.load(obj, proc = nil)
    if obj.respond_to? :to_str
      data = obj.to_s
    elsif obj.respond_to? :read
      data = obj.read
      if data.empty?
        raise EOFError, "end of file reached"
      end
    elsif obj.respond_to? :getc  # FIXME - don't read all of it upfront
      data = ''
      data << c while (c = obj.getc.chr)
    else
      raise TypeError, "instance of IO needed"
    end

    major = data[0]
    minor = data[1]

    if major != MAJOR_VERSION or minor > MINOR_VERSION then
      raise TypeError, "incompatible marshal file format (can't be read)\n\tformat version #{MAJOR_VERSION}.#{MINOR_VERSION} required; #{major}.#{minor} given"
    end

    ms = State.new data, nil, proc
    ms.construct
  end

end

