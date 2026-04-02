import can
import time

# BMS Identifiers to poll [cite: 12, 13]
# 0x100: Voltage/Current/RemCap | 0x101: SOC/Health | 0x102: Protection
# 0x104: System Config | 0x105: NTC1-3 | 0x106: NTC4-6
BMS_IDS = [0x100, 0x101, 0x102, 0x104, 0x105, 0x106]

def get_raw_hex():
    bus = None
    try:
        # Fixed 'interface' argument to resolve DeprecationWarning
        bus = can.interface.Bus(channel='can0', interface='socketcan', bitrate=500000)
        
        print(f"{'ID':<6} | {'Raw Hex Data':<25} | {'Description'}")
        print("-" * 70)

        while True:
            for can_id in BMS_IDS:
                # Send request command 0x5A 
                msg = can.Message(arbitration_id=can_id, data=[0x5A], is_extended_id=False)
                try:
                    bus.send(msg)
                except can.CanError:
                    print(f"Error sending request to ID 0x{can_id:03X}")
                    continue
                
                # Wait for response [cite: 5]
                response = bus.recv(timeout=0.1)
                
                if response and response.arbitration_id == can_id:
                    # Format as space-separated Hex
                    hex_data = " ".join(f"{b:02X}" for b in response.data)
                    
                    # Labels based on protocol [cite: 12, 13]
                    desc = "Unknown"
                    if can_id == 0x100: desc = "Volt/Curr/RemCap"
                    elif can_id == 0x101: desc = "FullCap/Cycles/SOC"
                    elif can_id == 0x102: desc = "Prot/Balance Status"
                    elif can_id == 0x104: desc = "Cell Strings/NTC Count"
                    elif can_id == 0x105: desc = "Temp NTC1 ~ NTC3"
                    elif can_id == 0x106: desc = "Temp NTC4 ~ NTC6"
                    
                    print(f"0x{can_id:03X} | {hex_data:<25} | {desc}")
            
            print("-" * 70)
            time.sleep(1.5)

    except KeyboardInterrupt:
        print("\nStopping monitor...")
    except Exception as e:
        print(f"General Error: {e}")
    finally:
        if bus:
            bus.shutdown() # Properly close the socket

if __name__ == "__main__":
    get_raw_hex()