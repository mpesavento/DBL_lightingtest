import java.awt.image.BufferedImage;
import java.io.BufferedReader;
import java.io.FileReader;
import java.awt.image.DataBufferByte;
import java.io.FileNotFoundException;
import java.io.IOException;
import javax.imageio.ImageIO;
import java.awt.Color;
import java.util.Scanner;
import java.util.Map;
import java.util.List;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.HashMap; 
import java.util.Arrays;
import java.lang.Double;

public class DoImageThings {

   public static void main(String[] args) throws IOException {

      BufferedImage culurz = ImageIO.read(DoImageThings.class.getResource("TestColors.jpg"));
      double[] imagedims = new double[] {culurz.getWidth(), culurz.getHeight()};

      // System.out.println("Testing convertTo2DUsingGetRGB:");
      // for (int i = 0; i < 10; i++) {
      //    long startTime = System.nanoTime();
      //    int[][] result = convertTo2DUsingGetRGB(culurz);
      //    long endTime = System.nanoTime();
      //    System.out.println(String.format("%-2d: %s", (i + 1), toString(endTime - startTime)));
      // }

      // System.out.println("");

      System.out.println("Testing convertTo2DWithoutUsingGetRGB:");
         int[][] result = convertTo2DWithoutUsingGetRGB(culurz);

      Color c = new Color(result[5][100]);
      Color cc = new Color(result[5][400]);

      double min_x = -90.4252;
      double max_x = 0.0;
      double min_y = -47.0471;
      double max_y = 23.3568;
      double min_z = -0.9436;
      double max_z = 23.86303;
      double[][] minmaxxy = new double[][] {{min_x,max_x},{min_y,max_y},{min_z,max_z}};
      List pixelrgbvalues = new ArrayList();
      ArrayList<ArrayList<Double>> leds = new ArrayList<ArrayList<Double>>();
      leds = getPixelValuesFromCSVFile("led_positions.csv");

      for (int row = 0; row < leds.size(); row++) {
         List rowww=new ArrayList<Double>();
         rowww=leds.get(row);
         Double ledIndex = (Double)rowww.get(0);
         Double x=(Double)rowww.get(1);
         Double y=(Double)rowww.get(2);
         Double z=(Double)rowww.get(3);
         double[] ledxy = new double[] {x,y};
         int[] newxyvalues = scaleLocationInImageToLocationInModule(imagedims, ledxy, minmaxxy);
         int rrggbb = result[newxyvalues[0]][newxyvalues[1]];
         int r = (rrggbb >> 16) & 0xFF;
         int g = (rrggbb >> 8) & 0xFF;
         int b = rrggbb & 0xFF;
         int xx=x.intValue();
         int yy=y.intValue();
         int zz=z.intValue();
         pixelrgbvalues.add(ledIndex.intValue());
         pixelrgbvalues.add(xx);
         pixelrgbvalues.add(yy);
         pixelrgbvalues.add(zz);
         pixelrgbvalues.add(r);
         pixelrgbvalues.add(g);
         pixelrgbvalues.add(b);
      }

      System.out.println(c);
      System.out.println(result[8][100]);
      System.out.println(result[100][100]);
      System.out.println(cc);
      System.out.println(result[100][100]);
   }

   private static int[] scaleLocationInImageToLocationInModule(double[] imagedims, double[] ledxy, double[][] minmaxxy) {
      
    //  System.out.println(Arrays.toString(imagedims));
      System.out.println(Arrays.toString(ledxy));
      System.out.println(Arrays.deepToString(minmaxxy));
      double newx=(ledxy[0]-minmaxxy[0][0])/(minmaxxy[0][1]-minmaxxy[0][0])*imagedims[0];
      double newy=(ledxy[1]-minmaxxy[1][0])/(minmaxxy[1][1]-minmaxxy[1][0])*imagedims[1];
      int newxint=(int)newx;
      int newyint=(int)newy;
      if (newxint>=imagedims[0]){
         newxint=newxint-1;
      }
      if (newxint<=0){
         System.out.println("yay");
         newxint=newxint+1;
      }
      if (newyint>=imagedims[1]){
         newyint=newyint-1;
      }
      if (newyint<=0){
         newyint=newyint+1;
      }

      int[] result = new int[] {newxint,newyint};
      System.out.println(Arrays.toString(result));
      return result;
   }

