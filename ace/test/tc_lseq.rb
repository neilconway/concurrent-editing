require_relative 'test_common'
require_relative '../lseq'

class SeqTest < MiniTest::Unit::TestCase
  def test_non_comparable
    assert_raises(Bud::TypeError) { SeqLattice.new([true]) }
  end

  def check_permutations(ops)
    ops.permutation.each do |x|
      ops.permutation.each do |y|
        assert(x.reduce(:merge) == y.reduce(:merge))
      end
    end
  end

  def test_singleton
    x = SeqLattice.new([5])
    y = SeqLattice.new([10])

    check_permutations([x, y])
    m1 = x.merge(y)
    m2 = y.merge(x)
    assert_equal(Bud::MaxLattice.new(2), m1.size)
    assert_equal(Bud::MaxLattice.new(2), m2.size)
    assert_equal(Bud::SetLattice.new([10, 5]), m1.elements)
    assert_equal(Bud::SetLattice.new([10, 5]), m2.elements)
  end

  def test_basic
    ops = (1..4).map {|i| SeqLattice.new([i])}
    ops.combination(2).each {|o| check_permutations(o)}
    ops.combination(3).each {|o| check_permutations(o)}
    check_permutations(ops)
  end
end
