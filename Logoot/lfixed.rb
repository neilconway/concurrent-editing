require 'rubygems'
require 'bud'

class FixedLattice < Bud::Lattice
  wrapper_name :lfixed

  def initialize(i=nil)
  	@v = i
  end

  def merge(i)
  	i_val = i.reveal
    return self if i_val.nil?
    return FixedLattice.new(i_val)
  end

end


