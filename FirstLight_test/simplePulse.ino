// a simple test to make some colors animate along a single strip, connected to pins 11/12

#include "FastLED.h"

#define NUM_LEDS 60
#define CLOCK_PIN 11
#define DATA_PIN 12
CRGB leds[NUM_LEDS];
  	
 void setup() 
 { 
     FastLED.addLeds<APA102, DATA_PIN, CLOCK_PIN, GBR>(leds, NUM_LEDS);
 }
  	
 void loop() 
 { 
        for(int ii = 0; ii < NUM_LEDS; ii++) 
        { 
          
//            leds[ii] = CRGB( ii, 100, 150); //CRGB::Blue;
            leds[ii] = CHSV( (ii*4)%255, 255, 255); //CRGB::Blue;
            FastLED.show();
            
            // clear /fade this led for the next time around the loop
            CRGB old = leds[(ii-3)%NUM_LEDS];
            leds[(ii-3)%NUM_LEDS] = CRGB(old.r/4, old.g/4, old.b/4);  //fade
            //leds[(ii-3)%NUM_LEDS] = CRGB::Black; //turn off completely
            delay(30);
        }
 }
