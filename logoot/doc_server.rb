require 'rubygems'
require 'bud'
require_relative 'doc_protocol'
require_relative 'lfixed'

class LatticeDocServer
  include Bud
  include LatticeDocProtocol

  state { table :nodelist }

  bloom do
    nodelist <= connect.payloads
    to_host <~ (to_server * nodelist).pairs {|m,n| [n.key, m.val]}
  end
end

addr = ARGV.first ? ARGV.first : LatticeDocProtocol::DEFAULT_ADDR
ip, port = addr.split(":")
puts "Server address: #{ip}:#{port}"
program = LatticeDocServer.new(:ip => ip, :port => port.to_i)
program.run_fg
