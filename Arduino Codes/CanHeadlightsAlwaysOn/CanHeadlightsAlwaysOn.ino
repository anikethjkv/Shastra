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
  currentStates |= (1 << i); // This is nothing but currentStates = currentStates | ( 1 << i). This is Left shifting number 1 by i times and oring with currentStates
    // I am doing this last line to add the bit as Head light stays on always. 
    // As soom as the bike is powered the head light is On, So this line makes sure that while sending it through can, this Data is received.

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
  // 5   ->   High beam
  // 6   ->   Headlight and Tail light.
}