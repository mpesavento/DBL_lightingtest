import processing.serial.*;

Controller port;

color blueYellow[] = null, redGreen[] = null;

void setup() { 
  size(200, 200); 
  noStroke(); 
  frameRate(10); 
  // Open the port that the board is connected to and use the same speed (9600 bps)

  println(Serial.list());

  port = new Controller(this, "/dev/tty.usbmodem1421", 115200);
  port.sendBlank();
  } 

void ensureArrays() {
   if (blueYellow == null || redGreen == null) {
     int nled = port.numberOfLEDs();     
     if (nled < 0) {
       println("No LED count from controller yet..."); 
     } else {
       colorMode(HSB, 1.0);
       blueYellow = new color[nled];
       redGreen = new color[nled];
       for (int i = 0; i < nled; i++) {
          blueYellow[i] = color(0.25 + 0.5 * ((float) i) / ((float) nled), 1.0, 1.0);
       }
       int halfway = nled / 2;
       for (int i = 0; i < halfway; i++) {
          redGreen[i] = color(0.5 * ((float) i) / ((float) halfway), 1.0, 1.0);
       }
       for (int i = 0; halfway + i < nled; i++) {
          redGreen[halfway + i] = color(0.5 - 0.5 * ((float) i) / ((float) halfway), 1.0, 1.0);  
       }
     }
   }
}

boolean mouseOver = false;

void draw() {
  colorMode(RGB, 255);

  background(255); 
  boolean newMouseOver = mouseOverRect();
  
  if (newMouseOver) {
    fill(204);                     // change color
    if (newMouseOver != mouseOver) {
      ensureArrays();
      if (blueYellow != null) {
        port.sendNewColors(blueYellow);
      }
    }
  } else {                         // If mouse is not over square,
    fill(0);                       // change color and
    if (newMouseOver != mouseOver) {
      ensureArrays();
      if (redGreen != null) {
        port.sendNewColors(redGreen);
      }
    }
  } 
  rect(50, 50, 100, 100);          // Draw a square 
  mouseOver = newMouseOver;
} 


boolean mouseOverRect() {        // Test if mouse is over square 
  return ((mouseX >= 50) && (mouseX <= 150) && (mouseY >= 50) && (mouseY <= 150)); 
} 


