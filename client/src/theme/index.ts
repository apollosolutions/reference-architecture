// theme/index.js
import { extendTheme, type ThemeConfig } from '@chakra-ui/react'

// Global style overrides
import styles from './styles'
import colors from './foundations/colors'
import fonts from './fonts'
import borders from './foundations/borders'
import components from './components'

const config: ThemeConfig = {
  initialColorMode: 'system',
  useSystemColorMode: false,
}

const overrides = {
  config,
  styles,
  fonts,
  colors,
  borders,
  components,
}

export default extendTheme(overrides)
