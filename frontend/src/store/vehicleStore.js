import { create } from "zustand";

const API_URL = "http://localhost:5050/api/telemetry";

export const useVehicleStore = create((set, get) => ({

  /* ==============================
     PAGE CONTROL
  ============================== */

  activePage: "dashboard",

  setPage: (page) => set({ activePage: page }),

  /* ==============================
     CORE VEHICLE STATES
  ============================== */

  speed: 0,
  rpm: 0,

  temperature: 0,

  networkStrength: 0,

  highBeam: false,

  /* ==============================
     TILT SENSOR
  ============================== */

  tiltX: 0,
  tiltY: 0,

  setTilt: (x, y) =>
    set({
      tiltX: x,
      tiltY: y
    }),

  /* ==============================
     BATTERY / HVS
  ============================== */

  batteryLevel: 0,
  batteryVoltage: 0,

  setBatteryLevel: (value) =>
    set({
      batteryLevel: Math.max(0, Math.min(value, 100)),
    }),

  setBatteryVoltage: (value) =>
    set({
      batteryVoltage: value,
    }),

  /* ==============================
     BMS BATTERY DATA
  ============================== */

  bmsTotalVoltage: 0,
  bmsCurrent: 0,
  bmsRemCap: 0,
  bmsFullCap: 0,
  bmsCycles: 0,
  bmsSoc: 0,
  bmsStrings: 0,
  bmsNtcCount: 0,
  bmsNtc1: 0,
  bmsNtc2: 0,
  bmsNtc3: 0,
  bmsNtc4: 0,
  bmsNtc5: 0,

  /* ==============================
     TURN SIGNALS
  ============================== */

  leftIndicator: false,
  rightIndicator: false,
  hazard: false,

  toggleLeftIndicator: () =>
    set((state) => ({
      leftIndicator: !state.leftIndicator,
      rightIndicator: false,
    })),

  toggleRightIndicator: () =>
    set((state) => ({
      rightIndicator: !state.rightIndicator,
      leftIndicator: false,
    })),

  toggleHazard: () =>
    set((state) => ({
      hazard: !state.hazard,
      leftIndicator: !state.hazard,
      rightIndicator: !state.hazard,
    })),

  /* ==============================
     DRIVE MODES
  ============================== */

  mode: "SPORT",

  modes: {
    ECO:   { maxSpeed: 45, color: "#00c48c" },
    SPORT: { maxSpeed: 70, color: "#f5b301" },
    RACE:  { maxSpeed: 90, color: "#ff3b3b" },
  },

  setMode: (newMode) => {

    const modes = get().modes;

    if (modes[newMode]) {
      set({ mode: newMode });
    }

  },

  /* ==============================
     SPEED + RPM LOGIC
  ============================== */

  setSpeed: (value) =>
    set((state) => {

      const currentMode = state.modes[state.mode];

      const limitedSpeed = Math.max(
        0,
        Math.min(value, currentMode.maxSpeed)
      );

      return {
        speed: limitedSpeed,
        rpm: limitedSpeed * 80,
      };

    }),

  /* ==============================
     TEMPERATURE CONTROL
  ============================== */

  setTemperature: (value) =>
    set({
      temperature: Math.max(0, Math.min(value, 120)),
    }),

  /* ==============================
     NETWORK SIGNAL
  ============================== */

  setNetworkStrength: (value) =>
    set({
      networkStrength: Math.max(0, Math.min(value, 4)),
    }),

  /* ==============================
     HIGH BEAM CONTROL
  ============================== */

  toggleHighBeam: () =>
    set((state) => ({
      highBeam: !state.highBeam,
    })),

  /* ==============================
     MOTOR PHASE VOLTAGES
  ============================== */

  phaseU: 0,
  phaseV: 0,
  phaseW: 0,

  setPhaseVoltages: (u, v, w) =>
    set({
      phaseU: u,
      phaseV: v,
      phaseW: w
    }),

  /* ==============================
     MOTOR POWER & DISTANCE
  ============================== */

  motorPower: 0,
  motorTemp: 0,
  totalDistance: 0,

  /* ==============================
     CONTROLLER DATA
  ============================== */

  ctrlTemp: 0,
  ctrlFlags: 0,
  ctrlFlags2: 0,

  /* ==============================
     FAULTS & WARNINGS
  ============================== */

  faults: 0,
  faults2: 0,
  faults3: 0,
  warnings: 0,
  warnings2: 0,

  /* ==============================
     SMOKE SENSOR
  ============================== */

  smokeDetected: false,

  /* ==============================
     LIVE DATA POLLING
  ============================== */

  fetchTelemetry: async () => {
    try {
      const res = await fetch(API_URL);
      if (!res.ok) return;
      const d = await res.json();

      set({
        // Motor controller battery (TPDO 3)
        batteryVoltage: d.batt_v ?? get().batteryVoltage,
        batteryLevel:   d.bms_soc ?? d.batt_soc ?? get().batteryLevel,

        // Speed & Motor (TPDO 2)
        speed:      d.vehicle_speed ?? get().speed,
        rpm:        d.motor_rpm     ?? get().rpm,
        motorPower: d.motor_pwr     ?? get().motorPower,
        motorTemp:  d.motor_temp    ?? get().motorTemp,

        // Controller (TPDO 1)
        temperature: d.ctrl_temp   ?? get().temperature,
        ctrlTemp:    d.ctrl_temp   ?? get().ctrlTemp,
        ctrlFlags:   d.ctrl_flags  ?? get().ctrlFlags,
        ctrlFlags2:  d.ctrl_flags2 ?? get().ctrlFlags2,

        // Phase voltages (TPDO 4)
        phaseU: d.phase_v_a ?? get().phaseU,
        phaseV: d.phase_v_b ?? get().phaseV,
        phaseW: d.phase_v_c ?? get().phaseW,

        // Faults & Warnings (TPDO 5/6)
        faults:    d.faults    ?? get().faults,
        faults2:   d.faults2   ?? get().faults2,
        faults3:   d.faults3   ?? get().faults3,
        warnings:  d.warnings  ?? get().warnings,
        warnings2: d.warnings2 ?? get().warnings2,

        // Switches (Arduino 0x40)
        leftIndicator:  d.sw_left    ? true : false,
        rightIndicator: d.sw_right   ? true : false,
        highBeam:       d.sw_hi_beam ? true : false,

        // BMS battery data
        bmsTotalVoltage: d.bms_total_voltage ?? get().bmsTotalVoltage,
        bmsCurrent:      d.bms_current       ?? get().bmsCurrent,
        bmsRemCap:       d.bms_rem_cap       ?? get().bmsRemCap,
        bmsFullCap:      d.bms_full_cap      ?? get().bmsFullCap,
        bmsCycles:       d.bms_cycles        ?? get().bmsCycles,
        bmsSoc:          d.bms_soc           ?? get().bmsSoc,
        bmsStrings:      d.bms_strings       ?? get().bmsStrings,
        bmsNtcCount:     d.bms_ntc_count     ?? get().bmsNtcCount,
        bmsNtc1:         d.bms_ntc1          ?? get().bmsNtc1,
        bmsNtc2:         d.bms_ntc2          ?? get().bmsNtc2,
        bmsNtc3:         d.bms_ntc3          ?? get().bmsNtc3,
        bmsNtc4:         d.bms_ntc4          ?? get().bmsNtc4,
        bmsNtc5:         d.bms_ntc5          ?? get().bmsNtc5,

        // Tilt / Accelerometer
        tiltX: d.accel_x ?? get().tiltX,
        tiltY: d.accel_y ?? get().tiltY,

        // Odometer
        totalDistance: d.total_distance ?? get().totalDistance,

        // Smoke
        smokeDetected: d.smoke_detected ? true : false,

        // Network
        networkStrength: d.lte_status ? 4 : 0,
      });
    } catch {
      // API unreachable — keep current values
    }
  },
}));