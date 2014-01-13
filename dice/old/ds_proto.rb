require 'rubygems'
require 'set'

RawEdit = Struct.new(:id, :pre, :post)

$end = RawEdit.new(-Float::INFINITY)
$begin = RawEdit.new(Float::INFINITY, nil, $end.id)

class Proto
  include Enumerable

  Node = Struct.new(:id, :children) do
    def initialize(id)
      super(id, Set.new)
    end
  end

  def initialize
    @input_buf = Set.new
    @ht = Hash.new

    enqueue($end)
    enqueue($begin)
  end

  def enqueue(e)
    if @ht.has_key?(e.pre) and @ht.has_key?(e.post)
      @ht[e.id] = Node.new(e.id)
      @ht[e.pre].children << e.id
      @ht[e.post].children << e.id
    end
  end

  def tick
  end

  def each
  end
end

p = Proto.new
p.enqueue(RawEdit.new(1, $begin.id, $end.id))
p.enqueue(RawEdit.new(2, $begin.id, $end.id))
2.times { p.tick }

p.each {|n| puts n}
