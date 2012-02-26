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

    ' Set up audio player, using the same message port
    obj.audioPlayer = CreateObject("roAudioPlayer")
    obj.audioPlayer.SetMessagePort(obj.Screen.GetMessagePort())

    ' TODO: Do we want to loop? Always/Sometimes/Never/Preference?
    obj.audioPlayer.SetLoop(context.Count() > 1)

    obj.audioPlayer.SetContentList(context)
    obj.audioPlayer.SetNext(index)

    obj.AddButtons = audioAddButtons
    obj.GetMediaDetails = audioGetMediaDetails
    obj.HandleMessage = audioHandleMessage

    return obj
End Function

Function showSpringboardScreen() As Integer
    server = m.Item.server
    m.Refresh()

    while true
        msg = wait(m.msgTimeout, m.Screen.GetMessagePort())
        if m.HandleMessage(msg) then
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

Function sbRefresh()
    ' Don't show any sort of facade or loading dialog. We already have the
    ' metadata for all of our siblings, we don't have to fetch anything, and
    ' so the new screen usually comes up immediately. The dialog with the
    ' spinner ends up just flashing on the screen and being annoying.
    m.Screen.SetContent(invalid)

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
    m.buttonCommands = m.AddButtons(m.Screen, m.metadata, m.media)
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

Function videoAddButtons(screen, metadata, media) As Object
    buttonCommands = CreateObject("roAssociativeArray")
    screen.ClearButtons()
    buttonCount = 0
    if metadata.viewOffset <> invalid then
        intervalInSeconds = fix(val(metadata.viewOffset)/(1000))
        resumeTitle = "Resume from "+TimeDisplay(intervalInSeconds)
        screen.AddButton(buttonCount, resumeTitle)
        buttonCommands[str(buttonCount)] = "resume"
        buttonCount = buttonCount + 1
    endif
    screen.AddButton(buttonCount, "Play")
    buttonCommands[str(buttonCount)] = "play"
    buttonCount = buttonCount + 1

    print "Media = ";media
    print "metadata.optimizedForStreaming = ";metadata.optimizedForStreaming

    if media.container <> invalid AND media.videocodec <> invalid AND media.audiocodec <> invalid AND metadata.optimizedforstreaming <> invalid then
        dsp = 0
        ' MP4 files
        if media.container = "mov" then
            if media.videocodec = "h264" AND (media.audiocodec = "aac" OR media.audicodec = "ac3") then
                dsp = 1
            end if
        end if
        ' MKV files
        if media.container = "mkv" then
            if media.videocodec = "h264" AND (media.audiocodec = "aac" OR media.audicodec = "ac3") then
                dsp = 1
            end if
        end if

        if metadata.optimizedForStreaming = "0" AND dsp = 1 then
            print "Container = "+media.container+", ac = "+media.audiocodec+", vc = "+media.videocodec+", but not optimized for streaming"
            dsp = 0
        else if dsp = 1 then
            print "Container = "+media.container+", ac = "+media.audiocodec+", vc = "+media.videocodec+", OPTIMIZED FOR STREAMING"
        end if
    end if

    if metadata.viewCount <> invalid AND val(metadata.viewCount) > 0 then
        screen.AddButton(buttonCount, "Mark as unwatched")
        buttonCommands[str(buttonCount)] = "unscrobble"
        buttonCount = buttonCount + 1
    else
        if metadata.viewOffset <> invalid AND val(metadata.viewOffset) > 0 then
            screen.AddButton(buttonCount, "Mark as unwatched")
            buttonCommands[str(buttonCount)] = "unscrobble"
            buttonCount = buttonCount + 1
        end if
        screen.AddButton(buttonCount, "Mark as watched")
        buttonCommands[str(buttonCount)] = "scrobble"
        buttonCount = buttonCount + 1
    end if

    mediaPart = media.preferredPart
    subtitleStreams = []
    audioStreams = []
    for each Stream in mediaPart.streams
        if Stream.streamType = "2" then
            audioStreams.Push(Stream)
        else if Stream.streamType = "3" then
            subtitleStreams.Push(Stream)
        endif
    next
    print "Found audio streams:";audioStreams.Count()
    print "Found subtitle streams:";subtitleStreams.Count()
    if audioStreams.Count() > 1 then
        screen.AddButton(buttonCount, "Select audio stream")
        buttonCommands[str(buttonCount)] = "audioStreamSelection"
        buttonCount = buttonCount + 1
    endif
    if subtitleStreams.Count() > 0 then
        screen.AddButton(buttonCount, "Select subtitles")
        buttonCommands[str(buttonCount)] = "subtitleStreamSelection"
        buttonCount = buttonCount + 1
    endif

    if metadata.UserRating = invalid then
        metadata.UserRating = 0
    endif
    if metadata.StarRating = invalid then
        metadata.StarRating = 0
    endif
    screen.AddRatingButton(buttonCount, metadata.UserRating, metadata.StarRating)
    buttonCommands[str(buttonCount)] = "rateVideo"
    buttonCount = buttonCount + 1
    return buttonCommands
