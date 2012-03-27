Function videoAddButtons(obj) As Object
    screen = obj.Screen
    metadata = obj.metadata
    media = obj.media

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
    screen.AddButton(buttonCount, m.PlayButtonStates[m.PlayButtonState].label)
    buttonCommands[str(buttonCount)] = "play"
    buttonCount = buttonCount + 1

    print "Media = ";media
    print "Can direct play = ";videoCanDirectPlay(media)

    supportedIdentifier = (m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" OR m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex")
    if supportedIdentifier then
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
    end if

    if m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex" AND m.metadata.id <> invalid then
        screen.AddButton(buttonCount, "Delete from queue")
        buttonCommands[str(buttonCount)] = "delete"
        buttonCount = buttonCount + 1
    end if

    screen.AddButton(buttonCount, "Playback options")
    buttonCommands[str(buttonCount)] = "options"
    buttonCount = buttonCount + 1

    if supportedIdentifier then
        if metadata.UserRating = invalid then
            metadata.UserRating = 0
        endif
        if metadata.StarRating = invalid then
            metadata.StarRating = 0
        endif
        screen.AddRatingButton(buttonCount, metadata.UserRating, metadata.StarRating)
        buttonCommands[str(buttonCount)] = "rateVideo"
        buttonCount = buttonCount + 1
    end if
    return buttonCommands
End Function

Function videoHandleMessage(msg) As Boolean
    server = m.Item.server

    if msg = invalid then
        m.msgTimeout = 0
        m.Refresh(true)
        return true
    else if msg.isScreenClosed() then
        RegWrite("quality", m.OrigQuality, "preferences")
        return false
    else if msg.isButtonPressed() then
        buttonCommand = m.buttonCommands[str(msg.getIndex())]
        print "Button command: ";buttonCommand
        if buttonCommand = "play" OR buttonCommand = "resume" then
            startTime = 0
            if buttonCommand = "resume" then
                startTime = int(val(m.metadata.viewOffset))
            endif
            directPlayOptions = m.PlayButtonStates[m.PlayButtonState]
            print "Playing video with Direct Play options set to: "; directPlayOptions.label
            m.PlayVideo(startTime, directPlayOptions.value)
            '* Refresh play data after playing, but only after a timeout,
            '* otherwise we may leak objects if the play ended because the
            '* springboard was closed.
            m.msgTimeout = 1
        else if buttonCommand = "scrobble" then
            'scrobble key here
            server.Scrobble(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier)
            '* Refresh play data after scrobbling
            m.Refresh(true)
        else if buttonCommand = "unscrobble" then
            'unscrobble key here
            server.Unscrobble(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier)
            '* Refresh play data after unscrobbling
            m.Refresh(true)
        else if buttonCommand = "delete" then
            server.Delete(m.metadata.id)
            m.Screen.Close()
        else if buttonCommand = "options" then
            screen = createVideoOptionsScreen(m.metadata, m.ViewController)
            m.ViewController.InitializeOtherScreen(screen, ["Video Playback Options"])
            screen.Show()

            if screen.Changes.DoesExist("playback") then
                m.PlayButtonState = screen.Changes["playback"].toint()
            end if

            if screen.Changes.DoesExist("quality") then
                RegWrite("quality", screen.Changes["quality"], "preferences")
                m.metadata.preferredMediaItem = PickMediaItem(m.metadata.media)
            end if

            if screen.Changes.DoesExist("audio") then
                server.UpdateAudioStreamSelection(m.media.preferredPart.id, screen.Changes["audio"])
            end if

            if screen.Changes.DoesExist("subtitles") then
                server.UpdateSubtitleStreamSelection(m.media.preferredPart.id, screen.Changes["subtitles"])
            end if

            if NOT screen.Changes.IsEmpty() then
                m.Refresh(true)
            end if
            screen = invalid
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

