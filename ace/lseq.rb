require 'rubygems'
require 'bud'

class SeqLattice < Bud::Lattice
  wrapper_name :lseq

  def initialize(i=[])
    reject_input(i) unless i.all?{|v| v.kind_of? Comparable}
    @v = i
  end

  # XXX: inefficient. Should merge in linear time instead.
  def merge(i)
    vals = @v | i.reveal
    vals.sort!
    wrap_unsafe(vals)
  end

  morph :elements do
    Bud::SetLattice.new(@v)
  end

  monotone :size do
    Bud::MaxLattice.new(@v.size)
  end
end
