# engine/game.nim
import glm
import dialogue

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


proc initGame*(): Game =
  result.state = gsExplore
  result.camPos = vec3f(0f, 0f, 3f)
  result.activeObject = -1
  result.objects = @[
    GameObject(
      id: "square_0",
      points: [vec3f(-0.5f, -0.5f, 0f), vec3f(0.5f, -0.5f, 0f), vec3f(0.5f, 0.5f, 0f), vec3f(-0.5f, 0.5f, 0f)],
      dialogCamPos: vec3f(0f, 0f, 4f)
    ),
    GameObject(
      id: "square_1",
      points: [vec3f(1.5f, -0.5f, 0f), vec3f(2.5f, -0.5f, 0f), vec3f(2.5f, 0.5f, 0f), vec3f(1.5f, 0.5f, 0f)],
      dialogCamPos: vec3f(2f, 0f, 4f)
    ),
    GameObject(
      id: "asd",
      points: [vec3f(2.5f, -0.5f, 0f), vec3f(4.5f, -0.5f, 0f), vec3f(4.5f, 0.5f, 0f), vec3f(2.5f, 0.5f, 0f)],
      dialogCamPos: vec3f(2f, 0f, 4f)
    )
  ]