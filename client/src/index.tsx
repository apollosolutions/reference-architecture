import React from 'react'
import ReactDOM from 'react-dom/client'
import { ApolloProvider } from '@apollo/client'
import { AuthorizationProvider } from './context'
import { ChakraProvider } from '@chakra-ui/react'
import { RouterProvider } from 'react-router-dom'
import { router } from './router'
import client from './apollo/client'
import './index.css'
import theme from './theme'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ChakraProvider theme={theme}>
      <ApolloProvider client={client}>
        <AuthorizationProvider>
          <RouterProvider router={router} />
        </AuthorizationProvider>
      </ApolloProvider>
    </ChakraProvider>
  </React.StrictMode>
)
