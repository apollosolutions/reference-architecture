import {
  Route,
  createBrowserRouter,
  createRoutesFromElements,
} from 'react-router-dom'

import * as RootRoute from './routes/root'
import * as HomeRoute from './routes/home'
import * as AboutRoute from './routes/about'
import * as ProductsRoute from './routes/products'
import * as UserProfileRoute from './routes/user-profile'
import * as LoginRoute from './routes/login'
import * as LogoutRoute from './routes/logout'

import ErrorPage from './components/Error'

// UI Building
import * as ButtonsRoute from './routes/buttons'

const routes = createRoutesFromElements(
  <Route path="/" errorElement={<ErrorPage />}>
    {/* Wraps around every path providing high-level layout control*/}
    <Route element={<RootRoute.RouteComponent />}>
      {/* This is rendered in the "main" outlet inside the RootRoute */}
      <Route index element={<HomeRoute.RouteComponent />} />

      {/* Defining various pages, the route components wrap other components to encapsulate route-specific logic */}
      <Route path="/home" element={<HomeRoute.RouteComponent />} />
      <Route path="/about" element={<AboutRoute.RouteComponent />} />
      <Route path="/products" element={<ProductsRoute.RouteComponent />} />

      {/* User Routes */}
      <Route path="/profile" element={<UserProfileRoute.RouteComponent />} />
      <Route path="/login" element={<LoginRoute.RouteComponent />} />
      <Route path="/logout" element={<LogoutRoute.RouteComponent />} />

      {/* UI Building/testing, kind of a storybook light */}
      <Route path="/buttons" element={<ButtonsRoute.RouteComponent />} />
    </Route>
  </Route>
)
export const router = createBrowserRouter(routes)
