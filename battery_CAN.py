import can
import time

# List of BMS IDs to poll based on the protocol
# 0x100: Voltage/Current | 0x101: SOC/Health | 0x102: Protection
# 0x104: Strings/NTC Count | 0x105: NTC1-3 | 0x106: NTC4-6
BMS_IDS = [0x100, 0x101, 0x102, 0x104, 0x105, 0x106]

def get_raw_hex():
    try:
        # Initialize the CAN bus at 500k baud [cite: 4]
        bus = can.interface.Bus(channel='can0', bustype='socketcan', bitrate=500000)
        print(f"{'ID':<6} | {'Raw Hex Data':<25} | {'Description'}")
        print("-" * 60)

        while True:
            for can_id in BMS_IDS:
                # Send the request command (0x5A) as recommended [cite: 7, 8]
                msg = can.Message(arbitration_id=can_id, data=[0x5A], is_extended_id=False)
                bus.send(msg)
                
                # Wait briefly for the BMS to respond [cite: 5, 6]
                response = bus.recv(timeout=0.1)
                
                if response and response.arbitration_id == can_id:
                    # Format the data as space-separated Hex bytes
                    hex_data = " ".join(f"{b:02X}" for b in response.data)
                    
                    # Label the output based on protocol definitions
                    desc = ""
                    if can_id == 0x104: desc = "Strings & NTC Count" [cite: 13]
                    elif can_id == 0x105: desc = "NTC1 ~ NTC3 Temps" [cite: 13]
                    elif can_id == 0x106: desc = "NTC4 ~ NTC6 Temps" [cite: 13]
                    elif can_id == 0x101: desc = "SOC & Full Capacity" [cite: 12]
                    elif can_id == 0x100: desc = "Voltage & Current" [cite: 12]
                    
                    print(f"0x{can_id:03X} | {hex_data:<25} | {desc}")
            
            print("-" * 60)
            time.sleep(2) # Poll every 2 seconds

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    get_raw_hex()