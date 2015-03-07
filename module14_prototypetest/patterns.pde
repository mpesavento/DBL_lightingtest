import java.awt.image.BufferedImage;
import java.io.File;
import java.io.BufferedReader;
import java.io.FileReader;
import java.awt.image.DataBufferByte;
import java.io.FileNotFoundException;
import java.io.IOException;
import javax.imageio.ImageIO;
import java.awt.Color;
import java.util.Scanner;
import java.util.Map;
import java.lang.Math;
import java.util.List;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.HashMap; 
import java.util.Arrays;
import java.lang.Double;

//yay globals
//declare globally, crash locally

color[][] theimage;
color[][] theduplicat;
int [][] ledxyvals;
PImage culurz;
double[] imagedims;
double frame=0.0;
int widf;
int hite;
PImage tempurry;
      
      
void loopHSV(ArrayList<Particle> particles) {      
  colorMode(HSB, 360, 100, 100); //switch color mode to HSB, in degrees and percent
  //int offset = int(map(millis()%10000, 0, 10000, 0, 360)); 
  int offset = int(((millis() / 10000.0) % 1.0) * 360.0);
  int h = 0;
  for (int i=0; i<particles.size(); i++) {
    Particle p = particles.get(i);
    //h = int(map(i, 0, particles.size(), 0, 360) + offset) % 360;
    h = (int(float(i) / float(particles.size()) * 360.0) + offset) % 360;
    color c = color(h, 100, 100);
    //color c = Color.HSBtoRGB(h,100,70);
    
    p.r = int(red(c));
    p.g = int(green(c));
    p.b = int(blue(c));
  }

  colorMode(RGB, 255);//switch back to RGB
}

static double distanceBetweenPoints(double[] point1, double[] point2){
  return Math.sqrt(Math.pow((point1[0]-point2[0]),2)+Math.pow((point1[1]-point2[1]),2)+Math.pow((point1[2]-point2[2]),2));
}

void radial3dspheres(ArrayList<Particle> particles, double speed){
  frame=frame+speed %1.0;
  double centroidx=minmaxxyz[0][0]+(minmaxxyz[0][1]-minmaxxyz[0][0])/2.0;
  double centroidy=minmaxxyz[1][0]+(minmaxxyz[1][1]-minmaxxyz[1][0])/2.0;
  double centroidz=minmaxxyz[2][0]+(minmaxxyz[2][1]-minmaxxyz[2][0])/2.0;
  double[] centroid = new double[] {centroidx,centroidy,centroidz};  //DECLARE THIS GLOBALLY BRO (or just use the center node...)
  double maxdistance=Math.sqrt(Math.pow((minmaxxyz[0][0]-minmaxxyz[0][1]),2)+Math.pow((minmaxxyz[1][0]-minmaxxyz[1][1]),2)+Math.pow((minmaxxyz[2][0]-minmaxxyz[2][1]),2))/2.0;
  color[] ledcolors = new color[particles.size()];
  for (int row = 0; row < particles.size(); row++) {
         Particle pradial=particles.get(row);
         double x=pradial.x;
         double y=pradial.y;
         double z=pradial.z;
         double[] ledxyz = new double[] {x,y,z};
         double radialRatio=distanceBetweenPoints(ledxyz,centroid)/maxdistance;
         double level = Math.sin(2.0*Math.PI*(radialRatio+(1-frame))) * 127 + 128;
         int dat_culla=(int)level;
         pradial.r = (dat_culla >> 16) & 0xFF;
         pradial.g = (dat_culla >> 8) & 0xFF;
         pradial.b = dat_culla & 0xFF;
         particles.set(row,pradial);
  }
}
  
  
void slideTheImage(ArrayList<Particle> particles){

      theduplicat = new color[hite][widf];
      theduplicat=theimage; 

      for (int imgy = 0; imgy < hite; imgy++) {
        theimage[imgy][widf-1]=theduplicat[imgy][0];
      }
        
  
      for (int imgx = 0; imgx < widf-1; imgx++ ) {
        for (int imgyy = 0; imgyy < hite; imgyy++) {
          theimage[imgyy][imgx]=theduplicat[imgyy][imgx+1];
        }
      }
      
      for (int partic = 0; partic < particles.size(); partic++) {
         int[] newxyvalues = ledxyvals[partic];
         int ze_color=theimage[newxyvalues[1]][newxyvalues[0]];
         Particle p = particles.get(partic);
         p.r = (ze_color >> 16) & 0xFF;
         p.g = (ze_color >> 8) & 0xFF;
         p.b = ze_color & 0xFF;
         particles.set(partic,p);
      }
      
}



