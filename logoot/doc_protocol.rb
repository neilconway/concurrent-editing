module LatticeDocProtocol
  state do
    channel :to_host, [:@addr] => [:doc_name, :val]
    channel :to_server, [:@addr] => [:source_addr, :doc_name, :val]
    channel :connect, [:@addr] => [:source_addr]
    channel :list_of_docs_to_client, [:@addr] => [:val]
    channel :new_doc_to_server, [:@addr] => [:source_addr, :val]
    channel :select_doc_to_server, [:@addr] => [:source_addr, :doc_name]
  end

  DEFAULT_ADDR = "localhost:12345"
end
