'*
'* Springboard screens on top of which audio/video players are used.
'*

Function itemIsRefreshable(item) As Boolean
    return item.refresh <> invalid
End Function

Function createBaseSpringboardScreen(context, index, viewController, includePredicate=itemIsRefreshable) As Object
    obj = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")
    screen.SetMessagePort(port)

    ' Filter out anything in the context that can't be shown on a springboard.
    contextCopy = []
    i = 0
    offset = 0
    for each item in context
        if includePredicate(item) then
            contextCopy.Push(item)
            item.OrigIndex = i - offset
        else if i < index then
            offset = offset + 1
        end if
        i = i + 1
    next

    index = index - offset

    ' Standard properties for all our Screen types
    obj.Item = contextCopy[index]
    obj.Screen = screen
    obj.Port = port
    obj.ViewController = viewController

    ' Some properties that allow us to move between items in whatever
    ' container got us to this point.
    obj.Context = contextCopy
    obj.CurIndex = index
    obj.AllowLeftRight = contextCopy.Count() > 1
    obj.WrapLeftRight = obj.AllowLeftRight

    obj.Show = showSpringboardScreen
    obj.Refresh = sbRefresh
    obj.GotoNextItem = sbGotoNextItem
    obj.GotoPrevItem = sbGotoPrevItem

    obj.msgTimeout = 0

    ' Stretched and cropped posters both look kind of terrible, so zoom.
    screen.SetDisplayMode("zoom-to-fill")

    return obj
End Function

Function itemIsPhoto(item) As Boolean
    return item.NodeName = "Photo"
End Function

Function createPhotoSpringboardScreen(context, index, viewController) As Object
    obj = createBaseSpringboardScreen(context, index, viewController, itemIsPhoto)

    obj.AddButtons = photoAddButtons
    obj.GetMediaDetails = photoGetMediaDetails
    obj.HandleMessage = photoHandleMessage
    obj.CreateSlideShow = photoCreateSlideShow

    return obj
End Function

Function photoCreateSlideShow() As Object
    slideshow = CreateObject("roSlideShow")
    slideshow.SetMessagePort(m.Port)
    slideshow.SetUnderscan(2.5)
    slideshow.SetMaxUpscale(8.0)
    slideshow.SetDisplayMode("photo-fit")
    slideshow.SetPeriod(RegRead("slideshow_period", "preferences", "6").toInt())
    slideshow.SetTextOverlayHoldTime(RegRead("slideshow_overlay", "preferences", "2500").toInt())
    if m.Item.server.AccessToken <> invalid then
        slideshow.AddHeader("X-Plex-Token", m.Item.server.AccessToken)
    end if

    return slideshow
End Function

Function createVideoSpringboardScreen(context, index, viewController) As Object
    obj = createBaseSpringboardScreen(context, index, viewController)

    ' Our item's content-type affects the poster dimensions here, so treat
    ' clips as episodes.
    if obj.Item.ContentType = "clip" then
        obj.Item.ContentType = "episode"
    end if

    obj.AddButtons = videoAddButtons
    obj.GetMediaDetails = videoGetMediaDetails
    obj.HandleMessage = videoHandleMessage
    obj.PlayVideo = playVideo

    obj.PlayButtonStates = [
        {label: "Play", value: 0},
        {label: "Direct Play", value: 1},
        {label: "Direct Play w/ Fallback", value: 2},
        {label: "Direct Stream/Transcode", value: 3},
        {label: "Play Transcoded", value: 4}
    ]
    obj.PlayButtonState = RegRead("directplay", "preferences", "0").toint()

    obj.OrigQuality = RegRead("quality", "preferences", "7")
    
    return obj
End Function

Sub SwapArray(arr, i, j)
    if i <> j then
        temp = arr[i]
        arr[i] = arr[j]
        arr[j] = temp
    end if
End Sub

