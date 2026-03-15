import { useEffect } from "react";

import RPMGauge from "../components/dashboard/RPMGauge";
import Speedometer from "../components/dashboard/Speedometer";
import Battery from "../components/dashboard/Battery";
import PhaseVoltage from "../components/dashboard/PhaseVoltage";
import StandIndicator from "../components/dashboard/StandIndicator";

import IndicatorItem from "../components/dashboard/IndicatorItem";
import TurnIndicator from "../components/dashboard/TurnIndicator";
import ParkingButton from "../components/dashboard/parkingButton";
import HighBeamIndicator from "../components/dashboard/HighBeamIndicator";
import TiltPage from "../components/dashboard/TiltPage";

import "../styles/dashboard.css";
import "../styles/indicators.css";
import "../styles/turnindicator.css";
import "../styles/HighBeam.css";
import "../styles/phaseVoltage.css";
import "../styles/stand.css";

import shastraLogo from "../assets/shastra.png";

import { useVehicleStore } from "../store/vehicleStore";

export default function Dashboard() {

  const speed = useVehicleStore((state) => state.speed);
  const setSpeed = useVehicleStore((state) => state.setSpeed);

  const mode = useVehicleStore((state) => state.mode);
  const modes = useVehicleStore((state) => state.modes);
  const setMode = useVehicleStore((state) => state.setMode);

  const temperature = useVehicleStore((state) => state.temperature);
  const networkStrength = useVehicleStore((state) => state.networkStrength);

  const batteryLevel = useVehicleStore((state) => state.batteryLevel);
  const batteryVoltage = useVehicleStore((state) => state.batteryVoltage);

  const phaseU = useVehicleStore((state) => state.phaseU);
  const phaseV = useVehicleStore((state) => state.phaseV);
  const phaseW = useVehicleStore((state) => state.phaseW);

  const standDown = useVehicleStore((state) => state.standDown);

  const highBeam = useVehicleStore((state) => state.highBeam);
  const toggleHighBeam = useVehicleStore((state) => state.toggleHighBeam);

  const leftIndicator = useVehicleStore((state) => state.leftIndicator);
  const rightIndicator = useVehicleStore((state) => state.rightIndicator);

  const hazard = useVehicleStore((state) => state.hazard);
  const toggleHazard = useVehicleStore((state) => state.toggleHazard);

  const activePage = useVehicleStore((state) => state.activePage);
  const setPage = useVehicleStore((state) => state.setPage);

  const leftSignal = hazard ? true : leftIndicator;
  const rightSignal = hazard ? true : rightIndicator;

  /* STARTUP SWEEP */

  useEffect(() => {

    let currentSpeed = 0;
    setSpeed(0);

    const startDelay = setTimeout(() => {

      const sweepUp = setInterval(() => {

        currentSpeed += 4;
        setSpeed(currentSpeed);

        if (currentSpeed >= modes[mode].maxSpeed) {

          clearInterval(sweepUp);

          const sweepDown = setInterval(() => {

            currentSpeed -= 4;
            setSpeed(currentSpeed);

            if (currentSpeed <= 0) {

              clearInterval(sweepDown);
              setSpeed(52);

            }

          }, 20);

        }

      }, 20);

    }, 800);

    return () => clearTimeout(startDelay);

  }, [mode, setSpeed, modes]);



  let tempClass = "";

  if (temperature >= 80) tempClass = "overheat";
  else if (temperature >= 60) tempClass = "yellow";


  return (

    <div className="dashboard">

      {/* LEFT SIDEBAR */}

      <div className="sidebar">

        <IndicatorItem>
          <TurnIndicator direction="left" active={leftSignal} />
        </IndicatorItem>

        <IndicatorItem>
          <HighBeamIndicator
            active={highBeam}
            toggleHighBeam={toggleHighBeam}
          />
        </IndicatorItem>

        <IndicatorItem>
          <StandIndicator standDown={standDown} />
        </IndicatorItem>

        <IndicatorItem
          active={mode === "ECO"}
          onClick={() => setMode("ECO")}
        >
          ECO
        </IndicatorItem>

        <IndicatorItem
          active={mode === "SPORT"}
          onClick={() => setMode("SPORT")}
        >
          SPORT
        </IndicatorItem>

        <IndicatorItem
          active={mode === "RACE"}
          onClick={() => setMode("RACE")}
        >
          RACE
        </IndicatorItem>

      </div>


      {/* CENTER SCREEN */}

      <div className={`center ${activePage === "gps" ? "map-mode" : ""}`}>

        {activePage === "tilt" ? (

          <TiltPage />

        ) : activePage === "gps" ? (

          <div className="map-full">

            <iframe
              title="Live Map"
              src="https://maps.google.com/maps?q=12.9716,77.5946&z=15&output=embed"
              className="map-frame-full"
            />

            <div className="map-speed-overlay">

              <div className="map-speed-value">
                {speed}
              </div>

              <div className="map-speed-unit">
                km/h
              </div>

            </div>

          </div>

        ) : (

          <>

            <div className="center-top">

              <img
                src={shastraLogo}
                alt="Shastra Logo"
                className="dashboard-logo"
              />

            </div>


            <div className="phase-row">

              <PhaseVoltage phase="U" value={phaseU} />
              <PhaseVoltage phase="V" value={phaseV} />
              <PhaseVoltage phase="W" value={phaseW} />

            </div>


            <div className="center-main">

              <div className="rpm">
                <RPMGauge />
              </div>

              <div className="battery">

                <Battery
                  level={batteryLevel}
                  voltage={batteryVoltage}
                />

              </div>

              <div className="parking-container">

                <ParkingButton
                  hazard={hazard}
                  setHazard={toggleHazard}
                />

              </div>

              <div className="speed">
                <Speedometer />
              </div>

            </div>

          </>

        )}

      </div>


      {/* RIGHT SIDEBAR */}

      <div className="sidebar">

        <IndicatorItem>
          <TurnIndicator direction="right" active={rightSignal} />
        </IndicatorItem>

        <IndicatorItem>SMOKE</IndicatorItem>

        <IndicatorItem className={`temp-indicator ${tempClass}`}>

          <svg className="temp-icon" viewBox="0 0 24 24">
            <path
              d="M14 14.76V5a2 2 0 10-4 0v9.76a4 4 0 104 0z"
              fill="currentColor"
            />
          </svg>

        </IndicatorItem>

        <IndicatorItem active>BAT</IndicatorItem>


        {/* GPS INDICATOR */}

        <IndicatorItem
          active={activePage === "gps"}
          onClick={() =>
            setPage(activePage === "gps" ? "dashboard" : "gps")
          }
        >

          <svg
            className="gps-icon"
            viewBox="0 0 24 24"
          >

            <path
              d="M12 2L20 20L12 16L4 20L12 2Z"
              fill="currentColor"
            />

          </svg>

        </IndicatorItem>


        <IndicatorItem
          active={activePage === "tilt"}
          onClick={() =>
            setPage(activePage === "tilt" ? "dashboard" : "tilt")
          }
        >
          TILT
        </IndicatorItem>

        <IndicatorItem className="network-indicator">

          <div className={`signal-bars level-${networkStrength}`}>
            <span></span>
            <span></span>
            <span></span>
            <span></span>
          </div>

        </IndicatorItem>

      </div>

    </div>

  );
}