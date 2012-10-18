module LatticeDocProtocol
  state do
    channel :mcast, [:@address] => [:val]
    channel :connect
  end

  DEFAULT_ADDR = "localhost:12345"
end
