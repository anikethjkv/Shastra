import "../../styles/parkingButton.css";

export default function ParkingButton({ hazard, setHazard }) {
  return (
    <div
      className={`parking-button ${hazard ? "active" : ""}`}
      onClick={() => setHazard(!hazard)}
    >
      P
    </div>
  );
}