   public static ArrayList<ArrayList<Double>> getPixelValuesFromCSVFile(String filepath){
      try{
         BufferedReader reader = new BufferedReader(new FileReader(filepath));
      
         String line = null;
         Scanner scanner = null;
         int index = 0;
         int counta=0;
         Double led_id=0.0;
         Double x=0.0;
         Double y=0.0;
         Double z=0.0;
         ArrayList<ArrayList<Double>> ledPositions = new ArrayList<ArrayList<Double>>();
         try{
            while ((line = reader.readLine()) != null) {
                  scanner = new Scanner(line);
                  scanner.useDelimiter(",");

                  while (scanner.hasNext()) {
                      String data = scanner.next();
                      if (index == 0)
                          led_id=Double.parseDouble(data);
                      else if (index == 1)
                          x = Double.parseDouble(data);
                      else if (index == 2)
                          y = Double.parseDouble(data);
                      else if (index == 3)
                          z = Double.parseDouble(data);
                      else
                          System.out.println("invalid data::" + data);
                      index++;
                  }
                  ArrayList<Double> row = new ArrayList<Double>();
                  row.add(led_id);
                  row.add(x);
                  row.add(y);
                  row.add(z);
                  ledPositions.add(row);
                  counta++;
      //            Double[] coords = new Double[] {x,y,z};
        //          List<Double> coordsdammit = Arrays.asList(coords);
          //        ledPositions.put(led_id,coordsdammit);
                  index = 0;
              }
               
              //close reader
              reader.close();
           }
           catch(IOException ioe){
            System.out.println(ioe.getMessage());
            return null;
           }

           return ledPositions;         } 
      catch(FileNotFoundException fnfe) { 
            System.out.println(fnfe.getMessage());
            return null;
        } 
   }

   private static int[][] convertTo2DUsingGetRGB(BufferedImage image) {
      int width = image.getWidth();
      int height = image.getHeight();
      int[][] result = new int[height][width];

      for (int row = 0; row < height; row++) {
         for (int col = 0; col < width; col++) {
            result[row][col] = image.getRGB(row, col);
         }
      }
      return result;
   }

   private static int[][] convertTo2DWithoutUsingGetRGB(BufferedImage image) {

      final byte[] pixels = ((DataBufferByte) image.getRaster().getDataBuffer()).getData();
      final int width = image.getWidth();
      final int height = image.getHeight();
      final boolean hasAlphaChannel = image.getAlphaRaster() != null;

      int[][] result = new int[height][width];
      if (hasAlphaChannel) {
         final int pixelLength = 4;
         for (int pixel = 0, row = 0, col = 0; pixel < pixels.length; pixel += pixelLength) {
            int argb = 0;
            argb += (((int) pixels[pixel] & 0xff) << 24); // alpha
            argb += ((int) pixels[pixel + 1] & 0xff); // blue
            argb += (((int) pixels[pixel + 2] & 0xff) << 8); // green
            argb += (((int) pixels[pixel + 3] & 0xff) << 16); // red
            result[row][col] = argb;
            col++;
            if (col == width) {
               col = 0;
               row++;
            }
         }
      } else {
         final int pixelLength = 3;
         for (int pixel = 0, row = 0, col = 0; pixel < pixels.length; pixel += pixelLength) {
            int argb = 0;
            argb += -16777216; // 255 alpha
            argb += ((int) pixels[pixel] & 0xff); // blue
            argb += (((int) pixels[pixel + 1] & 0xff) << 8); // green
            argb += (((int) pixels[pixel + 2] & 0xff) << 16); // red
            result[row][col] = argb;
            col++;
            if (col == width) {
               col = 0;
               row++;
            }
         }
      }

      return result;
   }

}