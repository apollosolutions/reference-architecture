import type { StyleFunctionProps } from '@chakra-ui/styled-system'
import { mode } from '@chakra-ui/theme-tools'

export default {
  global: (props: StyleFunctionProps) => {
    return {
      body: {
        color: 'default',
        bg: mode('beige.400', 'navy.400')(props),
      },
    }
  },
}
