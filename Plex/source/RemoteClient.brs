'*
'* An implementation of the remote client/player interface that allows the Roku
'* to be controlled by other Plex clients, like the remote built into the
'* iOS/Android apps.
'*
'* Note that all handlers are evaluated in the context of a Reply object.
'*

Function ValidateRemoteControlRequest(reply) As Boolean
    if RegRead("remotecontrol", "preferences", "1") <> "1" then
        SendErrorResponse(reply, 404, "Remote control is disabled for this device")
        return false
    else if reply.request.fields["X-Plex-Target-Client-Identifier"] <> invalid AND reply.request.fields["X-Plex-Target-Client-Identifier"] <> GetGlobalAA().Lookup("rokuUniqueID") then
        SendErrorResponse(reply, 400, "Incorrect value for X-Plex-Target-Client-Identifer")
        return false
    else
        return true
    end if
End Function

Sub ProcessCommandID(request)
    deviceID = request.fields["X-Plex-Client-Identifier"]
    commandID = request.query["commandID"]

    if deviceID <> invalid AND commandID <> invalid then
        NowPlayingManager().UpdateCommandID(deviceID, commandID.toint())
    end if
End Sub

Sub SendErrorResponse(reply, code, message)
    xml = CreateObject("roXMLElement")
    xml.SetName("Response")
    xml.AddAttribute("code", tostr(code))
    xml.AddAttribute("status", tostr(message))
    xmlStr = xml.GenXML(false)

    reply.mimetype = MimeType("xml")
    reply.buf.fromasciistring(xmlStr)
    reply.length = reply.buf.count()
    reply.http_code = code
    reply.genHdr(true)
    reply.source = reply.GENERATED
End Sub

Function ProcessPlayMediaRequest() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true

    Debug("Processing PlayMedia request")
    for each name in m.request.fields
        Debug("  " + name + ": " + UrlUnescape(m.request.fields[name]))
    next

    ' Fetch the container for the path and then look for a matching key. This
    ' allows us to set the context correctly so we can do things like play an
    ' entire album or slideshow.

    url = RewriteNodeKey(UrlUnescape(firstOf(m.request.fields["X-Plex-Arg-Path"], "")))
    key = RewriteNodeKey(UrlUnescape(firstOf(m.request.fields["X-Plex-Arg-Key"], "")))

    server = GetServerForUrl(url)
    if server = invalid then
        Debug("Not sure which server to use for " + tostr(url) + ", falling back to primary")
        server = GetPrimaryServer()
    end if

    if server = invalid then
        m.default(404, "No server available for specified URL")
        return true
    end if

    container = createPlexContainerForUrl(server, "", url)
    children = container.GetMetadata()
    matchIndex = invalid
    for i = 0 to children.Count() - 1
        item = children[i]
        if key = item.key then
            matchIndex = i
            exit for
        end if
    end for

    ' Sadly, this doesn't work when playing something from the queue on iOS. So
    ' if we didn't find a match, just request the key directly.
    if matchIndex = invalid then
        container = createPlexContainerForUrl(server, url, key)
        children = container.GetMetadata()
        if children.Count() > 0 then matchIndex = 0
    end if

    if matchIndex <> invalid then
        if m.request.fields.DoesExist("X-Plex-Arg-ViewOffset") then
            seek = m.request.fields["X-Plex-Arg-ViewOffset"].toint()
        else
            seek = 0
        end if

        ' If we currently have a video playing, things are tricky. We can't
        ' play anything on top of video or Bad Things happen. But we also
        ' can't quickly close the screen and throw up a new video player
        ' because the new video screen will see the isScreenClosed event
        ' meant for the old video player. So we have to register a callback,
        ' which is always awkward.

        if GetViewController().IsVideoPlaying() then
            callback = CreateObject("roAssociativeArray")
            callback.context = children
            callback.contextIndex = matchIndex
            callback.seekValue = seek
            callback.OnAfterClose = createPlayerAfterClose
            GetViewController().CloseScreenWithCallback(callback)
        else
            GetViewController().CreatePlayerForItem(children, matchIndex, seek)

            ' If the screensaver is on, which we can't reliably know, then the
            ' video won't start until the user wakes the Roku up. We can do that
            ' for them by sending a harmless keystroke. Down is harmless, as long
            ' as they started a video or slideshow.
            if GetViewController().IsVideoPlaying() OR children[matchIndex].ContentType = "photo" then
                req = CreateURLTransferObject("http://127.0.0.1:8060/keypress/Down")
                req.AsyncPostFromString("")
            end if
        end if

        m.http_code = 200
    else
        Debug("Unable to find matching item for key")
        m.http_code = 404
    end if

    ' Always return an empty body
    m.simpleOK("")

    return true
End Function

