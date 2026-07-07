# engine/renderer.nim
import sdl3, glm, math
import game


proc worldToScreen*(p: Vec3f, camPos: Vec3f, camRot: float32, winW, winH: int32, fov = 90f): tuple[x, y, w: float32] =
  var view = rotate(mat4f(1f), -camRot, vec3f(0f, 1f, 0f))
  view = translate(view, -camPos)
  let proj = perspective(radians(fov), float32(winW)/float32(winH), 0.1f, 100f)
  var clip = proj * view * vec4f(p.x, p.y, p.z, 1f)
  if clip.w <= 0: return (-1000f, -1000f, 0f)
  result.x = (clip.x/clip.w + 1f) * 0.5f * float32(winW)
  result.y = (1f - clip.y/clip.w) * 0.5f * float32(winH)
  result.w = clip.w 

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
                outlineThick: int = 1,
                texture: ptr SDL_Texture = nil) =

  # ZMIANA: Wracamy do czystej struktury (x, y) bez wstrzykiwania wadliwego parametru głębi
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
    
    # Wyciągamy tylko czyste współrzędne ekranu (x, y), ignorując parametr 'w' z worldToScreen
    let screenRes = worldToScreen(rp, camPos, camRot, winW, winH, fov)
    sp[i] = (x: screenRes.x, y: screenRes.y)

  if sp[0].x <= -1000f or sp[1].x <= -1000f or sp[2].x <= -1000f or sp[3].x <= -1000f: 
    return

  # aight then thx ai

  let fc = if texture == nil:
             SDL_FColor(r: float32(fillColor[0])/255f, g: float32(fillColor[1])/255f,
                        b: float32(fillColor[2])/255f, a: float32(fillColor[3])/255f)
           else:
             SDL_FColor(r: 1f, g: 1f, b: 1f, a: 1f)
  
  # ai helped with this what the fuck is this how do i comprehend this

  # ZMIANA: Obliczamy idealny środek kwadratu na ekranie 2D (przecięcie przekątnych)
  let midX = (sp[0].x + sp[1].x + sp[2].x + sp[3].x) / 4f
  let midY = (sp[0].y + sp[1].y + sp[2].y + sp[3].y) / 4f
  let midVert = SDL_FPoint(x: midX, y: midY)

  # ZMIANA: Zamiast 2 gigantycznych trójkątów, dzielimy kwadrat na 4 mniejsze trójkąty
  # zbiegające się do wspólnego środka (midVert). To eliminuje psucie się tekstury na boki!
  var verts = [
    # Trójkąt 1 (Góra): Top-Left (0), Top-Right (1), Środek
    SDL_Vertex(position: SDL_FPoint(x: sp[0].x, y: sp[0].y), color: fc, texCoord: SDL_FPoint(x: 0f, y: 1f)),
    SDL_Vertex(position: SDL_FPoint(x: sp[1].x, y: sp[1].y), color: fc, texCoord: SDL_FPoint(x: 1f, y: 1f)),
    SDL_Vertex(position: midVert, color: fc, texCoord: SDL_FPoint(x: 0.5f, y: 0.5f)),

    # Trójkąt 2 (Prawo): Top-Right (1), Bottom-Right (2), Środek
    SDL_Vertex(position: SDL_FPoint(x: sp[1].x, y: sp[1].y), color: fc, texCoord: SDL_FPoint(x: 1f, y: 1f)),
    SDL_Vertex(position: SDL_FPoint(x: sp[2].x, y: sp[2].y), color: fc, texCoord: SDL_FPoint(x: 1f, y: 0f)),
    SDL_Vertex(position: midVert, color: fc, texCoord: SDL_FPoint(x: 0.5f, y: 0.5f)),

    # Trójkąt 3 (Dół): Bottom-Right (2), Bottom-Left (3), Środek
    SDL_Vertex(position: SDL_FPoint(x: sp[2].x, y: sp[2].y), color: fc, texCoord: SDL_FPoint(x: 1f, y: 0f)),
    SDL_Vertex(position: SDL_FPoint(x: sp[3].x, y: sp[3].y), color: fc, texCoord: SDL_FPoint(x: 0f, y: 0f)),
    SDL_Vertex(position: midVert, color: fc, texCoord: SDL_FPoint(x: 0.5f, y: 0.5f)),

    # Trójkąt 4 (Lewo): Bottom-Left (3), Top-Left (0), Środek
    SDL_Vertex(position: SDL_FPoint(x: sp[3].x, y: sp[3].y), color: fc, texCoord: SDL_FPoint(x: 0f, y: 0f)),
    SDL_Vertex(position: SDL_FPoint(x: sp[0].x, y: sp[0].y), color: fc, texCoord: SDL_FPoint(x: 0f, y: 1f)),
    SDL_Vertex(position: midVert, color: fc, texCoord: SDL_FPoint(x: 0.5f, y: 0.5f))
  ]
  
  # Rysujemy teraz 12 wierzchołków (4 trójkąty po 3 punkty) zamiast starej szóstki
  discard SDL_RenderGeometry(renderer, texture, cast[ptr SDL_Vertex](addr verts[0]), 12, nil, 0)
  
  # outline idk why
  SDL_SetRenderDrawColor(renderer, outlineColor[0], outlineColor[1], outlineColor[2], outlineColor[3])
  for i in 0..3:
    let next = (i+1) mod 4
    for offset in -(outlineThick div 2)..(outlineThick div 2):
      SDL_RenderLine(renderer, sp[i].x + float32(offset), sp[i].y + float32(offset),
                    sp[next].x + float32(offset), sp[next].y + float32(offset))
