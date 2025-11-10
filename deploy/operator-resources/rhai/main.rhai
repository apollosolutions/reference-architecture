// Rhai script for logging at all router lifecycle stages
// This script logs requests and responses at every stage to help debug request flow

fn router_service(service) {
    // Router Service: Beginning and end of HTTP request lifecycle
    let request_callback = |request| {
        log_info("=== Router Service: Request ===");
        log_info(`HTTP Method: ${request.method}`);
        log_info(`HTTP Path: ${request.uri.path}`);
        log_info(`Request ID: ${request.id}`);
        
        // Log headers
        try {
            log_debug("Request Headers:");
            for key in request.headers.keys() {
                log_debug(`  ${key}: ${request.headers[key]}`);
            }
        } catch(err) {
            log_debug(`Could not log headers: ${err}`);
        }
        
        // Try to get trace ID
        try {
            let trace_id = traceid();
            log_info(`Trace ID: ${trace_id}`);
        } catch(err) {
            log_debug(`Trace ID not available: ${err}`);
        }
    };
    
    let response_callback = |response| {
        log_info("=== Router Service: Response ===");
        
        // Check if this is the primary response (status_code only available on primary)
        if response.is_primary() {
            log_info(`HTTP Status: ${response.status_code.to_string()}`);
            
            // Log response headers
            try {
                log_debug("Response Headers:");
                for key in response.headers.keys() {
                    log_debug(`  ${key}: ${response.headers[key]}`);
                }
            } catch(err) {
                log_debug(`Could not log headers: ${err}`);
            }
        } else {
            log_debug("Non-primary response (deferred stream)");
        }
        
        log_info(`Response ID: ${response.id}`);
    };

    service.map_request(request_callback);
    service.map_response(response_callback);
}

fn supergraph_service(service) {
    // Supergraph Service: Beginning and end of GraphQL request lifecycle
    let request_callback = |request| {
        log_info("=== Supergraph Service: Request ===");
        
        // Log GraphQL operation details
        try {
            if request.body != () {
                try {
                    if request.body.query != () {
                        log_info(`GraphQL Query: ${request.body.query}`);
                    }
                } catch(err) {
                    log_debug(`Query not available: ${err}`);
                }
                try {
                    if request.body.operation_name != () {
                        log_info(`Operation Name: ${request.body.operation_name}`);
                    }
                } catch(err) {
                    log_debug(`Operation name not available: ${err}`);
                }
                try {
                    if request.body.variables != () {
                        log_debug(`Variables: ${request.body.variables}`);
                    }
                } catch(err) {
                    log_debug(`Variables not available: ${err}`);
                }
            }
        } catch(err) {
            log_debug(`Body not available: ${err}`);
        }
        
        // Log context
        try {
            if request.context != () {
                log_debug("Request Context available");
            }
        } catch(err) {
            log_debug(`Context not available: ${err}`);
        }
        
        // Try to get trace ID
        try {
            let trace_id = traceid();
            log_info(`Trace ID: ${trace_id}`);
        } catch(err) {
            log_debug(`Trace ID not available: ${err}`);
        }
    };
    
    let response_callback = |response| {
        log_info("=== Supergraph Service: Response ===");
        
        // Log GraphQL response details
        try {
            if response.body != () {
                try {
                    if response.body.data != () {
                        log_debug("Response contains data");
                    }
                } catch(err) {
                    log_debug(`Data not available: ${err}`);
                }
                try {
                    if response.body.errors != () {
                        log_warn(`GraphQL Errors: ${response.body.errors}`);
                    }
                } catch(err) {
                    log_debug(`Errors not available: ${err}`);
                }
                try {
                    if response.body.extensions != () {
                        log_debug(`Extensions: ${response.body.extensions}`);
                    }
                } catch(err) {
                    log_debug(`Extensions not available: ${err}`);
                }
            }
        } catch(err) {
            log_debug(`Body not available: ${err}`);
        }
        
        // Note: status_code is not available on SupergraphService responses
        // HTTP status is only available on RouterService responses
    };

    service.map_request(request_callback);
    service.map_response(response_callback);
}

