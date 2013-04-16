module DocProtocol
  state do
    channel :to_host, [:@addr] => [:txt_id, :pre, :post, :txt]
    channel :to_server, [:@addr] => [:source_addr, :txt_id, :pre, :post, :txt] 
    channel :connect, [:@addr] => [:source_addr]
  end

  DEFAULT_ADDR = "localhost:12345"
end