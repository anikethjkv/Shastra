#include <SPI.h>
#include <mcp_can.h>

const int TX_CAN_ID = 0x40;       // Arduino -> Pi (Switches)
const int RPI_CAN_ID = 0x41;      // Command from Pi

MCP_CAN CAN0(10); 

const int inputPins[] = {7, 6, 5, 4, 2}; 
const int relayPins[] = {A5, A4, A3, A2, A0}; 
const int headlight = A1;

unsigned long lastSendTime = 0;
const int sendInterval = 100; 

void setup() {

  for(int i = 0; i < 5; i++) {
    pinMode(relayPins[i], OUTPUT);
    digitalWrite(relayPins[i], HIGH);
    pinMode(inputPins[i], INPUT_PULLUP);
  }
  pinMode(headlight, OUTPUT);
  digitalWrite(headlight, HIGH); // Intializing the Headlight relay

  // Initializing at 500KBPS (ensure this matches RPi and Motor Controller)
  if(CAN0.begin(MCP_ANY, CAN_500KBPS, MCP_8MHZ) == CAN_OK) {
      CAN0.setMode(MCP_NORMAL);
  }
}

void loop() {

  // --- 1. SWITCH LOGIC and CAN BYTE UPDATION ---
  byte currentStates = 0;
  for(int i = 0; i < 5; i++) {
    if (digitalRead(inputPins[i]) == LOW) {
      digitalWrite(relayPins[i], LOW);
      currentStates |= (1 << i);
    } else {
      digitalWrite(relayPins[i], HIGH);
    }
  }
  digitalWrite(headlight, LOW);
  currentStates |= (1 << 5); // Force bit 5 HIGH — Headlight/Tail always ON at power-up
    // i is out of scope here; using explicit bit position (1 << 5) for reliability.
    // As soon as the bike is powered the headlight is ON. This ensures the bit is set in the CAN byte.

  // --- 4. SEND TO RPI (0x40) ---
  unsigned long currentTime = millis();
  if (currentTime - lastSendTime >= sendInterval) {
    lastSendTime = currentTime;
    CAN0.sendMsgBuf(TX_CAN_ID, 0, 1, &currentStates);
  }

  // Byte order of CAN byte (bit positions, 0-indexed):
  // bit 0  ->  Left Indicator
  // bit 1  ->  Right Indicator
  // bit 2  ->  Horn
  // bit 3  ->  Brake Light
  // bit 4  ->  High Beam
  // bit 5  ->  Headlight and Tail light  (ALWAYS ON in this sketch)
}