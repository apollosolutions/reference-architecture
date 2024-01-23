import { createContext, ReactNode, useState } from "react";
import { User } from "../hooks/useAuth";

type ProviderType = ({ children }: { children: ReactNode }) => JSX.Element
type ReactChildrenType = { children: ReactNode }
type AuthorizationContextType = {
  user: User | null;
  setUser: (user: User | null) => void;
}

export const AuthorizationContext = createContext<AuthorizationContextType>({
  user: null,
  setUser: () => { }
});

export const AuthorizationProvider: ProviderType = ({ children }: ReactChildrenType) => {
  const [user, setUser] = useState<User | null>(null)
  return <AuthorizationContext.Provider value={{ user, setUser }}>{children}</AuthorizationContext.Provider>
}
