'*
'* Springboard screens on top of which audio/video players are used.
'*

Function createBaseSpringboardScreen(context, index, viewController) As Object
    obj = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")
    screen.SetMessagePort(port)

    ' Standard properties for all our Screen types
    obj.Item = context[index]
    obj.Screen = screen
    obj.Port = port
    obj.ViewController = viewController

    ' Some properties that allow us to move between items in whatever
    ' container got us to this point.
    obj.Context = context
    obj.CurIndex = index
    obj.AllowLeftRight = context.Count() > 1
    obj.WrapLeftRight = obj.AllowLeftRight

    obj.Show = showSpringboardScreen
    obj.Refresh = sbRefresh
    obj.GotoNextItem = sbGotoNextItem
    obj.GotoPrevItem = sbGotoPrevItem

    obj.msgTimeout = 0

    return obj
End Function

Function createPhotoSpringboardScreen(context, index, viewController) As Object
    obj = createBaseSpringboardScreen(context, index, viewController)

    obj.AddButtons = photoAddButtons
    obj.GetMediaDetails = photoGetMediaDetails
    obj.HandleMessage = photoHandleMessage
    
    return obj
End Function

Function createVideoSpringboardScreen(context, index, viewController) As Object
    obj = createBaseSpringboardScreen(context, index, viewController)

    obj.AddButtons = videoAddButtons
    obj.GetMediaDetails = videoGetMediaDetails
    obj.HandleMessage = videoHandleMessage
    
    return obj
End Function

Function createAudioSpringboardScreen(context, index, viewController) As Object
    obj = createBaseSpringboardScreen(context, index, viewController)

    obj.Screen.SetDescriptionStyle("audio")
    obj.Screen.SetStaticRatingEnabled(false)
    obj.Screen.AllowNavRewind(true)
    obj.Screen.AllowNavFastForward(true)
    obj.Screen.setProgressIndicatorEnabled(true)

    ' Set up audio player, using the same message port
    obj.audioPlayer = CreateObject("roAudioPlayer")
    obj.audioPlayer.SetMessagePort(obj.Screen.GetMessagePort())
    if obj.Item.server.AccessToken <> invalid then
        obj.audioPlayer.AddHeader("X-Plex-Token", obj.Item.server.AccessToken)
    end if
    obj.isPlayState = 0   ' Stopped
    obj.setPlayState = audioPlayer_newstate

    ' TODO: Do we want to loop? Always/Sometimes/Never/Preference?
    obj.audioPlayer.SetLoop(context.Count() > 1)

    obj.audioPlayer.SetContentList(context)
    obj.audioPlayer.SetNext(index)

    obj.AddButtons      = audioPlayer_setbuttons
    obj.GetMediaDetails = audioGetMediaDetails
    obj.HandleMessage   = audioHandleMessage
    obj.setPlayState(2) ' start playback when screen is opened

    return obj
End Function

Function showSpringboardScreen() As Integer
    server = m.Item.server
    m.Refresh()

    while true
        msg = wait(m.msgTimeout, m.Screen.GetMessagePort())
        if m.HandleMessage(msg) then
        else if msg = invalid then
            m.msgTimeout = 0
        else if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
            return -1
        else if msg.isButtonPressed() then
            buttonCommand = m.buttonCommands[str(msg.getIndex())]
            print "Unhandled button press: "; buttonCommand
        else if msg.isRemoteKeyPressed() then
            '* index=4 -> left ; index=5 -> right
            if msg.getIndex() = 4 then
                m.GotoPrevItem()
            else if msg.getIndex() = 5 then
                m.GotoNextItem()
            endif
        endif
    end while

    return 0
End Function

Function sbRefresh(force=false)
    ' Don't show any sort of facade or loading dialog. We already have the
    ' metadata for all of our siblings, we don't have to fetch anything, and
    ' so the new screen usually comes up immediately. The dialog with the
    ' spinner ends up just flashing on the screen and being annoying.
    m.Screen.SetContent(invalid)

    if force then m.Item.Refresh(true)
    m.GetMediaDetails(m.Item)

    if m.AllowLeftRight then
        if m.WrapLeftRight then
            m.Screen.AllowNavLeft(true)
            m.Screen.AllowNavRight(true)
        else
            m.Screen.AllowNavLeft(m.CurIndex > 0)
            m.Screen.AllowNavRight(m.CurIndex < m.Context.Count() - 1)
        end if
    end if

    m.Screen.setContent(m.metadata)
    m.buttonCommands = m.AddButtons(m)
    if m.metadata.SDPosterURL <> invalid and m.metadata.HDPosterURL <> invalid then
        m.Screen.PrefetchPoster(m.metadata.SDPosterURL, m.metadata.HDPosterURL)
    endif
    m.Screen.Show()
End Function

