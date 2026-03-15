import { useVehicleStore } from "../../store/vehicleStore";

export default function Indicators({ side }) {
  const indicators = useVehicleStore((state) => state.indicators);
  const updateVehicleData = useVehicleStore(
    (state) => state.updateVehicleData
  );

  // LEFT SIDE INDICATORS (TOP → BOTTOM)
  const leftIndicators = [
    { key: "left", label: "←" },
    { key: "highBeam", label: "HIGH" },
    { key: "sideStand", label: "STAND" },
    { key: "mode1", label: "MODE1" },
    { key: "mode2", label: "MODE2" },
    { key: "mode3", label: "MODE3" },
  ];

  // RIGHT SIDE INDICATORS (TOP → BOTTOM)
  const rightIndicators = [
    { key: "right", label: "→" },
    { key: "smoke", label: "SMOKE" },
    { key: "volt", label: "VOLT" },
    { key: "temp", label: "TEMP" },
    { key: "gps", label: "GPS" },
    { key: "lte", label: "LTE" },
  ];

  const items = side === "left" ? leftIndicators : rightIndicators;

  // TOUCH / TAP HANDLER
  const handleTap = (key) => {
    updateVehicleData({
      indicators: {
        ...indicators,
        [key]: !indicators[key],
      },
    });
  };

  return (
    <div className="sidebar">
      {items.map((item) => (
        <div
          key={item.key}
          className={`indicator ${indicators[item.key] ? "active" : ""}`}
          onPointerDown={() => handleTap(item.key)}
        >
          {item.label}
        </div>
      ))}
    </div>
  );
}
