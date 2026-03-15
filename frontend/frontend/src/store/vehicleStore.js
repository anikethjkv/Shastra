import { create } from "zustand";

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

  temperature: 70,

  networkStrength: 4,

  highBeam: false,

  /* ==============================
     TILT SENSOR
  ============================== */

  tiltX: 40,   // Left / Right lean angle
  tiltY: 0,   // Forward / Back tilt

  setTilt: (x, y) =>
    set({
      tiltX: x,
      tiltY: y
    }),

  /* ==============================
     BATTERY / HVS
  ============================== */

  batteryLevel: 78,
  batteryVoltage: 72,

  setBatteryLevel: (value) =>
    set({
      batteryLevel: Math.max(0, Math.min(value, 100)),
    }),

  setBatteryVoltage: (value) =>
    set({
      batteryVoltage: value,
    }),

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
/* MOTOR PHASE VOLTAGES */

phaseU: 48,
phaseV: 47,
phaseW: 49,

setPhaseVoltages: (u, v, w) =>
  set({
    phaseU: u,
    phaseV: v,
    phaseW: w
  }),
}));