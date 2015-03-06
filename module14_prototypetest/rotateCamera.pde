
void rotateCamera(ArrayList<Particle> particlesToCentreOn) {
  // look through this for more!
  // https://processing.org/tutorials/p3d/

  //set perspective: fov, aspect ratio, and front/rear clipping planes
  float fov = PI/3; //60 degree vertical field of view
  float cameraZ = (height/2.0) / tan(fov/2.0);
  perspective(fov, float(width)/float(height), cameraZ/100.0, cameraZ*10.0);

  //use mouse!
  float zoom = 0.1;//2.0*mouseY/height;

  float x, y, z, mx, my, ox, oy, oz, vx, vy, vz, oox, ooy, ooz;
  float tx, ty, tz; //theta x,y,z - rotation of camera around each axis away from default position
  mx = mouseX; //mouse coords in window
  my = mouseY;
  oox = width/2; //origin x of centre of window
  ooy = height/2; //origin y of centre of window
  ooz = 0; //origin z of centre of window

  vx = width/2; //default camera positon x
  vy = height/2; //default camera positon y
  vz = (height/2)/ tan(fov/2); //default camera positon z

  //set camera pos based on centre of mass of object, and use mouse to rotate
  Particle meanParticle = findCentroid(particlesToCentreOn);
  float scale = findScale(particlesToCentreOn)*2;
  //zoom = scale/(height/2);
  ox = meanParticle.x; //origin x of centre of model
  oy = meanParticle.y; //origin y of centre of model
  oz = meanParticle.z; //origin z of centre of model
  
  vx = ox; //default camera positon x
  vy = oy; //default camera positon y
  vz = oz + (scale/2)/ tan(fov/2); //default camera positon z

  ty = PI/2*(mx-oox)/oox; //map x mouse position to +-pi
  tx = PI/2*(my-ooy)/ooy; //map y mouse position to +-pi

  x = vx;
  y = vy;
  z = vz;

  //first rotate around y axis
  x = ox + (vz-oz)*sin(ty);
  y = vy;
  z = oz + (vz-oz)*cos(ty);



  //define a new axis to rotate around, and create a 3x3 rotation matrix that rotates around it
  float aX = x-ox;
  float aY = y-oy;
  float aZ = z-oz;
  
  aX = 1;
  aY = 0;
  aZ = 0;
  
  ///create rotaiton matrix to rotate around y axis 
  float[] Rmat;
  Rmat = CreateRotationMatrixAroundAxis(aX, aY, aZ, tx);

  //rotate around new axis
  float x1 = ox + (x-ox)*Rmat[0] + (y-oy)*Rmat[1] + (z-oz)*Rmat[2];
  float y1 = oy + (x-ox)*Rmat[3] + (y-oy)*Rmat[4] + (z-oz)*Rmat[5];
  float z1 = oz + (x-ox)*Rmat[6] + (y-oy)*Rmat[7] + (z-oz)*Rmat[8];
  x=x1;
  y=y1;
  z=z1;

  //println("theta y=",nf(ty*180/PI,3,2),   "theta x=",nf(tx*180/PI,3,2), "\t",    "x",nf(x,3,2) ,"y", nf(y,3,2),"z", nf(z,3,2));
  println(Rmat[0], Rmat[1], Rmat[2], "\n", Rmat[3], Rmat[4], Rmat[5],  "\n", Rmat[6], Rmat[7], Rmat[8],  "\n");

  //camera "up" vector - rotate around same axis
  float nx = 0;
  float ny = 1; //default is up along y 
  float nz = 0;
  nx = Rmat[1];
  ny = Rmat[4];
  nz = Rmat[7];
  
  camera(x, y, z, ox, oy, oz, nx, ny, nz);
}


//makes a 3x3 rotation matrix that rotates by a given angle around an arbitrary vector
float[] CreateRotationMatrixAroundAxis(float aX, float aY, float aZ, float angle)
{
  float norm = sqrt(aX*aX + aY*aY + aZ*aZ);
  aX /= norm;
  aY /= norm;
  aZ /= norm; 

  float[] term2 = {
    aX * aX, aX * aY, aX * aZ, 
    aX * aY, aY * aY, aY * aZ, 
    aX * aZ, aY * aZ, aZ * aZ
  };

  float[] term3 = {
    0, aZ, -aY, 
    -aZ, 0, aX, 
    aY, -aX, 0
  };

  float[] Rmat = {
    cos(angle), 0,          0, 
    0,          cos(angle), 0, 
    0,          0,          cos(angle)
  };

  for (int i=0; i<9; i++)
  {
    Rmat[i] += (1 - cos(angle)) * term2[i] - sin(angle)*term3[i];
  }   
  
  return Rmat;
}

Particle findCentroid(ArrayList<Particle> ps)
{
  float meanx=0, meany=0, meanz=0;
  Particle meanParticle = new Particle();

  for (int i=0; i<ps.size (); i++)
  {
    Particle p = ps.get(i);
    meanx += p.x;
    meany += p.y;
    meanz += p.z;
  }
  meanParticle.x = meanx/ps.size();
  meanParticle.y = meany/ps.size();
  meanParticle.z = meanz/ps.size();

  return meanParticle;
}

//find extreme co-ordinates, i.e. approximate max size of the object
float findScale(ArrayList<Particle> ps)
{
  float inf = 1.0e38;
  float minx=inf, maxx=-inf, miny=inf, maxy=-inf;

  for (int i=0; i<ps.size (); i++)
  {
    Particle p = ps.get(i);
    if (p.x < minx)
      minx = p.x;
    if (p.y < miny)
      miny = p.y; 
    if (p.x > maxx)
      maxx = p.x;
    if (p.y > maxy)
      maxy = p.y;
  }

  float rangex = maxx-minx;
  float rangey = maxy-miny;
  if (rangex>rangey)
    return rangex;
  else
    return rangey;
}
