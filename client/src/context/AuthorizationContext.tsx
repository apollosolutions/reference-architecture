import { createContext } from 'react'
import { User } from '../hooks/useAuth'

type AuthorizationContextType = {
  user: User | null
  setUser: (user: User | null) => void
}

export const AuthorizationContext = createContext<AuthorizationContextType>({
  user: null,
  setUser: () => {},
})
