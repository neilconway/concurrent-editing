module LatticeDocProtocol
  state do
    #
    channel :toHost, [:@address] => [:val]
    channel :toServer, [:@address] => [:site, :val]
    channel :connect
  end

  DEFAULT_ADDR = "localhost:12345"
end
