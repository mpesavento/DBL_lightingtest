
String lines[];
class Particle {
  float x,y,z;
  int r,g,b;
}

ArrayList<Particle> particles;

void setup() {
  size(1600, 1200, P3D);
  lines = loadStrings("C:\\Users\\mpesavento\\src\\DBL_lightingtest\\led_positions.txt");
  particles = new ArrayList<Particle>();
  for(int i = 0; i<lines.length; i++){    
     float[] dims = float(split(lines[i], ','));
     Particle p = new Particle();
     p.x = dims[0];
     p.y = dims[1];
     p.z = dims[2];
     particles.add(p);
  }
}

float spinx = 0;
float spinz = 0;
void draw() {
  background(0);
  translate(width/2, height/2, 700);
  rotateX(PI/2+spinx);
  rotateZ(-PI/6+spinz);
  noFill();
  strokeWeight(3);
  
  //spinx+=0.01;
  spinz+=0.01;
  
  for(int i=0; i<particles.size(); i++){
     Particle p = particles.get(i);
     stroke(int(random(255)), int(random(255)), int(random(255)));
     point(p.x, p.y, p.z);    
  }


}

