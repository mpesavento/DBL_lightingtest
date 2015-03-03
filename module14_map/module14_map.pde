// This should plot the pixels of APA102 created for module 14
// coordinates created by Alex Maki-Jokela





/**** globals ****************************/

int ROTATION_TYPE = 1;
// 0 = no motion
// 1 = wiggle around z
// 2 = rotate clockwise around z

//rotate the coordinate frame so LIE-LAW axis is vertical, LIE (origin) on the bottom
float sx = 0;
float sz = 0;

//starting angle for tilt along X (azimuth), 0 is top-down,PI/4 is 
//float phi = 0;
//float phi = PI/8;
//float phi = PI/6;
float phi = PI/4;
//float phi = PI/3;


float theta = 0; //not used, for rotating along Z?

/* this is waaaay more complicated than it needs to be! */
float XSPIN_RATE = 0; // 0.008
float ZSPIN_RATE = 0.01; // 0.008
int WIGGLE_RATE = 200;

float spinx = 0; //object spin rate, X
float spinz = ZSPIN_RATE;
int spinz_dir = 1;
int wiggle_count = 0; //loop over this til wiggle_count % WIGGLE_RATE==0 and change directions

// particle buffer
ArrayList<Particle> particles;

// init global variables for 3sin sequence
int thisdelay=8; // a delay value for the sequence(s)

int wave1=0;
int wave2=0;
int wave3=0;
int inc1=2;
int inc2=1;
int inc3=-3;

int lvl1=80;
int lvl2=80;
int lvl3=80;

int mul1=20;
int mul2=25;
int mul3=22;

/**** methods ****************************/


String lines[];
class Particle {
  int i; //linear index
  float x,y,z;
  int r,g,b;
}

void rotateCamera() {
  // look through this for more!
  // https://processing.org/tutorials/p3d/
  
  //use mouse!
  //camera(mouseX, height/2, (height/2) / tan(PI/6), width/2, height/2, 0, 0, 1, 0);
}

void setModelRotate() {
  
  switch (ROTATION_TYPE) {
    case 0: // no rotation
      translate(width/2-40, height/2, 520); //center LIE in screen
      rotateX(phi);
//      spinz=0;
      break;
    case 1: // wiggle on Z
      translate(width/2-40, height/2, 520); //center LIE in screen
      if (wiggle_count % WIGGLE_RATE==0) {
        wiggle_count=0;
        spinz_dir*=-1; // change sign of spin
      }
      spinx+=XSPIN_RATE;
      spinz+=spinz_dir*ZSPIN_RATE;
      rotateX(phi);
      rotateZ(spinz);
      break;
    case 2: 
      translate(width/2, height/2, 500); // not quite centered, since origin (0,0,0) at LIE is not in center of object
      spinx+=XSPIN_RATE;
      spinz+=ZSPIN_RATE;
      rotateX(phi+spinx);
      rotateZ(spinz);
     break; 
  }
  wiggle_count+=1;
}  

void setup() {
  size(1024,768, P3D);
  lines = loadStrings("C:\\Users\\mpesavento\\src\\DBL_lightingtest\\led_positions.csv");
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
}


void draw() {
  background(0);
  noFill();
  strokeWeight(3);
  
  setModelRotate();
  
  //spinx+=0.01;
  //spinz+=0.003;

  wave1 += inc1;
  wave2 += inc2;
  wave3 += inc3;

  
  for(int i=0; i<particles.size(); i++){
     Particle p = particles.get(i);
     stroke(qsub8(sin8(mul1*i + wave1), lvl1), //R
            qsub8(sin8(mul2*i + wave2), lvl2),  //G
            qsub8(sin8(mul3*i + wave3), lvl3)); //B
     point(p.x, p.y, p.z);    
  }


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



