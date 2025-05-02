import { Link } from 'react-router-dom'
import {
  Box,
  Flex,
  HStack,
  IconButton,
  useDisclosure,
  useColorModeValue,
  Stack,
  Heading,
  Text,
} from '@chakra-ui/react'
import { HamburgerIcon, CloseIcon } from '@chakra-ui/icons'
import Logo from '../Icons/Logo'
import { STORE_NAME } from '../../constants'
import { useAuth } from '../../hooks/useAuth'
import LoggedInMenu from './LoggedInMenu'
import LoggedOutMenu from './LoggedOutMenu'
import ToggleLoggedIn from './ToggleLoggedIn'

interface Props {
  children: React.ReactNode
}

const LINKS = ['Home', 'About', 'Products']

const NavLink = (props: Props) => {
  const { children } = props
  return (
    <Box
      as="a"
      px={2}
      py={1}
      rounded={'md'}
      _hover={{
        textDecoration: 'none',
        bg: useColorModeValue('navy.200', 'navy.500'),
      }}
      href={'#'}
    >
      {children}
    </Box>
  )
}

export default function Header() {
  const { isOpen, onOpen, onClose } = useDisclosure()
  const { isLoggedIn } = useAuth()

  return (
    <>
      <Box
        bg={useColorModeValue('navy.400', 'beige.400')}
        color={useColorModeValue('beige.100', 'navy.400')}
        px={4}
        minHeight="70px"
      >
        <Flex h={16} alignItems={'center'} justifyContent={'space-between'}>
          <IconButton
            size={'md'}
            icon={isOpen ? <CloseIcon /> : <HamburgerIcon />}
            bgColor={'orange.400'}
            aria-label={'Open Menu'}
            display={{ md: 'none' }}
            onClick={isOpen ? onClose : onOpen}
          />
          <HStack spacing={8} alignItems={'center'}>
            <HStack
              as={'nav'}
              spacing={4}
              display={{ base: 'none', md: 'flex' }}
            >
              <Link to="/home">
                <Logo fill={useColorModeValue('beige.400', 'navy.400')} />
              </Link>
              <Link to="/home">
                <Heading size={'lg'}>{STORE_NAME}</Heading>
              </Link>
            </HStack>
            <HStack
              as={'nav'}
              spacing={4}
              display={{ base: 'none', md: 'flex' }}
            >
              {LINKS.map((link) => (
                <Link to={`/${link.toLowerCase()}`} key={link}>
                  <Text fontWeight={600}>{link}</Text>
                </Link>
              ))}
              <ToggleLoggedIn />
            </HStack>
          </HStack>
          {isLoggedIn ? <LoggedInMenu /> : <LoggedOutMenu />}
        </Flex>

        {isOpen ? (
          <Box pb={4} display={{ md: 'none' }}>
            <Stack as={'nav'} spacing={4}>
              {LINKS.map((link) => (
                <NavLink key={link}>{link}</NavLink>
              ))}
            </Stack>
          </Box>
        ) : null}
      </Box>
    </>
  )
}
