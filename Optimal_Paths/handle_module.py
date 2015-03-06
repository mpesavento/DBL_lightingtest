#!/usr/bin/python

import sys, os, math
import csv
import numpy, random, copy

nodefile="../node_info.csv"

module_nodes=set(["ERA","RIB","IRE","FOG","LAW","GIG","EVE","TAU","OLD","LIE"])

#reads the node positions file and saves the xyz of each node/segment
nodes = {}
    
for line in open(nodefile, "r").xreadlines():
   vals = line.rstrip().split(",")
   if len(vals) <4 or len(vals[0]) != 3: 
       continue
   node = vals[0]
   if node not in module_nodes:
      continue
   x = int(float(vals[1]) * 25.4) # millimeters!
   y = int(float(vals[2]) * 25.4) # for the love of god!
   z = int(float(vals[3]) * 25.4)
   pos = numpy.array((x, y, z))
   mates={}
   mateidx = 4
   while mateidx < len(vals)-1:
      mate = vals[mateidx]
      if mate in module_nodes:
         mates[mate] = None
      mateidx += 2
   nodes[node] = {"pos":pos, "mates":mates}

# Store distances as value for mate keys
for node,val in nodes.iteritems():
   for mate in val["mates"].iterkeys():
      val["mates"][mate] = int(numpy.linalg.norm(val["pos"] -  nodes[mate]["pos"]))

print nodes
   
dist = 0
for node in nodes.iterkeys():
   for mate in nodes[node]["mates"]:
      if node < mate:
         dist += nodes[node]["mates"][mate]

print dist

# 
niter = 100000
maxLength = 5000

def unlink(a, b, d):
   d[a]["mates"].pop(b)
   if len(d[a]["mates"]) < 1:
      d.pop(a)
   d[b]["mates"].pop(a)
   if len(d[b]["mates"]) < 1:
      d.pop(b)

for i in xrange(1,niter):
   tmpnodes = copy.deepcopy(nodes)
   plan = []
   longest = 0
   while len(tmpnodes) > 0:
      currentNode = random.choice(tmpnodes.keys())
      totalLength = 0
      path = []
      while totalLength < maxLength:
         path.append(currentNode)
         if totalLength > longest: longest = totalLength
         if currentNode not in tmpnodes: break
         nextNode = random.choice(tmpnodes[currentNode]["mates"].keys())
         totalLength += tmpnodes[currentNode]["mates"][nextNode]
         if totalLength > maxLength: break
         unlink(currentNode, nextNode, tmpnodes)
         currentNode = nextNode
      plan.append(path)
   if len(plan) < 6:
      print len(plan),"\t",longest,"\t",plan
