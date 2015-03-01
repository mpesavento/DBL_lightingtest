#!/usr/bin/python

import sys

for argstr in sys.argv[1:len(sys.argv)]:
    if (len(argstr) == 2):
        b1 = ord(argstr[0])
        b2 = ord(argstr[1])
        v = ((b1 - 0x30) << 6) + (b2 - 0x30)
        print argstr,"=>",hex(b1),hex(b2),"=",v
    else:
        print argstr," not length 2"
