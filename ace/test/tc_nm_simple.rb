require_relative 'test_common'
require_relative '../nm_simple'

class NmSimpleTest < MiniTest::Unit::TestCase
  def test_empty_doc
    s = SimpleNmLinear.new
    s.tick
    assert_equal([[BEGIN_ID, END_ID]], s.sem_hist.to_a)
    assert_equal([[BEGIN_ID, END_ID]], s.before.to_a)
    assert_equal([[BEGIN_ID, END_ID]], s.before_tc.to_a)
    assert_equal([[BEGIN_ID, END_ID]], s.explicit.to_a)
    assert_equal([], s.implied_parent.to_a)
  end

  def test_fail_nil_pre
    s = SimpleNmLinear.new
    s.constr <+ [[1, nil, END_ID]]
    assert_raises(InvalidDocError) { s.tick }
  end

  def test_fail_nil_post
    s = SimpleNmLinear.new
    s.constr <+ [[1, BEGIN_ID, nil]]
    assert_raises(InvalidDocError) { s.tick }
  end

  def test_fail_cycle
    s = SimpleNmLinear.new
    s.constr <+ [[1, BEGIN_ID, END_ID],
                 [2, 1, END_ID],
                 [3, 2, 1]]
    assert_raises(InvalidDocError) { s.tick }
  end

  def test_explicit_simple
  end

  def test_tiebreak_simple
  end

  # 3 -> 1 is clear, but 2 might plausibly be placed anywhere with respect to 3
  # and 1: [2,3,1], [3,2,1], [3,1,2] all respect the explicit constraints.
  # However, since we would order 1 -> 2 given only those two atoms, this
  # implied constraint must also be respected. Hence, [3,1,2] is the only
  # correct outcome. Note that this scenario is essentially identical to the
  # "dOPT Puzzle" described in "Operational transformation in real-time group
  # editors: issues, algorithms, and achievements" (Sun and Ellis, CSCW'98).
  def test_implied_parent_simple
  end
end
