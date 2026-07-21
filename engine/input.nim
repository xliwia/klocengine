# engine/input.nim
import sdl3
import game, config, math

proc handleEvent*(g: var Game, window: SDL_Window, event: SDL_Event, winW, winH: int32) =
  case event.`type`

  of SDL_EVENT_KEY_DOWN:
    if event.key.key == SDLK_ESCAPE:
      discard


  of SDL_EVENT_MOUSE_MOTION:

    if g.state == gsExplore and not g.skipMouse:

      g.camRot -= float32(event.motion.xrel) * MOUSE_SENS

      const TAU = 6.2831853f
      g.camRot = (g.camRot mod TAU + TAU) mod TAU


    elif g.state == gsMenu:

      let mx = float32(event.motion.x)
      let my = float32(event.motion.y)

      g.menuHovered = -1

      var y = float32(winH) * 0.4f

      for i in 0 ..< g.menuScene.items.len:

        let x = float32(winW) * 0.35f

        if mx >= x and mx <= x + float32(winW)*0.3f and
           my >= y and my <= y + 50f:

          g.menuHovered = i

        y += 70f


    else:
      g.skipMouse = false



  of SDL_EVENT_MOUSE_BUTTON_DOWN:

    if event.button.button == 1'u8:


      # MENU
      if g.state == gsMenu:

        if g.menuHovered >= 0:

          let item = g.menuScene.items[g.menuHovered]

          case item.action

          of "switchseq":

            g.pendingStageFile = item.target
            g.pendingStageKind = item.targetType
            g.stageFinished = true


          of "quit":

            g.stageFinished = true


          else:
            discard



      # EXPLORE 3D
      elif g.state == gsExplore:

        if g.squareHovered and not g.camAnimating and g.activeObject >= 0:
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



      # DIALOGUE
      elif g.state == gsDialogue:

        if g.squareHovered and not g.squareClicked:

          g.squareClicked = true
          g.text = "Tekst w trybie Q!"
          g.textIdx = 0
          g.textTimer = 0f
          g.textFinished = false
          g.arrowVisible = true


        elif g.squareClicked:

          if not g.textFinished:

            g.textIdx = g.text.len
            g.textFinished = true
            g.arrowTimer = 0f


          elif not g.waitingAfterLine:

            g.currentLine += 1

            if g.currentLine < g.dialogueLines.len:

              let line = g.dialogueLines[g.currentLine]

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


  else:
    discard