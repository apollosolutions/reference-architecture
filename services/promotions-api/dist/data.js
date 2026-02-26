"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PROMOTIONS = void 0;
exports.PROMOTIONS = [
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
