#!/usr/bin/python

import sys

for argstr in sys.argv[1:len(sys.argv)]:
    if (len(argstr) == 4):
        h0 = ord(argstr[0]) - 0x30;
        h1 = ord(argstr[1]) - 0x30;
        h2 = ord(argstr[2]) - 0x30;
        h3 = ord(argstr[3]) - 0x30;

        r = (h0 << 2) + (h1 >> 4)
        g = ((h1 & 0x0f) << 4) + (h2 >> 2)
        b = ((h2 & 0x03) << 6) + h3

        rgb = (r << 16) + (g << 8) + b
        print argstr,"=>",hex(h0),hex(h1),hex(h2),hex(h3),"=",hex(rgb)
    else:
        print argstr,"not length 4"