# end square shit what the fuck

proc drawBillboard*(renderer: SDL_Renderer, points: array[4, Vec3f], 
                   camPos: Vec3f, camRot: float32, squareRot: float32, squareBounce: float32, 
                   winW, winH: int32, fov: float32,
                   fillColor: array[4, uint8], outlineColor: array[4, uint8], 
                   outlineThick: int = 1,
                   texture: ptr SDL_Texture = nil) =
  var centerX = 0f; var centerY = 0f; var centerZ = 0f
  for p in points:
    centerX += p.x
    centerY += p.y
    centerZ += p.z
  centerX /= 4f; centerY /= 4f; centerZ /= 4f
  
  let finalWorldPos = vec3f(centerX, centerY + squareBounce, centerZ)
  let screenPos = worldToScreen(finalWorldPos, camPos, camRot, winW, winH, fov)
  
  if screenPos.x <= -1000f or screenPos.w <= 0.1f: 
    return

  let baseSizeInWorld = 1.0f 
  let currentScale = (baseSizeInWorld * float32(winH)) / (screenPos.w * radians(fov))
  let destW = currentScale
  let destH = currentScale

  if texture != nil:
    var destRect = SDL_FRect(x: screenPos.x - (destW / 2f), y: screenPos.y - (destH / 2f), w: destW, h: destH)
    discard SDL_RenderTexture(renderer, texture, nil, addr destRect)
  else:
    SDL_SetRenderDrawColor(renderer, fillColor[0], fillColor[1], fillColor[2], fillColor[3])
    var fallbackRect = SDL_FRect(x: screenPos.x - (destW / 2f), y: screenPos.y - (destH / 2f), w: destW, h: destH)
    discard SDL_RenderFillRect(renderer, addr fallbackRect)

  # outline
  SDL_SetRenderDrawColor(renderer, outlineColor[0], outlineColor[1], outlineColor[2], outlineColor[3])
  var outlineRect = SDL_FRect(x: screenPos.x - (destW / 2f), y: screenPos.y - (destH / 2f), w: destW, h: destH)
  for offset in -(outlineThick div 2)..(outlineThick div 2):
    var thickRect = SDL_FRect(
      x: outlineRect.x - float32(offset),
      y: outlineRect.y - float32(offset),
      w: outlineRect.w + float32(offset * 2),
      h: outlineRect.h + float32(offset * 2)
    )
    discard SDL_RenderRect(renderer, addr thickRect)
# end billboard

proc drawCrosshair*(r: SDL_Renderer, winW, winH: int32) =
  let cx = float32(winW)/2f; let cy = float32(winH)/2f; let size = 2.5f
  SDL_SetRenderDrawColor(r, 255, 255, 255, 200)
  for dy in -int(size)..int(size):
    for dx in -int(size)..int(size):
      if sqrt(float32(dx*dx + dy*dy)) <= size:
        SDL_RenderPoint(r, cx + float32(dx), cy + float32(dy))

