import time
from hardware import BikeHardware

def main():
    print("--- Initializing Hardware Interface ---")
    bike = BikeHardware()
    
    print(f"Monitoring Smoke Sensor on GPIO {bike.SMOKE_PIN}")
    print("LOGIC: Pin 0 = FIRE | Pin 1 = SAFE")
    print("-" * 30)

    try:
        while True:
            # 1. Update reads the pin and does the conversion
            current_state = bike.update()
            
            # 2. Get the converted Boolean (True/False)
            is_smoke_present = current_state["smoke_detected"]
            
            # 3. Read raw value just for debugging visualization
            raw_pin_value = bike.smoke_sensor.value
            
            # 4. Print status
            if is_smoke_present: # This means True
                print(f"Pin State: {raw_pin_value} -> ⚠️  FIRE DETECTED!")
            else:
                print(f"Pin State: {raw_pin_value} -> ✅  Clear (Safe)")
                
            time.sleep(0.5)

    except KeyboardInterrupt:
        print("\nExiting...")

if __name__ == "__main__":
    main()
