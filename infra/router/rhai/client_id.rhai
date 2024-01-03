fn process_request(request) {
  log_info("processing request");
  let valid_clients = ["1", "2"];
  let valid_client_names = ["apollo-client"];

  if ("apollographql-client-version" in request.headers && "apollographql-client-name" in request.headers) {
    let client_header = request.headers["apollographql-client-version"];
    let name_header = request.headers["apollographql-client-name"];
  
    if !valid_clients.contains(client_header) {
      log_error("Invalid client ID provided");
      throw #{
        status: 401,
        message: "Invalid client ID provided"
      };
    }
    if !valid_client_names.contains(name_header) {
      log_error("Invalid client name provided");
      throw #{
        status: 401,
        message: "Invalid client name provided"
      };
    }
  }
  else {
    log_error("No client headers set. Please provide headers: apollographql-client-name and apollographql-client-version");
    throw #{
      status: 401,
      message: "No client headers set"
    };
  }    
}