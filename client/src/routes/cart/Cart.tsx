import {
  Container,
  Heading,
  VStack,
  Text,
  Image,
  Button,
  Card,
  CardBody,
  CardFooter,
  Flex,
  Divider,
  useColorModeValue,
  Alert,
  AlertIcon,
  Spinner,
  Center,
} from '@chakra-ui/react'
import { useQuery } from '@apollo/client'
import { QUERIES } from '../../apollo/queries'
import { User } from '../../hooks/useAuth'

type Props = {
  user: User
}

export default function Cart(props: Props) {
  const { user } = props
  const cardBg = useColorModeValue('white', 'navy.400')

  const headers: { [key: string]: string } = {
    'x-user-id': 'user:1',
  }
  if (user && user.token) {
    headers.authorization = `Bearer ${user.token}`
  }

  const { loading, error, data } = useQuery(QUERIES.USER_PROFILE_FULL, {
    context: {
      headers,
    },
    variables: {},
    errorPolicy: 'all',
    skip: !user || !user.token,
  })

  if (loading) {
    return (
      <Container maxW="container.xl" py={8}>
        <Center>
          <Spinner size="xl" />
        </Center>
      </Container>
    )
  }

  if (error) {
    return (
      <Container maxW="container.xl" py={8}>
        <Alert status="error">
          <AlertIcon />
          Error loading cart: {error.message}
        </Alert>
      </Container>
    )
  }

  const cart = data?.user?.cart
  const items = cart?.items || []
  const subtotal = cart?.subtotal || 0

  return (
    <Container maxW="container.xl" py={8}>
      <VStack spacing={6} align="stretch">
        <Heading size="xl" color={useColorModeValue('navy.400', 'beige.400')}>
          Shopping Cart
        </Heading>

        {items.length === 0 ? (
          <Card bg={cardBg}>
            <CardBody>
              <Alert status="info">
                <AlertIcon />
                Your cart is empty
              </Alert>
            </CardBody>
          </Card>
        ) : (
          <>
            <VStack spacing={4} align="stretch">
              {items.map((item: any) => (
                <Card key={item.id} bg={cardBg}>
                  <CardBody>
                    <Flex direction={{ base: 'column', md: 'row' }} gap={4}>
                      {item.product?.mediaUrl && (
                        <Image
                          src={item.product.mediaUrl}
                          alt={item.product?.title || 'Product'}
                          boxSize={{ base: '100px', md: '150px' }}
                          objectFit="cover"
                          borderRadius="md"
                        />
                      )}
                      <VStack align="start" flex="1" spacing={2}>
                        <Heading size="md">{item.product?.title || 'Product'}</Heading>
                        {item.product?.description && (
                          <Text fontSize="sm" color="gray.500" noOfLines={2}>
                            {item.product.description}
                          </Text>
                        )}
                        {item.colorway && (
                          <Text fontSize="sm">
                            <strong>Color:</strong> {item.colorway}
                          </Text>
                        )}
                        {item.size && (
                          <Text fontSize="sm">
                            <strong>Size:</strong> {item.size}
                          </Text>
                        )}
                      </VStack>
                      <VStack align="end" spacing={2}>
                        <Heading size="lg">${item.price?.toFixed(2) || '0.00'}</Heading>
                      </VStack>
                    </Flex>
                  </CardBody>
                </Card>
              ))}
            </VStack>

            <Divider />

            <Card bg={cardBg}>
              <CardBody>
                <Flex justify="space-between" align="center">
                  <Heading size="lg">Subtotal</Heading>
                  <Heading size="xl">${subtotal.toFixed(2)}</Heading>
                </Flex>
              </CardBody>
              <CardFooter>
                <Button
                  colorScheme="orange"
                  size="lg"
                  w="full"
                  disabled={items.length === 0}
                >
                  Proceed to Checkout
                </Button>
              </CardFooter>
            </Card>
          </>
        )}
      </VStack>
    </Container>
  )
}

