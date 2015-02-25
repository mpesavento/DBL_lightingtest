// This should plot the pixels of APA102 created for module 14
// coordinates created by Alex Maki-Jokela

String lines[];
class Particle {
  int i; //linear index
  float x,y,z;
  int r,g,b;
}

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

float spinx = 0;
float spinz = 0;
void draw() {
  background(0);
  translate(width/2, height/2, 525);
  rotateX(PI/3+spinx);
  rotateZ(-PI/6+spinz);
  noFill();
  strokeWeight(3);
  
  //spinx+=0.01;
  //spinz+=0.005;

  wave1 += inc1;
  wave2 += inc2;
  wave3 += inc3;

  
  for(int i=0; i<particles.size(); i++){
     Particle p = particles.get(i);
     stroke(qsub8(sin8(mul1*i + wave1), lvl1),
            qsub8(sin8(mul2*i + wave2), lvl2), 
            qsub8(sin8(mul3*i + wave3), lvl3));
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
//output is unsigned uint8_t
int sin8(int x) {
  return int( (sin( (x/128.0)*PI) * 128) + 128);
}



