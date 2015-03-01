#include "FastLED.h"

// Per-controller configuration:
#define CONTROLLER_ID 0x123
#define NUM_LEDS 300

#define SERIAL_SPEED 115200

// SPI configuration:
// Data pin that led data will be written out over
#define DATA_PIN 12
// Clock pin only needed for SPI based chipsets when not using hardware SPI
#define CLOCK_PIN 11
// Use if you want to force the software SPI subsystem to be used for some reason (generally, you don't)
// #define FORCE_SOFTWARE_SPI
// Use if you want to force non-accelerated pin access (hint: you really don't, it breaks lots of things)
// #define FORCE_SOFTWARE_SPI
// #define FORCE_SOFTWARE_PINS

// Pin for status LED
#define STATUS_PIN 13

// This is an array of leds.  One item for each led in your strip.
CRGB leds[NUM_LEDS];
bool autoUpdate;

// SERIAL PROTOCOL

// The protocol consists of messages sent from the master to the
// Arduino controller, comprising a command along with a collection of
// data. These controller acknowledges each message after completing
// all required processing (updating memory and potentially sending
// new data out to LEDs.

// Messages manipulate a stored array of LED values on the controller,
// as well as the propagation of stored LED values onto the attached
// physical LEDs. By default, messages change only stored LED values
// and a separate message triggers an update of the physical LEDs with
// the stored values. The controller can be set into "auto-update"
// mode, meaning that stored LED values are propagated immediately
// following all changes to their stored values.

// LOW-LEVEL DETAILS

// Protocol bytes are always between 0x21 (ASCII '!') and 0x7e (ASCII
// '~') inclusive. The space character 0x20 is never used.

// The protocol encodes 6-bit values by adding 0x30 (ASCII '0'),
// yielding an encoded value between 0x30 and 0x6f (ASCII 'o'). These
// 6-bit values are combined to represent 12-bit integers in
// most-significant-first order, as well as 24-bit colors in 8-bit,
// RGB, most-significant-first order.

// The value 0x7e (ASCII '~') is reserved for a "reset" value that may
// be sent by the master at any time. This terminates any ongoing
// message, though in some cases the message may have been partially
// executed. The Arduino controller acknowledges the reset by sending
// back 0x7e, at which point the master can send a new message.

// When the Arduino controller receives erroneous data, it terminates
// the current message (which may have been partially executed) and
// immediately sends an error byte 0x7d (ASCII '}'). The controller
// ignores all subsequent data until a protocol reset is completed,
// initiated by the master as described above and then acknowledged by
// the Arduino controller.

// MESSAGES

// A single-LED update message comprises a 12-bit LED index followed
// by a 24-bit color. Any message beginning with a valid 6-bit value
// is a single-LED update. This message is acknowledged with
// ACK_STORED = 0x22 (ASCII '"'), unless the controller is in
// auto-update mode, in which case it is acknowledged with ACK_UPDATED
// = 0x23 (ASCII '#').

// A block update message begins with an 0x21 (ASCII '!') command
// byte, followed by two 12-bit numbers giving the first and the last
// LED indexes to be updated, inclusively. New 24-bit colors for these
// LEDs are then specified in order from first to last. Protocol
// errors or resets arising in the middle of a block update message
// can result in the update of a subset of LEDs, which will occur in
// the absence of an acknowledgement. This message is acknowledged
// with ACK_STORED or ACK_UPDATED as with single-LED updates.

// A blanking message comprises an 0x22 (ASCII '"') command byte. This
// resets all stored LED colors to black (i.e., off). It is
// acknowledged by ACK_STORED or ACK_UPDATED as with single-LED
// updates.

// A controller query message comprises an 0x23 (ASCII '#') command
// byte. It is acknowledged by an ACK_IDENT = 0x21 (ASCII '!')
// followed by a 12-bit / 2-byte controller ID number and a 12-bit /
// 2-byte LED count.

