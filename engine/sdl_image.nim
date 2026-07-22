{.passL: "-lSDL3_image".}

import sdl3

proc IMG_Load*(file: cstring): ptr SDL_Surface
  {.cdecl, importc: "IMG_Load".}