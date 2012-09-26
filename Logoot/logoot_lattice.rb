require 'rubygems'
require 'bud'
require './lfixed'

class Triple
	include Comparable

	attr_writer :num
	attr_reader :num
	attr_writer :site_id
	attr_reader :site_id
	attr_writer :time_stamp
	attr_reader :time_stamp

	def initialize(n, s, t)
		@num = n
		@site_id = s
		@time_stamp = t
	end

	def <=> (other)
		if @num > other.num
			return 1
		elsif other.num > @num
			return -1
		
		elsif @site_id > other.site_id
			return 1
		elsif other.site_id > @site_id
			return -1
		
		elsif @time_stamp > other.time_stamp
			return 1
		elsif other.time_stamp > @time_stamp
			return -1
		else
			return 0
		end		
	end

end

class RecursiveLmap

  attr_reader :line_id
  attr_reader :text
  
  def initialize(line_id, text)
    @line_id = line_id
    @text = text
  end

  def create()
    base = Hash[Triple.new(-1,-1,-1) => FixedLattice.new(@text)]
    rlmap = Bud::MapLattice.new(base)
    for t in line_id.reverse
      rlmap = Bud::MapLattice.new(t => rlmap)
    end
    return rlmap
  end
end


class PrettyPrinter

  def initialize()
  end

  def printDocument(lmap)
    sortedKeys = lmap.reveal.keys.sort
    for key in sortedKeys
      if key == Triple.new(-1,-1,-1)
        p lmap.reveal.values_at(key)[0].reveal
        next
      end
      nextLmap = lmap.reveal[key]
      self.printDocument(nextLmap)
    end
  end
end


