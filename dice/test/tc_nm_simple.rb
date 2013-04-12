require_relative 'test_common'
require_relative '../nm_simple'

class NmSimpleTest < MiniTest::Unit::TestCase
  def test_empty_doc
    s = SimpleNmLinear.new
    s.tick
    check_linear_order(s, BEGIN_ID, END_ID)
    check_sem_hist(s)
    assert_equal([[BEGIN_ID, END_ID]], s.explicit.to_a)
    assert_equal([], s.use_implied_anc.to_a)
  end

  def test_fail_nil_pre
    s = SimpleNmLinear.new
    s.input_buf <+ [[1, nil, END_ID]]
    assert_raises(InvalidDocError) { s.tick }
  end

  def test_fail_nil_post
    s = SimpleNmLinear.new
    s.input_buf <+ [[1, BEGIN_ID, nil]]
    assert_raises(InvalidDocError) { s.tick }
  end

  def test_fail_cycle
    s = SimpleNmLinear.new
    s.input_buf <+ [[1, BEGIN_ID, END_ID],
                    [2, 1, END_ID],
                    [3, 2, 1]]
    s.tick ; s.tick
    assert_raises(InvalidDocError) { s.tick }
  end

  def test_explicit
    s = SimpleNmLinear.new
    s.input_buf <+ [[9, BEGIN_ID, END_ID],
                    [2, 9, END_ID],
                    [1, 9, 2]]
    s.tick
    s.tick
    s.tick
    check_linear_order(s, BEGIN_ID, 9, 1, 2, END_ID)
    check_sem_hist(s, 9 => [], 2 => [9], 1 => [2, 9])
  end

  def test_tiebreak
    s = SimpleNmLinear.new
    s.input_buf <+ [[1, BEGIN_ID, END_ID],
                    [2, BEGIN_ID, END_ID]]
    s.tick
    s.tick
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
  def test_implied_anc
    s = SimpleNmLinear.new
    s.input_buf <+ [[1, BEGIN_ID, END_ID],
                    [2, BEGIN_ID, END_ID],
                    [3, BEGIN_ID, 1]]
    # First tick: non-tiebreaks for 1
    s.tick
    # Second tick: tiebreaks for 1, non-tiebreaks for 2
    s.tick
    # Third tick: tiebreaks for 2, non-tiebreaks for 3
    s.tick
    check_linear_order(s, BEGIN_ID, 3, 1, 2, END_ID)
    check_sem_hist(s, 1 => [], 2 => [], 3 => [1])
    assert_equal([[3, 2]], s.use_implied_anc.to_a.sort)

    s.tick      # No-op
    check_linear_order(s, BEGIN_ID, 3, 1, 2, END_ID)
    check_sem_hist(s, 1 => [], 2 => [], 3 => [1])
  end

  def test_implied_anc_pre
    s = SimpleNmLinear.new
    s.input_buf <+ [[2, BEGIN_ID, END_ID],
                    [3, BEGIN_ID, END_ID],
                    [1, 3, END_ID]]
    s.tick ; s.tick ; s.tick

    check_linear_order(s, BEGIN_ID, 2, 3, 1, END_ID)
    check_sem_hist(s, 2 => [], 3 => [], 1 => [3])

    s.tick      # No-op
    check_linear_order(s, BEGIN_ID, 2, 3, 1, END_ID)
    check_sem_hist(s, 2 => [], 3 => [], 1 => [3])
  end

  # Similar to the above scenario, but slightly more complicated: there are two
  # concurrent edits 3,4 that depend on 2 and 1, respectively.
  def test_implied_anc_concurrent
    s = SimpleNmLinear.new
    s.input_buf <+ [[1, BEGIN_ID, END_ID],
                    [2, BEGIN_ID, END_ID],
                    [3, BEGIN_ID, 2],
                    [4, BEGIN_ID, 1]]
    s.tick
    s.tick
    s.tick
    s.tick
    check_linear_order(s, BEGIN_ID, 4, 1, 3, 2, END_ID)
    check_sem_hist(s, 1 => [], 2 => [], 3 => [2], 4 => [1])
  end

  def test_doc_tree
    doc = [[10, BEGIN_ID, END_ID],
           [11, 10, END_ID],
           [12, 11, END_ID],
           [13, 12, END_ID],
           [15, 13, 14],
           [14, 12, END_ID],
           [30, BEGIN_ID, END_ID],
           [31, 30, END_ID],
           [99, 31, 40],
           [40, BEGIN_ID, END_ID],
           [41, 40, END_ID]]
    input = doc.shuffle
    s = SimpleNmLinear.new
    input.each do |i|
      s.input_buf <+ [i]
      s.tick
    end
    doc.length.times { s.tick }

    doc_order = doc.map {|d| d.first}
    check_linear_order(s, BEGIN_ID, *doc_order, END_ID)
    check_sem_hist(s,
                   10 => [], 11 => [10], 12 => [10, 11], 13 => [10, 11, 12],
                   14 => [10,11,12], 15 => [10,11,12,13,14], 30 => [],
                   31 => [30], 99 => [30, 31, 40], 40 => [], 41 => [40])
  end

  def check_linear_order(b, *vals)
    ary = []
    vals.each_with_index do |v,i|
      i.times do |j|
        ary << [vals[j], vals[i]]
      end
    end
    assert_equal(ary.sort, b.before.to_a.sort)
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
