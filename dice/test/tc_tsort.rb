require_relative 'test_common'
require_relative '../tsort'

class TSortTest < MiniTest::Unit::TestCase
  def max(x)
    Bud::MaxLattice.new(x)
  end

  def test_basic
    t = TSort.new
    t.edge <= [['aa', 'b'],
               ['a', 'b'],
               ['b', 'c'],
               ['c', 'd'],
               ['d', 'y'],
               ['d', 'z'],
               ['a', 'm'],
               ['m', 'n'],
               ['n', 'o'],
               ['o', 'y'],
               ['o', 'z']]
    t.tick

    result = t.min_cost.to_a.sort {|a,b| [a.c, a.n] <=> [b.c, b.n]}
    assert_equal([["a", max(0)],
                  ["aa", max(0)],
                  ["b", max(1)],
                  ["m", max(1)],
                  ["c", max(2)],
                  ["n", max(2)],
                  ["d", max(3)],
                  ["o", max(3)],
                  ["y", max(4)],
                  ["z", max(4)]], result)
  end
end
