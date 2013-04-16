require 'rubygems'
require 'backports'
require 'bud'
require_relative 'doc_protocol'

class DocServer
  include Bud
  include DocProtocol

  state do
    table :nodelist
  end


  bloom do
    stdio <~ connect {|c| ["New client: #{c.source_addr}"]}
    stdio <~ to_server {|m| ["Msg @ server: #{m.inspect}"]}
    nodelist <= connect {|c| [c.source_addr]}
    to_host <~ (to_server * nodelist).pairs {|t,n| [n.key, t.txt_id, t.txt, t.pre, t.post]}
  end

end

if __FILE__ == $0
  addr = ARGV.first ? ARGV.first : DocProtocol::DEFAULT_ADDR
  ip, port = addr.split(":")
  puts "Server address: #{ip}:#{port}"
  program = DocServer.new(:ip => ip, :port => port.to_i)
  program.run_fg
end
