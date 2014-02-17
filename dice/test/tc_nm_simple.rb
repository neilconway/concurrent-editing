require_relative 'test_common'
require_relative 'ord_util'
require_relative '../nm_simple'
require 'digest/md5'

class NmSimpleTest < MiniTest::Unit::TestCase
  def check_linear_order(b, *vals)
    vals = [BEGIN_ID] + vals + [END_ID]
    ary = []
    vals.each_with_index do |v,i|
      i.times do |j|
        ary << [vals[i], vals[j]]
      end
    end

    assert_equal(ary.sort, b.ord.to_a.sort, "order mismatch")
  end

  def check_sem_hist(b, hist={})
    # We let the caller omit sentinels from the semantic history
    hist = hist.hmap {|v| v + [BEGIN_ID, END_ID]}
    hist[BEGIN_ID] = [END_ID]
    hist[END_ID] = []

    hist_ary = []
    hist.each do |k,v|
      v.each do |dep|
        hist_ary << [k, dep]
      end
    end
    assert_equal(hist_ary.sort, b.sem_hist.to_a.sort, "incorrect causal history")
  end

  def test_empty_doc
    s = SimpleNmLinear.new
    s.tick
    check_linear_order(s)
    check_sem_hist(s)
    assert_equal([[END_ID, BEGIN_ID]].to_set, s.explicit.to_set)
    assert_equal([], s.use_implied_anc.to_a)
    assert_equal([], s.use_tiebreak.to_a)
  end

  def test_explicit
    s = SimpleNmLinear.new
    s.input_buf <+ [[9, BEGIN_ID, END_ID],
                    [2, 9, END_ID],
                    [1, 9, 2]]
    s.tick
    check_linear_order(s, 9, 1, 2)
    check_sem_hist(s, 9 => [], 2 => [9], 1 => [2, 9])
  end

  def test_tiebreak
    s = SimpleNmLinear.new
    s.input_buf <+ [[1, BEGIN_ID, END_ID],
                    [2, BEGIN_ID, END_ID]]
    s.tick

    check_linear_order(s, 1, 2)
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

    # Second iteration should be a no-op
    2.times do
      s.tick
      check_linear_order(s, 3, 1, 2)
      check_sem_hist(s, 1 => [], 2 => [], 3 => [1])
      assert_equal([[2, 3]], s.use_implied_anc.to_a.sort)
    end
  end

  def test_implied_anc_pre
    s = SimpleNmLinear.new
    s.input_buf <+ [[2, BEGIN_ID, END_ID],
                    [3, BEGIN_ID, END_ID],
                    [1, 3, END_ID]]

    # Second iteration should be a no-op
    2.times do
      s.tick
      check_linear_order(s, 2, 3, 1)
      check_sem_hist(s, 2 => [], 3 => [], 1 => [3])
    end
  end

  # Similar to the above scenario, but slightly more complicated: there are two
  # concurrent edits 3,4 that depend on 2 and 1, respectively.
  def test_implied_anc_concurrent
    s = SimpleNmLinear.new
    s.input_buf <+ [[1, BEGIN_ID, END_ID],
                    [2, BEGIN_ID, END_ID],
                    [4, BEGIN_ID, 1],
                    [3, BEGIN_ID, 2]]
    s.tick

    check_linear_order(s, 4, 1, 3, 2)
    check_sem_hist(s, 1 => [], 2 => [], 3 => [2], 4 => [1])
  end

  def test_implied_anc_concurrent_split_up1
    s = SimpleNmLinear.new
    s.input_buf <+ [[1, BEGIN_ID, END_ID],
                    [2, BEGIN_ID, END_ID],
                    [4, BEGIN_ID, 1]]
    s.tick

    check_linear_order(s, 4, 1, 2)
    check_sem_hist(s, 1 => [], 2 => [], 4 => [1])

    s.input_buf <+ [[3, BEGIN_ID, 2]]
    s.tick

    check_linear_order(s, 4, 1, 3, 2)
    check_sem_hist(s, 1 => [], 2 => [], 3 => [2], 4 => [1])
  end

  def test_implied_anc_concurrent_split_up2
    s = SimpleNmLinear.new
    s.input_buf <+ [[1, BEGIN_ID, END_ID],
                    [2, BEGIN_ID, END_ID],
                    [3, BEGIN_ID, 2]]
    s.tick

    check_linear_order(s, 1, 3, 2)
    check_sem_hist(s, 1 => [], 2 => [], 3 => [2])

    s.input_buf <+ [[4, BEGIN_ID, 1]]
    s.tick

    check_sem_hist(s, 1 => [], 2 => [], 3 => [2], 4 => [1])
    check_linear_order(s, 4, 1, 3, 2)
  end

  def test_implied_anc_concurrent_2
    s = SimpleNmLinear.new
    s.input_buf <+ [[8, BEGIN_ID, END_ID],
                    [9, BEGIN_ID, END_ID],
                    [2, 8, END_ID],
                    [1, 9, END_ID]]
    s.tick

    check_sem_hist(s, 8 => [], 9 => [], 2 => [8], 1 => [9])
    check_linear_order(s, 8, 2, 9, 1)
  end

  def test_implied_anc_concurrent_3
    s = SimpleNmLinear.new
    s.input_buf <+ [[1, BEGIN_ID, END_ID],
                    [2, BEGIN_ID, END_ID],
                    [4, BEGIN_ID, 1],
                    [0, BEGIN_ID, 2]]
    s.tick

    check_linear_order(s, 0, 4, 1, 2)
    check_sem_hist(s, 1 => [], 2 => [], 0 => [2], 4 => [1])
  end

  def test_deep_right_branch_concurrent_edit_near_root
  end

  def test_merge_concurrent_branches
    # A scenario in which an edit depends on two previous edits that are
    # concurrent with one another.
    s = SimpleNmLinear.new
    s.input_buf <+ [[1, BEGIN_ID, END_ID],
                    [2, BEGIN_ID, END_ID],
                    [3, 1, END_ID],
                    [4, 2, END_ID]]
    s.tick

    check_linear_order(s, 1, 2, 3, 4)
    check_sem_hist(s, 1 => [], 2 => [], 3 => [1], 4 => [2])

    s.input_buf <+ [[5, 3, 4]]
    s.tick

    check_linear_order(s, 1, 2, 3, 5, 4)
    check_sem_hist(s, 1 => [], 2 => [], 3 => [1], 4 => [2], 5 => [1,2,3,4])
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
    s = SimpleNmLinear.new
    s.input_buf <+ doc.shuffle
    s.tick

    doc_order = doc.map {|d| d.first}
    check_linear_order(s, *doc_order)
    check_sem_hist(s,
                   10 => [], 11 => [10], 12 => [10, 11], 13 => [10, 11, 12],
                   14 => [10,11,12], 15 => [10,11,12,13,14], 30 => [],
                   31 => [30], 99 => [30, 31, 40], 40 => [], 41 => [40])
  end

  DOC_SIZE = 22
  def test_big_explicit
    doc = []
    prev = BEGIN_ID
    DOC_SIZE.times do |i|
      curr = stable_hash(i)
      doc << [curr, prev, END_ID]
      prev = curr
    end
    s = SimpleNmLinear.new
    s.input_buf <+ doc
    s.tick

    doc_order = doc.map {|d| d.first}
    check_linear_order(s, *doc_order)

    sem_hist = {}
    doc.each_with_index do |d,i|
      sem_hist[d[0]] = []
      i.times {|j| sem_hist[d[0]] << doc[j][0]}
    end
    check_sem_hist(s, sem_hist)
  end

  def stable_hash(v)
    Digest::MD5.digest(v.to_s).unpack("L_").first
  end
end
