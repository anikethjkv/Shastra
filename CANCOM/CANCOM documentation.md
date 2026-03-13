# CANCOM with BAC2000 using HW-184 documentation

# Pinouts of the HW-184
VCC -> 5V (Pin 2 or 4)
GND -> GND (Pin 6 or 9,14,20,25,30,34,39)
CS -> GPIO8 (Pin 24)
SCK -> GPIO11 (Pin 23)
MOSI -> GPIO10 (Pin 19)
MISO -> GPIO9 (Pin 21)
INT -> GPIO25 (Pin 22)

# Pinouts of HW-221
VA -> 3V
VB -> 5V
OE -> Active-High (5V)

# Install python-can module
sudo pip3 install python-can --break-system-packages

# After this we have to enable the SPI interface on the RPi.
sudo raspi-config

# Navigate to Interface Options -> SPI.
# Select Yes to "Would you like the SPI interface to be enabled?"

# Now we have to configure the config file to enable the SPI interface.
sudo nano /boot/config.txt

# Add the following lines to the file
dtparam=spi=on
dtoverlay=mcp2515-can0,oscillator=8000000,interrupt=25

# reboot 
sudo reboot now

# Now we have to set the baud rate of the CAN interface.
sudo ip link set can0 up type can bitrate 250000

# To check if the CAN interface is working
ip -details -statistics link show can0

# To recieve your first transmission, ask the can0 device to dump the data
candump can0



# TPDO - Transfer Process Data Object. The Motor contoller Transmittes the Data through CAN using These Packets. 
# We have to Receive those packets on the PI and use it to Display on the Webpage
# The Controller Supports upto 8 TPDOs, Wherein Only 4 is Officially supported by OpenCAN protocal. To use the other 4 TPDO's We should manually configure the Address on the other Devices
# In the ASI controller Each TPDO can handel 4 Parameters called as maps. And Each Parameter has an address assigned. We can add one address to One map.
# In each map has 2 Entries. 1) Index , 2) SubIndex and Size.  So in Index Entry We add the Higher Address Ex: 2005. In SubIndex and size We add the Lower Address and the Size Correspoing to it Ex: 0F10
# In 2 first is subindex that is 0F and the next is Size that is 10 corresponds to Short Valuetype.
# CAN ID's are in HEX formate
# To get the Actual real word Deciaml Value of the parameter. First We must capture the HEX values from the TPDO. Then Convert the HEX values to Decimal then Divide the obtained Decimal value by the Scale (Multiplier) to get the Real world Value.
# The CAN gives transmittes the data in Little Endiean formate. That is the Lower Nibble is sent first then the Higher Nibble is sent.
# Example: Assume normal hex code 06-DE. But it will be sent by the controller as DE-06. This is what the Pi will receive we have to use it accordingly.
# The Controller Flags (1&2) are transmitted as 4 bit hexadecimal values in little endian, that is to be decoded to 16 bit binary values.

# Controller Flags
bit 0 - Brake
bit 1 - Cutout
bit 2 - Run Request
bit 3 - Pedal
bit 4 - Regen
bit 5 - Walk
bit 6 - Walk Start
bit 7 - Throttle
bit 8 - Reverse
bit 9 - Interlock Off
bit 10 - Pedal Ramp Rate Active
bit 11 - Gate Enable Request
bit 12 - Gate Enabled
bit 13 - Boost Mode
bit 14 - Anti-Theft
bit 15 - Free Wheel

# Controller Flags 2
bit 0 - Regen off Throttle Active
bit 1 - Cruise Enable Active
bit 2 - Alternate Power Limit Active
bit 3 - Alternate Speed Limit Active
bit 4 - Speed calculation using motor
bit 5 - Speed Calculation using External Sensor
bit 6 - Comm loss limp mode
bit 7 - Spare
bit 8 - Spare
bit 9 - Spare
bit 10 - Spare
bit 11 - Spare
bit 12 - Spare
bit 13 - Spare
bit 14 - Spare
bit 15 - Spare

# TPDOx - Parameter name - CAN ID - Scale (Multipler)

TPDO 1 - Controller Data - CAN ID - Scale (Multiplier)
Map1 - Controller Status - 2004 (02) - 1 
Map2 - Controller temperature - 2004 (04) - 1
Map3 - Controller Flags - 2005(08) - 1
Map4 - Controller Flags2 - 2007(29) - 1

TPDO 2 - Motor Data - CAN ID - Scale (Multiplier)
Map1 - Motor input power - 2005 (0F) - 1
Map2 - Vehicle Speed - 2004 (05) - 256
Map3 - motor RPM - 2004 (08) - 1
Map4 - Motor temperature - 2004 (06) - 1

TPDO 3 - Battery Data - CAN ID - Scale (Multipler)
Map1 - Battery Voltage - 2004 (0A) - 32
Map2 - Battery Current - 2004 (0B) - 32
Map3 - State of Charge - 2004 (0C) - 1
Map4 - temperature - 2004 (18) - 1

TPDO 4 - Motor Phase Voltages - CAN ID - Value Type - Scale (Multipler)
Map1 - Phase A voltage - 2004 (1E) - short - 32
Map2 - Phase B voltage - 2004 (1F) - short - 32
Map3 - Phase C voltage - 2004 (20) - short - 32
Map4 - Motor temp - 2004 (06) - short - 1

TPDO 5 - Motor Phase Currents - CAN ID - Value Type - Scale (Multipler)
Map1 - Phase A current -  2004 (1B) - short - 32
Map2 - Phase B current -  2004 (1C) - short - 32
Map3 - Phase C current -  2004 (1D) - short - 32

# RPDO - Recieve Process Data Object. The Pi will Transmittes the Data to the Controller through CAN using These Packets.

RPDO 1 - Controller Data - CAN ID - Scale (Multiplier)
Map1 - Alternate Power Mode - 2007(31) - 1
Map2 - 

# Digital Input Bits
bit 0 - Cut Out
bit 1 - Headlight
bit 2 - Runlight
bit 3 - Brake Light
bit 4 - Charge Disable
bit 5 - Alternate Speed
bit 6 - Alternate Power
bit 7 - Regen1
bit 8 - Regen2
bit 9 - HDQ
bit 10 - disable analog regen
bit 11 - disable reverse cadence regen
bit 12 - enable remote braking torque
bit 13 - remote can fault
bit 14 - spare
bit 15 - spare







