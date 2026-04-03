import can
import time

def probe_bms_config():
    # Configure your CAN interface
    # For PCAN-USB at 500kbps (BMS Default)
    # Note: If your BAC2000 8MHz clock is active, you might need to try 250000
    bus = can.interface.Bus(interface='pcan', channel='PCAN_USBBUS1', bitrate=500000)

    # Construct the Read Command [cite: 1245, 1253]
    # ID 0x137 is Protection Parameter 29-32
    # Data 0x5A with length 1 tells the BMS to 'Read' 
    msg = can.Message(
        arbitration_id=0x137,
        data=[0x5A],
        is_extended_id=False
    )

    try:
        print("Sending Read Request to BMS (ID 0x137)...")
        bus.send(msg)

        # Wait up to 2 seconds for the 8-byte response 
        response = bus.recv(2.0)

        if response:
            print(f"Response Received from ID {hex(response.arbitration_id)}:")
            print(f"Data (Hex): {' '.join([hex(b) for b in response.data])}")
            print(f"Data (Dec): {list(response.data)}")
            
            # Identify the Function Configuration 
            # BYTE 2 and 3 are the keys to the baud rate
            if len(response.data) >= 4:
                print(f"Target Bytes (2 & 3): {hex(response.data[2])} {hex(response.data[3])}")
        else:
            print("No response received. Check wiring, termination, or baud rate.")

    except can.CanError as e:
        print(f"Message NOT sent: {e}")
    finally:
        bus.shutdown()

if __name__ == "__main__":
    probe_bms_config()