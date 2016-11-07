#!/bin/bash

touch scoring.csv #creo un archivo para meter los resultados

echo 'Archivo PDBQT,Archivo MOL2 (1er pose), SMILES, Score (kcal/mol),Score (J/mol),pKb,MW,logP,TPSA,MR,HBA1,HBA2,HBD,Formula' > scoring.csv #estas seran las columnas
			#se pueden agregar más pero deberán corresponder a algún valor posterior
			#ya que sino el CSV no se va a leer bien

for o in out*.pdbqt

do

base=$(basename -s .pdbqt $o) #el nombre del archivo sin el .pdbqt

obabel -ipdbqt $o -omol2 -O ${base}.mol2 -l 1 #convertimos la primer pose a mol2 legible por todos

filescore=$(sed -n 2p $o) #scoring de la primer pose

score=$(echo $filescore | awk '{ print $4 }') #el valor del scoring

score_j=$(echo ${score}*4182 | bc) #el scoring en j/mol

pkb=$(echo ${score}*-1.36 | bc) #el pKb

# los descriptores más comunes se pueden calcular de la siguiente manera

# obabel archivo.mol2 -o txt --append <DESCRIPTOR>

#abonds    Number of aromatic bonds
#atoms    Number of atoms
#bonds    Number of bonds
#cansmi    Canonical SMILES
#cansmiNS    Canonical SMILES without isotopes or stereo
#dbonds    Number of double bonds
#formula    Chemical formula
#HBA1    Number of Hydrogen Bond Acceptors 1 (JoelLib)
#HBA2    Number of Hydrogen Bond Acceptors 2 (JoelLib)
#HBD    Number of Hydrogen Bond Donors (JoelLib)
#InChI    IUPAC InChI identifier
#InChIKey    InChIKey
#L5    Lipinski Rule of Five
#logP    octanol/water partition coefficient
#MR    molar refractivity
#MW    Molecular Weight filter
#nF    Number of Fluorine Atoms
#s    SMARTS filter
#sbonds    Number of single bonds
#smarts    SMARTS filter
#tbonds    Number of triple bonds
#title    For comparing a molecule's title
#TPSA    topological polar surface area

tpsa=$(obabel ${base}.mol2 -o txt --title "" --append TPSA)
logp=$(obabel ${base}.mol2 -o txt --title "" --append logP)
formula=$(obabel ${base}.mol2 -o txt --title "" --append formula)
mw=$(obabel ${base}.mol2 -o txt --title "" --append MW)
mr=$(obabel ${base}.mol2 -o txt --title "" --append MR)
hba1=$(obabel ${base}.mol2 -o txt --title "" --append HBA1)
hba2=$(obabel ${base}.mol2 -o txt --title "" --append HBA2)
hbd=$(obabel ${base}.mol2 -o txt --title "" --append HBD)
smiles=$(obabel ${base}.mol2 -o txt --title "" --append cansmi)

# Archivo PDBQT , Archivo MOL2 (1er pose), SMILES, Score (kcal/mol) , Score (J/mol) , pKb , MW , logP , TPSA , MR , HBA1 , HBA2 , HBD , Formula
echo " $o , ${base}.mol2 , $smiles , $score , $score_j , $pkb , $mw , $logp , $tpsa , $mr , $hba1 , $hba2 , $hbd , $formula " >> scoring.csv #pasar los datos al CSV

done

cat scoring.csv | sort -t, -k4 -n >> scoring_ord.csv #creamos un archivo con el dG ordenado,
													#lo convierto en otro archivo por si acaso



