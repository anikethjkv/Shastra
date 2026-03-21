#!/bin/bash

# Navigate to the script's directory (new-type)
cd "$(dirname "$0")"

echo "Cleaning up old processes..."
pkill -f "python3 Cancom.py"
pkill -f "python3 SensorReader.py"
pkill -f "python3 api.py"
kill $(lsof -ti:8080) 2>/dev/null
sleep 1

echo "Opening terminals and starting Shastra Telemetry services..."

# Raspberry Pi Default (LXDE Desktop)
if command -v lxterminal &> /dev/null; then
    lxterminal --title="CAN Telemetry" -e "python3 Cancom.py" &
    lxterminal --title="Sensor Reader" -e "python3 SensorReader.py" &
    lxterminal --title="API Server" -e "python3 api.py" &

# Secondary Debian Default Fallback
elif command -v x-terminal-emulator &> /dev/null; then
    x-terminal-emulator -T "CAN Telemetry" -e "python3 Cancom.py" &
    x-terminal-emulator -T "Sensor Reader" -e "python3 SensorReader.py" &
    x-terminal-emulator -T "API Server" -e "python3 api.py" &

# Basic X11 Fallback
elif command -v xterm &> /dev/null; then
    xterm -title "CAN Telemetry" -hold -e "python3 Cancom.py" &
    xterm -title "Sensor Reader" -hold -e "python3 SensorReader.py" &
    xterm -title "API Server" -hold -e "python3 api.py" &

# Mac OS fallback (if you test it on your Mac)
elif [[ "$OSTYPE" == "darwin"* ]]; then
    osascript -e 'tell app "Terminal" to do script "cd '\"$(pwd)\"' && python3 Cancom.py"'
    osascript -e 'tell app "Terminal" to do script "cd '\"$(pwd)\"' && python3 SensorReader.py"'
    osascript -e 'tell app "Terminal" to do script "cd '\"$(pwd)\"' && python3 api.py"'

# Headless / No GUI fallback
else
    echo "No GUI terminal found. Running in the background..."
    python3 Cancom.py &
    python3 SensorReader.py &
    python3 api.py &
    echo "Press Ctrl+C to stop all services."
    wait
fi

echo "Done! The dashboard is running."
