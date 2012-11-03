require './test_common'
require 'lfixed'

class SimpleLfixed
  include Bud
  
  state do 
    lfixed :m1
    lfixed :m2
    lfixed :holder1
    lfixed :holder2
  end
  
  bloom do
    holder1 <= m1
    holder2 <= m2
  end
end


class TestLFixed < Test::Unit::TestCase
  def test_basic
    i = SimpleLfixed.new
    line1 = "Concurrent editing is awesome"
    line2 = "i <3 Logoot"
    i.m1 <+ FixedLattice.new(line1)
    i.m2 <+ FixedLattice.new(line2)
    i.tick
    
    assert_equal(line1, i.holder1.current_value.reveal)
    assert_equal(line2, i.holder2.current_value.reveal)
    i.tick
    
    assert_equal(line1, i.holder1.current_value.reveal)
    assert_equal(line2, i.holder2.current_value.reveal)
    
    i.m1 <+ FixedLattice.new("this should not change")
    
    assert_raise(Bud::Error) do
      i.tick
    end
  end
  
  def test_delete
    i = SimpleLfixed.new
    line1 = "Concurrent editing is awesome"
    line2 = "i <3 Logoot"
    i.m1 <+ FixedLattice.new(line1)
    i.m2 <+ FixedLattice.new(line2)
    i.tick
    
    assert_equal(line1, i.holder1.current_value.reveal)
    assert_equal(line2, i.holder2.current_value.reveal)
    i.tick
    
    i.m1 <+ FixedLattice.new(-1)
    i.tick
    assert_equal(-1, i.holder1.current_value.reveal)
    assert_equal(line2, i.holder2.current_value.reveal)
    
  end
  
end
