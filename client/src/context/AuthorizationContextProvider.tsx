import { ReactNode, useState } from 'react'
import { User } from 'src/hooks/useAuth'
import { AuthorizationContext } from './AuthorizationContext'

type ProviderType = ({ children }: { children: ReactNode }) => JSX.Element
type ReactChildrenType = { children: ReactNode }

export const AuthorizationProvider: ProviderType = ({
  children,
}: ReactChildrenType) => {
  const [user, setUser] = useState<User | null>(null)
  return (
    <AuthorizationContext.Provider value={{ user, setUser }}>
      {children}
    </AuthorizationContext.Provider>
  )
}
