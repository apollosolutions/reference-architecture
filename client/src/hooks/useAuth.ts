import { useContext, useEffect, useState } from 'react'
import { useMount } from '../hooks/useMount'
import { useLocalStorage } from './useLocalStorage'
import { AuthorizationContext } from '../context'

export interface User {
  id: string
  name: string
  email: string
  token?: string
}

export const useAuth = () => {
  const { user, setUser } = useContext(AuthorizationContext)
  const { setItem, removeItem } = useLocalStorage()
  const { getItem } = useLocalStorage()
  const [isLoggedIn, setIsLoggedIn] = useState(false)

  // Try to load from local storage
  useMount(() => {
    const user = getItem('user')
    if (user) {
      addUser(JSON.parse(user))
    }
  })

  useEffect(() => {
    let status = false
    if (user) {
      status = true
    }
    setIsLoggedIn(status)
  }, [user])

  const login = (user: User) => {
    addUser(user)
  }

  const logout = () => {
    removeUser()
  }

  const addUser = (user: User) => {
    setUser(user)
    setItem('user', JSON.stringify(user))
  }

  const removeUser = () => {
    setUser(null)
    removeItem('user')
  }

  return { user, login, logout, isLoggedIn }
}
