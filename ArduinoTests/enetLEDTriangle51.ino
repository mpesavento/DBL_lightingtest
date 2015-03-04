//Ethernet to WS2811 bridge for max et


#include "FastLED.h"
#include <SPI.h>         // needed for Arduino versions later than 0018
#include <Ethernet.h>
#include <EthernetUdp.h>         // UDP library from: bjoern@cs.stanford.edu 12/30/2008
#define NUM_LEDS 300
#define DATA_PIN 6

#define UDP_TX_PACKET_MAX_SIZE 938

CRGB leds[NUM_LEDS];


// Enter a MAC address and IP address for your controller below.
// The IP address will be dependent on your local network:
//byte mac[] = {  
//  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte mac[] = {  
  0xAA, 0xAE, 0xAF, 0xAA, 0xEA, 0xEF };
IPAddress ip(192.168.1.51);

unsigned int localPort = 6038;      // local port to listen on

const int num_channels = 900;
const int ck_header = 8;

EthernetUDP Udp;

// buffers for receiving and sending data
//char packetBuffer[UDP_TX_PACKET_MAX_SIZE]; //buffer to hold incoming packet,
char packetBuffer[UDP_TX_PACKET_MAX_SIZE]; //buffer to hold incoming packet
//har vals_tmp[ck_header + num_channels]; //buffer to hold incoming packet
//char vals[num_channels]; //buffer to hold incoming packet
//char vals[ck_header + num_channels]; //buffer to hold incoming packet

//int dataPin = 2;
//int clockPin = 3;
//Adafruit_WS2801 strip = Adafruit_WS2801(num_channels/3, dataPin, clockPin);

//WS2801 strip = WS2801(160);

void setup() {
  // start the Ethernet and UDP:
  Ethernet.begin(mac,ip);
  Udp.begin(localPort);

  //Serial.begin(57600);
  
   FastLED.addLeds<NEOPIXEL, DATA_PIN>(leds, NUM_LEDS);
Serial.println("enetNeoPixel finished setup");
}

void loop() {
  // if there's data available, read a packet
  int packetSize = Udp.parsePacket();
  if(packetSize)
  {

//Udp.read(packetBuffer,UDP_TX_PACKET_MAX_SIZE);

Udp.read( (char*)leds, NUM_LEDS * 3);

//    for (int n=0; n < NUM_LEDS  ; n++) {
//
//int nz = n*3+21;
// leds[n].setRGB(packetBuffer[nz],packetBuffer[nz+1],packetBuffer[nz+2]);
// 
// 
//   }
// 
   
  }
 
    FastLED.show();
}




