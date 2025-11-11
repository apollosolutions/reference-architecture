import { Outlet } from 'react-router-dom'
import { Box, Flex } from '@chakra-ui/react'
import Header from '../components/Header'
import Footer from '../components/Footer'

export const RouteComponent = () => {
  return (
    <Flex direction="column" minH="100vh">
      <Header />
      <Box flex="1" pb={8}>
        <Outlet />
      </Box>
      <Footer />
    </Flex>
  )
}