// A controller blink message comprises an 0x24 (ASCII '$') command
// byte. This blinks all LEDs by XORing their color value components
// with 255, typically changing the hue and brightness of the entire
// strip very noticeably (though 50% grey does not change
// greatly). The blink lasts 1 second, after which time values are
// reverted to their original status. The controller blink is intended
// for development and debugging rather than generating visual
// effects, and so it is propagated to the physical LEDs
// immediately. It is acknowledged by ACK_UPDATED = 0x23 (ASCII '#')
// after the ~1s blink is completed.

// The update message comprises an 0x25 (ASCII '%') command byte. This
// propagates stored LED colors onto physical LEDs immediately, and is
// acknowledged by ACK_UPDATED = 0x23 (ASCII '#').

// The auto-update message comprises an 0x26 (ASCII '&') command
// byte. This sets the controller into auto-update mode and
// immediately propagates stored LED colors onto physical LEDs, and is
// acknowledged by ACK_UPDATED = 0x23 (ASCII '#').

// The no-auto-update message comprises an 0x27 (ASCII ''') command
// byte. This unsets auto-update mode on the controller and is
// acknowledged by ACK_STORED = 0x22 (ASCII '"').

// Messages 0x28 (ASCII '(') through 0x2f (ASCII '/') and 0x70 (ASCII
// 'p') through 0x7c (ASCII '|') are available for future expansion;
// it is advised to avoid using 0x7d for future messages although 0x7d
// has special significance for controller-to-master messages at
// present. All acknowledgement values 0x24 (ASCII '$') through 0x7c
// are available for future expansion. 

// Serial protocol
#define PROTO_MIN   0x21
#define PROTO_MAX   0x7d
#define PROTO_RESET 0x7e

// Guaranteed to be between min and max, not 8- to 6-decoded.
struct protoByte { uint8_t pbyte; };

// 8-bit to 6-bit encoding parameters
#define ENCODE_BASE  0x30
#define ENCODE_MASK  0x3f
#define ENCODE_INVM  0xc0
#define ENCODE_MIN   ENCODE_BASE
#define ENCODE_MAX   (ENCODE_BASE + ENCODE_MASK)

// Commands start master->controller messages with values outside 6-bit encoding
// Default command is a 12-bit LED index followed by a 24-bit RGB
#define CMD_BLOCK 0x21 // Followed by 12-bit start, 12-bit end, and N * 24-bit RGB block
#define CMD_BLANK 0x22 // Followed by nothing
#define CMD_QUERY 0x23 // Followed by nothing
#define CMD_BLINK 0x24 // Followed by nothing
#define CMD_UPDATE 0x25
#define CMD_AUTOUPDATE 0x26
#define CMD_NOAUTOUPDATE 0x27

// Acknowledgements begin controller->master messages
#define ACK_IDENT 0x21 // Followed by 12-bit controller ID and 12-bit LED count
#define ACK_STORED 0x22
#define ACK_UPDATED 0x23
#define ACK_ERROR 0x7d // Error during decoding
#define ACK_RESET 0x7e  

#define RESULT_GOOD 1
#define RESULT_RESET -1
#define RESULT_ERROR -2

void setup() {
    // sanity check delay - allows reprogramming if accidently blowing power w/leds
    pinMode(STATUS_PIN, OUTPUT);
    for (int i = 0; i < 5; i++) {
      digitalWrite(STATUS_PIN, HIGH);
      delay(200);
      digitalWrite(STATUS_PIN, LOW);
      delay(200);
    }

    FastLED.addLeds<APA102, DATA_PIN, CLOCK_PIN, GBR>(leds, NUM_LEDS); //init the LED array
    autoUpdate = false;
}

void loop() {
  int res = processCommand();

  if (res == RESULT_GOOD) {
    return;
  } else if (res == RESULT_RESET) {
    protoReset();
  } else {
    protoError();
  }
}

// Blocking read for 1 byte from the serial port.
int serialReadBlocking() {
  int b;
  while ((b = Serial.read()) < 0) { /* Do nothing */ } 
  return b;
}

