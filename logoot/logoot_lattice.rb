require 'rubygems'
require 'backports'
require 'bud'
require 'pp'
require_relative 'lfixed'

TEXT_FLAG = [-1,-1,-1]
MAX_INT = 100

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


def constructId(line_id1, line_id2, site_id)
  if line_id1 == false and line_id2 == false
    return [[rand(MAX_INT), site_id, Time.now.sec + Time.now.min], TEXT_FLAG]
  elsif line_id1 == line_id2
    randomNum = (1..line_id1[0][0] - 1).to_a.sample
    return [[randomNum, site_id, Time.now.sec + Time.now.min], TEXT_FLAG]
  elsif line_id1 == false
    constructId([0,0,0], line_id2, site_id)
  elsif line_id2 == false
    constructId(line_id1, [MAX_INT, MAX_INT, MAX_INT], site_id)
  elsif line_id2[0][0] - line_id1[0][0] > 1
    randomNum = (line_id1[0][0] + 1 .. line_id2[0][0] - 1).to_a.sample
    return [[randomNum, site_id, Time.now.sec + Time.now.min], TEXT_FLAG]
  else
    line_id1.pop
    return line_id1.concat([[rand(MAX_INT), site_id, Time.now.sec + Time.now.min], TEXT_FLAG])
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
