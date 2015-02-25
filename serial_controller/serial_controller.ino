// Use if you want to force the software SPI subsystem to be used for some reason (generally, you don't)
// #define FORCE_SOFTWARE_SPI
// Use if you want to force non-accelerated pin access (hint: you really don't, it breaks lots of things)
// #define FORCE_SOFTWARE_SPI
// #define FORCE_SOFTWARE_PINS
#include "FastLED.h"

///////////////////////////////////////////////////////////////////////////////////////////
//
// Move a white dot along the strip of leds.  This program simply shows how to configure the leds,
// and then how to turn a single pixel white and then off, moving down the line of pixels.
// 

#define SERIAL_SPEED 9600

// How many leds are in the strip?
#define NUM_LEDS 300

// Data pin that led data will be written out over
#define DATA_PIN 12

// Clock pin only needed for SPI based chipsets when not using hardware SPI
#define CLOCK_PIN 11

// Pin for status LED
#define STATUS_PIN 13

// This is an array of leds.  One item for each led in your strip.
CRGB leds[NUM_LEDS];

// This function sets up the ledsand tells the controller about them
void setup() {
    // sanity check delay - allows reprogramming if accidently blowing power w/leds
    pinMode(STATUS_PIN, OUTPUT);
    for (int i = 0; i < 5; i++) {
      digitalWrite(STATUS_PIN, HIGH);
      delay(100);
      digitalWrite(STATUS_PIN, LOW);
      delay(100);
    }

//    Serial.begin(SERIAL_SPEED);
//    Serial.write("BRAIN");
    
    FastLED.addLeds<APA102, DATA_PIN, CLOCK_PIN, GBR>(leds, NUM_LEDS); //init the LED array
    loopRGB();
}

//int serialReadBlocking() {
//  int b;
//  while ((b = Serial.read()) < 0) { /* Do nothing */ } 
//  return b;
//}
//
//void serialReadRGB(struct CRGB *rgb) {
//  rgb->r = serialReadBlocking();
//  rgb->g = serialReadBlocking();
//  rgb->b = serialReadBlocking();
//}

void loop() {
//  Serial.write(NUM_LEDS >> 8);
//  Serial.write(NUM_LEDS & 0xff);
//
//  int msb = serialReadBlocking();
//
////  if (msb == 0xff) {
//  if (msb) {
//    digitalWrite(STATUS_PIN, HIGH);
//    delay(200);
//    digitalWrite(STATUS_PIN, LOW);
//    loopRGB();
//    return;
//  } else {
//    return;
//  }
//
//  int lsb = serialReadBlocking();
//
//  digitalWrite(STATUS_PIN, HIGH);
//
//  if (msb & 0x80) {
//    int led = ((msb & 0x7f) * 0x100) + lsb;
//    if (led >= 0 && led < NUM_LEDS) {
//      serialReadRGB(&(leds[led])); 
//    }
//  } else {
//    int ledlo = ((msb & 0x7f) * 0x100) + lsb;
//    msb = serialReadBlocking();
//    lsb = serialReadBlocking();
//    int ledhi = ((msb & 0x7f) * 0x100) + lsb;
//    
//    if ((ledlo >= 0) && (ledhi < NUM_LEDS) && (ledlo <= ledhi)) {
//      for (int led = ledlo; led <= ledhi; led++) {
//        serialReadRGB(&(leds[led])); 
//      }
//    }
//  }
//
//  digitalWrite(STATUS_PIN, LOW);
//  FastLED.show();
}

//void errorWait()
//{
//  while (Serial.available() < 0) {
//    digitalWrite(STATUS_PIN, HIGH);
//    delay(50);
//    digitalWrite(STATUS_PIN, LOW);
//    delay(50);
//  }
//}
//
void loopRGB() {
//  Serial.write("loopRGB");
    for (int i = 0; i < NUM_LEDS; i++) {
      leds[i].r = 255;
      leds[i].g = 255;
      leds[i].b = 255;
      FastLED.show(); 
      Serial.write(i);
    }
  
    for (int i = 0; i < NUM_LEDS; i++) {
      leds[i].r = ((i % 2) ? 0x00 : 0xff);
      leds[i].g = 0;
      leds[i].b = 0;
      Serial.write(i);
    }
    FastLED.show();

    delay(500);

    for (int i = 0; i < NUM_LEDS; i++) {
      leds[i].r = 0;
      leds[i].g = ((i % 3) ? 0x00 : 0xff);
      leds[i].b = 0;
    }
    FastLED.show();

    delay(500);

    for (int i = 0; i < NUM_LEDS; i++) {
      leds[i].r = 0;
      leds[i].g = 0;
      leds[i].b = ((i % 5) ? 0x00 : 0xff);
    }
    FastLED.show();

    delay(500);
  
    for (int i = 0; i < NUM_LEDS; i++) {
      leds[i].r = ((i % 2) ? 0x00 : 0xff);
      leds[i].g = ((i % 3) ? 0x00 : 0xff);
      leds[i].b = ((i % 5) ? 0x00 : 0xff);
    }
    FastLED.show();

    delay(500);
  
    for (int i = 0; i < NUM_LEDS; i++) {
      leds[i].r = 0;
      leds[i].g = 0;
      leds[i].b = 0;
    }
    FastLED.show();
}