// Blocking read for value in serial protocol, catching protocol reset
// requests.  
// The value read is stored into (*dest). In the case of a protocol
// reset or an error, (*dest) is unchanged.
// Returns RESULT_GOOD when a value is read, or RESULT_RESET for
// protocol reset, or RESULT_ERROR for protocol errors.
int serialReadProtocol(struct protoByte *proto)
{
  int raw = serialReadBlocking();
  if (raw == PROTO_RESET) {
    return RESULT_RESET;
  } else if (raw < PROTO_MIN || raw > PROTO_MAX) {
    return RESULT_ERROR;
  } else {
    proto->pbyte = raw;
    return RESULT_GOOD;
  }
}

// 12-BIT ENCODING
// Two 6-bit values are specified in two bytes with the most
// significant first. Each 6-bit value is encoded by adding
// ENCODE_BASE.

// Value 0 is encoded by '00', value 1 by '01', and so forth to value
// 4095 encoded by 'oo'.

// Blocking read for a 12-bit integer value from the serial protocol.
// The value read is stored into (*dest). In the case of a protocol
// reset, a protocol error, or an encoding error, (*dest) is
// unchanged.
// Returns RESULT_GOOD when a value is read; RESULT_RESET for a
// protocol reset; and RESULT_ERROR for errors in reading or decoding.
int serialRead12(uint16_t *dest)
{
  struct protoByte b1, b2;
  int res;
  if ((res = serialReadProtocol(&b1)) != RESULT_GOOD) {
    return res;
  }
  if ((res = serialReadProtocol(&b2)) != RESULT_GOOD) {
    return res;
  }
  return serialDecode12(dest, b1, b2);
}

// Decode two bytes into a 12-bit value.
// The bytes are b1 and b2, in that order.
// The decoded value is stored into (*dest). In the case of a decoding
// error, (*dest) is unchanged.
// Returns RESULT_GOOD when a value is read, or RESULT_ERROR for
// errors in decoding.
int serialDecode12(uint16_t *dest, struct protoByte b1, struct protoByte b2)
{
  uint8_t d1 = b1.pbyte - ENCODE_BASE, d2 = b2.pbyte - ENCODE_BASE;
  if ((d1 | d2) & ENCODE_INVM) {
    return RESULT_ERROR;
  } else {
    (*dest) = (((uint16_t) d1) << 6) + d2;
    return RESULT_GOOD;
  }
}

// Write a 12-bit value in the serial protocol.
// The value is given in val, which should fall in the 12-bit value
// range [0, 4095].
// Returns RESULT_GOOD when a value is encoded, or RESULT_ERROR for an
// out-of-range value.
int serialWrite12(uint16_t val)
{
  int res;
  struct protoByte b1, b2;

  if ((res = serialEncode12(&b1, &b2, val)) != RESULT_GOOD) {
    return res;
  }
  Serial.write(b1.pbyte);
  Serial.write(b2.pbyte);
  return RESULT_GOOD;
}

// Encode a 12-bit value into two bytes.
// The value is given in val, which should fall between 0 and 4095.
// The encoded bytes are stored into (*b1) and (*b2). These are left
// unchanged in the case of an encoding error.
// Returns RESULT_GOOD when a value is encoded, or RESULT_ERROR for an
// out-of-range value.
int serialEncode12(struct protoByte *b1, struct protoByte *b2, uint16_t val)
{
  if (val > (ENCODE_MASK + (ENCODE_MASK << 6))) {
    return RESULT_ERROR;
  }

  b2->pbyte = ENCODE_BASE + (val & ENCODE_MASK);
  val = val >> 6;
  b1->pbyte = ENCODE_BASE + (val & ENCODE_MASK);

  return RESULT_GOOD;
}

// COLOR ENCODING INTO FOUR BYTES

// Encoding of 3x8bit RGB color into 4x6 bit encoding:

// 876543218765432187654321
// rrrrrrrrggggggggbbbbbbbb
// 654321654321654321654321
// 111111222222333333444444

// Black = decoded 00 00 00 00 = encoded 30 30 30 30 = ascii 0000
// White = decoded 3f 3f 3f 3f = encoded 6f 6f 6f 6f = ascii oooo
// Red   = decoded 3f 30 00 00 = encoded 6f 60 30 30 = ascii o`00
// Green = decoded 00 0f 3c 00 = encoded 30 3f 6c 30 = ascii 0?l0
// Blue  = decoded 00 00 03 3f = encoded 30 30 33 6f = ascii 003o

