import "../../styles/phaseVoltage.css";

export default function PhaseVoltage({ phase, value }) {

  return (

    <div className="phase-voltage">

      <div className="phase-label">
        {phase}
      </div>

      <div className="phase-value">
        {value} V
      </div>

    </div>

  );

}