#!/usr/bin/python

import sys

for argstr in sys.argv[1:len(sys.argv)]:
    try:
        argval = int(argstr)
        if (argval >= 0) & (argval < 0xfff):
            b1 = 0x30 + ((argval >> 6) & 0x3f);
            b2 = 0x30 + (argval & 0x3f);
            print argstr,"=>",hex(b1),hex(b2),"=",chr(b1)+chr(b2)
        else:
            print argstr," out of range [0,4095]"
    except ValueError:
        print "Input argument ",argstr," not integral"
