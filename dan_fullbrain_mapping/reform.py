#!/usr/bin/python

import sys, os

segs = {}
count = 0
for line in open(sys.argv[1], "r").xreadlines():
   vals = line.rstrip().split(",")
   if len(vals)<6: continue
   seg = vals[0]
   x = float(vals[1])
   y = float(vals[2])
   z = float(vals[3])
   segs[seg] = {"fx":x,"fy":y,"fz":z}

fs = {}
for line in open(sys.argv[1], "r").xreadlines():
   vals = line.rstrip().split(",")
   if len(vals)<6: continue

   pair = 4
   f = vals[0]
   t = vals[pair]
   fs["start-" + f] = s = {}
   s["fx"] = segs[f]["fx"]
   s["fy"] = segs[f]["fy"]
   s["fz"] = segs[f]["fz"]
   s["tx"] = segs[t]["fx"]
   s["ty"] = segs[t]["fy"]
   s["tz"] = segs[t]["fz"]

   while pair < len(vals)-2:
      pair+=2
      f = t
      t = vals[pair]
      fs[f + "-" + t] = s = {}
      s["fx"] = segs[f]["fx"]
      s["fy"] = segs[f]["fy"]
      s["fz"] = segs[f]["fz"]
      s["tx"] = segs[t]["fx"]
      s["ty"] = segs[t]["fy"]
      s["tz"] = segs[t]["fz"]

#print segs

#sys.exit()

for k in fs.keys():
   #print k, segs[k]
   #print "beginShape();"
   f = fs[k]
   xd = f["tx"] - f["fx"]
   yd = f["ty"] - f["fy"]
   zd = f["tz"] - f["fz"]

   interp = 15

   xd/=interp;
   yd/=interp;
   zd/=interp;

   for i in range(0,interp):
      print f["fx"]+xd*i, ",", f["fy"]+yd*i, ",", f["fz"]+zd*i

   #print "point(", f["tx"], ",", f["ty"], ",", f["tz"], ");"
   #print "endShape();"