fn execution_service(service) {
    // Execution Service: Query plan execution
    let request_callback = |request| {
        log_info("=== Execution Service: Request ===");
        log_info("Query plan execution initiated");
        
        // Log query plan details if available
        try {
            if request.query_plan != () {
                log_debug("Query plan available");
            }
        } catch(err) {
            log_debug(`Query plan not available: ${err}`);
        }
        
        // Log operation details
        try {
            if request.body != () {
                try {
                    if request.body.query != () {
                        log_debug(`Executing query: ${request.body.query}`);
                    }
                } catch(err) {
                    log_debug(`Query not available: ${err}`);
                }
                try {
                    if request.body.operation_name != () {
                        log_info(`Operation: ${request.body.operation_name}`);
                    }
                } catch(err) {
                    log_debug(`Operation name not available: ${err}`);
                }
            }
        } catch(err) {
            log_debug(`Body not available: ${err}`);
        }
        
        // Try to get trace ID
        try {
            let trace_id = traceid();
            log_info(`Trace ID: ${trace_id}`);
        } catch(err) {
            log_debug(`Trace ID not available: ${err}`);
        }
    };
    
    let response_callback = |response| {
        log_info("=== Execution Service: Response ===");
        log_info("Query plan execution completed");
        
        // Log execution results
        try {
            if response.body != () {
                try {
                    if response.body.data != () {
                        log_debug("Execution returned data");
                    }
                } catch(err) {
                    log_debug(`Data not available: ${err}`);
                }
                try {
                    if response.body.errors != () {
                        log_warn(`Execution errors: ${response.body.errors}`);
                    }
                } catch(err) {
                    log_debug(`Errors not available: ${err}`);
                }
            }
        } catch(err) {
            log_debug(`Body not available: ${err}`);
        }
    };

    service.map_request(request_callback);
    service.map_response(response_callback);
}

fn subgraph_service(service, subgraph) {
    // Subgraph Service: Communication with individual subgraphs
    let request_callback = |request| {
        log_info(`=== Subgraph Service: Request to ${subgraph} ===`);
        log_info(`Subgraph: ${subgraph}`);
        
        // Log subgraph request details
        // For subgraph_service, request.subgraph.* contains the subgraph request details
        log_info(`Subgraph URI Scheme: ${request.subgraph.uri.scheme}`);
        log_info(`Subgraph URI Host: ${request.subgraph.uri.host}`);
        if request.subgraph.uri.port != () {
            log_info(`Subgraph URI Port: ${request.subgraph.uri.port}`);
        }
        log_info(`Subgraph URI Path: ${request.subgraph.uri.path}`);
        
        // Log subgraph operation details
        try {
            if request.subgraph.body != () {
                try {
                    if request.subgraph.body.query != () {
                        log_debug(`Subgraph Query: ${request.subgraph.body.query}`);
                    }
                } catch(err) {
                    log_debug(`Subgraph query not available: ${err}`);
                }
                try {
                    if request.subgraph.body.operation_name != () {
                        log_debug(`Subgraph Operation: ${request.subgraph.body.operation_name}`);
                    }
                } catch(err) {
                    log_debug(`Subgraph operation name not available: ${err}`);
                }
                try {
                    if request.subgraph.body.variables != () {
                        log_debug(`Subgraph Variables: ${request.subgraph.body.variables}`);
                    }
                } catch(err) {
                    log_debug(`Subgraph variables not available: ${err}`);
                }
            }
        } catch(err) {
            log_debug(`Subgraph body not available: ${err}`);
        }
        
        // Log headers being sent to subgraph
        try {
            log_debug(`Headers sent to ${subgraph}:`);
            for key in request.subgraph.headers.keys() {
                log_debug(`  ${key}: ${request.subgraph.headers[key]}`);
            }
        } catch(err) {
            log_debug(`Could not log subgraph request headers: ${err}`);
        }
        
        // Try to get trace ID
        try {
            let trace_id = traceid();
            log_info(`Trace ID: ${trace_id}`);
        } catch(err) {
            log_debug(`Trace ID not available: ${err}`);
        }
    };
    
    let response_callback = |response| {
        log_info(`=== Subgraph Service: Response from ${subgraph} ===`);
        log_info(`Subgraph: ${subgraph}`);
        
        // Log subgraph response status
        log_info(`HTTP Status: ${response.status_code.to_string()}`);
        
        // Log subgraph response details
        try {
            if response.body != () {
                try {
                    if response.body.data != () {
                        log_debug(`Response from ${subgraph} contains data`);
                    }
                } catch(err) {
                    log_debug(`Data not available: ${err}`);
                }
                try {
                    if response.body.errors != () {
                        log_warn(`Errors from ${subgraph}: ${response.body.errors}`);
                    }
                } catch(err) {
                    log_debug(`Errors not available: ${err}`);
                }
            }
        } catch(err) {
            log_debug(`Body not available: ${err}`);
        }
        
        // Log headers received from subgraph
        try {
            log_debug(`Headers received from ${subgraph}:`);
            for key in response.headers.keys() {
                log_debug(`  ${key}: ${response.headers[key]}`);
            }
        } catch(err) {
            log_debug(`Could not log subgraph response headers: ${err}`);
        }
    };

    service.map_request(request_callback);
    service.map_response(response_callback);
}

