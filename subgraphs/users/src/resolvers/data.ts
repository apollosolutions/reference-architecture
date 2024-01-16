export type DataUserType = {
  id: string;
  username: string;
  paymentMethods: DataPaymentMethodType[];
  cart: DataCartType;
  orders: DataOrderType[];
  shippingAddress: string;
  email: string;
}
type DataPaymentMethodType = {
  id: string;
  name: string;
  type: string;
}
type DataCartType = {
  items?: DataVariantType[];
}
type DataOrderType = {
  id: string;
}
type DataVariantType = {
  id: string
}

export const users = [
  {
    id: "user:1",
    username: "user1",
    paymentMethods: [
      {
        id: "paymentMethod:1",
        name: "User One's first credit card",
        type: "CREDIT_CARD",
      },
      {
        id: "paymentMethod:2",
        name: "User One's second credit card",
        type: "CREDIT_CARD",
      },
    ],
    cart: {
      items: [{ id: "variant:1" }, { id: "variant:2" }],
      subtotal: 1200.5,
    },
    orders: [{ id: "order:1" }, { id: "order:2" }],
    shippingAddress: "123 Main St",
    email: "user1@contoso.org"
  },
  {
    id: "user:2",
    username: "user2",
    paymentMethods: [
      {
        id: "paymentMethod:3",
        name: "User Two's first debit card",
        type: "DEBIT_CARD",
      },
    ],
    cart: {
      items: [{ id: "variant:1" }],
      subtotal: 600.25,
    },
    orders: [{ id: "order:3" }],
    shippingAddress: "123 Main St",
    email: "user2@contoso.org"
  },
  
  {
    id: "user:3",
    username: "user3",
    paymentMethods: [
      {
        id: "paymentMethod:4",
        name: "User Three's first debit card",
        type: "DEBIT_CARD",
      },
      {
        id: "paymentMethod:5",
        name: "User Three's first bank account",
        type: "BANK_ACCOUNT",
      },
    ],
    cart: {},
    orders: [{ id: "order:4" }, { id: "order:5" }, { id: "order:6" }],
    shippingAddress: "123 Main St",
    email: "user3@contoso.org"
  },
];
