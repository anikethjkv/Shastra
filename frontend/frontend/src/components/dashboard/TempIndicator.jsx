import "../../styles/tempindicator.css";

const TempIndicator = ({ temp = 35 }) => {
  return (
    <div className="temp-indicator">
      🌡️ <span>{temp}°C</span>
    </div>
  );
};

export default TempIndicator;
