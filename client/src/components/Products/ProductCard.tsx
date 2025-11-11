import {
  Heading,
  Button,
  Card,
  CardHeader,
  CardBody,
  CardFooter,
  Center,
  Flex,
  HStack,
  Image,
  Text,
  Spacer,
} from '@chakra-ui/react'
import ShowMoreText from 'react-show-more-text'
import { StarIcon } from '../Icons/Star'
import { Product } from '../../apollo/types'
import { useCart } from '../../hooks/useCart'

type ProductCardProps = {
  product: Product
}
export default function ProductCard(props: ProductCardProps) {
  const { product } = props
  const { addToCart, addingToCart } = useCart()
  const productDescription = product.description.padEnd(125)
  const firstVariant = product?.variants?.[0]

  const handleAddToCart = () => {
    if (firstVariant?.id) {
      addToCart(String(firstVariant.id), 1)
    }
  }

  return (
    <Card
      variant="elevated"
      bg="navy.400"
      borderRadius={'xl'}
      color="beige.400"
      height="100%"
      display="flex"
      flexDirection="column"
      overflow="hidden"
    >
      <CardHeader p={{ base: 2, md: 4 }} pb={0}>
        <Center>
          <Image
            src={product.mediaUrl}
            alt={product.title}
            objectFit={'cover'}
            align={'center'}
            maxH={{ base: '200px', md: '300px' }}
            w="100%"
            borderRadius="md"
          />
        </Center>
      </CardHeader>
      <CardBody bg="navy.300" borderTopRadius={'xl'} flex="1" p={{ base: 3, md: 6 }} pt={{ base: 4, md: 6 }}>
        <Flex direction={{ base: 'column', sm: 'row' }} gap={2} mb={2}>
          <Heading size={{ base: 'sm', md: 'md' }} flex="1">
            {product.title}
          </Heading>
          <HStack spacing={1}>
            {Array.from({ length: 5 }, (_, i) => (
              <StarIcon key={i} fill={i < 4 ? 'beige' : 'transparent'} />
            ))}
          </HStack>
        </Flex>
        <ShowMoreText
          lines={1}
          more="Show more"
          less="Show less"
          className="ml-0 m-4"
          anchorClass="show-more-less-clickable"
          expanded={false}
          width={700}
          truncatedEndingComponent={'... '}
        >
          <Text fontSize={{ base: 'sm', md: 'xl' }}>{productDescription}</Text>
        </ShowMoreText>
      </CardBody>
      <CardFooter bg="navy.300" borderBottomRadius={'xl'} p={{ base: 3, md: 6 }}>
        <Flex w="100%" direction={{ base: 'column', sm: 'row' }} gap={3} align="center">
          <Heading size={{ base: 'md', md: 'lg' }}>${firstVariant?.price || '0.00'}</Heading>
          <Spacer display={{ base: 'none', sm: 'block' }} />
          <Button
            variant="outline"
            color="beige.400"
            borderColor={'beige.400'}
            rounded={'full'}
            size={{ base: 'md', md: 'lg' }}
            borderWidth={'2px'}
            w={{ base: '100%', sm: 'auto' }}
            isLoading={addingToCart}
            loadingText="Adding..."
            onClick={handleAddToCart}
            disabled={!firstVariant?.id}
            _hover={{
              bg: 'beige.400',
              color: 'navy.400',
            }}
          >
            Add to cart
          </Button>
        </Flex>
      </CardFooter>
    </Card>
  )
}
