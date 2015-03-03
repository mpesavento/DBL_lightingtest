#!/usr/bin/python

import sys, string

def encode12(v):
    if ((v < 0) or (v > 0xfff)):
        raise Exception("Value out of 12-bit range: " + v)
    return [ 0x30 + ((v >> 6) & 0x3f)
           , 0x30 + (v & 0x3f)
           ]

def encodeRGB(rgb):
    if ((rgb < 0) or (rgb > 0xffffff)):
        raise Exception("RGB value out of 24-bit range: " + hex(rgb))
    r = (rgb >> 16) & 0xff
    g = (rgb >> 8) & 0xff
    b = rgb & 0xff
    return [ 0x30 + (r >> 2), 0x30 + ((r & 0x03) << 4) + (g >> 4)
           , 0x30 + ((g & 0x0f) << 2) + (b >> 6), 0x30 + (b & 0x3f)
           ]

def parseRGB(rgbstr):
    if ((len(rgbstr) == 8) and (rgbstr[0:2] == "0x")):
        return int(rgbstr[2:len(rgbstr)], base=16)
    else:
        raise Exception("Malformed RGB string " + repr(rgbstr))

def LED(argspl):
    if (len(argspl) != 3):
        raise Exception("Malformed LED command " + repr(argspl))
    ledidx = encode12(int(argspl[1]))
    color = encodeRGB(parseRGB(argspl[2]))
    return (ledidx + color)

def Block(argspl):
    ledlo = int(argspl[1])
    ledhi = int(argspl[2])
    if ((ledhi - ledlo) != (len(argspl) - 4)):
        raise Exception("LED range ["+str(ledlo)+","+str(ledhi)+"] but saw " + str(len(argspl)-2) + " RGB colors")
    rgbs = map(parseRGB, argspl[3:len(argspl)])
    colors = map(encodeRGB, rgbs)
    buf = [ 0x21 ] + encode12(ledlo) + encode12(ledhi)
    for color in colors:
        buf = buf + color
    return buf

def Blank(argspl):
    return [ 0x22 ]

def Query(argspl):
    return [ 0x23 ]

def Blink(argspl):
    return [ 0x24 ]

def Update(argspl):
    return [ 0x25 ]

def AutoUpdate(argspl):
    return [ 0x26 ]

def NoAutoUpdate(argspl):
    return [ 0x27 ]

def BurnInfo(argspl):
    cid = encode12(int(argspl[1]))
    nled = encode12(int(argspl[2]))
    return ([ 0x7c ] + cid + nled)

commandDict = dict( LED=LED
                    , Block=Block
                    , Blank=Blank
                    , Query=Query
                    , Blink=Blink
                    , Update=Update
                    , AutoUpdate=AutoUpdate
                    , NoAutoUpdate=NoAutoUpdate
                    , BurnInfo=BurnInfo
                )

def command(argspl):
    if (not(commandDict.has_key(argspl[0]))):
        raise Exception("Unknown command in " + repr(argspl))
    return (commandDict[argspl[0]])(argspl)

final = "";

for argstr in sys.argv[1:len(sys.argv)]:
    argspl = argstr.split(",")
    try:
        buf = command(argspl)
        hexstrs = map(hex, buf)
        chrs = map(chr,buf)
        print argstr,"=>",string.join(hexstrs),"=",string.join(chrs,sep='')
        final = final + string.join(chrs, sep='')
    except Exception as e:
        print "Error encoding",format(argstr),":",e.message

print final
