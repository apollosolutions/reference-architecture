import { Link } from 'react-router-dom'
import { Text } from '@chakra-ui/react'
import { useAuth } from '../../hooks/useAuth'

export default function LoginOrOut() {
  const { isLoggedIn } = useAuth()
  const link = isLoggedIn ? 'Logout' : 'Login'
  return (
    <Link to={`/${link.toLowerCase()}`} key={link}>
      <Text fontWeight={600}>{link}</Text>
    </Link>
  )
}
