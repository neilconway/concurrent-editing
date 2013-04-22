require 'rubygems'
require 'bud'

class SeqLattice < Bud::Lattice
  wrapper_name :lseq

  def initialize(i=[])
    reject_input(i) unless i.all?{|v| v.kind_of? Comparable}

    i = SortedSet.new(i) unless i.kind_of? SortedSet
    @v = i
  end

  def merge(i)
    wrap_unsafe(@v | i.reveal)
  end

  morph :elements do
    Bud::SetLattice.new(@v)
  end

  monotone :size do
    Bud::MaxLattice.new(@v.size)
  end
end
