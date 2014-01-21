require 'set'

Node = Struct.new(:id, :parents, :path_len)

class SimpleGraph
  def initialize
    @nodes = {}
    @frontier = nil
    @current_strat = 0
  end

  # Insert a new partial ordering, y < x. We assume that this does not introduce
  # a cycle. To implement this, we need to add x to the parents of y. Moreover,
  # we then need to update all the path lengths of the nodes in the forward
  # transitive closure of x to reflect the new edge.
  def insert(x, y)
    x_node = @nodes[x]
    if x_node.nil?
      x_node = @nodes[x] = Node.new(x, [].to_set, 0)
    end

    y_node = @nodes[y]
    if y_node.nil?
      y_node = @nodes[y] = Node.new(y, [x_node].to_set, 0)
    else
      y_node.parents << x_node
    end

    # Update the path_len values for all the transitively reachable parent
    # nodes, if necessary.
    update_path_len(x_node, y_node.path_len + 1)
  end

  def update_path_len(n, v)
    return if n.path_len >= v

    n.path_len = v
    n.parents.each do |p|
      update_path_len(p, v + 1)
    end
  end

  def reset
    @frontier = @nodes.values.select {|n| n.path_len == 0}.to_set
    @current_strat = 0
  end

  def advance_strat
    @current_strat += 1
    @frontier = @frontier.flat_map do |n|
      n.parents.map do |p|
        p if p.path_len == @current_strat
      end.compact
    end.to_set
  end

  def print_nodes(s)
    s.map {|n| n.id}
  end

  def each_raw(&blk)
    @frontier.each do |n|
      n.parents.each do |p|
        blk.call(n, p)
      end
    end
  end

  def all_strat
    reset
    rv = []
    while true
      strat = []
      each_raw {|n,p| strat << [n.id, p.id]}
      break if strat.empty?
      rv << strat
      advance_strat
    end
    rv
  end

  def dump_graph
    require 'graphviz'
    g = GraphViz.new(:G, :type => :digraph)
    @nodes.each_value do |n|
      g.add_node(n.id, :label => "#{n.id} (#{n.path_len})")
    end
    @nodes.each_value do |n|
      n.parents.each do |p|
        g.add_edges(g.find_node(n.id), g.find_node(p.id))
      end
    end

    g.output(:pdf => "graph.pdf")
  end
end

sg = SimpleGraph.new
sg.insert("A", "B")
sg.insert("B", "C")
sg.insert("D", "E")
sg.insert("E", "F")
sg.insert("A", "F")
sg.insert("B", "D")
raise unless sg.all_strat == [[["C", "B"], ["F", "E"], ["F", "A"]], [["E", "D"]], [["D", "B"]], [["B", "A"]]]

sg = SimpleGraph.new
sg.insert("A", "B")
sg.insert("B", "C")
sg.insert("C", "D")
sg.insert("C", "E")
sg.insert("B", "E")
sg.insert("A", "E")
raise unless sg.all_strat == [[["D", "C"], ["E", "C"], ["E", "B"], ["E", "A"]], [["C", "B"]], [["B", "A"]]]
