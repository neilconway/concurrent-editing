require 'set'

class SimpleGraph
  Node = Struct.new(:id, :parents, :path_len)

  def initialize
    @nodes = {}
    reset
  end

  # Insert a new partial ordering, y < x; we assume this does not introduce a
  # cycle.
  def insert(x, y)
    @nodes[x] ||= Node.new(x, [].to_set, 0)
    @nodes[y] ||= Node.new(y, [].to_set, 0)
    @nodes[y].parents << @nodes[x]

    # Update the path_len values for all the transitively reachable parent
    # nodes, as needed.
    update_path_len(@nodes[x], @nodes[y].path_len + 1)
  end

  def update_path_len(n, v)
    return if n.path_len >= v
    n.path_len = v
    n.parents.each {|p| update_path_len(p, v + 1)}
  end

  def reset
    @frontier = @nodes.values.select {|n| n.path_len == 0}.to_set
    @current_stratum = 0
  end

  def advance_stratum
    @current_stratum += 1
    @frontier = @frontier.flat_map do |n|
      n.parents.map do |p|
        if p.path_len == @current_stratum
          p
        elsif p.path_len > @current_stratum
          n
        end
      end.compact
    end.to_set
  end

  def print_nodes(s)
    s.map {|n| n.id}
  end

  def each_raw(&blk)
    @frontier.each do |n|
      n.parents.each do |p|
        blk.call(n, p) if p.path_len == @current_stratum + 1
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
      rv << strat.sort
      advance_stratum
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
sg.insert("A", "C")
sg.insert("B", "C")
raise unless sg.all_strat == [[["C", "B"]], [["B", "A"], ["C", "A"]]]

sg = SimpleGraph.new
sg.insert("A", "B")
sg.insert("B", "C")
sg.insert("D", "E")
sg.insert("E", "F")
sg.insert("A", "F")
sg.insert("B", "D")
# NB: Note that in some sense, it would be more correct to emit C -> B in the
# first stratum. However, implementing this seems quite difficult/expensive, and
# delaying the appearance of such an edge does not seem unsafe/wrong.
raise unless sg.all_strat == [[["F", "E"]],
                              [["E", "D"]],
                              [["C", "B"], ["D", "B"]],
                              [["B", "A"], ["F", "A"]]]

sg = SimpleGraph.new
sg.insert("A", "B")
sg.insert("B", "C")
sg.insert("C", "D")
sg.insert("C", "E")
sg.insert("B", "E")
sg.insert("A", "E")
raise unless sg.all_strat == [[["D", "C"], ["E", "C"]],
                              [["C", "B"], ["E", "B"]],
                              [["B", "A"], ["E", "A"]]]
