require_relative 'test_common'
require_relative '../nm_simple'

class NmSimpleTest < MiniTest::Unit::TestCase
  def test_sem_hist
    s = SimpleNmLinear.new
    s.tick
    assert_equal([[BEGIN_ID, BEGIN_ID],
                  [END_ID, BEGIN_ID],
                  [END_ID, END_ID],
                  [BEGIN_ID, END_ID]].sort, s.sem_hist.to_a.sort)
  end
end
