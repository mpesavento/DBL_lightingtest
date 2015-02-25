#!/usr/bin/python

import sys, os, math
import csv

segs = {}
count = 0
sys.argv[1]="node_info.csv"
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
   fs[f + "-" + t] = s = {}
   s["fx"] = segs[f]["fx"]
   s["fy"] = segs[f]["fy"]
   s["fz"] = segs[f]["fz"]
   s["tx"] = segs[t]["fx"]
   s["ty"] = segs[t]["fy"]
   s["tz"] = segs[t]["fz"]
   while pair < len(vals)-2:
      pair+=2
     # f = t    #this line was causing an error. the nodes in a given line are all connecting to the first node, not stringing along each other.
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

module_nodes=["ERA","RIB","IRE","FOG","LAW","GIG","EVE","TAU","OLD","LIE"]
#full path
#module_path=["LIE","TAU","FOG","RIB","ERA","IRE","GIG","LIE","OLD","TAU","LAW","OLD","FOG","LAW","RIB","IRE","LAW","ERA","GIG","LAW","LIE","EVE","OLD","EVE","GIG","EVE","IRE"]
module_path=["LIE","TAU","FOG","LAW","EVE","OLD","LIE"]

x0=segs[module_path[0]]["fx"]
y0=segs[module_path[0]]["fy"]
z0=segs[module_path[0]]["fz"]

segment_indexes={}
leds=[]
led_distance=0.656168 #60 leds per meter, in inches. Why in tarnation are we using inches?
start=module_path[0]
distance_covered=0
ledpositions=[]
minledx=0
minledy=0
minledz=0
maxledx=0
maxledy=0
maxledz=0
for node in module_path[1:]: 
      end=node
      k = start+"-"+end
      k2=end+"-"+start
      segment_index_reversed=False
      try:
         f = fs[k]
         xd = f["tx"] - f["fx"]
         yd = f["ty"] - f["fy"]
         zd = f["tz"] - f["fz"]
         right_direction=k
      except KeyError:
         f = fs[k2]
         fs[k]=f
         segment_index_reversed=True
         xd = f["fx"] - f["tx"]
         yd = f["fy"] - f["ty"]
         zd = f["fz"] - f["tz"]
         right_direction=k2
      segment_indexes[right_direction]=[]
      segment_indexes[right_direction].append(len(ledpositions)+1)
      distance=math.sqrt(math.pow(xd,2)+math.pow(yd,2)+math.pow(zd,2))
      distance_covered+=distance
      divcount=0
      while len(ledpositions)*led_distance<distance_covered:
         if not segment_index_reversed:
            ledx=f["fx"]+divcount*led_distance*xd/distance-x0
            ledy=f["fy"]+divcount*led_distance*yd/distance-y0
            ledz=f["fz"]+divcount*led_distance*zd/distance-z0
         else:
            ledx=f["tx"]-divcount*led_distance*xd/distance-x0
            ledy=f["ty"]-divcount*led_distance*yd/distance-y0
            ledz=f["tz"]-divcount*led_distance*zd/distance-z0
         ledpositions.append([ledx,ledy,ledz])
         if ledx<minledx:
            minledx=ledx
         if ledy<minledy:
            minledy=ledy
         if ledz<minledz:
            minledz=ledz
         if ledx>maxledx:
            maxledx=ledx
         if ledy>maxledy:
            maxledy=ledy
         if ledy>maxledz:
            maxledz=ledz
         divcount+=1
      segment_indexes[right_direction].append(len(ledpositions))
      start=end
      #ledpositions.append(node)

with open("led_positions.csv","wb") as f:
   wrtr=csv.writer(f)
   for c,led in enumerate(ledpositions):
      wrtr.writerow([c]+led)
      print c,"-",led

with open("segment_start_end_indexes.csv","wb") as f:
   wrtr=csv.writer(f)
   for segment in segment_indexes:
      wrtr.writerow([segment]+segment_indexes[segment])

for x in segment_indexes:
   print x,segment_indexes[x]      

print "min x,y,z:",minledx,minledy,minledz
print "max x,y,z:",maxledx,maxledy,maxledz

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
  #    print f["fx"]+xd*i, ",", f["fy"]+yd*i, ",", f["fz"]+zd*i
     pass
   #print "point(", f["tx"], ",", f["ty"], ",", f["tz"], ");"
   #print "endShape();"