Sub playVideo(seekValue=0, directPlayOptions=0)
    metadata = m.metadata
    server = metadata.server

	print "MediaPlayer::playVideo: Displaying video: ";metadata.title
	seconds = int(seekValue/1000)

    origDirectPlayOptions = RegRead("directplay", "preferences", "0")
    if origDirectPlayOptions <> directPlayOptions.tostr() then
        print "Temporarily overwriting direct play preference to:"; directPlayOptions
        RegWrite("directplay", directPlayOptions.tostr(), "preferences")
        Capabilities(true)
    else
        origDirectPlayOptions = invalid
    end if

    videoItem = server.ConstructVideoItem(metadata, seconds, directPlayOptions < 3, directPlayOptions = 1 OR directPlayOptions = 2)
    if videoItem = invalid then
        print "Can't play video, server was unable to construct video item"
        return
    end if

    port = CreateObject("roMessagePort")
    videoPlayer = CreateObject("roVideoScreen")
    videoPlayer.SetMessagePort(port)
    videoPlayer.SetContent(videoItem)

    if server.AccessToken <> invalid then
        videoPlayer.AddHeader("X-Plex-Token", server.AccessToken)
    end if

    if videoItem.IsTranscoded then
        cookie = server.StartTranscode(videoItem.StreamUrls[0])
        if cookie <> invalid then
            videoPlayer.AddHeader("Cookie", cookie)
        end if
    else
        for each header in videoItem.IndirectHttpHeaders
            for each name in header
                videoPlayer.AddHeader(name, header[name])
            next
        next
    end if

    videoPlayer.SetPositionNotificationPeriod(5)
    videoPlayer.Show()

    success = videoMessageLoop(server, metadata, port, videoItem.IsTranscoded)

    if NOT success then
        if videoItem.IsTranscoded then
            ' Nothing left to fall back to, tell the user
            dialog = createBaseDialog()
            dialog.Title = "Video Unavailable"
            dialog.Text = "We're unable to play this video, make sure the server is running and has access to this video."
            dialog.Show()
        else if directPlayOptions = 1 then
            dialog = createBaseDialog()
            dialog.Title = "Direct Play Unavailable"
            dialog.Text = "This video isn't supported for Direct Play."
            dialog.Show()
        else
            ' Force transcoding this time
            m.PlayVideo(seekValue, 3)
        end if
    end if

    if origDirectPlayOptions <> invalid then
        print "Restoring direct play options to: "; origDirectPlayOptions
        RegWrite("directplay", origDirectPlayOptions, "preferences")
        Capabilities(true)
    end if

    if GetGlobalAA().DoesExist("show_underrun_warning") then
        GetGlobalAA().AddReplace("underrun_warning_shown", "1")
        GetGlobalAA().Delete("show_underrun_warning")

        dialog = createBaseDialog()
        dialog.Title = "Quality Too High"
        dialog.Text = "We seem to have had a hard time playing that video. You may get better results with a lower quality setting."
        dialog.Buttons = {ok: "Ok", quality: "Lower the quality setting now"}
        dialog.HandleButton = qualityHandleButton
        dialog.Quality = m.OrigQuality
        dialog.Show()

        if m.OrigQuality <> dialog.Quality then
            m.metadata.preferredMediaItem = PickMediaItem(m.metadata.media)
            m.OrigQuality = dialog.Quality
        end if
    end if
End Sub

Sub qualityHandleButton(key)
    if key = "quality" then
        print "Lowering quality from original value: "; m.Quality
        quality = m.Quality.toint()
        newQuality = invalid

        if quality >= 9 then
            newQuality = 7
        else if quality >= 6 then
            newQuality = 5
        else if quality >= 5 then
            newQuality = 4
        end if

        if newQuality <> invalid then
            print "New quality:"; newQuality
            RegWrite("quality", newQuality.tostr(), "preferences")
            m.Quality = newQuality.tostr()
        end if
    end if

    if metadata.RestoreSubtitleID <> invalid then
        print "Restoring subtitle selection"
        server.UpdateSubtitleStreamSelection(metadata.RestoreSubtitlePartID, metadata.RestoreSubtitleID)
    end if