// Blocking read of a 4-byte encoded color.
// The decoded color is stored into (*dest), which is left unchanged
// in the case of a protocol reset or error.
// When a color is read and decoded, RESULT_GOOD is returned. Protocol
// resets and errors while reading bytes give result values of
// RESULT_RESET and RESULT_ERROR, respectively, and in the case of
// decoding errors, RESULT_ERROR is returned.
int serialReadRGB(CRGB *dest)
{
  struct protoByte hs[4];
  for (int i = 0; i < 4; i++) {
    int res = serialReadProtocol(&(hs[i]));
    if (res != RESULT_GOOD) {
      return res;
    }
  }
  return serialDecodeRGB(dest, hs);
}

// Decode a 4-byte encoded color.
// The encoded bytes are provided in hs.
// The decoded color is stored into (*dest), which is left unchanged
// in the case of a decoding error.
// When a color is successfully decoded, RESULT_GOOD is
// returned. Otherwise, RESULT_ERROR is returned.
int serialDecodeRGB(CRGB *dest, struct protoByte hs[4])
{
  uint8_t h0 = (hs[0].pbyte - ENCODE_BASE);
  uint8_t h1 = (hs[1].pbyte - ENCODE_BASE);
  uint8_t h2 = (hs[2].pbyte - ENCODE_BASE);
  uint8_t h3 = (hs[3].pbyte - ENCODE_BASE);
  if ((h0 | h1 | h2 | h3) & ENCODE_INVM) {
    return RESULT_ERROR;
  } else {
    (dest->r) = (h0 << 2) + (h1 >> 4);
    (dest->g) = ((h1 & 0x0f) << 4) + (h2 >> 2);
    (dest->b) = ((h2 & 0x03) << 6) + h3;
    return RESULT_GOOD;
  }
}

// Read and process one command from the input stream.
// Return RESULT_GOOD for success, or RESULT_RESET or RESULT_ERROR for
// protocol resets or errors arising during the reading, execution, or
// acknowledgement of commands.
int processCommand()
{
  struct protoByte b;
  int res = serialReadProtocol(&b);
  if (res != RESULT_GOOD) {
    return res;
  }

  if ((b.pbyte >= ENCODE_MIN) && (b.pbyte <= ENCODE_MAX)) {
    return commandOne(b);
  } else {
    switch(b.pbyte) {
    case CMD_BLOCK:
      return commandBlock();
    case CMD_BLANK:
      return commandBlank();
    case CMD_QUERY:
      return commandQuery();
    case CMD_BLINK:
      return commandBlink();
    case CMD_UPDATE:
      return commandUpdate();
    case CMD_AUTOUPDATE:
      return commandAutoUpdate();
    case CMD_NOAUTOUPDATE:
      return commandNoAutoUpdate();
    default:
      return RESULT_ERROR;
    }
  }
}

// Acknowledge a protocol reset message by writing a reset
// acknowledgement byte.
void protoReset()
{
  Serial.write(ACK_RESET);
}

// Enter a protocol error state.
// The error state blocks and discards all serial input until a
// protocol reset byte is present at the head of the serial buffer,
// but does not consume this reset byte. At the same time, the value
// of the status pin is toggled in a distinctive repeating pattern.
void protoError()
{
  Serial.write(ACK_ERROR);

  do { 
    int res = Serial.peek();
    if (res == PROTO_RESET) {
      break;
    } else if (res >= 0) {
      Serial.read();
    }

    int t = (millis() % 1700) / 50;

    digitalWrite(STATUS_PIN, (t == 0 || t == 2 || t == 4 || (t >= 8 && t <= 18 && t != 11 && t != 15) || t == 22 || t == 24 || t == 26));
  } while (1);
  
  digitalWrite(STATUS_PIN, LOW);
}

