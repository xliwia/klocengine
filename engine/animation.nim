# engine/animation.nim
import sdl3, glm, math
import game, config, renderer, dialogue

# just to be clear ion know how this shit works
# allat math shit my biggest enemy ffs
proc pointInPoly*(px, py: float32, poly: openArray[tuple[x, y: float32]]): bool =
  var inside = false; var j = poly.len - 1
  for i in 0..<poly.len:
    if ((poly[i].y > py) != (poly[j].y > py)) and
       (px < (poly[j].x - poly[i].x) * (py - poly[i].y) / (poly[j].y - poly[i].y) + poly[i].x):
      inside = not inside
    j = i
  return inside

proc isHovering*(mx, my: float32, points: array[4, Vec3f], camPos: Vec3f, camRot: float32, 
                 objRot: float32, objBounce: float32, winW, winH: int32, fov: float32): bool =
  var sp: array[4, tuple[x, y, w: float32]]
  
  var centerX = 0f; var centerZ = 0f
  for p in points:
    centerX += p.x
    centerZ += p.z
  centerX /= 4f; centerZ /= 4f
  
  for i in 0..3:
    var rp = points[i]
    
    let cr = cos(objRot); let sr = sin(objRot)
    let dx = rp.x - centerX
    let dz = rp.z - centerZ
    rp.x = centerX + (dx * cr - dz * sr)
    rp.z = centerZ + (dx * sr + dz * cr)
    
    rp.y = rp.y + objBounce
    
    sp[i] = worldToScreen(rp, camPos, camRot, winW, winH, fov)
    if sp[i].x < -1000: return false

  var polyPoints: array[4, tuple[x, y: float32]]
  for idx in 0..3:
    polyPoints[idx] = (x: sp[idx].x, y: sp[idx].y)

  return pointInPoly(mx, my, polyPoints)



