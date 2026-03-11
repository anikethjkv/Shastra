import time
from hardware import BikeHardware

def main():
    print("--- Initializing Hardware Interface ---")
    
    # Initialize the class exactly as the main app does
    bike = BikeHardware()
    
    # Verify which pin it is using
    print(f"Monitoring Smoke Sensor on GPIO: {bike.SMOKE_PIN}")
    print("Press CTRL+C to stop")
    print("-" * 30)

    try:
        while True:
            # 1. Force an update of the hardware state
            current_state = bike.update()
            
            # 2. Extract just the smoke status
            # The hardware.py logic converts the electrical signal (0/1) 
            # into a True/False "Is there smoke?" boolean.
            is_smoke = current_state["smoke_detected"]
            
            if is_smoke:
                print("⚠️  FIRE DETECTED! (Sensor Active)")
            else:
                print("✅  Clear (Safe)")
                
            time.sleep(0.5)

    except KeyboardInterrupt:
        print("\nExiting...")

if __name__ == "__main__":
    main()
