import { Alert, Card, CardBody, Center } from '@chakra-ui/react'
import { useAuth } from '../../hooks/useAuth'
import UserProfile from './UserProfile'

export const RouteComponent = () => {
  const { user } = useAuth()

  if (!user)
    return (
      <Center>
        <Card>
          <CardBody>
            <Alert status="error">User not logged in</Alert>
          </CardBody>
        </Card>
      </Center>
    )

  return <UserProfile user={user} />
}
