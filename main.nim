# main.nim
import sdl3
import engine/[game, renderer, input, animation]

const
  WIN_W = 1280
  WIN_H = 720
  WIN_TITLE = "kloc"

proc main() =
  doAssert SDL_Init(SDL_INIT_VIDEO)
  let window = SDL_CreateWindow(WIN_TITLE, WIN_W, WIN_H, 0)
  let renderer = SDL_CreateRenderer(window, nil)
  discard SDL_SetWindowRelativeMouseMode(window, true)
  
  var game = initGame()
  
  var event: SDL_Event
  var running = true
  var lastTime = SDL_GetTicks()
  var mouseX, mouseY: float32
  
  while running:
    let currentTime = SDL_GetTicks()
    let dt = float32(currentTime - lastTime) / 1000f
    lastTime = currentTime
    
    var mx, my: cfloat
    discard SDL_GetMouseState(mx, my)
    mouseX = mx; mouseY = my
    
    while SDL_PollEvent(event):
      if event.`type` == SDL_EVENT_QUIT or 
         (event.`type` == SDL_EVENT_KEY_DOWN and event.key.key == SDLK_ESCAPE):
        running = false
      else:
        handleEvent(game, window, event, WIN_W, WIN_H)
    
    update(game, window, dt, mouseX, mouseY, WIN_W, WIN_H)
    render(game, renderer, WIN_W, WIN_H)
    SDL_RenderPresent(renderer)
  
  SDL_DestroyWindow(window)
  SDL_Quit()

when isMainModule:
  main()