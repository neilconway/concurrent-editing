require_relative 'concurrent-editing/dice/nm_simple'

  DOC_SIZE = 30
  def test_big_explicit
    doc = []
    prev = BEGIN_ID
    DOC_SIZE.times do |i|
      curr = i.hash % 100000
      doc << [curr, prev, END_ID]
      prev = curr
    end
    # doc = [[92534, Float::INFINITY, -Float::INFINITY], [71984, 92534, -Float::INFINITY], [26210, 71984, -Float::INFINITY], [11996, 26210, -Float::INFINITY], [39758, 11996, -Float::INFINITY]]
    puts "doc = #{doc}"
    s = SimpleNmLinear.new
    s.input_buf <+ doc
    DOC_SIZE.times { |i| s.tick }

    # puts "# constr_prod: #{s.constr_prod.to_a.size}"
    # puts "# tiebreak (raw): #{s.tiebreak.to_a.size}"
    # puts "# implied: #{s.use_implied_anc.to_a.size}"
    # puts "# tiebreak: #{s.use_tiebreak.to_a.size}"
    # puts "# explicit: #{s.explicit_tc.to_a.size}"
    # puts "# before: #{s.before.to_a.size}"

    # puts "USE_TIEBREAK: #{s.use_tiebreak.to_a.sort}"
    # puts "USE_IMPLIED_ANC: #{s.use_implied_anc.to_a.sort}"
    # puts "USE_EXPLICIT: #{s.explicit_tc.to_a.sort}"
  end

test_big_explicit
