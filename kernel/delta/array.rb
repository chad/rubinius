# depends on: class.rb enumerable.rb tuple.rb kernel.rb

##
# Arrays are ordered, integer-indexed collections of any object.  Array
# indexing starts at 0, as in C or Java.  A negative index is assumed to be
# relative to the end of the array---that is, an index of -1 indicates the
# last element of the array, -2 is the next to last element in the array, and
# so on.
#
# Arrays can be created with the <tt>[]</tt> syntax, or via <tt>Array.new</tt>.

class Array
  def total=(n) ; @total = n ; end
  def tuple=(t) ; @tuple = t ; end
  def start=(s) ; @start = s ; end

  include Enumerable

  # The flow control for many of these methods is
  # pretty evil due to how MRI works. There is
  # also a lot of duplication of code due to very
  # subtle processing differences and, in some
  # cases, to avoid mutual dependency. Apologies.


  # Returns a new Array populated with the given objects
  def self.[](*args)
    new args
  end

  def self.allocate
    ary = super()
    ary.start = 0
    ary.total = 0
    ary.tuple = Tuple.new 8
    ary
  end

  # Creates a new Array. Without arguments, an empty
  # Array is returned. If the only argument is an object
  # that responds to +to_ary+, a copy of that Array is
  # created. Otherwise the first argument is the size
  # of the new Array (default 0.) The second argument
  # may be an object used to fill the Array up to the
  # size given (the same object, not a copy.) Alternatively,
  # a block that takes the numeric index can be given and
  # will be run size times to fill the Array with its
  # result. The block supercedes any object given. If
  # neither is provided, the Array is filled with nil.
  def initialize(*args)
    raise ArgumentError, "Wrong number of arguments, #{args.size} for 2" if args.size > 2

    unless args.empty?
      if args.size == 1 and (args.first.__kind_of__ Array or args.first.respond_to? :to_ary)
        ary = Type.coerce_to args.first, Array, :to_ary

        tuple = Tuple.new(ary.size + 10)
        @total = ary.size
        tuple.copy_from ary.tuple, ary.start, 0
        @tuple = tuple
      else
        count = Type.coerce_to args.first, Fixnum, :to_int
        raise ArgumentError, "Size must be positive" if count < 0
        obj = args[1]

        @tuple = Tuple.new(count + 10)
        @total = count

        if block_given?
          count.times { |i| @tuple.put i, yield(i) }
        else
          count.times { |i| @tuple.put i, obj }
        end
      end
    end

    self
  end

  private :initialize

  # Element reference, returns the element at the given index or
  # a subarray starting from the index continuing for length
  # elements or returns a subarray from range elements. Negative
  # indices count from the end. Returns nil if the index or subarray
  # request cannot be completed. Array#slice is synonymous with #[].
  # Subclasses return instances of themselves.
  def [](one, two = nil)
    Ruby.primitive :array_aref

    # Normalise the argument variants
    start, finish, count, simple, is_range = nil, nil, nil, false, false

    if one.kind_of? Range
      is_range = true
      start, finish = one.begin, one.end
    elsif two
      start, count = one, Type.coerce_to(two, Fixnum, :to_int)
      return nil if count < 0       # No need to go further
    else
      start, finish, simple = one, one, true
    end

    # Convert negative indices
    start = Type.coerce_to start, Fixnum, :to_int
    start += @total if start < 0

    if simple
      return nil if start < 0 or start >= @total
      return @tuple.at(@start + start)

    # ONE past end only, MRI compat
    elsif start == @total
      return self.class.new

    elsif start < 0 or start >= @total
      return nil
    end


    finish = Type.coerce_to finish, Fixnum, :to_int if finish
    finish = (start + count - 1) if count    # For non-ranges

    finish += @total if finish < 0

    finish -= 1 if is_range and one.exclude_end?

    # Going past the end is ignored (sort of)
    finish = (@total - 1) if finish >= @total

    if finish < 0
      return self.class.new if is_range
      return nil
    end

    out = self.class.new

    return out if finish < start or count == 0

    start.upto(finish) { |i| out << at(i) }
    out
  end


  def []=(idx, ent, *args)
    Ruby.primitive :array_aset

    cnt = nil
    if args.size != 0
      cnt = ent.to_int
      ent = args[0]             # 2nd arg (cnt) is the optional one!
    end

    # Normalise Ranges
    if idx.is_a?(Range)
      if cnt
        raise ArgumentError, "Second argument invalid with a range"
      end

      unless idx.first.respond_to?(:to_int)
        raise TypeError, "can't convert #{idx.first.class} into Integer"
      end

      unless idx.last.respond_to?(:to_int)
        raise TypeError, "can't convert #{idx.last.class} into Integer"
      end

      lst = idx.last.to_int
      if lst < 0
        lst += @total
      end
      lst += 1 unless idx.exclude_end?

      idx = idx.first.to_int
      if idx < 0
        idx += @total
        raise RangeError if idx < 0
      end

      # m..n, m > n allowed
      lst = idx if idx > lst

      cnt = lst - idx
    end

    idx = idx.to_int

    if idx < 0
      idx += @total
      raise IndexError.new("Index #{idx -= @total} out of bounds") if idx < 0
    end

    if cnt
      # count < 0 not allowed
      raise IndexError.new("Negative length #{cnt}") if cnt < 0

      cnt = @total - idx if cnt > @total - idx # MRI seems to be forgiving here!

      if ent.nil?
        replacement = []
      elsif ent.is_a?(Array)
        replacement = ent.dup
      elsif ent.respond_to?(:to_ary)
        replacement = ent.to_ary
      else
        replacement = [ent]
      end

      if replacement.size > cnt
        newtotal = @total + replacement.size - cnt
        if newtotal > @tuple.fields - @start
          nt = Tuple.new(newtotal + 10)
          nt.copy_from @tuple, @start, 0 # FIXME: double copy of right part
          @start = 0
          @tuple = nt
        end                     # this should be an else
        f = @total
        t = newtotal
        while f > idx + cnt
          t -= 1
          f -= 1
          @tuple.put(@start+t, @tuple.at(@start+f))
        end
        @total = newtotal
      end
      replacement.each_with_index { |el, i|
        @tuple.put(@start+idx+i, el)
      }

      if replacement.size < cnt
        f = @start + idx + cnt
        t = @start + idx + replacement.size

        # shift fields to the left
        while f < @total
          @tuple.put(t, @tuple.at(f))
          t += 1
          f += 1
        end

        # unset any extraneous fields
        while t < @tuple.fields
          @tuple.put(t, nil)
          t += 1
        end

        @total -= (cnt - replacement.size)
      end

      return ent
    end

    nt = @start + idx + 1
    reallocate(nt) if @tuple.size < nt

    @tuple.put @start + idx, ent
    if idx >= @total - 1
      @total = idx + 1
    end
    return ent
  end

  # Appends the object to the end of the Array.
  # Returns self so several appends can be chained.
  def <<(obj)
    nt = @start + @total + 1
    reallocate nt if @tuple.size < nt
    @tuple.put @start + @total, obj
    @total += 1
    self
  end

  # Removes all nil elements from self, returns nil if no changes
  # TODO: Needs improvement
  def compact!()
    i = @start
    tot = @start + @total

    # Low-level because pretty much anything else breaks everything
    while i < tot
      if @tuple.at(i).nil?
        j = i
        i += 1

        while i < tot
          if @tuple.at(i) != nil
            @tuple.put j, @tuple.at(i)
            j += 1
          end

          i += 1
        end

        # OK to leave tuple size larger?
        @total = j - @start
        return self
      end

      i += 1
    end

    nil
  end

  # Appends the elements in the other Array to self
  def concat(other)
    ary = Type.coerce_to(other, Array, :to_ary)
    size = @total + ary.size
    tuple = Tuple.new size
    tuple.copy_from @tuple, @start, 0 if @total > 0
    tuple.copy_from ary.tuple, ary.start, @total
    @tuple = tuple
    @start = 0
    @total = size
    self
  end

  # Stupid subtle differences prevent proper reuse in these three

  # Removes all elements from self that are #== to the given object.
  # If the object does not appear at all, nil is returned unless a
  # block is provided in which case the value of running it is
  # returned instead.
  def delete(obj)
    i = @start
    tot = @start + @total

    # Leaves the tuple to the original size still
    while i < tot
      if @tuple.at(i) == obj
        j = i
        i += 1

        while i < tot
          if @tuple.at(i) != obj
            @tuple.put(j, @tuple.at(i))
            j += 1
          end

          i += 1
        end

        @total = j - @start
        return obj
      end

      i += 1
    end

    yield if block_given?
  end

  # Deletes the element at the given index and returns
  # the deleted element or nil if the index is out of
  # range. Negative indices count backwards from end.
  def delete_at(idx)
    idx = Type.coerce_to idx, Fixnum, :to_int

    # Flip to positive and weed out out of bounds
    idx += @total if idx < 0
    return nil if idx < 0 or idx >= @total

    # Grab the object and adjust the indices for the rest
    obj = @tuple.at(@start + idx)

    idx.upto(@total - 2) { |i| @tuple.put(@start + i, @tuple.at(@start + i + 1)) }
    @tuple.put(@start + @total - 1, nil)

    @total -= 1
    obj
  end

  # Deletes every element from self for which block evaluates to true
  def delete_if()
    i = @start
    tot = @total + @start

    # Leaves the tuple to the original size still
    while i < tot
      if yield @tuple.at(i)
        j = i
        i += 1

        while i < tot
          unless yield @tuple.at(i)
            @tuple.put(j, @tuple.at(i))
            j += 1
          end

          i += 1
        end

        @total = j - @start
        return self
      end

      i += 1
    end

    return self
  end

  # Passes each element in the Array to the given block
  # and returns self.  We re-evaluate @total each time
  # through the loop in case the array has changed.
  def each()
    i = 0
    while i < @total
      yield at(i)
      i += 1
    end
    self
  end

  # Attempts to return the element at the given index. By default
  # an IndexError is raised if the element is out of bounds. The
  # user may supply either a default value or a block that takes
  # the index object instead.
  def fetch(idx, *rest)
    raise ArgumentError, "Expected 1-2, got #{1 + rest.length}" if rest.length > 1
    warn 'Block supercedes default object' if !rest.empty? && block_given?

    idx, orig = Type.coerce_to(idx, Fixnum, :to_int), idx
    idx += @total if idx < 0

    if idx < 0 || idx >= @total
      return yield(orig) if block_given?
      return rest.at(0) unless rest.empty?

      raise IndexError, "Index #{idx} out of array" if rest.empty?
    end

    at(idx)
  end

  # Fill some portion of the Array with a given element. The
  # element to be used can be either given as the first argument
  # or as a block that takes the index as its argument. The
  # section that is to be filled can be defined by the following
  # arguments. The first following argument is either a starting
  # index or a Range. If the first argument is a starting index,
  # the second argument can be the length. No length given
  # defaults to rest of Array, no starting defaults to 0. Negative
  # indices are treated as counting backwards from the end. Negative
  # counts leave the Array unchanged. Returns self.
  #
  # array.fill(obj)                                -> array
  # array.fill(obj, start [, length])              -> array
  # array.fill(obj, range)                         -> array
  # array.fill {|index| block }                    -> array
  # array.fill(start [, length]) {|index| block }  -> array
  # array.fill(range) {|index| block }             -> array
  #
  def fill(*args)
    raise ArgumentError, "Wrong number of arguments" if block_given? and args.size > 2
    raise ArgumentError, "Wrong number of arguments" if args.size > 3

    # Normalise arguments
    start, finish, obj = 0, (@total - 1), nil

    obj = args.shift unless block_given?
    one, two = args.at(0), args.at(1)

    if one.kind_of? Range
      raise TypeError, "Length invalid with range" if args.size > 1   # WTF, MRI, TypeError?

      start, finish = Type.coerce_to(one.begin, Fixnum, :to_int), Type.coerce_to(one.end, Fixnum, :to_int)

      start += @total if start < 0
      finish += @total if finish < 0

      if one.exclude_end?
        return self if start == finish
        finish -= 1
      end

      raise RangeError, "#{one.inspect} out of range" if start < 0
      return self if finish < 0           # Nothing to modify

    else
      if one
        start = Type.coerce_to one, Fixnum, :to_int

        start += @total if start < 0
        start = 0 if start < 0            # MRI comp adjusts to 0

        if two
          finish = Type.coerce_to two, Fixnum, :to_int
          raise ArgumentError, "argument too big" if finish < 0 && start < finish.abs
          return self if finish < 1       # Nothing to modify

          finish = start + finish - 1
        end
      end
    end                                   # Argument normalisation

    # Adjust the size progressively
    unless finish < @total
      nt = finish + 1
      reallocate(nt) if @tuple.size < nt
      @total = finish + 1
    end

    if block_given?
      start.upto(finish) { |i|  @tuple.put @start + i, yield(i) }
    else
      start.upto(finish) { |i|  @tuple.put @start + i, obj }
    end


    self
  end

  # Returns true if the given obj is present in the Array.
  # Presence is determined by calling elem == obj until found.
  def include?(obj)
    @total.times { |i| return true if @tuple.at(@start + i) == obj }
    false
  end

  # Returns the index of the first element in the Array
  # for which elem == obj is true or nil.
  def index(obj)
    @total.times { |i| return i if @tuple.at(@start + i) == obj }
    nil
  end


  # For a positive index, inserts the given values before
  # the element at the given index. Negative indices count
  # backwards from the end and the values are inserted
  # after them.
  def insert(idx, *items)
    return self if items.length == 0

    # Adjust the index for correct insertion
    idx = Type.coerce_to idx, Fixnum, :to_int
    idx += (@total + 1) if idx < 0    # Negatives add AFTER the element
    raise IndexError, "#{idx} out of bounds" if idx < 0

    self[idx, 0] = items   # Cheat
    self
  end


  # Generates a string from converting all elements of
  # the Array to strings, inserting a separator between
  # each. The separator defaults to $,. Detects recursive
  # Arrays.
  def join(sep = nil, method = :to_s)
    return "" if @total == 0
    sep ||= $,
    begin
      sep = sep.to_str
    rescue NoMethodError
      raise TypeError, "Cannot convert #{sep.inspect} to str"
    end

    out = ""

    @total.times do |i|
      elem = at(i)

      out << sep unless i == 0
      if elem.kind_of?(Array)
        if RecursionGuard.inspecting?(elem)
          out << "[...]"
        else
          RecursionGuard.inspect(self) do
            out << elem.join(sep, method)
          end
        end
      else
        out << elem.__send__(method)
      end
    end
    out
  end


  BASE_64_B2A = {}
  def self.after_loaded
    (00..25).each {|x| BASE_64_B2A[x] = (?A + x - 00).chr}
    (26..51).each {|x| BASE_64_B2A[x] = (?a + x - 26).chr}
    (52..61).each {|x| BASE_64_B2A[x] = (?0 + x - 52).chr}
    BASE_64_B2A[62] = '+'
    BASE_64_B2A[63] = '/'
  end

  # Removes and returns the last element from the Array.
  def pop()
    return nil if empty?

    # TODO Reduce tuple if there are a lot of free slots

    elem = at(-1)
    @total -= 1
    elem
  end
  # Rubinius-only, better inspect representation of the Array
  def indented_inspect(indent = 0)
    # Here there be dragons. In fact, there is one jusAAAAAAAARGH
    str = "["

    sub = false
    i = 0
    lst = size - 1
    while i < size
      element = self[i]
      if Array === element
        estr = element.indented_inspect(indent + 2)
        if str.size > 30 or estr.size > 30
          if estr[0] != ?\s
            estr = "#{' ' * (indent + 2)}#{estr}"
          end

          str << "\n#{estr}"
          sub = true
        else
          str << estr
        end
      else
        str << element.inspect
      end

      str << ", " unless i == lst
      i += 1
    end

    if sub
      str << "\n#{' ' * indent}]"
    else
      str << "]"
    end

    if sub
      return "#{' ' * indent}#{str}"
    end

    return str
  end

  # Replaces contents of self with contents of other,
  # adjusting size as needed.
  def replace(other)
    other = Type.coerce_to other, Array, :to_ary

    @tuple = other.tuple.dup
    @total = other.total
    @start = other.start
    self
  end

  # Reverses the order of elements in self. Returns self
  # even if no changes are made
  def reverse!
    return self unless @total > 1

    tuple = Tuple.new @total
    i = 0
    (@start + @total - 1).downto(@start) do |j|
      tuple.put i, @tuple.at(j)
      i += 1
    end

    @tuple = tuple
    @start = 0

    self
  end

  # Goes through the Array back to front and yields
  # each element to the supplied block. Returns self.
  def reverse_each()
    (@total - 1).downto(0) { |i| yield(at(i)) }
    self
  end

  # Returns the index of the last element in the Array
  # for which elem == obj is true.
  def rindex(obj)
    (@total - 1).downto(0) { |i| return i if at(i) == obj }
    nil
  end

  # Removes and returns the first element in the
  # Array or nil if empty. All other elements are
  # moved down one index.
  def shift()
    return nil if @total == 0

    obj = @tuple.at(@start)
    @start += 1
    @total -= 1

    obj
  end

  # Sorts this Array in-place. See #sort.
  def sort!(&block)
    return self unless @total > 1

    if (@total - @start) < 6
      if block
        isort_block! @start, (@total - 1), block
      else
        isort! @start, (@total - 1)
      end
    else
      if block
        qsort_block! block
      else
        qsort!
      end
    end

    self
  end

  # Returns a new Array populated from the elements in
  # self corresponding to the given selector(s.) The
  # arguments may be one or more integer indices or
  # Ranges.
  def values_at(*args)
    out = []

    args.each { |elem|
      # Cannot use #[] because of subtly different errors
      if elem.kind_of? Range
        finish = elem.last
        start = elem.first

        start, finish = Type.coerce_to(start, Fixnum, :to_int), Type.coerce_to(finish, Fixnum, :to_int)

        start += @total if start < 0
        next if start < 0

        finish += @total if finish < 0
        finish -= 1 if elem.exclude_end?
        finish = @total unless finish < @total

        next if finish < start

        start.upto(finish) { |i| out << at(i) }

      else
        i = Type.coerce_to elem, Fixnum, :to_int
        out << at(i)
      end
    }

    out
  end

  # Interleaves all given :to_ary's so that the n-th element of each
  # Array is inserted into the n-th subarray of the returned Array.
  # If a block is provided, then each subarray is passed to it
  # instead. The maximum number of subarrays and therefore elements
  # used is the size of self. Missing indices are filled in with
  # nils and any elements past self.size in the other Arrays are
  # ignored.
  def zip(*others)
    out = Array.new(size) { [] }
    others = others.map { |ary| ary.to_a }

    size.times do |i|
      slot = out.at(i)
      slot << @tuple.at(@start + i)
      others.each { |ary| slot << ary.at(i) }
    end

    if block_given?
      out.each { |ary| yield ary }
      return nil
    end

    out
  end

  def unshift(*values)
    while values.size > 0 && @start > 0
      @start -= 1
      @total += 1
      @tuple.put @start, values.pop
    end

    @tuple = @tuple.shifted(values.size)

    values.each_with_index do |val, i|
      @tuple.put i, val
    end

    @total += values.size
    self
  end


  # Reallocates the internal Tuple to accommodate at least given size
  def reallocate(at_least)
    return if at_least < @tuple.size

    new_size = @tuple.size * 2

    if new_size < at_least
      new_size = at_least
    end

    tuple = Tuple.new(new_size)

    tuple.copy_from @tuple, @start, 0     # Swap over old data

    @tuple = tuple
    @start = 0
  end

  private :reallocate

  # Helper to recurse through flattening since the method
  # is not allowed to recurse itself. Detects recursive structures.
  def recursively_flatten(array, out, recursive_placeholder = Undefined)
    if RecursionGuard.inspecting?(array)
      if recursive_placeholder.equal? Undefined
        raise ArgumentError, "tried to flatten recursive array"
      else
        out << recursive_placeholder
        return nil
      end
    end

    ret = nil
    array.each { |o|
      if o.respond_to? :to_ary
        RecursionGuard.inspect(array) do
          ary = Type.coerce_to o, Array, :to_ary
          recursively_flatten(ary, out, recursive_placeholder)
          ret = self
        end
      else
        out << o
      end
    }

    ret
  end

  private :recursively_flatten

  def remove_outer_arrays(array=self)
    if RecursionGuard.inspecting?(array)
      array
    elsif array.size == 1 && array.first.kind_of?(Array)
      new_array = nil
      RecursionGuard.inspect(array) do
        new_array = remove_outer_arrays(array.first)
      end
      new_array
    else
      array
    end
  end

  private :remove_outer_arrays

  ISORT_THRESHOLD   = 7
  MEDIAN_THRESHOLD  = 11

  # In-place non-recursive sort between the given indexes.
  def qsort!()
    # Stack stores the indexes that still need sorting
    stack = []
    left_end, right_end = @start, (@total - 1)

    # We are either processing a 'new' partition or one that
    # was saved to stack earlier.
    while true
      left, right = left_end, (right_end - 1)   # Leave room for pivot
      eqls_left, eqls_right = (left_end - 1), right_end

      # Choose pivot from median
      # CAUTION: This is NOT the same as #qsort_block!
      middle = left_end + ((right_end - left_end) / 2)
      low, mid, hi = @tuple.at(left_end), @tuple.at(middle), @tuple.at(right_end)

      segment_size = right_end - left_end

      # "Heuristic" to avoid problems with reverse-sorted
      if segment_size > 1000 and (low <=> mid) == 1 and (mid <=> hi) == 1
        semi_left = @tuple.at(left_end + ((middle - left_end) / 2))
        semi_right = @tuple.at(middle + ((right_end - middle) / 2))

        if (low <=> semi_left) == 1 and (semi_left <=> mid) == 1 and
           (mid <=> semi_right) == 1 and (semi_right <=> hi) == 1

          r = segment_size / 4
          while r > 0
            @tuple.swap(rand(segment_size), rand(segment_size))
            r -= 1
          end

          middle += (right_end - middle) / 2
        end
      end

      # These can be reordered which may help with sorting randomly
      # distributed elements at the cost of presorted. Be sure to
      # mark down the correct order though..
      @tuple.swap(left_end, right_end)  if (hi <=> low) < 0
      @tuple.swap(left_end, middle)     if (mid <=> low) < 0
      @tuple.swap(middle, right_end)    if (hi <=> mid) < 0

      pivot = @tuple.at(middle)
      @tuple.swap(right_end, middle)  # Known position to help partition three ways

      # Partition
      while true
        while left < right_end
          case @tuple.at(left) <=> pivot
          when -1
            left += 1
          when 0
            @tuple.swap(left, (eqls_left += 1))
            left += 1
          else
            break
          end
        end

        while right > left_end
          case @tuple.at(right) <=> pivot
          when 1
            right -= 1
          when 0
            @tuple.swap(right, (eqls_right -= 1))
            right -= 1
          else
            break
          end
        end

        break if left >= right
        @tuple.swap(left, right)
      end

      # Move pivot back to the middle
      @tuple.swap(left, right_end)
      left, right = (left - 1), (left + 1)

      # Move the stashed == pivot elements back to the middle
      while eqls_left >= left_end
        @tuple.swap(eqls_left, left)
        left -= 1
        eqls_left -= 1
      end

      unless right >= right_end
        while eqls_right < right_end and right < right_end
          @tuple.swap(eqls_right, right)
          right += 1
          eqls_right += 1
        end
      end

      # Continue processing the now smaller partitions or if
      # done with this segment, restore a stored one from the
      # stack until nothing remains either way.
      left_size, right_size = (left - left_end), (right_end - right)

      # Insertion sort is faster at anywhere below 7-9 elements
      if left_size < ISORT_THRESHOLD
        isort! left_end, left

        # We can restore next saved if both of these are getting sorted
        if right_size < ISORT_THRESHOLD
          isort! right, right_end
          break if stack.empty?       # Completely done, no stored ones left either
          left_end, right_end = stack.pop
        else
          left_end = right
        end

      elsif right_size < ISORT_THRESHOLD
        isort! right, right_end
        right_end = left

      # Save whichever is the larger partition and do the smaller first
      else
        if left_size > right_size
          stack.push [left_end, left]
          left_end = right
        else
          stack.push [right, right_end]
          right_end = left
        end
      end
    end
  end

  # In-place non-recursive sort between the given indexes using a block.
  def qsort_block!(block)
    # Stack stores the indexes that still need sorting
    stack = []
    left_end, right_end = @start, (@total - 1)

    # We are either processing a 'new' partition or one that
    # was saved to stack earlier.
    while true
      left, right = left_end, (right_end - 1)   # Leave room for pivot
      eqls_left, eqls_right = (left_end - 1), right_end

      # Choose pivot from median
      # CAUTION: This is NOT the same as #qsort!
      middle = left_end + ((right_end - left_end) / 2)
      low, mid, hi = @tuple.at(left_end), @tuple.at(middle), @tuple.at(right_end)

      segment_size = right_end - left_end

      # "Heuristic" for reverse-sorted
      if segment_size > 1000 and block.call(low, mid) == 1 and block.call(mid, hi) == 1
        semi_left = @tuple.at(left_end + ((middle - left_end) / 2))
        semi_right = @tuple.at(middle + ((right_end - middle) / 2))

        if block.call(low, semi_left) == 1 and block.call(semi_left, mid) == 1 and
           block.call(mid, semi_right) == 1 and block.call(semi_right, hi) == 1

          r = segment_size / 4
          while r > 0
            @tuple.swap(rand(segment_size), rand(segment_size))
            r -= 1
          end

          middle += (right_end - middle) / 2
        end
      end

      # These can be reordered which may help with sorting randomly
      # distributed elements at the cost of presorted. Be sure to
      # mark down the correct order though..
      @tuple.swap(left_end, right_end)  if block.call(hi, low)  < 0
      @tuple.swap(left_end, middle)     if block.call(mid, low) < 0
      @tuple.swap(middle, right_end)    if block.call(hi, mid)  < 0

      pivot = @tuple.at(middle)
      @tuple.swap(right_end, middle)  # Known position to help partition three ways

      # Partition
      while true
        while left < right_end
          case block.call(@tuple.at(left), pivot)
          when -1
            left += 1
          when 0
            @tuple.swap(left, (eqls_left += 1))
            left += 1
          else
            break
          end
        end

        while right > left_end
          case block.call(@tuple.at(right), pivot)
          when 1
            right -= 1
          when 0
            @tuple.swap(right, (eqls_right -= 1))
            right -= 1
          else
            break
          end
        end

        break if left >= right
        @tuple.swap(left, right)
      end

      # Move pivot back to the middle
      @tuple.swap(left, right_end)
      left, right = (left - 1), (left + 1)

      # Move the stashed == pivot elements back to the middle
      while eqls_left >= left_end
        @tuple.swap(eqls_left, left)
        left -= 1
        eqls_left -= 1
      end

      unless right >= right_end
        while eqls_right < right_end and right < right_end
          @tuple.swap(eqls_right, right)
          right += 1
          eqls_right += 1
        end
      end

      # Continue processing the now smaller partitions or if
      # done with this segment, restore a stored one from the
      # stack until nothing remains either way.
      left_size, right_size = (left - left_end), (right_end - right)

      # Insertion sort is faster at anywhere below 7-9 elements
      if left_size < ISORT_THRESHOLD
        isort_block! left_end, left, block

        # We can restore next saved if both of these are getting sorted
        if right_size < ISORT_THRESHOLD
          isort_block! right, right_end, block
          break if stack.empty?       # Completely done, no stored ones left either
          left_end, right_end = stack.pop
        else
          left_end = right
        end

      elsif right_size < ISORT_THRESHOLD
        isort_block! right, right_end, block
        right_end = left

      # Save whichever is the larger partition and do the smaller first
      else
        if left_size > right_size
          stack.push [left_end, left]
          left_end = right
        else
          stack.push [right, right_end]
          right_end = left
        end
      end
    end
  end

  # Insertion sort in-place between the given indexes.
  def isort!(left, right)
    i = left + 1

    while i <= right
      j = i

      while j > 0 and (@tuple.at(j - 1) <=> @tuple.at(j)) > 0
        @tuple.swap(j, (j - 1))
        j -= 1
      end

      i += 1
    end
  end

  # Insertion sort in-place between the given indexes using a block.
  def isort_block!(left, right, block)
    i = left + 1

    while i <= right
      j = i

      while j > 0 and block.call(@tuple.at(j - 1), @tuple.at(j)) > 0
        @tuple.swap(j, (j - 1))
        j -= 1
      end

      i += 1
    end
  end
  
  def __rescue_match__(exception)
    i = 0
    while i < @total
      return true if at(i) === exception
      i += 1
    end
    false
  end
  
  private :qsort
  private :isort
  private :qsort_block
  private :isort_block
end


