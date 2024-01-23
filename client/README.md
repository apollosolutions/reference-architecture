# Apollo Customer Success Demos

## Client

### Design

- [/login modeled after /contact-sales](https://www.apollographql.com/contact-sales)
- [/profile modeled after /signup](https://www.apollographql.com/signup)

### Getting Started

```shell
npm install
npm run dev
```

Links for installed packages:

- [Vite](https://vitejs.dev/)
- [Tailwind CSS](https://tailwindcss.com/docs/theme)
- [Vite + Tailwind](https://tailwindcss.com/docs/guides/vite)
- [Chakra UI](https://chakra-ui.com/docs/components)
- [React Router](https://reactrouter.com/en/main)
- [`clsx``](https://github.com/lukeed/clsx)
- [Lorem Ipsum](https://loremipsum.io/)

Other tools utilized:

- [Chakra UI Theming tool for colors](https://themera.vercel.app/)
- [Volta](https://volta.sh/)
- [Pravatar - Placeholder avatars](https://pravatar.cc/)
- [Sandbox for ChakraUI](https://codesandbox.io/s/chakra-ui-typescript-pomi8?file=/src/index.tsx)

Other frameworks considered but ultimately not chosen:

- [redwood.js](https://redwoodjs.com/)
- [next.js](https://nextjs.org/)
- [create.t3.gg](https://create.t3.gg/)
- [DaisyUI Component Library](https://daisyui.com/)
- [Vike Router](https://vike.dev/add)
- [Ant-Design - An enterprise-class UI design language and React UI library](https://www.npmjs.com/package/antd)
- [Tailwind & Headless UI](https://headlessui.com/)

Other resources:

- New apollographql.com scss for use in overriding other css frameworks - [New Branding](https://github.com/apollographql/www/blob/main/src/css/global.scss)
- [Auth in React](https://auth0.com/blog/complete-guide-to-react-user-authentication/)

### React + TypeScript + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react/README.md) uses [Babel](https://babeljs.io/) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## Expanding the ESLint configuration

If you are developing a production application, we recommend updating the configuration to enable type aware lint rules:

- Configure the top-level `parserOptions` property like this:

```js
   parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
    project: ['./tsconfig.json', './tsconfig.node.json'],
    tsconfigRootDir: __dirname,
   },
```

- Replace `plugin:@typescript-eslint/recommended` to `plugin:@typescript-eslint/recommended-type-checked` or `plugin:@typescript-eslint/strict-type-checked`
- Optionally add `plugin:@typescript-eslint/stylistic-type-checked`
- Install [eslint-plugin-react](https://github.com/jsx-eslint/eslint-plugin-react) and add `plugin:react/recommended` & `plugin:react/jsx-runtime` to the `extends` list