'* Show a dialog allowing user to select from all available subtitle streams
Function SelectSubtitleStream(server, media)
    port = CreateObject("roMessagePort")
    dialog = CreateObject("roMessageDialog")
    dialog.SetMessagePort(port)
    dialog.SetMenuTopLeft(true)
    dialog.EnableBackButton(true)
    dialog.SetTitle("Select Subtitle")
    mediaPart = media.preferredPart
    selected = false
    for each Stream in mediaPart.streams
        if Stream.streamType = "3" AND Stream.selected <> invalid then
            selected = true
        endif
    next
    noSelectionTitle = "No Subtitles"
    if not selected then
        noSelectionTitle = "> "+noSelectionTitle
    endif

    buttonCommands = CreateObject("roAssociativeArray")
    buttonCount = 0
    dialog.AddButton(buttonCount, noSelectionTitle)
    buttonCommands[str(buttonCount)+"_id"] = ""
    buttonCount = buttonCount + 1
    for each Stream in mediaPart.streams
        if Stream.streamType = "3" then
            buttonTitle = "Unknown"
            if Stream.Language <> Invalid then
                buttonTitle = Stream.Language
            endif
            if Stream.Language <> Invalid AND Stream.Codec <> Invalid AND Stream.Codec = "srt" then
                buttonTitle = Stream.Language + " (*)"
            else if Stream.Codec <> Invalid AND Stream.Codec = "srt" then
                buttonTitle = "Unknown (*)"
            endif
            if Stream.selected <> invalid then
                buttonTitle = "> " + buttonTitle
            endif
            dialog.AddButton(buttonCount, buttonTitle)
            buttonCommands[str(buttonCount)+"_id"] = Stream.Id
            buttonCount = buttonCount + 1
        endif
    next
    dialog.Show()
    while true
        msg = wait(0, dialog.GetMessagePort())
        if type(msg) = "roMessageDialogEvent"
            if msg.isScreenClosed() then
                dialog.close()
                exit while
            else if msg.isButtonPressed() then
                print "Button pressed:";msg.getIndex()
                streamId = buttonCommands[str(msg.getIndex())+"_id"]
                print "Media part "+media.preferredPart.id
                print "Selected subtitle "+streamId
                server.UpdateSubtitleStreamSelection(media.preferredPart.id, streamId)
                dialog.close()
            end if
        end if
    end while
End Function

'* Show a dialog allowing user to select from all available subtitle streams
Function SelectAudioStream(server, media)
    port = CreateObject("roMessagePort")
    dialog = CreateObject("roMessageDialog")
    dialog.SetMessagePort(port)
    dialog.SetMenuTopLeft(true)
    dialog.EnableBackButton(true)
    dialog.SetTitle("Select Audio Stream")
    mediaPart = media.preferredPart
    buttonCommands = CreateObject("roAssociativeArray")
    buttonCount = 0
    for each Stream in mediaPart.streams
        if Stream.streamType = "2" then
            buttonTitle = "Unkwown"
            if Stream.Language <> Invalid then
                buttonTitle = Stream.Language
            endif
            subtitle = invalid
            if Stream.Codec <> invalid then
                if Stream.Codec = "dca" then
                    subtitle = "DTS"
                else
                    subtitle = ucase(Stream.Codec)
                endif
            endif
            if Stream.Channels <> invalid then
                if Stream.Channels = "2" then
                    subtitle = subtitle + " Stereo"
                else if Stream.Channels = "6" then
                    subtitle = subtitle + " 5.1"
                else if Stream.Channels = "8" then
                    subtitle = subtitle + " 7.1"
                endif
            endif
            if subtitle <> invalid then
                buttonTitle = buttonTitle + " ("+subtitle+")"
            endif
            if Stream.selected <> invalid then
                buttonTitle = "> " + buttonTitle
            endif
            dialog.AddButton(buttonCount, buttonTitle)
            buttonCommands[str(buttonCount)+"_id"] = Stream.Id
            buttonCount = buttonCount + 1
        endif
    next
    dialog.Show()
    while true
        msg = wait(0, dialog.GetMessagePort())
        if type(msg) = "roMessageDialogEvent"
            if msg.isScreenClosed() then
                dialog.close()
                exit while
            else if msg.isButtonPressed() then
                streamId = buttonCommands[str(msg.getIndex())+"_id"]
                print "Media part "+media.preferredPart.id
                print "Selected audio stream "+streamId
                server.UpdateAudioStreamSelection(media.preferredPart.id, streamId)
                dialog.close()
            end if
        end if
    end while
End Function

Function TimeDisplay(intervalInSeconds) As String
    hours = fix(intervalInSeconds/(60*60))
    remainder = intervalInSeconds - hours*60*60
    minutes = fix(remainder/60)
    seconds = remainder - minutes*60
    hoursStr = hours.tostr()
    if hoursStr.len() = 1 then
        hoursStr = "0"+hoursStr
    endif
    minsStr = minutes.tostr()
    if minsStr.len() = 1 then
        minsStr = "0"+minsStr
    endif
    secsStr = seconds.tostr()
    if secsStr.len() = 1 then
        secsStr = "0"+secsStr
    endif
    return hoursStr+":"+minsStr+":"+secsStr
End Function

Function sbGotoNextItem() As Boolean
    if NOT m.AllowLeftRight then return false

    maxIndex = m.Context.Count() - 1
    index = m.CurIndex
    newIndex = index

    if index < maxIndex then
        newIndex = index + 1
    else if m.WrapLeftRight then
        newIndex = 0
    end if

    if index <> newIndex then
        m.CurIndex = newIndex
        m.Item = m.Context[newIndex]
        m.Refresh()
        return true
    end if

    return false
End Function

Function sbGotoPrevItem() As Boolean
    if NOT m.AllowLeftRight then return false

    maxIndex = m.Context.Count() - 1
    index = m.CurIndex
    newIndex = index

    if index > 0 then
        newIndex = index - 1
    else if m.WrapLeftRight then
        newIndex = maxIndex
    end if

    if index <> newIndex then
        m.CurIndex = newIndex
        m.Item = m.Context[newIndex]
        m.Refresh()
        return true
    end if

    return false
End Function

Sub videoGetMediaDetails(content)
    server = content.server
    print "About to fetch meta-data for Content Type: "; content.contentType

    m.metadata = content.ParseDetails()
    m.media = m.metadata.preferredMediaItem
End Sub

Sub audioGetMediaDetails(content)
    m.metadata = content
    m.media = invalid
End Sub

Sub photoGetMediaDetails(content)
    m.metadata = content
    m.media = invalid
End Sub

