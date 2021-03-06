$: << 'lib' # so we can run in MRI

require File.dirname(__FILE__) + "/spec_helper"

$-w = true

##
# Two dimensions:
# + one vs many
# + splat on end vs not
#
# Other edge cases:
# + no block args
# + empty block args
# + paren args (for like, each_with_index on a hash)
# + nested paren args
# + unnamed splat
# + trailing comma "arg"

describe Compiler do
  platform_is :rubinius do
    it "compiles 'ary.each do; ... end'" do
      x = [:iter,
           [:call, [:vcall, :ary], :each],
           nil]

      gen_iter x do |d|
        # do nothing
      end
    end

    it "compiles 'ary.each do ||; end'" do
      # FIX: we don't distinguish between no and empty args
      x = [:iter,
           [:call, [:vcall, :ary], :each],
           nil]

      gen_iter x do |d|
        # do nothing
      end
    end

    it "compiles 'ary.each do |a|; end'" do
      x = [:iter,
           [:call, [:vcall, :ary], :each],
           [:lasgn, :a]]

      gen_iter x do |d|
        d.cast_for_single_block_arg
        d.set_local_depth 0, 0
      end
    end

    it "compiles 'ary.each do |a, |; ... end'" do
      x = [:iter,
           [:call, [:vcall, :ary], :each],
           [:masgn, [:array, [:lasgn, :a]], nil, nil]]

      gen_iter x do |d|
        d.cast_for_multi_block_arg
        d.lvar_at 0
      end
    end

    it "compiles 'ary.each do |*a|; ... end'" do
      x = [:iter,
           [:call, [:vcall, :ary], :each],
           [:masgn, [:lasgn, :a], nil]]

      gen_iter x do |d|
        d.cast_array
        d.set_local_depth 0, 0
      end
    end

    it "compiles 'ary.each do |a, b, c|; ... end'" do
      x = [:iter,
           [:call, [:vcall, :ary], :each],
           [:masgn,
            [:array,
             [:lasgn, :a],
             [:lasgn, :b],
             [:lasgn, :c]], nil, nil]]

      gen_iter x do |d|
        d.cast_for_multi_block_arg
        3.times do |slot|
          d.lvar_at slot
        end
      end
    end

    it "compiles 'ary.each do |a, b, *c|; ... end'" do
      x = [:iter,
           [:call, [:vcall, :ary], :each],
           [:masgn,
            [:array,
             [:lasgn, :a],
             [:lasgn, :b]],
            [:lasgn, :c], nil]]

      gen_iter x do |d|
        d.cast_for_multi_block_arg
        d.lvar_at 0
        d.lvar_at 1
        d.cast_array
        d.set_local_depth 0, 2
      end
    end

    it "compiles 'ary.each do |(a, b), c|; ... end'" do
      x = [:iter,
           [:call, [:vcall, :ary], :each],
           [:masgn,
            [:array,
             [:masgn,
              [:array,
               [:lasgn, :a],
               [:lasgn, :b]], nil, nil],
             [:lasgn, :c]], nil, nil]]

      gen_iter x do |d|
        d.cast_for_multi_block_arg
        d.unshift_tuple

        # Pull the first element out and use it like a tuple.
        d.cast_tuple
        d.lvar_at 0
        d.lvar_at 1
        d.pop
        d.push :true

        d.pop

        d.lvar_at 2
      end
    end

    it "compiles 'ary.each do |(a, b), *c|; ... end'" do
      x = [:iter,
           [:call, [:vcall, :ary], :each],
           [:masgn,
            [:array,
             [:masgn,
              [:array,
               [:lasgn, :a],
               [:lasgn, :b]], nil, nil]],
            [:lasgn, :c], nil]]

      gen_iter x do |d|
        d.cast_for_multi_block_arg
        d.unshift_tuple
        d.cast_tuple

        d.lvar_at 0
        d.lvar_at 1

        d.pop
        d.push :true
        d.pop
        d.cast_array
        d.set_local_depth 0, 2
      end
    end

    it "compiles 'ary.each do |(a, (b, c)), d|; ... end'" do
      x = [:iter,
           [:call, [:vcall, :ary], :each],
           [:masgn,
            [:array,
             [:masgn,
              [:array,
               [:lasgn, :a],
               [:masgn,
                [:array,
                 [:lasgn, :b],
                 [:lasgn, :c]], nil, nil]], nil, nil],
             [:lasgn, :d]], nil, nil]]

      gen_iter x do |d|
        d.cast_for_multi_block_arg
        d.unshift_tuple
        d.cast_tuple

        d.lvar_at 0

        d.unshift_tuple
        d.cast_tuple

        d.lvar_at 1
        d.lvar_at 2

        2.times do
          d.pop
          d.push :true
          d.pop
        end

        d.lvar_at 3
      end
    end

    it "compiles 'ary.each do |*|; ... end'" do
      x = [:iter,
           [:call, [:vcall, :ary], :each],
           [:masgn, true, nil]]

      gen_iter x do |d|
      end
    end

    it "compiles 'ary.each do |a, *|; ... end'" do
      x = [:iter,
           [:call, [:vcall, :ary], :each],
           [:masgn, [:array, [:lasgn, :a]], true, nil]]

      gen_iter x do |d|
        d.cast_for_multi_block_arg
        d.lvar_at 0
      end
    end
  end

  it "runs 'ary.each do; ... end'" do
    i = 0
    %w(a b c d e f g).each { i += 1 }
    i.should == 7
  end

  it "runs 'ary.each do ||; ... end'" do
    i = 0
    %w(a b c d e f g).each { || i += 1 } # TODO: check || should warn or not
    i.should == 7
  end

  it "runs 'ary.each do |a|; end'" do
    data = [[1, 2, 3], [4, 5], 6]

    data.dup.map { |a| a }.should == data.dup
  end

  it "runs 'ary.each do |a, |; end'" do
    data = [[1, 2, 3], [4, 5, 6], 7]

    data.dup.map { |a, | a }.should == [1, 4, 7]
  end

  it "runs 'ary.each do |*a|; ... end'" do
    data = [[1, 2, 3], [4, 5], 6]
    expected = [[[1, 2, 3]], [[4, 5]], [6]]

    data.dup.map { |*a| a }.should == expected
  end

  it "runs 'ary.each do |a, b, c|; end'" do
    data = [[1, 2, 3], [4, 5], 6]
    expected = [[1, 2, 3], [4, 5, nil], [6, nil, nil]]

    data.dup.map { |a, b, c| [a, b, c] }.should == expected
  end

  it "runs 'ary.each do |a, b, *c|; end'" do
    data = [[1, 2, 3], [4, 5], 6]
    expected = [[1, 2, [3]], [4, 5, []], [6, nil, []]]

    data.dup.map { |a, b, *c| [a, b, c] }.should == expected
  end

  it "runs 'ary.each do |(a, b), c|; end'" do
    data = [[[1, 2], 3], [[4], 5], 6]
    expected = [[1, 2, 3], [4, nil, 5], [6, nil, nil]]

    data.dup.map { |(a, b), c| [a, b, c] }.should == expected
  end

  it "runs 'ary.each do |(a, b), *c|; end'" do
    data = [[[1, 2], 3], [[4], 5], 6]
    expected = [[1, 2, [3]], [4, nil, [5]], [6, nil, []]]

    data.dup.map { |(a, b), *c| [a, b, c] }.should == expected
  end

  it "runs 'ary.each do |(a, (b, c)), d|; end'" do
    data     = [[[1, [2, 3]], 4], [[5, 6], 7], [[8], 9], [[10]]]
    expected = [[1, 2, 3, 4], [5, 6, nil, 7],
                [8, nil, nil, 9], [10, nil, nil, nil]]

    data.dup.map { |(a, (b, c)), d| [a, b, c, d] }.should == expected
  end

  it "runs 'ary.each do |*|; end'" do
    i = 0
    %w(a b c d e f g).each { |*| i += 1 }
    i.should == 7
  end

  it "runs 'ary.each do |a, *|; end'" do
    data = [[1, 2, 3], [4, 5], 6]
    expected = [1, 4, 6]

    data.dup.map { |a, *| a }.should == expected
  end
end
