require 'rubygems'
require 'backports'
require 'bud'
require 'pp'
require_relative 'lfixed'

TEXT_FLAG = [-1,-1,-1]
BEGIN_DOC = [[0,0,0], TEXT_FLAG]
END_DOC = [[101,101,101], TEXT_FLAG]
MAX_INT = 100

def createPartialLattice(line_id, text)
  for t in line_id.reverse
    if t == TEXT_FLAG
      rlmap = Bud::MapLattice.new(t => FixedLattice.new(text))
    else
      rlmap = Bud::MapLattice.new(t => rlmap)
    end
  end
  return rlmap
end

def createDocLattice(line_id, text)
  startDoc = createPartialLattice(BEGIN_DOC, "start")
  endDoc = createPartialLattice(END_DOC, "end")
  middle = createPartialLattice(line_id, text)
  doc = startDoc.merge(middle)
  doc = doc.merge(endDoc)
  return doc
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

# if before == true, then we are inserting before.  If false, inserting after
def constructId(line_id1, line_id2, site_id, before, time)
  if line_id1 == nil and line_id2 == nil
    return [[rand(MAX_INT), site_id, time], TEXT_FLAG]
  elsif line_id1 == line_id2 and before
    randomNum = (1..line_id1[0][0] - 1).to_a.sample
    return [[randomNum, site_id, time], TEXT_FLAG]
  elsif line_id1 == line_id2 and not before
    randomNum = (line_id1[0][0] + 1 .. MAX_INT).to_a.sample
    return [[randomNum, site_id, time], TEXT_FLAG]
  elsif line_id1 == nil
    constructId([0,0,0], line_id2, site_id, before)
  elsif line_id2 == nil
    constructId(line_id1, [MAX_INT, MAX_INT, MAX_INT], site_id)
  elsif line_id2[0][0] - line_id1[0][0] > 1
    randomNum = (line_id1[0][0] + 1 .. line_id2[0][0] - 1).to_a.sample
    return [[randomNum, site_id, time], TEXT_FLAG]
  else
    line_id1.pop
    return line_id1.concat([[rand(MAX_INT), site_id, time], TEXT_FLAG])
  end
end


def tableHelper(lmap, hash, paths)
  sortedKeys = lmap.reveal.keys.sort
  for key in sortedKeys
    if key == [-1,-1,-1]
      if lmap.reveal.values_at(key)[0].reveal != -1
        curPath = paths.pop
        text_atom = lmap.reveal.values_at(key)[0].reveal
        hash[curPath] = text_atom
      end
      next
    end
    nextLmap = lmap.reveal[key]
    tableHelper(nextLmap, hash, paths)
  end
end

def createTable(lmap, paths, char_offset)
  partialHash = Hash.new()
  lookupTable = Hash.new()
  tableHelper(lmap, partialHash, paths)
  for key in partialHash.keys.sort
    text_atom = partialHash[key]
    # add 1 to encode space after text atom
    lookupTable[char_offset] = [text_atom, key]
    char_offset = char_offset + text_atom.size + 1
  end
  p lookupTable
  return lookupTable
end

def createDelta(currentDoc, currentTable, site_id)
  splitString = currentDoc.split('#')
  splitString.shift
  charOffsets = currentTable.keys.sort
  if currentTable.keys.size == 0
    newID = constructId(nil, nil, site_id, false)
    return createDocLattice(newID, splitString[0])
  end
  for i in 0..splitString.length
    if currentTable[charOffsets[i]][0] != splitString[i]
      prevEntry = currentTable[charOffsets[i - 1]][1]
      nextEntry = currentTable[charOffsets[i]][1]
      newID = constructId(prevEntry, nextEntry, site_id, false)
      return createDocLattice(newID, splitString[i])
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
