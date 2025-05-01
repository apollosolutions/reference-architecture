import { Link } from 'react-router-dom'
import { Flex, Spacer, Button } from '@chakra-ui/react'
import { AddIcon } from '@chakra-ui/icons'
import { ShoppingCart } from '../Icons/ShoppingCart'

const link = 'Login'
export default function LoggedOutMenu() {
  return (
    <Flex alignItems={'center'} width={'200px'}>
      <Link to={`/${link.toLowerCase()}`} key={link}>
        Hello, sign in
      </Link>
      <Spacer />
      <Button
        variant={'solid'}
        bgColor={'orange.400'}
        color={'navy.400'}
        size={'sm'}
        mr={4}
        leftIcon={<AddIcon />}
      >
        <ShoppingCart />
      </Button>
    </Flex>
  )
}
