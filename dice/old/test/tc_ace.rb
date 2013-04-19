require_relative 'test_common'
require_relative '../ace'

class AceTest < MiniTest::Unit::TestCase
  def test_basic_insert
    r = AceReplica.new
    r.insert_op('foo', AceReplica::START_DOC, AceReplica::END_DOC)
    r.tick
  end

  def test_invalid_pre
    r = AceReplica.new
    r.insert_op('foo', 555, AceReplica::END_DOC)
    assert_raises(BadInvariantError) { r.tick }
  end

  def test_invalid_post
    r = AceReplica.new
    r.insert_op('foo', AceReplica::START_DOC, 555)
    assert_raises(BadInvariantError) { r.tick }
  end

  def test_pre_after_post
  end

  def test_cyclic_pre
  end

  def test_cyclic_post
  end

  def test_connected_doc
  end
end
