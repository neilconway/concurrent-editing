require './test_common'
require 'rubygems'
require 'bud'
require './logoot_lattice'
require "set"
require './lfixed'



class TestRLmap < Test::Unit::TestCase
  def testMakeRecursiveLmap
    t1 = [1,1,1]
    t2 = [2,2,2]
    t3 = [3,3,3]
    textFlag = [-1,-1,-1]
    line_id = [t1, t2, t3, textFlag]
    text = "hello world"
    rlm = RecursiveLmap.new(line_id, text)
    m = rlm.create()
    assert_equal(m.key?(t1).reveal, true)
    assert_equal(m.key?(t2).reveal, false)
    secondLevel = m.at(t1)
    assert_equal(secondLevel.key?(t2).reveal, true)
    thirdLevel = secondLevel.at(t2)
    assert_equal(thirdLevel.key?(t3).reveal, true)
  end
  
  def test_basic
    t1 = [1,1,1]
    text_flag = [-1,-1,-1]
    line_id = [t1, text_flag]
    text = "I love concurrent editing"
    rlm = RecursiveLmap.new(line_id, text)
    m = rlm.create()
    assert_equal(m.key?(t1).reveal, true)
    
    #pp = PrettyPrinter.new()
    #pp.printDocument(m)
  end
  
  def test_print
    t1 = [1,1,1]
    t2 = [2,2,2]
    t3 = [3,3,3]
    t4 = [3,4,4]
    text_flag = [-1,-1,-1]
    line_id1 = [t1, text_flag]
    line_id2 = [t2, text_flag]
    line_id3 = [t1, t3, text_flag]
    line_id4 = [t1, t4, text_flag]
    text1 = "first line"
    text2 = "fourth line"
    text3 = "second line"
    text4 = "third line"
    rlm = RecursiveLmap.new(line_id1, text1)
    m = rlm.create()
    #m.reveal.printDocument()
    m = m.merge(RecursiveLmap.new(line_id2, text2).create())
    m = m.merge(RecursiveLmap.new(line_id3, text3).create())
    m = m.merge(RecursiveLmap.new(line_id4, text4).create())
    
    pp = PrettyPrinter.new()
    pp.printDocument(m)

  end  

end

class SimpleLmap
  include Bud
  
  state do 
    lmap :m1
    lmap :m2
    lmap :m3
  end
  
  bloom do
    m1 <= m2
    m1 <= m3
  end
end


