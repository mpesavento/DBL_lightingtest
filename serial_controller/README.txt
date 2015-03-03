The serial protocol, described in detail in the source file, uses all
ASCII printable characters. Thus, it can be tested and programmed from
the serial monitor -- remember to set the speed to 115200 baud and
turn off line endings.

In the case of an error (blinking status LED) send a reset message 
~
which should reset the controller and produce a 
~
response. In addition to blinking, the controller should send a
}
message when it encounters a protocol error. The controller will
ignore everything besides a reset while in the error state.

Query the controller configuration with
#
And receive a response like
!oo0b
This indicates a controller with compile-time default controller ID
and LED count (50 LEDs).

Set individual LED colors with
00oooo%
and similar commands as described below, which will be acknowledged by
"#

The first two comprise an encoded LED index, where 00 = 0, 01 = 1, 09
= 9, 0: = 10, 0; = 11, and so forth through ASCII values up to 0o =
63, though by default the controller is configured for only 50 LEDs
(i.e., through 0a) and will enter an error state if you go beyond 50.

The following 4 comprise an encoded RGB value, which is documented in
the source but briefly:
Black = 0000
White = oooo
Red   = o`00
Green = 0?l0
Blue  = 003o

Finally, you can program the controller ID and the LED count using
|001T
for 100 LEDs, which should receive a response of
!001T
You can substitute 1T for e.g. 38 for 200 LEDs or 4\ for 300 LEDs.

