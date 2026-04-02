import can
import os
import time
import subprocess

# --- CONFIGURATION FROM DOCUMENTATION ---
INTERFACE = 'can0'
BITRATE = 500000 

# Multipliers from documentation
SCALES = {
    "voltage": 32.0, 
    "current": 32.0,
    "speed": 256.0,
    "temp": 1.0
}

# --- LABEL MAPPINGS ---
FLAGS1_LABELS = {
    0: "Brake", 1: "Cutout", 2: "Run Request", 3: "Pedal", 4: "Regen", 5: "Walk", 
    6: "Walk Start", 7: "Throttle", 8: "Reverse", 9: "Interlock Off", 
    10: "Pedal Ramp", 11: "Gate Req", 12: "Gate En", 13: "Boost", 14: "Anti-Theft", 15: "Free Wheel"
}

FAULTS1_LABELS = {
    0: "Avg OverVolt", 1: "Avg Phase OverCurr", 2: "Curr Sens Calib", 3: "Curr Sens OverCurr",
    4: "Contr OverTemp", 5: "Motor Hall Sensor Fault", 6: "Avg Motor OverTemp", 7: "POST Static",
    8: "Comm Timeout", 9: "Inst Phase OverCurr", 10: "Motor OverTemp", 11: "Throttle Outside Range",
    12: "Inst Controller OverVolt", 13: "Internal Err", 14: "POST Dynamic", 15: "Inst Controller UnderVolt"
}

FAULTS2_LABELS = {
    0: "Param CRC", 1: "Curr Scale", 2: "Volt Scale", 3: "Headlight UnderV",
    4: "Param 3CRC", 5: "CAN Bus", 6: "Hall Stall", 8: "Param 2CRC",
    9: "Hall vs Sensorless", 12: "Remote CAN", 13: "Open Phase", 14: "Analog Brake Range"
}

FAULTS3_LABELS = {
    0: "Enc Sin Range", 1: "Enc Cos Range", 2: "ADC Saturation", 3: "Dual Throttle Range"
}

WARNINGS1_LABELS = {
    0: "Comm Timeout", 1: "Hall Sens", 2: "Hall Stall", 3: "Wheel Speed", 4: "CAN Bus",
    7: "Low Bat Fold", 8: "High Bat Fold", 9: "Motor Temp Fold", 10: "Contr Temp Fold",
    11: "Low SOC Fold", 12: "High SOC Fold", 13: "I2T Overload", 14: "Low Temp Fold"
}

# --- SYSTEM HELPERS ---
def setup_can_interface():
    """Automatically enables can0 at 500000 bitrate if it is off."""
    try:
        result = subprocess.run(['ip', 'link', 'show', INTERFACE], capture_output=True, text=True)
        if "UP" not in result.stdout:
            # Documentation setup commands
            subprocess.run(['sudo', 'ip', 'link', 'set', INTERFACE, 'down'], check=False)
            subprocess.run(['sudo', 'ip', 'link', 'set', INTERFACE, 'type', 'can', 'bitrate', str(BITRATE)], check=True)
            subprocess.run(['sudo', 'ip', 'link', 'set', INTERFACE, 'up'], check=True)
        return True
    except Exception:
        return False

def decode_le(data_chunk, signed=True):
    """Decodes little endian data from CAN packet."""
    return int.from_bytes(data_chunk, byteorder='little', signed=signed)

def get_active_bits(val, mapping):
    """Returns list of active labels. Only triggers if bit is high (1)."""
    if val <= 0: return []
    return [desc for bit, desc in mapping.items() if (val >> bit) & 1]

