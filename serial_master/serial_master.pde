import processing.serial.*;

Serial port;


void setup() { 
  size(200, 200); 
  noStroke(); 
  frameRate(10); 
  // Open the port that the board is connected to and use the same speed (9600 bps)

  println(Serial.list());

  port = new Serial(this, "/dev/tty.usbmodem1421", 9600); 

  port.write(0xff);
  
  while (port.available() < 2) { /* Busy wait!? */ }

  int msb = port.read();
  int lsb = port.read();

  println(msb);
  println(lsb);  
} 
 
void draw() { 
  background(255); 
  if (mouseOverRect() == true)  {  // If mouse is over square,
    fill(204);                     // change color and  
    port.write(0xFF);               // send an H to indicate mouse is over square 
  } else {                         // If mouse is not over square,
    fill(0);                       // change color and
    port.write(0xFF);               // send an L otherwise
  } 
  rect(50, 50, 100, 100);          // Draw a square 
} 


boolean mouseOverRect() {        // Test if mouse is over square 
  return ((mouseX >= 50) && (mouseX <= 150) && (mouseY >= 50) && (mouseY <= 150)); 
} 


