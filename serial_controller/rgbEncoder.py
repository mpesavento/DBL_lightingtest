#!/usr/bin/python

import sys

for argstr in sys.argv[1:len(sys.argv)]:
    if ((len(argstr) == 8) & (argstr[0:2] == "0x")):
        argstr = argstr[2:len(argstr)]
    
    if (len(argstr) == 6):
        rgb = int(argstr, base=16)
        r = (rgb >> 16) & 0xff
        g = (rgb >> 8) & 0xff
        b = rgb & 0xff

        h0 = 0x30 + (r >> 2)
        h1 = 0x30 + ((r & 0x03) << 4) + (g >> 4)
        h2 = 0x30 + ((g & 0x0f) << 2) + (b >> 6)
        h3 = 0x30 + (b & 0x3f)

        print argstr,"=>",hex(h0),hex(h1),hex(h2),hex(h3),"=",chr(h0)+chr(h1)+chr(h2)+chr(h3)
    else:
        print argstr,"not a good hex RGB value"
