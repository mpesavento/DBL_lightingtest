import java.util.LinkedList;
import java.util.Timer;
import java.util.TimerTask;
import jssc.*;

class Controller 
extends Serial
{
  public final byte protoMin   = 0x21;
  public final byte protoMax   = 0x7e;
  public final byte protoReset = 0x7e;

  public final byte encodeBase = 0x30;
  public final byte encodeMask = 0x3f;

  public final byte commandBlock = 0x21;
  public final byte commandBlank = 0x22;
  public final byte commandQuery = 0x23;
  public final byte commandBlink = 0x24;

  public final byte ackReset = 0x7e;
  public final byte ackOkay  = 0x21;
  public final byte ackIdent = 0x22;
  public final byte ackError = 0x7d;

  final int maxBufLen = 64;

  final long ackTimeout = 2000; // milliseconds

  private int controllerID = -1;
  private color currColors[];
  private LinkedList<Command> commandQueue = new LinkedList();
  private Command runningCommand = null;
  private long commandStart = -1;
  private Timer ackTimer = null;
  private boolean resetting = false;
  private boolean connected = false;

  Controller(PApplet parent, String portName, int baudRate) 
  { 
    super(parent, portName, baudRate);
    currColors = null; 

    beginCommand(new CommandQuery());
  } 

  private void enqueueCommand(Command c)
  {
    println("Enqueueing " + c.getClass().getName() + " while running = " + ((runningCommand == null) ? "(null)" : runningCommand.getClass().getName()));
    if (isBroken()) {
     println("Connection broken, not enqueueing new commands!");
     return; 
    }
    synchronized(this) {
      if (runningCommand == null) {
        beginCommand(c); 
      } else {
        commandQueue.addLast(c); 
      }
    } 
  }

  public boolean isBroken() { return !connected && resetting; }
  public boolean isConnected() { return connected; }
  
  public int numberOfLEDs() {
    if (currColors == null) {
      return -1; 
    } else {
      return currColors.length;   
    }
  }
  
  public final color[] currentColors() { return currColors; }

  public void sendBlank() { enqueueCommand(new CommandBlank()); }
  
  public void sendNewColors(color upd[]) {
    if (upd.length != currColors.length) {
       throw new RuntimeException("New color length " + upd.length + " != " + currColors.length);
    }
    
    int chunkSize = (maxBufLen - 5) / 4;
    int chunkStart = 0;
    while (chunkStart < upd.length) {
      int chunkEnd = chunkStart + chunkSize - 1;
      if (chunkEnd >= upd.length) {
        chunkEnd = upd.length - 1; 
      }
      int len = 1 + chunkEnd - chunkStart;
      color chunkColor[] = new color[len];
      for (int i = 0; i < len; i++) {
        chunkColor[i] = upd[chunkStart + i];
      }
      enqueueCommand(new CommandBlock(chunkStart, chunkColor));
      chunkStart = chunkEnd + 1;
    }    
  }

  void write(byte buffer[]) {
    for (int i = 0; i < buffer.length; i++) {
      if (buffer[i] < 0x21 || buffer[i] > 0x7e) {
        println("BAD BYTE AT " + i + ": " + Integer.toHexString(buffer[i]));
      } 
    }
    super.write(buffer);

    print(buffer.length + " bytes:");
    /* Debug hex buffer contents
    for (int i = 0; i < buffer.length; i++) {
      print(Integer.toHexString(buffer[i]) + " ");
    } 
    */
    println();
    /* Debug literal buffer representation
    for (int i = 0; i < buffer.length; i++) {
      print(char(buffer[i]));
    }
    println();
    */
  }

  private void beginCommand(Command c)
  {
    if (isBroken()) {
      println("Connection broken, not starting new commands!"); 
      return;
    }

    println("Beginning command " + c.getClass().getName());
    synchronized(this) {
      runningCommand = c;
      commandStart = millis();
      byte buffer[] = runningCommand.encode();
      write(buffer);
      ackTimer = new Timer(true);
      ackTimer.schedule(new CommandTimeout(), ackTimeout);
    }
  }

  private void finishCommand()
  {
    synchronized (this) {
      print("Finished command " + runningCommand.getClass().getName());
      ackTimer.cancel();
      ackTimer = null;
      runningCommand = null;
      resetting = false;
      connected = true;
      long commandEnd = millis(), commandTime = commandEnd - commandStart;
      commandStart = -1;
      println("time: " + ((float) commandTime) / 1000.0);
      Command next = commandQueue.poll();
      if (next != null) {        
        beginCommand(next);
      }
    }
  }

  private void connectionReset()
  {
    synchronized (this) {
      if (isBroken()) {
        println("Trying to reset a lost connection");
      } else if (resetting) {
        connected = false;
        println("Resetting failed, connection lost");
      } else {
        ackTimer.cancel();
        ackTimer = null;
        commandQueue.addFirst(runningCommand);
        runningCommand = null;
        resetting = true;
        beginCommand(new CommandReset());
      }
    }
  }

  private class CommandTimeout
    extends TimerTask
  {
    public void run() {
      println("Command timeout with " + available() + " bytes in the queue");
      if (isBroken()) {
        println("Connection broken");
      } else {
        connectionReset();        
      }
    }
  }

  public void serialEvent(SerialPortEvent event)
  {
    super.serialEvent(event);
    
    if (isBroken()) {
     println("Connection broken, ignoring further input");
     return; 
    }
    
    // println("Serial event! available = " + available());
    while (available() > 0) {
      synchronized (this) {
        int b = read();
        // println("Received byte " + Integer.toHexString(b));
        if (b < protoMin || b > protoMax) {
          protoError("Bad byte: " + b);
        } else if (b == ackError) {
          protoReceiveError();
        } else if (runningCommand == null) {
          protoError("Received byte " + Integer.toHexString(b) + " with no running command");
        } else {
          try {
            if (runningCommand.ackByte(this, byte(b))) {
              finishCommand();
            }
          } 
          catch (BadAckException bae) {
            protoError(bae.message);
          }
        }
      }
    }
  }

  private void protoError(String message)
  {
    println("Protocol error in serial connection to controller, resetting connection:");
    println(message);
    connectionReset();
  }

  private void protoReceiveError()
  {
    println("Received protocol error complaint from controller, resetting connection");
    connectionReset();
  } 

  int serialDecode12(final byte buffer[], int pos)
    throws SerialDecodeException
  {
    byte d1 = byte(buffer[pos] - encodeBase), d2 = byte(buffer[pos + 1] - encodeBase);
    if ((d1 < 0) || (d1 > encodeMask) ||
      (d2 < 0) || (d2 > encodeMask)) { 
      throw new SerialDecodeException("Cannot decode " + d1 + " " + d2 + " into 12-bit value");
    } else {
      return (((int) d1) << 6) + (int) d2;
    }
  }

  void serialEncode12(byte buffer[], int pos, int val)
  {
    buffer[pos + 1] = byte(encodeBase + byte(val & encodeMask));
    buffer[pos] = byte(encodeBase + byte((val >> 6) & encodeMask));
  }

  void serialEncodeRGB(byte buffer[], int pos, color c)
  {
    int r = (c>>16 & 0xff);
    int g = (c>>8 & 0xff);
    int b = (c & 0xff);

    buffer[pos + 0] = byte(encodeBase + (r >> 2));
    buffer[pos + 1] = byte(encodeBase + ((r & 0x03) << 4) + (g >> 4));
    buffer[pos + 2] = byte(encodeBase + ((g & 0x0f) << 2) + (b >> 6));
    buffer[pos + 3] = byte(encodeBase + (b & 0x3f));

    /* Debug RGB encoding
    print(Integer.toHexString(c) + " => " + Integer.toHexString(r) + "," + Integer.toHexString(g) + "," + Integer.toHexString(b) + " => ");    
    for (int i = 0; i < 3; i++) { print(Integer.toHexString(buffer[pos + i]) + ","); }
    println(Integer.toHexString(buffer[pos+3]));
    */
  }

  class SerialDecodeException
    extends Exception
  {
    String message;
    SerialDecodeException(String m) { 
      message = m;
    }
  }

  class BadAckException
    extends Exception
  {
    String message;
    BadAckException(String m) { 
      message = m;
    }
    BadAckException(Command c, byte expected, byte actual) {
      this(c.getClass().getName() + ": Expecting " + Integer.toHexString(expected) + ", saw " + Integer.toHexString(actual) + ")");
    }
  }

  abstract class Command {
    abstract byte[] encode();
    abstract boolean ackByte(Controller c, byte b) throws BadAckException;
  }

  public class CommandOne
    extends Command
  {
    int ledNo;
    color col;

    CommandOne(int l, color c) { 
      ledNo = l; 
      col = c;
    }

    byte[] encode() {
      byte buffer[] = new byte[6];
      serialEncode12(buffer, 0, ledNo);
      serialEncodeRGB(buffer, 2, col);
      return buffer;
    }

    boolean ackByte(Controller c, byte b) 
      throws BadAckException
    {
      if (b == ackOkay) {
        c.currColors[ledNo] = col;
        return true;
      } else {
        throw new BadAckException(this, ackOkay, b);
      }
    }
  }

  public class CommandBlock 
    extends Command
  {
    int ledLo;
    color cols[]; 

    CommandBlock(int l, color c[]) { 
      ledLo = l; 
      cols = c;
    }

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

//    int encodedLength(int ncols) { return 5 + 4*ncols; }
//    int maxColorsForLength(int maxlen) { return (maxlen - 5)/4; }

    boolean ackByte(Controller c, byte b) 
      throws BadAckException
    {
      if (b == ackOkay) {
        for (int i = 0; i < cols.length; i++) {
          c.currColors[ledLo + i] = cols[i];
        } 
        return true;
      } else {
        throw new BadAckException(this, ackOkay, b);
      }
    }
  }

  class CommandBlank
    extends Command
  {
    CommandBlank() {
    }

    byte[] encode() { 
      byte buffer[] = new byte[1];
      buffer[0] = commandBlank;
      return buffer;
    }  

    void finish(Controller c) {
    }

    boolean ackByte(Controller c, byte b) 
      throws BadAckException
    {
      if (b == ackOkay) {
        for (int i = 0; i < c.currColors.length; i++) {
          c.currColors[i] = color(0, 0, 0);
        }
        return true;
      } else {
        throw new BadAckException(this, ackOkay, b);
      }
    }
  }

  class CommandQuery
    extends Command
  {
    byte response[] = new byte[5];
    int respNext = 0;
    CommandQuery() {
    }

    byte[] encode() {
      byte buffer[] = new byte[1];
      buffer[0] = commandQuery;
      return buffer;
    }

    boolean ackByte(Controller c, byte b) 
      throws BadAckException
    {
      if ((respNext == 0) && (b != ackIdent)) { 
        throw new BadAckException(this, ackIdent, b);
      }
      response[respNext] = b;
      respNext++;
      if (respNext >= 5) {
        try {
          int cid = serialDecode12(response, 1);
          int nled = serialDecode12(response, 3);

          if (c.controllerID == -1) {
            c.controllerID = cid;
          } else if (c.controllerID != cid) {
            throw new BadAckException(this.getClass().getName() + ": Controller ID changed from " + c.controllerID + " to " + cid);
          }

          if (c.currColors == null) {
            c.currColors = new color[nled];
          } else if (c.currColors.length != nled) {
            throw new BadAckException(this.getClass().getName() + ": Controller #LEDs changed from " + c.currColors.length + " to " + nled);
          }

          println("Controller ID = " + Integer.toHexString(cid));
          println("# LEDs = " + nled);

          return true;
        } 
        catch (SerialDecodeException sde) {
          throw new BadAckException(this.getClass().getName() + ": Error decoding ident response:\n  " + sde.message);
        }
      } else {
        return false;
      }
    }
  }

  class CommandReset
    extends Command
  {
    CommandReset() {
    }

    byte[] encode() {
      byte buffer[] = new byte[1];
      buffer[0] = protoReset;
      return buffer;
    }

    boolean ackByte(Controller c, byte b) 
      throws BadAckException
    {
      if (b == ackReset) {
       c.resetting = false;
       return true; 
      }
      return false;
    }
  }
}

