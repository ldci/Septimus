#!/usr/local/bin/red
Red [
	Title:   "Septimus for R2P2"
	Author:  "ldci"
	File: 	 %septimus.red
	Needs:	 View
]

#include %flir.red			;--Flir Tools (not requiring redCV)	

;--App directory
home: select list-env "HOME"
appDir: to-file rejoin [home "/Programmation/Red/Septimus/"]
change-dir to-file appDir

margins: 	5x5				;--for main window spacing
winBorder: 	5x66			;--for rect offset calculation				
rawStart: 	0x0				;--raw data start
rawEnd: 	80x60			;--raw data end	(C3 camera)				
flirFile: 	""				;--flir image file
tempBlk: copy []			;--image matrix temperatures
irSize: 640x480			 	;--default image size (C3 Camera)
w: 	irSize/x / 2 - 20		;--window size update 	 
padder: as-pair  w 70		;--for tmpV position
roiW: 128					;--default x size
roiH: 128					;--default y size
acolor: black				;--default color
rawW: 80					;--raw image width for C3 camera
rawH: 60					;--raw image height for C3 camera
ratio: 8					;--default ratio (640x480 / 80x60) for C3 camera
isFile?: false				;--patient file status


;--Draw Cross Block
crossSize: 41x41
cross: 	compose [
	line-width 2 pen (acolor) 
	box 0x0 40x40 
	line 20x0 20x15 line 20x25 20x40
	line 0x20 15x20 line 25x20 40x20
]

coldBox: compose [
	line-width 2 pen blue
	box 0x0 20x20 
	circle 10x10 5
]

hotBox: compose [
	line-width 2 pen red
	box 0x0 20x20 
	circle 10x10 5
]


loadImage:  does [
	tmpFile: request-file
	unless none? tmpFile [
		pTemp/offset: canvas1/offset					;--temperature cross position
		flirFile: form tmpFile							;--read Flir file
		getFlirMetaData flirFile						;--Flir metadata to red words and values
		do read exifFile2								;--informations we need from Flir
		extractFlirData flirFile tempBlk				;--Flir extracted temperatures from pgm image
		imgIR: load tmpFile								;--Flir image
		canvas1/image: imgIR							;--Flir orginal IR image
		imgRGB: load to-red-file rgbimg					;--embbeded RGB image
		canvas2/image: imgRGB							;--embbeded RGB image			
		clear canvas2/text								;--clear
		rawW: RawThermalImageWidth						;--x raw size
		rawH: RawThermalImageHeight						;--y raw size
		roiW: rect/size/x 								;--roi size x
		roiH: rect/size/y								;--roi size y
		ratio: irSize/x / rawW							;--update ratio value
		size1/text: form imgIR/size						;--IR image size
		imgRaw: load to-red-file irimg					;--raw data
		rgbw: EmbeddedImageWidth						;--rgb image width
		rgbh: EmbeddedImageHeight						;--rgb image height
		size2/text: form as-pair rgbw rgbh 				;--rgb image size
		size3/text: form as-pair rawW rawH				;--raw image size
		fratio/text: form ratio							;--show ratio
		cModel/text: CameraModel						;--camera type
		fw/text: form 0 fh/text: form 0					;--default values
		rect/offset: 0x0 + winBorder					;--ROI default offset 
		c/offset: rect/offset + rect/size				;--ROI default offset 
		pTemp/offset: tmpV/offset + 10x40				;--cross pointer position
		rect/visible?: c/visible?: pTemp/visible?: true	;--faces become visible
		;pCold/visible?: pHot/visible?: true				;--faces become visible
		tmpV/visible?: true
		tmpV/font/color: acolor							;--default color
		upDateClip										;--by default we process the whole raw image
		fho2/text: form as-pair rawW rawH				;--update
		clear sb/text									;--clear status bar
		isFile?: true									;--we have an IR file
		dp2/selected: 1									;--RGB by default
	]
]

upDateClip: func [] [
	fw/text: form RoiW 									;--ROI width
	fh/text: form RoiH									;--ROI height
	fwo/text: form rect/offset/x						;--ROI x offset in IR image
	fho/text: form rect/offset/y						;--ROI Y offset in IR image
	fwo2/text: form rawStart							;--ROI offset in Raw image 
	fho2/text: form rawEnd								;--ROI end in Raw image 
]

