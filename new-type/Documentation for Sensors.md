# First We have to install the SQLlite Database Application to handel the data coming from the sensors and to store them somewhere.
# Then it can be read by another script ment for displaying the values on the dash board

# To install the SQL lite database use the following commands

sudo apt update
sudo apt upgrade
sudo apt install sqlite3 -y

# Create a SQL lite Database at any location near the script files

sqlite3 Sensor_data.db "PRAGMA journal_mode=WAL;"

# To setup the database only to enter the values. Where the KEY = Column and the Value of the key = ROW
# Use the Below commands to enter into SQL
sqlite3 Sensor_data.db

#Then Enter the below commands to Set key value pair and time stamps

CREATE TABLE IF NOT EXISTS bike_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    sensor_name TEXT,
    reading_value REAL
);

.exit

#After entering the above Exit from SQL and come back to the terminal and install navit app

# Now Connect the Sensors as Follows

# The Pinouts of the Sensors are as Follows Regarding the pi

    Sensor Name            Pin    ->   RPI - Pin
1) Smoke Sensor            VCC    ->   Vcc(5v)
                           D0     ->   5v to 3.3v (Con)   ->  GPIO23(16)    LOW as +ve Sense
		 	   GND    ->   GND
# Adjust the Blue potentiometer On the board to set the Threshold for Smoke Detection,.


2) MPU6050                 VCC    ->   3.3v
			   SCL    ->   GPIO3 (5)
			   SDA    ->   GPIO2 (3)
			   AD0    ->   GND - Address Set to 0x68
			   GND    ->   GND

# using the I2c Interface to communicate with Raspberry pi.

3) Hall HW477 A3144        VCC    ->   5v
   To Get the Speed        GND    ->   GND
   From the Wheel          D0     ->  5v to 3.3v (Con)   ->  GPIO12 (32)    LOW as +ve Sense
   and Distance covered	   With a Pull up to VCC by a 10k Ohm Resistor to D0.

4) GPS sensor              VCC    ->   3.3v
   NEO6M                   TX     ->   GPIO15 (10)
                           RX     ->   GPIO14 (08)
                           GND    ->   GND


# mapping to Gpsd Socket is required and the GPS sensor data can be accessed system wide by Gpsd Protocal
# To Enable the GPIO 14 and 15 on the RPi as hardware Serial pin.

sudo raspi-config

# Navigate to Interface Options -> Serial Port.
# Select No to "Would you like a login shell to be accessible over serial?".
# Select Yes to "Would you like the serial port hardware to be enabled?". 
# Inside the Interface Options Enable I2c for MPU Sensor and also Enable SSH and VNC To Connect over the Network and access the pi.
# Reboot the device.

# Edit the Config File of GPSD and point it to the Hardware GPIO pins

sudo nano /etc/default/gpsd

# Enter the Following lines in the file

START_DAEMON="true"
USBAUTO="false"
DEVICES="/dev/ttyAMA0"
GPSD_OPTIONS="-n"

# Then Exit from nano using CTRL + X and then press Y to save and Exit.
# Then to Set it to run at Boot Run the following commands

sudo systemctl enable gpsd.socket
sudo systemctl start gpsd.socket


5) LTE module              TX, RX, GND  ->  USB TTL Converter
   SIMC A7670C		   Requires 9v or higher through the Barrel jack for it to work
   With RS232              In Serial Communication Tx of Source must connect to RX of Sink Vice Voce


# To install NAVIT and Speach Language run the below commands
sudo apt install navit espeak-ng -y

# Lets Create the Script which handels all the communication between the Sensor modules and SQL data base
# The code can be found in the script it self

nano Sensor_read.py

# Enter the code and close the file
# Run the Below commands to install all the dependencies

sudo pip3 install mpu6050-raspberrypi --break-system-packages

# Install the GPSD library & using pip as they are not available in APT package manager to Run System wide.
sudo pip3 install gpsd-py3 --break-system-packages

# Ensure the system-wide GPS and GPIO tools are present
sudo apt install python3-gps python3-gpiozero i2c-tools -y


# Pinout for Arduino Uno

1) HW184 CAN - Module Pinouts
 
                PIN ->  Arduino Pin
		VCC ->	5V	
                GND ->	GND	
 		CS  ->	D10	SPI Chip Select	
          SI (MOSI) ->	D11	SPI Data In	
          SO (MISO) ->	D12	SPI Data Out	
               SCK  ->	D13	SPI Clock	
	       INT  ->	D9	Interrupt 0

2) 4 Channel Relay - 

		PIN      ->      Arduino Pin    -> Use of Relay
		VCC      ->      5V     	
		GND      ->      GND
		IN1      ->      A5		-> Left Indicator
		IN2      ->      A4		-> Right Indicator
		IN3      ->      A3		-> Horn
		IN4      ->      A2		-> Brake Light

3) 2 Channel Relay -
		
		PIN      ->      Arduino Pin    -> Use of Relay
		VCC      ->      5v
		GND	 ->	 GND
		IN1	 ->	 A1		-> HeadLight & Tail Lamp
		IN2	 -> 	 A0	 	-> High Beam 

4) Inputs -

		PIN	 ->	 Arduino Pin 	-> Use of Pin
		Left I	 ->	 D7
		Right I  ->	 D6
		Horn 	 -> 	 D5
		Brake 	 -> 	 D4
Headlight / Tail light	 -> 	 D3
	     High Beam   ->      D2
		