Function ProcessStopMediaRequest() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true

    ' If we're playing a video, close it. Otherwise assume this is destined for
    ' the audio player, which will respond appropriately whatever state it's in.
    vc = GetViewController()
    if vc.IsVideoPlaying() then
        vc.CloseScreenWithCallback(invalid)
    else
        AudioPlayer().Stop()
    end if

    ' Always return an empty body
    m.simpleOK("")

    return true
End Function

Function ProcessResourcesRequest() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true

    mc = CreateObject("roXMLElement")
    mc.SetName("MediaContainer")

    player = mc.AddElement("Player")
    player.AddAttribute("protocolCapabilities", "timeline,playback,navigation")
    player.AddAttribute("product", "Plex/Roku")
    player.AddAttribute("version", GetGlobalAA().Lookup("appVersionStr"))
    player.AddAttribute("platformVersion", GetGlobalAA().Lookup("rokuVersionStr"))
    player.AddAttribute("platform", "Roku")
    player.AddAttribute("machineIdentifier", GetGlobalAA().Lookup("rokuUniqueID"))
    player.AddAttribute("title", RegRead("player_name", "preferences", GetGlobalAA().Lookup("rokuModel")))
    player.AddAttribute("protocolVersion", "1")
    player.AddAttribute("deviceClass", "stb")

    m.mimetype = MimeType("xml")
    m.simpleOK(mc.GenXML(false))

    return true
End Function

Function ProcessTimelineSubscribe() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    protocol = firstOf(m.request.query["protocol"], "http")
    port = firstOf(m.request.query["port"], "32400")
    host = m.request.remote_addr
    deviceID = m.request.fields["X-Plex-Client-Identifier"]
    commandID = firstOf(m.request.query["commandID"], "0").toint()

    connectionUrl = protocol + "://" + tostr(host) + ":" + port

    if NowPlayingManager().AddSubscriber(deviceID, connectionUrl, commandID) then
        m.simpleOK("")
    else
        SendErrorResponse(m, 400, "Invalid subscribe request")
    end if

    return true
End Function

Function ProcessTimelineUnsubscribe() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    deviceID = m.request.fields["X-Plex-Client-Identifier"]
    NowPlayingManager().RemoveSubscriber(deviceID)

    m.simpleOK("")
    return true
End Function

Function ProcessTimelinePoll() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    m.headers["X-Plex-Client-Identifier"] = GetGlobalAA().Lookup("rokuUniqueID")

    deviceID = m.request.fields["X-Plex-Client-Identifier"]
    commandID = firstOf(m.request.query["commandID"], "0").toint()

    NowPlayingManager().AddPollSubscriber(deviceID, commandID)

    if firstOf(m.request.query["wait"], "0") = "0" then
        xml = NowPlayingManager().TimelineDataXmlForSubscriber(deviceID)
        m.mimetype = MimeType("xml")
        m.simpleOK(xml)
    else
        NowPlayingManager().WaitForNextTimeline(deviceID, m)
    end if

    return true
End Function

Function ProcessPlaybackPlayMedia() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    machineID = m.request.query["machineIdentifier"]

    server = GetPlexMediaServer(machineID)

    if server = invalid then
        port = firstOf(m.request.query["port"], "32400")
        protocol = firstOf(m.request.query["protocol"], "http")
        address = m.request.query["address"]
        if address = invalid then
            SendErrorResponse(m, 400, "address must be specified")
            return true
        end if

        server = newSyntheticPlexMediaServer(protocol + "://" + address + ":" + port, machineID)
    end if

    offset = firstOf(m.request.query["offset"], "0").toint()
    key = m.request.query["key"]
    containerKey = firstOf(m.request.query["containerKey"], key)

    ' If we have a container key, fetch the container and look for the matching
    ' item. Otherwise, just fetch the key and use the first result.

    if containerKey = invalid then
        SendErrorResponse(m, 400, "at least one of key or containerKey must be specified")
        return true
    end if

    container = createPlexContainerForUrl(server, "", containerKey)
    children = container.GetMetadata()
    matchIndex = invalid
    for i = 0 to children.Count() - 1
        item = children[i]
        if key = item.key then
            matchIndex = i
            exit for
        end if
    end for

    if matchIndex <> invalid then
        ' If we currently have a video playing, things are tricky. We can't
        ' play anything on top of video or Bad Things happen. But we also
        ' can't quickly close the screen and throw up a new video player
        ' because the new video screen will see the isScreenClosed event
        ' meant for the old video player. So we have to register a callback,
        ' which is always awkward.

        if GetViewController().IsVideoPlaying() then
            callback = CreateObject("roAssociativeArray")
            callback.context = children
            callback.contextIndex = matchIndex
            callback.seekValue = offset
            callback.OnAfterClose = createPlayerAfterClose
            GetViewController().CloseScreenWithCallback(callback)
        else
            GetViewController().CreatePlayerForItem(children, matchIndex, offset)

            ' If the screensaver is on, which we can't reliably know, then the
            ' video won't start until the user wakes the Roku up. We can do that
            ' for them by sending a harmless keystroke. Down is harmless, as long
            ' as they started a video or slideshow.
            SendEcpCommand("Down")
        end if
    else
        SendErrorResponse(m, 400, "unable to find media for key")
        return true
    end if

    m.simpleOK("")
    return true
