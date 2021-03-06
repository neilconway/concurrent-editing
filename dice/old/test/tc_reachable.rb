require_relative 'test_common'
require_relative '../reachable'

class ReachableTest < MiniTest::Unit::TestCase
  def test_rset_basic
    r = Reachable.new
    r.constraints <+ [["1", BEGIN_ID, END_ID],
                      ["2", BEGIN_ID, END_ID],
                      ["3", BEGIN_ID, "1"],
                      ["4", "3", "1"]]
    r.tick

    expected = {
      "1" => [BEGIN_ID, END_ID],
      "2" => [BEGIN_ID, END_ID],
      "3" => [BEGIN_ID, END_ID, "1"],
      "4" => [BEGIN_ID, END_ID, "3", "1"],
      BEGIN_ID => [END_ID],
      END_ID => [BEGIN_ID]
    }
    rv = r.reach_set.current_value.reveal
    rset = rv.happly(:reveal)
    expected = expected.happly(:to_set)
    assert_equal(expected, rset)
    check_invariants(r)
  end

  def test_rset_proper_tc
    r = Reachable.new
    r.constraints <+ [["x", BEGIN_ID, "y"],
                      ["z", "x", END_ID],
                      ["y", BEGIN_ID, END_ID]]
    r.tick
    expected = {
      "y" => [BEGIN_ID, END_ID],
      "x" => [BEGIN_ID, END_ID, "y"],
      "z" => [BEGIN_ID, END_ID, "x", "y"],
      BEGIN_ID => [END_ID],
      END_ID => [BEGIN_ID]
    }
    rv = r.reach_set.current_value.reveal
    rset = rv.happly(:reveal)
    expected = expected.happly(:to_set)
    assert_equal(expected, rset)
    check_invariants(r)
  end

  def test_bad_pre
    r = Reachable.new
    r.constraints <+ [["1", BEGIN_ID, END_ID],
                      ["2", BEGIN_ID, END_ID],
                      ["3", "4", END_ID]]
    r.tick
    assert_equal([["3", "4", END_ID]], r.bad_pre.to_a)
    check_invariants(r, :bad_pre)
  end

  def test_bad_post
    r = Reachable.new
    r.constraints <+ [["1", BEGIN_ID, END_ID],
                      ["2", BEGIN_ID, END_ID],
                      ["3", BEGIN_ID, "4"]]
    r.tick
    assert_equal([["3", BEGIN_ID, "4"]], r.bad_post.to_a)
    check_invariants(r, :bad_post)
  end

  def test_before_start
    r = Reachable.new
    r.constraints <+ [["1", END_ID, BEGIN_ID]]
    r.tick
    assert_equal([["1"], [END_ID], [BEGIN_ID]].sort, r.cycle.to_a.sort)
    check_invariants(r, :cycle)
  end

  def test_simple_cycle
    r = Reachable.new
    r.constraints <+ [["1", BEGIN_ID, END_ID],
                      ["2", "1", END_ID],
                      ["3", "2", "1"]]
    r.tick
    assert_equal([["1"], ["2"], ["3"]], r.cycle.to_a.sort)
    check_invariants(r, :cycle)
  end

  def test_indirect_cycle
    r = Reachable.new
    r.constraints <+ [["1", BEGIN_ID, END_ID],
                      ["2", "1", END_ID],
                      ["3", "2", END_ID],
                      ["4", "3", END_ID],
                      ["5", "4", "1"]]
    r.tick
    assert_equal([["1"], ["2"], ["3"], ["4"], ["5"]], r.cycle.to_a.sort)
    check_invariants(r, :cycle)
  end

  def test_disconnected_cycle
    r = Reachable.new
    r.constraints <+ [["1", BEGIN_ID, END_ID],
                      ["2", "3", "4"],
                      ["3", "4", "2"],
                      ["4", "2", "3"]]
    r.tick
    assert_equal([["2"], ["3"], ["4"]], r.cycle.to_a.sort)
    check_invariants(r, :cycle)
  end

  def test_self_cycle
    r = Reachable.new
    r.constraints <+ [["1", "1", END_ID]]
    r.tick
    assert_equal([["1"]], r.cycle.to_a)
    check_invariants(r, :cycle)
  end

  def check_invariants(r, *skip)
    to_check = [:bad_pre, :bad_post, :cycle] - skip

    to_check.each do |t|
      assert_equal([], r.send(t).to_a, "expected '#{t}' to be empty")
    end
  end

  # A simple linearization example: only one linearization is consistent with
  # (and hence implied by) the user's constraints.
  def test_basic_order
    r = Reachable.new
    r.constraints <+ [["1", BEGIN_ID, END_ID],
                      ["2", "1", END_ID],
                      ["3", "2", END_ID]]
    r.tick
    assert_equal([[BEGIN_ID, "1"],
                  [BEGIN_ID, "2"],
                  [BEGIN_ID, "3"],
                  [BEGIN_ID, END_ID],
                  ["1", "2"],
                  ["1", "3"],
                  ["1", END_ID],
                  ["2", "3"],
                  ["2", END_ID],
                  ["3", END_ID]].sort, r.orders.to_a.sort)
    check_invariants(r)
  end

  # First ambiguous case. Both [1,2] and [2,1] would be consistent with the
  # user's constraints, so we need to pick a winner. For this simple scenario,
  # breaking ties using the minimum atom ID is sufficient.
  def test_order_ambig1
    r = Reachable.new
    r.constraints <+ [["1", BEGIN_ID, END_ID],
                      ["2", BEGIN_ID, END_ID]]
    r.tick
    assert_equal([[BEGIN_ID, "1"],
                  [BEGIN_ID, "2"],
                  [BEGIN_ID, END_ID],
                  ["1", "2"],
                  ["1", END_ID],
                  ["2", END_ID]].sort, r.orders.to_a.sort)
    check_invariants(r)
  end
end
