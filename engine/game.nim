# engine/game.nim
import sdl3, glm
import dialogue, config
import std/[json, os, strutils]

type
  GameState* = enum gsExplore, gsDialogue

  VNCharacter* = object
    id*: string
    name*: string
    spritePath*: string
    alignment*: string
    texture*: ptr SDL_Texture
    visible*: bool
    opacity*: float32
    bounceTimer*: float32
    bounceHeight*: float32
    bounceDuration*: float32
    opacityStart*: float32
    opacityTarget*: float32
    opacityTimer*: float32
    opacityDuration*: float32
    opacityActive*: bool

  VNScene* = object
    backgroundPath*: string
    backgroundTexture*: ptr SDL_Texture
    characters*: seq[VNCharacter]
    dialogueLines*: seq[DialogueLine]

  GameObject* = object
    id*: string
    points*: array[4, Vec3f]
    dialogCamPos*: Vec3f
    rot*: float32
    bounce*: float32
    spinTimer*: float32
    texture*: ptr SDL_Texture
    renderType*: string

  Game* = object
    state*: GameState
    camPos*: Vec3f
    camRot*: float32
    savedCamPos*: Vec3f
    savedCamRot*: float32
    squareClicked*: bool
    squareHovered*: bool
    text*: string
    textIdx*: int
    textTimer*: float32
    qPrev*: bool
    skipMouse*: bool
    textFinished*: bool
    arrowTimer*: float32
    arrowVisible*: bool
    camAnimating*: bool
    camAnimTimer*: float32
    camAnimStartPos*: Vec3f
    camAnimStartRot*: float32
    camAnimTargetPos*: Vec3f
    camAnimTargetRot*: float32
    dialogueLines*: seq[DialogueLine]
    currentLine*: int
    activeObject*: int
    objects*: seq[GameObject]
    vnActive*: bool
    vnScene*: VNScene
    pendingStageKind*: string
    pendingStageFile*: string
    dialogueTextSpeed*: float32
    dialogueInstant*: bool
    stageFinished*: bool
    hasError*: bool
    errorMessage*: string
    showDialogueBox*: bool
    waitTimer*: float32
    waitingAfterLine*: bool

proc findProjectRoot(startDir: string): string =
  var dir = if startDir.len > 0: absolutePath(startDir) else: absolutePath(getCurrentDir())
  while true:
    let gameDir = joinPath(dir, "game")
    if dirExists(gameDir) and fileExists(joinPath(gameDir, "init.json")):
      return dir
    let parent = parentDir(dir)
    if parent == dir:
      break
    dir = parent
  return startDir

proc resolveGamePath*(path: string): string =
  if path.len == 0:
    return path
  if path.isAbsolute or fileExists(path):
    return path

  let projectRoot = findProjectRoot(getCurrentDir())
  let rootCandidate = joinPath(projectRoot, path)
  if fileExists(rootCandidate):
    return rootCandidate

  let cwdCandidate = joinPath(getCurrentDir(), path)
  if fileExists(cwdCandidate):
    return cwdCandidate

  let appCandidate = joinPath(getAppDir(), path)
  if fileExists(appCandidate):
    return appCandidate

  let rootGameCandidate = joinPath(projectRoot, "game", path)
  if fileExists(rootGameCandidate):
    return rootGameCandidate

  let cwdGameCandidate = joinPath(getCurrentDir(), "game", path)
  if fileExists(cwdGameCandidate):
    return cwdGameCandidate

  let appGameCandidate = joinPath(getAppDir(), "game", path)
  if fileExists(appGameCandidate):
    return appGameCandidate

  return path

