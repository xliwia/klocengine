# main.nim
import sdl3
import engine/[game, renderer, input, animation]
import std/[json, os]

type
  Stage = object
    kind: string
    file: string

var stages: seq[Stage]
var stageIndex = 0
var onComplete = "stop"

const skipBtnW: float32 = 120
const skipBtnH: float32 = 36
var skipBtnX, skipBtnY: float32

proc loadInitConfig(path: string): tuple[w, h: int32, title: string] =
  var w: int32 = 1280
  var h: int32 = 720
  var title = "kloc"
  if fileExists(path):
    let data = parseFile(path)
    if data.hasKey("window"):
      let win = data["window"]
      if win.hasKey("width"): w = int32(win["width"].getInt)
      if win.hasKey("height"): h = int32(win["height"].getInt)
      if win.hasKey("title"): title = win["title"].getStr
    if data.hasKey("onComplete"):
      onComplete = data["onComplete"].getStr
    if data.hasKey("sequence"):
      for s in data["sequence"]:
        stages.add Stage(kind: s["type"].getStr, file: s["file"].getStr)
  return (w, h, title)

proc loadStage(game: var Game, renderer: SDL_Renderer, kind, file: string) =
  case kind
  of "storyline":
    echo "attempting to load ", file
    loadStorylineStage(game, "game/" & file, renderer)
  of "freetime":
    echo "attempting to load ", file
    loadFreetimeStage(game, "game/" & file, renderer)
  of "vn":
    echo "attempting to load vn scene ", file
    loadVNStage(game, "game/" & file, renderer)
  of "menu":
    echo "attempting to load menu ", file
    loadMenuStage(game, "game/" & file, renderer)
  else:
    discard

proc loadCurrentStage(game: var Game, renderer: SDL_Renderer) =
  if stageIndex < 0 or stageIndex >= stages.len: return
  let stage = stages[stageIndex]
  loadStage(game, renderer, stage.kind, stage.file)

proc advanceStage(game: var Game, renderer: SDL_Renderer) =
  if game.pendingStageFile.len > 0:
    let kind = if game.pendingStageKind.len > 0: game.pendingStageKind else: "vn"
    let file = game.pendingStageFile
    game.pendingStageFile = ""
    game.pendingStageKind = ""
    loadStage(game, renderer, kind, file)
    return

  stageIndex.inc
  if stageIndex >= stages.len:
    if onComplete == "loop":
      stageIndex = 0
    else:
      game.hasError = true
      game.errorMessage = "no more stages (end of seq in init.json)"
      return
  loadCurrentStage(game, renderer)

proc drawErrorOverlay(renderer: SDL_Renderer, game: Game, winW, winH: int32) =
  discard SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND)
  discard SDL_SetRenderDrawColor(renderer, 120'u8, 10'u8, 10'u8, 215'u8)
  var bgRect = SDL_FRect(x: 0'f32, y: 0'f32, w: float32(winW), h: float32(winH))
  discard SDL_RenderFillRect(renderer, addr bgRect)

  discard SDL_SetRenderDrawColor(renderer, 255'u8, 255'u8, 255'u8, 255'u8)
  discard SDL_RenderDebugText(renderer, 20'f32, 20'f32, cstring("engine error"))
  discard SDL_RenderDebugText(renderer, 20'f32, 40'f32, cstring(game.errorMessage))
  discard SDL_RenderDebugText(renderer, 20'f32, 60'f32, cstring("if you wish, you may attempt to skip the stage"))

  discard SDL_SetRenderDrawColor(renderer, 210'u8, 200'u8, 40'u8, 255'u8)
  var btnRect = SDL_FRect(x: skipBtnX, y: skipBtnY, w: skipBtnW, h: skipBtnH)
  discard SDL_RenderFillRect(renderer, addr btnRect)
  discard SDL_SetRenderDrawColor(renderer, 0'u8, 0'u8, 0'u8, 255'u8)
  discard SDL_RenderDebugText(renderer, skipBtnX + 28'f32, skipBtnY + 12'f32, cstring("> skip <"))

proc main() =
  let (winW, winH, winTitle) = loadInitConfig("game/init.json")
  skipBtnX = float32(winW) - skipBtnW - 20'f32
  skipBtnY = float32(winH) - skipBtnH - 20'f32

  doAssert SDL_Init(SDL_INIT_VIDEO)
  let window = SDL_CreateWindow(cstring(winTitle), cint(winW), cint(winH), SDL_WindowFlags(0))
  let renderer = SDL_CreateRenderer(window, nil)

  discard SDL_SetWindowRelativeMouseMode(window, false)
  discard SDL_ShowCursor()

  var game = initGame()
  if stages.len > 0:
    loadCurrentStage(game, renderer)
  else:
    loadStorylineStage(game, "game/dialogue.json", renderer)

  var event: SDL_Event
  var running = true
  var lastTime = SDL_GetTicks()
  var currentFPS: float32 = 0.0f
  var mouseX, mouseY: float32
  var prevHasError = false

  while running:
    let currentTime = SDL_GetTicks()
    let dt = float32(currentTime - lastTime) / 1000f
    lastTime = currentTime
    currentFPS = if dt > 0f: 1.0f/dt else: 0.0f

    var mx, my: cfloat
    discard SDL_GetMouseState(mx, my)
    mouseX = mx; mouseY = my

    while SDL_PollEvent(event):
      if event.`type` == SDL_EVENT_QUIT or
         (event.`type` == SDL_EVENT_KEY_DOWN and event.key.key == SDLK_ESCAPE):
        running = false
      elif game.hasError:
        if event.`type` == SDL_EVENT_MOUSE_BUTTON_DOWN and event.button.button == 1'u8:
          if event.button.x >= skipBtnX and event.button.x <= skipBtnX + skipBtnW and
             event.button.y >= skipBtnY and event.button.y <= skipBtnY + skipBtnH:
            advanceStage(game, renderer)
      else:
        handleEvent(game, window, event, winW, winH)

    if not game.hasError:
      update(game, window, dt, mouseX, mouseY, winW, winH)

    if game.stageFinished:
      advanceStage(game, renderer)

    if game.hasError != prevHasError:
      discard SDL_SetWindowRelativeMouseMode(window, not game.hasError)
      prevHasError = game.hasError

    render(game, renderer, winW, winH, currentFPS)
    if game.hasError:
      drawErrorOverlay(renderer, game, winW, winH)
    SDL_RenderPresent(renderer)

  SDL_DestroyWindow(window)
  SDL_Quit()

when isMainModule:
  main()
