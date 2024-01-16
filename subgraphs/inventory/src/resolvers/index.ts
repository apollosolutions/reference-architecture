import { Resolvers } from "../__generated__/resolvers-types";
import { INVENTORY } from "./data";

export const resolvers:Resolvers = {
  Variant: {
    inventory: (v) => {
      const inv = INVENTORY.find((i) => i.id === v.id);

      if (!inv) return null;

      return {
        inStock: inv.inventory > 0,
        inventory: inv.inventory,
      };
    },
  },
};
