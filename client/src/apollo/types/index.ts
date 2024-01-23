export type Product = {
  id: string
  upc: string
  title: string
  description: string
  mediaUrl: string
  releaseDate: string
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
