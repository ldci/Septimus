Red [
	Title:   "Flir"
	Author:  "ldci"
	File: 	 %flir.red
	Needs:	 View
]

;-- Required files for Flir image processing
#include %default_exif.red 		;--for decoding Flir image

unless exists? %tmp [make-dir %tmp]

rgbimg: 	"tmp/rgb.jpg"		;--Flir embedded visible image
irimg: 		"tmp/irimg.png"		;--Linear corrected Grayscale IR image
palimg: 	"tmp/palette.png"	;--Flir palette
rawimg:		"tmp/rawimg.png"	;--Corrected linear raw temperatures
tempimg:	"tmp/celsius.pgm"	;--For temperature export 

OS:  system/platform
if any [OS = 'macOS OS = 'Linux] [exifTool: "/usr/local/bin/exiftool" convertTool: "/usr/local/bin/magick"] 
if any [OS = 'MSDOS OS = 'Windows][exifTool: "exiftool" convertTool: "magick"]
exifFile:  %tmp/exif.txt
exifFile2: %tmp/exif.red

;--get all Flir file metadata. This function must be called before extractFlirData
;--the function generate a Red file with all Flir informations
getFlirMetaData: func [
	fileName	[string!]
][
	prog: copy rejoin [exifTool " -php -flir:all -q " fileName " > " exifFile]
	ret: call/shell/wait prog			;--get Flir metadata
	var: read/lines exifFile
	n: length? var
	i: 2								;--create a Red file
	write/lines exifFile2 "Red ["
	write/lines/append exifFile2 "]"
	while [i < n] [
		str: trim/with var/:i ","
		ss: split str " => "
		s: trim ss/1
		s: trim/with s #"^""
		v: set to-word s ss/2 
		vs: rejoin [s ": " ss/2]
		write/lines/append exifFile2 vs	;write values in Red File
		i: i + 1
	]
]

;--all data we need. Values are coming from generated Red file (exifFile2.red) 
extractFlirData: func [
	fileName	[string!]
	tblock		[block!]
	return:		[integer!]
][
	str: 		copy  ReflectedApparentTemperature
	tmpREF: 	to-float trim/with str " C"
	RAWmax: 	RawValueMedian + (RawValueRange / 2)
	RAWmin: 	RAWmax - RawValueRange
	Kelvin: 	273.15
	returnVal:	0
	binstr: 	copy #{}
	clear tblock
	
	;--calculate the amount of radiance of reflected objects ( Emissivity < 1 )	
	;--formula decomposition for easier arguments 
	v0: PlanckB / (tmpREF + Kelvin)
	v1: exp v0
	v1: v1 - PlanckF 
	v2: (PlanckR2 * v1) 
	RAWrefl: (PlanckR1 / v2) - PlanckO

	;--raw object min/max temperatures
	em: 1.0 - Emissivity
	RAWmaxobj: RAWmax - (em * RAWrefl) / Emissivity
	RAWminobj: RAWmin - (em * RAWrefl) / Emissivity	

	;--min and max ° values as float
	v0: log-e (PlanckR1 / (PlanckR2 * (RAWminobj + PlanckO))+ PlanckF)
	imgMinTemp: (PlanckB / v0) - Kelvin
	v0: log-e (PlanckR1 / (PlanckR2 * (RAWmaxobj + PlanckO))+ PlanckF)
	imgMaxTemp: (PlanckB / v0) - Kelvin
	
	;--extract embedded visible image
	prog: rejoin [exifTool " -EmbeddedImage -b " fileName]
	ret: call/wait/output prog binstr
	switch EmbeddedImageType [ 
		"PNG"  [write/binary %tmp/rgb.png binstr rgbimg: form %tmp/rgb.png]
		"JPG"  [write/binary %tmp/rgb.jpg binstr rgbimg: form %tmp/rgb.jpg]
		"DAT"  [
			imgsize: as-pair EmbeddedImageWidth EmbeddedImageHeight
			img: make image! reduce [imgsize binstr]
			save %tmp/rgb.jpg img
			rgbimg: form %tmp/rgb.jpg
		]
	]
	returnVal: returnVal + ret
	
	;--extract color table, swap Cb Cr and expand pal color table from [16,235] to [0,255]			
	size: rejoin [form PaletteColors "x1"]
	prog:  rejoin [
		exifTool  " " fileName " -b -Palette" 
		" | " convertTool " -size " size 
		" -depth 8 YCbCr:- -separate -swap 1,2"
		" -set colorspace YCbCr -combine -colorspace RGB -auto-level " 
		palimg
	]
	
	
	ret: call/shell/wait prog 
	returnVal: returnVal + ret
	
	
	;--Get Flir RAW thermal data
	if RawThermalImageType = "TIFF" [
		prog: rejoin [
			exifTool " -RawThermalImage " fileName 
			" | " convertTool " " rawimg
		]
	]
	;16-bit PNG JPG OR DAT format: change byte order
	if RawThermalImageType <> "TIFF" [
		size: rejoin [form RawThermalImageWidth "x" form RawThermalImageHeight]
		prog: rejoin [
				exifTool " -b -RawThermalImage " fileName 
				" | " convertTool " - gray:- | " 
				convertTool " -depth 16 -endian msb -size " size " gray:- " 
				rawimg
			]
	]
	ret: call/shell/wait prog
	returnVal: returnVal + ret
	
	
	;convert every rawimg-16-Bit pixel with Planck law to a temperature grayscale value
	;--Planck Law
	sMax: PlanckB / log-e (PlanckR1 / (PlanckR2 * (RAWmax + PlanckO)) + PlanckF)
	sMin: PlanckB / log-e (PlanckR1 / (PlanckR2 * (RAWmin + PlanckO)) + PlanckF)
	;--we can also use values in metadata for recent camera
	;sMax: ImageTemperatureMax
	;sMin: ImageTemperatureMin
	sDelta: sMax - sMin
	
	;--string form for creating mathExp as argument for magick conversion
	R1: form PlanckR1
	R2: form PlanckR2
	B: 	form PlanckB
	O: form PlanckO
	F: form PlanckF
	ssMin: form sMin
	ssDelta: form sDelta
	mathExp: rejoin ["("B"/ln("R1"/("R2"*(65535*u+"O"))+"F")-"ssMin")/"ssDelta]
	;#"^"" for inserting " in convert argument
	prog: rejoin [convertTool " " rawimg " -fx " #"^"" mathExp #"^"" " " irimg]
	ret: call/shell/wait prog
	returnVal: returnVal + ret
	
	;--convert linear gray IR image to pgm format for temperature reading
	prog: rejoin [convertTool " " irimg " -compress none " tempimg]
	ret: call/shell/wait prog
	returnVal: returnVal + ret 
	
	;--export temperatures as float values in a block
	img: load to-file tempimg	;--a pgm image
	delta: imgMaxTemp - imgMinTemp
	colorMax: to-integer img/4 ; 65535 for 16-bit 255 for 8-bit
	n: length? img
	i: 5
	while [i <= n] [
		celsius: ((img/:i / colorMax) * delta) + imgMinTemp 
		append tblock celsius
		i: i + 1
	]
	returnVal
]
