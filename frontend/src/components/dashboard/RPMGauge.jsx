import "../../styles/rpmgauge.css";

const RPMGauge = ({ rpm = 4200 }) => {
  const maxRPM = 8000;
  const percentage = rpm / maxRPM;

  const cx = 110;
  const cy = 110;
  const r = 90;

  const degToRad = (deg) => (deg * Math.PI) / 180;

  // ROTATED 90° LEFT
  const startAngle = -180;
  const endAngle = 0;

  const startX = cx + r * Math.cos(degToRad(startAngle));
  const startY = cy + r * Math.sin(degToRad(startAngle));

  const endX = cx + r * Math.cos(degToRad(endAngle));
  const endY = cy + r * Math.sin(degToRad(endAngle));

  const activeAngle = startAngle + percentage * 180;
  const activeX = cx + r * Math.cos(degToRad(activeAngle));
  const activeY = cy + r * Math.sin(degToRad(activeAngle));

  const needleAngle = activeAngle;

  const totalTicks = 8;
  const ticks = [];

  for (let i = 0; i <= totalTicks; i++) {
    const angle = startAngle + (i / totalTicks) * 180;
    const rad = degToRad(angle);

    const inner = r - 15;
    const outer = r;

    const x1 = cx + inner * Math.cos(rad);
    const y1 = cy + inner * Math.sin(rad);
    const x2 = cx + outer * Math.cos(rad);
    const y2 = cy + outer * Math.sin(rad);

    ticks.push(
      <line
        key={i}
        x1={x1}
        y1={y1}
        x2={x2}
        y2={y2}
        className="rpm-tick"
      />
    );
  }

  return (
    <div className="rpm-wrapper">
      <svg width="220" height="140">

        {/* Background Arc */}
        <path
          d={`M ${startX} ${startY}
              A ${r} ${r} 0 0 1 ${endX} ${endY}`}
          className="rpm-bg"
        />

        {/* Active Arc */}
        <path
          d={`M ${startX} ${startY}
              A ${r} ${r} 0 0 1 ${activeX} ${activeY}`}
          className="rpm-active"
        />

        {/* Ticks */}
        {ticks}

        {/* Needle */}
        <line
          x1={cx}
          y1={cy}
          x2={cx}
          y2={cy - (r - 25)}
          className="rpm-needle"
          style={{
            transform: `rotate(${needleAngle}deg)`,
            transformOrigin: `${cx}px ${cy}px`,
          }}
        />

        <circle cx={cx} cy={cy} r="6" className="rpm-center" />
      </svg>

      <div className="rpm-value">
        {(rpm / 1000).toFixed(1)}k RPM
      </div>
    </div>
  );
};

export default RPMGauge;
