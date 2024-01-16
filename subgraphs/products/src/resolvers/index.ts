import { Resolvers } from "../__generated__/resolvers-types.js";
import {PRODUCTS, VARIANTS} from "./data";

export const getVariantById = (id:string) => VARIANTS.find((it) => it.id === id);
export const getProductById = (id:string) => PRODUCTS.find((it) => it.id === id);

export const resolvers:Resolvers = {
  Query: {
    product: (_, { id }) => getProductById(id),
    variant: (_, { id }) => getVariantById(id),
    searchVariants(_, { searchInput }) {
      if (searchInput?.sizeStartsWith) {
        return VARIANTS.filter((v) =>
          v.size.startsWith(searchInput.sizeStartsWith)
        );
      }

      return VARIANTS;
    },
    searchProducts(_, { searchInput }) {
      if (searchInput?.titleStartsWith) {
        return PRODUCTS.filter((p) =>
          p.title.startsWith(searchInput.titleStartsWith)
        );
      }

      return PRODUCTS;
    },
  },
  Product: {
    __resolveReference(ref) {
      // @ts-ignore
      return getProductById(ref.id || ref.upc);
    },
    upc: (parent) => parent.id,
    variants(parent, { searchInput }) {
      const variants = getProductById(parent.id).variants.map((it) =>
        getVariantById(it.id)
      );

      if (searchInput?.sizeStartsWith) {
        return variants.filter((it) =>
          it.size.startsWith(searchInput.sizeStartsWith)
        );
      }
      return variants;
    },
    releaseDate: () => getRandomDate().toISOString()
  },
  Variant: {
    __resolveReference(ref) {
      return getVariantById(ref.id);
    },
    product(parent) {
      const productId = getVariantById(parent.id).product.id;
      return getProductById(productId);
    },
  },
};

const getRandomDate = () => {
  // Get a random number between -10 and 10
  const randomDays = Math.floor(Math.random() * 20) - 10;
  const today = new Date();

  // Add the random number of days to today's date
  return new Date(today.getTime() + randomDays * 24 * 60 * 60 * 1000);
}
