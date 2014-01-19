require 'set'

Vertex = Struct.new(:id, :parents, :path_len)

class SimpleGraph
  def initialize
    @nodes = {}
  end

  # Insert a new partial ordering, y < x. We assume that this does not introduce
  # a cycle. To implement this, we need to add x to the parents of y. Moreover,
  # we then need to update all the path lengths of the nodes in the forward
  # transitive closure of x to reflect the new edge.
  def insert(x, y)
    x = x.to_s
    y = y.to_s
    x_node = @nodes[x]
    if x_node.nil?
      x_node = @nodes[x] = Vertex.new(x, [].to_set, 0)
    end

    y_node = @nodes[y]
    if y_node.nil?
      y_node = @nodes[y] = Vertex.new(y, [x_node].to_set, 0)
    else
      y_node.parents << x_node
    end

    # Update the path_len values for all the transitively reachable parent
    # nodes, if necessary.
    update_path_len(x_node, 1)
  end

  def update_path_len(n, v)
    return if n.path_len >= v

    n.path_len = v
    n.parents.each do |p|
      update_path_len(p, v + 1)
    end
  end

  def enumerate
    strat = 0
    while true
      strat_nodes = @nodes.values.select {|v| v.path_len == strat}
      break if strat_nodes.empty?

      puts "STRATUM #{strat}:"
      strat_nodes.each do |n|
        puts "#{n.id} => #{n.path_len}"
        n.parents.each do |p|
          puts "#{n.id} < #{p.id}"
        end
      end
      strat += 1
    end
  end

  def dump_graph
    require 'graphviz'
    g = GraphViz.new(:G, :type => :digraph)
    @nodes.each_value do |n|
      g.add_node(n.id, :label => "#{n.id} (#{n.path_len})")
    end
    @nodes.each_value do |n|
      n.parents.each do |p|
        from = g.find_node(n.id)
        to = g.find_node(p.id)
        g.add_edges(from, to)
      end
    end

    g.output(:pdf => "graph.pdf")
  end
end

sg = SimpleGraph.new
sg.insert(:A, :B)
sg.insert(:B, :C)
sg.insert(:D, :E)
sg.insert(:E, :F)
sg.insert(:A, :F)
sg.insert(:B, :D)
sg.enumerate
sg.dump_graph
