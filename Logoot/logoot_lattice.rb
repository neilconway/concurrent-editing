require 'rubygems'
require 'bud'
require './lfixed'
require 'pp'

def createDocLattice(line_id, text)
  for t in line_id.reverse
    if t == [-1,-1,-1]
      rlmap = Bud::MapLattice.new(t => FixedLattice.new(text))
    else
      rlmap = Bud::MapLattice.new(t => rlmap)
    end
  end
  return rlmap
end

def getPaths(lmap)
  def helper (lmap, seen)
    sortedKeys = lmap.reveal.keys.sort
    if sortedKeys.include?([-1,-1,-1])
      rtn = [seen]
    else
      rtn = []
    end
    for key in sortedKeys
      if key == [-1,-1,-1]
        next
      end
      seen2 = seen.clone
      seen2 << key
      for x in helper(lmap.reveal[key], seen2)
        rtn << x
      end
    end
    return rtn
  end
  return helper(lmap, [])
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

class PrettyPrinter
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
end



