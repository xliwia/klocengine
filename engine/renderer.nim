# engine/renderer.nim
import sdl3, glm, math
import game
import std/strutils
import font_ft

var dialogueFontPath = "assets/Roboto-Regular.ttf"
var dialogueFontHandle: pointer = nil

const COLOR_TAG_BEFORE_SPACE = 4f
const COLOR_TAG_AFTER_SPACE = 2.0f

proc ensureDialogueFont() =
  if dialogueFontHandle != nil:
    return
  let resolvedPath = resolveGamePath(dialogueFontPath)
  dialogueFontHandle = font_load(resolvedPath.cstring, 24.cint)

proc renderTextWithFont(renderer: SDL_Renderer, x, y: float32, text: string, color: array[4, uint8]): int =
  if text.len == 0:
    return 0

  ensureDialogueFont()

  if dialogueFontHandle == nil:
    echo "!! font nie zaladowany - sprawdz sciezke: ", resolveGamePath(dialogueFontPath)
    return 0

  var outW, outH: cint
  let pixelData = font_render_text(dialogueFontHandle, text.cstring, 1.0f, addr outW, addr outH)

  if pixelData == nil:
    return 0

  if outW <= 0 or outH <= 0:
    font_free_pixels(pixelData)
    return 0

  let pixCount = outW.int * outH.int
  var rgba = newSeq[uint8](pixCount * 4)

  let src = cast[ptr UncheckedArray[uint8]](pixelData)

  for i in 0 ..< pixCount:
    let a = src[i]
    rgba[i*4 + 0] = 255'u8
    rgba[i*4 + 1] = 255'u8
    rgba[i*4 + 2] = 255'u8
    rgba[i*4 + 3] = a

  let surface = SDL_CreateSurfaceFrom(
    outW,
    outH,
    SDL_PIXELFORMAT_RGBA32,
    addr rgba[0],
    outW * 4
  )

  if surface != nil:
    let texture = SDL_CreateTextureFromSurface(renderer, surface)

    if texture != nil:
      var dst = SDL_FRect(
        x: x,
        y: y,
        w: float32(outW),
        h: float32(outH)
      )

      discard SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND)
      discard SDL_SetTextureColorMod(texture, color[0], color[1], color[2])
      discard SDL_SetTextureAlphaMod(texture, color[3])

      discard SDL_RenderTexture(renderer, texture, nil, addr dst)

      SDL_DestroyTexture(texture)

    SDL_DestroySurface(surface)

  font_free_pixels(pixelData)

  return outW

proc measureTextWidth(renderer: SDL_Renderer, text: string): float32 =
  if text.len == 0:
    return 0f

  ensureDialogueFont()

  if dialogueFontHandle == nil:
    return 0f

  var w, h: cint
  let pixels = font_render_text(
    dialogueFontHandle,
    text.cstring,
    1.0f,
    addr w,
    addr h
  )

  if pixels != nil:
    font_free_pixels(pixels)

  return float32(w) * 0.92f

proc drawTextSegment(renderer: SDL_Renderer, x, y: float32, text: string, color: array[4, uint8]): float32 =
  let width = renderTextWithFont(renderer, x, y, text, color)
  return float32(width) * 0.92f

proc stripStyleTags*(text: string): string =
  var i = 0

  while i < text.len:
    if text[i] == '<':
      let closePos = text.find('>', i)

      if closePos >= 0:
        i = closePos + 1
        continue

    result.add text[i]
    inc i

proc takeVisibleChars*(text: string, amount: int): string =
  var visibleCount = 0
  var i = 0

  while i < text.len:

    if text[i] == '<':
      let closePos = text.find('>', i)

      if closePos >= 0:
        # kopiujemy cały tag od razu
        result.add text[i .. closePos]
        i = closePos + 1
        continue


    if visibleCount >= amount:
      break

    result.add text[i]
    inc visibleCount
    inc i

