import java.util.Collections;
import java.util.List;
import java.util.LinkedList;
import java.util.Timer;
import java.util.TimerTask;
import jssc.*;

/**
 * Serial port connection to an Arduino LED controller. The LED
 * controller stores a table of LED colors on-board and propagates
 * these colors to the physical LEDs on demand.
 */
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
  public final byte commandUpdate = 0x25;
  public final byte commandAutoUpdate = 0x26;
  public final byte commandNoAutoUpdate = 0x27;

  public final byte ackReset = 0x7e;
  public final byte ackIdent = 0x21;
  public final byte ackStored = 0x22;
  public final byte ackUpdated = 0x23;
  public final byte ackError = 0x7d;

    /**
     * Maximum message size in bytes. This maximum message size should
     * not exceed the Arduino controller serial buffer size, which is
     * 64 bytes by default. Block updates are split across chunks to
     * accomodate this limitation.
     */
    final int maxBufLen = 64;

    /**
     * Duration of acknowledgement timer, in milliseconds. The "blink"
     * message delays slightly more than 1 second before
     * acknowledgement, so this value must be greater than 1
     * second. The acknowledgement timeout should not be triggered
     * under normal protocol operation.
     */
  final long ackTimeout = 2000;

    /**
     * Representation of the stored and displayed LED colors on the
     * controller. This representation is immutable and directly
     * exposes data fields.
     */
  public class ControllerState
  {
      /**
       * LED colors expected on physical LEDs.
       */
    public final color displayedColors[];
      /**
       * LED colors expected in controller memory.
       */
    public final color storedColors[];
      /**
       * Setting for auto-update of physical LEDs after receiving
       * messages.
       */
    public final boolean autoUpdate;

      /**
       * 
       */
    ControllerState(color dc[], color sc[], boolean au) { 
      displayedColors = dc; 
      storedColors = sc; 
      autoUpdate = au;
    }
  }

    private int controllerID = -1;
    private int numberOfLEDs = -1;
    private ControllerState currentState;
    private ControllerState finalState;
    private LinkedList<Command> commandQueue = new LinkedList();
    private Command runningCommand = null;
    private long commandStart = -1;
    private Timer ackTimer = null;
    private boolean resetting = false;
    private boolean connected = false;
    private int bytesSent = 0;
    private int bytesReceived = 0;
    private int messagesSent = 0;
    
    /**
     * New Controller connected to a serial port. The Controller
     * begins in a pre-connected state and sends a query to the
     * controller to establish a connection. Acknowledgement of this
     * query establishes a connection, and this query is subject to
     * the same timeouts and resetting strategy as all messages to the
     * Arduino controller.
     * @param parent    Enclosing Processing Applet.
     * @param portName  Serial port name for connection to controller
     * @param baudRate  Serial port connection speed with controller
     */
    Controller(PApplet parent, String portName, int baudRate) 
    { 
	super(parent, portName, baudRate);
	currentState = null;
	finalState = null;
	
	beginCommand(new CommandQuery());
    } 
    
    /**
     * Establish a connection based on the controller responses to a
     * master query. 
     */
    private void completeConnection(int cid, int nled)
    {
	controllerID = cid;
	numberOfLEDs = nled;
	color colors[] = new color[nled];
	currentState = new ControllerState(colors, colors, false);
	finalState = currentState;
	connected = true;
    }
    
    private void enqueueCommand(Command c)
    {
	/* Debug enqueueing
	   println("Enqueueing " + c.getClass().getName() + " while running = " + ((runningCommand == null) ? "(null)" : runningCommand.getClass().getName()));
	*/
	if (!isConnected()) {
	    println(isBroken() ? "Connection broken, not enqueueing commands!" : "Not connected, not enqueueing commands!");
	}
	synchronized(this) {
	    finalState = c.stateTransform(finalState); 
	    
	    if (runningCommand == null) {
		beginCommand(c);
	    } else {
		commandQueue.addLast(c);
	    }
	}
    }

    /**
     * Is the connection broken? The connection is broken when a
     * protocol error or acknowledgement timeout arises and the
     * subsequent master-to-controller reset message also fails
     * (including through a failed acknowledgement timeout).
     */
    public boolean isBroken() { return !connected && resetting; }
    
    /**
     * Is there an established connection to the controller? A
     * connection is established when a response to an initial query
     * is received, and lasts until an unresettable protocol error
     * arises {@link isBroken}.
     */
    public boolean isConnected() { return connected; }

    /**
     * LED count from controller. Prior to establishment of a
     * connection to the controller, returns -1.
     */
    public int numberOfLEDs() { return numberOfLEDs; }
    
    /**
     * The state of the controller after all acknowledged messages.
     */
    public ControllerState currentState() { return currentState; }  

    /**
     * The future state of the controller after successful handling
     * all enqueued messages.
     */
    public ControllerState finalState() { return finalState; }

    /**
     * The total number of bytes sent to the controller.
     */
    public int bytesSent() { return bytesSent; }

    /**
     * The total number of bytes received from the controller.
     */
    public int bytesReceived() { return bytesReceived; }

    /**
     * The total number of messages sent to the controller.
     */
    public int messagesSent() { return messagesSent; }
    
    /**
     * Length of the pending command queue.
     */
    public int queueSize() { return commandQueue.size(); }

    /**
     * Blank the controller, i.e., set all stored LED colors to black
     * / off.  <p> Blanking will propagate to physical LEDs only after
     * an update; if auto-update mode is set, this will happen
     * immediately.
     */
    public void sendBlank() { 
	enqueueCommand(new CommandBlank());
    }

    /**
     * Send new values for all stored colors on the controller. <p>LED
     * color updates will propagate to physical LEDs only after an
     * update; if auto-update mode is set, this will happen
     * immediately.
     * @param upd  New colors in an array whose length must match {@link numberOfLEDs}.
     */
    public void sendNewColors(color upd[]) {
	if (upd.length != numberOfLEDs()) {
	    throw new RuntimeException("New color length " + upd.length + " != " + numberOfLEDs());
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
  
    /**
     * Update physical LED colors to match stored LED colors.
     */
    public void sendUpdate() { enqueueCommand(new CommandUpdate()); }
    
    void write(byte buffer[]) {
	for (int i = 0; i < buffer.length; i++) {
	    if (buffer[i] < 0x21 || buffer[i] > 0x7e) {
		println("BAD BYTE AT " + i + ": " + Integer.toHexString(buffer[i]));
	    }
	}
	super.write(buffer);

	/* Debug hex buffer contents
	   print(buffer.length + " bytes:");
	   for (int i = 0; i < buffer.length; i++) {
	   print(Integer.toHexString(buffer[i]) + " ");
	   } 
	   println();
	*/
	/* Debug literal buffer representation
	   for (int i = 0; i < buffer.length; i++) {
	   print(char(buffer[i]));
	   }
	   println();
	*/
    }

    private void beginCommand(Command c)
    {
	/* Debug commands
	   println("Beginning command " + c.getClass().getName());
	*/
	synchronized(this) {
	    runningCommand = c;
	    commandStart = millis();
	    byte buffer[] = runningCommand.encode();
	    write(buffer);
	    bytesSent += buffer.length;
	    messagesSent++;
	    ackTimer = new Timer(true);
	    ackTimer.schedule(new CommandTimeout(), ackTimeout);
	}
    }
    
    private void finishCommand()
    {
	synchronized (this) {
	    long commandEnd = millis(), commandTime = commandEnd - commandStart;
	    commandStart = -1;
	    /* Debug command finishing
	       println("Finished command " + runningCommand.getClass().getName() + ", time: " + ((float) commandTime) / 1000.0);
	    */
	    ackTimer.cancel();
	    ackTimer = null;
	    runningCommand = null;
	    resetting = false;
	    connected = true;
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
	while (available () > 0) {
	    synchronized (this) {
		int b = read();
		bytesReceived++;
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

    /**
     * Decode a 12-bit value from protocol bytes.
     * @param buffer  Contains protocol message
     * @param pos     Position of the first byte of the encoded 12-bit value in the buffer
     * @return  Decoded value, which will fall between 0 and 4095.
     * @exception SerialDecodeException Bad encoding of 6-bit values comprising the 12-bit number.
     */
    private int serialDecode12(final byte buffer[], int pos)
	throws SerialDecodeException
    {
	byte d1 = byte(buffer[pos] - encodeBase), d2 = byte(buffer[pos + 1] - encodeBase);
	if ((d1 < 0) || (d1 > encodeMask) ||
	    (d2 < 0) || (d2 > encodeMask)) { 
	    throw new SerialDecodeException("Cannot decode " + Integer.toHexString(buffer[pos]) + " " + Integer.toHexString(buffer[pos+1]) + " into 12-bit value");
	} else {
	    return (((int) d1) << 6) + (int) d2;
	}
    }
    
    /**
     * Encode a 12-bit value into 2 protocol bytes.
     * @param buffer  Protocol message buffer to receive encoded value
     * @param pos     Position of the first byte of the encoded value within the buffer
     * @param val     Value to encode, which should fall within 0 and 4095 inclusive.
     */
    void serialEncode12(byte buffer[], int pos, int val)
    {
	buffer[pos + 1] = byte(encodeBase + byte(val & encodeMask));
	buffer[pos] = byte(encodeBase + byte((val >> 6) & encodeMask));
    }

    /**
     * Encode a color into 4 protocol bytes.
     * @param buffer Protocol mesasge buffer to receive encoded value
     * @param pos    Position of the first byte of the encoded value within the buffer
     * @param val    Value to encode, which should fall within 0 and 4095 inclusive.
     */
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
    abstract ControllerState stateTransform(ControllerState cs);
  }

  public class CommandOne
    extends Command
  {
    final int ledNo;
    final color col;
    final byte encoding[];

    CommandOne(int l, color c) { 
      ledNo = l; 
      col = c;
      encoding = new byte[6];
      serialEncode12(encoding, 0, ledNo);
      serialEncodeRGB(encoding, 2, col);
    }

    byte[] encode() { return encoding; }

    ControllerState stateTransform(ControllerState cs0)
    {
      color storedNew[] = new color[cs0.storedColors.length];
      System.arraycopy(cs0.storedColors, 0, storedNew, 0, cs0.storedColors.length);
      storedNew[ledNo] = col;
      color displayNew[] = (cs0.autoUpdate ? storedNew : cs0.displayedColors);
      return new ControllerState(storedNew, displayNew, cs0.autoUpdate);
    }

    boolean ackByte(Controller c, byte b) 
      throws BadAckException
    {
      byte expectedAck = (currentState.autoUpdate ? ackUpdated : ackStored);
      if (b == expectedAck) {
        currentState = stateTransform(currentState);
        return true;
      } else {
        throw new BadAckException(this, expectedAck, b);
      }
    }
  }

  public class CommandBlock 
    extends Command
  {
    final int ledLo;
    final color cols[];
    final byte encoding[];

    CommandBlock(int l, color c[]) { 
      ledLo = l; 
      cols = c;
      encoding = new byte[5 + 4*cols.length];
      encoding[0] = commandBlock;
      serialEncode12(encoding, 1, ledLo);
      serialEncode12(encoding, 3, (ledLo + cols.length - 1));
      for (int i = 0; i < cols.length; i++) {
        serialEncodeRGB(encoding, 5 + 4 * i, cols[i]);
      }
    }

    byte[] encode() { return encoding; }

    //    int encodedLength(int ncols) { return 5 + 4*ncols; }
    //    int maxColorsForLength(int maxlen) { return (maxlen - 5)/4; }

    ControllerState stateTransform(ControllerState cs0)
    {
      color storedNew[] = new color[cs0.storedColors.length];
      System.arraycopy(cs0.storedColors, 0, storedNew, 0, cs0.storedColors.length);
      for (int i = 0; i < cols.length; i++) {
        storedNew[ledLo + i] = cols[i];
      } 
      color displayNew[] = (cs0.autoUpdate ? storedNew : cs0.displayedColors);
      return new ControllerState(storedNew, displayNew, cs0.autoUpdate);
    }

    boolean ackByte(Controller c, byte b) 
      throws BadAckException
    {
      byte expectedAck = (currentState.autoUpdate ? ackUpdated : ackStored);
      if (b == expectedAck) {
        currentState = stateTransform(currentState);
        return true;
      } else {
        throw new BadAckException(this, expectedAck, b);
      }
    }
  }

  class CommandBlank
    extends Command
  {
    final byte encoding[] = { commandBlank };
    CommandBlank() { }

    byte[] encode() { return encoding; }

    ControllerState stateTransform(ControllerState cs0)
    {
      color storedNew[] = new color[cs0.storedColors.length];
      color displayNew[] = (cs0.autoUpdate ? storedNew : cs0.displayedColors);
      return new ControllerState(storedNew, displayNew, cs0.autoUpdate);
    }    

    boolean ackByte(Controller c, byte b) 
      throws BadAckException
    {
      byte expectedAck = (currentState.autoUpdate ? ackUpdated : ackStored);
      if (b == expectedAck) {
        currentState = stateTransform(currentState);
        return true;
      } else {
        throw new BadAckException(this, expectedAck, b);
      }
    }
  }

  class CommandQuery
    extends Command
  {
    byte response[] = new byte[5];
    int respNext = 0;
    final byte encoding[] = { commandQuery };
    CommandQuery() { }

    byte[] encode() { return encoding; }

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

          if (isConnected()) {
            if (c.controllerID != cid) {
              throw new BadAckException(this.getClass().getName() + ": Controller ID changed from " + c.controllerID + " to " + cid);
            }
            if (nled != c.currentState.storedColors.length) {
              throw new BadAckException(this.getClass().getName() + ": Controller #LEDs changed from " + c.currentState.storedColors.length + " to " + nled);
            }
          } else {
            completeConnection(cid, nled); 
          }

          println("Controller ID = " + Integer.toHexString(cid));
          println("Number of LEDs = " + nled);

          return true;
        } 
        catch (SerialDecodeException sde) {
          throw new BadAckException(this.getClass().getName() + ": Error decoding ident response:\n  " + sde.message);
        }
      } else {
        return false;
      }
    }

    ControllerState stateTransform(ControllerState cs0) { return cs0; }
  }

  class CommandReset
    extends Command
  {
    final byte encoding[] = { protoReset };

    CommandReset() { }

    byte[] encode() { return encoding; }
    ControllerState stateTransform(ControllerState cs0) { return cs0; }
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

  class CommandUpdate
    extends Command
  {
    private final byte encoding[] = { commandUpdate };
    CommandUpdate() { }
    byte[] encode() { return encoding; }
    ControllerState stateTransform(ControllerState cs0)
    {
      return new ControllerState(cs0.storedColors, cs0.storedColors, cs0.autoUpdate); 
    }
    boolean ackByte(Controller c, byte b) 
      throws BadAckException
    {
      if (b == ackUpdated) {
        currentState = stateTransform(currentState);
        return true;
      } else {
        throw new BadAckException(this, ackUpdated, b);
      }
    }

  }
}

