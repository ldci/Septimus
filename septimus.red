#!/usr/local/bin/red
Red [
	Title:   "Septimus for R2P2"
	Author:  "ldci"
	File: 	 %septimus.red
	Needs:	 View
]

;--Flir Tools (not requiring redCV)
#include %flir.red	

;--App directory
home: select list-env "HOME"
appDir: to-file rejoin [home "/Programmation/Red/Septimus/"]
change-dir to-file appDir

margins: 	5x5
winBorder: 5x66				;--for rect calculation				
rawStart: 0x0				;--raw data start
rawEnd: 80x60				;--raw data end	(C3 camera)				
flirFile: 	""				;--flir image file
tempBlk: copy []			;--image matrix temperatures
irSize: 640x480			 	;--default image size (C3 Camera)
w: 	irSize/x / 2 - 20		;--window size update 	 
padder: as-pair  w 70		;--idem
roiW: 128					;--default x size
roiH: 128					;--default y size
acolor: black				;--default color

;--Draw block
drawCross: 	compose [
	line-width 2 pen (acolor) 
	box 0x0 40x40 
	line 20x0 20x15 line 20x25 20x40
	line 0x20 15x20 line 25x20 40x20
]

;--for hot spot
rawW: 80					;--raw image width
rawH: 60					;--raw image height
nPixels: rawW * rawH		;--raw image size
ratio: 8					;--default ratio (640x480 / 80x60)
isFile?: false				;--patient file status


loadImage:  does [
	tmpFile: request-file
	unless none? tmpFile [
		p1/offset: canvas1/offset						;--Temperature cross position
		flirFile: form tmpFile							;--Read Flir file
		getFlirMetaData flirFile						;--Flir metadata to red words and values
		do read exifFile2								;--Informations we need
		clear tempBlk									;--clear temperatures block 
		extractFlirData flirFile tempBlk				;--Flir extracted temperatures from pgm image
		imgIR: load tmpFile								;--Flir image
		canvas1/image: imgIR							;--Flir orginal IR image
		canvas2/image: load to-file rgbimg				;--Embbeded RGB image
		clear canvas2/text								;--no more comment
		rawW: RawThermalImageWidth						;--x raw size
		rawH: RawThermalImageHeight						;--y raw size
		roiW: rect/size/x 								;--Roi size
		roiH: rect/size/y								;--Roi size
		nPixels: rawW * rawH							;--Raw image size
		ratio: irSize/x / rawW							;--Update ratio value
		size1/text: form imgIR/size						;--IR image size
		size2/text: form as-pair EmbeddedImageWidth EmbeddedImageHeight ;--RGB image size
		size3/text: form as-pair rawW rawH				;--Raw image size
		fratio/text: form ratio							;--Show ratio
		cModel/text: CameraModel						;--Camera type
		fw/text: form 0 fh/text: form 0					;--default values
		rect/offset: 0x0 + winBorder					;--ROI default offset 
		c/offset: rect/offset + rect/size				;--ROI default offset 
		rect/visible?: c/visible?: p1/visible?: true	;--faces become visible
		tmpV/visible?: true								;--faces become visible
		tmpV/font/color: acolor							;--default color
		upDateClip										;--by default we process the whole raw image
		fho2/text: form as-pair rawW rawH				;--Update
		isFile?: true									;--We have an IR file
	]
]


upDateClip: func [] [
	fw/text: form RoiW 									;--ROI width
	fh/text: form RoiW									;--ROI height
	fwo/text: form rect/offset/x						;--ROI x offset in IR image
	fho/text: form rect/offset/y						;--ROI Y offset in IR image
	fwo2/text: form rawStart							;--ROI offset in Raw image 
	fho2/text: form rawEnd								;--ROI end in Raw image 
]


