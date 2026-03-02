import can
import os
import time
import subprocess

# --- CONFIGURATION ---
INTERFACE = 'can0'
BITRATE = 250000 
SCALES = {
    "voltage": 32.0, "bat_current": 32.0,
    "motor_current": 32.0, "temp": 1.0            
}

# --- FLAG DEFINITIONS ---
FLAGS1_LABELS = {
    0: "Brake", 1: "Cutout", 2: "Run Request", 3: "Pedal",
    4: "Regen", 5: "Walk", 6: "Walk Start", 7: "Throttle",
    8: "Reverse", 9: "Interlock Off", 10: "Pedal Ramp Rate Active",
    11: "Gate Enable Request", 12: "Gate Enabled", 13: "Boost Mode",
    14: "Anti-Theft", 15: "Free Wheel"
}

FLAGS2_LABELS = {
    0: "Regen off Throttle Active", 1: "Cruise Enable Active",
    2: "Alternate Power Limit Active", 3: "Alternate Speed Limit Active",
    4: "Speed motor", 5: "Speed Ext Sensor", 6: "Limp Mode"
}

def setup_can_interface():
    """Attempts to bring up the interface via system calls."""
    try:
        # check if interface is already up
        result = subprocess.run(['ip', 'link', 'show', INTERFACE], capture_output=True, text=True)
        if "UP" not in result.stdout:
            subprocess.run(['sudo', 'ip', 'link', 'set', INTERFACE, 'down'], check=False)
            subprocess.run(['sudo', 'ip', 'link', 'set', INTERFACE, 'type', 'can', 'bitrate', str(BITRATE)], check=True)
            subprocess.run(['sudo', 'ip', 'link', 'set', INTERFACE, 'up'], check=True)
        return True
    except Exception:
        return False

def decode_little_endian(data_chunk, signed=True):
    return int.from_bytes(data_chunk, byteorder='little', signed=signed)

def get_active_flags(val, mapping):
    return [desc for bit, desc in mapping.items() if (val >> bit) & 1]

def main():
    os.system('clear')
    telemetry = {
        "status": 0, "c_temp": 0, "flags1": 0, "flags2": 0,
        "power": 0, "m_current": 0.0, "rpm": 0, "m_temp": 0,
        "voltage": 0.0, "b_current": 0.0, "soc": 0, "b_temp": 0
    }

    bus = None
    while True: # Global Reconnect Loop
        try:
            if bus is None:
                if not setup_can_interface():
                    print("\033[1;1H\033[K[!] Waiting for CAN hardware connection...")
                    time.sleep(2)
                    continue
                bus = can.interface.Bus(channel=INTERFACE, interface='socketcan')
            
            msg = bus.recv(timeout=0.1)
            if not msg: continue

            # Decode Logic
            if msg.arbitration_id == 0x1AA:
                telemetry["status"]  = decode_little_endian(msg.data[0:2])
                telemetry["c_temp"]  = decode_little_endian(msg.data[2:4])
                telemetry["flags1"]  = decode_little_endian(msg.data[4:6], signed=False)
                telemetry["flags2"]  = decode_little_endian(msg.data[6:8], signed=False)
            elif msg.arbitration_id == 0x2AA:
                telemetry["power"]     = decode_little_endian(msg.data[0:2])
                telemetry["m_current"] = decode_little_endian(msg.data[2:4]) / SCALES["motor_current"]
                telemetry["rpm"]       = decode_little_endian(msg.data[4:6])
                telemetry["m_temp"]    = decode_little_endian(msg.data[6:8])
            elif msg.arbitration_id == 0x3AA:
                telemetry["voltage"]   = decode_little_endian(msg.data[0:2]) / SCALES["voltage"]
                telemetry["b_current"] = decode_little_endian(msg.data[2:4]) / SCALES["bat_current"]
                telemetry["soc"]       = decode_little_endian(msg.data[4:6], signed=False)
                telemetry["b_temp"]    = decode_little_endian(msg.data[6:8])

            # Refresh UI
            active_f1 = get_active_flags(telemetry["flags1"], FLAGS1_LABELS)
            active_f2 = get_active_flags(telemetry["flags2"], FLAGS2_LABELS)

            print(f"\033[1;1H", end="")
            print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(f"                ASI BAC2000 MULTI-TPDO MONITOR                ")
            print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(f"\033[K [BATTERY]   {telemetry['voltage']:>6.2f}V | {telemetry['b_current']:>5.2f}A | SOC: {telemetry['soc']:>3d}% | Temp: {telemetry['b_temp']:>2d}°C")
            print(f"\033[K [MOTOR]     {telemetry['power']:>5d}W | {telemetry['m_current']:>5.2f}A | {telemetry['rpm']:>5d} RPM | {telemetry['m_temp']:>3d}°C")
            print(f"\033[K [CONTR]     Temp: {telemetry['c_temp']:>3d}°C | Status: {telemetry['status']:<2d}")
            print(f"\033[K [FLAGS 1]   {', '.join(active_f1) if active_f1 else 'None'}")
            print(f"\033[K [FLAGS 2]   {', '.join(active_f2) if active_f2 else 'None'}")
            print(f"\033[11;1H" + "━" * 68)

        except (can.CanOperationError, OSError):
            # Handle "Network is down" without crashing
            print("\033[12;1H\033[K[!] CAN Network Disconnected. Reconnecting...")
            if bus:
                try: bus.shutdown()
                except: pass
                bus = None
            time.sleep(1)
        except KeyboardInterrupt:
            if bus: bus.shutdown()
            print("\nMonitor Stopped.")
            break

if __name__ == "__main__":
    main()