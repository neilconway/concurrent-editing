require 'rubygems'
require 'bud'

gem 'minitest'
require 'minitest/autorun'

class Hash
  # Like Enumerable#map, but map from Hash -> Hash rather than Enumerable ->
  # Array, and only yield values.
  def hmap
    result = {}
    self.each_pair do |k,v|
      result[k] = yield v
    end
    result
  end

  def happly(sym)
    hmap {|v| v.send(sym)}
  end
end
