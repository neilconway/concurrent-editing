require 'rubygems'
require 'bud'
require './lfixed'
require 'pp'

class RecursiveLmap
  
  attr_reader :line_id
  attr_reader :text
  attr_accessor :lmap
  
  def initialize(line_id, text)
    @line_id = line_id
    @text = text
  end
  
  def create
    for t in line_id.reverse
      if t == [-1,-1,-1]
        rlmap = Bud::MapLattice.new(t => FixedLattice.new(@text))
      else
        rlmap = Bud::MapLattice.new(t => rlmap)
      end
    end
    return rlmap
  end

end


class PrettyPrinter

  attr_accessor :path
  
  def initialize
    @path = []
  end
  
  def printDocument(lmap)
    sortedKeys = lmap.reveal.keys.sort
    for key in sortedKeys
      if key == [-1,-1,-1]
        if lmap.reveal.values_at(key)[0].reveal != -1
          p lmap.reveal.values_at(key)[0].reveal
        end
        next
      end
      nextLmap = lmap.reveal[key]
      self.printDocument(nextLmap)
    end
  end


  def getNewID(line_id, site_id)
    if line_id == false
      return [[rand(100), site_id, Time.now.sec], [-1,-1, -1]]
    else
      line_id.pop
      newID = line_id.concat([[rand(100), site_id, Time.now.sec]])
      newID = newID.concat([[-1,-1,-1]]) 
      puts "new id"
      pp newID
      return newID
    end
  end

end


