import { useMutation } from '@apollo/client'
import { useToast } from '@chakra-ui/react'
import { MUTATIONS } from '../apollo/queries'
import { QUERIES } from '../apollo/queries'
import { useAuth } from './useAuth'

export const useCart = () => {
  const { isLoggedIn, user } = useAuth()
  const toast = useToast()

  const headers: { [key: string]: string } = {
    'x-user-id': 'user:1',
  }
  if (user && user.token) {
    headers.authorization = `Bearer ${user.token}`
  }

  const [addVariantToCartMutation, { loading: addingToCart }] = useMutation(
    MUTATIONS.ADD_VARIANT_TO_CART,
    {
      refetchQueries: [
        {
          query: QUERIES.USER_PROFILE_FULL,
          context: {
            headers,
          },
        },
      ],
      onCompleted: (data: any) => {
        if (data?.cart?.addVariantToCart?.successful) {
          toast({
            title: 'Item added to cart',
            description: data.cart.addVariantToCart.message || 'Item successfully added to your cart',
            status: 'success',
            duration: 3000,
            isClosable: true,
          })
        } else {
          toast({
            title: 'Failed to add item',
            description: data?.cart?.addVariantToCart?.message || 'Unable to add item to cart',
            status: 'error',
            duration: 3000,
            isClosable: true,
          })
        }
      },
      onError: (error: any) => {
        toast({
          title: 'Error',
          description: error.message || 'Failed to add item to cart',
          status: 'error',
          duration: 3000,
          isClosable: true,
        })
      },
    }
  )

  const addToCart = (variantId: string, quantity: number = 1) => {
    if (!isLoggedIn || !user || !user.token) {
      toast({
        title: 'Please log in',
        description: 'You need to be logged in to add items to your cart',
        status: 'warning',
        duration: 3000,
        isClosable: true,
      })
      return
    }

    addVariantToCartMutation({
      variables: {
        variantId,
        quantity,
      },
      context: {
        headers,
      },
    })
  }

  return {
    addToCart,
    addingToCart,
    isLoggedIn,
  }
}

