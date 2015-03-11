
// stores strand / start / end indexes
int[][] edges = {
  {0,0,60},
  {0,60,105},
  {0,108,153},
  {0,153,200},
  {0,201,269},
  {0,270,329},
  {1,330,391},
  {1,392,436},
  {1,437,561},
  {1,562,612},
  {2,613,696},
  {2,697,778},
  {2,779,825},
  {2,826,878},
  {3,879,953},
  {3,954,1010},
  {3,1011,1062},
  {3,1063,1110},
  {3,1111,1160},
  {4,1161,1240},
  {4,1241,1300},
  {4,1301,1352},
  {4,1353,1410},
  {4,1411,1477}
};


float pulsePos = 0.0;

int pulsing = 0;

int start=0;
int end=0;
int chaseStrand=0;
int edge=0;
int direction=0;

void think(ArrayList<Particle> particles){

  // time to pick another random edge and start a pulse  
  if(pulsing==0){
    pulsing = 1;
    edge = int(random(edges.length));
//edge = 1;
    chaseStrand = edges[edge][0];
    start = edges[edge][1];
    end = edges[edge][2];
    direction = int(random(2));
    if(direction==1){
      pulsePos = start*1.0;
    }else{
      pulsePos = end*1.0;
    }

    //println(str(direction));
  }

  if(direction==1){
    pulsePos+=2;
    if(pulsePos>end){
      pulsing = 0;
    }
  }else{
    pulsePos-=2;
    if(pulsePos<start){
      pulsing = 0;
    } 
  }
  
  int pulsePixel = int(pulsePos);

      for (int partic = 0; partic < particles.size(); partic++) {
         int[] newxyvalues = ledxyvals[partic];
         int ze_color=100;
         Particle p = particles.get(partic);
           //p.b = 10;
           //p.r = 10;
           //p.g = 0;
         if (partic == pulsePixel){
           p.b = 254;
           p.r = 254;
           p.g = 254;
         }
         if (partic == pulsePixel+1 || partic == pulsePixel-1){
           p.b = 254;
           p.r = 254;
           p.g = 254;
         }
         particles.set(partic,p);
      }
      
}



