require_relative 'test_common'
require_relative '../nm_simple'

class NmSimpleTest < MiniTest::Unit::TestCase
  def test_empty_doc
    s = SimpleNmLinear.new
    s.tick
    check_linear_order(s, BEGIN_ID, END_ID)
    check_sem_hist(s)
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
    s = SimpleNmLinear.new
    s.constr <+ [[9, BEGIN_ID, END_ID],
                 [2, 9, END_ID],
                 [1, 9, 2]]
    s.tick
    check_linear_order(s, BEGIN_ID, 9, 1, 2, END_ID)
    check_sem_hist(s,
                   9 => [],
                   2 => [9],
                   1 => [2, 9])
  end

  def test_tiebreak_simple
    s = SimpleNmLinear.new
    s.constr <+ [[1, BEGIN_ID, END_ID],
                 [2, BEGIN_ID, END_ID]]
    s.tick
    check_linear_order(s, BEGIN_ID, 1, 2, END_ID)
    check_sem_hist(s, 1 => [], 2 => [])
  end

  # 3 -> 1 is clear, but 2 might plausibly be placed anywhere with respect to 3
  # and 1: [2,3,1], [3,2,1], [3,1,2] all respect the explicit constraints.
  # However, since we would order 1 -> 2 given only those two atoms, this
  # implied constraint must also be respected. Hence, [3,1,2] is the only
  # correct outcome. Note that this scenario is essentially identical to the
  # "dOPT Puzzle" described in "Operational transformation in real-time group
  # editors: issues, algorithms, and achievements" (Sun and Ellis, CSCW'98).
  def test_implied_parent_simple
    s = SimpleNmLinear.new
    s.constr <+ [[1, BEGIN_ID, END_ID],
                 [2, BEGIN_ID, END_ID],
                 [3, BEGIN_ID, 1]]
    s.tick
    puts s.before_src.to_a.sort.inspect
    check_linear_order(s, BEGIN_ID, 3, 1, 2, END_ID)
  end

  def check_linear_order(b, *vals)
    ary = []
    vals.each_with_index do |v,i|
      i.times do |j|
        ary << [vals[j], vals[i]]
      end
    end
    assert_equal(ary.sort, b.before_tc.to_a.sort)
  end

  def check_sem_hist(b, hist={})
    # We let the caller omit the semantic history of the sentinels
    hist = hist.hmap {|v| v + [BEGIN_ID, END_ID]}
    hist[BEGIN_ID] = [END_ID]
    hist[END_ID] = []

    hist_ary = []
    hist.each do |k,v|
      v.each do |dep|
        hist_ary << [dep, k]
      end
    end
    assert_equal(hist_ary.sort, b.sem_hist.to_a.sort)
  end
end
