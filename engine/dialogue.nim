# engine/dialogue.nim
import std/[json, tables, os]

type
  DialogueCommand* = object
    name*: string
    args*: seq[string]

  DialogueLine* = object
    speaker*: string
    text*: string
    character*: string
    commands*: seq[DialogueCommand]
    textSpeed*: float32
    instant*: bool
    wait*: float32
    voice*: string
    sfx*: string
    
  DialogueData* = Table[string, seq[DialogueLine]]

var dialogueData: DialogueData

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

proc resolveDialoguePath(path: string): string =
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

proc loadDialogueData*(path: string): bool =
  let resolvedPath = resolveDialoguePath(path)
  dialogueData = initTable[string, seq[DialogueLine]]()
  if not fileExists(resolvedPath):
    echo "!! no dialog file: ", path, " (resolved: ", resolvedPath, ")"
    return false
  try:
    let data = parseFile(resolvedPath)
    proc parseObj(objNode: JsonNode) =
      for objId, linesNode in objNode.pairs:
        var lines: seq[DialogueLine]
        if linesNode.kind != JArray:
          raise newException(ValueError, "dialogue lines must be an array")
        for lineNode in linesNode:
          var cmdSeq: seq[DialogueCommand]
          if lineNode.hasKey("commands"):
            for cmdNode in lineNode["commands"]:
              var args: seq[string]
              if cmdNode.hasKey("args"):
                for argNode in cmdNode["args"]:
                  args.add argNode.getStr
              cmdSeq.add DialogueCommand(name: cmdNode["name"].getStr, args: args)

          var line = DialogueLine(
            text: lineNode["text"].getStr,
            speaker: (if lineNode.hasKey("speaker"): lineNode["speaker"].getStr else: ""),
            character: (if lineNode.hasKey("character"): lineNode["character"].getStr else: ""),
            commands: cmdSeq,
            textSpeed: (if lineNode.hasKey("textSpeed"): lineNode["textSpeed"].getFloat else: 0f),
            instant: (if lineNode.hasKey("instant"): lineNode["instant"].getBool else: false)
          )
          lines.add line
        dialogueData[objId] = lines

    case data.kind
    of JObject:
      parseObj(data)
    of JArray:
      for item in data:
        if item.kind == JObject:
          parseObj(item)
        else:
          raise newException(ValueError, "expected object entries inside array")
    else:
      raise newException(ValueError, "dialogue file must be an object or array")

    return true
  except JsonParsingError as e:
    echo "!! corrupted json ", resolvedPath, ": ", e.msg
    return false
  except CatchableError as e:
    echo "!! cant load ", resolvedPath, ": ", e.msg
    return false

proc loadDialogue*(objectId: string): seq[DialogueLine] =
  if dialogueData.hasKey(objectId):
    return dialogueData[objectId]
  return @[DialogueLine(text: "nothing here", speaker: "", character: "")]
