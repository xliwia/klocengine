# engine/dialogue.nim
import tables

type
  DialogueLine* = object
    text*: string
    character*: string 

  DialogueData* = Table[string, seq[DialogueLine]]

proc loadDialogue*(objectId: string): seq[DialogueLine] =
  case objectId:
  of "square_0":
    @[
      DialogueLine(text: "elo", character: ""),
      DialogueLine(text: "asasa", character: "")
    ]
  of "square_1":
    @[
      DialogueLine(text: "dhfdfh", character: ""),
      DialogueLine(text: "hfdfdhfd", character: ""),
      DialogueLine(text: "dfhfdhfdh", character: "")
    ]
  of "asd":
    @[
      DialogueLine(text: "kfgfdgfdfgdafgdaagfdgfadsagafrgfasdagfasgfsgfdsfhgfdsyhdfgh", character: ""),
    ]
  of "test":
    @[
      DialogueLine(text: "siusiak", character: ""),
      DialogueLine(text: "afdgaafgd", character: "agdfgdfad")
    ]
  else:
    @[DialogueLine(text: "tu nic nie ma", character: "")]