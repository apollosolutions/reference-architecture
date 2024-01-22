import { Outlet } from 'react-router-dom'
import Header from '../components/Header'
import Footer from '../components/Footer'

export const RouteComponent = () => {
  return (
    <>
      <Header />
      <div className="screen-aware-full-height">
        <Outlet />
      </div>
      <Footer />
    </>
  )
}
