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
    productIds: ["product:1"],
  },
  {
    id: "promo:2",
    name: "Supreme Collaboration",
    description: "15% off Supreme collabs",
    discountType: "PERCENTAGE",
    value: 15,
    productIds: ["product:2"],
  },
];
