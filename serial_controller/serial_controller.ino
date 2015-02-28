// Use if you want to force the software SPI subsystem to be used for some reason (generally, you don't)
// #define FORCE_SOFTWARE_SPI
// Use if you want to force non-accelerated pin access (hint: you really don't, it breaks lots of things)
// #define FORCE_SOFTWARE_SPI
// #define FORCE_SOFTWARE_PINS
#include "FastLED.h"



///////////////////////////////////////////////////////////////////////////////////////////
//
// Move a white dot along the strip of leds.  This program simply shows how to configure the leds,
// and then how to turn a single pixel white and then off, moving down the line of pixels.
// 

#define SERIAL_SPEED 9600

#define CONTROLLER_ID 0x000

// How many leds are in the strip?
#define NUM_LEDS 128

// Data pin that led data will be written out over
#define DATA_PIN 12

// Clock pin only needed for SPI based chipsets when not using hardware SPI
#define CLOCK_PIN 11

// Pin for status LED
#define STATUS_PIN 13

// This is an array of leds.  One item for each led in your strip.
CRGB leds[NUM_LEDS];

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

// Acknowledgements begin controller->master messages
#define ACK_RESET 0x7e // Stands alone
#define ACK_ZERO  0x21 // Stands alone
#define ACK_ONE   0x22 // Followed by 12-bit LED index
#define ACK_MANY  0x23 // Followed by 12-bit LED count
#define ACK_IDENT 0x24 // Followed by 12-bit controller ID and 12-bit LED count
#define ACK_ERROR 0x7d // Error during decoding

#define RESULT_GOOD 1
#define RESULT_RESET -1
#define RESULT_ERROR -2

// This function sets up the ledsand tells the controller about them
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

int serialReadBlocking() {
  int b;
  while ((b = Serial.read()) < 0) { /* Do nothing */ } 
  return b;
}

// Read a protocol value into (*dest) and return RESULT_GOOD. If a
// protocol reset byte (PROTO_RESET, which is outside [PROTO_MIN,
// PROTO_MAX]) is encountered, leave (*dest) unchanged and return
// RESULT_RESET.  If an error is encountered (any other value less
// than PROTO_MIN or greater than PROTO_MAX), leave (*dest) unchanged
// and return RESULT_ERROR.
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

// Decode two decoded 6-bit values into a 12-bit value and return
// RESULT_GOOD. If either decoded 6-bit value falls outside the 6-bit
// range, return RESULT_ERROR and leave dest unchanged.
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

int serialEncode12(struct protoByte *b1, struct protoByte *b2, uint16_t val)
{
  if (val & (ENCODE_MASK | (ENCODE_MASK << 6))) {
    return RESULT_ERROR;
  }

  b2->pbyte = (val & ENCODE_MASK);
  val = val >> 6;
  b1->pbyte = (val & ENCODE_MASK);

  return RESULT_GOOD;
}

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

// Read 4 bits of encoded CRGB color (through serialReadEncoded),
// decode it into a CRGB dest, and return RESULT_GOOD. In the case of
// any non-GOOD results from reading or decoding, leave dest unchanged
// and return instead the result that arose.
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

// Decode a 4x6-bit RGB color into a CRGB, dest, and return
// RESULT_GOOD. If any of the input 6-bit values fall outside the
// 6-bit range, leave dest unchanged and instead return RESULT_ERROR.
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
    default:
      return RESULT_ERROR;
    }
  }
}

// Acknowledge a protocol stream reset
void protoReset()
{
  Serial.write(ACK_RESET);
}

// Send an error acknowledgement and block while reading bytes until a
// protocol stream reset comes up.
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

    digitalWrite(STATUS_PIN, ((millis() / 400) > 200));
  } while (1);
}

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

  Serial.write(ACK_ONE);
  serialWrite12(ledno);
  return RESULT_GOOD;
}

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
  for (idx = 0; idx < (1 + ledhi - ledlo); idx++) {
    if ((res = serialReadRGB(&(leds[ledlo + idx]))) != RESULT_GOOD) {
      break;
    }
  }

  Serial.write(ACK_MANY);
  serialWrite12(idx);
}

int commandBlank(void)
{
  fill_solid(leds, NUM_LEDS, CRGB::Black);

  Serial.write(ACK_MANY);
  serialWrite12(NUM_LEDS);
}

int commandQuery(void)
{
  Serial.write(ACK_IDENT);

  serialWrite12(CONTROLLER_ID);
  serialWrite12(NUM_LEDS);

  return RESULT_GOOD;
}

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

  return commandQuery();
}