End Function

Function audioAddButtons(screen, metadata, media) As Object
    ' TODO(schuyler): This is totally bogus placeholder stuff. Flesh it
    ' out and update based on the current item and state. They're also
    ' not really wired up to the message loop meaningfully.

    buttonCommands = CreateObject("roAssociativeArray")
    screen.ClearButtons()
    buttonCount = 0

    screen.AddButton(buttonCount, "Play")
    buttonCommands[str(buttonCount)] = "play"
    buttonCount = buttonCount + 1

    screen.AddButton(buttonCount, "Next Song")
    buttonCommands[str(buttonCount)] = "next"
    buttonCount = buttonCount + 1

    screen.AddButton(buttonCount, "Previous Song")
    buttonCommands[str(buttonCount)] = "prev"
    buttonCount = buttonCount + 1

    return buttonCommands
End Function

Function photoAddButtons(screen, metadata, media) As Object
    ' TODO(schuyler): This is totally bogus placeholder stuff. Flesh it
    ' out and update based on the current item and state. They're also
    ' not really wired up to the message loop meaningfully.

    buttonCommands = CreateObject("roAssociativeArray")
    screen.ClearButtons()
    buttonCount = 0

    screen.AddButton(buttonCount, "Show")
    buttonCommands[str(buttonCount)] = "show"
    buttonCount = buttonCount + 1

    screen.AddButton(buttonCount, "Slideshow")
    buttonCommands[str(buttonCount)] = "slideshow"
    buttonCount = buttonCount + 1

    screen.AddButton(buttonCount, "Next Photo")
    buttonCommands[str(buttonCount)] = "next"
    buttonCount = buttonCount + 1

    screen.AddButton(buttonCount, "Previous Photo")
    buttonCommands[str(buttonCount)] = "prev"
    buttonCount = buttonCount + 1

    if metadata.UserRating = invalid then
        metadata.UserRating = 0
    endif
    if metadata.StarRating = invalid then
        metadata.StarRating = 0
    endif
    screen.AddRatingButton(buttonCount, metadata.UserRating, metadata.StarRating)
    buttonCommands[str(buttonCount)] = "ratePhoto"
    buttonCount = buttonCount + 1

    return buttonCommands
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

