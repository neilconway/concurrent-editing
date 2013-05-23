require './test_common'
require '../wooth'

class NmSimpleTest < MiniTest::Unit::TestCase
  def test_explicit
    doc = WootHashDocument.new(1)
    ops = [[9, IB, IE],
                    [2, 9, IE],
                    [1, 9, 2]]
    doc.localInsert(ops)
    ids = doc.buildDoc 
    assert_equal([9,1,2], ids)
  end

  def test_tiebreak
    doc = WootHashDocument.new(1)
    ops = [[1, IB, IE],
                    [2, IB, IE]]
    doc.localInsert(ops)
    ids = doc.buildDoc 
    assert_equal([1,2], ids)
  end

  def test_implied_anc
    doc = WootHashDocument.new(1)
    ops = [[1, IB, IE],
                    [2, IB, IE],
                    [3, IB, 1]]
    doc.localInsert(ops)
    ids = doc.buildDoc 
    assert_equal([3,1,2], ids)
  end

  def test_implied_anc_pre
    doc = WootHashDocument.new(1)
    ops = [[2, IB, IE],
                    [3, IB, IE],
                    [1, 3, IE]]
    doc.localInsert(ops)
    ids = doc.buildDoc 
    assert_equal([2,3,1], ids)
  end

  def test_implied_anc_concurrent
    doc = WootHashDocument.new(1)
    ops = [[1, IB, IE],
                    [2, IB, IE],
                    [3, IB, 2],
                    [4, IB, 1]]
    doc.localInsert(ops)
    ids = doc.buildDoc 
    assert_equal([4, 1, 3, 2], ids)
  end

  def test_doc_tree
    doc = WootHashDocument.new(1)
    ops = [[10, IB, IE],
           [11, 10, IE],
           [12, 11, IE],
           [13, 12, IE],
           [15, 13, 14],
           [14, 12, IE],
           [30, IB, IE],
           [31, 30, IE],
           [99, 31, 40],
           [40, IB, IE],
           [41, 40, IE]]
    doc.localInsert(ops)
    ids = doc.buildDoc
    assert_equal([10, 11, 12, 13, 15, 14, 30, 31, 99, 40, 41], ids) 
  end

  def test_delete
    doc = WootHashDocument.new(1)
    ops = [[10, IB, IE],
           [11, 10, IE],
           [12, 11, IE],
           [13, 12, IE],
           [15, 13, 14],
           [14, 12, IE],
           [30, IB, IE],
           [31, 30, IE],
           [99, 31, 40],
           [40, IB, IE],
           [41, 40, IE]]
    doc.localInsert(ops)
    ids = doc.buildDoc
    assert_equal([10, 11, 12, 13, 15, 14, 30, 31, 99, 40, 41], ids) 
    del = WootHashOp.new(15, nil, nil, 'del')
    doc.apply(del)
    assert_equal([10, 11, 12, 13, 14, 30, 31, 99, 40, 41], doc.buildDoc) 
  end 

  def test_buffer
    doc = WootHashDocument.new(1)
    ops = [[0, IB, IE], [1, 0, IE], [2, 1, IE], [3, 2, IE], [4, 3, IE], [5, 4, IE], [6, 5, IE], [7, 6, IE], [8, 7, IE], [9, 8, IE], [10, 9, IE], [11, 10, IE], [12, 11, IE], [13, 12, IE], [14, 13, IE], [15, 14, IE], [16, 15, IE], [17, 16, IE], [18, 17, IE], [19, 18, IE], [20, 19, IE], [21, 20, IE], [22, 21, IE], [23, 22, IE], [24, 23, IE], [25, 24, IE], [0.1, 0, 1], [0.7, 0, 0.1], [0.2, 0, 1], [0.3, 0, 1], [1.1, 1, 2], [1.7, 1, 1.1], [1.2, 1, 2], [1.3, 1, 2], [2.1, 2, 3], [2.7, 2, 2.1], [2.2, 2, 3], [2.3, 2, 3], [3.1, 3, 4], [3.7, 3, 3.1], [3.2, 3, 4], [3.3, 3, 4]]
    doc.localInsert(ops)
    ids = doc.buildDoc
  end
end


