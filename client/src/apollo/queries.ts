import { gql } from '@apollo/client'

const SEARCH_PRODUCTS = gql`
  query SearchProducts {
    searchProducts {
      id
      upc
      title
      description
      mediaUrl
      releaseDate
      variants {
        id
        colorway
        price
        size
        dimensions
        weight
      }
    }
  }
`

const USER_PROFILE = gql`
  query UserProfile {
    me {
      id
      shippingAddress
      username
      previousSessions
      loyaltyPoints
      paymentMethods {
        id
        name
        description
        type
      }
    }
  }
`
const USER_PROFILE_FULL = gql`
  query UserProfileFull {
    user {
      id
      cart {
        userId
        items {
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
        subtotal
      }
      recommendedProducts {
        id
        upc
        title
        description
        mediaUrl
        releaseDate
        variants {
          id
          price
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
            shippingAddress
            username
            previousSessions
            loyaltyPoints
          }
        }
      }
      shippingAddress
      username
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
          previousSessions
          loyaltyPoints
        }
        shippingCost
      }
    }
  }
`
export const QUERIES = {
  SEARCH_PRODUCTS,
  USER_PROFILE,
  USER_PROFILE_FULL,
}

const LOGIN = gql`
  mutation Mutation(
    $username: String!
    $password: String!
    $scopes: [String!]!
  ) {
    login(username: $username, password: $password, scopes: $scopes) {
      ... on LoginSuccessful {
        token
        scopes
        user {
          id
          username
          previousSessions
        }
      }
      ... on LoginFailed {
        reason
      }
    }
  }
`
export const MUTATIONS = {
  LOGIN,
}
