# engine/game.nim
import glm
import dialogue
import std/[json, os]

type
  GameState* = enum gsExplore, gsDialogue

  GameObject* = object
    id*: string
    points*: array[4, Vec3f]
    dialogCamPos*: Vec3f
    rot*: float32
    bounce*: float32
    spinTimer*: float32

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
    stageFinished*: bool
    hasError*: bool
    errorMessage*: string

proc loadGameObjects(path: string): seq[GameObject] =
  if not fileExists(path):
    echo "!! object json files not found: ", path
    return @[]
  try:
    let data = parseFile(path)
    for objNode in data:
      var pts: array[4, Vec3f]
      for i, p in objNode["points"].getElems():
        pts[i] = vec3f(p[0].getFloat, p[1].getFloat, p[2].getFloat)
      let dc = objNode["dialogCamPos"]
      result.add GameObject(
        id: objNode["id"].getStr,
        points: pts,
        dialogCamPos: vec3f(dc[0].getFloat, dc[1].getFloat, dc[2].getFloat)
      )
  except JsonParsingError as e:
    echo "!! corrupted json in ", path, ": ", e.msg
    return @[]
  except CatchableError as e:
    echo "!! couldnt load ", path, ": ", e.msg
    return @[]

proc initGame*(): Game =
  result.state = gsExplore
  result.camPos = vec3f(0f, 0f, 3f)
  result.activeObject = -1
  result.stageFinished = false
  result.hasError = false

proc loadStorylineStage*(game: var Game, file: string) =
  let objs = loadGameObjects("game/objects.json")
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
  game.state = gsExplore
  game.stageFinished = false
  game.hasError = false

proc loadFreetimeStage*(game: var Game, file: string) =
  if not fileExists(file):
    game.hasError = true
    game.errorMessage = "load failed " & file
    echo "================================================================"
    echo "!! engine error; ", file, ", declared in init, unable to load"
    echo "cause: ", game.errorMessage
    echo "================================================================"
    return
  game.objects = loadGameObjects(file)
  game.activeObject = -1
  game.state = gsExplore
  game.stageFinished = false
  game.hasError = false