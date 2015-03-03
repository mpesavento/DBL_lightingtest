import processing.serial.*;

Controller port;

void setup() { 
  size(200, 200); 
  noStroke(); 
  frameRate(10); 
  // Open the port that the board is connected to and use the same speed (9600 bps)

  println(Serial.list());

  port = new Controller(this, "/dev/tty.usbmodem1421", 115200);
} 

final float period = 2000; // milliseconds

int lastMillis = 0;
int lastBytes = 0;
int lastQueueSize = 0;

void draw() {
  if (millis() > lastMillis + 1000) {
    float dur = ((float) (millis() - lastMillis)) / 1000.0;
    int newBytes = port.bytesSent();
    int newQueueSize = port.queueSize();

    int dBytes = newBytes - lastBytes;
    float byteRate = ((float) (newBytes - lastBytes)) / dur;
    int dQueue = newQueueSize - lastQueueSize;

    println("Sent " + dBytes + " in " + dur + " seconds = " + byteRate + "; queue grew by " + dQueue + " to " + newQueueSize);

    lastMillis = millis();
    lastBytes = newBytes;
    lastQueueSize = newQueueSize;
  }

  boolean mouseOver = mouseOverRect();

  colorMode(HSB, 1.0);
  color newColors[] = null;
  if (port.numberOfLEDs() > 0) {
    newColors = new color[port.numberOfLEDs()];
   
    float tphase = TWO_PI * (((float) millis()) / period);
    for (int i = 0; i < newColors.length; i++) {
      if (mouseOver) {
        newColors[i] = color(0.25 + 0.25 * sin(tphase + TWO_PI * (((float) i) / ((float) newColors.length))), 1.0, 1.0);
      } else {
        newColors[i] = color(0.5 + 0.25 * sin(tphase + 2.0 * TWO_PI * (((float) i) / ((float) newColors.length))), 1.0, 1.0);
      }
    }
  }
  
  port.sendNewColors(newColors);
  port.sendUpdate();
  
  colorMode(RGB, 255);

  background(255); 
  
  if (mouseOver) {
    fill(204);                     // change color
  } else {                         // If mouse is not over square,
    fill(0);                       // change color and
  } 

  rect(50, 50, 100, 100);          // Draw a square 
} 


boolean mouseOverRect() {        // Test if mouse is over square 
  return ((mouseX >= 50) && (mouseX <= 150) && (mouseY >= 50) && (mouseY <= 150)); 
} 