def main():
    os.system('clear')
    # Initialize telemetry with 0.0 values
    telemetry = {
        "v": 0.0, "i": 0.0, "soc": 0, "pwr": 0, "rpm": 0, "speed": 0.0,
        "c_status": 0, "c_temp": 0, "m_temp": 0, "b_temp": 0,
        "pA_v": 0.0, "pB_v": 0.0, "pC_v": 0.0,
        "pA_i": 0.0, "pB_i": 0.0, "pC_i": 0.0,
        "f1": 0, "f2": 0, "f3": 0, "w1": 0, "w2": 0, "flags": 0, "flags2": 0
    }

    bus = None
    while True:
        try:
            if bus is None:
                if not setup_can_interface():
                    print("\033[1;1H\033[K[!] CAN Interface Error. Retrying...")
                    time.sleep(2)
                    continue
                bus = can.interface.Bus(channel=INTERFACE, interface='socketcan')
            
            msg = bus.recv(timeout=0.1)
            if not msg: continue

            # --- TPDO DECODING LOGIC ---
            if msg.arbitration_id == 0x1AA: # TPDO 1
                telemetry["c_status"] = decode_le(msg.data[0:2], signed=False)  # Map1: Controller Status
                telemetry["c_temp"]  = decode_le(msg.data[2:4])                 # Map2: Controller Temperature
                telemetry["flags"]   = decode_le(msg.data[4:6], signed=False)   # Map3: Controller Flags
                telemetry["flags2"]  = decode_le(msg.data[6:8], signed=False)   # Map4: Controller Flags2
            elif msg.arbitration_id == 0x2AA: # TPDO 2
                telemetry["pwr"]    = decode_le(msg.data[0:2])
                telemetry["speed"]  = decode_le(msg.data[2:4]) / SCALES["speed"]
                telemetry["rpm"]    = decode_le(msg.data[4:6])
                telemetry["m_temp"] = decode_le(msg.data[6:8])
            elif msg.arbitration_id == 0x3AA: # TPDO 3
                telemetry["v"]      = decode_le(msg.data[0:2]) / SCALES["voltage"]   # Map1: Battery Voltage
                telemetry["i"]      = decode_le(msg.data[2:4]) / SCALES["current"]   # Map2: Battery Current
                telemetry["soc"]    = decode_le(msg.data[4:6], signed=False)          # Map3: State of Charge
                telemetry["b_temp"] = decode_le(msg.data[6:8])                        # Map4: Battery Temperature
            elif msg.arbitration_id == 0x4AA: # TPDO 4
                telemetry["pA_v"]   = decode_le(msg.data[0:2]) / SCALES["voltage"]
                telemetry["pB_v"]   = decode_le(msg.data[2:4]) / SCALES["voltage"]
                telemetry["pC_v"]   = decode_le(msg.data[4:6]) / SCALES["voltage"]
            elif msg.arbitration_id == 0x5AA: # TPDO 5
                telemetry["pA_i"]   = decode_le(msg.data[0:2]) / SCALES["current"]
                telemetry["pB_i"]   = decode_le(msg.data[2:4]) / SCALES["current"]
                telemetry["pC_i"]   = decode_le(msg.data[4:6]) / SCALES["current"]
                telemetry["f1"]     = decode_le(msg.data[6:8], signed=False)
            elif msg.arbitration_id == 0x6AA: # TPDO 6
                telemetry["f2"]     = decode_le(msg.data[0:2], signed=False)
                telemetry["f3"]     = decode_le(msg.data[2:4], signed=False)
                telemetry["w1"]     = decode_le(msg.data[4:6], signed=False)

            # --- UI PROCESSING ---
            active_flags = get_active_bits(telemetry["flags"], FLAGS1_LABELS)
            all_faults = (get_active_bits(telemetry["f1"], FAULTS1_LABELS) + 
                          get_active_bits(telemetry["f2"], FAULTS2_LABELS) + 
                          get_active_bits(telemetry["f3"], FAULTS3_LABELS))
            all_warns  = get_active_bits(telemetry["w1"], WARNINGS1_LABELS)

            print(f"\033[1;1H", end="")
            print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(f"                ASI BAC2000 SYSTEM MONITOR                    ")
            print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(f"\033[K [BATTERY] {telemetry['v']:>5.1f}V | {telemetry['i']:>5.1f}A | SOC: {telemetry['soc']}% | Temp: {telemetry['b_temp']}°C")
            print(f"\033[K [MOTOR]   {telemetry['pwr']:>5d}W | {telemetry['rpm']:>5d} RPM | {telemetry['speed']:.1f} km/h")
            print(f"\033[K [PHASES]  V: {telemetry['pA_v']:.1f}, {telemetry['pB_v']:.1f}, {telemetry['pC_v']:.1f}")
            print(f"\033[K           I: {telemetry['pA_i']:.1f}, {telemetry['pB_i']:.1f}, {telemetry['pC_i']:.1f}")
            print(f"\033[K [TEMPS]   Contr: {telemetry['c_temp']}°C | Motor: {telemetry['m_temp']}°C")
            print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(f"\033[K [FLAGS]   {', '.join(active_flags) if active_flags else 'None'}")
            print(f"\033[K [FAULTS]  \033[91m{', '.join(all_faults) if all_faults else 'None'}\033[0m")
            print(f"\033[K [WARNS]   \033[93m{', '.join(all_warns) if all_warns else 'None'}\033[0m")
            print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        except (can.CanOperationError, OSError):
            bus = None
            time.sleep(1)
        except KeyboardInterrupt:
            if bus: bus.shutdown()
            break

if __name__ == "__main__":
    main()