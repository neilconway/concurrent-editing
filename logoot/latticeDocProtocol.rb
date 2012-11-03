module LatticeDocProtocol
  DEFAULT_ADDR = "localhost:12345"

  state do
    channel :toHost, [:@address] => [:val]
    channel :toServer, [:@address] => [:site, :val]
    channel :connect
  end
end