proc drawStyledText(
    renderer: SDL_Renderer,
    x, y: float32,
    text: string,
    baseColor: array[4, uint8]
) =
  var cursor = 0
  var drawX = x
  var color = baseColor
  var insideColor = false

  let spaceWidth = measureTextWidth(renderer, " ")

  while cursor < text.len:

    if text[cursor] == '<':
      let closePos = text.find('>', cursor + 1)

      if closePos >= 0:
        let tag = text[cursor + 1 ..< closePos]

        # zamykanie koloru
        if tag.len > 0 and tag[0] == '/':
          color = baseColor
          insideColor = false

          # normalna spacja PO kolorze
          drawX += spaceWidth * COLOR_TAG_AFTER_SPACE

        else:
          # otwieranie koloru
          let tagLower = toLowerAscii(tag)

          if tagLower == "red" or
             tagLower == "green" or
             tagLower == "blue" or
             tagLower == "yellow" or
             tagLower == "white" or
             tagLower.startsWith("color="):

            # dodatkowy odstęp PRZED kolorowym tekstem
            drawX += spaceWidth * COLOR_TAG_BEFORE_SPACE
            insideColor = true

            case tagLower
            of "red":
              color = [255'u8,90'u8,90'u8,255'u8]

            of "green":
              color = [90'u8,220'u8,120'u8,255'u8]

            of "blue":
              color = [100'u8,170'u8,255'u8,255'u8]

            of "yellow":
              color = [255'u8,220'u8,90'u8,255'u8]

            of "white":
              color = baseColor

            else:
              if tagLower.startsWith("color="):
                let hex = tagLower[tagLower.find("=")+1 ..< tagLower.len]

                if hex.len == 6:
                  color = [
                    uint8(parseHexInt(hex[0..1])),
                    uint8(parseHexInt(hex[2..3])),
                    uint8(parseHexInt(hex[4..5])),
                    255'u8
                  ]

        cursor = closePos + 1
        continue


    let nextTag = text.find('<', cursor)

    let endPos =
      if nextTag >= 0 and nextTag > cursor:
        nextTag
      else:
        text.len

    let segment = text[cursor ..< endPos]

    if segment.len > 0:
      drawX += drawTextSegment(
        renderer,
        drawX,
        y,
        segment,
        color
      )

    cursor = endPos

