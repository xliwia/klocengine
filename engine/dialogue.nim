# engine/dialogue.nim
import std/[json, tables, os]

type
  DialogueLine* = object
    text*: string
    character*: string

  DialogueData* = Table[string, seq[DialogueLine]]

var dialogueData: DialogueData

proc loadDialogueData*(path: string): bool =
  dialogueData = initTable[string, seq[DialogueLine]]()
  if not fileExists(path):
    echo "!! brak pliku dialogow: ", path
    return false
  try:
    let data = parseFile(path)
    for objId, linesNode in data.pairs:
      var lines: seq[DialogueLine]
      for lineNode in linesNode:
        lines.add DialogueLine(
          text: lineNode["text"].getStr,
          character: (if lineNode.hasKey("character"): lineNode["character"].getStr else: "")
        )
      dialogueData[objId] = lines
    return true
  except JsonParsingError as e:
    echo "!! zepsuty JSON w ", path, ": ", e.msg
    return false
  except CatchableError as e:
    echo "!! nie udalo sie wczytac ", path, ": ", e.msg
    return false

proc loadDialogue*(objectId: string): seq[DialogueLine] =
  if dialogueData.hasKey(objectId):
    return dialogueData[objectId]
  return @[DialogueLine(text: "tu nic nie ma", character: "")]