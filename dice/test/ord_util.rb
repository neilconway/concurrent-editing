require 'tsort'

class LinearPrinter
  include TSort

  def initialize(b)
    @bud = b
  end

  def tsort_each_node(&blk)
    @bud.ord.to_a.map {|t| t.id}.uniq.each(&blk)
  end

  def tsort_each_child(node, &blk)
    @bud.ord.to_a.each do |t|
      if t.id == node
        blk.call(t.pred) unless t.pred.nil?
      end
    end
  end
end

def print_linear_order(b)
  puts LinearPrinter.new(b).tsort
end
