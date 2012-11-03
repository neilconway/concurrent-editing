module LatticeDocProtocol
  state do
    channel :to_host, [:@address] => [:val]
    channel :to_server, [:@address] => [:site, :val]
    channel :connect
  end

  DEFAULT_ADDR = "localhost:12345"
end