Sub audioShuffle(arr)
    ' Our context is already a copy of the original, so we can safely shuffle
    ' in place. Mixing up the list means that all the navigation will work as
    ' expected without needing a bunch of special logic elsewhere.

    ' Start by moving the current song to the front so we can easily play it.
    SwapArray(m.Context, 0, m.CurIndex)
    m.CurIndex = 0

    for i = m.Context.Count() - 1 to 1 step -1
        ' Note that we're only looping to 1, and Rnd doesn't return 0, so
        ' the item we put at 0 will be left untouched.
        SwapArray(m.Context, i, Rnd(i))
    next

    m.audioPlayer.SetContentList(m.Context)
    m.audioPlayer.SetNext(m.CurIndex + 1)
End Sub

Sub audioUnshuffle(arr)
    for i = 0 to m.Context.Count() - 1
        SwapArray(m.Context, i, m.Context[i].OrigIndex)
    next
    m.CurIndex = m.Item.OrigIndex

    m.audioPlayer.SetContentList(m.Context)
    m.audioPlayer.SetNext(m.CurIndex + 1)
End Sub

Function createAudioSpringboardScreen(context, index, viewController) As Dynamic
    obj = createBaseSpringboardScreen(context, index, viewController)

    obj.Screen.SetDescriptionStyle("audio")
    obj.Screen.SetStaticRatingEnabled(false)
    obj.Screen.AllowNavRewind(true)
    obj.Screen.AllowNavFastForward(true)
    obj.Screen.setProgressIndicatorEnabled(true)

    ' Grid screens get corrupted when audio players are created, so tell the
    ' controller to destroy and recreate them.
    viewController.DestroyGlitchyScreens()

    ' Set up audio player, using the same message port
    obj.audioPlayer = CreateObject("roAudioPlayer")
    obj.audioPlayer.SetMessagePort(obj.Screen.GetMessagePort())
    if obj.Item.server.AccessToken <> invalid then
        obj.audioPlayer.AddHeader("X-Plex-Token", obj.Item.server.AccessToken)
    end if
    obj.isPlayState = 0   ' Stopped
    obj.setPlayState = audioPlayer_newstate

    ' TODO: Do we want to loop? Always/Sometimes/Never/Preference?
    obj.audioPlayer.SetLoop(obj.Context.Count() > 1)

    obj.IsShuffled = false
    obj.Shuffle = audioShuffle
    obj.Unshuffle = audioUnshuffle

    obj.audioPlayer.SetContentList(obj.Context)
    obj.audioPlayer.SetNext(obj.CurIndex)

    obj.AddButtons      = audioPlayer_setbuttons
    obj.GetMediaDetails = audioGetMediaDetails
    obj.HandleMessage   = audioHandleMessage

    ' In there isn't a single playable item in the list then the Roku has
    ' been observed to die a horrible death.
    obj.IsPlayable = false
    for i = obj.CurIndex to obj.Context.Count() - 1
        url = obj.Context[i].Url
        if url <> invalid AND url <> "" then
            obj.IsPlayable = true
            obj.audioPlayer.SetNext(i)
            obj.Item = obj.Context[i]
            exit for
        end if
    next

    if obj.IsPlayable then
        obj.setPlayState(2) ' start playback when screen is opened
    else
        dialog = createBaseDialog()
        dialog.Title = "Unsupported Format"
        dialog.Text = "None of the audio tracks in this list are in a supported format. Use MP3s for best results."
        dialog.Show()
        return invalid
    end if

    obj.progressTimer = CreateObject("roTimespan")
    obj.progressOffset = 0

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
            exit while
        else if msg.isButtonPressed() then
            buttonCommand = m.buttonCommands[str(msg.getIndex())]
            Debug("Unhandled button press: " + tostr(buttonCommand))
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
    m.Screen.AllowUpdates(false)
    m.buttonCommands = m.AddButtons(m)
    m.Screen.AllowUpdates(true)
    if m.metadata.SDPosterURL <> invalid and m.metadata.HDPosterURL <> invalid then
        m.Screen.PrefetchPoster(m.metadata.SDPosterURL, m.metadata.HDPosterURL)
        SaveImagesForScreenSaver(m.metadata, ImageSizes(m.metadata.ViewGroup, m.metadata.Type))
    endif
    m.Screen.Show()
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
    Debug("About to fetch meta-data for Content Type: " + tostr(content.contentType))

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