proc drawVNScene*(renderer: SDL_Renderer, g: Game, winW, winH: int32) =
  if g.vnActive:
    if g.vnScene.backgroundTexture != nil:
      var texW, texH: cfloat
      discard SDL_GetTextureSize(g.vnScene.backgroundTexture, texW, texH)
      if texW > 0f and texH > 0f:
        let scale = min(float32(winW) / float32(texW), float32(winH) / float32(texH))
        let targetW = float32(texW) * scale
        let targetH = float32(texH) * scale
        var dst = SDL_FRect(x: (float32(winW) - targetW) / 2f, y: (float32(winH) - targetH) / 2f, w: targetW, h: targetH)
        discard SDL_RenderTexture(renderer, g.vnScene.backgroundTexture, nil, addr dst)
      else:
        SDL_SetRenderDrawColor(renderer, 20, 20, 30, 255)
        var fill = SDL_FRect(x: 0f, y: 0f, w: float32(winW), h: float32(winH))
        discard SDL_RenderFillRect(renderer, addr fill)
    else:
      SDL_SetRenderDrawColor(renderer, 20, 20, 30, 255)
      var fill = SDL_FRect(x: 0f, y: 0f, w: float32(winW), h: float32(winH))
      discard SDL_RenderFillRect(renderer, addr fill)

    for ch in g.vnScene.characters:
      if ch.visible and ch.texture != nil:
        var texW, texH: cfloat
        discard SDL_GetTextureSize(ch.texture, texW, texH)
        if texW > 0f and texH > 0f:
          let targetH = float32(winH) * 0.65f
          let targetW = targetH * (float32(texW) / float32(texH))
          var x = float32(winW) * 0.5f - targetW / 2f
          if ch.alignment == "left":
            x = float32(winW) * 0.1f
          elif ch.alignment == "right":
            x = float32(winW) * 0.9f - targetW
          elif ch.alignment == "center":
            x = float32(winW) * 0.5f - targetW / 2f
          let bounceDuration = if ch.bounceDuration > 0f: ch.bounceDuration else: 0.25f
          let bounceOffset = if ch.bounceTimer > 0f:
            let t = 1f - (ch.bounceTimer / bounceDuration)
            let eased = sin(t * PI)
            eased * ch.bounceHeight
          else:
            0f
          let alphaValue = uint8(max(0f, min(1f, ch.opacity)) * 255f)
          discard SDL_SetTextureAlphaMod(ch.texture, alphaValue)
          var dst = SDL_FRect(x: x, y: float32(winH) - targetH - 20f - bounceOffset, w: targetW, h: targetH)
          discard SDL_RenderTexture(renderer, ch.texture, nil, addr dst)


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
    
    let screenRes = worldToScreen(rp, camPos, camRot, winW, winH, fov)
    sp[i] = (x: screenRes.x, y: screenRes.y)

  if sp[0].x <= -1000f or sp[1].x <= -1000f or sp[2].x <= -1000f or sp[3].x <= -1000f: 
    return

  let fc = if texture == nil:
             SDL_FColor(r: float32(fillColor[0])/255f, g: float32(fillColor[1])/255f,
                        b: float32(fillColor[2])/255f, a: float32(fillColor[3])/255f)
           else:
             SDL_FColor(r: 1f, g: 1f, b: 1f, a: 1f)

  let midX = (sp[0].x + sp[1].x + sp[2].x + sp[3].x) / 4f
  let midY = (sp[0].y + sp[1].y + sp[2].y + sp[3].y) / 4f
  let midVert = SDL_FPoint(x: midX, y: midY)

  var verts = [
    SDL_Vertex(position: SDL_FPoint(x: sp[0].x, y: sp[0].y), color: fc, texCoord: SDL_FPoint(x: 0f, y: 1f)),
    SDL_Vertex(position: SDL_FPoint(x: sp[1].x, y: sp[1].y), color: fc, texCoord: SDL_FPoint(x: 1f, y: 1f)),
    SDL_Vertex(position: midVert, color: fc, texCoord: SDL_FPoint(x: 0.5f, y: 0.5f)),

    SDL_Vertex(position: SDL_FPoint(x: sp[1].x, y: sp[1].y), color: fc, texCoord: SDL_FPoint(x: 1f, y: 1f)),
    SDL_Vertex(position: SDL_FPoint(x: sp[2].x, y: sp[2].y), color: fc, texCoord: SDL_FPoint(x: 1f, y: 0f)),
    SDL_Vertex(position: midVert, color: fc, texCoord: SDL_FPoint(x: 0.5f, y: 0.5f)),

    SDL_Vertex(position: SDL_FPoint(x: sp[2].x, y: sp[2].y), color: fc, texCoord: SDL_FPoint(x: 1f, y: 0f)),
    SDL_Vertex(position: SDL_FPoint(x: sp[3].x, y: sp[3].y), color: fc, texCoord: SDL_FPoint(x: 0f, y: 0f)),
    SDL_Vertex(position: midVert, color: fc, texCoord: SDL_FPoint(x: 0.5f, y: 0.5f)),

    SDL_Vertex(position: SDL_FPoint(x: sp[3].x, y: sp[3].y), color: fc, texCoord: SDL_FPoint(x: 0f, y: 0f)),
    SDL_Vertex(position: SDL_FPoint(x: sp[0].x, y: sp[0].y), color: fc, texCoord: SDL_FPoint(x: 0f, y: 1f)),
    SDL_Vertex(position: midVert, color: fc, texCoord: SDL_FPoint(x: 0.5f, y: 0.5f))
  ]
  
  discard SDL_RenderGeometry(renderer, texture, cast[ptr SDL_Vertex](addr verts[0]), 12, nil, 0)
  
  SDL_SetRenderDrawColor(renderer, outlineColor[0], outlineColor[1], outlineColor[2], outlineColor[3])
  for i in 0..3:
    let next = (i+1) mod 4
    for offset in -(outlineThick div 2)..(outlineThick div 2):
      SDL_RenderLine(renderer, sp[i].x + float32(offset), sp[i].y + float32(offset),
                    sp[next].x + float32(offset), sp[next].y + float32(offset))

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

