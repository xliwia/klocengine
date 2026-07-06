# engine/renderer.nim
import sdl3, glm, math
import game

proc worldToScreen*(p: Vec3f, camPos: Vec3f, camRot: float32, winW, winH: int32, fov = 90f): tuple[x, y: float32] =
  var view = rotate(mat4f(1f), -camRot, vec3f(0f, 1f, 0f))
  view = translate(view, -camPos)
  let proj = perspective(radians(fov), float32(winW)/float32(winH), 0.1f, 100f)
  var clip = proj * view * vec4f(p.x, p.y, p.z, 1f)
  if clip.w <= 0: return (-1000f, -1000f)
  result.x = (clip.x/clip.w + 1f) * 0.5f * float32(winW)
  result.y = (1f - clip.y/clip.w) * 0.5f * float32(winH)

proc drawArrow*(r: SDL_Renderer, x, y: float32, visible: bool) =
  if not visible: return
  SDL_SetRenderDrawColor(r, 255, 255, 255, 255)
  let size = 8.0f
  SDL_RenderLine(r, x, y, x + size, y - size*1.5f)
  SDL_RenderLine(r, x, y, x - size, y - size*1.5f)
  SDL_RenderLine(r, x - size, y - size*1.5f, x + size, y - size*1.5f)

proc drawSquare*(renderer: SDL_Renderer, points: array[4, Vec3f], 
                camPos: Vec3f, camRot: float32, squareRot: float32, squareBounce: float32, 
                winW, winH: int32, fov: float32,
                fillColor: array[4, uint8], outlineColor: array[4, uint8], 
                outlineThick: int = 1) =
  var sp: array[4, tuple[x, y: float32]]
  
  var centerX = 0f; var centerZ = 0f
  for p in points:
    centerX += p.x
    centerZ += p.z
  centerX /= 4f; centerZ /= 4f
  
  for i in 0..3:
    var rp = points[i]
    
    let cr = cos(squareRot); let sr = sin(squareRot)
    let dx = rp.x - centerX
    let dz = rp.z - centerZ
    rp.x = centerX + (dx * cr - dz * sr)
    rp.z = centerZ + (dx * sr + dz * cr)
    
    rp.y = rp.y + squareBounce
    
    sp[i] = worldToScreen(rp, camPos, camRot, winW, winH, fov)
    if sp[i].x < -1000: return
  
  let fc = SDL_FColor(r: float32(fillColor[0])/255f, g: float32(fillColor[1])/255f,
                      b: float32(fillColor[2])/255f, a: float32(fillColor[3])/255f)
  
  var verts = [
    SDL_Vertex(position: SDL_FPoint(x: sp[0].x, y: sp[0].y), color: fc, texCoord: SDL_FPoint(x: 0, y: 0)),
    SDL_Vertex(position: SDL_FPoint(x: sp[1].x, y: sp[1].y), color: fc, texCoord: SDL_FPoint(x: 0, y: 0)),
    SDL_Vertex(position: SDL_FPoint(x: sp[2].x, y: sp[2].y), color: fc, texCoord: SDL_FPoint(x: 0, y: 0)),
    SDL_Vertex(position: SDL_FPoint(x: sp[0].x, y: sp[0].y), color: fc, texCoord: SDL_FPoint(x: 0, y: 0)),
    SDL_Vertex(position: SDL_FPoint(x: sp[2].x, y: sp[2].y), color: fc, texCoord: SDL_FPoint(x: 0, y: 0)),
    SDL_Vertex(position: SDL_FPoint(x: sp[3].x, y: sp[3].y), color: fc, texCoord: SDL_FPoint(x: 0, y: 0))
  ]
  discard SDL_RenderGeometry(renderer, nil, cast[ptr SDL_Vertex](addr verts[0]), 6, nil, 0)
  
  SDL_SetRenderDrawColor(renderer, outlineColor[0], outlineColor[1], outlineColor[2], outlineColor[3])
  for i in 0..3:
    let next = (i+1) mod 4
    for offset in -(outlineThick div 2)..(outlineThick div 2):
      SDL_RenderLine(renderer, sp[i].x + float32(offset), sp[i].y + float32(offset),
                    sp[next].x + float32(offset), sp[next].y + float32(offset))

proc drawCrosshair*(r: SDL_Renderer, winW, winH: int32) =
  let cx = float32(winW)/2f; let cy = float32(winH)/2f; let size = 2.5f
  SDL_SetRenderDrawColor(r, 255, 255, 255, 200)
  for dy in -int(size)..int(size):
    for dx in -int(size)..int(size):
      if sqrt(float32(dx*dx + dy*dy)) <= size:
        SDL_RenderPoint(r, cx + float32(dx), cy + float32(dy))

proc render*(g: Game, renderer: SDL_Renderer, winW, winH: int32) =
  SDL_SetRenderDrawColor(renderer, 13, 13, 20, 255)
  SDL_RenderClear(renderer)
  
  let fov = if g.state == gsDialogue or g.camAnimating: 45f else: 90f
  let fillCol = if g.squareHovered: [255'u8, 50, 100, 255] else: [255'u8, 0, 77, 255]
  let outlineCol = if g.squareClicked: [255'u8, 0, 0, 255] elif g.squareHovered: [255'u8, 255, 100, 255] else: [255'u8, 255, 255, 100]
  let outlineThick = if g.squareClicked: 5 else: 1
  
  for obj in g.objects:
    drawSquare(renderer, obj.points, g.camPos, g.camRot, obj.rot, obj.bounce, winW, winH, fov, fillCol, outlineCol, outlineThick)
  
  if g.state == gsExplore: drawCrosshair(renderer, winW, winH)
  
  if g.state == gsDialogue and g.squareClicked:
    SDL_SetRenderDrawColor(renderer, 20, 20, 40, 255)
    var r = SDL_FRect(x: float32(winW)*0.05f, y: float32(winH)*0.7f, w: float32(winW)*0.9f, h: float32(winH)*0.25f)
    SDL_RenderFillRect(renderer, addr r)
    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 150)
    SDL_RenderRect(renderer, addr r)
    
    if g.textIdx > 0:
      SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255)
      SDL_RenderDebugTextFormat(renderer, r.x+20, r.y+20, "%s", g.text[0..<g.textIdx].cstring)
    
    if g.textFinished:
      drawArrow(renderer, r.x + r.w - 30f, r.y + r.h - 20f, g.arrowVisible)