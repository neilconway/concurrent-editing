require 'rubygems'
require 'bud'

class Reachable
  include Bud

  state do
    # The constraint that the given ID must follow the "pre" node and precede
    # the "post" node.
    table :constraints, [:id] => [:pre, :post]

    scratch :reach_pre, [:from, :to]
    scratch :reach_post, [:from, :to]

    lmap :reach_set

    scratch :bad_pre, constraints.schema
    scratch :bad_post, constraints.schema
  end

  bloom do
    reach_pre <= constraints {|c| [c.id, c.id]}
    reach_pre <= (reach_pre * constraints).pairs(:to => :id) {|r,c| [r.from, c.pre]}

    reach_post <= constraints {|c| [c.id, c.id]}
    reach_post <= (reach_post * constraints).pairs(:to => :id) {|r,c| [r.from, c.post]}

    reach_set <= reach_pre {|r| {r.from => Bud::SetLattice.new([r.to])} unless r.from == r.to}
    reach_set <= reach_post {|r| {r.from => Bud::SetLattice.new([r.to])} unless r.from == r.to}
  end

  bloom :integrity do
    # Check that constraints reference extant nodes
    bad_pre <= constraints.notin(constraints, :pre => :id)
    bad_post <= constraints.notin(constraints, :post => :id)
  end
end

r = Reachable.new
r.constraints <+ [["1", "x", "y"],
                  ["2", "x", "y"],
                  ["3", "x", "1"],
                  ["4", "3", "1"]]
r.tick

# puts r.reach_pre.to_a.sort.inspect
# puts r.reach_post.to_a.sort.inspect

m = r.reach_set.current_value.reveal
m.keys.sort.each do |k|
  puts "#{k} => #{m[k].reveal.sort}"
end

#puts r.reach_set.current_value.inspect

puts r.bad_pre.to_a.inspect
puts r.bad_post.to_a.inspect

