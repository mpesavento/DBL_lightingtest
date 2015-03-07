import hypermedia.net.*;
import peasy.*;
import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress remoteOSCLocation;


UDP udp;
int UDP_PORT = 6038;


class Particle {
  int i; //linear (global) index
  int strand;
  int offset; // from start of strand
  float x,y,z;
  int r,g,b;
}

// particle buffer
ArrayList<Particle> particles;



int NUM_CTRL = 5; //number of controllers we are using

float led_gain = 0.75; //0.5;
color white = color(255*led_gain,255*led_gain,0);

int[] ctrl_color = {color(255*led_gain,0,0),
                  color(0,255*led_gain,0),
                  color(0,0,255*led_gain),
                  color(255*led_gain,255*led_gain,0),
                  color(255*led_gain,0,255*led_gain)
                };
                

int TOTAL_NUMLED = 1483; //total number of LEDs on module
int NUM_LED = 300; // max number of LEDs in each strand

boolean MOUSE_ROTATE = boolean(0); // use the mouse to rotate the image, or not.

// container of byte arrays for each controller
ArrayList<byte[]> packet_list;


String lines[]; //reading in pixel index & XYZ from file


float phi = PI/4; // starting angle for tilt along X; 0 is top down, PI/4 is 45 deg
//float phi = 0;




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




/*
* load the particle buffer with separate colors for each strip
*/
void loadPixelColorByStrip() {
  int strandix = 0;
  int r=0;
  int g=0;
  int b=0;
  int curcolor=0;
  for (int ii=0; ii< particles.size(); ii++) {
    Particle cp = particles.get(ii);
    strandix = cp.strand;
    curcolor = ctrl_color[strandix];
    
    cp.r = int(curcolor >> 16 & 0xFF);
    cp.g = int(curcolor >> 8 & 0xFF);
    cp.b = int(curcolor & 0xFF);
    // println("pixel " + str(ii) + " -> r: " + str(cp.r) + " g: " + str(cp.g) + " b: " + str(cp.b) );
    
  } 
  
}

/*
* copy the colors from the Particles array ointo the packet buffers
*/
void updatePackets() {
  int offset = -1;
  byte[] packet = packet_list.get(0);
  for (int ii=0; ii< particles.size(); ii++) {
    Particle cp = particles.get(ii);
    if (cp.offset != offset) {
      println("offset changed: " + str(offset) + " to " + str(cp.offset));
      offset = cp.offset;
      packet = packet_list.get(cp.strand); //update to next packet
    }
      
    
    packet = packet_list.get(cp.strand); //update to next packet
    packet[21+cp.offset*3 +0] = byte(cp.r & 0xFF); // R 
    packet[21+cp.offset*3 +1] = byte(cp.g & 0xFF); // G
    packet[21+cp.offset*3 +2] = byte(cp.b & 0xFF); // B   
    //packet[21-offset*3 +(ii*3)+0] = byte(cp.r & 0xFF); // R 
    //packet[21-offset*3 +(ii*3)+1] = byte(cp.g & 0xFF); // G
    //packet[21-offset*3 +(ii*3)+2] = byte(cp.b & 0xFF); // B   

  }   
    
}



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
  size(1024,768, P3D);
  
  println("opening UDP socket: " + str(UDP_PORT));
  udp = new UDP(this, UDP_PORT);
  udp.listen( true );

  //oscP5 = new OscP5(this, 5000); // read from muse port
  //remoteOSCLocation = new NetAddress("127.0.0.1", 5000);  
  
  packet_list = new ArrayList<byte[]>();
  for( int i=0; i<NUM_CTRL; i++) {
    byte[] packet = new byte[21 + NUM_LED*3 + 200];
    buildPacketHeader(packet);
    packet_list.add(packet);
  }

  // create the particle animation

  lines = loadStrings("led_positions.csv");
  particles = new ArrayList<Particle>();
  int cur_strand = -1;
  int cur_offset = 0;
  for(int i = 0; i<lines.length; i++){    
     float[] dims = float(split(lines[i], ','));
     Particle p = new Particle();
     p.i = int(dims[0]);
     p.strand = int(dims[1]);
     if (p.strand != cur_strand) {
       println("strand " + str(p.strand) + " offset: " + str(i));
       cur_strand = p.strand;
       cur_offset = 0;
       //p.offset = i;
     }
     p.offset = cur_offset;
     cur_offset++;
     p.x = -dims[2]; //flipping the sign on this because the orientation of the original node list is likely inccorrect in X
     p.y = dims[3];
     p.z = dims[4];
     p.r = 0;
     p.g = 0;
     p.b = 255;
     particles.add(p);
  }
  TOTAL_NUMLED = particles.size();
  println("found " + TOTAL_NUMLED + " pixels");
  
  // set each strip to it's own color
  loadPixelColorByStrip();

}



void updateScreen() {
  Particle mp = findCentroid(particles);
  if (MOUSE_ROTATE) {
    translate(mp.x, mp.y, mp.z); //centre centroid in screen
    rotateCamera(particles); //use the mouse to rotate the camera
  }
  else {
    translate(width/2-30, height/2+20, 530);
    //rotateY(PI/2);
    rotateZ(-PI/2);
    //rotateX(phi);
  }
  background(0);
  noFill();
    
}


void draw() {
  
  updateScreen();
  
  //attempt to show origin and where LAW is
  strokeWeight(10);
  stroke(255,255,255);
  //point(coord_LAW[0],coord_LAW[1],coord_LAW[2]); //this Z puts it way out of frame. how are we flattening the module?
  //point(-coord_LAW[0],-coord_LAW[1],0);
  point(0,0,0);
  
  //byte[] extractedData = (byte[])packet_list[0];
  
  updatePackets();

  for (int i =0 ; i<particles.size(); i++) {
    Particle p = particles.get(i);

    strokeWeight(3);
    stroke(color(p.r, p.g, p.b));
    point(p.x, p.y, p.z);
  }
  
  
  delay(30); //some power supplies freak out if this is less than 30ms or so
  udp.send(packet_list.get(0), "10.4.2.11"); // 0-299
  udp.send(packet_list.get(1), "10.4.2.15"); // 300-599
  udp.send(packet_list.get(2), "10.4.2.12"); // 600-899
  udp.send(packet_list.get(3), "10.4.2.10"); // 900-1199
  udp.send(packet_list.get(4), "10.4.2.14"); // 1200-1500
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

