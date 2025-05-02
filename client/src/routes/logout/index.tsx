import { useNavigate } from 'react-router-dom'
import { useMount } from '../../hooks/useMount'
import { useAuth } from '../../hooks/useAuth'

export const RouteComponent = () => {
  const { logout } = useAuth()
  const navigate = useNavigate()

  useMount(() => {
    logout()
    navigate('/home')
  })

  return <>Logging you out...</>
}
