import { Box, Stack, Heading, Text, useColorModeValue } from '@chakra-ui/react'
import { useAuth } from '../../hooks/useAuth'
import LoginForm from '../../components/LoginForm'

const LoggedInMessage = () => {
  return (
    <>
      <Heading color={'beige.400'} fontSize={'4xl'}>
        Welcome
      </Heading>
      <Text fontSize={'xl'} color={'beige.400'}>
        Enjoy shopping our great{' '}
        <Text color={'orange.400'} as="span">
          deals!
        </Text>
      </Text>
    </>
  )
}

const LoggedOutMessage = () => {
  return (
    <>
      <Heading color={'beige.400'} fontSize={'4xl'}>
        Sign in to your account
      </Heading>
      <Text fontSize={'xl'} color={'beige.400'}>
        to enjoy all of our cool{' '}
        <Text color={'orange.400'} as="span">
          features
        </Text>
      </Text>
    </>
  )
}

export const RouteComponent = () => {
  const { isLoggedIn } = useAuth()

  return (
    <Box bgColor={'navy.400'} minHeight={'70vh'}>
      <Stack spacing={8} mx={'auto'} maxW={'lg'} py={12} px={6}>
        <Stack align={'left'}>
          {isLoggedIn ? <LoggedInMessage /> : <LoggedOutMessage />}
        </Stack>
        <Box
          rounded={'lg'}
          bg={useColorModeValue('navy.400', 'navy.400')}
          boxShadow={'lg'}
          p={8}
        >
          <Stack spacing={4} color={'beige.400'}>
            <LoginForm />
          </Stack>
        </Box>
      </Stack>
    </Box>
  )
}
