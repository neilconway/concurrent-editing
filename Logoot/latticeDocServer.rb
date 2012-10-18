require 'rubygems'
require 'bud'
require './latticeDocProtocol'

class LatticeDocServer
	include Bud
	include LatticeDocProtocol

	state { table :nodelist}

	bloom  do
		nodelist <= connect.payloads
		mcast <~ (mcast * nodelist).pairs {|m,n| [n.key, m.val]}
		
	end
end

addr = ARGV.first ? ARGV.first : LatticeDocProtocol::DEFAULT_ADDR
ip, port = addr.split(":")
puts "Server address: #{ip}:#{port}"
program = LatticeDocServer.new(:ip => ip, :port => port.to_i)
program.run_fg