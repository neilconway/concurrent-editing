require_relative 'test_common'
require_relative '../list_append'

class ListAppendTest < MiniTest::Unit::TestCase
  def test_safe_tc
    s = ListAppend.new
    s.explicit <+ [["a", LIST_START_ID], ["b", "a"], ["c", "a"], ["d", "c"], ["f", "e"]]
    s.tick

    assert_equal([["a", LIST_START_ID], ["b", "a"], ["c", "a"],
                  ["d", "c"], LIST_START_TUPLE].to_set, s.safe.to_set)
    assert_equal([["a", LIST_START_ID], ["b", "a"], ["b", LIST_START_ID],
                  ["c", "a"], ["c", LIST_START_ID],
                  ["d", "c"], ["d", "a"], ["d", LIST_START_ID],
                  LIST_START_TUPLE].to_set, s.safe_tc.to_set)
  end

  def test_use_ancestor_1
    s = ListAppend.new
    # We have Z -> X explicitly. Hypothetical tiebreaks are Y -> Z and X ->
    # Y. However, we should follow causal order when using tiebreaks, which
    # means we should first apply Y -> Z, which implies Y -> X; the latter order
    # should be preferred over the X -> Y tiebreak.
    s.explicit <+ [["z", LIST_START_ID], ["x", "z"], ["y", LIST_START_ID]]
    s.tick

    puts s.tiebreak.to_a.sort.inspect
  end
end
