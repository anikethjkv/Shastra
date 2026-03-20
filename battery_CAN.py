import can
import struct
import time
import os

def crc16(data):
    """CRC-16 implementation as per protocol (Polynomial: 0xA001)[cite: 58, 59, 62]."""
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x0001:
                crc = (crc >> 1) ^ 0xA001
            else:
                crc >>= 1
    return crc

def request_bms_data(bus, can_id):
    """Sends a request frame with data 0x5A to trigger a BMS response[cite: 7, 8]."""
    msg = can.Message(arbitration_id=can_id, data=[0x5A], is_extended_id=False)
    try:
        bus.send(msg)
    except can.CanError:
        pass

def parse_and_display(msg):
    """Parses response and prints values to terminal[cite: 11, 12]."""
    if msg.arbitration_id in [0x100, 0x101]:
        payload = msg.data[:6]
        recv_crc = (msg.data[6] << 8) | msg.data[7] # High byte first 
        
        if crc16(payload) != recv_crc:
            return

        os.system('clear')
        print("--- E-Bike Battery Monitor ---")
        
        if msg.arbitration_id == 0x100:
            # BYTE4~5: Remaining capacity, unit 10mAh 
            rem_cap = struct.unpack('>H', payload[4:6])[0] * 10
            print(f"Remaining Cap: {rem_cap} mAh")

        elif msg.arbitration_id == 0x101:
            # BYTE0~1: Full capacity (10mAh), BYTE2~3: Cycles, BYTE4~5: RSOC (%) 
            full_cap = struct.unpack('>H', payload[0:2])[0] * 10
            cycles = struct.unpack('>h', payload[2:4])[0]
            soc = struct.unpack('>H', payload[4:6])[0]
            
            print(f"State of Charge (SOC): {soc}%")
            print(f"Health (Full Capacity): {full_cap} mAh")
            print(f"Discharge Cycles:      {cycles}")

def main():
    with can.interface.Bus(channel='can0', bustype='socketcan') as bus:
        print("Initializing Terminal Monitor...")
        while True:
            # Periodically poll the BMS for data [cite: 5, 6]
            request_bms_data(bus, 0x101)
            time.sleep(0.1)
            request_bms_data(bus, 0x100)
            
            # Read and display response
            msg = bus.recv(timeout=1.0)
            if msg:
                parse_and_display(msg)
            time.sleep(1)

if __name__ == "__main__":
    main()