Function videoHandleMessage(msg) As Boolean
    server = m.Item.server

    if msg.isButtonPressed() then
        buttonCommand = m.buttonCommands[str(msg.getIndex())]
        print "Button command: ";buttonCommand
        if buttonCommand = "play" OR buttonCommand = "resume" then
            startTime = 0
            if buttonCommand = "resume" then
                startTime = int(val(m.metadata.viewOffset))
            endif
            playVideo(server, m.metadata, m.media, startTime)
            '* Refresh play data after playing
            m.Refresh()
        else if buttonCommand = "audioStreamSelection" then
            SelectAudioStream(server, m.media)
            m.Refresh()
        else if buttonCommand = "subtitleStreamSelection" then
            SelectSubtitleStream(server, m.media)
            m.Refresh()
        else if buttonCommand = "scrobble" then
            'scrobble key here
            server.Scrobble(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier)
            '* Refresh play data after scrobbling
            m.Refresh()
        else if buttonCommand = "unscrobble" then
            'unscrobble key here
            server.Unscrobble(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier)
            '* Refresh play data after unscrobbling
            m.Refresh()
	 else if buttonCommand = "rateVideo" then                
		rateValue% = msg.getData() /10
		m.metadata.UserRating = msg.getdata()
		server.Rate(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier,rateValue%.ToStr())
        else
            return false
        endif

        return true
    end if

    return false
End Function

Function audioHandleMessage(msg) As Boolean
    ' TODO(schuyler) Actually handle all of these
    if type(msg) = "roAudioPlayerEvent" then
        if msg.isRequestSucceeded() then
            Print "Playback of single song completed"
        else if msg.isRequestFailed() then
            Print "Playback failed"
        else if msg.isListItemSelected() then
            Print "Starting to play item"
            ' What does this actually mean? How is it triggered?
            'm.audioPlayer.Play()
        else if msg.isStatusMessage() then
            Print "Audio player status: "; msg.getMessage()
        else if msg.isFullResult() then
            Print "Playback of entire list finished"
        else if msg.isPartialResult() then
            Print "isPartialResult"
        else if msg.isPaused() then
            Print "Stream paused by user"
        else if msg.isResumed() then
            Print "Stream resumed by user"
        end if
        return true
    else if msg.isButtonPressed() then
        buttonCommand = m.buttonCommands[str(msg.getIndex())]
        print "Button command: ";buttonCommand
        if buttonCommand = "play" then
            m.audioPlayer.Play()
        else if buttonCommand = "pause" then
            m.audioPlayer.Pause()
        else if buttonCommand = "stop" then
            m.audioPlayer.Stop()
        else if buttonCommand = "resume" then
            m.audioPlayer.Resume()
        else if buttonCommand = "next" then
        else if buttonCommand = "prev" then
        else
            return false
        end if
        return true
    end if

    return false
End Function

Function photoHandleMessage(msg) As Boolean
    server = m.Item.server
    port = CreateObject("roMessagePort")

    if msg.isButtonPressed() then
        buttonCommand = m.buttonCommands[str(msg.getIndex())]
        print "Button command: ";buttonCommand
        if buttonCommand = "show" then
            Print "photoHandleMessage:: Show photo fullscreen"
            url = FullUrl(m.item.server.serverurl, m.item.sourceurl, m.item.media[0].parts[0].key)
            'Print "Url = ";url2
            slideshow = SlideShowSetup(port, 5.0, "#6b4226", 6)
            pl = CreateObject("roList")
            pl.Push(url)
            DisplaySlideShow(port, slideshow, pl)
        else if buttonCommand = "slideshow" then
            Print "photoHandleMessage:: Start slideshow"
            list = GetPhotoList(m.item.server.serverurl, m.item.sourceurl)
            slideshow = SlideShowSetup(port, 5.0, "#6b4226", 6)
            DisplaySlideShow(port, slideshow, list)
        else if buttonCommand = "next" then
            Print "photoHandleMessage:: show next photo"
             m.GotoNextItem()
        else if buttonCommand = "prev" then
            Print "photoHandleMessage:: show previous photo"
             m.GotoPrevItem()
	    else if buttonCommand = "ratePhoto" then                
            Print "photoHandleMessage:: Rate photo for key ";m.metadata.ratingKey
		    rateValue% = (msg.getData() /10)
		    m.metadata.UserRating = msg.getdata()
            if m.metadata.ratingKey = invalid then
                m.metadata.ratingKey = 0
            end if
		    server.Rate(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier,rateValue%.ToStr())
        else
            return false
        end if

        return true
    end if

    return false
End Function

