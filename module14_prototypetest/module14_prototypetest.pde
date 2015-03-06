import hypermedia.net.*;
import peasy.*;
import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress remoteOSCLocation;

PeasyCam cam;
UDP udp;

int TOTAL_NUMLED = 1545; //total number of LEDs on module

int NUM_LED = 300; // max number of LEDs in each strand

/* ideally I would make a object to iterate over each of these individual buffers, and then create
a function that would map the full pixel string to each separate buffer, split at strandIx pixel index.
*/
// for now have separate buffers for each string
byte[] packet0 = new byte[21 + NUM_LED*3];
byte[] packet1 = new byte[21 + NUM_LED*3];
byte[] packet2 = new byte[21 + NUM_LED*3];
byte[] packet3 = new byte[21 + NUM_LED*3];
byte[] packet4 = new byte[21 + NUM_LED*3];


//always add final index for end of actual strand +1
int[] strandIx = {0, 300, 600}; //these can be mutable, depending on how many pixels actually in string
//int[] strandIx = {0, 300, 600, 900}; //these can be mutable, depending on how many pixels actually in string


String lines[]; //reading in pixel index & XYZ from file

// tried to use this for the center of the object, unclear if this works
float[] coord_LAW = {-30.4079, 9.60728, 74.5791};

float phi = PI/4; // starting angle for tilt along X; 0 is top down, PI/4 is 45 deg
//float phi = 0;


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

// placeholder, use this to access Muse variables specifically
void oscEvent(OscMessage theOscMessage) 
{  
  // get the first value as an integer
  int firstValue = theOscMessage.get(0).intValue();
 
  // get the second value as a float  
  float secondValue = theOscMessage.get(1).floatValue();
 
  // get the third value as a string
  String thirdValue = theOscMessage.get(2).stringValue();
 
  // print out the message
  print("OSC Message Recieved: ");
  print(theOscMessage.addrPattern() + " ");
  println(firstValue + " " + secondValue + " " + thirdValue);
}





void setup() {

  udp = new UDP(this, 6038);
  udp.listen( true );
  buildPacketHeader(packet0);
  buildPacketHeader(packet1);
  buildPacketHeader(packet2);
  
  oscP5 = new OscP5(this, 5000); // read from muse port
  remoteOSCLocation = new NetAddress("127.0.0.1", 5000);  
  
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
  
  //cam = new PeasyCam(this,0,0,0, 10);
  //cam = new PeasyCam(this, 0,0,0, 10);
  //cam.setMinimumDistance(50);
  //cam.setMaximumDistance(500);
  //cam.setYawRotationMode();
}

void updateAnimation() {
  translate(width/2-40, height/2, 500); //center LIE in screen
  rotateX(phi);
  background(0);
  noFill();
    
}


void draw() {
  
  updateAnimation();
  
  //attempt to show origin and where LAW is
  strokeWeight(10);
  stroke(255,255,255);
  //point(coord_LAW[0],coord_LAW[1],coord_LAW[2]); //this Z puts it way out of frame. how are we flattening the module?
  point(-coord_LAW[0],-coord_LAW[1],0);
  point(0,0,0);
  
  
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
    strokeWeight(3);
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



