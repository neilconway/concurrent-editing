require "rubygems"
require "bud"

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
end
