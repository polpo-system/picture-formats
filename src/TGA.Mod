(* OBERON System 3, Release 2.3.

Copyright 1999 ETH Zrich Institute for Computer Systems,
ETH Center, CH-8092 Zrich. e-mail: oberon@inf.ethz.ch.

This module may be used under the conditions of the general Oberon
System 3 license contract. The full text can be downloaded from

	"ftp://ftp.inf.ethz.ch/pub/software/Oberon/System3/license.txt;A"

Under the license terms stated it is in particular (a) prohibited to modify
the interface of this module in any way that disagrees with the style
or content of the system and (b) requested to provide all conversions
of the source code to another platform with the name OBERON. *)

MODULE TGA;	(** portable *)
(*
	JJ 02.03.95	Original Version of Jack Johnson's Targa
	PM 25.10.95	System 3 / DOS/PC-Oberon version
	PM 12.04.96	renamed to PictureTools, added StoreTGA
	IW  22.10.96	changed Interface for PictureConverters, removed StoreTGA
	polpo 2026-10-06	loading rewritten: the colours mapped to the display palette (as BMP does),
		true colour (15, 16, 24, 32 bits), run length encoding for all types (9, 10, 11), and
		the row order of the descriptor (top to bottom when bit 5 is set); before only 8 bit
		images loaded, with their palette indices taken as display colours
*)

IMPORT Display, Files, Objects, Out, Pictures;

CONST CacheSize = 4096;

TYPE
	Header = RECORD
		IDlength: CHAR;
		cmap, type: SHORTINT;
		cmaporigin, cmaplength: INTEGER;
		csize: SHORTINT;
		xorigin, yorigin, width, height: INTEGER;
		depth, descriptor: SHORTINT;
	END;

VAR
	r, g, b: ARRAY 256 OF INTEGER;  (* the display palette *)
	nColors: INTEGER;
	map: ARRAY 256 OF INTEGER;  (* of a colour mapped image: palette entry -> display colour *)
	cacheKey: ARRAY CacheSize OF LONGINT;  (* RGB + 1, 0 for empty *)
	cacheCol: ARRAY CacheSize OF INTEGER;

(* the display colour nearest to red, green, blue (the measure of BMP) *)
PROCEDURE Nearest(red, green, blue: INTEGER): INTEGER;
VAR j, minj: INTEGER; x, y, z, d, min: LONGINT;
BEGIN
	min := MAX(LONGINT); minj := 0; j := 0;
	WHILE j < nColors DO
		x := ABS(red - r[j]); y := ABS(green - g[j]); z := ABS(blue - b[j]);
		d := x; IF y > d THEN d := y END; IF z > d THEN d := z END;
		d := d*d + (x*x + y*y + z*z);
		IF d < min THEN min := d; minj := j END;
		INC(j)
	END;
	RETURN minj
END Nearest;

(* Nearest, through a cache of the colours met *)
PROCEDURE Col(red, green, blue: INTEGER): INTEGER;
VAR key: LONGINT; h: INTEGER;
BEGIN
	key := (LONG(red) * 256 + green) * 256 + blue + 1;
	h := SHORT((key * 7 + key DIV 4096) MOD CacheSize);
	IF cacheKey[h] # key THEN cacheKey[h] := key; cacheCol[h] := Nearest(red, green, blue) END;
	RETURN cacheCol[h]
END Col;

PROCEDURE InitColors;
VAR i: INTEGER;
BEGIN
	nColors := SHORT(ASH(1, Display.Depth(0)));
	IF (nColors > 256) OR (nColors <= 0) THEN nColors := 256 END;
	i := 0; WHILE i < nColors DO Display.GetColor(i, r[i], g[i], b[i]); INC(i) END;
	i := 0; WHILE i < CacheSize DO cacheKey[i] := 0; INC(i) END
END InitColors;

