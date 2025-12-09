import { ApolloClient, InMemoryCache, createHttpLink, from } from '@apollo/client'
import { setContext } from '@apollo/client/link/context'
import { fragmentRegistry } from './fragmentRegistry'

const ROUTER_LINK = import.meta.env.VITE_BACKEND_URL ?? 'http://127.0.0.1:4000/'

const httpLink = createHttpLink({
  uri: ROUTER_LINK,
})

const authLink = setContext((_, { headers }) => {
  const userStr = localStorage.getItem('user')
  let authHeaders: { [key: string]: string } = {
    'x-user-id': 'user:1',
    ...headers,
  }

  if (userStr) {
    try {
      const user = JSON.parse(userStr)
      if (user && user.token) {
        authHeaders.authorization = `Bearer ${user.token}`
      }
    } catch (e) {
      console.error('Failed to parse user from localStorage', e)
    }
  }

  return {
    headers: authHeaders,
  }
})

export default new ApolloClient({
  link: from([authLink, httpLink]),
  connectToDevTools: true,
  name: 'retail-website',
  version: '1.0',
  cache: new InMemoryCache({
    fragments: fragmentRegistry,
    possibleTypes: {},
    typePolicies: {},
  }),
})
