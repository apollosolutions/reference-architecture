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

type ProductCardProps = {
  product: Product
}
export default function ProductCard(props: ProductCardProps) {
  const { product } = props
  const productDescription = product.description.padEnd(125)
  return (
    <Card
      variant="elevated"
      bg="navy.400"
      borderRadius={'xl'}
      color="beige.400"
    >
      <CardHeader>
        <Center>
          <Image
            src={product.mediaUrl}
            alt="My alt message"
            objectFit={'cover'}
            align={'center'}
            marginTop={'-70px'}
            marginBottom={'-30px'}
          />
        </Center>
      </CardHeader>
      <CardBody bg="navy.300" borderTopRadius={'xl'}>
        <Flex>
          <Heading>{product.title}</Heading>
          <Spacer />
          <HStack>
            {Array.from({ length: 5 }, (_, i) => (
              <StarIcon key={i} fill={i < 4 ? 'beige' : 'transparent'} />
            ))}
          </HStack>
        </Flex>
        <ShowMoreText
          /* Default options */
          lines={1}
          more="Show more"
          less="Show less"
          className="ml-0 m-4"
          anchorClass="show-more-less-clickable"
          expanded={false}
          width={700}
          truncatedEndingComponent={'... '}
        >
          <Text fontSize="xl">{productDescription}</Text>
        </ShowMoreText>
      </CardBody>
      <CardFooter bg="navy.300" borderBottomRadius={'xl'}>
        <Flex w="100%">
          <Heading>${product?.variants[0].price}</Heading>
          <Spacer />
          <Button
            variant="outline"
            color="beige.400"
            borderColor={'beige.400'}
            rounded={'full'}
            size={'lg'}
            borderWidth={'2px'}
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
