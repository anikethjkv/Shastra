#include <SPI.h>
#include <mcp_can.h>

const int TX_CAN_ID = 0x40;       // Arduino -> Pi (Switches)
const int RPI_CAN_ID = 0x41;      // Command from Pi
const int REMOTE_START_RELAY = 8; // Pin for Remote Start Relay

MCP_CAN CAN0(10); 

const int inputPins[] = {7, 6, 5, 4, 3, 2}; 
const int relayPins[] = {A5, A4, A3, A2, A1, A0}; 

unsigned long lastSendTime = 0;
unsigned long lastCommandTime = 0;
const int sendInterval = 100; 
const unsigned long TIMEOUT_MS = 2000; 

void setup() {
  pinMode(REMOTE_START_RELAY, OUTPUT);
  digitalWrite(REMOTE_START_RELAY, HIGH); // Default OFF

  for(int i = 0; i < 6; i++) {
    pinMode(relayPins[i], OUTPUT);
    digitalWrite(relayPins[i], HIGH);
    pinMode(inputPins[i], INPUT_PULLUP);
  }
  
  // Initializing at 250KBPS (ensure this matches RPi and Motor Controller)
  if(CAN0.begin(MCP_ANY, CAN_500KBPS, MCP_8MHZ) == CAN_OK) {
      CAN0.setMode(MCP_NORMAL);
  }
}

void loop() {
  // --- 1. RECEIVE FROM RPI (0x41) ---
  if(CAN0.checkReceive() == CAN_MSGAVAIL) {
    long unsigned int rxId;
    unsigned char len = 0;
    unsigned char buf[8];

    CAN0.readMsgBuf(&rxId, &len, buf);

    if(rxId == RPI_CAN_ID) {
      lastCommandTime = millis(); 
      if(buf[0] == 1) {
          digitalWrite(REMOTE_START_RELAY, LOW);  // Relay ON
      } else if(buf[0] == 0) {
          digitalWrite(REMOTE_START_RELAY, HIGH); // Relay OFF
      }
    }
  }

  // --- 2. TIMEOUT SAFETY ---
  // Automatically shuts off remote start if connection to RPi is lost
  if (millis() - lastCommandTime > TIMEOUT_MS && lastCommandTime > 0) {
    digitalWrite(REMOTE_START_RELAY, HIGH); 
  }

  // --- 3. SWITCH LOGIC ---
  byte currentStates = 0;
  for(int i = 0; i < 6; i++) {
    if (digitalRead(inputPins[i]) == LOW) {
      digitalWrite(relayPins[i], LOW);
      currentStates |= (1 << i);
      // This is nothing but currentStates = currentStates | ( 1 << i). This is Left shifting number 1 by i times and oring with currentStates
    } else {
      digitalWrite(relayPins[i], HIGH);
    }
  }

  // --- 4. SEND TO RPI (0x40) ---
  unsigned long currentTime = millis();
  if (currentTime - lastSendTime >= sendInterval) {
    lastSendTime = currentTime;
    CAN0.sendMsgBuf(TX_CAN_ID, 0, 1, &currentStates);
  }
   // Byte order of Can is given by currentStatus
  // 1   ->   Left Indicator
  // 2   ->   Right Indicator
  // 3   ->   Horn
  // 4   ->   Brake Light
  // 5   ->   Headlight and Tail light.
  // 6   ->   High beam
}