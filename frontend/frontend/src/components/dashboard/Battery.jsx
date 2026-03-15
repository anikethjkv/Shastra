import "../../styles/battery.css";

const Battery = ({
  level = 78,
  voltage = 72,
  isCharging = true
}) => {
  return (
    <div className="battery-wrapper">

      {/* HVS Voltage */}

      <div className="battery-voltage">

        <span className="voltage-label">HVS</span>

        <span className="voltage-value">
          {voltage}V
        </span>

      </div>


      {/* Battery Icon */}

      <div className="battery-icon">

        <div
          className="battery-level"
          style={{ height: `${level}%` }}
        ></div>

        {isCharging && (
          <div className="battery-bolt">⚡</div>
        )}

      </div>


      {/* Battery Percentage */}

      <div className="battery-percentage">
        {level}%
      </div>

    </div>
  );
};

export default Battery;