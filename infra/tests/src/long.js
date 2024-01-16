import http from "k6/http";
import { check } from "k6";

export const options = {
  stages: [
    { duration: "30s", target: 100 }, // simulate ramp-up of traffic from 1 to 100 users
    { duration: "2m", target: 100 }, // stay at 100 users
    { duration: "30s", target: 0 }, // ramp-down to 0 users
  ],
  thresholds: {
    http_req_duration: ["p(99)<1500"], // 99% of requests must complete below 1.5s
  },
};

const BASE_URL = "http://router.router.svc.cluster.local/";

const loginMutation = `
mutation Login {
  login(username: "LOAD_TEST"){
    token
  }
}
`

const query = `
query Locations {
  locations {
    name
    reviewsForLocation {
      rating
    }
  }
}
`;

const headers = {
  "Content-Type": "application/json",
  "apollographql-client-name": "apollo-client",
  "apollographql-client-version": "1"
};

export default () => {
  const loginRes = http.post(BASE_URL, JSON.stringify({ query: loginMutation }), {
    headers: headers,
  });
  check(loginRes, {
    "is login status 200": (r) => r.status === 200,
  });
  const loginBody = JSON.parse(loginRes.body);
  check(loginBody, {
    "login without errors": (b) => b.errors == null,
  });
  const jwt = loginBody.data.login.token;

  const requestHeaders = headers;
  requestHeaders['Authorization'] = `Bearer ${jwt}`
  const res = http.post(BASE_URL, JSON.stringify({ query: query }), {
    headers: requestHeaders,
  });
  check(res, {
    "is status 200": (r) => r.status === 200,
  });

  const body = JSON.parse(res.body);
  check(body, {
    "without errors": (b) => b.errors == null,
  });
};
