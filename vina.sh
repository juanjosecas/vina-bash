#!/bin/bash

for file in lig*.pdbqt
 do
	base=$(basename -s .pdbqt $file)
	vina --config config.txt --ligand $file --out out_${base}.pdbqt 
done	

