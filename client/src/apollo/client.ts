import { ApolloClient, InMemoryCache } from '@apollo/client'
import { fragmentRegistry } from './fragmentRegistry'

const ROUTER_LINK = import.meta.env.VITE_BACKEND_URL ?? 'http://127.0.0.1:4000/'

export default new ApolloClient({
  uri: ROUTER_LINK,
  connectToDevTools: true,
  name: 'retail-website',
  version: '1.0',
  cache: new InMemoryCache({
    fragments: fragmentRegistry,
    possibleTypes: {},
    typePolicies: {},
  }),
})
