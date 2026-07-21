# engine/font_ft.nim
{.passC: staticExec("pkg-config --cflags freetype2").}
{.passL: staticExec("pkg-config --libs freetype2").}
{.compile: "font_ft.c".}

proc font_load*(path: cstring, size: cint): pointer {.importc: "font_load".}
proc font_free*(handle: pointer) {.importc: "font_free".}
proc font_free_pixels*(pixels: pointer) {.importc: "font_free_pixels".}
proc font_text_width*(handle: pointer, text: cstring, scale: cfloat): cint {.importc: "font_text_width".}
proc font_render_text*(handle: pointer, text: cstring, scale: cfloat, outW: ptr cint, outH: ptr cint): pointer {.importc: "font_render_text".}