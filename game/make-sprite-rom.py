import sys

readingPalette = True
inSprite = False
paletteKey = {}
palette = [0 for x in range(16)]
currentSprite = []
sprites = []

for line in open(sys.argv[1]):
	if not line.strip():
		# Empty line
		readingPalette = False
		if inSprite:
			sprites += [ currentSprite ]
			currentSprite = []
			inSprite = False
	else:
		if readingPalette:
			ch, r, g, b = line.split()
			palette[len(paletteKey)] = ((int(r) & 15) << 8) | ((int(g) & 15) << 4) | (int(b) & 15)
			paletteKey[ch] = len(paletteKey)
		else:
			inSprite = True
			for ch in line.strip():
				currentSprite += [ paletteKey[ch] ]

if inSprite:
	sprites += [ currentSprite ]

# Write the palette file
f = open('palette.hex', 'w')
for x in palette:
	f.write('%03x\n' % x)

f.close()

# Write the sprites file
f = open('sprites.hex', 'w')
for sp in sprites:
	for val in sp:
		f.write('%x\n' % val)

f.close()