End Sub

Function videoCanDirectPlay(mediaItem) As Boolean
    if mediaItem = invalid then
        print "Media item has no Video object, can't direct play"
        return false
    end if

    if mediaItem.preferredPart <> invalid AND mediaItem.preferredPart.subtitles <> invalid then
        subtitleFormat = firstOf(mediaItem.preferredPart.subtitles.codec, "")
    else
        subtitleFormat = invalid
    end if

    print "Media item optimized for streaming: "; mediaItem.optimized
    print "Media item container: "; mediaItem.container
    print "Media item video codec: "; mediaItem.videoCodec
    print "Media item audio codec: "; mediaItem.audioCodec
    print "Media item subtitles: "; subtitleFormat

    versionArr = GetGlobal("rokuVersionArr", [0])
    major = versionArr[0]

    if subtitleFormat <> invalid AND subtitleFormat <> "srt" then
        print "videoCanDirectPlay: subtitles not SRT"
        return false
    end if

    if mediaItem.container = "mp4" OR mediaItem.container = "mov" OR mediaItem.container = "m4v" then
        if (mediaItem.optimized <> "true" AND mediaItem.optimized <> "1")
            print "videoCanDirectPlay: media is not optimized"
            return false
        end if

        if (mediaItem.videoCodec <> "h264" AND mediaItem.videoCodec <> "mpeg4") then
            print "videoCanDirectPlay: vc not h264/mpeg4"
            return false
        end if

        ' NOTE: ac3 seems to fail for this commenter (though it does at least throw an error)
        if (mediaItem.audioCodec <> "aac" AND mediaItem.audioCodec <> "ac3") then
            print "videoCanDirectPlay: ac not aac/ac3"
            return false
        end if

        return true
    end if

    if mediaItem.container = "wmv" then
        ' TODO: What exactly should we check here?

        ' Based on docs, only WMA9.2 is supported for audio
        if Left(mediaItem.audioCodec, 3) <> "wma" then
            print "videoCanDirectPlay: ac not wmav2"
            return false
        end if

        ' Video support is less obvious. WMV9 up to 480p, VC-1 up to 1080p?
        if mediaItem.videoCodec <> "wmv3" AND mediaItem.videoCodec <> "vc1" then
            print "videoCanDirectPlay: vc not wmv3/vc1"
            return false
        end if

        return true
    end if

    if mediaItem.container = "mkv" then
        if major < 4 then
            print "videoCanDirectPlay: mkv not supported by version"; major
            return false
        end if

        if mediaItem.videoCodec <> "h264" then
            print "videoCanDirectPlay: vc not h264"
            return false
        end if

        if (mediaItem.audioCodec <> "aac" AND mediaItem.audioCodec <> "ac3" AND mediaItem.audioCodec <> "mp3") then
            print "videoCanDirectPlay: ac not aac/ac3/mp3"
            return false
        end if

        return true
    end if

    return false
End Function