getSpots: func [
	imgPGM		[file!] ;--a pgm image
][
	f: load imgPGM
	ftype: f/1 rawW: f/2 rawH: f/3 cmax: f/4			;--read file information
	f: skip f 4											;--go to the first temperature measure
	hotSpot: 0											;--for hot value
	coldSpot: cmax										;--for cold	value
	posxy1: 0x0											;--default value
	posxy2: 0x0											;--default value
	idx1: idx2: i: 1									;--Red is one-based
	y: 0												;--now read pgm file data									
	while [y < rawH][
		x: 0
		while [x < rawW][
			pos: as-pair x y
			;--get temperature only in ROI	
			if all [pos/x > rawStart/x pos/y > rawStart/y pos/x < rawEnd/x pos/y < rawEnd/y][
				if f/:i > hotSpot [hotSpot: f/:i posxy1: pos idx1: i]
				if f/:i < coldSpot [coldSpot: f/:i posxy2: pos idx2: i]
			]
			i: i + 1
			x: x + 1
		]
		y: y + 1
	]
	
	pTemp/offset: (posxy1 * ratio) + canvas1/offset - 20	;--update cross offset
	tValue: round/to pick tempBlk idx1 0.01					;--get hot spot value
	tmpV/text: rejoin [form tValue "°"]						;--show hot spot value
	cValue: round/to pick tempBlk idx2 0.01					;--get cold value
	;pHot/offset:  (posxy1 * ratio) + canvas1/offset - 10	;--??
	;pCold/offset: (posxy2 * ratio) + canvas1/offset - 10	:--??	
	;--copy results to the clipboard
	result: rejoin [
		"Area offset: " form rect/offset " "
		"Area size: " form rect/size " "
		;"Position: " form pTemp/offset " " 
		"Cold spot: " cValue "° "
		"Hot spot : " tValue "°"
	]
	write-clipboard form result
	sb/text: result
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
	text 45  bold "Color"
	dp1: drop-down 70 data ["Black" "Red" "Green" "Blue" "Yellow" "White"]
		select 1
		on-change [acolor: reduce to-word pick face/data any [face/selected 1]
				r: aColor/1
				g: aColor/2
				b: aColor/3
				a: 128
				cross/4: acolor
				tcolor: to-tuple reduce [r g b a] 
				rect/color: c/color: tcolor
				tmpV/font/color: acolor
	]
	text 45 bold "Image"
	dp2: drop-down 60 data ["RGB" "RAW"]
	select 1
	on-change [
		if isfile? [
			switch face/selected [
				1 [canvas2/image: imgRGB]
				2 [canvas2/image: imgRaw]
			]
		]
	]
	button "Get Spots" 	[if isFile? [getSpots %tmp/celsius.pgm]]
	pCold: base  21x21 white loose draw coldBox 
	pHot:  base  21x21 white loose draw hotBox
	pad 25x0
	button "Quit" 			[Quit]
	return
	text  "Region of Interest"
	text 40 "Width" fw: field 40
	text 40 "Height" fh: field 40
	text 10 "X"  fwo: field 50
	text 10 "Y"  fho: field 50
	text "Start" 35 fwo2: field 60
	text "End" 30 fho2: field 60
	sb: base 640x22 white
	return
	canvas1: base irSize %septimus.jpg
	canvas2: base irSize green
	at canvas1/offset pTemp: base 255.255.255.240 crossSize loose draw cross
	on-drag [
	if isfile? [
		posct: (pTemp/offset - canvas1/offset) + 20 ;--pTemp/size / 2
		tValue: 0.0
		if all [posct/x >= 0 posct/y >= 0 posct/x <= irSize/x posct/y <= irSize/y][	
			;--to find temperature in the smaller raw image
			posc: posct / ratio							;--coordinates in raw image
			rpos: as-pair posc/x posc/y					;--coordinates in raw image as pair
			idx: to integer! (rpos/y * rawW + rpos/x)	;--index as integer
			tValue: round/to pick tempBlk idx 0.01		;--temperature value
		]
		tmpV/text: rejoin [form tValue "°"]]
	]
	
	at padder tmpV: h2 150 "0.0°" react [face/font/color: acolor]
	at canvas1/offset + winBorder
	rect: base 128x128 0.0.0.200 loose on-drag [
		roffset: rect/offset - canvas1/offset
		if all [roffset/x >= 0 roffset/y >= 0 roffset/x <= irSize/x roffset/y <= irSize/y][
			pstart: roffset / ratio 					;--starting box in raw image
			rawStart: as-pair pstart/x pstart/y			;--starting box in raw image as pair
			pend: (roffset + rect/size) / ratio			;--ending box in raw image
			rawEnd: as-pair pend/x pend/y				;--ending box in raw imageas pair
			roiW: to-integer rect/size/x				;--ROI width (IR image)
			roiH: to-integer rect/size/Y 				;--ROI height (IR image)
			upDateClip									;--Update information
			c/offset: rect/offset + rect/size			;--c offset 
		]
	] 	
	at (rect/offset + rect/size) 
	c: base 10x10 acolor loose on-drag [
		rect/size: c/offset - rect/offset 
		roiW: to-integer rect/size/x
		roiH: to-integer rect/size/Y 
		upDateClip
	]
	do [
		fw/text: form 0 fh/text: form 0 
		fwo/text: form 0 fho/text: form 0 
		fwo2/text: form 0x0
		fho2/text: form 0x0
		rect/visible?: c/visible?: pTemp/visible?: false
		pCold/visible?: pHot/visible?: true
		tmpV/visible?: false
		canvas2/text: "Please, load a patient image"
	]
]
view mainWin