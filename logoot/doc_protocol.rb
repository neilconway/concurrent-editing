module LatticeDocProtocol
  state do
    channel :to_host, [:@addr] => [:val]
    channel :to_server, [:@addr] => [:source_addr, :val]
    channel :connect, [:@addr] => [:source_addr]
  end

  DEFAULT_ADDR = "localhost:12345"
end
