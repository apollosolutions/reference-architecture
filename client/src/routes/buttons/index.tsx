import {
  Box,
  Button,
  ButtonProps,
  Container,
  Grid,
  GridItem,
  Text,
} from '@chakra-ui/react'

const variants = ['solid', 'outline', 'ghost', 'link']
const colors = ['beige', 'navy', 'orange']

const buttons = variants.reduce((allButtons, variant) => {
  allButtons.push({ variant })
  const variantColors: ButtonProps[] = colors.map((color) => {
    return {
      variant,
      colorScheme: color,
    } as ButtonProps
  })
  allButtons.push(...variantColors)
  return allButtons
}, [] as ButtonProps[])

export const RouteComponent = () => {
  return (
    <>
      <Container bg="beige.400" maxW={'3xl'}>
        <Box padding="10" maxW="xl">
          <Text>
            Buttons appear to use the 600 weight of colors defined in a color
            scheme
          </Text>
          <Grid templateColumns="repeat(4, 1fr)" gap={6}>
            {buttons.map((buttonProps, k) => {
              return (
                <GridItem key={k}>
                  <Button {...buttonProps}>
                    <Text>{Object.values(buttonProps).join(' ')}</Text>
                  </Button>
                </GridItem>
              )
            })}
          </Grid>
        </Box>
      </Container>

      <Container bg="navy.400" maxW={'3xl'}>
        <Box padding="10" maxW="xl">
          <Grid templateColumns="repeat(4, 1fr)" gap={6}>
            {buttons.map((buttonProps, k) => {
              return (
                <GridItem key={k}>
                  <Button {...buttonProps}>
                    <Text>{Object.values(buttonProps).join(' ')}</Text>
                  </Button>
                </GridItem>
              )
            })}
          </Grid>
        </Box>
      </Container>
    </>
  )
}
