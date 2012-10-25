require 'rubygems'
require 'bud'

class FixedLattice < Bud::Lattice
  wrapper_name :lfixed
  
  def initialize(i=nil)
    @v = i
    @deleteFlag = -1
  end
  
  def merge(i)
    i_val = i.reveal
    if i_val == @deleteFlag or @v == @deleteFlag
      return FixedLattice.new(@deleteFlag)
    end
    return self if i_val.nil?
    if i_val != @v and @v != nil
      raise Bud::Error, "Cannot change fixed lattice. input = #{i.inspect}"
    end
    return FixedLattice.new(i_val)
  end
end


