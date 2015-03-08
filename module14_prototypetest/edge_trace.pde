
// stores strand / start / end indexes
int[][] edges = {
  {0,0,60},
  {0,60,105} 
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

    println(str(direction));
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
         if (partic == pulsePixel){
           p.b = 254;
         }
         if (partic == pulsePixel+1 || partic == pulsePixel-1){
           p.b = 175;
         }
         particles.set(partic,p);
      }
      
}



