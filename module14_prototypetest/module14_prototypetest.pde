import hypermedia.net.*;



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

float master_gain = 0.45; //0.5;

color white = color(255,255,0);

int[] ctrl_color = {color(255,0,0),
                  color(0,255,0),
                  color(0,0,255),
                  color(255,255,0),
                  color(255,0,255)
                };
                

int TOTAL_NUMLED = 1483; //total number of LEDs on module
int NUM_LED = 300; // max number of LEDs in each strand

int PATTERN_INTERVAL = 15; //60; // number of seconds to play pattern before switching to the next
int NUM_PATTERN = 4; //number of patterns to iterate through
int curpattern = 0;
float lastTime; //holds last recorded tie for the pattern timer

boolean MOUSE_ROTATE = boolean(1); // use the mouse to rotate the image, or not.

// container of byte arrays for each controller
ArrayList<byte[]> packet_list;


String lines[]; //reading in pixel index & XYZ from file

int loop_counter = 0; //count iterations on loop

float phi = PI/4; // starting angle for tilt along X; 0 is top down, PI/4 is 45 deg
//float phi = 0;

double[][] minmaxxyz = new double[3][2];


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
  int curstrand=0;
  byte[] packet = packet_list.get(0);
  for (int ii=0; ii< particles.size(); ii++) {
    Particle cp = particles.get(ii);
    if (cp.strand != curstrand) {
      //println("strand changed: " + str(curstrand) + " to " + str(cp.curstrand));
      curstrand = cp.strand;
      packet = packet_list.get(cp.strand); //update to next packet
    }
      
    packet = packet_list.get(cp.strand); //update to next packet
    packet[21+cp.offset*3 +0] = byte(int(cp.r*master_gain) & 0xFF); // R 
    packet[21+cp.offset*3 +1] = byte(int(cp.g*master_gain) & 0xFF); // G
    packet[21+cp.offset*3 +2] = byte(int(cp.b*master_gain) & 0xFF); // B   

  }   
    
}




void updateScreen() {
  Particle mp = findCentroid(particles);
  if (MOUSE_ROTATE) {
    rotateCamera(particles, int(MOUSE_ROTATE)); //use the mouse to rotate the camera
  }
  else {
    translate(width/2-30, height/2-20, 530);
    //rotateY(PI/2);
    rotateZ(-PI/6);
    //rotateX(phi);
  }
  background(0);
  noFill();
  
  // print framerate
  textSize(6);
  fill(255,255,255);
  text("fps=" + str(int(frameRate)), -100, 125);
  //println(str(frameRate));
    
}


//****************************************************************************
//  setup() and draw()

void setup() {
  size(1024,768, P3D);
  textMode(SHAPE);
  
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
  double min_x=0.0;
  double max_x=0.0;
  double min_y=0.0;
  double max_y=0.0;
  double min_z=0.0;
  double max_z=0.0;
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
     if (p.x>max_x){
       max_x=p.x;
     }         
     if (p.x<min_x){
       min_x=p.x;
     }
     if (p.y>max_y){
       max_y=p.y;
     }         
     if (p.y<min_y){
       min_y=p.y;
     }
     if (p.z>max_z){
       max_z=p.z;
     }         
     if (p.z<min_z){
       min_z=p.z;
     }
  }
  minmaxxyz = new double[][]{{min_x,max_x},{min_y,max_y},{min_z,max_z}};
  TOTAL_NUMLED = particles.size();
  println("found " + TOTAL_NUMLED + " pixels");
  
  // set each strip to its own color
  loadPixelColorByStrip();
  
  lastTime = millis();
  
  initPatterns(particles, "TestColors3.jpg");
  //initPatterns(particles, "painting.png");
  //initPatterns(particles, "TestColors2.jpg");
  //initPatterns(particles, "vertical.png");
}



void draw() {
  loop_counter++;
  //println("t= " + str(loop_counter));
  updateScreen();
  
  //attempt to show origin and where LAW is
  strokeWeight(10);
  stroke(255,255,255);
  point(0,0,0);
  
  
  
  if ( millis()-lastTime > PATTERN_INTERVAL*1000) {
    lastTime = millis();
     curpattern = (curpattern+1) % NUM_PATTERN;
     println("switching pattern to #" + str(curpattern));
  }
  
  //loopHSV(particles);
  
  switch (curpattern) {
    case 0:
      //PATTERN: image cycling code: just uncomment this line
      slideTheImage(particles, 10);
      think(particles); // neurons talking animation
      break;
    case 1:
      //PATTERN: Radial spheres: Uncomment this block
      radial3dspheres_reverse(particles, 0.004+Math.random()*0.004);
      think(particles); // neurons talking animation
      break;
    case 2:
      //PATTERN: Radial spheres: Uncomment this block
      radial3dspheres_blue(particles, 10);
      think(particles); // neurons talking animation
      break;
    case 3:
      //PATTERN: loop over hue values
      loopHSV(particles);
      break;
  }
  
     
   
  
  updatePackets();

  // draw pixels in sim
  for (int i =0 ; i<particles.size(); i++) {
    Particle p = particles.get(i);
    strokeWeight(3);
    stroke(color(p.r, p.g, p.b));
    point(p.x, p.y, p.z);
  }
  
  
  //delay(5); //some power supplies freak out if this is less than 30ms or so
  udp.send(packet_list.get(0), "10.4.2.11"); // 0-299
  udp.send(packet_list.get(1), "10.4.2.15"); // 300-599
  udp.send(packet_list.get(2), "10.4.2.12"); // 600-899
  udp.send(packet_list.get(3), "10.4.2.10"); // 900-1199
  udp.send(packet_list.get(4), "10.4.2.16"); // 1200-1500
}





//***********************************************************
// teh maths


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

