import { useQuery } from '@apollo/client'
import {
  Alert,
  AlertIcon,
  Button,
  FormControl,
  FormLabel,
  Input,
  Stack,
  Spinner,
  Avatar,
  AvatarBadge,
  IconButton,
  Center,
} from '@chakra-ui/react'
import { SmallCloseIcon } from '@chakra-ui/icons'
import { QUERIES } from '../../apollo/queries'

export default function UserProfileForm() {
  const { loading, error, data } = useQuery(QUERIES.USER_PROFILE, {
    context: {
      headers: {
        "x-user-id": "user:1"
      }
    },
    variables: {},
    errorPolicy: "all",
  })

  if (loading) <Spinner />
  if (error) {
    return (
      <Alert status='error' color="navy.400">
        <AlertIcon />
        There was an error processing your request
      </Alert>
    )
  }
  return (
    <>
      <FormControl id="userName">
        <FormLabel>User Icon</FormLabel>
        <Stack direction={['column', 'row']} spacing={6}>
          <Center>
            <Avatar size="xl" src="https://bit.ly/sage-adebayo">
              <AvatarBadge
                as={IconButton}
                size="sm"
                rounded="full"
                top="-10px"
                colorScheme="red"
                aria-label="remove Image"
                icon={<SmallCloseIcon />}
              />
            </Avatar>
          </Center>
          <Center w="full">
            <Button w="full">Change Icon</Button>
          </Center>
        </Stack>
      </FormControl>
      <FormControl id="userName" isRequired>
        <FormLabel>User name</FormLabel>
        <Input
          placeholder="UserName"
          _placeholder={{ color: 'gray.500' }}
          type="text"
          defaultValue={data?.user?.username}
        />
      </FormControl>
      <FormControl id="email" isRequired>
        <FormLabel>Email address</FormLabel>
        <Input
          placeholder="your-email@example.com"
          _placeholder={{ color: 'gray.500' }}
          type="email"
        />
      </FormControl>
      <FormControl id="password" isRequired>
        <FormLabel>Password</FormLabel>
        <Input
          placeholder="password"
          _placeholder={{ color: 'gray.500' }}
          type="password"
        />
      </FormControl>
      <Stack spacing={6} direction={['column', 'row']}>
        <Button
          variant={"outline"}
          borderColor={"navy.400"}
          borderWidth={"2px"}
          color={'navy.400'}
          w="full"
          _hover={{
            bg: 'red.500',
          }}>
          Cancel
        </Button>
        <Button
          bg={'navy.400'}
          color={'beige.400'}
          w="full"
          _hover={{
            bg: 'orange.200',
          }}>
          Submit
        </Button>
      </Stack>
    </>
  )
}
