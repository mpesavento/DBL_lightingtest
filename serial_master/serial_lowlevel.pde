final byte protoMin   = 0x21;
final byte protoMax   = 0x7d;
final byte protoReset = 0x7e;

final byte encodeBase = 0x30;
final byte encodeMask = 0x3f;

final byte commandBlock = 0x21;
final byte commandBlank = 0x22;
final byte commandQuery = 0x23;
final byte commandBlink = 0x24;

final byte ackReset = 0x7e;
final byte ackOne   = 0x21;
final byte ackMany  = 0x22;
final byte ackIdent = 0x23;
final byte ackError = 0x7d;

int serialDecode12(final   byte buffer[], int pos)
{
  byte d1 = byte(buffer[pos] - encodeBase), d2 = byte(buffer[pos + 1] - encodeBase);
  if ((d1 < 0) || (d1 > encodeMask) ||
      (d2 < 0) || (d2 > encodeMask)) { 

   return -1;
 } else {
   return (((int) d1) << 6) + (int) d2; 
 }
}

void serialEncode12(byte buffer[], int pos, int val)
{
  buffer[pos + 1] = byte(val & encodeMask);
  buffer[pos] = byte((val >> 6) & encodeMask); 
}

void serialEncodeRGB(byte buffer[], int pos, color c)
{
  byte r = byte(c>>16 & 0xff);
  byte g = byte(c>>8 & 0xff);
  byte b = byte(c & 0xff);
  
  buffer[pos + 0] = byte(encodeBase + (r >> 2));
  buffer[pos + 1] = byte(encodeBase + ((r & 0x03) << 4) + (g >> 4));
  buffer[pos + 2] = byte(encodeBase + ((g & 0x0f) << 2) + (b >> 6));
  buffer[pos + 3] = byte(encodeBase + (b & 0x3f));
}

class Controller {
 Serial port;
 color current[];
 
 Controller(Serial p) { port = p; current = null; }
}

interface Command {
 byte[] encode();
 void updateModel(color c[]); 
}

class CommandOne
  implements Command
{
 int ledNo;
 color col;

 CommandOne(int l, color c)  { ledNo = l; col = c; }

 byte[] encode() {
  byte buffer[] = new byte[6];
  serialEncode12(buffer, 0, ledNo);
  serialEncodeRGB(buffer, 2, col);
  return buffer;
 }
 
 void updateModel(color c[]) {
  c[ledNo] = col; 
 }
}

class CommandBlock 
  implements Command
{
 int ledLo;
 color cols[]; 

 CommandBlock(int l, color c[]) { ledLo = l; cols = c; }
 
 byte[] encode() {
  byte buffer[] = new byte[5 + 4*cols.length];
  buffer[0] = commandBlock;
  serialEncode12(buffer, 1, ledLo);
  serialEncode12(buffer, 3, (ledLo + cols.length - 1));
  for (int i = 0; i < cols.length; i++) {
   serialEncodeRGB(buffer, 5 + 4 * i, cols[i]); 
  }
  return buffer;
 }
 
 void updateModel(color c[]) {
  for (int i = 0; i < cols.length; i++) {
   c[ledLo + i] = cols[i];
  } 
 }
}

class CommandBlank
  implements Command
{
  CommandBlank() { }

  byte[] encode() { 
    byte buffer[] = new byte[1];
    buffer[0] = commandBlank;
    return buffer;
  }  
  
  void updateModel(color c[]) {
   for (int i = 0; i < c.length; i++) {
    c[i] = color(0,0,0);
   } 
  }
}
