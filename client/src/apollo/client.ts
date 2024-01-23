import { ApolloClient, InMemoryCache } from '@apollo/client'
import { fragmentRegistry } from './fragmentRegistry'

const ROUTER_LINK = import.meta.env.VITE_BACKEND_URL ?? 'http://127.0.0.1:4000/'

console.log(ROUTER_LINK)
export default new ApolloClient({
  uri: ROUTER_LINK,
  connectToDevTools: true,
  name: 'Retail website',
  cache: new InMemoryCache({
    fragments: fragmentRegistry,
    possibleTypes: {},
    typePolicies: {},
  }),
})
