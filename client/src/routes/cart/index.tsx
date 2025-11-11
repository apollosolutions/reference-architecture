import { Alert, Card, CardBody, Center } from '@chakra-ui/react'
import { useAuth } from '../../hooks/useAuth'
import Cart from './Cart'

export const RouteComponent = () => {
  const { user, isLoggedIn } = useAuth()

  if (!isLoggedIn || !user) {
    return (
      <Center py={8}>
        <Card>
          <CardBody>
            <Alert status="warning">Please log in to view your cart</Alert>
          </CardBody>
        </Card>
      </Center>
    )
  }

  return <Cart user={user} />
}