proc update*(g: var Game, window: SDL_Window, dt, mx, my: float32, winW, winH: int32) =
  var n: cint; let k = SDL_GetKeyboardState(n)
  
  let fov = if g.state == gsDialogue or g.camAnimating: 45f else: 90f
  
  if not g.camAnimating:
    g.squareHovered = false
    g.activeObject = -1
    for i, obj in mpairs(g.objects):
      if isHovering(mx, my, obj.points, g.camPos, g.camRot, obj.rot, obj.bounce, winW, winH, fov):
        g.squareHovered = true
        g.activeObject = i
        break
 
  if g.camAnimating:
    if g.activeObject < 0 or g.activeObject >= g.objects.len:
      g.camAnimating = false
      return
    
    g.camAnimTimer += dt * CAM_FLY_SPEED
    if g.camAnimTimer > 1.0f: g.camAnimTimer = 1.0f
    
    let t = g.camAnimTimer
    let ease = t * t * (3.0f - 2.0f * t)
    
    g.camPos = g.camAnimStartPos + (g.camAnimTargetPos - g.camAnimStartPos) * ease
    g.camRot = g.camAnimStartRot + (g.camAnimTargetRot - g.camAnimStartRot) * ease
    
    let objAddr = addr g.objects[g.activeObject]
    objAddr.spinTimer += dt * SQUARE_SPIN_SPEED
    
    if objAddr.spinTimer < SQUARE_SPIN_DELAY:
      objAddr.rot = 0f
      objAddr.bounce = 0f
    else:
      let spinT = (objAddr.spinTimer - SQUARE_SPIN_DELAY) / (1.0f - SQUARE_SPIN_DELAY)
      let spinClamped = min(spinT, 1.0f)
      let spinEase = spinClamped * spinClamped * (3.0f - 2.0f * spinClamped)
      objAddr.rot = spinEase * PI * 2.0f
      
      let bounceTime = spinClamped * SQUARE_BOUNCE_DURATION
      let bouncePhase = bounceTime * PI * 2.0f * SQUARE_BOUNCE_SPEED
      let fadeOut = 1.0f - spinEase
      objAddr.bounce = sin(bouncePhase) * SQUARE_BOUNCE_HEIGHT * fadeOut
    
    if g.camAnimTimer >= 1.0f:
      g.camPos = g.camAnimTargetPos
      g.camRot = 0f
      objAddr.rot = PI * 2.0f
      objAddr.bounce = 0f
      objAddr.spinTimer = 0f
      g.camAnimating = false
      g.state = gsDialogue
      g.squareClicked = true
      g.dialogueLines = loadDialogue(objAddr.id)
      g.currentLine = 0
      if g.dialogueLines.len > 0:
        g.text = g.dialogueLines[0].text
      else:
        g.text = "..."
      g.textIdx = 0
      g.textTimer = 0f
      g.textFinished = false
      g.arrowVisible = true
    return

  let q = k[SDL_SCANCODE_Q.int]
  if q and not g.qPrev:
    if g.state == gsDialogue:
      g.state = gsExplore
      g.camPos = g.savedCamPos; g.camRot = g.savedCamRot
      g.squareClicked = false
      g.textFinished = false
      if g.activeObject >= 0 and g.activeObject < g.objects.len:
        g.objects[g.activeObject].rot = 0f
        g.objects[g.activeObject].bounce = 0f
      g.dialogueLines = @[]
      g.currentLine = 0
      discard SDL_SetWindowRelativeMouseMode(window, true)
      g.skipMouse = true
    else:
      g.state = gsDialogue
      g.savedCamPos = g.camPos; g.savedCamRot = g.camRot
      if g.activeObject >= 0 and g.activeObject < g.objects.len:
        g.camPos = g.objects[g.activeObject].dialogCamPos
      g.camRot = 0f
      g.squareClicked = false
      g.textFinished = false
      if g.activeObject >= 0 and g.activeObject < g.objects.len:
        g.objects[g.activeObject].rot = 0f
        g.objects[g.activeObject].bounce = 0f
      discard SDL_SetWindowRelativeMouseMode(window, false)
  g.qPrev = q
  
  if g.camAnimating: return

  if g.state == gsExplore:
    let forward = vec3f(-sin(g.camRot), 0f, -cos(g.camRot))
    let right = vec3f(cos(g.camRot), 0f, -sin(g.camRot))
    
    # 1. Obliczamy pożądaną, następną pozycję na podstawie wciśniętych klawiszy
    var nextPos = g.camPos
    if k[SDL_SCANCODE_W.int]: nextPos = nextPos + forward * MOVE_SPEED * dt * 60f
    if k[SDL_SCANCODE_S.int]: nextPos = nextPos - forward * MOVE_SPEED * dt * 60f
    if k[SDL_SCANCODE_A.int]: nextPos = nextPos - right * MOVE_SPEED * dt * 60f
    if k[SDL_SCANCODE_D.int]: nextPos = nextPos + right * MOVE_SPEED * dt * 60f
    

    let playerRadius = 0.4f # player radius for collision detection
    
    for obj in g.objects:
      var minX = obj.points[0].x
      var maxX = obj.points[0].x
      var minZ = obj.points[0].z
      var maxZ = obj.points[0].z
      
      for p in obj.points:
        if p.x < minX: minX = p.x
        if p.x > maxX: maxX = p.x
        if p.z < minZ: minZ = p.z
        if p.z > maxZ: maxZ = p.z
        
      # expand the bounding box by the player's radius to prevent the player from getting too close
      minX -= playerRadius
      maxX += playerRadius
      minZ -= playerRadius
      maxZ += playerRadius
      
      if nextPos.x >= minX and nextPos.x <= maxX and
         nextPos.z >= minZ and nextPos.z <= maxZ:
           if g.camPos.x < minX or g.camPos.x > maxX:
             nextPos.x = g.camPos.x
           elif g.camPos.z < minZ or g.camPos.z > maxZ:
             nextPos.z = g.camPos.z

    g.camPos = nextPos
    
    SDL_WarpMouseInWindow(window, float32(winW)/2f, float32(winH)/2f)

  
  if g.state == gsDialogue and g.squareClicked:
    if g.textIdx < g.text.len:
      g.textTimer += dt
      while g.textTimer >= TEXT_SPEED and g.textIdx < g.text.len:
        g.textIdx += 1; g.textTimer -= TEXT_SPEED
      if g.textIdx >= g.text.len:
        g.textFinished = true
        g.arrowTimer = 0f
    
    if g.textFinished:
      g.arrowTimer += dt
      if g.arrowTimer >= 0.5f:
        g.arrowVisible = not g.arrowVisible
        g.arrowTimer -= 0.5f