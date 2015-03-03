// a simple test to interpolate x,y,z values for each LED from a lookup table of bar end points
// should set r,g,b based on x,y,z position. Still needs to be debugged!

#include "FastLED.h"

#define NUM_LEDS 300
#define CLOCK_PIN 11
#define DATA_PIN 12
CRGB leds[NUM_LEDS];
//#define DEBUG_SERIAL
  	
//segment	start	end	x1	y1	z1	x2	y2	z2
//FOG-LAW	134	179	-48.3600692	-38.24698348	28.77890415	-45.4397	-13.12042	13.2248
//EVE-OLD	225	286	-28.83402422	9.185582321	21.50898854	-8.6436	        -25.61328	21.9743
//LIE-TAU	1	82	-0.30368428	-0.574802553	0.089074841	-24.8563	-47.0471	7.2907
//OLD-LIE	287	339	-8.480794893	-25.13084527	21.56040668	-0.177734431	-0.526674272	0.451847575
//TAU-FOG	83	133	-25.32256429	-46.88398673	7.722612162	-48.4246	-38.8022	29.1226
//LAW-EVE	180	224	-45.0747957	-12.60761337	13.41035497	-29.1633	9.7531	        21.5014

// the start and end LED indices
const uint16_t data[] = {
134,	179,
225,	286,
1,	82,
287,	339,
83,	133,
180,	224
};

//the x,y,z positions in 16 bit format
const uint16_t data2[] = { 
55, 8601, 65245, 2523, 29835, 52100,
16556, 48686, 59101, 33619, 19278, 59494,
40667, 40438, 40999, 19918, 1164, 47085,
33756, 19686, 59144, 40773, 40478, 41305,
19523, 1302, 47450, 0, 8132, 65535,
2831, 30269, 52257, 16278, 49166, 59094
};
  
 const int numBars = 6;
   



void setup() 
{ 
    delay( 2000 ); // power-up safety delay
     FastLED.addLeds<APA102, DATA_PIN, CLOCK_PIN, GBR>(leds, NUM_LEDS);
     
#ifdef DEBUG_SERIAL
      Serial.begin(9600);           // set up Serial library at 9600 bps
      Serial.println("Running xyz!");  //for debugging
#endif
}
  
  
  	
void loop() 
{ 
   #ifdef DEBUG_SERIAL
     static int i = 0;
   
     if(i<5)
     {
        i++;
        Serial.print("loop "); 
        Serial.println(i);  //debug
     }
   #endif
   
       for(int bar=0; bar<numBars; bar++)
       {
          #ifdef DEBUG_SERIAL
            Serial.println(" --------------------- "); 
            Serial.print("bar ");  
            Serial.println(bar);   //debug
          #endif
          
         //look up the values from the data arrays for this bar:
          uint16_t startLED = data[(bar-1)*2    ];
          uint16_t endLED   = data[(bar-1)*2 + 1];
          uint16_t x1 = data2[(bar-1)*6    ];
          uint16_t y1 = data2[(bar-1)*6 + 1];
          uint16_t z1 = data2[(bar-1)*6 + 2];
          uint16_t x2 = data2[(bar-1)*6 + 3];
          uint16_t y2 = data2[(bar-1)*6 + 4];
          uint16_t z2 = data2[(bar-1)*6 + 5];
          
          #ifdef DEBUG_SERIAL
            Serial.print("x1 ");  
            Serial.println(x1);  //debug
          #endif
      
          int range = (endLED-startLED);
          for(int ii = startLED; ii < endLED; ii++) 
          {
            int frac = (ii-startLED)/range;
            int x = lerp16by16( x1, x2, frac );
            int y = lerp16by16( x1, x2, frac );
            int z = lerp16by16( x1, x2, frac );
            
            if(ii<NUM_LEDS)
            {
                leds[ii] = CRGB( x/256 ,y/256, z/256);
//                leds[ii] = CRGB( 255 ,255, 0);//test
            }
          }
       }
   
   FastLED.show();
}
