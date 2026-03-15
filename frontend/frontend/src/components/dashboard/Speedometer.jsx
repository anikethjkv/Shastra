import { useVehicleStore } from "../../store/vehicleStore";

export default function Speedometer() {
  const speed = useVehicleStore((state) =>
    state.speed !== undefined ? state.speed : 0
  );

  const maxSpeed = 80;
  const clampedSpeed = Math.max(0, Math.min(speed, maxSpeed));

  /* ==============================
     GAUGE CONFIG
     ============================== */
  const cx = 160;
  const cy = 160;
  const radius = 120;

  // 0° (left) → 180° (right)
  const needleAngle = (clampedSpeed / maxSpeed) * 180;

  // Arc length (half circle)
  const arcLength = Math.PI * radius;
  const progressLength = (clampedSpeed / maxSpeed) * arcLength;

  /* ==============================
     COLOR BASED ON SPEED
     ============================== */
  let arcColor = "#00c48c"; // green
  if (clampedSpeed >= 60) arcColor = "#ff3b3b"; // red
  else if (clampedSpeed >= 40) arcColor = "#f5b301"; // yellow

  const ticks = [0, 20, 40, 60, 80];

  return (
    <svg width="320" height="180" viewBox="0 0 320 180">

      {/* Background arc */}
      <path
        d="M 40 160 A 120 120 0 0 1 280 160"
        fill="none"
        stroke="#cfd4da"
        strokeWidth="14"
      />

      {/* Progress arc */}
      <path
        d="M 40 160 A 120 120 0 0 1 280 160"
        fill="none"
        stroke={arcColor}
        strokeWidth="14"
        strokeLinecap="round"
        strokeDasharray={arcLength}
        strokeDashoffset={arcLength - progressLength}
        style={{
          transition:
            "stroke-dashoffset 0.4s ease-out, stroke 0.3s ease",
        }}
      />

      {/* Tick marks + labels */}
      {ticks.map((value) => {
        const angle = (value / maxSpeed) * Math.PI; // 0 → π
        const rad = Math.PI - angle; // flip so 0 is left

        const x1 = cx + Math.cos(rad) * 95;
        const y1 = cy - Math.sin(rad) * 95;
        const x2 = cx + Math.cos(rad) * 110;
        const y2 = cy - Math.sin(rad) * 110;

        const lx = cx + Math.cos(rad) * 78;
        const ly = cy - Math.sin(rad) * 78;

        return (
          <g key={value}>
            <line
              x1={x1}
              y1={y1}
              x2={x2}
              y2={y2}
              stroke="#6b7280"
              strokeWidth="3"
            />
            <text
              x={lx}
              y={ly}
              textAnchor="middle"
              dominantBaseline="middle"
              fontSize="12"
              fill="#6b7280"
            >
              {value}
            </text>
          </g>
        );
      })}

      {/* Needle (animated properly) */}
      <g
        style={{
          transform: `rotate(${needleAngle}deg)`,
          transformOrigin: `${cx}px ${cy}px`,
          transition: "transform 0.4s ease-out",
        }}
      >
        <line
          x1={cx}
          y1={cy}
          x2={cx - 100}
          y2={cy}
          stroke="#1f2933"
          strokeWidth="4"
          strokeLinecap="round"
        />
      </g>

      {/* Needle center */}
      <circle cx={cx} cy={cy} r="6" fill="#1f2933" />

      {/* Digital speed */}
      <text
        x="160"
        y="120"
        textAnchor="middle"
        fontSize="36"
        fontWeight="600"
        fill="#1f2933"
      >
        {clampedSpeed}
      </text>

      <text
        x="160"
        y="145"
        textAnchor="middle"
        fontSize="14"
        fill="#6b7280"
      >
        km/h
      </text>
    </svg>
  );
}
