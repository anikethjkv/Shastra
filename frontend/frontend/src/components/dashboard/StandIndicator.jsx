import "../../styles/stand.css";

export default function StandIndicator({ standDown }) {

  return (

    <div className={`stand-indicator ${standDown ? "down" : "up"}`}>

      <svg
        className="stand-icon"
        viewBox="0 0 24 24"
      >
        <path
          d="M7 4h2l2 7 3 1 2 5h-2l-2-4-3-1-1 4H6l2-6-2-6z"
          fill="currentColor"
        />
      </svg>

      <span className="stand-text">
        STAND
      </span>

    </div>

  );

}