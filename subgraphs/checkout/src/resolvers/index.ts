import { Resolvers } from "../__generated__/resolvers-types.js";
import { GraphQLError } from "graphql";
import { activeCarts } from "./data.js";

const getCartByUserId = (id:string) => activeCarts.find((it) => it.userId === id);

export const resolvers:Resolvers = {
  User: {
    cart: (parent) => getCartByUserId(parent.id)
  },
  Cart: {
    subtotal: (parent) => {
      const items = parent.items ?? [];
      return items
        ?.map(item => item.price ?? 0)
        ?.reduce((total, price) => total + price, 0);
    }
  },
  Mutation: {
    cart: () => ({})
  },
  CartMutations: {
    checkout: (_, { paymentMethodId }, { user }) => {
      if (!user || !user.sub) {
        throw new GraphQLError("Authentication required", {
          extensions: {
            code: "UNAUTHENTICATED",
            http: { status: 401 },
          },
        });
      }

      const userId = user.sub as string;
      const cart = getCartByUserId(userId);
      
      if (!cart || !cart.items || cart.items.length === 0) {
        return {
          successful: false,
          orderID: null
        };
      }

      // In a real implementation, this would create an order
      return {
        successful: true,
        orderID: 'mockOderId123'
      };
    },
    addVariantToCart: (_, { variantId, quantity }, { user }) => {
      if (!user || !user.sub) {
        throw new GraphQLError("Authentication required", {
          extensions: {
            code: "UNAUTHENTICATED",
            http: { status: 401 },
          },
        });
      }

      const userId = user.sub as string;
      // In a real implementation, this would add the variant to the user's cart
      return {
        successful: true,
        message: `MOCK: Added variant ${variantId} to cart`
      };
    },
    removeVariantFromCart: (_, { variantId, quantity }, { user }) => {
      if (!user || !user.sub) {
        throw new GraphQLError("Authentication required", {
          extensions: {
            code: "UNAUTHENTICATED",
            http: { status: 401 },
          },
        });
      }

      const userId = user.sub as string;
      // In a real implementation, this would remove the variant from the user's cart
      return {
        successful: true,
        message: `MOCK: Removed variant ${variantId} from cart`
      };
    },
  }
};
