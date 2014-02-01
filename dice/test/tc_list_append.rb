require_relative 'test_common'
require_relative '../list_append'

class ListAppendTest < MiniTest::Unit::TestCase
  def make_list_append
    ListAppend.new
  end

  def check_linear_order(b, *vals)
    vals = [LIST_START_ID] + vals
    ary = []
    vals.each_with_index do |v,i|
      i.times do |j|
        ary << [vals[i], vals[j]]
      end
    end
    ary << LIST_START_TUPLE
    assert_equal(ary.sort, b.ord.to_a.sort)
  end

  def test_safe_tc
    s = make_list_append
    s.explicit <+ [["a", LIST_START_ID], ["b", "a"], ["c", "a"], ["d", "c"], ["f", "e"]]
    s.tick

    assert_equal([["a", LIST_START_ID], ["b", "a"], ["c", "a"], ["d", "c"],
                  LIST_START_TUPLE].to_set, s.safe.to_set)
    assert_equal([["a", LIST_START_ID], ["b", LIST_START_ID],
                  ["c", LIST_START_ID], ["d", LIST_START_ID],
                  ["b", "a"], ["c", "a"], ["d", "c"], ["d", "a"],
                  LIST_START_TUPLE].to_set, s.safe_tc.to_set)
  end

  def test_linear_chain
    s = make_list_append
    s.explicit <+ [["a", LIST_START_ID], ["b", "a"], ["c", "b"]]
    s.tick

    check_linear_order(s, "a", "b", "c")
  end

  def test_simple_tiebreak
    s = make_list_append
    s.explicit <+ [["a", LIST_START_ID], ["b", LIST_START_ID], ["c", LIST_START_ID]]
    s.tick

    check_linear_order(s, "a", "b", "c")
  end

  def test_use_ancestor_1
    s = make_list_append
    # We have Z -> X explicitly. Hypothetical tiebreaks are Y -> Z and X ->
    # Y. However, we should follow causal order when using tiebreaks, which
    # means we should first apply Y -> Z, which implies Y -> X; the latter order
    # should be preferred over the X -> Y tiebreak. Hence, resulting order
    # should be Y -> Z -> X.
    s.explicit <+ [["z", LIST_START_ID], ["x", "z"], ["y", LIST_START_ID]]
    s.tick

    check_linear_order(s, "y", "z", "x")
  end

  def test_key_conflict
  end
end