class TestLogootLattice <Test::Unit::TestCase
  def test1
    i = SimpleLmap.new
    t1 = [1,1,1]
    t2 = [2,2,2]
    text_flag = [-1,-1,-1]
    line_id1 = [t1, text_flag]
    line_id2 = [t2, text_flag]
    text1 = "foo"
    text2 = "bar"
    
    rlm1 = RecursiveLmap.new(line_id1, text1)
    r1 = rlm1.create()
    i.m3 <+ r1
    rlm2 = RecursiveLmap.new(line_id2, text2)
    r2 = rlm2.create()
    i.m2 <+ r2
    i.tick
    
    assert_equal(i.m1.current_value.key?(t1).reveal, true)
    assert_equal(i.m1.current_value.key?(t2).reveal, true)
    
    t3 = [3,4,5]
    line_id3 = [t1, t3, text_flag]
    text3 = "baz"
    
    rlm3 = RecursiveLmap.new(line_id3, text3)
    i.m3 <+ rlm3.create()
    i.tick
    
    assert_equal(i.m1.current_value.key?(t1).reveal, true)
    assert_equal(i.m1.current_value.key?(t2).reveal, true)
    assert_equal(i.m1.current_value.key?(t3).reveal, false)
    
    secondLevel = i.m1.current_value.at(t1)
    assert_equal(secondLevel.key?(t3).reveal, true)
    
    #pp = PrettyPrinter.new()
    #pp.printDocument(i.m1.current_value)
  end
  
  def test_concurrent_inserts
    i = SimpleLmap.new
    t1 = [1,1,1]
    t2 = [2,2,2]
    text_flag = [-1,-1,-1]
    line_id1 = [t1, text_flag]
    line_id2 = [t2, text_flag]
    text1 = "foo"
    text2 = "bar"
    
    rlm1 = RecursiveLmap.new(line_id1, text1)
    r1 = rlm1.create()
    i.m3 <+ r1
    rlm2 = RecursiveLmap.new(line_id2, text2)
    r2 = rlm2.create()
    i.m2 <+ r2
    i.tick
    
    # At this point we have the document:
    # foo
    # bar
    # We will now try to concurrently insert
    # something between foo and bar at 2 different
    # replicas.
    
    t3 = [3, 4, 1]
    t4 = [3, 5, 1]
    line_id3 = [t1, t3, text_flag]
    line_id4 = [t1, t4, text_flag]
    text3 = "baz"
    text4 = "buzz"
    
    rlm3 = RecursiveLmap.new(line_id3, text3).create()
    rlm4 = RecursiveLmap.new(line_id4, text4).create()
    i.m2 <+ rlm3
    i.m2 <+ rlm4
    i.tick
    
    assert_equal(i.m1.current_value.key?(t1).reveal, true)
    assert_equal(i.m1.current_value.key?(t2).reveal, true)
    assert_equal(i.m1.current_value.key?(t3).reveal, false)
    assert_equal(i.m1.current_value.key?(t4).reveal, false)
    
    secondLevel = i.m1.current_value.at(t1)
    
    assert_equal(secondLevel.key?(t3).reveal, true)
    assert_equal(secondLevel.key?(t4).reveal, true)
    
    #pp = PrettyPrinter.new()
    #pp.printDocument(i.m1.current_value)
    
  end



  
  def test_sequential_inserts
    i = SimpleLmap.new
    t1 = [1,1,1]
    t2 = [2,2,2]
    text_flag = [-1,-1,-1]
    line_id1 = [t1, text_flag]
    line_id2 = [t2, text_flag]
    text1 = "foo"
    text2 = "bar"
    
    rlm1 = RecursiveLmap.new(line_id1, text1)
    r1 = rlm1.create()
    i.m3 <+ r1
    rlm2 = RecursiveLmap.new(line_id2, text2)
    r2 = rlm2.create()
    i.m2 <+ r2
    i.tick
    
    t3 = [3, 4, 1]
    t4 = [3, 5, 2]
    line_id3 = [t1, t3, text_flag]
    line_id4 = [t1, t4, text_flag]
    text3 = "baz"
    text4 = "buzz"
    
    rlm3 = RecursiveLmap.new(line_id3, text3).create()
    rlm4 = RecursiveLmap.new(line_id4, text4).create()
    i.m2 <+ rlm3
    i.tick
    i.m2 <+ rlm4
    i.tick
    
    assert_equal(i.m1.current_value.key?(t1).reveal, true)
    assert_equal(i.m1.current_value.key?(t2).reveal, true)
    assert_equal(i.m1.current_value.key?(t3).reveal, false)
    assert_equal(i.m1.current_value.key?(t4).reveal, false)
    
    secondLevel = i.m1.current_value.at(t1)
    
    assert_equal(secondLevel.key?(t3).reveal, true)
    assert_equal(secondLevel.key?(t4).reveal, true)
    
    #pp = PrettyPrinter.new()
    #pp.printDocument(i.m1.current_value)
    
  end

  def test_basic_delete
    i = SimpleLmap.new
    t1 = [1,1,1]
    text_flag = [-1,-1,-1]
    line_id1 = [t1, text_flag]
    text1 = ":D"
    lattice = RecursiveLmap.new(line_id1, text1).create
    i.m2 <+ lattice
    i.tick

    assert_equal(i.m1.current_value.at(t1).at(text_flag).reveal, ":D")

    delete = RecursiveLmap.new(line_id1, -1).create
    i.m2 <+ delete
    i.tick
    
    assert_equal(i.m1.current_value.at(t1).at(text_flag).reveal, -1)

  end

  def test_delete
    i = SimpleLmap.new
    t1 = [1,1,1]
    t2 = [2,2,2]
    text_flag = [-1,-1,-1]
    line_id1 = [t1, text_flag]
    line_id2 = [t2, text_flag]
    text1 = "foo"
    text2 = "bar"
    
    rlm1 = RecursiveLmap.new(line_id1, text1)
    r1 = rlm1.create()
    i.m3 <+ r1
    rlm2 = RecursiveLmap.new(line_id2, text2)
    r2 = rlm2.create()
    i.m2 <+ r2
    i.tick
        
    t3 = [3, 4, 1]
    t4 = [3, 5, 1]
    line_id3 = [t1, t3, text_flag]
    line_id4 = [t1, t4, text_flag]
    text3 = "baz"
    text4 = "buzz"
    
    rlm3 = RecursiveLmap.new(line_id3, text3).create()
    rlm4 = RecursiveLmap.new(line_id4, text4).create()
    i.m2 <+ rlm3
    i.m2 <+ rlm4
    i.tick
    
    assert_equal(i.m1.current_value.key?(t1).reveal, true)
    assert_equal(i.m1.current_value.key?(t2).reveal, true)
    assert_equal(i.m1.current_value.key?(t3).reveal, false)
    assert_equal(i.m1.current_value.key?(t4).reveal, false)
    
    secondLevel = i.m1.current_value.at(t1)
    
    assert_equal(secondLevel.key?(t3).reveal, true)
    assert_equal(secondLevel.key?(t4).reveal, true)

    #Will delete buzz

    rlmDelete = RecursiveLmap.new(line_id4, -1).create()
    
    i.m2 <+ rlmDelete
    i.tick

    assert_equal(i.m1.current_value.key?(t1).reveal, true)
    assert_equal(i.m1.current_value.key?(t2).reveal, true)
    assert_equal(i.m1.current_value.key?(t3).reveal, false)
    assert_equal(i.m1.current_value.key?(t4).reveal, false)
    
    secondLevel = i.m1.current_value.at(t1)
    
    assert_equal(secondLevel.key?(t3).reveal, true)
    assert_equal(secondLevel.key?(t4).reveal, true)

    thirdLevel = secondLevel.at(t4)

    assert_equal(thirdLevel.at(text_flag).reveal, -1)


  end

  def test_concurrent_deletes
    i = SimpleLmap.new
    t1 = [1,1,1]
    t2 = [2,2,2]
    text_flag = [-1,-1,-1]
    line_id1 = [t1, text_flag]
    line_id2 = [t2, text_flag]
    text1 = "foo"
    text2 = "bar"
    
    rlm1 = RecursiveLmap.new(line_id1, text1)
    r1 = rlm1.create()
    i.m3 <+ r1
    rlm2 = RecursiveLmap.new(line_id2, text2)
    r2 = rlm2.create()
    i.m2 <+ r2
    i.tick
    
    
    t3 = [3, 4, 1]
    t4 = [3, 5, 1]
    line_id3 = [t1, t3, text_flag]
    line_id4 = [t1, t4, text_flag]
    text3 = "baz"
    text4 = "buzz"
    
    rlm3 = RecursiveLmap.new(line_id3, text3).create()
    rlm4 = RecursiveLmap.new(line_id4, text4).create()
    i.m2 <+ rlm3
    i.m2 <+ rlm4
    i.tick
    
    
    deleter = RecursiveLmap.new(line_id3, -1).create
    i.m2 <+ deleter
    i.m3 <+ deleter
    i.tick
    
    pp = PrettyPrinter.new()
    pp.printDocument(i.m1.current_value)
  end
  
end











