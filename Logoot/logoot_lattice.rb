require 'rubygems'
require 'bud'
require './lfixed'
require 'pp'

TEXT_FLAG = [-1,-1,-1]

def createDocLattice(line_id, text)
  for t in line_id.reverse
    if t == TEXT_FLAG
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
    if sortedKeys.include?(TEXT_FLAG)
      rtn = [seen]
    else
      rtn = []
    end
    for key in sortedKeys
      if key == TEXT_FLAG
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
    return [[rand(100), site_id, Time.now.sec], TEXT_FLAG]
  else
    line_id.pop
    newID = line_id.concat([[rand(100), site_id, Time.now.sec]])
    newID = newID.concat([TEXT_FLAG]) 
    puts "new id"
    pp newID
    return newID
  end
end

class PrettyPrinter
  def printDocument(lmap)
    sortedKeys = lmap.reveal.keys.sort
    for key in sortedKeys
      if key == TEXT_FLAG
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



