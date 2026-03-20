import "../styles/splash.css";
import jssLogo from "../assets/jssate.png";

export default function Splash() {
  return (
    <div className="splash">
      <img
        src={jssLogo}
        alt="JSSATE Bengaluru"
        className="splash-image"
        draggable="false"
      />
    </div>
  );
}
