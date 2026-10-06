# Picture formats of ETH Oberon, for polpo

The picture converters of Native Oberon 2.3.6 for `Pictures`, without Gadgets: each one is a
portia package, and `Pictures.Open` finds it through the PictureConverters section of
`Oberon.Text` (polpo's lists them already). View the pictures with Iris
(https://github.com/polpo-system/iris).

    package       modules              reads
    gif           GIF                  GIF
    jpeg          JPEG (bit)           baseline JPEG, up to 4096 pixels wide and high
    bmp           BMP                  BMP with a palette (1, 4, 8 bits, RLE)
    tga           TGA                  Targa: colour mapped, true colour (15/16/24/32 bits),
                                       grey, plain and run length encoded
    pcx           PCX (bit)            PCX up to 256 colours
    ico           ICO (bit)            Windows icons (even sizes)
    iff           IFF (bit)            Amiga IFF ILBM
    xpm           XPM (colormodels)    X pixmaps
    bit           BIT                  bit operations on CHAR, INTEGER, LONGINT
    colormodels   ColorModels          RGB, HSV and CMY conversions

Pictures have 256 colours of the display palette: the converters map the colours of the files
to the nearest ones (JPEG dithers).

## Changes for polpo

  * TGA: loading rewritten. Before only 8 bit images loaded, and their palette indices were
    taken as display colours; now the colours are mapped to the display palette as in BMP,
    true colour and run length encoding work for all types, and the row order of the
    descriptor is followed (top to bottom images were upside down).
  * JPEG: JPEGMAXDIMENSION 4096 instead of 1024 ("image too large" for most photos).
  * BIT: ISWAP and LSWAP with shifts; SYSTEM.VAL of a value to an array type did not compile
    with the RISC-V and MIPS compilers.
  * XPM: the methods of its Rider take a base record; the ARM compiler does not accept a
    record with procedure fields of its own type.
  * PCX: true colour PCX files are refused instead of trapping.

GIF, BMP, ICO, IFF and ColorModels are unchanged. PPM and XBM are not here: they need
Documents and Display3 of the Gadgets system.

`test/`: a sample of each format (except IFF) and `PictTest.Open file width height`, the
test of the packages (needs the desktop).

The license is the one of ETH Oberon: see `LICENSE`.
