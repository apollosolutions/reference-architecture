import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Alert,
  AlertIcon,
  Button,
  Center,
  Checkbox,
  FormControl,
  FormLabel,
  Input,
  Stack,
  Text,
  Spinner,
} from '@chakra-ui/react'
import { ApolloError, useMutation } from '@apollo/client'
import { MUTATIONS } from '../../apollo/queries'
import { useAuth } from '../../hooks/useAuth'

const inputProps = {
  bg: 'navy.400',
  borderWidth: '2px',
  borderColor: 'beige.400',
}

const LoginForm = () => {
  const { login } = useAuth()
  const navigate = useNavigate()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [scopes, setScopes] = useState('')
  const [loginError, setLoginError] = useState(
    undefined as ApolloError | undefined
  )

  const resetForm = () => {
    setUsername('')
    setPassword('')
    setScopes('')
  }

  const handleChangeUsername = (e: React.FormEvent<HTMLInputElement>) => {
    setUsername(e?.currentTarget.value)
  }

  const handleChangePassword = (e: React.FormEvent<HTMLInputElement>) => {
    setPassword(e?.currentTarget.value)
  }

  const handleChangeScopes = (e: React.FormEvent<HTMLInputElement>) => {
    setScopes(e?.currentTarget.value)
  }

  const [loginMutation, { data, loading, error: requestError }] = useMutation(
    MUTATIONS.LOGIN,
    {
      variables: {
        username: username,
        password: password,
        scopes: scopes.split(','),
      },
      onCompleted: async (data) => {
        // Request succeeded but login failed
        if (data.login.__typename === 'LoginFailed') {
          setLoginError(data.login.reason)
          return
        }

        // Request succeeded and login suceeded
        if (data) {
          // Reset form
          resetForm()

          // Set application wide user-data
          login(data.login)
        }
      },
    }
  )

  const handleSubmit = (e: React.SyntheticEvent) => {
    e.preventDefault()
    setLoginError(undefined)
    loginMutation()
  }

  if (loading)
    return (
      <Center>
        <Spinner color={'beige.400'} size={'xl'} />
      </Center>
    )

  return (
    <>
      {!data && (
        <>
          <FormControl id="username">
            <FormLabel>Username</FormLabel>
            <Input
              type="username"
              bg="navy.400"
              borderWidth="2px"
              borderColor="beige.400"
              placeholder="Type your username"
              value={username}
              onChange={handleChangeUsername}
            />
          </FormControl>
          <FormControl id="password">
            <FormLabel>Password</FormLabel>
            <Input
              type="password"
              {...inputProps}
              placeholder="Your Password"
              value={password}
              onChange={handleChangePassword}
            />
          </FormControl>
          <FormControl id="scopes">
            <FormLabel>Scopes</FormLabel>
            <Input
              type="scopes"
              {...inputProps}
              placeholder="Comma Separated Scopes"
              value={scopes}
              onChange={handleChangeScopes}
            />
          </FormControl>
          <Stack spacing={10}>
            <Stack
              direction={{ base: 'column', sm: 'row' }}
              align={'start'}
              justify={'space-between'}
            >
              <Checkbox borderColor="beige.400">Remember me</Checkbox>
              <Text color={'blue.400'}>Forgot password?</Text>
            </Stack>
            <Button
              bg={'orange.400'}
              rounded={'full'}
              px={6}
              _hover={{
                bg: 'navy.500',
              }}
              onClick={handleSubmit}
            >
              Sign In
            </Button>
          </Stack>
        </>
      )}
      {!loading && (
        <Stack spacing={3}>
          {/* 1. Request error */}
          {requestError && (
            <Alert status="error" color="navy.400">
              <AlertIcon />
              There was an error processing your request
              {JSON.stringify(loginError, null, 2)}
            </Alert>
          )}

          {/* 2. Server Login error */}
          {loginError && (
            <Alert status="error" color="navy.400">
              <AlertIcon />
              {`There was an error processing your request: ${JSON.stringify(loginError, null, 2)}`}
            </Alert>
          )}

          {/* 3. Success */}
          {!requestError && !loginError && data && (
            <>
              <Alert status="success" color="navy.400">
                <AlertIcon />
                {`Sign-in successful! Blast Off!`}
              </Alert>
              <Alert status="info" color="navy.400">
                <AlertIcon />
                <pre>${JSON.stringify(data, null, 2)}</pre>
              </Alert>
              <Button
                bg={'orange.400'}
                rounded={'full'}
                px={6}
                _hover={{
                  bg: 'navy.500',
                }}
                onClick={() => navigate('/profile')}
              >
                Go to User Profile
              </Button>
            </>
          )}
        </Stack>
      )}
    </>
  )
}
export default LoginForm
