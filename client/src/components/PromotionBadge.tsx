import { Badge } from '@chakra-ui/react'
import { Promotion } from '../apollo/types'

type PromotionBadgeProps = {
  promo: Promotion
  /** Tighter padding for inline contexts (e.g. cart). Default uses slightly more padding. */
  size?: 'compact' | 'default'
}

export function PromotionBadge({ promo, size = 'default' }: PromotionBadgeProps) {
  const label =
    promo.discountType === 'PERCENTAGE'
      ? `${promo.value}% off`
      : `$${promo.value} off`

  return (
    <Badge
      colorScheme="orange"
      variant="solid"
      fontSize="sm"
      fontWeight="bold"
      px={3}
      py={size === 'compact' ? 1 : 1.5}
      borderRadius="md"
      title={promo.description}
      boxShadow="md"
      textTransform="uppercase"
      letterSpacing="wider"
    >
      {label}
    </Badge>
  )
}
