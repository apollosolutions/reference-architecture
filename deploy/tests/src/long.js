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
};

export default () => {
  const res = http.post(BASE_URL, JSON.stringify({ query: query }), {
    headers: headers,
  });
  check(res, {
    "is status 200": (r) => r.status === 200,
  });

  const body = JSON.parse(res.body);
  check(body, {
    "without errors": (b) => b.errors == null,
  });
};
