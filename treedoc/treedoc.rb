require "rubygems"
require "bud"

class MiniNode
  include Enumerable
  
  attr_reader :left
  attr_reader :right
  attr_reader :dis
  attr_reader :atom
  
  def initialize(l, r, d, a)
    @left = l
    @right = r
    @dis = d
    @atom = a
  end
  
  def each(&blk)
    @left.each do |l|
      l.each(&blk)
    end
    blk.call(@atom)     # XXX: tombstones?
    @right.each do |r|
      r.each(&blk)
    end
  end
end

class TreeNode
  include Enumerable
  
  attr_reader :minis
  
  def initialize(m)
    @minis = m
  end
  
  
  # Invokes the block for each atom in the tree, doing an in-order traversal
  # according to the treedoc semantics.
  def each(&blk)
    minis.each do |m|
      m.each(&blk)
    end
  end
  

  # Finds treeNode at the end of specified path
  def find_tree_node(path)
    if path.first == nil
      return self
    elsif path.first == 1
      return self.minis[minis.length - 1].right[0].find_tree_node(path[1..path.length])
    elsif path.first == 0
      return self.minis[0].left[0].find_tree_node(path[1..path.length])
    end
  end
  
  # checks if TreeNode's left child is nil
  def check_empty_left()
    if self.minis[0].left[0] == nil
      return true
    else
      return false
    end
  end
  
  # checks if TreeNode's right child is nil
  def check_empty_right()
    if self.minis[minis.length - 1].right[0] == nil
      return true
    else
      return false
    end
  end
  
  # Used when direct child of reference node is not nil.  Helps find spot in tree
  # directly before reference node.
  def find_farthest_right()
    if self.minis[minis.length - 1].right[0] == nil
      return self
    else
      return self.minis[minis.length - 1].right[0].find_farthest_right()
    end
  end
  
  # Helps find spot in tree directly after reference node when right child is not nil
  def find_farthest_left()
    if self.minis[0].left[0] == nil
      return self
    else
      return self.minis[0].left[0].find_farthest_left()
    end
  end
  
  # XXX: Insertion methods do not deal with disambiguators yet
  
  def insert_before(path, atom)
    new_mini = MiniNode.new([],[], nil, atom)
    new_node = TreeNode.new([new_mini])
    referenceNode = self.find_tree_node(path)
    if referenceNode.check_empty_left()
      referenceNode.minis[0].left[0] = new_node
    else
      farthestRightNode = referenceNode.minis[0].left[0].find_farthest_right()
      farthestRightNode.minis[minis.length - 1].right[0] = new_node
    end
  end
  
  def insert_after(path, atom)
    new_mini = MiniNode.new([],[], nil, atom)
    new_node = TreeNode.new([new_mini])
    referenceNode = self.find_tree_node(path)
    if referenceNode.check_empty_right()
      referenceNode.minis[minis.length - 1].right[0] = new_node
    else
      farthestLeftNode = referenceNode.find_farthest_left()
      farthestLeftNode.minis[0].left[0] = new_node
    end
  end 
  
  
end   


class TreedocL < Bud::Lattice
  wrapper_name :tdoc
  
  def initialize
    @v = []
  end
  
  # XXX: monotone or morphism?
  monotone :insert_before do |pos,atom|   
  end
  
  monotone :insert_after do |pos,atom|
  end
  
  # XXX: monotone or morphism?
  monotone :delete do |pos|
  end
  
  def contents
  end
end
