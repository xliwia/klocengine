{.passL: "-lSDL3_mixer".}

const
  SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK* = 0xFFFFFFFF'u32

type
  MIX_Mixer* = object
  MIX_Audio* = object
  MIX_Track* = object


proc MIX_Init*(flags: uint32): bool
  {.cdecl, importc: "MIX_Init".}

proc MIX_CreateMixerDevice*(device: uint32, spec: pointer): ptr MIX_Mixer
  {.cdecl, importc: "MIX_CreateMixerDevice".}

proc MIX_DestroyMixer*(mixer: ptr MIX_Mixer)
  {.cdecl, importc: "MIX_DestroyMixer".}

proc MIX_LoadAudio*(mixer: ptr MIX_Mixer, file: cstring, predecode: bool): ptr MIX_Audio
  {.cdecl, importc: "MIX_LoadAudio".}

proc MIX_DestroyAudio*(audio: ptr MIX_Audio)
  {.cdecl, importc: "MIX_DestroyAudio".}

proc MIX_CreateTrack*(mixer: ptr MIX_Mixer): ptr MIX_Track
  {.cdecl, importc: "MIX_CreateTrack".}

proc MIX_SetTrackAudio*(track: ptr MIX_Track, audio: ptr MIX_Audio): bool
  {.cdecl, importc: "MIX_SetTrackAudio".}

proc MIX_SetTrackLoops*(track: ptr MIX_Track, loops: int32): bool
  {.cdecl, importc: "MIX_SetTrackLoops".}

proc MIX_PlayTrack*(track: ptr MIX_Track, loops: int32): bool
  {.cdecl, importc: "MIX_PlayTrack".}

proc MIX_StopTrack*(track: ptr MIX_Track, fadeMs: int32): bool
  {.cdecl, importc: "MIX_StopTrack".}


var mixer*: ptr MIX_Mixer = nil

# music
var musicTrack*: ptr MIX_Track = nil
var currentAudio*: ptr MIX_Audio = nil

# voice
var voiceTrack*: ptr MIX_Track = nil
var voiceAudio*: ptr MIX_Audio = nil


proc initAudio*() =
  echo "initializing audio"

  if not MIX_Init(0):
    echo "FAILED: MIX_Init"
    return

  echo "MIX_Init ok"

  mixer = MIX_CreateMixerDevice(
    SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK,
    nil
  )

  if mixer == nil:
    echo "FAILED: MIX_CreateMixer"
    return

  echo "mixer ok"


  musicTrack = MIX_CreateTrack(mixer)

  if musicTrack == nil:
    echo "FAILED: music track"
    return


  voiceTrack = MIX_CreateTrack(mixer)

  if voiceTrack == nil:
    echo "FAILED: voice track"
    return


  echo "audio ready"



proc playMusic*(file: string) =

  if mixer == nil or musicTrack == nil:
    echo "audio not initialized"
    return


  if currentAudio != nil:
    discard MIX_StopTrack(musicTrack, 300)
    MIX_DestroyAudio(currentAudio)
    currentAudio = nil


  echo "playing music: ", file


  currentAudio = MIX_LoadAudio(
    mixer,
    cstring(file),
    false
  )


  if currentAudio == nil:
    echo "FAILED loading music"
    return


  discard MIX_SetTrackAudio(
    musicTrack,
    currentAudio
  )

  discard MIX_SetTrackLoops(
    musicTrack,
    -1
  )

  discard MIX_PlayTrack(
    musicTrack,
    -1
  )


proc stopMusic*() =

  if musicTrack != nil:
    echo "stopping music"
    discard MIX_StopTrack(
      musicTrack,
      500
    )



proc playVoice*(file: string) =

  if mixer == nil or voiceTrack == nil:
    echo "voice unavailable"
    return


  if voiceAudio != nil:
    discard MIX_StopTrack(
      voiceTrack,
      0
    )

    MIX_DestroyAudio(
      voiceAudio
    )

    voiceAudio = nil


  echo "playing voice: ", file


  voiceAudio = MIX_LoadAudio(
    mixer,
    cstring(file),
    false
  )


  if voiceAudio == nil:
    echo "FAILED loading voice"
    return


  discard MIX_SetTrackAudio(
    voiceTrack,
    voiceAudio
  )


  discard MIX_PlayTrack(
    voiceTrack,
    0
  )