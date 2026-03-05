import { Resolvers } from "../__generated__/resolvers-types.js";
import { GraphQLError } from "graphql";
import { orders } from "./data";

const getOrderById = (id:string) => orders.find((it) => it.id === id);

export const resolvers:Resolvers = {
  Query: {
    order(_, { id }, { user }) {
      const order = getOrderById(id);
      
      if (!order) {
        throw new GraphQLError("Order not found");
      }

      // Resource-level authorization: users can only access their own orders
      if (user && user.sub) {
        const userId = user.sub as string;
        if (order.buyer.id !== userId) {
          throw new GraphQLError("Access denied: You can only view your own orders", {
            extensions: {
              code: "FORBIDDEN",
              http: { status: 403 },
            },
          });
        }
      }

      return order;
    },
  },
  Order: {
    __resolveReference(ref) {
      return getOrderById(ref.id);
    },
  },
};
