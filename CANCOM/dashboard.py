import can
import os
import time
import subprocess

# --- CONFIGURATION FROM DOCUMENTATION ---
INTERFACE = 'can0'
BITRATE = 250000 

SCALES = {
    "voltage": 32.0, 
    "current": 32.0,
    "speed": 256.0,
    "temp": 1.0
}

# --- DICTIONARY MAPPINGS ---
FLAGS1_LABELS = {
    0: "Brake", 1: "Cutout", 2: "Run Request", 3: "Pedal", 4: "Regen", 5: "Walk", 
    6: "Walk Start", 7: "Throttle", 8: "Reverse", 9: "Interlock Off", 
    10: "Pedal Ramp", 11: "Gate Req", 12: "Gate En", 13: "Boost", 14: "Anti-Theft", 15: "Free Wheel"
}

FAULTS1_LABELS = {
    0: "OverVolt", 1: "Phase OverCurr", 2: "Sens Calib", 3: "Sens OverCurr",
    4: "Contr OverTemp", 5: "Motor Hall", 6: "Avg Motor OverTemp", 7: "POST Static",
    8: "Comm Timeout", 9: "Inst Phase OverCurr", 10: "Motor OverTemp", 11: "Throttle Range",
    12: "Inst OverVolt", 13: "Internal Err", 14: "POST Dynamic", 15: "Inst UnderVolt"
}

# --- HELPER FUNCTIONS ---
def setup_can_interface():
    """Ensures can0 is up and configured to 250000 bitrate."""
    try:
        result = subprocess.run(['ip', 'link', 'show', INTERFACE], capture_output=True, text=True)
        # Re-initialize if down OR if the output doesn't confirm the correct bitrate
        if "UP" not in result.stdout or str(BITRATE) not in result.stdout:
            subprocess.run(['sudo', 'ip', 'link', 'set', INTERFACE, 'down'], check=False)
            subprocess.run(['sudo', 'ip', 'link', 'set', INTERFACE, 'type', 'can', 'bitrate', str(BITRATE)], check=True)
            subprocess.run(['sudo', 'ip', 'link', 'set', INTERFACE, 'up'], check=True)
        return True
    except Exception:
        return False

def decode_le(data_chunk, signed=True):
    """Decodes little endian hex to decimal."""
    return int.from_bytes(data_chunk, byteorder='little', signed=signed)

def get_active_bits(val, mapping):
    """Returns labels only if the corresponding bit is high."""
    if val <= 0: return [] 
    return [desc for bit, desc in mapping.items() if (val >> bit) & 1]

def main():
    os.system('clear')
    telemetry = {
        "status": 0, "c_temp": 0, "f1": 0, "f2": 0,
        "pwr": 0, "speed": 0.0, "rpm": 0, "m_temp": 0,
        "v": 0.0, "i": 0.0, "soc": 0, "b_temp": 0,
        "pA_v": 0.0, "pB_v": 0.0, "pC_v": 0.0,
        "pA_i": 0.0, "pB_i": 0.0, "pC_i": 0.0,
        "fault1": 0, "fault2": 0, "fault3": 0, "warn1": 0, "warn2": 0
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

            # --- DECODING LOGIC ---
            if msg.arbitration_id == 0x1AA:
                telemetry["status"] = decode_le(msg.data[0:2])
                telemetry["c_temp"] = decode_le(msg.data[2:4])
                telemetry["f1"]     = decode_le(msg.data[4:6], signed=False)
                telemetry["f2"]     = decode_le(msg.data[6:8], signed=False)
            elif msg.arbitration_id == 0x2AA:
                telemetry["pwr"]    = decode_le(msg.data[0:2])
                telemetry["speed"]  = decode_le(msg.data[2:4]) / SCALES["speed"]
                telemetry["rpm"]    = decode_le(msg.data[4:6])
                telemetry["m_temp"] = decode_le(msg.data[6:8])
            elif msg.arbitration_id == 0x3AA:
                telemetry["v"]      = decode_le(msg.data[0:2]) / SCALES["voltage"]
                telemetry["i"]      = decode_le(msg.data[2:4]) / SCALES["current"]
                telemetry["soc"]    = decode_le(msg.data[4:6], signed=False)
                telemetry["b_temp"] = decode_le(msg.data[6:8])
            elif msg.arbitration_id == 0x4AA:
                telemetry["pA_v"]   = decode_le(msg.data[0:2]) / SCALES["voltage"]
                telemetry["pB_v"]   = decode_le(msg.data[2:4]) / SCALES["voltage"]
                telemetry["pC_v"]   = decode_le(msg.data[4:6]) / SCALES["voltage"]
            elif msg.arbitration_id == 0x5AA:
                telemetry["pA_i"]   = decode_le(msg.data[0:2]) / SCALES["current"]
                telemetry["pB_i"]   = decode_le(msg.data[2:4]) / SCALES["current"]
                telemetry["pC_i"]   = decode_le(msg.data[4:6]) / SCALES["current"]
                telemetry["fault1"] = decode_le(msg.data[6:8], signed=False)
            elif msg.arbitration_id == 0x6AA:
                telemetry["fault2"] = decode_le(msg.data[0:2], signed=False)
                telemetry["fault3"] = decode_le(msg.data[2:4], signed=False)
                telemetry["warn1"]  = decode_le(msg.data[4:6], signed=False)
                telemetry["warn2"]  = decode_le(msg.data[6:8], signed=False)

            # --- UI RENDERING ---
            active_f1 = get_active_bits(telemetry["f1"], FLAGS1_LABELS)
            active_err = get_active_bits(telemetry["fault1"], FAULTS1_LABELS)

            print(f"\033[1;1H", end="")
            print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(f"                ASI BAC2000 SYSTEM MONITOR                    ")
            print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(f"\033[K [BATTERY] {telemetry['v']:>5.1f}V | {telemetry['i']:>5.1f}A | SOC: {telemetry['soc']}%")
            print(f"\033[K [MOTOR]   {telemetry['pwr']:>5d}W | {telemetry['rpm']:>5d} RPM | {telemetry['speed']:.1f} km/h")
            print(f"\033[K [PHASE V] A:{telemetry['pA_v']:>4.1f} B:{telemetry['pB_v']:>4.1f} C:{telemetry['pC_v']:>4.1f}")
            print(f"\033[K [PHASE I] A:{telemetry['pA_i']:>4.1f} B:{telemetry['pB_i']:>4.1f} C:{telemetry['pC_i']:>4.1f}")
            print(f"\033[K [TEMPS]   Contr: {telemetry['c_temp']}°C | Motor: {telemetry['m_temp']}°C")
            print(f"\033[K [FLAGS]   {', '.join(active_f1) if active_f1 else 'Normal'}")
            print(f"\033[K [FAULTS]  \033[91m{', '.join(active_err) if active_err else 'None'}\033[0m")
            print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        except (can.CanOperationError, OSError):
            print("\033[13;1H\033[K[!] CAN Disconnected. Retrying setup...")
            bus = None
            time.sleep(1)
        except KeyboardInterrupt:
            if bus: bus.shutdown()
            break

if __name__ == "__main__":
    main()