proc loadTextureFromPath(path: string, renderer: SDL_Renderer): ptr SDL_Texture =
  if path.len == 0:
    return nil
  let resolvedPath = resolveGamePath(path)
  if not fileExists(resolvedPath):
    echo "texture missing: ", resolvedPath
    return nil

  let surface = SDL_LoadBMP(resolvedPath.cstring)
  if surface == nil:
    echo "could not load texture: ", resolvedPath
    return nil

  let nativeTex = SDL_CreateTextureFromSurface(renderer, surface)
  SDL_DestroySurface(surface)
  if nativeTex == nil:
    return nil
  discard SDL_SetTextureBlendMode(nativeTex, SDL_BLENDMODE_BLEND)
  discard SDL_SetTextureAlphaMod(nativeTex, 255'u8)
  return cast[ptr SDL_Texture](nativeTex)

proc loadGameObjects(path: string, renderer: SDL_Renderer): seq[GameObject] =
  let resolvedPath = resolveGamePath(path)
  if not fileExists(resolvedPath):
    echo "!! object json files not found: ", path, " (resolved: ", resolvedPath, ")"
    return @[]
  try:
    let data = parseFile(resolvedPath)
    for objNode in data:
      var pts: array[4, Vec3f]
      for i, p in objNode["points"].getElems():
        pts[i] = vec3f(p[0].getFloat, p[1].getFloat, p[2].getFloat)
      let dc = objNode["dialogCamPos"]
      
      var loadedTex: ptr SDL_Texture = nil
      if objNode.hasKey("texture"):
        let texPath = objNode["texture"].getStr
        if texPath != "":
          let resolvedTexPath = resolveGamePath(texPath)
          echo "loading texture: ", resolvedTexPath
          
          let surface = SDL_LoadBMP(resolvedTexPath.cstring)
          if surface != nil:
            echo "SDL_Surface created for: ", texPath
            
            # Tworzymy teksturę i bezpiecznie rzutujemy ją na wskaźnik ptr
            let nativeTex = SDL_CreateTextureFromSurface(renderer, surface)
            loadedTex = cast[ptr SDL_Texture](nativeTex)
            
            if loadedTex != nil:
              echo "should work aight"
            else:
              echo "sum is fucked"
              
            SDL_DestroySurface(surface)
          else:
            echo "SDL_LoadBMP is nil for ", texPath
            echo "has to be 24 - 32 bit uncompressed BMP"

      let rType = if objNode.hasKey("renderType"): objNode["renderType"].getStr else: "square"

      result.add GameObject(
        id: objNode["id"].getStr, 
        points: pts,
        dialogCamPos: vec3f(dc[0].getFloat, dc[1].getFloat, dc[2].getFloat),
        texture: loadedTex,
        renderType: rType
      )

  except JsonParsingError as e:
    echo "!! corrupted json in ", resolvedPath, ": ", e.msg
    return @[]
  except CatchableError as e:
    echo "!! couldnt load ", resolvedPath, ": ", e.msg
    return @[]

proc initGame*(): Game =
  result.state = gsExplore
  result.camPos = vec3f(0f, 0f, 3f)
  result.activeObject = -1
  result.vnActive = false
  result.dialogueTextSpeed = TEXT_SPEED
  result.dialogueInstant = false
  result.stageFinished = false
  result.hasError = false
  result.showDialogueBox = true

proc applyDialogueLineCommands*(g: var Game, line: DialogueLine) =
  g.dialogueTextSpeed = if line.textSpeed > 0f: line.textSpeed else: TEXT_SPEED
  g.dialogueInstant = line.instant

  for cmd in line.commands:
    case cmd.name
    of "speed":
      if cmd.args.len > 0:
        try:
          g.dialogueTextSpeed = parseFloat(cmd.args[0]).float32
        except ValueError:
          discard
    of "instant":
      g.dialogueInstant = true
    of "switchseq":
      if cmd.args.len > 0:
        g.pendingStageFile = cmd.args[0]
        if cmd.args.len > 1:
          g.pendingStageKind = cmd.args[1]
        else:
          g.pendingStageKind = ""
      else:
        g.pendingStageFile = ""
        g.pendingStageKind = ""
    of "movechar", "setalign", "align":
      if cmd.args.len >= 2:
        let charId = cmd.args[0]
        let targetAlign = cmd.args[1]
        for idx in 0 ..< g.vnScene.characters.len:
          if g.vnScene.characters[idx].id == charId:
            g.vnScene.characters[idx].alignment = targetAlign
            break
    of "showchar":
      if cmd.args.len > 0:
        for idx in 0 ..< g.vnScene.characters.len:
          if g.vnScene.characters[idx].id == cmd.args[0]:
            g.vnScene.characters[idx].visible = true
            g.vnScene.characters[idx].opacity = 1f
            g.vnScene.characters[idx].opacityActive = false
            g.vnScene.characters[idx].opacityTimer = 0f
            g.vnScene.characters[idx].opacityTarget = 1f
            break
    of "hidechar":
      if cmd.args.len > 0:
        for idx in 0 ..< g.vnScene.characters.len:
          if g.vnScene.characters[idx].id == cmd.args[0]:
            g.vnScene.characters[idx].visible = false
            g.vnScene.characters[idx].opacity = 0f
            g.vnScene.characters[idx].opacityActive = false
            g.vnScene.characters[idx].opacityTimer = 0f
            g.vnScene.characters[idx].opacityTarget = 0f
            break
    of "fadein":
      if cmd.args.len > 0:
        let duration = if cmd.args.len > 1:
                         try:
                           parseFloat(cmd.args[1]).float32
                         except ValueError:
                           0.35f
                       else:
                         0.35f
        for idx in 0 ..< g.vnScene.characters.len:
          if g.vnScene.characters[idx].id == cmd.args[0]:
            var ch = addr g.vnScene.characters[idx]
            ch.visible = true
            ch.opacityStart = ch.opacity
            ch.opacityTarget = 1f
            ch.opacityTimer = 0f
            ch.opacityDuration = duration
            ch.opacityActive = true
            break
    of "fadeout":
      if cmd.args.len > 0:
        let duration = if cmd.args.len > 1:
                         try:
                           parseFloat(cmd.args[1]).float32
                         except ValueError:
                           0.35f
                       else:
                         0.35f
        for idx in 0 ..< g.vnScene.characters.len:
          if g.vnScene.characters[idx].id == cmd.args[0]:
            var ch = addr g.vnScene.characters[idx]
            ch.visible = true
            ch.opacityStart = ch.opacity
            ch.opacityTarget = 0f
            ch.opacityTimer = 0f
            ch.opacityDuration = duration
            ch.opacityActive = true
            break
    of "bounce":
      if cmd.args.len > 0:
        for idx in 0 ..< g.vnScene.characters.len:
          if g.vnScene.characters[idx].id == cmd.args[0]:
            let height = if cmd.args.len > 1:
                           try:
                             parseFloat(cmd.args[1]).float32
                           except ValueError:
                             24f
                         else:
                           24f
            let duration = if cmd.args.len > 2:
                             try:
                               parseFloat(cmd.args[2]).float32
                             except ValueError:
                               0.25f
                           else:
                             0.25f
            var ch = addr g.vnScene.characters[idx]
            ch.bounceHeight = height
            ch.bounceDuration = duration
            ch.bounceTimer = duration
            break
    else:
      discard

proc loadVNStage*(game: var Game, file: string, renderer: SDL_Renderer) =
  game.showDialogueBox = true
  let resolvedFile = resolveGamePath(file)
  if not fileExists(resolvedFile):
    game.hasError = true
    game.errorMessage = "load failed " & file
    echo "================================================================"
    echo "!! engine error; ", file, ", declared in init, unable to load"
    echo "cause: ", game.errorMessage
    echo "================================================================"
    return

  try:
    let data = parseFile(resolvedFile)
    var scene = VNScene()
    if data.hasKey("background"):
      scene.backgroundPath = data["background"].getStr
      scene.backgroundTexture = loadTextureFromPath(scene.backgroundPath, renderer)

    if data.hasKey("characters"):
      for chNode in data["characters"]:
        let alignment = if chNode.hasKey("alignment"): chNode["alignment"].getStr else: "center"
        let spritePath = if chNode.hasKey("sprite"): chNode["sprite"].getStr else: ""
        scene.characters.add VNCharacter(
          id: if chNode.hasKey("id"): chNode["id"].getStr else: "",
          name: if chNode.hasKey("name"): chNode["name"].getStr else: "",
          spritePath: spritePath,
          alignment: alignment,
          texture: loadTextureFromPath(spritePath, renderer),
          visible: true,
          opacity: 1f,
          bounceDuration: 0.25f,
          opacityDuration: 0.35f
        )

    if data.hasKey("dialogue"):
      for lineNode in data["dialogue"]:
        var cmdSeq: seq[DialogueCommand]
        if lineNode.hasKey("commands"):
          for cmdNode in lineNode["commands"]:
            var args: seq[string]
            if cmdNode.hasKey("args"):
              for argNode in cmdNode["args"]:
                args.add argNode.getStr
            cmdSeq.add DialogueCommand(name: cmdNode["name"].getStr, args: args)

        scene.dialogueLines.add DialogueLine(
          speaker: if lineNode.hasKey("speaker"): lineNode["speaker"].getStr else: "",
          text: if lineNode.hasKey("text"): lineNode["text"].getStr else: "",
          character: if lineNode.hasKey("character"): lineNode["character"].getStr else: "",
          commands: cmdSeq,
          textSpeed: (
            if lineNode.hasKey("textSpeed"):
              lineNode["textSpeed"].getFloat
            else:
              0f
          ),
          instant: (
            if lineNode.hasKey("instant"):
              lineNode["instant"].getBool
            else:
              false
          ),
          wait: (
            if lineNode.hasKey("wait"):
              lineNode["wait"].getFloat
            else:
              0f
          )
        )

    game.objects = @[]
    game.activeObject = -1
    game.vnScene = scene
    game.vnActive = true
    game.pendingStageFile = ""
    game.pendingStageKind = ""
    game.state = gsDialogue
    game.squareClicked = true
    game.dialogueLines = scene.dialogueLines
    game.currentLine = 0
    game.text = if scene.dialogueLines.len > 0: scene.dialogueLines[0].text else: ""
    game.textIdx = 0
    game.textTimer = 0f
    game.textFinished = false
    game.arrowVisible = true
    game.waitTimer = 0f
    game.waitingAfterLine = false
    if scene.dialogueLines.len > 0:
      game.applyDialogueLineCommands(scene.dialogueLines[0])
    game.stageFinished = false
    game.hasError = false
  except JsonParsingError as e:
    game.hasError = true
    game.errorMessage = "failed to parse vn scene " & file & ": " & e.msg
    echo "!! couldnt load vn scene ", resolvedFile, ": ", e.msg
  except CatchableError as e:
    game.hasError = true
    game.errorMessage = "failed to load vn scene " & file & ": " & e.msg
    echo "!! couldnt load vn scene ", resolvedFile, ": ", e.msg

proc loadStorylineStage*(game: var Game, file: string, renderer: SDL_Renderer) = 
  let objs = loadGameObjects("game/objects.json", renderer)
  let dialogOk = loadDialogueData(file)
  if not dialogOk:
    game.hasError = true
    game.errorMessage = "load failed " & file
    echo "================================================================"
    echo "!! engine error; ", file, ", declared in init, unable to load"
    echo "cause: ", game.errorMessage
    echo "================================================================"
    return
  game.objects = objs
  game.activeObject = -1
  game.vnActive = false
  game.state = gsExplore
  game.squareClicked = false
  game.stageFinished = false
  game.hasError = false

proc nextDialogueLine*(game: var Game) =
  if game.currentLine >= game.dialogueLines.len:
    return

  let current = game.dialogueLines[game.currentLine]

  if current.wait > 0f:
    game.waitTimer = current.wait
    game.waitingAfterLine = true
    game.text = ""
    game.textIdx = 0
    game.textFinished = true
    return

  game.currentLine += 1

  if game.currentLine < game.dialogueLines.len:
    let line = game.dialogueLines[game.currentLine]

    game.text = line.text
    game.textIdx = 0
    game.textTimer = 0f
    game.textFinished = false

    game.applyDialogueLineCommands(line)

proc loadFreetimeStage*(game: var Game, file: string, renderer: SDL_Renderer) = 
  let resolvedFile = resolveGamePath(file)
  if not fileExists(resolvedFile):
    game.hasError = true
    game.errorMessage = "load failed " & file
    echo "================================================================"
    echo "!! engine error; ", file, ", declared in init, unable to load"
    echo "cause: ", game.errorMessage
    echo "================================================================"
    return
  game.objects = loadGameObjects(resolvedFile, renderer)
  game.activeObject = -1
  game.vnActive = false
  game.state = gsExplore
  game.squareClicked = false
  game.stageFinished = false
  game.hasError = false
