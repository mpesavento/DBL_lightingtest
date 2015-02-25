# DBL_lightingtest
This holds the test code and accumulated info on getting preliminary lighting working for Dr. Brainlove 2.0

# folders and files

## module14_map
Take the 3 dimensional coordinates of each pixel and map that to pixel index for the arduino code

## dan_fullbrain_mapping
This contains a quick mapping from node coordinates of DBL1 (xyz coordinates) into pixel location

## node_info.csv
Contains the node coordinates and bar lengths from DBL 1.0. Not accurate for current module arrangements

## enetLEDTriangle51.ino
ethernet input to arduino, example from Sean

## reform_module.py
Code to parse node_info.csv data and select a subset of nodes, interpolating the number of pixels between each node and outputting the pixel coordinates in XYZ