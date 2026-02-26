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
export declare const PROMOTIONS: Promotion[];
//# sourceMappingURL=data.d.ts.map