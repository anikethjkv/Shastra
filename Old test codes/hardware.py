import time
import math
import os
from smbus2 import SMBus
from gpiozero import DigitalInputDevice

class BikeHardware:
    def __init__(self):
        self.SMOKE_PIN = 23 # Physical pin 16
        self.MPU_ADDR = 0x68
        
        # Initialize Smoke Sensor
        try:
            # Logic 0 = FIRE | Logic 1 = SAFE
            self.smoke_sensor = DigitalInputDevice(self.SMOKE_PIN, pull_up=True)
            print(f"Smoke sensor initialized on GPIO {self.SMOKE_PIN}")
        except Exception as e:
            print(f"Hardware Bypass: Smoke sensor not found ({e})")
            self.smoke_sensor = None

        # Initialize MPU6050
        try:
            self.bus = SMBus(1)
            self.bus.write_byte_data(self.MPU_ADDR, 0x6B, 0)
            print("MPU6050 initialized.")
        except Exception as e:
            print(f"Hardware Bypass: I2C/MPU6050 not found ({e})")
            self.bus = None

    def _read_mpu_word(self, reg):
        if not self.bus: return 0
        try:
            high = self.bus.read_byte_data(self.MPU_ADDR, reg)
            low = self.bus.read_byte_data(self.MPU_ADDR, reg+1)
            val = (high << 8) + low
            return -((65535 - val) + 1) if val >= 0x8000 else val
        except:
            return 0

    def get_sensor_payload(self):
        # Smoke Detection Logic
        smoke_active = False
        if self.smoke_sensor:
            # value is 0 when smoke is detected
            smoke_active = (self.smoke_sensor.value == 0)

        return {
            "speed": (math.sin(time.time() * 0.5) + 1) * 30, # Mock speed
            "battery_voltage": 72.0, # Target battery
            "smoke_detected": smoke_active,
            "gps_status": os.path.exists('/dev/ttyACM0'),
            "lte_status": os.path.exists('/dev/ttyAMA0'),
            "gyro": {
                "x": self._read_mpu_word(0x43),
                "y": self._read_mpu_word(0x45),
                "z": self._read_mpu_word(0x47)
            },
            "timestamp": time.time()
        }