Function videoMessageLoop(server, metadata, messagePort, transcoded) As Boolean
    scrobbleThreshold = 0.90
    lastPosition = 0
    played = false
    success = true
    underrunCount = 0

    while true
    	' Time out after 60 seconds causing invalid event allowing ping to be sent during 
    	' long running periods with no video events (e.g. user pause). Note that this timeout
    	' has to be bigger than the SetPositionNotificationPeriod above to allow actual
    	' video screen isPlaybackPosition events to be generated and reacted to
        msg = wait(60005, messagePort)
        print "MediaPlayer::playVideo: Reacting to video screen event message -> ";msg
        if transcoded then server.PingTranscode()
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then
                print "MediaPlayer::playVideo::VideoScreenEvent::isScreenClosed: position -> "; lastPosition
                if metadata.ratingKey <> invalid then
                    if played then
                        print "MediaPlayer::playVideo::VideoScreenEvent::isScreenClosed: scrobbling media -> ";metadata.ratingKey
                        server.Scrobble(metadata.ratingKey, metadata.mediaContainerIdentifier)
                    else
                        server.SetProgress(metadata.ratingKey, metadata.mediaContainerIdentifier, 1000*lastPosition)
                    end if
                end if
                if transcoded then server.StopVideo()
                exit while
            else if msg.isPlaybackPosition() then
                lastPosition = msg.GetIndex()
                if metadata.ratingKey <> invalid then
                    if metadata.Length <> invalid AND metadata.Length > 0 then
                        playedFraction = lastPosition/metadata.Length
                        print "MediaPlayer::playVideo::VideoScreenEvent::isPlaybackPosition: position -> "; lastPosition;" playedFraction -> "; playedFraction
                        if playedFraction > scrobbleThreshold then
                            played = true
                        end if
                    end if
                    print "MediaPlayer::playVideo::VideoScreenEvent::isPlaybackPosition: set progress -> ";1000*lastPosition
                    server.SetProgress(metadata.ratingKey, metadata.mediaContainerIdentifier, 1000*lastPosition)
                end if
            else if msg.isRequestFailed() then
                print "MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - message = "; msg.GetMessage()
                print "MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - data = "; msg.GetData()
                print "MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - index = "; msg.GetIndex()
                success = false
            else if msg.isPaused() then
                print "MediaPlayer::playVideo::VideoScreenEvent::isPaused: position -> "; lastPosition
            else if msg.isPartialResult() then
                if metadata.Length <> invalid AND metadata.Length > 0 then
                	playedFraction = lastPosition/metadata.Length
                	print "MediaPlayer::playVideo::VideoScreenEvent::isPartialResult: position -> "; lastPosition;" playedFraction -> "; playedFraction
            		if playedFraction > scrobbleThreshold then
            			played = true
            		end if
            	end if
                if transcoded then server.StopVideo()
            else if msg.isFullResult() then
            	print "MediaPlayer::playVideo::VideoScreenEvent::isFullResult: position -> ";lastPosition
    			played = true
                if transcoded then server.StopVideo()
                success = true
            else if msg.isStreamStarted() then
            	print "MediaPlayer::playVideo::VideoScreenEvent::isStreamStarted: position -> ";lastPosition
            	print "Message data -> ";msg.GetInfo()

                if msg.GetInfo().IsUnderrun = true then
                    underrunCount = underrunCount + 1
                    if underrunCount = 4 and not GetGlobalAA().DoesExist("underrun_warning_shown") then
                        GetGlobalAA().AddReplace("show_underrun_warning", "1")
                    end if
                end if
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end if
    end while

    return success
End Function

