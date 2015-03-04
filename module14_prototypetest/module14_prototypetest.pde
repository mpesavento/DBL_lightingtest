import hypermedia.net.*;
import peasy.*;

PeasyCam cam;
UDP udp;

int TOTAL_NUMLED = 1545; //total number of LEDs on module

int NUM_LED = 300;
// for now have separate buffers for each string
byte[] packet0 = new byte[21 + NUM_LED*3];
byte[] packet1 = new byte[21 + NUM_LED*3];
byte[] packet2 = new byte[21 + NUM_LED*3];

//AudioFile myInput; 
//AudioStream myStream; 
//FFT myFFT; 
float volume; 
float avgVol; 

//always add final index for end of actual strand +1
int[] strandIx = {0, 300, 600}; //these can be mutable, depending on how many pixels actually in string
//int[] strandIx = {0, 300, 600, 900}; //these can be mutable, depending on how many pixels actually in string


String lines[]; //reading in pixel index & XYZ from file

float phi = PI/4; // starting angle for tilt along X; 0 is top down, PI/4 is 45 deg

class Particle {
  int i; //linear index
  float x,y,z;
  int r,g,b;
}

// particle buffer
ArrayList<Particle> particles;


/* 
* the packet header is a variation from the ColorKinetics LED protocol, as modified by sean
*/
void buildPacketHeader(byte[] packet) {
  packet[00] = 0x04;
  packet[01] = 0x01;
  packet[02] = byte(0xdc);
  packet[03] = byte(0x4a);
  packet[04] = 0x01;
 // packet[05] = 0x00; //???? was not in orig code

  packet[06] = 0x01;
  packet[07] = 0x01;

  packet[16] = byte(0xff);  
  packet[17] = byte(0xff);
  packet[18] = byte(0xff);
  packet[19] = byte(0xff);  // port # string is connected to on the power supply.
  // packet[21] = 0x02;
  //packet[22] = byte(0x01); // number of ports
  //packet[23] = byte(0xff);

}

/******** 
these are some example test functions, but not written in java or for this framework.
Mike will modify these
*/
/*
// number, twinkle color, background color, delay
// twinkleRand(5,strip.Color(255,255,255),strip.Color(255, 0, 100),90);
// twinkle random number of pixels
void twinkleRand(int num, uint32_t c,uint32_t bg,int wait) {
  // set background
   stripSet(bg,0);
   // for each num
   for (int i=0; i<num; i++) {
     strip.setPixelColor(random(strip.numPixels()),c);
   }
  strip.show();
  delay(wait);
}
*/


/*
// very simple wave: velocity, cycles,delay between frames
// simpleWave(0.03,5,10);
void simpleWave(float rate, int cycles, int wait) {
   float pos=0.0;
  // cycle through x times
  for(int x=0; x<(strip.numPixels()*cycles); x++)
  {
      pos = pos+rate;
      for(int i=0; i<strip.numPixels(); i++) {
        // sine wave, 3 offset waves make a rainbow!
        float level = sin(i+pos) * 127 + 128;
        // set color level 
        strip.setPixelColor(i,(int)level,0,0);
      }
         strip.show();
         delay(wait);
  }
}  
*/

void setup() {

  udp = new UDP(this, 6038);
  udp.listen( true );
  buildPacketHeader(packet0);
  buildPacketHeader(packet1);
  buildPacketHeader(packet2);
  
  // create the particle animation
  size(1024,768, P3D);
  lines = loadStrings("led_positions.csv");
  particles = new ArrayList<Particle>();
  for(int i = 0; i<lines.length; i++){    
     float[] dims = float(split(lines[i], ','));
     Particle p = new Particle();
     p.i = int(dims[0]);
     p.x = -dims[1]; //flipping the sign on this because the orientation of the original node list is likely inccorrect in X
     p.y = dims[2];
     p.z = dims[3];
     particles.add(p);
  }
  TOTAL_NUMLED = particles.size();
  println("found " + TOTAL_NUMLED + " pixels");
  
  //cam = new PeasyCam(this, 100);
  //cam = new PeasyCam(this, 0,0,0, 1000);
  //cam.setMinimumDistance(50);
  //cam.setMaximumDistance(500);
  //cam.setYawRotationMode();
}

void updateAnimation() {
  background(0);
  noFill();
  strokeWeight(3);
    
}


void draw() {
  translate(width/2-40, height/2, 500); //center LIE in screen
  rotateX(phi);
  //camera(mouseX, height/2, (height/2) / tan(PI/6), width/2, height/2, 0, 0, 1, 0);
  //camera(mouseX*0.1, height/2, (height/2) / tan(PI/6), width/2, height/2, 0, 0, 1, 0);
  
  updateAnimation();
  
  int strandNum = 0;
  for (int i =0 ; i<TOTAL_NUMLED; i++) {
    Particle p = particles.get(i);

    //increment to nexdt strand
    if ( strandNum != strandIx.length-1 && i==strandIx[strandNum+1]) {
      //println("incrementing strandNum");
      strandNum++;
    }
    
    //println("pixel " + i + ",offset " + strandIx[strandNum]);
    //println("pixel " + i + ", udp offset " +  int(0-strandIx[strandNum]*3 +(i*3)+0));
    color c = color(255,255,255);    
    if (strandNum == 0) {
      c = color(255, 0,0);
      packet1[21+(i*3)+0] = byte((c >> 16) & 0xFF); // R 
      packet1[21+(i*3)+1] = byte((c >> 8) & 0xFF); // G
      packet1[21+(i*3)+2] = byte(c & 0xFF); // B
    }
    else if (strandNum==1) {
      c = color(0, 255, 0);
      packet2[21-strandIx[strandNum]*3 +(i*3)+0] = byte((c >> 16) & 0xFF); // R 
      packet2[21-strandIx[strandNum]*3 +(i*3)+1] = byte((c >> 8) & 0xFF); // G
      packet2[21-strandIx[strandNum]*3 +(i*3)+2] = byte(c & 0xFF); // B      
    }
    else {
      c = color(random(255), random(255), random(255));
      //no strand to write packet to
    }
    stroke(c);
    point(p.x, p.y, p.z);
  }
  
  
  delay(30); //some power supplies freak out if this is less than 30ms or so
  udp.send(packet1, "10.4.2.10"); // 0-299
  udp.send(packet2, "10.4.2.11"); // 300-599
  udp.send(packet2, "10.4.2.13"); // 600-899
}




// mimic FastLEDs saturating math functions
int qadd8(int i, int j) {
  return min( (i+j),0xff);
}
int qsub8(int i, int j) {
  return max((i-j),0);
}

//expected input is a uint8_t from 0-255
//output is unsigned uint8_t (0-255)
int sin8(int x) {
  return int( (sin( (x/128.0)*PI) * 128) + 128);
}