proc drawMenu*(renderer: SDL_Renderer, g: Game, winW, winH: int32) =
  if g.menuScene.backgroundTexture != nil:
    var dst = SDL_FRect(
      x: 0,
      y: 0,
      w: float32(winW),
      h: float32(winH)
    )
    discard SDL_RenderTexture(
      renderer,
      g.menuScene.backgroundTexture,
      nil,
      addr dst
    )
  else:
    SDL_SetRenderDrawColor(renderer, 20,20,30,255)
    var rect = SDL_FRect(
      x:0,
      y:0,
      w:float32(winW),
      h:float32(winH)
    )
    SDL_RenderFillRect(renderer, addr rect)


  var y = float32(winH) * 0.4f

  for i, item in g.menuScene.items:
    let hovered = i == g.menuHovered

    let col =
      if hovered:
        [255'u8,200'u8,50'u8,255'u8]
      else:
        [255'u8,255'u8,255'u8,255'u8]

    discard renderTextWithFont(
      renderer,
      float32(winW)*0.4f,
      y,
      item.text,
      col
    )

    y += 70f

proc render*(g: Game, renderer: SDL_Renderer, winW, winH: int32, fps: float32) =
  SDL_SetRenderDrawColor(renderer, 13, 13, 20, 255)
  SDL_RenderClear(renderer)
  
  SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255)
  discard SDL_RenderDebugTextFormat(renderer, 20'f32, 20'f32, "FPS: %.1f".cstring, fps)

  var fov = 90f
  if g.state == gsMenu:
    drawMenu(renderer, g, winW, winH)
  elif g.vnActive:
    drawVNScene(renderer, g, winW, winH)
  else:
    fov = if g.state == gsDialogue or g.camAnimating: 45f else: 90f
    drawGroundPlane(renderer, g.camPos, g.camRot, winW, winH, fov)


  if not g.vnActive and g.state != gsMenu:
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

      let fillCol =
        if isThisHovered:
          [255'u8, 50, 100, 255]
        else:
          [255'u8, 0, 77, 255]

      let outlineCol =
        if isThisClicked:
          [255'u8, 0, 0, 255]
        elif isThisHovered:
          [255'u8, 255, 100, 255]
        else:
          [255'u8, 255, 255, 100]

      let outlineThick = if isThisClicked: 5 else: 1

      case obj.renderType
      of "billboard":
        drawBillboard(
          renderer,
          obj.points,
          g.camPos,
          g.camRot,
          obj.rot,
          obj.bounce,
          winW,
          winH,
          fov,
          fillCol,
          outlineCol,
          outlineThick,
          obj.texture
        )
      else:
        drawSquare(
          renderer,
          obj.points,
          g.camPos,
          g.camRot,
          obj.rot,
          obj.bounce,
          winW,
          winH,
          fov,
          fillCol,
          outlineCol,
          outlineThick,
          obj.texture
        )


  if not g.vnActive and g.state == gsExplore:
    drawCrosshair(renderer, winW, winH)


  if g.state == gsDialogue and g.squareClicked and g.showDialogueBox:
    SDL_SetRenderDrawColor(renderer, 20, 20, 40, 255)
    var r = SDL_FRect(
      x: float32(winW)*0.05f,
      y: float32(winH)*0.7f,
      w: float32(winW)*0.9f,
      h: float32(winH)*0.25f
    )
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
        drawStyledText(
          renderer,
          nameBox.x + 10f,
          nameBox.y + 6f,
          speakerName,
          [255'u8, 215'u8, 0'u8, 255'u8]
        )
            
    if g.textIdx > 0:
      if g.textIdx > 0:
        drawStyledText(
          renderer,
          r.x + 20f,
          r.y + 20f,
          takeVisibleChars(g.text, g.textIdx),
          [255'u8, 255'u8, 255'u8, 255'u8]
        )
    if g.textFinished:
      drawArrow(renderer, r.x + r.w - 30f, r.y + r.h - 20f, g.arrowVisible)