Function createVideoOptionsScreen(item, viewController) As Object
    obj = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    screen = CreateObject("roListScreen")

    screen.SetMessagePort(port)

    ' Standard properties for all our Screen types
    obj.Item = item
    obj.Screen = screen
    obj.Port = port
    obj.ViewController = viewController
    obj.MessageHandler = invalid
    obj.MsgTimeout = 0

    obj.Show = showVideoOptionsScreen

    obj.Changes = CreateObject("roAssociativeArray")
    obj.Prefs = CreateObject("roAssociativeArray")

    lsInitBaseListScreen(obj)

    ' Transcoding vs. direct play
    options = [
        { title: "Automatic", EnumValue: "0" },
        { title: "Direct Play", EnumValue: "1" },
        { title: "Direct Play w/ Fallback", EnumValue: "2" },
        { title: "Direct Stream/Transcode", EnumValue: "3" },
        { title: "Transcode", EnumValue: "4" }
    ]
    obj.Prefs["playback"] = {
        values: options,
        label: "Transcoding",
        heading: "Should this video be transcoded or use Direct Play?",
        default: RegRead("directplay", "preferences", "0")
    }

    ' Quality
    qualities = [
        { title: "720 kbps, 320p", EnumValue: "4" },
        { title: "1.5 Mbps, 480p", EnumValue: "5" },
        { title: "2.0 Mbps, 720p", EnumValue: "6" },
        { title: "3.0 Mbps, 720p", EnumValue: "7" },
        { title: "4.0 Mbps, 720p", EnumValue: "8" },
        { title: "8.0 Mbps, 1080p", EnumValue: "9"}
    ]
    obj.Prefs["quality"] = {
        values: qualities,
        label: "Quality",
        heading: "Higher settings require more bandwidth and may buffer",
        default: RegRead("quality", "preferences", "7")
    }

    audioStreams = []
    subtitleStreams = []
    defaultAudio = ""
    defaultSubtitle = ""

    subtitleStreams.Push({ title: "No Subtitles", EnumValue: "" })

    for each stream in item.preferredMediaItem.preferredPart.streams
        if stream.streamType = "2" then
            language = firstOf(stream.Language, "Unknown")
            format = ucase(firstOf(stream.Codec, ""))
            if format = "DCA" then format = "DTS"
            if stream.Channels <> invalid then
                if stream.Channels = "2" then
                    format = format + " Stereo"
                else if stream.Channels = "6" then
                    format = format + " 5.1"
                else if stream.Channels = "8" then
                    format = format + " 7.1"
                end if
            end if
            if format <> "" then
                title = language + " (" + format + ")"
            else
                title = language
            end if
            if stream.selected <> invalid then
                defaultAudio = stream.Id
            end if

            audioStreams.Push({ title: title, EnumValue: stream.Id })
        else if stream.streamType = "3" then
            language = firstOf(stream.Language, "Unknown")
            if stream.Codec = "srt" then
                language = language + " (*)"
            end if
            if stream.selected <> invalid then
                defaultSubtitle = stream.Id
            end if

            subtitleStreams.Push({ title: language, EnumValue: stream.Id })
        end if
    next

    ' Audio streams
    print "Found audio streams:"; audioStreams.Count()
    if audioStreams.Count() > 0 then
        obj.Prefs["audio"] = {
            values: audioStreams,
            label: "Audio Stream",
            heading: "Select an audio stream",
            default: defaultAudio
        }
    end if

    ' Subtitle streams
    print "Found subtitle streams:"; (subtitleStreams.Count() - 1)
    if subtitleStreams.Count() > 1 then
        obj.Prefs["subtitles"] = {
            values: subtitleStreams,
            label: "Subtitle Stream",
            heading: "Select a subtitle stream",
            default: defaultSubtitle
        }
    end if

    obj.GetEnumValue = videoGetEnumValue

    return obj
End Function

Sub showVideoOptionsScreen()
    m.Screen.SetHeader("Video playback options")

    possiblePrefs = ["playback", "quality", "audio", "subtitles"]
    for each key in possiblePrefs
        pref = m.Prefs[key]
        if pref <> invalid then
            m.AddItem({title: pref.label}, key)
            m.AppendValue(invalid, m.GetEnumValue(key))
        end if
    next

    m.AddItem({title: "Close"}, "close")

    m.Screen.Show()

    while true
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roListScreenEvent" then
            if msg.isScreenClosed() then
                print "Closing video options screen"
                m.ViewController.PopScreen(m)
                exit while
            else if msg.isListItemSelected() then
                command = m.GetSelectedCommand(msg.GetIndex())
                if command = "playback" OR command = "audio" OR command = "subtitles" OR command = "quality" then
                    pref = m.Prefs[command]
                    screen = m.ViewController.CreateEnumInputScreen(pref.values, pref.default, pref.heading, [pref.label])
                    if screen.SelectedIndex <> invalid then
                        m.Changes.AddReplace(command, screen.SelectedValue)
                        pref.default = screen.SelectedValue
                        m.AppendValue(msg.GetIndex(), screen.SelectedLabel)
                    end if
                    screen = invalid
                else if command = "close" then
                    m.Screen.Close()
                end if
            end if
        end if
    end while
End Sub

Function videoGetEnumValue(key) As String
    pref = m.Prefs[key]
    for each item in pref.values
        if item.EnumValue = pref.default then
            return item.title
        end if
    next

    return invalid
End Function

