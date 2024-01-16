import { Resolvers } from "../__generated__/resolvers-types.js";
import { orders } from "./data";

const getOrderById = (id:string) => orders.find((it) => it.id === id);

export const resolvers:Resolvers = {
  Query: {
    order(_, { id }) {
      return getOrderById(id);
    },
  },
  Order: {
    __resolveReference(ref) {
      return getOrderById(ref.id);
    },
  },
};
