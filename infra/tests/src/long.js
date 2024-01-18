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
  login(username: "user1", password: "password", scopes: []){
    ... on LoginSuccessful {
      token
    }
  }
}
`

const query = `
query ProductById{
  product(id: "product:1") {
    id
    recommendedProducts {
      id
      upc
      title
      description
      mediaUrl
      releaseDate
    }
    upc
    title
    description
    mediaUrl
    releaseDate
    variants {
      id
      price
      inventory {
        inStock
        inventory
      }
      product {
        id
        upc
        title
        description
        mediaUrl
        releaseDate
      }
      colorway
      size
      dimensions
      weight
    }
    reviews {
      id
      body
      author
      user {
        id
        cart {
          userId
          items {
            id
            price
            colorway
            size
            dimensions
            weight
          }
          subtotal
        }
        shippingAddress
        username
        email
        previousSessions
        loyaltyPoints
        paymentMethods {
          id
          name
          description
          type
        }
        orders {
          id
          buyer {
            id
            shippingAddress
            username
            email
            previousSessions
            loyaltyPoints
          }
          shippingCost
        }
      }
    }
  }
}
`;

const headers = {
  "Content-Type": "application/json",
  "apollographql-client-name": "apollo-loadtest",
  "apollographql-client-version": "long"
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
