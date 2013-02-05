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
  startDoc = createPartialLattice(BEGIN_DOC, "")
  endDoc = createPartialLattice(END_DOC, "")
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

def constructId(pre, post, site_id, time)
  if pre == nil and post == nil
    return [[rand(MAX_INT), site_id, time], TEXT_FLAG]
  elsif post[0][0] - pre[0][0] > 1
    randomNum = (pre[0][0] + 1..post[0][0] - 1).to_a.sample
    return [[randomNum, site_id, time], TEXT_FLAG]
  else
    pre.pop
    return pre.concat([[rand(MAX_INT), site_id, time], TEXT_FLAG])
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
      else
        curPath = paths.pop
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
    lookupTable[char_offset] = [text_atom, key]
    char_offset = char_offset + 1
  end
  return lookupTable
end

def createDelta(newText, offset, currentTable, site_id, time)
  offset = offset + 1
  # This accounts for shift in offsets due to start and end doc
  post = currentTable[offset]
  if post != nil
    post = post[1]
  end
  pre = currentTable[offset - 1]
  if pre != nil
    pre = pre[1]
  end
  newID = constructId(pre, post, site_id, time)
  return  createDocLattice(newID, newText)
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
