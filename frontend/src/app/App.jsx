import { useEffect, useState } from "react";
import Splash from "../pages/Splash";
import Dashboard from "../pages/Dashboard";
import AppLayout from "./AppLayout";

export default function App() {
  const [showSplash, setShowSplash] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => {
      setShowSplash(false);
    }, 2000);
    return () => clearTimeout(timer);
  }, []);

  return (
    <AppLayout>
      {showSplash ? <Splash /> : <Dashboard />}
    </AppLayout>
  );
}
