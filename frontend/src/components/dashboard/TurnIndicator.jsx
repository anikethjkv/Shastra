import "../../styles/turnindicator.css";

export default function TurnIndicator({ direction, active }) {
  return (
    <div className={`turn-indicator ${direction} ${active ? "active" : ""}`}>
      <svg viewBox="0 0 24 24" className="turn-icon">

        {direction === "left" ? (
          <path d="M14 6L8 12L14 18V14H20V10H14V6Z" />
        ) : (
          <path d="M10 6V10H4V14H10V18L16 12L10 6Z" />
        )}

      </svg>
    </div>
  );
}