PROCEDURE GetTgaHeader( VAR R: Files.Rider; VAR H: Header): BOOLEAN;
VAR string: ARRAY 256 OF CHAR; t: INTEGER;
BEGIN
	IF Files.Length(Files.Base(R)) < 18 THEN RETURN FALSE END;
	Files.Read(R, H.IDlength); Files.Read(R, H.cmap); Files.Read(R, H.type);
	Files.ReadInt(R, H.cmaporigin); Files.ReadInt(R, H.cmaplength);
	Files.Read(R, H.csize);
	Files.ReadInt(R, H.xorigin); Files.ReadInt(R, H.yorigin);
	Files.ReadInt(R, H.width); Files.ReadInt(R, H.height);
	Files.Read(R, H.depth); Files.Read( R, H.descriptor);
	t := H.type MOD 8;  (* 9, 10, 11: run length encoded 1, 2, 3 *)
	IF (H.type # t) & (H.type # t + 8) OR (t < 1) OR (t > 3) OR (H.width <= 0) OR (H.height <= 0) THEN RETURN FALSE END;
	IF (t = 1) & ((H.depth # 8) OR (H.cmap # 1) OR (H.cmaplength > 256) OR (H.csize # 24) & (H.csize # 32) & (H.csize # 15) & (H.csize # 16))
		OR (t = 2) & (H.depth # 15) & (H.depth # 16) & (H.depth # 24) & (H.depth # 32)
		OR (t = 3) & (H.depth # 8) THEN
		Out.String("Targa: unsupported type "); Out.Int(H.type, 0); Out.String(", depth "); Out.Int(H.depth, 0); Out.Ln;
		RETURN FALSE
	END;
	Files.ReadBytes( R, string, ORD(H.IDlength));
	Out.String("Targa type "); Out.Int(H.type, 0); Out.String(", "); Out.Int(H.width, 0); Out.String(" by ");
	Out.Int(H.height, 0); Out.String(", "); Out.Int(H.depth, 0); Out.String(" bits"); Out.Ln;
	RETURN TRUE
END GetTgaHeader;

(* a colour of bits size (15, 16, 24, 32: BGR, BGRA, 5-5-5) *)
PROCEDURE ReadRGB(VAR R: Files.Rider; size: INTEGER; VAR red, green, blue: INTEGER);
VAR c0, c1, c2, c3: CHAR; v: LONGINT;
BEGIN
	IF size <= 16 THEN
		Files.Read(R, c0); Files.Read(R, c1); v := ORD(c0) + LONG(ORD(c1)) * 256;
		blue := SHORT(v MOD 32 * 255 DIV 31); green := SHORT(v DIV 32 MOD 32 * 255 DIV 31); red := SHORT(v DIV 1024 MOD 32 * 255 DIV 31)
	ELSE
		Files.Read(R, c0); Files.Read(R, c1); Files.Read(R, c2); IF size = 32 THEN Files.Read(R, c3) END;
		blue := ORD(c0); green := ORD(c1); red := ORD(c2)
	END
END ReadRGB;

PROCEDURE GetPalette( VAR R: Files.Rider; P: Pictures.Picture; VAR H: Header);
VAR i, red, green, blue: INTEGER;
BEGIN
	i := 0; WHILE i < 256 DO map[i] := 0; INC(i) END;
	IF H.type MOD 8 = 1 THEN
		i := H.cmaporigin;
		WHILE i < H.cmaporigin + H.cmaplength DO
			ReadRGB(R, H.csize, red, green, blue);
			IF i < 256 THEN map[i] := Col(red, green, blue) END;
			INC(i)
		END
	ELSE  (* grey *)
		i := 0; WHILE i < 256 DO map[i] := Col(i, i, i); INC(i) END
	END
END GetPalette;

(* the display colour of the next pixel *)
PROCEDURE ReadPixel(VAR R: Files.Rider; VAR H: Header): INTEGER;
VAR c: CHAR; red, green, blue: INTEGER;
BEGIN
	IF H.type MOD 8 = 2 THEN ReadRGB(R, H.depth, red, green, blue); RETURN Col(red, green, blue)
	ELSE Files.Read(R, c); RETURN map[ORD(c)]
	END
END ReadPixel;

PROCEDURE LoadTga(VAR R: Files.Rider; colorConversion: BOOLEAN; P: Pictures.Picture);
VAR H: Header; pos: LONGINT; x, y, n, col: INTEGER; packet: CHAR; rle, run, down: BOOLEAN;

	PROCEDURE Put;  (* col at x, y; to the next pixel *)
	BEGIN
		IF down THEN Pictures.Dot(P, col, x, P.height - 1 - y, Display.replace) ELSE Pictures.Dot(P, col, x, y, Display.replace) END;
		INC(x); IF x = P.width THEN x := 0; INC(y) END
	END Put;

BEGIN
	pos := Files.Pos(R);
	IF GetTgaHeader( R, H) THEN
		InitColors;
		Pictures.Create( P, H.width, H.height, 8);
		n := 0; WHILE n < nColors DO Pictures.SetColor(P, n, r[n], g[n], b[n]); INC(n) END;
		IF H.cmap = 1 THEN GetPalette(R, P, H)
		ELSIF H.type MOD 8 = 3 THEN GetPalette(R, P, H)
		END;
		rle := H.type > 8; down := ODD(H.descriptor MOD 256 DIV 32);  (* bit 5: the first row is the top one *)
		x := 0; y := 0;
		WHILE (y < P.height) & ~R.eof DO
			IF rle THEN
				Files.Read(R, packet); n := ORD(packet) MOD 128 + 1; run := ORD(packet) >= 128;
				IF run THEN col := ReadPixel(R, H); WHILE (n > 0) & (y < P.height) DO Put; DEC(n) END
				ELSE WHILE (n > 0) & (y < P.height) & ~R.eof DO col := ReadPixel(R, H); Put; DEC(n) END
				END
			ELSE col := ReadPixel(R, H); Put
			END
		END
	ELSE Files.Set(R, Files.Base(R), pos)
	END
END LoadTga;

PROCEDURE Handle*(obj: Objects.Object; VAR msg: Objects.ObjMsg);
VAR
	pos: LONGINT;
BEGIN
	WITH obj: Pictures.Picture DO
		IF msg IS Objects.AttrMsg THEN
			WITH msg: Objects.AttrMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Gen") THEN
					msg.class:= Objects.String; COPY("Pictures.NewPicture",msg.s); msg.res:=0
				END;
			END;
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF (msg.id = Objects.load) THEN
					pos:= Files.Pos(msg.R);
					LoadTga(msg.R,TRUE,obj); msg.len:= Files.Pos(msg.R) - pos;
				ELSE
					Pictures.Handle(obj,msg)
				END;
			END;
		ELSE
			Pictures.Handle(obj, msg)
		END;
	END;
END Handle;

(** Called from Pictures.Open to try and load a Targa picture. The picture descriptor is pre-allocated by Pictures in
Objects.NewObj. InitPicture overwrites the handler of the picture with a new handler that will load the
Targa picture when a FileMsg is received (variant load). *)
PROCEDURE InitPicture*;
BEGIN
	Objects.NewObj.handle:= Handle;
END InitPicture;

PROCEDURE NewPicture*;
VAR
	P: Pictures.Picture;
BEGIN
	NEW(P); P.handle:= Handle; Objects.NewObj:= P;
END NewPicture;

END TGA.

Targa file types:

       0  -  No image data included.
       1  -  Uncompressed, color-mapped images.
       2  -  Uncompressed, RGB images.
       3  -  Uncompressed, black and white images.
       9  -  Runlength encoded color-mapped images.
      10  -  Runlength encoded RGB images.
      11  -  Compressed, black and white images.
