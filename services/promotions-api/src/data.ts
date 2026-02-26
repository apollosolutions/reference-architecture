/**
 * Mock promotions data - maps product IDs to active promotions.
 * In production, this would come from a database or external service.
 */
export interface Promotion {
  id: string;
  name: string;
  description: string;
  discountType: "PERCENTAGE" | "FIXED";
  value: number;
  productIds: string[];
  minPurchase?: number;
}

export const PROMOTIONS: Promotion[] = [
  {
    id: "promo:1",
    name: "Sneaker Sale",
    description: "20% off all sneakers",
    discountType: "PERCENTAGE",
    value: 20,
    productIds: ["product:1", "product:4", "product:5"],
  },
  {
    id: "promo:2",
    name: "Luxury Watch Deal",
    description: "$500 off luxury watches",
    discountType: "FIXED",
    value: 500,
    productIds: ["product:3"],
  },
  {
    id: "promo:3",
    name: "Supreme Collaboration",
    description: "15% off Supreme collabs",
    discountType: "PERCENTAGE",
    value: 15,
    productIds: ["product:2"],
  },
  {
    id: "promo:4",
    name: "Cart Saver",
    description: "10% off orders over $200",
    discountType: "PERCENTAGE",
    value: 10,
    productIds: [],
    minPurchase: 200,
  },
];
