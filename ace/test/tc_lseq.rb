require 'rubygems'
require 'bud'
require_relative '../lseq'

gem 'minitest'
require 'minitest/autorun'

class SeqTest < MiniTest::Unit::TestCase
  def test_non_comparable
    assert_raises(Bud::TypeError) { SeqLattice.new([true]) }
  end

  def test_singleton
    x = SeqLattice.new([5])
    y = SeqLattice.new([10])
    assert_equal(x, x.merge(x))
    assert_equal(y, y.merge(y))
    m1 = x.merge(y)
    m2 = y.merge(x)
    assert_equal(SeqLattice.new([5, 10]), m1)
    assert_equal(SeqLattice.new([5, 10]), m2)
    assert_equal(Bud::MaxLattice.new(2), m1.size)
    assert_equal(Bud::MaxLattice.new(2), m2.size)
    assert_equal(Bud::SetLattice.new([10, 5]), m1.elements)
    assert_equal(Bud::SetLattice.new([10, 5]), m2.elements)
  end
end
