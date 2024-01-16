import { Resolvers } from "../__generated__/resolvers-types.js";
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
    checkout: () => ({
      successful: true,
      orderID: 'mockOderId123'
    }),
    addVariantToCart: () => ({
      successful: true,
      message: 'MOCK: Added variant to cart'
    }),
    removeVariantFromCart: () => ({
      successful: true,
      message: 'MOCK: Removed variant from cart'
    }),
  }
};
