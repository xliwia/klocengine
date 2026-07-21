{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    nim
    sdl3
    libx11
    libxext
    libxrandr
    libxinerama
    libxcursor
    libxi
    libGL
    libGLU
    freetype
    pkg-config
    git
  ];

  shellHook = ''
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:${pkgs.lib.makeLibraryPath [
      pkgs.sdl3
      pkgs.libGL
      pkgs.libx11
      pkgs.libxext
    ]}:$LD_LIBRARY_PATH"
    echo "kupadupa"
  '';
}