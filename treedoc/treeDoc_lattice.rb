require 'rubygems'
require 'backports'
require 'bud'
require 'pp'
require_relative 'lfixed'

TEXT_FLAG = [1,1]

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
  def helper(lmap, seen)
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
  paths = helper(lmap, [])
  for x in paths
    x << TEXT_FLAG
  end
  return paths
end

def gen_id_after(line_id, site_id, time)
  if line_id == nil
    return [[site_id, time], TEXT_FLAG]
  end
  line_id.pop
  line_id << [111, 111]
  line_id << [site_id, time]
  line_id << TEXT_FLAG
  return line_id
end

def gen_id_before(line_id, site_id, time)
  if line_id == nil
    return [[site_id, time], TEXT_FLAG]
  end
  line_id.pop
  line_id << [0,0]
  line_id << [site_id, time]
  line_id << TEXT_FLAG
  return line_id
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

