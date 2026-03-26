export type Promotion = {
  id: string
  name: string
  description: string
  discountType: 'PERCENTAGE' | 'FIXED'
  value: number
}

export type Product = {
  id: string
  upc: string
  title: string
  description: string
  mediaUrl: string
  releaseDate: string
  promotions?: Promotion[]
  variants: Variant[]
}

export type Variant = {
  id: number
  product: Product
  colorway: string
  price: number
  size: string
  dimensions: string
  weight: number
}
