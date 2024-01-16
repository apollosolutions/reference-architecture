import { Resolvers } from "../__generated__/resolvers-types";

export const resolvers:Resolvers = {
  Order: {
    // Simulate calculating costs with some added randomness
    shippingCost: (parent) => {
      const variantCost = parent.items.map(it => getCostToShipToAddress(it.weight, parent.buyer.shippingAddress));
      const totalCost = variantCost.reduce((prev, cur) => prev + cur, 0);
      return totalCost + (Math.floor(Math.random() * 10));
    },
  },
};


// Simulate calculating real shipping costs from an address
// Just turn address string size to a number for simple math
const getCostToShipToAddress = (weight:number, address:string) => {
  return weight * address.length;
};
