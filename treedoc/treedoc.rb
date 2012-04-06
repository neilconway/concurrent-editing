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
end

class TreedocL < Bud::Lattice
  wrapper_name :tdoc

  def initialize
    @v = []
  end

  # XXX: monotone or morphism?
  monotone :insert do |pos,atom|
  end

  # XXX: monotone or morphism?
  monotone :delete do |pos|
  end

  def contents
  end
end