// Read and process a single LED update message.
// b1 is the first byte of the message, which should contain a valid
// 6-bit encoding.
// Returns RESULT_GOOD on success, or RESULT_ERROR or RESULT_RESET for
// errors and protocol resets.
int commandOne(struct protoByte b1)
{
  struct protoByte b2;
  int res;
  uint16_t ledno;

  if ((res = serialReadProtocol(&b2)) != RESULT_GOOD) {
    return res;
  }
  if ((res = serialDecode12(&ledno, b1, b2)) != RESULT_GOOD) {
    return res;
  }

  if (ledno >= NUM_LEDS) {
    return RESULT_ERROR;
  }

  if ((res = serialReadRGB(&(leds[ledno]))) != RESULT_GOOD) {
    return res;
  }

  if (autoUpdate) {
    FastLED.show();
    Serial.write(ACK_UPDATED);
  } else {
    Serial.write(ACK_STORED); 
  }
  
  return RESULT_GOOD;
}

// Read and process a block LED update message.
// Returns RESULT_GOOD on success, or RESULT_ERROR or RESULT_RESET for
// errors and protocol resets.
int commandBlock()
{
  int res;
  uint16_t ledlo, ledhi;

  if ((res = serialRead12(&ledlo)) != RESULT_GOOD) {
    return res;
  }
  if ((res = serialRead12(&ledhi)) != RESULT_GOOD) {
    return res;
  }

  if ((ledlo > ledhi) || (ledhi >= NUM_LEDS)) {
    return RESULT_ERROR;
  }

  uint16_t idx;
  for (idx = 0; ledlo + idx <= ledhi; idx++) {
    if ((res = serialReadRGB(&(leds[ledlo + idx]))) != RESULT_GOOD) {
      break;
    }
  }
  
  if (autoUpdate) {
    FastLED.show();
    Serial.write(ACK_UPDATED);
  } else {
    Serial.write(ACK_STORED); 
  }
  
  return RESULT_GOOD;
}

// Process a blanking message.
// Returns RESULT_GOOD (i.e., cannot fail).
int commandBlank(void)
{
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  if (autoUpdate) {
    FastLED.show();
    Serial.write(ACK_UPDATED);
  } else {
    Serial.write(ACK_STORED);
  }
  return RESULT_GOOD;
}

// Process a query message by replying with the controller ID and number of LEDs.
// Returns RESULT_GOOD, or RESULT_ERROR in the case of an error
// encoding the return acknowledgement.
int commandQuery(void)
{
  int res;
  
  Serial.write(ACK_IDENT);

  if ((res = serialWrite12(CONTROLLER_ID)) != RESULT_GOOD) {
    return res; 
  }
  return serialWrite12(NUM_LEDS);
}

// Process a blink message.
// Returns RESULT_GOOD (i.e., cannot fail).
int commandBlink(void)
{
  for (int led = 0; led < NUM_LEDS; led++) {
    leds[led].r ^= 0xff;
    leds[led].g ^= 0xff;
    leds[led].b ^= 0xff;
  }

  FastLED.show();

  delay(1000);

  for (int led = 0; led < NUM_LEDS; led++) {
    leds[led].r ^= 0xff;
    leds[led].g ^= 0xff;
    leds[led].b ^= 0xff;
  }

  FastLED.show();

  Serial.write(ACK_UPDATED);
  return RESULT_GOOD;
}

// Process an update message.
// Returns RESULT_GOOD (i.e., cannot fail).
int commandUpdate(void)
{
  FastLED.show();
  Serial.write(ACK_UPDATED);
  return RESULT_GOOD; 
}

// Process an auto-update message.
// Returns RESULT_GOOD (i.e., cannot fail).
int commandAutoUpdate(void)
{
  autoUpdate = 1;
  FastLED.show();
  Serial.write(ACK_UPDATED);
  return RESULT_GOOD; 
}

// Process a no-auto-update message.
// Returns RESULT_GOOD (i.e., cannot fail).
int commandNoAutoUpdate(void)
{
  autoUpdate = 0;
  Serial.write(ACK_STORED);
  return RESULT_GOOD; 
}
