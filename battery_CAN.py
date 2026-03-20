import can
import time
import struct

BMS_IDS = [0x100, 0x101, 0x102, 0x104, 0x105, 0x106]

def decode_temp(raw_value):
    # Formula: (Raw - 2731) / 10
    return (raw_value - 2731) / 10.0

def get_battery_data():
    bus = None
    try:
        bus = can.interface.Bus(channel='can0', interface='socketcan', bitrate=500000)
        print(f"{'ID':<6} | {'Parameter':<22} | {'Value':<15} | {'Unit'}")
        print("-" * 65)

        while True:
            for can_id in BMS_IDS:
                # Request frame with 0x5A
                msg = can.Message(arbitration_id=can_id, data=[0x5A], is_extended_id=False)
                bus.send(msg)
                
                response = bus.recv(timeout=0.1)
                if response and response.arbitration_id == can_id and len(response.data) >= 4:
                    data = response.data

                    if can_id == 0x100:
                        # Voltage (Unsigned H), Current (Signed h), RemCap (Unsigned H)
                        volt_raw, curr_raw, rem_cap_raw = struct.unpack('>HhH', data[0:6])
                        print(f"0x100  | Total Voltage          | {volt_raw * 0.01:<15.2f} | V")
                        print(f"0x100  | Current                | {curr_raw * 0.01:<15.2f} | A")
                        print(f"0x100  | Remaining Capacity     | {rem_cap_raw * 10:<15} | mAh")

                    elif can_id == 0x101:
                        # FullCap (Unsigned H), Cycles (Signed h), RSOC (Unsigned H)
                        full_cap_raw, cycles, rsoc = struct.unpack('>HhH', data[0:6])
                        print(f"0x101  | Full Capacity (Health) | {full_cap_raw * 10:<15} | mAh")
                        print(f"0x101  | Discharge Cycles       | {cycles:<15} | Times")
                        print(f"0x101  | State of Charge (SOC)  | {rsoc:<15} | %")

                    elif can_id == 0x104:
                        # Byte 0: Strings, Byte 1: NTC Count
                        strings = data[0]
                        ntc_count = data[1]
                        print(f"0x104  | Battery Strings        | {strings:<15} | S")
                        print(f"0x104  | NTC Probe Count        | {ntc_count:<15} | Qty")

                    elif can_id == 0x105:
                        ntc1, ntc2, ntc3 = struct.unpack('>HHH', data[0:6])
                        print(f"0x105  | Temp NTC 1             | {decode_temp(ntc1):<15.1f} | °C")
                        print(f"0x105  | Temp NTC 2             | {decode_temp(ntc2):<15.1f} | °C")
                        print(f"0x105  | Temp NTC 3             | {decode_temp(ntc3):<15.1f} | °C")

                    elif can_id == 0x106:
                        # Only decode if data is present (checks for at least 2 bytes per sensor)
                        if len(data) >= 2:
                            print(f"0x106  | Temp NTC 4             | {decode_temp(struct.unpack('>H', data[0:2])[0]):<15.1f} | °C")
                        if len(data) >= 4:
                            print(f"0x106  | Temp NTC 5             | {decode_temp(struct.unpack('>H', data[2:4])[0]):<15.1f} | °C")
            
            print("-" * 65)
            time.sleep(2)

    except KeyboardInterrupt:
        print("\nStopping monitor...")
    finally:
        if bus: bus.shutdown()

if __name__ == "__main__":
    get_battery_data()