import { Flex, useColorModeValue, Heading, Text, Stack } from '@chakra-ui/react'
import UserProfileForm from './UserProfileForm'
import { User } from '../../hooks/useAuth'

type Props = {
  user: User
}
export default function UserProfile(props: Props) {
  const { user } = props
  return (
    <Flex
      minH={'100vh'}
      flexDirection={'column'}
      align={'center'}
      justify={'center'}
      bg={useColorModeValue('navy.400', 'navy.500')}
    >
      <Stack
        spacing={4}
        w={'full'}
        maxW={'md'}
        bg={useColorModeValue('beige.400', 'beige.500')}
        rounded={'xl'}
        boxShadow={'lg'}
        p={6}
        my={12}
      >
        <Heading lineHeight={1.1} fontSize={{ base: '2xl', sm: '3xl' }}>
          User Profile Edit
        </Heading>
        <UserProfileForm user={user} />
      </Stack>
      <Stack
        spacing={4}
        w={'full'}
        maxW={'md'}
        bg={useColorModeValue('beige.400', 'gray.500')}
        rounded={'xl'}
        boxShadow={'lg'}
        p={6}
        my={12}
      >
        <Heading lineHeight={1.1} fontSize={{ base: '2xl', sm: '3xl' }}>
          Authentication
        </Heading>
        <Text as="pre" className={'whitespace-pre-wrap'}>
          {JSON.stringify(user, null, 2)}
        </Text>
      </Stack>
    </Flex>
  )
}
