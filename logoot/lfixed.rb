require 'rubygems'
require 'bud'

class FixedLattice < Bud::Lattice
  wrapper_name :lfixed

  DELETE_FLAG = -1
  
  def initialize(i=nil)
    @v = i
  end
  
  def merge(i)
    i_val = i.reveal
    if i_val == DELETE_FLAG or @v == DELETE_FLAG
      return FixedLattice.new(DELETE_FLAG)
    end
    return self if i_val.nil?
    if i_val != @v and @v != nil
      raise Bud::Error, "Cannot change fixed lattice. input = #{i.inspect}"
    end
    return FixedLattice.new(i_val)
  end
end


