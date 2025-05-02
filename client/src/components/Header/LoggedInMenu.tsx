import { Link } from 'react-router-dom'
import {
  Avatar,
  Button,
  Menu,
  MenuButton,
  MenuList,
  MenuItem,
  MenuDivider,
  Text,
  HStack,
  Flex,
  Spacer,
  useColorMode,
  useColorModeValue,
} from '@chakra-ui/react'
import { AtSignIcon, AddIcon, SunIcon, MoonIcon } from '@chakra-ui/icons'
import { ShoppingCart } from '../Icons/ShoppingCart'
import { useAuth } from '../../hooks/useAuth'

const ColorModeToggle = () => {
  const { colorMode, toggleColorMode } = useColorMode()
  return (
    <Button
      size={'md'}
      color={colorMode === 'light' ? 'orange.400' : 'navy.400'}
      bgColor={colorMode === 'light' ? 'beige.400' : 'orange.400'}
      onClick={toggleColorMode}
    >
      {colorMode === 'light' ? <MoonIcon /> : <SunIcon />}
    </Button>
  )
}

export default function LoggedInMenu() {
  const { logout } = useAuth()
  return (
    <Flex alignItems={'center'} width={'275px'}>
      <Menu>
        <MenuButton
          as={Button}
          rounded={'full'}
          variant={'link'}
          cursor={'pointer'}
          minW={0}
        >
          <HStack color={useColorModeValue('beige.400', 'navy.400')}>
            <Text>Welcome</Text>
            <Avatar
              size={'md'}
              src={
                'https://images.unsplash.com/photo-1493666438817-866a91353ca9?ixlib=rb-0.3.5&q=80&fm=jpg&crop=faces&fit=crop&h=200&w=200&s=b616b2c5b373a80ffc9636ba24f7a4a9'
              }
            />
          </HStack>
        </MenuButton>
        <MenuList>
          <Link to="/profile">
            <MenuItem icon={<AtSignIcon />}>Profile</MenuItem>
          </Link>
          <MenuDivider />
          <MenuItem onClick={() => logout()}>Logout</MenuItem>
        </MenuList>
      </Menu>
      <Spacer />
      <Button
        variant={'solid'}
        bgColor={'orange.400'}
        color={'navy.400'}
        size={'md'}
        mr={4}
        leftIcon={<AddIcon />}
      >
        <ShoppingCart />
      </Button>
      <ColorModeToggle />
    </Flex>
  )
}
