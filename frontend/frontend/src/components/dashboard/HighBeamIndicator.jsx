import "../../styles/highbeam.css";

export default function HighBeamIndicator({ active, toggleHighBeam }) {
  return (
    <div
      className={`highbeam-container ${active ? "active" : ""}`}
      onClick={toggleHighBeam}
    >
      <svg viewBox="0 0 28 24" className="highbeam-icon">

        {/* Headlamp body */}
        <rect
          x="2"
          y="6"
          width="6"
          height="12"
          rx="3"
          ry="3"
        />

        {/* Light beam lines */}
        <line x1="10" y1="6" x2="26" y2="6" />
        <line x1="10" y1="10" x2="26" y2="10" />
        <line x1="10" y1="14" x2="26" y2="14" />
        <line x1="10" y1="18" x2="26" y2="18" />

      </svg>
    </div>
  );
}