End Function

Function ProcessPlaybackSeekTo() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    mediaType = m.request.query["type"]
    offset = m.request.query["offset"]

    if mediaType = "music" AND offset <> invalid
        AudioPlayer().Seek(int(val(offset)))
    else if mediaType = "video" AND offset <> invalid
        player = VideoPlayer()
        if player <> invalid then
            player.Seek(int(val(offset)))
        end if
    end if

    m.simpleOK("")
    return true
End Function

Function ProcessPlaybackPlay() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    mediaType = m.request.query["type"]

    ' Try to deal with the command directly, falling back to ECP.
    if mediaType = "music" then
        player = AudioPlayer()
        if player.IsPaused then
            player.Resume()
        else
            player.Play()
        end if
    else if mediaType = "photo" then
        player = PhotoPlayer()
        if player <> invalid then player.Resume()
    else if mediaType = "video" then
        player = VideoPlayer()
        if player <> invalid then player.Resume()
    else
        SendEcpCommand("Play")
    end if

    m.simpleOK("")
    return true
End Function

Function ProcessPlaybackPause() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    mediaType = m.request.query["type"]

    ' Try to deal with the command directly, falling back to ECP.
    if mediaType = "music" then
        AudioPlayer().Pause()
    else if mediaType = "photo" then
        player = PhotoPlayer()
        if player <> invalid then player.Pause()
    else if mediaType = "video" then
        player = VideoPlayer()
        if player <> invalid then player.Pause()
    else
        SendEcpCommand("Play")
    end if

    m.simpleOK("")
    return true
End Function

Function ProcessPlaybackStop() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    mediaType = m.request.query["type"]

    ' Try to deal with the command directly, falling back to ECP.
    if mediaType = "music" then
        AudioPlayer().Stop()
    else if mediaType = "photo" then
        player = PhotoPlayer()
        if player <> invalid then player.Stop()
    else if mediaType = "video" then
        player = VideoPlayer()
        if player <> invalid then player.Stop()
    else
        SendEcpCommand("Back")
    end if

    m.simpleOK("")
    return true
End Function


Function ProcessPlaybackSkipNext() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    mediaType = m.request.query["type"]

    ' Try to deal with the command directly, falling back to ECP.
    if mediaType = "music" then
        AudioPlayer().Next()
    else if mediaType = "photo" then
        player = PhotoPlayer()
        if player <> invalid then player.Next()
    else if mediaType = "video" then
        player = VideoPlayer()
        if player <> invalid then player.Next()
    else
        SendEcpCommand("Fwd")
    end if

    m.simpleOK("")
    return true
End Function

Function ProcessPlaybackSkipPrevious() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    mediaType = m.request.query["type"]

    ' Try to deal with the command directly, falling back to ECP.
    if mediaType = "music" then
        AudioPlayer().Prev()
    else if mediaType = "photo" then
        player = PhotoPlayer()
        if player <> invalid then player.Prev()
    else if mediaType = "video" then
        player = VideoPlayer()
        if player <> invalid then player.Prev()
    else
        SendEcpCommand("Rev")
    end if

    m.simpleOK("")
    return true
End Function

Function ProcessPlaybackStepBack() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    mediaType = m.request.query["type"]

    ' Try to deal with the command directly, falling back to ECP.
    if mediaType = "music" then
        AudioPlayer().Seek(-15000, true)
    else if mediaType = "photo" then
    else 
        SendEcpCommand("InstantReplay")
    end if

    m.simpleOK("")
    return true
End Function

Function ProcessPlaybackStepForward() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    mediaType = m.request.query["type"]

    player = invalid
    if mediaType = "music" then
        player = AudioPlayer()
    else if mediaType = "video" then
        player = VideoPlayer()
    end if

    if player <> invalid then
        player.Seek(30000, true)
    end if

    m.simpleOK("")
    return true
End Function

Function ProcessPlaybackSetParameters() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    mediaType = m.request.query["type"]

    if mediaType = "music" then
        if m.request.query["shuffle"] <> invalid then
            AudioPlayer().SetShuffle(m.request.query["shuffle"].toint())
        end if

        if m.request.query["repeat"] <> invalid then
            AudioPlayer().SetRepeat(m.request.query["repeat"].toint())
        end if
    else if mediaType = "photo" then
        player = PhotoPlayer()
        if player <> invalid AND m.request.query["shuffle"] <> invalid then
            player.SetShuffle(m.request.query["shuffle"].toint())
        end if
    end if

    m.simpleOK("")
    return true
