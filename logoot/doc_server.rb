require 'rubygems'
require 'backports'
require 'bud'
require_relative 'doc_protocol'
require_relative 'lfixed'

class LatticeDocServer
  include Bud
  include LatticeDocProtocol

  state do
    table :doc_list, [:doc_name] => [:doc_lmap]
    table :nodelist
  end

  bloom do
    stdio <~ connect {|c| ["New client: #{c.source_addr}"]}
    stdio <~ to_server {|m| ["Msg @ server: #{m.inspect}"]}
    nodelist <= connect {|c| [c.source_addr]}
    doc_list <= new_doc_to_server {|n| [n.val, nil]}
    list_of_docs_to_client <~ connect {|c| [c.source_addr, doc_list.keys]}
    #list_of_docs_to_client <~ (connect * doc_list).combos { |c, d| [c.source_addr, [d.doc_name]] }
    to_host <~ (select_doc_to_server * doc_list).pairs(select_doc_to_server.doc_name => doc_list.doc_name) { |s, d| [s.source_addr, d.doc_name, d.doc_lmap]}
    doc_list <+- to_server {|t| [t.doc_name, t.val]}
    to_host <~ (to_server * doc_list * nodelist).pairs(to_server.doc_name => doc_list.doc_name) {|t, d, n| [n.key, d.doc_name, t.val]}
  end
end

if __FILE__ == $0
  addr = ARGV.first ? ARGV.first : LatticeDocProtocol::DEFAULT_ADDR
  ip, port = addr.split(":")
  puts "Server address: #{ip}:#{port}"
  program = LatticeDocServer.new(:ip => ip, :port => port.to_i)
  program.run_fg
end
