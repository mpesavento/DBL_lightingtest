import hypermedia.net.*;

UDP udp;

int temp;
byte[] packet = new byte[536];
//AudioFile myInput; 
//AudioStream myStream; 
//FFT myFFT; 
float volume; 
float avgVol; 

int NUM_LED = 300;

public class Sin3 {
  int wave1=0;
  int wave2=0;
  int wave3=0;

  int inc1 = 2;
  int inc2 = 1;
  int inc3 = -3;

  int lvl1 = 80;
  int lvl2 = 80;
  int lvl3 = 80;

  int mul1 = 20;
  int mul2 = 25;
  int mul3 = 22;
  
  public Sin3() {}
  
  public setwave(leds) {
    wave1 += inc1;
    wave2 += inc2;
    wave3 += inc3;
    for (int k=0; k<NUM_LEDS; k++) {
      leds[k].r = qsub8(sin8(mul1*k + wave1), lvl1);         // Another fixed frequency, variable phase sine wave with lowered level
      leds[k].g = qsub8(sin8(mul2*k + wave2), lvl2);         // A fixed frequency, variable phase sine wave with lowered level
      leds[k].b = qsub8(sin8(mul3*k + wave3), lvl3);         // A fixed frequency, variable phase sine wave with lowered level
    }  
  }
  
};





void setup() {

  udp = new UDP(this, 6038);
  udp.listen( true );

  packet[00] = 0x04;
  packet[01] = 0x01;
  packet[02] = byte(0xdc);
  packet[03] = byte(0x4a);
  packet[04] = 0x01;
 // packet[05] = 0x00; //???? was not in orig code

  packet[06] = 0x01;
  packet[07] = 0x01;

  packet[16] = byte(0xff);  
  packet[17] = byte(0xff);
  packet[18] = byte(0xff);
  packet[19] = byte(0xff);  // port # string is connected to on the power supply.
  // packet[21] = 0x02;
  //packet[22] = byte(0x01); // number of ports
  //packet[23] = byte(0xff);
}

void draw() {
  // set string port here:
  // packet[16] = 0x01
  
    for (int i = 0; i < NUM_LED; i++) {

      packet[21+(i*3)+1] = byte(64);
//        packet[21+(i*3)+1] = byte(255-i);
//        packet[21+(i*3)+2] = byte(255-i*2);
    }

    delay(30); //some power supplies freak out if this is less than 30ms or so
    udp.send(packet, "10.4.2.5");

}




