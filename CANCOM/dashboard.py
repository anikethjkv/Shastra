import can
import os
import time
import subprocess

# --- CONFIGURATION FROM DOCUMENTATION ---
INTERFACE = 'can0'
BITRATE = 250000 

# Scale factors: Value = CAN_Value / Scale
SCALES = {
    "voltage": 32.0, 
    "current": 32.0,
    "speed": 256.0,
    "temp": 1.0,
    "status": 1.0
}

# --- LABEL DEFINITIONS ---
FLAGS1_LABELS = {
    0: "Brake", 1: "Cutout", 2: "Run Request", 3: "Pedal", 4: "Regen", 5: "Walk", 
    6: "Walk Start", 7: "Throttle", 8: "Reverse", 9: "Interlock Off", 
    10: "Pedal Ramp Rate Active", 11: "Gate Enable Request", 12: "Gate Enabled", 
    13: "Boost Mode", 14: "Anti-Theft", 15: "Free Wheel"
}

FAULTS_LABELS = {
    0: "Avg OverVolt", 1: "Avg Phase OverCurr", 2: "Curr Sens Calib", 3: "Curr Sens OverCurr",
    4: "Contr OverTemp", 5: "Motor Hall", 6: "Avg Motor OverTemp", 7: "POST Static",
    8: "Comm Timeout", 9: "Inst Phase OverCurr", 10: "Motor OverTemp", 11: "Throttle Range",
    12: "Inst OverVolt", 13: "Internal Error", 14: "POST Dynamic", 15: "Inst UnderVolt"
}

# --- HELPER FUNCTIONS ---
def setup_can_interface():
    """Ensures can0 is up and configured to 250000 bitrate."""
    try:
        result = subprocess.run(['ip', 'link', 'show', INTERFACE], capture_output=True, text=True)
        if "UP" not in result.stdout or f"bitrate {BITRATE}" not in result.stdout:
            print(f"[!] Configuring {INTERFACE}...")
            subprocess.run(['sudo', 'ip', 'link', 'set', INTERFACE, 'down'], check=False)
            subprocess.run(['sudo', 'ip', 'link', 'set', INTERFACE, 'type', 'can', 'bitrate', str(BITRATE)], check=True)
            subprocess.run(['sudo', 'ip', 'link', 'set', INTERFACE, 'up'], check=True)
        return True
    except Exception as e:
        print(f"Error setting up interface: {e}")
        return False

def decode_little_endian(data_chunk, signed=True):
    return int.from_bytes(data_chunk, byteorder='little', signed=signed)

def get_active_bits(val, mapping):
    return [desc for bit, desc in mapping.items() if (val >> bit) & 1]

def main():
    os.system('clear')
    # Data structure to hold all documented TPDO values
    telemetry = {
        "status": 0, "c_temp": 0, "flags1": 0, "flags2": 0,
        "power": 0, "speed": 0.0, "rpm": 0, "m_temp": 0,
        "voltage": 0.0, "b_current": 0.0, "soc": 0, "b_temp": 0,
        "pA_v": 0.0, "pB_v": 0.0, "pC_v": 0.0,
        "pA_i": 0.0, "pB_i": 0.0, "pC_i": 0.0,
        "faults": 0, "warnings": 0
    }

    bus = None
    while True:
        try:
            if bus is None:
                if not setup_can_interface():
                    print("\033[1;1H\033[K[!] Waiting for CAN hardware...")
                    time.sleep(2)
                    continue
                bus = can.interface.Bus(channel=INTERFACE, interface='socketcan')
            
            msg = bus.recv(timeout=0.1)
            if not msg: continue

            # Map messages to TPDOs based on IDs provided in documentation
            # (Assuming standard IDs 0x1AA-0x6AA for TPDO 1-6)
            if msg.arbitration_id == 0x1AA: # TPDO 1
                telemetry["status"]  = decode_little_endian(msg.data[0:2])
                telemetry["c_temp"]  = decode_little_endian(msg.data[2:4])
                telemetry["flags1"]  = decode_little_endian(msg.data[4:6], signed=False)
            elif msg.arbitration_id == 0x2AA: # TPDO 2
                telemetry["power"]   = decode_little_endian(msg.data[0:2])
                telemetry["speed"]   = decode_little_endian(msg.data[2:4]) / SCALES["speed"]
                telemetry["rpm"]     = decode_little_endian(msg.data[4:6])
                telemetry["m_temp"]  = decode_little_endian(msg.data[6:8])
            elif msg.arbitration_id == 0x3AA: # TPDO 3
                telemetry["voltage"]   = decode_little_endian(msg.data[0:2]) / SCALES["voltage"]
                telemetry["b_current"] = decode_little_endian(msg.data[2:4]) / SCALES["current"]
                telemetry["soc"]       = decode_little_endian(msg.data[4:6], signed=False)
                telemetry["b_temp"]    = decode_little_endian(msg.data[6:8])
            elif msg.arbitration_id == 0x4AA: # TPDO 4
                telemetry["pA_v"]    = decode_little_endian(msg.data[0:2]) / SCALES["voltage"]
                telemetry["pB_v"]    = decode_little_endian(msg.data[2:4]) / SCALES["voltage"]
                telemetry["pC_v"]    = decode_little_endian(msg.data[4:6]) / SCALES["voltage"]
            elif msg.arbitration_id == 0x5AA: # TPDO 5
                telemetry["pA_i"]    = decode_little_endian(msg.data[0:2]) / SCALES["current"]
                telemetry["pB_i"]    = decode_little_endian(msg.data[2:4]) / SCALES["current"]
                telemetry["pC_i"]    = decode_little_endian(msg.data[4:6]) / SCALES["current"]
                telemetry["faults"]  = decode_little_endian(msg.data[6:8], signed=False)

            # Refresh UI
            active_f1 = get_active_bits(telemetry["flags1"], FLAGS1_LABELS)
            active_err = get_active_bits(telemetry["faults"], FAULTS_LABELS)

            print(f"\033[1;1H", end="")
            print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(f"                ASI BAC2000 SYSTEM MONITOR                    ")
            print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(f"\033[K [BATTERY] {telemetry['voltage']:>5.1f}V | {telemetry['b_current']:>5.1f}A | SOC: {telemetry['soc']}%")
            print(f"\033[K [MOTOR]   {telemetry['power']:>5d}W | {telemetry['rpm']:>5d} RPM | Speed: {telemetry['speed']:.1f} km/h")
            print(f"\033[K [PHASES]  V: {telemetry['pA_v']:.1f}, {telemetry['pB_v']:.1f}, {telemetry['pC_v']:.1f} | I: {telemetry['pA_i']:.1f}A")
            print(f"\033[K [TEMPS]   Contr: {telemetry['c_temp']}°C | Motor: {telemetry['m_temp']}°C")
            print(f"\033[K [FLAGS]   {', '.join(active_f1) if active_f1 else 'Normal'}")
            print(f"\033[K [FAULTS]  \033[91m{', '.join(active_err) if active_err else 'None'}\033[0m")
            print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        except (can.CanOperationError, OSError):
            print("\033[12;1H\033[K[!] CAN Disconnected. Retrying...")
            bus = None
            time.sleep(1)
        except KeyboardInterrupt:
            if bus: bus.shutdown()
            break

if __name__ == "__main__":
    main()