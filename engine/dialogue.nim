# engine/dialogue.nim
import std/[json, tables, os]

type
  DialogueLine* = object
    speaker*: string
    text*: string
    character*: string

  DialogueData* = Table[string, seq[DialogueLine]]

var dialogueData: DialogueData

proc loadDialogueData*(path: string): bool =
  dialogueData = initTable[string, seq[DialogueLine]]()
  if not fileExists(path):
    echo "!! no dialog file: ", path
    return false
  try:
    let data = parseFile(path)
    proc parseObj(objNode: JsonNode) =
      for objId, linesNode in objNode.pairs:
        var lines: seq[DialogueLine]
        if linesNode.kind != JArray:
          raise newException(ValueError, "dialogue lines must be an array")
        for lineNode in linesNode:
          lines.add DialogueLine(
            text: lineNode["text"].getStr,
            speaker: (if lineNode.hasKey("speaker"): lineNode["speaker"].getStr else: ""),
            character: (if lineNode.hasKey("character"): lineNode["character"].getStr else: "")
          )
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
    echo "!! corrupted json ", path, ": ", e.msg
    return false
  except CatchableError as e:
    echo "!! cant load ", path, ": ", e.msg
    return false

proc loadDialogue*(objectId: string): seq[DialogueLine] =
  if dialogueData.hasKey(objectId):
    return dialogueData[objectId]
  return @[DialogueLine(text: "nothing here", speaker: "", character: "")]
