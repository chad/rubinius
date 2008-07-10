class Array
  ivar_as_index :total => 0, :tuple => 1, :start => 2, :shared => 3

  def total    ; @total ; end
  def tuple    ; @tuple ; end
  def start    ; @start ; end
  def __ivars__; nil    ; end

  def size
    @total
  end

  # THIS MUST NOT BE REMOVED. the kernel requires a simple
  # Array#[] to work while parts of the kernel boot.
  def [](idx)    
    if idx >= @total
      return nil
    end

    @tuple.at(@start + idx)
  end

  def []=(idx, ent)
    if idx >= @tuple.fields
      nt = Tuple.new(idx + 10)
      nt.copy_from @tuple, @start, 0
      @tuple = nt
    end

    @tuple.put @start + idx, ent
    if idx >= @total - 1
      @total = idx + 1
    end
    return ent
  end

  # Runtime method to support case when *foo syntax
  def __matches_when__(receiver)
    i = @start
    tot = @total + @start
    while i < tot
      return true if @tuple.at(i) === receiver
      i = i + 1
    end
    false
  end

  # Returns the element at the given index. If the
  # index is negative, counts from the end of the
  # Array. If the index is out of range, nil is
  # returned. Slightly faster than +Array#[]+
  def at(idx)
    Ruby.primitive :array_aref
    idx = Type.coerce_to idx, Fixnum, :to_int
    idx += @total if idx < 0

    return nil if idx < 0 or idx >= @total

    @tuple.at @start + idx
  end

  # Removes all elements in the Array and leaves it empty
  def clear()
    @tuple = Tuple.new(1)
    @total = 0
    @start = 0
    self
  end

  def size
    @total
  end

end