End Function

Function ProcessNavigationMoveRight() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    ' Just use ECP, trying to figure out how to refocus whatever is currently
    ' visible is a mess.
    SendEcpCommand("Right")

    m.simpleOK("")
    return true
End Function

Function ProcessNavigationMoveLeft() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    ' Just use ECP, trying to figure out how to refocus whatever is currently
    ' visible is a mess.
    SendEcpCommand("Left")

    m.simpleOK("")
    return true
End Function

Function ProcessNavigationMoveDown() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    ' Just use ECP, trying to figure out how to refocus whatever is currently
    ' visible is a mess.
    SendEcpCommand("Down")

    m.simpleOK("")
    return true
End Function

Function ProcessNavigationMoveUp() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    ' Just use ECP, trying to figure out how to refocus whatever is currently
    ' visible is a mess.
    SendEcpCommand("Up")

    m.simpleOK("")
    return true
End Function

Function ProcessNavigationSelect() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    SendEcpCommand("Select")

    m.simpleOK("")
    return true
End Function

Function ProcessNavigationBack() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    SendEcpCommand("Back")

    m.simpleOK("")
    return true
End Function

Function ProcessNavigationMusic() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    dummyItem = CreateObject("roAssociativeArray")
    dummyItem.ContentType = "audio"
    dummyItem.Key = "nowplaying"
    GetViewController().CreateScreenForItem(dummyItem, invalid, ["Now Playing"])

    m.simpleOK("")
    return true
End Function

Function ProcessNavigationHome() As Boolean
    if NOT ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    context = CreateObject("roAssociativeArray")
    context.OnAfterClose = CloseScreenUntilHomeVisible
    context.OnAfterClose()

    m.simpleOK("")
    return true
End Function

Sub CloseScreenUntilHomeVisible()
    vc = GetViewController()

    if vc.Home = invalid OR NOT vc.IsActiveScreen(vc.Home) then
        vc.CloseScreenWithCallback(m)
    end if
End Sub

Sub InitRemoteControlHandlers()
    ' Old custom requests
    ClassReply().AddHandler("/application/PlayMedia", ProcessPlayMediaRequest)
    ClassReply().AddHandler("/application/Stop", ProcessStopMediaRequest)

    ' Advertising
    ClassReply().AddHandler("/resources", ProcessResourcesRequest)

    ' Timeline
    ClassReply().AddHandler("/player/timeline/subscribe", ProcessTimelineSubscribe)
    ClassReply().AddHandler("/player/timeline/unsubscribe", ProcessTimelineUnsubscribe)
    ClassReply().AddHandler("/player/timeline/poll", ProcessTimelinePoll)

    ' Playback
    ClassReply().AddHandler("/player/playback/playMedia", ProcessPlaybackPlayMedia)
    ClassReply().AddHandler("/player/playback/seekTo", ProcessPlaybackSeekTo)
    ClassReply().AddHandler("/player/playback/play", ProcessPlaybackPlay)
    ClassReply().AddHandler("/player/playback/pause", ProcessPlaybackPause)
    ClassReply().AddHandler("/player/playback/stop", ProcessPlaybackStop)
    ClassReply().AddHandler("/player/playback/skipNext", ProcessPlaybackSkipNext)
    ClassReply().AddHandler("/player/playback/skipPrevious", ProcessPlaybackSkipPrevious)
    ClassReply().AddHandler("/player/playback/stepBack", ProcessPlaybackStepBack)
    ClassReply().AddHandler("/player/playback/stepForward", ProcessPlaybackStepForward)
    ClassReply().AddHandler("/player/playback/setParameters", ProcessPlaybackSetParameters)

    ' Navigation
    ClassReply().AddHandler("/player/navigation/moveRight", ProcessNavigationMoveRight)
    ClassReply().AddHandler("/player/navigation/moveLeft", ProcessNavigationMoveLeft)
    ClassReply().AddHandler("/player/navigation/moveDown", ProcessNavigationMoveDown)
    ClassReply().AddHandler("/player/navigation/moveUp", ProcessNavigationMoveUp)
    ClassReply().AddHandler("/player/navigation/select", ProcessNavigationSelect)
    ClassReply().AddHandler("/player/navigation/back", ProcessNavigationBack)
    ClassReply().AddHandler("/player/navigation/music", ProcessNavigationMusic)
    ClassReply().AddHandler("/player/navigation/home", ProcessNavigationHome)
End Sub

Sub createPlayerAfterClose()
    GetViewController().CreatePlayerForItem(m.context, m.contextIndex, m.seekValue)
End Sub

Sub SendEcpCommand(command)
    GetViewController().StartRequestIgnoringResponse("http://127.0.0.1:8060/keypress/" + command, "", "txt")
End Sub
