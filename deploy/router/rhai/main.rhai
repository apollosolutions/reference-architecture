import "client_id" as client_id;

fn process_request(request) {
  client_id::process_request(request)
}

fn supergraph_service(service) {
  // Rhai convention for creating a function pointer
  const request_callback = Fn("process_request"); 
  
  service.map_request(request_callback);
}