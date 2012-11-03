require 'rubygems'
require 'backports'
require 'bud'
require 'pp'
require_relative 'lfixed'

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
  return helper(lmap, [])
end


#TODO: Make newID generation come up with most efficient line_id
#TODO: fix hackiness in generateNewId
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

def generateNewId(line_id1, line_id2, site_id)
  if line_id1 == false or line_id2 == false
    return getNewID(line_id1, site_id)
  end
  size1 = line_id1.size
  size2 = line_id2.size
  if size1 == size2 or size1 > size2 or line_id2 == false
    return getNewID(line_id1, site_id)
  else
    line_id1.pop
    line_id2.pop
    for i in (0..size1)
      if line_id1[i] != line_id2[i]
        randomNum = (0 .. line_id2[i][0]).to_a.sample
        if randomNum == line_id2[i][0]
          modified_time = (0 .. line_id2[i][2]).to_a.sample
          newId = line_id1[0..i].concat([[randomNum, site_id, modified_time]])
          newId.concat([TEXT_FLAG])
          return newId
        end
        newId = line_id1[0..i].concat([[randomNum, site_id, Time.now.sec]])
        newId.concat([TEXT_FLAG])
        return newId
      end
    end
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