proc drawGroundPlane*(renderer: SDL_Renderer, camPos: Vec3f, camRot: float32, winW, winH: int32, fov: float32) =
  SDL_SetRenderDrawColor(renderer, 45, 45, 60, 255)
  const 
    GridRange = 30.0f
    Step = 2.0f
    FloorY = -1.0f 

  var x = -GridRange
  while x <= GridRange:
    var z = -GridRange
    while z < GridRange:
      let p1 = worldToScreen(vec3f(x, FloorY, z), camPos, camRot, winW, winH, fov)
      let p2 = worldToScreen(vec3f(x, FloorY, z + Step), camPos, camRot, winW, winH, fov)
      if p1.x > -900 and p2.x > -900:
        SDL_RenderLine(renderer, p1.x, p1.y, p2.x, p2.y)
      z += Step
    x += Step

  var z = -GridRange
  while z <= GridRange:
    var x = -GridRange
    while x < GridRange:
      let p1 = worldToScreen(vec3f(x, FloorY, z), camPos, camRot, winW, winH, fov)
      let p2 = worldToScreen(vec3f(x + Step, FloorY, z), camPos, camRot, winW, winH, fov)
      if p1.x > -900 and p2.x > -900:
        SDL_RenderLine(renderer, p1.x, p1.y, p2.x, p2.y)
      x += Step
    z += Step

proc render*(g: Game, renderer: SDL_Renderer, winW, winH: int32, fps: float32) =
  SDL_SetRenderDrawColor(renderer, 13, 13, 20, 255)
  SDL_RenderClear(renderer)
  
  SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255)
  discard SDL_RenderDebugTextFormat(renderer, 20'f32, 20'f32, "FPS: %.1f".cstring, fps)
  
  let fov = if g.state == gsDialogue or g.camAnimating: 45f else: 90f
  drawGroundPlane(renderer, g.camPos, g.camRot, winW, winH, fov)
  
  for idx in 0 ..< g.objects.len:
    let obj = g.objects[idx]
    var isThisHovered = false
    var isThisClicked = false
    
    if g.state == gsDialogue:
      isThisClicked = (g.activeObject == idx)
      isThisHovered = (g.activeObject == idx)
    else:
      isThisHovered = g.squareHovered and (g.activeObject == idx)
      isThisClicked = g.squareClicked and (g.activeObject == idx)
    
    let fillCol = if isThisHovered: [255'u8, 50, 100, 255] else: [255'u8, 0, 77, 255]
    let outlineCol = if isThisClicked: [255'u8, 0, 0, 255] 
                     elif isThisHovered: [255'u8, 255, 100, 255] 
                     else: [255'u8, 255, 255, 100]
    let outlineThick = if isThisClicked: 5 else: 1
    
    case obj.renderType
    of "billboard":
      drawBillboard(renderer, obj.points, g.camPos, g.camRot, obj.rot, obj.bounce, 
                    winW, winH, fov, fillCol, outlineCol, outlineThick, obj.texture)
    else:
      drawSquare(renderer, obj.points, g.camPos, g.camRot, obj.rot, obj.bounce, 
                 winW, winH, fov, fillCol, outlineCol, outlineThick, obj.texture)
    
  if g.state == gsExplore: drawCrosshair(renderer, winW, winH)
  
  if g.state == gsDialogue and g.squareClicked:
    SDL_SetRenderDrawColor(renderer, 20, 20, 40, 255)
    var r = SDL_FRect(x: float32(winW)*0.05f, y: float32(winH)*0.7f, w: float32(winW)*0.9f, h: float32(winH)*0.25f)
    SDL_RenderFillRect(renderer, addr r)
    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 150)
    SDL_RenderRect(renderer, addr r)
    
    if g.currentLine >= 0 and g.currentLine < g.dialogueLines.len:
      let speakerName = g.dialogueLines[g.currentLine].speaker
      if speakerName != "":
        SDL_SetRenderDrawColor(renderer, 30, 30, 60, 255)
        var nameBox = SDL_FRect(x: r.x + 10f, y: r.y - 30f, w: 150f, h: 30f)
        SDL_RenderFillRect(renderer, addr nameBox)
        SDL_SetRenderDrawColor(renderer, 255, 255, 255, 150)
        SDL_RenderRect(renderer, addr nameBox)
        
        SDL_SetRenderDrawColor(renderer, 255, 215, 0, 255)
        SDL_RenderDebugTextFormat(renderer, nameBox.x + 10f, nameBox.y + 6f, "%s", speakerName.cstring)
    
    if g.textIdx > 0:
      SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255)
      SDL_RenderDebugTextFormat(renderer, r.x+20, r.y+20, "%s", g.text[0..<g.textIdx].cstring)
    
    if g.textFinished:
      drawArrow(renderer, r.x + r.w - 30f, r.y + r.h - 20f, g.arrowVisible)
