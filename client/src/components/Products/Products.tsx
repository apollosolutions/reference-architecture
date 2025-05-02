import { Container, Grid, GridItem } from '@chakra-ui/react'
import { useQuery } from '@apollo/client'
import { QUERIES } from '../../apollo/queries'
import { Product } from '../../apollo/types'
import ProductCard from './ProductCard'

type ProductSearch = {
  searchProducts: Array<Product>
}
type ProductListingProps = {
  data: ProductSearch
}
const ProductListing = (props: ProductListingProps) => {
  const {
    data = {
      searchProducts: [],
    },
  } = props

  return (
    <Container maxW={'container.xl'} centerContent>
      <Grid templateColumns="repeat(2, 1fr)" gap={10}>
        {data.searchProducts.map((product) => {
          return (
            <GridItem key={product.id}>
              <ProductCard product={product} />
            </GridItem>
          )
        })}
      </Grid>
    </Container>
  )
}

export default function Products() {
  const { loading, error, data } = useQuery(QUERIES.SEARCH_PRODUCTS, {
    variables: {},
    errorPolicy: 'all',
  })

  if (loading) {
    return <span className="loading loading-ring loading-lg"></span>
  }

  if (error) {
    return (
      <div className="alert alert-error">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          className="stroke-current shrink-0 h-6 w-6"
          fill="none"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="2"
            d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        <span>Error! Task failed:</span>
        <pre>{JSON.stringify(error, null, 2)}</pre>
      </div>
    )
  }

  if (!loading && !error) {
    return (
      <>
        <ProductListing data={data} />
      </>
    )
  }
  return null
}
