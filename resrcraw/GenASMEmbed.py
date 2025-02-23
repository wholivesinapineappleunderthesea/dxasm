import os
import sys
import re

# recursive glob all .bin files in ..\resrc
binfilepaths = []
for root, dirs, files in os.walk('../resrc'):
	for file in files:
		if file.endswith('.bin'):
			binfilepaths.append(os.path.join(root, file))

# open asm file
asmfile = open('../src/resrc.asm', 'w')
asmfile.write(".CONST\n")
incfile = open('../src/resrc.inc', 'w')

for binfilepath in binfilepaths:
	binfile = open(binfilepath, 'rb')
	# replace all instances of \ with __
	binfilename = binfilepath.replace('\\', '__')
	# replace all instances of / with __
	binfilename = binfilename.replace('/', '__')
	# replace all instances of . with _
	binfilename = binfilename.replace('.', '_')
	# remove prefix _ characters
	binfilename = re.sub(r'^_+', '', binfilename)
	print(binfilename + " -> " + binfilepath)

	# read all bytes from bin file
	binbytes = binfile.read()

	# ex : EXTERN binfilename:BYTE
	incfile.write("EXTERN " + binfilename + ":BYTE\n")
	# ex : binfilename_SIZE EQU 0999h
	incfile.write(binfilename + "_SIZE EQU " + str(len(binbytes)) + "\n")

	

	# write byte constant to asm file
	# every 16 bytes, do a newline to get around the limit in masm
	# binfilename BYTE 0ffh, 012h, 044h
	# BYTE 091h, 0a2h, 0b3h
	# BYTE 0c4h, 0d5h, 0e6h
	asmfile.write(binfilename + " ")
	for i in range(0, len(binbytes), 16):
		asmfile.write("BYTE ")
		for j in range(i, min(i+16, len(binbytes))):
			asmfile.write("0" + format(binbytes[j], '02x') + "h")
			if j < min(i+16, len(binbytes)) - 1:
				asmfile.write(", ")
		asmfile.write("\n")
	
	binfile.close()

asmfile.write("\nEND")
asmfile.close()
incfile.close()