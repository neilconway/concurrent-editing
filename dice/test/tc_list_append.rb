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
end
