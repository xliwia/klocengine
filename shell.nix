{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    nim
    SDL3
    xorg.libX11
    xorg.libXext
    xorg.libXrandr
    xorg.libXinerama
    xorg.libXcursor
    xorg.libXi
    libGL
    libGLU
    pkg-config
    git
  ];

  shellHook = ''
    export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
      pkgs.SDL3
      pkgs.libGL
      pkgs.xorg.libX11
      pkgs.xorg.libXext
    ]}
    echo "kupadupa"
  '';
}