static int[] scaleLocationInImageToLocationInModule(double[] imagedims, double[] ledxy, double[][] minmaxxyz) {
      
      println("START");
      println(ledxy[0]);
      println(minmaxxyz[0][0]);
      println(minmaxxyz[0][1]);
  
      double newx=(ledxy[0]-minmaxxyz[0][0])/(minmaxxyz[0][1]-minmaxxyz[0][0])*imagedims[0];
      double newy=(ledxy[1]-minmaxxyz[1][0])/(minmaxxyz[1][1]-minmaxxyz[1][0])*imagedims[1];
      println(newx);
      int newxint=(int)newx;
      int newyint=(int)newy;
      if (newxint>=imagedims[0]){
         newxint=(int)imagedims[0]-1;
      }
      if (newxint<=0){
         newxint=0;
      }
      if (newyint>=imagedims[1]){
         newyint=(int)imagedims[1]-1;
      }
      if (newyint<=0){
         newyint=0;
      }

      int[] result = new int[] {newxint,newyint};
      return result;
      
   }



static int[] scaleLocationIn3dspaceToLocationInModule(double[] imagedims, double[] ledxyz, double[][] minmaxxyz) {
      
      double newx=(ledxyz[0]-minmaxxyz[0][0])/(minmaxxyz[0][1]-minmaxxyz[0][0])*imagedims[0];
      double newy=(ledxyz[1]-minmaxxyz[1][0])/(minmaxxyz[1][1]-minmaxxyz[1][0])*imagedims[1];
      double newz=(ledxyz[2]-minmaxxyz[2][0])/(minmaxxyz[2][1]-minmaxxyz[2][0])*imagedims[2];
      int newxint=(int)newx;
      int newyint=(int)newy;
      int newzint=(int)newz;
      if (newxint>=imagedims[0]){
         newxint=newxint-1;
      }
      if (newxint<=0){
         newxint=newxint+1;
      }
      if (newyint>=imagedims[1]){
         newyint=newyint-1;
      }
      if (newyint<=0){
         newyint=newyint+1;
      }
      if (newzint>=imagedims[2]){
         newzint=newzint-1;
      }
      if (newzint<=0){
         newzint=newzint+1;
      }

      int[] result = new int[] {newxint,newyint, newzint};
      return result;     
   }

void initPatterns(ArrayList<Particle> particles, String filename) {
    //image stuff
    culurz = loadImage(filename);
    loadPixels();  
    culurz.loadPixels();
    widf=(int)culurz.width;
    hite=(int)culurz.height;
    double[] imagedims = new double[] {widf,hite};
    theimage = new color[hite][widf];

    for (int imgy = 1; imgy < hite; imgy++ ) {
      color[] noorow = new color[widf];
      for (int imgx = 0; imgx < widf; imgx++) {
        noorow[imgx]=culurz.pixels[imgy*widf+imgx];
      }
      theimage[imgy]=noorow;
    }


    //setting up xy coordination for image scrolling
    ledxyvals= new int[particles.size()][2];
    for (int pa=0; pa<particles.size(); pa++){
        Particle p=particles.get(pa);
        double[] ledxy=new double[] {p.x,p.y};
        ledxyvals[pa] = scaleLocationInImageToLocationInModule(imagedims, ledxy, minmaxxyz);
    }
   
}

