import { Resolvers } from "../__generated__/resolvers-types.js";
import { REVIEWS } from "./data";

export const getReviewsById = (reviewId:string) => REVIEWS.find((it) => it.id === reviewId);
export const getReviewsByProductUpc = (productUpc:string) => REVIEWS.filter((it) => it.product.upc === productUpc);

export const resolvers:Resolvers = {
  Review: {
    __resolveReference: (ref) => getReviewsById(ref.id)
  },
  Product: {
    reviews: (parent) => getReviewsByProductUpc(parent.upc)
  }
};
