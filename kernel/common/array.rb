class Array
  alias_method :slice, :[]
  # Creates a new Array containing only elements common to
  # both Arrays, without duplicates. Also known as a 'set
  # intersection'
  def &(other)
    other = Type.coerce_to other, Array, :to_ary

    out, set_include = [], {}

    other.each { |x| set_include[x] = [true, x] }
    each { |x|
      if set_include[x] and set_include[x].last.eql?(x)
        out << x
        set_include[x] = false
      end
    }

    out
  end

  # Creates a new Array by combining the two Arrays' items,
  # without duplicates. Also known as a 'set union.'
  def |(other)
    other = Type.coerce_to other, Array, :to_ary

    out, exclude = [], {}

    (self + other).each { |x|
      unless exclude[x]
        out << x
        exclude[x] = true
      end
    }

    out
  end

  # Repetition operator when supplied a #to_int argument:
  # returns a new Array as a concatenation of the given number
  # of the original Arrays. With an argument that responds to
  # #to_str, functions exactly like #join instead.
  def *(val)
    if val.respond_to? :to_str
      return join(val)

    else
      # Aaargh stupid MRI's stupid specific stupid error stupid types stupid
      val = Type.coerce_to val, Fixnum, :to_int

      raise ArgumentError, "Count cannot be negative" if val < 0

      out = self.class.new
      val.times { out.push(*self) }
      out
    end
  end

  # Create a concatenation of the two Arrays.
  def +(other)
    other = Type.coerce_to other, Array, :to_ary
    out = []

    each { |e| out << e }
    other.each { |e| out << e }

    out
  end

  # Creates a new Array that contains the items of the original
  # Array that do not appear in the other Array, effectively
  # 'deducting' those items. The matching method is Hash-based.
  def -(other)
    other = Type.coerce_to other, Array, :to_ary
    out, exclude = [], {}

    other.each { |x| exclude[x] = true }
    each { |x| out << x unless exclude[x] }

    out
  end

  # Compares the two Arrays and returns -1, 0 or 1 depending
  # on whether the first one is 'smaller', 'equal' or 'greater'
  # in relation to the second. Two Arrays are equal only if all
  # their elements are 0 using first_e <=> second_e and their
  # lengths are the same. The element comparison is the primary
  # and length is only checked if the former results in 0's.
  def <=>(other)
    other = Type.coerce_to other, Array, :to_ary

    size.times { |i|
      return 1 unless other.size > i

      diff = at(i) <=> other.at(i)
      return diff if diff != 0
    }

    return 1 if size > other.size
    return -1 if size < other.size
    0
  end

  # The two Arrays are considered equal only if their
  # lengths are the same and each of their elements
  # are equal according to first_e == second_e . Both
  # Array subclasses and to_ary objects are accepted.
  def ==(other)
    unless other.kind_of? Array
      return false unless other.respond_to? :to_ary
      other = other.to_ary
    end

    return false unless size == other.size

    size.times { |i| return false unless at(i) == other.at(i) }

    true
  end

  # Assumes the Array contains other Arrays and searches through
  # it comparing the given object with the first element of each
  # contained Array using elem == obj. Returns the first contained
  # Array that matches (the first 'associated' Array) or nil.
  def assoc(obj)
    # FIX: use break when it works again
    found, res = nil, nil

    each { |elem|
      if found.nil? and elem.kind_of? Array and elem.first == obj
        found, res = true, elem
      end
    }

    res
  end
  #
  # Returns a copy of self with all nil elements removed
  def compact()
    dup.compact! || self
  end

  #
  # Passes each index of the Array to the given block
  # and returns self.  
  def each_index()
    i = 0
    each do
      yield i
      i += 1
    end
    self
  end


  # Returns true if both are the same object or if both
  # have the same elements (#eql? used for testing.)
  def eql?(other)
    return true if equal? other
    return false unless other.kind_of?(Array)
    return false if size != other.size

    each_with_index { |o, i| return false unless o.eql?(other[i]) }

    true
  end

  # True if Array has no elements.
  def empty?()
    size == 0
  end

  # Returns the first or first n elements of the Array.
  # If no argument is given, returns nil if the item
  # is not found. If there is an argument, an empty
  # Array is returned instead.
  def first(n = nil)
    return at(0) unless n

    n = Type.coerce_to n, Fixnum, :to_int
    raise ArgumentError, "Size must be positive" if n < 0

    Array.new(self[0...n])
  end

  # Recursively flatten any contained Arrays into an one-dimensional result.
  def flatten()
    dup.flatten! || self
  end

  # Flattens self in place as #flatten. If no changes are
  # made, returns nil, otherwise self.
  def flatten!
    ret, out = nil, []

    ret = recursively_flatten(self, out)
    replace(out) if ret
    ret
  end

  # Computes a Fixnum hash code for this Array. Any two
  # Arrays with the same content will have the same hash
  # code (similar to #eql?)
  def hash()
    # IMPROVE: This is a really really poor implementation of hash for an array, but
    # it does work. It should be replaced with something much better, but I'm not sure
    # what level it belongs at.
    str = ""
    each { |item| str << item.hash.to_s }
    str.hash
  end


  # Returns an Array populated with the objects at the given indices of the original.
  # Range arguments are given as nested Arrays as from #[].
  def indexes(*args)
    warn 'Array#indexes is deprecated, use Array#values_at instead'

    out = []

    args.each { |a|
      if a.kind_of? Range
        out << self[a]
      else
        out << at(Type.coerce_to(a, Fixnum, :to_int))
      end
    }

    out
  end

  alias_method :indices, :indexes

  # Produces a printable string of the Array. The string
  # is constructed by calling #inspect on all elements.
  # Descends through contained Arrays, recursive ones
  # are indicated as [...].
  def inspect()
    return "[...]" if RecursionGuard.inspecting?(self)

    out = []
    RecursionGuard.inspect(self) do
      each { |o|
        out << o.inspect
      }
    end

    "[#{out.join ', '}]"
  end

  # Returns the last element or n elements of self. If
  # the Array is empty, without a count nil is returned,
  # otherwise an empty Array. Always returns an Array.
  def last(n = nil)
    return at(-1) unless n

    n = Type.coerce_to n, Fixnum, :to_int
    return [] if n.zero?
    raise ArgumentError, "Number must be positive" if n < 0

    n = size if n > size
    Array.new self[-n..-1]
  end

  # Creates a new Array from the return values of passing
  # each element in self to the supplied block.
  def map()
    out = []
    each { |elem| out << yield(elem) }
    out
  end

  alias_method :collect, :map

  # Replaces each element in self with the return value
  # of passing that element to the supplied block.
  def map!(&block)
    replace(map(&block))
  end

  alias_method :collect!, :map!

  # Returns number of non-nil elements in self, may be zero
  def nitems
    sum = 0
    each { |elem| sum += 1 unless elem.nil? }
    sum
  end

  ##
  #  call-seq:
  #     arr.pack ( aTemplateString ) -> aBinaryString
  #
  #  Packs the contents of <i>arr</i> into a binary sequence according to
  #  the directives in <i>aTemplateString</i> (see the table below)
  #  Directives ``A,'' ``a,'' and ``Z'' may be followed by a count,
  #  which gives the width of the resulting field. The remaining
  #  directives also may take a count, indicating the number of array
  #  elements to convert. If the count is an asterisk
  #  (``<code>*</code>''), all remaining array elements will be
  #  converted. Any of the directives ``<code>sSiIlL</code>'' may be
  #  followed by an underscore (``<code>_</code>'') to use the underlying
  #  platform's native size for the specified type; otherwise, they use a
  #  platform-independent size. Spaces are ignored in the template
  #  string. See also <code>String#unpack</code>.
  #
  #     a = [ "a", "b", "c" ]
  #     n = [ 65, 66, 67 ]
  #     a.pack("A3A3A3")   #=> "a  b  c  "
  #     a.pack("a3a3a3")   #=> "a\000\000b\000\000c\000\000"
  #     n.pack("ccc")      #=> "ABC"
  #
  #  Directives for +pack+.
  #
  #   Directive    Meaning
  #   ---------------------------------------------------------------
  #       @     |  Moves to absolute position
  #       A     |  ASCII string (space padded, count is width)
  #       a     |  ASCII string (null padded, count is width)
  #       B     |  Bit string (descending bit order)
  #       b     |  Bit string (ascending bit order)
  #       C     |  Unsigned char
  #       c     |  Char
  #       D, d  |  Double-precision float, native format
  #       E     |  Double-precision float, little-endian byte order
  #       e     |  Single-precision float, little-endian byte order
  #       F, f  |  Single-precision float, native format
  #       G     |  Double-precision float, network (big-endian) byte order
  #       g     |  Single-precision float, network (big-endian) byte order
  #       H     |  Hex string (high nibble first)
  #       h     |  Hex string (low nibble first)
  #       I     |  Unsigned integer
  #       i     |  Integer
  #       L     |  Unsigned long
  #       l     |  Long
  #       M     |  Quoted printable, MIME encoding (see RFC2045)
  #       m     |  Base64 encoded string
  #       N     |  Long, network (big-endian) byte order
  #       n     |  Short, network (big-endian) byte-order
  #       P     |  Pointer to a structure (fixed-length string)
  #       p     |  Pointer to a null-terminated string
  #       Q, q  |  64-bit number
  #       S     |  Unsigned short
  #       s     |  Short
  #       U     |  UTF-8
  #       u     |  UU-encoded string
  #       V     |  Long, little-endian byte order
  #       v     |  Short, little-endian byte order
  #       w     |  BER-compressed integer\fnm
  #       X     |  Back up a byte
  #       x     |  Null byte
  #       Z     |  Same as ``a'', except that null is added with *

  def pack schema
    # The schema is an array of arrays like [["A", "6"], ["u", "*"],
    # ["X", ""]]. It represents the parsed form of "A6u*X".  Remove
    # strings in the schema between # and \n
    schema = schema.gsub(/#.*/, '')
    schema = schema.scan(/([^\s\d\*][\d\*]*)/).flatten.map {|x|
      x.match(/([^\s\d\*])([\d\*]*)/)[1..-1]
    }

    ret = ""
    arr_idx = 0

    schema.each do |kind, t|
      # p :iter => [kind, t]
      item = self[arr_idx]
      t = nil if t.empty?

      # MRI nil compatibilty for string functions
      item = "" if item.nil? && kind =~ /[aAZbBhH]/

      # if there's no item, that means there's more schema items than
      # array items, so throw an error. All actions that DON'T
      # increment arr_idx must occur before this test.
      raise ArgumentError, "too few array elements" if
        arr_idx >= self.length and kind !~ /x/i

      case kind # TODO: switch kind to ints
      when 'X' then
        size = (t || 1).to_i
        raise ArgumentError, "you're backing up too far" if size > ret.size
        ret[-size..-1] = '' if size > 0
      when 'x' then
        size = (t || 1).to_i
        ret << "\000" * size
      when 'N' then
        parts = []
        4.times do                          # TODO: const?
          parts << (item % 256).chr
          item >>= 8
        end
        ret << parts.reverse.join
        arr_idx += 1
        item = nil
        next # HACK
      when 'V' then
        parts = []
        4.times do                          # TODO: const?
          parts << (item % 256).chr
          item >>= 8
        end
        ret << parts.join
        arr_idx += 1
      when 'v' then
        parts = []
        2.times do
          parts << (item % 256).chr
          item >>= 8
        end
        ret << parts.join
        arr_idx += 1
      when 'a', 'A', 'Z' then
        item = Type.coerce_to(item, String, :to_str)
        size = case t
               when nil
                 1
               when '*' then
                 item.size + (kind == "Z" ? 1 : 0)
               else
                 t.to_i
               end

        padsize = size - item.size
        filler  = kind == "A" ? " " : "\0"

        ret << item.split(//).first(size).join
        ret << filler * padsize if padsize > 0

        arr_idx += 1
      when 'b', 'B' then
        item = Type.coerce_to(item, String, :to_str)
        byte = 0
        lsb  = (kind == "b")
        size = case t
               when nil
                 1
               when '*' then
                 item.size
               else
                 t.to_i
               end

        bits = item.split(//).map { |c| c[0] & 01 }
        min = [size, item.size].min

        bits.first(min).each_with_index do |bit, i| # TODO: this can be cleaner
          i &= 07

          byte |= bit << (lsb ? i : 07 - i)

          if i == 07 then
            ret << byte.chr
            byte = 0
          end
        end

        # always output an incomplete byte
        if ((size & 07) != 0 || min != size) && item.size > 0 then
          ret << byte.chr
        end

        # Emulate the weird MRI spec for every 2 chars over output a \000 # FIX
        (item.length).step(size-1, 2) { |i| ret << 0 } if size > item.length

        arr_idx += 1
      when 'c', 'C' then
        size = case t
               when nil
                 1
               when '*' then
                 self.size # TODO: - arr_idx?
               else
                 t.to_i
               end

        # FIX: uhh... size is the same as length. just tests that arr_idx == 0
        raise ArgumentError, "too few array elements" if
          arr_idx + size > self.length

        sub = self[arr_idx...arr_idx+size]
        sub.map! { |o| (Type.coerce_to(o, Integer, :to_int) & 0xff).chr }
        ret << sub.join

        arr_idx += size
      when 'M' then
        # for some reason MRI responds to to_s here
        item = Type.coerce_to(item, String, :to_s)
        ret << item.scan(/.{1,73}/m).map { |line| # 75 chars per line incl =\n
          line.gsub(/[^ -<>-~\t\n]/) { |m| "=%02X" % m[0] } + "=\n"
        }.join
        arr_idx += 1
      when 'm' then # REFACTOR: merge with u
        item = Type.coerce_to(item, String, :to_str)

        ret << item.scan(/.{1,45}/m).map { |line|
          encoded = line.scan(/(.)(.?)(.?)/m).map { |a,b,c|
            a = a[0]
            b = b[0] || 0
            c = c[0] || 0

            [BASE_64_B2A[( a >> 2                    ) & 077],
             BASE_64_B2A[((a << 4) | ((b >> 4) & 017)) & 077],
             BASE_64_B2A[((b << 2) | ((c >> 6) & 003)) & 077],
             BASE_64_B2A[( c                         ) & 077]]
          }

          "#{encoded.flatten.join}\n"
        }.join.sub(/(A{1,2})\n\Z/) { "#{'=' * $1.size}\n" }

        arr_idx += 1
      when 'w' then
        item = Type.coerce_to(item, Integer, :to_i)
        raise ArgumentError, "can't compress negative numbers" if item < 0

        ret << (item & 0x7f)
        while (item >>= 7) > 0 do
          ret << ((item & 0x7f) | 0x80)
        end

        ret.reverse! # FIX - breaks anything following BER?
        arr_idx += 1
      when 'u' then # REFACTOR: merge with m
        item = Type.coerce_to(item, String, :to_str)

        # http://www.opengroup.org/onlinepubs/009695399/utilities/uuencode.html
        ret << item.scan(/.{1,45}/m).map { |line|
          encoded = line.scan(/(.)(.?)(.?)/m).map { |a,b,c|
            a = a[0]
            b = b[0] || 0
            c = c[0] || 0

            [(?\s + (( a >> 2                    ) & 077)).chr,
             (?\s + (((a << 4) | ((b >> 4) & 017)) & 077)).chr,
             (?\s + (((b << 2) | ((c >> 6) & 003)) & 077)).chr,
             (?\s + (( c                         ) & 077)).chr]
          }.flatten

          "#{(line.size + ?\s).chr}#{encoded.join}\n"
        }.join.gsub(/ /, '`')
        arr_idx += 1
      when 'i', 's', 'l', 'n', 'I', 'S', 'L' then
        size = case t
               when nil
                 1
               when '*' then
                 self.size
               else
                 t.to_i
               end

        native        = t && t == '_'
        unsigned      = (kind =~ /I|S|L/)
        little_endian = kind !~ /n/i && endian?(:little)

        raise "unsupported - fix me" if native

        unless native then
          bytes = case kind
                  when /n/i then 2
                  when /s/i then 2
                  when /i/i then 4
                  when /l/i then 4
                  end
        end

        size.times do |i|
          item = Type.coerce_to(self[arr_idx], Integer, :to_i)

          # MRI seems only only raise RangeError at 2**32 and above, even shorts
          raise RangeError, "bignum too big to convert into 'unsigned long'" if
            item.abs >= 2**32 # FIX: const

            ret << if little_endian then
                     item += 2 ** (8 * bytes) if item < 0
                     (0...bytes).map { |b| ((item >> (b * 8)) & 0xFF).chr }
                   else # ugly
                     (0...bytes).map {n=(item % 256).chr;item /= 256; n}.reverse
                   end.join
          arr_idx += 1
        end
      when 'H', 'h' then
        size = if t.nil?
                 0
               elsif t == "*"
                 item.length
               else
                 t.to_i
               end
        str = item.scan(/..?/).first(size)

        ret << if kind == "h" then
                 str.map { |b| b.reverse.hex.chr }.join
               else
                 str.map { |b| b.        hex.chr }.join
               end

        arr_idx += 1
      when 'U' then
        count = if t.nil? then
                  1
                elsif t == "*"
                  self.size - arr_idx
                else
                  t.to_i
                end

        raise ArgumentError, "too few array elements" if
          arr_idx + count > self.length

        count.times do
          item = Type.coerce_to(self[arr_idx], Integer, :to_i)

          raise RangeError, "pack(U): value out of range" if item < 0

          bytes = 0
          f = [2 ** 7, 2 ** 11, 2 ** 16, 2 ** 21, 2 ** 26, 2 ** 31].find { |n|
            bytes += 1
            item < n
          }

          raise RangeError, "pack(U): value out of range" if f.nil?

          if bytes == 1 then
            ret << item
            bytes = 0
          end

          i = bytes

          buf = []
          if i > 0 then
            (i-1).times do
              buf.unshift((item | 0x80) & 0xBF)
              item >>= 6
            end
            # catch the highest bits - the mask depends on the byte count
            buf.unshift(item | ((0x3F00 >> bytes)) & 0xFC)
          end

          ret << buf.map { |n| n.chr }.join

          arr_idx += 1
        end
      else
        raise ArgumentError, "Unknown kind #{kind}"
      end
    end

    return ret
  end

  # Appends the given object(s) to the Array and returns
  # the modified self.
  def push(*args)
    args.each { |ent| self << ent }
    self
  end

  # Searches through contained Arrays within the Array,
  # comparing obj with the second element of each using
  # elem == obj. Returns the first matching Array, nil
  # on failure. See also Array#assoc.
  def rassoc(obj)
    # FIX: Use break when it works
    found, res = nil, nil

    each { |elem|
      if found.nil? and elem.kind_of? Array and elem.at(1) == obj
        res, found = elem, true
      end
    }

    res
  end

  # Returns a new Array by removing items from self for
  # which block is true. An Array is also returned when
  # invoked on subclasses. See #reject!
  def reject(&block)
    Array.new(self).reject!(&block) || self
  end

  # Equivalent to #delete_if except that returns nil if
  # no changes were made.
  def reject!(&block)
    was = length
    self.delete_if(&block)

    self if was != length     # Too clever?
  end

  # Returns a new Array or subclass populated from self
  # but in reverse order.
  def reverse()
    dup.reverse!
  end

  # Deletes the element(s) given by an index (optionally with a length)
  # or by a range. Returns the deleted object, subarray, or nil if the
  # index is out of range. Equivalent to:
  def slice!(*args)
    out = self[*args]
    if !(Range === args[0])
      # make sure that negative values are not passed through to the
      # []= assignment
      args[0] = Type.coerce_to args[0], Integer, :to_int
      args[0] = args[0] + self.length if args[0] < 0
      # This is to match the MRI behaviour of not extending the array
      # with nil when specifying an index greater than the length
      # of the array.
      if args.size == 1
        return out unless args[0] >= 0 && args[0] < self.length
        args << 1
      end
    end
    self[*args] = []
    out
  end

  # Returns a new Array created by sorting elements in self. Comparisons
  # to sort are either done using <=> or a block may be provided. The
  # block must take two parameters and return -1, 0, 1 depending on
  # whether the first parameter is smaller, equal or larger than the
  # second parameter.
  def sort(&block)
    dup.sort!(&block)
  end

  # Returns self except on subclasses which are converted
  # or 'upcast' to Arrays.
  def to_a()
    if self.class == Array
      self
    else
      Array.new(self[0..-1])
    end
  end

  # Returns self
  def to_ary()
    self
  end

  # Produces a string by joining all elements without a
  # separator. See #join
  def to_s()
    self.join
  end

  # Treats all elements as being Arrays of equal lengths and
  # transposes their rows and columns so that the first contained
  # Array in the result includes the first elements of all the
  # Arrays and so on.
  def transpose()
    return [] if empty?

    out, max = [], nil

    each { |ary|
      ary = Type.coerce_to ary, Array, :to_ary
      max ||= ary.size

      # Catches too-large as well as too-small (for which #fetch would suffice)
      raise IndexError, "All arrays must be same length" if ary.size != max

      ary.size.times { |i| (out[i] ||= []) << ary.at(i) }
    }

    out
  end

  # Returns a new Array by removing duplicate entries
  # from self. Equality is determined by using a Hash
  def uniq()
    seen, out = {}, self.class.new

    each { |elem|
      out << elem unless seen[elem]
      seen[elem] = true
    }

    out
  end

  # Removes duplicates from the Array in place as #uniq
  def uniq!()
    ary = uniq
    replace(ary) if size != ary.size
  end

#  # Inserts the element to the front of the Array and
#  # moves the other elements up by one index.
#  def unshift(*val)
#    raise TypeError, "Array is frozen" if frozen?
#    return self if val.empty?
#
#    self[0, 0] = val
#    self
#  end

  def length
    size
  end


  # Exactly the same as #replace but private
  def initialize_copy(other)
    replace other
  end

  private :initialize_copy

end

