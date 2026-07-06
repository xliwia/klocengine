import std/os

if existsEnv("NIM_CFLAGS"):
  switch("passC", getEnv("NIM_CFLAGS"))