getHotSpot: func [
	imgPGM		[file!] ;--a pgm image
][
	f: load imgPGM
	n: length? f
	hotSpot: 0
	posxy: 0x0
	rawW: f/2 rawH: f/3 cmax: f/4
	f: skip f 4
	idx: 1 y: 0 i: 1
	while [y < rawH][
		x: 0
		while [x < rawW][
			pos: as-pair x y	
			if all [pos/x > rawStart/x pos/y > rawStart/y pos/x < rawEnd/x pos/y < rawEnd/y][
				if f/:i > hotSpot [hotSpot: f/:i posxy: pos idx: i]
			]
			i: i + 1
			x: x + 1
		]
		y: y + 1
	]
	p1/offset: posxy * ratio + canvas1/offset - 20
	tValue: round/to pick tempBlk idx 0.01
	tmpV/text: form tValue
]

;**************************** Main Program *****************************
mainWin: layout [
	title "R2P2: Septimus [All Flir cameras]"
	origin margins space margins
	button "Load Patient Image"		[loadImage]
	cModel: base 100x23 white 
	text 30 bold "IR "  	size1: base 100x23 white 
	text 50 bold "Visible"  size2: base 100x23 white
	text 40 bold "Raw"  	size3: base 100x23 white
	text 40 bold "Ratio"  	fratio: base 50x23 white
	text 45 "Color"
	dp2: drop-down 70 data ["Black" "Red" "Green" "Blue" "Yellow" "White"]
		select 1
		on-change [acolor: reduce to-word pick face/data any [face/selected 1]
				drawCross/4: acolor
				r: aColor/1
				g: aColor/2
				b: aColor/3
				a: 128
				tcolor: to-tuple reduce [r g b a] 
				rect/color: c/color: tcolor
				tmpV/font/color: acolor
	]
	button "Get Hot Spot" 	[if isFile? [getHotSpot %tmp/celsius.pgm]]
	pad 170x0
	button "Quit" 			[Quit]
	return
	text 35 "ROI"
	text 40 "Width"
	fw: field 40
	text 40 "Height"
	fh: field 40
	text 10 "X"  fwo: field 50
	text 10 "Y"  fho: field 50
	text "Start" 50 fwo2: field 70
	text "End" 50 fho2: field 70
	
	return
	canvas1: base irSize %septimus.jpg
	canvas2: base irSize white
	at canvas1/offset p1: base 255.255.255.240 41x41 loose draw drawCross
	on-drag [
	if isfile? [
		posct: (p1/offset - canvas1/offset) + 20 ;--20x20
		tValue: 0.0
		if all [posct/x >= 0 posct/y >= 0 posct/x <= irSize/x posct/y <= irSize/y][	
			;--to find temperature in the smaller raw image
			posc: posct / ratio
			rpos: as-pair posc/x posc/y					;--coordinates in raw image
			idx: to integer! (rpos/y * rawW + rpos/x)	;--index as integer
			tValue: round/to pick tempBlk idx 0.01		;--temperature value
		]
		tmpV/text: form tValue
	]]
	at padder tmpV: h2 150 "0.0 °" react [face/font/color: acolor]
	at canvas1/offset + winBorder 
	rect: base 128x128 0.0.0.200 loose on-drag [
		roffset: rect/offset - canvas1/offset
		if all [roffset/x >= 0 roffset/y >= 0 roffset/x <= irSize/x roffset/y <= irSize/y][
			start: roffset; rect/offset - winBorder
			pstart: start / ratio 
			rawStart: as-pair pstart/x pstart/y
			pend: (start + rect/size) / ratio
			rawEnd: as-pair pend/x pend/y
			c/offset: rect/offset + rect/size 
			roiW: to-integer roiW rect/size/x
			roiH: to-integer rect/size/Y 
			upDateClip
		]
	] 
	
	at (rect/offset + rect/size) 
	c: base 10x10 acolor loose on-drag [
		rect/size: (c/offset - rect/offset) 
		roiW: to-integer rect/size/x
		roiH: to-integer rect/size/Y 
		upDateClip
	]
	
	do [
		fw/text: form 0 fh/text: form 0 
		fwo/text: form 0 fho/text: form 0 
		fwo2/text: form 0x0
		fho2/text: form 0x0
		rect/visible?: c/visible?: p1/visible?: false
		tmpV/visible?: false
		canvas2/text: "Load Patient Image"
	]
]
view mainWin