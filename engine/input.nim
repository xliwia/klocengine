# engine/input.nim
import sdl3
import game, config, math

proc handleEvent*(g: var Game, window: SDL_Window, event: SDL_Event, winW, winH: int32) =
  case event.`type`
  of SDL_EVENT_KEY_DOWN:
    if event.key.key == SDLK_ESCAPE: 
      discard # handled in main
  of SDL_EVENT_MOUSE_MOTION:
    if g.state == gsExplore and not g.skipMouse:
      g.camRot -= float32(event.motion.xrel) * MOUSE_SENS
      const TAU = 6.2831853f
      g.camRot = (g.camRot mod TAU + TAU) mod TAU
    else: g.skipMouse = false
  of SDL_EVENT_MOUSE_BUTTON_DOWN:
    if event.button.button == 1'u8:
      if g.state == gsExplore and g.squareHovered and not g.camAnimating and g.activeObject >= 0:
        discard SDL_SetWindowRelativeMouseMode(window, false)
        g.skipMouse = true
        g.camAnimating = true
        g.camAnimTimer = 0f
        g.objects[g.activeObject].spinTimer = 0f
        g.objects[g.activeObject].rot = 0f
        g.objects[g.activeObject].bounce = 0f
        g.camAnimStartPos = g.camPos
        const TAU = 6.2831853f
        let targetRot = 0f
        var diff = targetRot - g.camRot
        diff = (diff mod TAU + TAU) mod TAU
        if diff > 3.1415927f:
          diff -= TAU
        g.camAnimStartRot = g.camRot
        g.camAnimTargetRot = g.camRot + diff
        g.camAnimTargetPos = g.objects[g.activeObject].dialogCamPos
        g.savedCamPos = g.camPos
        g.savedCamRot = g.camRot
      elif g.state == gsDialogue and g.squareHovered and not g.squareClicked:
        g.squareClicked = true
        g.text = "Tekst w trybie Q!"
        g.textIdx = 0; g.textTimer = 0f
        g.textFinished = false; g.arrowVisible = true
      elif g.state == gsDialogue and g.squareClicked:
        if not g.textFinished:
          g.textIdx = g.text.len
          g.textFinished = true
          g.arrowTimer = 0f
        else:
          if g.waitingAfterLine:
            discard
          else:
            g.currentLine += 1

            if g.currentLine < g.dialogueLines.len:
              let line = g.dialogueLines[g.currentLine]

              if line.wait > 0f:
                g.waitTimer = line.wait
                g.waitingAfterLine = true

                g.text = ""
                g.textIdx = 0
                g.textFinished = true
                g.arrowVisible = false
                g.showDialogueBox = false
              else:
                g.text = line.text
                g.textIdx = 0
                g.textTimer = 0f
                g.textFinished = false
                g.arrowVisible = true
                g.applyDialogueLineCommands(line)

            else:
              if g.pendingStageFile.len > 0:
                g.stageFinished = true
              else:
                g.squareClicked = false
                g.textFinished = false
                g.state = gsExplore
                g.camPos = g.savedCamPos
                g.camRot = g.savedCamRot

                if g.activeObject >= 0 and g.activeObject < g.objects.len:
                  g.objects[g.activeObject].rot = 0f
                  g.objects[g.activeObject].bounce = 0f
                  g.objects[g.activeObject].spinTimer = 0f

                discard SDL_SetWindowRelativeMouseMode(window, true)
                g.skipMouse = true
  else: discard