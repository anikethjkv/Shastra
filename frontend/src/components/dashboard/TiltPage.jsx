import { useVehicleStore } from "../../store/vehicleStore";
import { useEffect, useState } from "react";
import "../../styles/tilt.css";
import bike from "../../assets/bike-front.png";

export default function TiltPage() {

  const tiltX = useVehicleStore((state) => state.tiltX);

  const angle = Math.max(-90, Math.min(90, tiltX));

  const [maxLeft, setMaxLeft] = useState(0);
  const [maxRight, setMaxRight] = useState(0);

  useEffect(() => {

    if (angle < maxLeft) setMaxLeft(angle);

    if (angle > maxRight) setMaxRight(angle);

  }, [angle]);

  return (

    <div className="tilt-page">

      {/* LEAN ARC */}

      <div className="lean-meter">

        <div className="arc">

          <div
            className="needle"
            style={{ transform: `rotate(${angle}deg)` }}
          ></div>

        </div>

        <div className="bike-container">

          <img
            src={bike}
            alt="bike"
            className="tilt-bike"
            style={{ transform: `rotate(${angle}deg)` }}
          />

        </div>

      </div>


      {/* CURRENT ANGLE */}

      <div className="tilt-angle">

        {angle.toFixed(1)}°

      </div>


      {/* LEAN BARS */}

      <div className="lean-bars">

        <div className="lean-bar left">

          <div
            className="bar-fill"
            style={{
              height: `${Math.abs(Math.min(angle,0))}%`
            }}
          ></div>

        </div>

        <div className="lean-bar right">

          <div
            className="bar-fill"
            style={{
              height: `${Math.max(angle,0)}%`
            }}
          ></div>

        </div>

      </div>


      {/* MAX LEAN */}

      <div className="max-lean">

        <div className="max-box">

          MAX L

          <span>{maxLeft.toFixed(1)}°</span>

        </div>

        <div className="max-box">

          MAX R

          <span>{maxRight.toFixed(1)}°</span>

        </div>

      </div>

    </div>

  );

}