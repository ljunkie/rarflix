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

    Debug("Media = " + tostr(media))
    Debug("Can direct play = " + tostr(videoCanDirectPlay(media)))

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
        Debug("Button command: " + tostr(buttonCommand))
        if buttonCommand = "play" OR buttonCommand = "resume" then
            startTime = 0
            if buttonCommand = "resume" then
                startTime = int(val(m.metadata.viewOffset))
            endif
            directPlayOptions = m.PlayButtonStates[m.PlayButtonState]
            Debug("Playing video with Direct Play options set to: " + directPlayOptions.label)
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
                m.metadata.preferredMediaItem = PickMediaItem(m.metadata.media, m.metadata.HasDetails)
            end if

            if screen.Changes.DoesExist("audio") then
                m.media.canDirectPlay = invalid
                server.UpdateAudioStreamSelection(m.media.preferredPart.id, screen.Changes["audio"])
            end if

            if screen.Changes.DoesExist("subtitles") then
                m.media.canDirectPlay = invalid
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

	Debug("MediaPlayer::playVideo: Displaying video: " + tostr(metadata.title))
	seconds = int(seekValue/1000)

    if (metadata.preferredMediaItem <> invalid AND metadata.preferredMediaItem.forceTranscode <> invalid) AND (directPlayOptions <> 1 AND directPlayOptions <> 2) then
        directPlayOptions = 4
    end if

    origDirectPlayOptions = RegRead("directplay", "preferences", "0")
    if origDirectPlayOptions <> directPlayOptions.tostr() then
        Debug("Temporarily overwriting direct play preference to: " + tostr(directPlayOptions))
        RegWrite("directplay", directPlayOptions.tostr(), "preferences")
        RegWrite("directplay_restore", origDirectPlayOptions, "preferences")
        Capabilities(true)
    else
        origDirectPlayOptions = invalid
    end if

    videoItem = server.ConstructVideoItem(metadata, seconds, directPlayOptions < 3, directPlayOptions = 1 OR directPlayOptions = 2)

    if videoItem = invalid then
        Debug("Can't play video, server was unable to construct video item", server)
        success = false
    else
        port = CreateObject("roMessagePort")
        videoPlayer = CreateObject("roVideoScreen")
        videoPlayer.SetMessagePort(port)
        videoPlayer.SetContent(videoItem)

        ' If we're playing the video from the server, add appropriate X-Plex
        ' headers.
        if server.IsRequestToServer(videoItem.StreamUrls[0]) then
            AddPlexHeaders(videoPlayer, server.AccessToken)
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

        if videoItem.IsTranscoded then
            Debug("Starting to play transcoded video", server)
        else
            Debug("Starting to direct play video", server)
        end if

        success = videoMessageLoop(server, metadata, port, videoItem.IsTranscoded)
    end if

    if NOT success then
        Debug("Error occurred while playing video", server)
        if (videoItem <> invalid AND videoItem.IsTranscoded) OR directPlayOptions >= 3 then
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
        Debug("Restoring direct play options to: " + tostr(origDirectPlayOptions))
        RegWrite("directplay", origDirectPlayOptions, "preferences")
        RegDelete("directplay_restore", "preferences")
        Capabilities(true)
    end if

    if GetGlobalAA().DoesExist("show_underrun_warning") then
        GetGlobalAA().AddReplace("underrun_warning_shown", "1")
        GetGlobalAA().Delete("show_underrun_warning")

        dialog = createBaseDialog()
        dialog.Title = "Quality Too High"
        dialog.Text = "We seem to have had a hard time playing that video. You may get better results with a lower quality setting."
        dialog.SetButton("ok", "Ok")
        dialog.SetButton("quality", "Lower the quality setting now")
        dialog.HandleButton = qualityHandleButton
        dialog.Quality = m.OrigQuality
        dialog.Show()

        if m.OrigQuality <> dialog.Quality then
            m.metadata.preferredMediaItem = PickMediaItem(m.metadata.media, m.metadata.HasDetails)
            m.OrigQuality = dialog.Quality
        end if
    end if

    if m.metadata.RestoreSubtitleID <> invalid then
        Debug("Restoring subtitle selection")
        server.UpdateSubtitleStreamSelection(m.metadata.RestoreSubtitlePartID, m.metadata.RestoreSubtitleID)
    end if
End Sub

Function qualityHandleButton(key, data) As Boolean
    if key = "quality" then
        Debug("Lowering quality from original value: " + tostr(m.Quality))
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
            Debug("New quality: " + tostr(newQuality))
            RegWrite("quality", newQuality.tostr(), "preferences")
            m.Quality = newQuality.tostr()
        end if
    end if
    return true
End Function

Function videoCanDirectPlay(mediaItem) As Boolean
    if mediaItem = invalid then
        Debug("Media item has no Video object, can't direct play")
        return false
    end if

    if mediaItem.canDirectPlay <> invalid then
        return mediaItem.canDirectPlay
    end if
    mediaItem.canDirectPlay = false

    if mediaItem.preferredPart <> invalid AND mediaItem.preferredPart.subtitles <> invalid then
        subtitleStream = mediaItem.preferredPart.subtitles
        subtitleFormat = firstOf(subtitleStream.codec, "")
    else
        subtitleStream = invalid
        subtitleFormat = invalid
    end if

    ' There doesn't seem to be a great way to do this, but we need to see if
    ' the audio streams will support direct play. We'll assume that if there
    ' are audio streams with different numbers of channels, they're probably
    ' the same audio; if there are multiple streams with the same number of
    ' channels, they're probably something like commentary or another language.
    ' So if the selected stream is the first stream with that number of
    ' channels, it might be chosen by the Roku when Direct Playing. We don't
    ' just check the selected stream though, because if the 5.1 AC3 stream is
    ' selected and there's also a stereo AAC stream, we can direct play.

    stereoCodec = invalid
    surroundCodec = invalid
    secondaryStreamSelected = false
    numAudioStreams = 0
    videoStream = invalid
    if mediaItem.preferredPart <> invalid then
        for each stream in mediaItem.preferredPart.streams
            if stream.streamType = "2" then
                numAudioStreams = numAudioStreams + 1
                if stream.channels = "2" OR stream.channels = "1" then
                    if stereoCodec = invalid then
                        stereoCodec = stream.codec
                    else if stream.selected <> invalid then
                        secondaryStreamSelected = true
                    end if
                else if stream.channels = "6" then
                    if surroundCodec = invalid then
                        surroundCodec = stream.codec
                    else if stream.selected <> invalid then
                        secondaryStreamSelected = true
                    end if
                else
                    Debug("Unexpected channels on audio stream: " + tostr(stream.channels))
                end if
            elseif stream.streamType = "1" AND videoStream = invalid then
                videoStream = stream
            end if
        next
    end if

    Debug("Media item optimized for streaming: " + tostr(mediaItem.optimized))
    Debug("Media item container: " + tostr(mediaItem.container))
    Debug("Media item video codec: " + tostr(mediaItem.videoCodec))
    Debug("Media item audio codec: " + tostr(mediaItem.audioCodec))
    Debug("Media item subtitles: " + tostr(subtitleFormat))
    Debug("Media item stereo codec: " + tostr(stereoCodec))
    Debug("Media item 5.1 codec: " + tostr(surroundCodec))
    Debug("Secondary audio stream selected: " + tostr(secondaryStreamSelected))
    Debug("Media item aspect ratio: " + tostr(mediaItem.aspectRatio))

    ' If no streams are provided, treat the Media audio codec as stereo.
    if numAudioStreams = 0 then
        stereoCodec = mediaItem.audioCodec
    end if

    versionArr = GetGlobal("rokuVersionArr", [0])
    major = versionArr[0]

    if subtitleStream <> invalid AND NOT shouldUseSoftSubs(subtitleStream) then
        Debug("videoCanDirectPlay: need to burn in subtitles")
        return false
    end if

    if secondaryStreamSelected then
        Debug("videoCanDirectPlay: audio stream selected")
        return false
    end if

    if mediaItem.aspectRatio > 2.2 AND NOT GetGlobal("playsAnamorphic", false) then
        Debug("videoCanDirectPlay: anamorphic videos not supported")
        return false
    end if

    device = CreateObject("roDeviceInfo")

    if mediaItem.container = "mp4" OR mediaItem.container = "mov" OR mediaItem.container = "m4v" then
        if (mediaItem.videoCodec <> "h264" AND mediaItem.videoCodec <> "mpeg4") then
            Debug("videoCanDirectPlay: vc not h264/mpeg4")
            return false
        end if

        if videoStream <> invalid AND firstOf(videoStream.refFrames, "0").toInt() > GetGlobal("maxRefFrames", 0) then
            ' Not only can we not Direct Play, but we want to make sure we
            ' don't try to Direct Stream.
            mediaItem.forceTranscode = true
            Debug("videoCanDirectPlay: too many ReFrames: " + tostr(videoStream.refFrames))
            return false
        end if

        if device.hasFeature("5.1_surround_sound") AND surroundCodec <> invalid AND surroundCodec = "ac3" then
            mediaItem.canDirectPlay = true
            return true
        end if

        if stereoCodec <> invalid AND (stereoCodec = "aac" OR stereoCodec = "ac3") then
            mediaItem.canDirectPlay = true
            return true
        end if

        Debug("videoCanDirectPlay: ac not aac/ac3")
        return false
    end if

    if mediaItem.container = "wmv" then
        ' TODO: What exactly should we check here?

        ' Based on docs, only WMA9.2 is supported for audio
        if stereoCodec = invalid OR Left(stereoCodec, 3) <> "wma" then
            Debug("videoCanDirectPlay: ac not stereo wmav2")
            return false
        end if

        ' Video support is less obvious. WMV9 up to 480p, VC-1 up to 1080p?
        if mediaItem.videoCodec <> "wmv3" AND mediaItem.videoCodec <> "vc1" then
            Debug("videoCanDirectPlay: vc not wmv3/vc1")
            return false
        end if

        mediaItem.canDirectPlay = true
        return true
    end if

    if mediaItem.container = "mkv" then
        if major < 4 then
            Debug("videoCanDirectPlay: mkv not supported by version " + tostr(major))
            return false
        else
            ' TODO(schuyler): Reenable for 4+ only if/when we can figure out
            ' why so many MKVs fail.
            Debug("videoCanDirectPlay: mkv (temporarily?) disallowed for version " + tostr(major))
            return false
        end if

        if mediaItem.videoCodec <> "h264" then
            Debug("videoCanDirectPlay: vc not h264")
            return false
        end if

        if device.hasFeature("5.1_surround_sound") AND surroundCodec <> invalid AND surroundCodec = "ac3" then
            mediaItem.canDirectPlay = true
            return true
        end if

        if stereoCodec <> invalid AND (stereoCodec = "aac" OR stereoCodec = "ac3" OR stereoCodec = "mp3") then
            mediaItem.canDirectPlay = true
            return true
        end if

        Debug("videoCanDirectPlay: ac not aac/ac3/mp3")
        return false
    end if

    if mediaItem.container = "hls" then
        if mediaItem.videoCodec <> "h264" then
            Debug("videoCanDirectPlay: vc not h264")
            return false
        end if

        if (mediaItem.audioCodec <> "aac" AND mediaItem.audioCodec <> "ac3" AND mediaItem.audioCodec <> "mp3") then
            Debug("videoCanDirectPlay: ac not aac/ac3/mp3")
            return false
        end if

        mediaItem.canDirectPlay = true
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
        Debug("MediaPlayer::playVideo: Reacting to video screen event message -> " + tostr(msg))
        if transcoded then server.PingTranscode()
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then
                Debug("MediaPlayer::playVideo::VideoScreenEvent::isScreenClosed: position -> " + tostr(lastPosition))
                if metadata.ratingKey <> invalid then
                    if played then
                        Debug("MediaPlayer::playVideo::VideoScreenEvent::isScreenClosed: scrobbling media -> " + tostr(metadata.ratingKey))
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
                        Debug("MediaPlayer::playVideo::VideoScreenEvent::isPlaybackPosition: position -> " + tostr(lastPosition) + " playedFraction -> " + tostr(playedFraction))
                        if playedFraction > scrobbleThreshold then
                            played = true
                        end if
                    end if
                    Debug("MediaPlayer::playVideo::VideoScreenEvent::isPlaybackPosition: set progress -> " + tostr(1000*lastPosition))
                    server.SetProgress(metadata.ratingKey, metadata.mediaContainerIdentifier, 1000*lastPosition)
                end if
            else if msg.isRequestFailed() then
                Debug("MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - message = " + tostr(msg.GetMessage()))
                Debug("MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - data = " + tostr(msg.GetData()))
                Debug("MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - index = " + tostr(msg.GetIndex()))
                success = false
            else if msg.isPaused() then
                Debug("MediaPlayer::playVideo::VideoScreenEvent::isPaused: position -> " + tostr(lastPosition))
            else if msg.isPartialResult() then
                if metadata.Length <> invalid AND metadata.Length > 0 then
                	playedFraction = lastPosition/metadata.Length
                	Debug("MediaPlayer::playVideo::VideoScreenEvent::isPartialResult: position -> " + tostr(lastPosition) + " playedFraction -> " + tostr(playedFraction))
            		if playedFraction > scrobbleThreshold then
            			played = true
            		end if
            	end if
                if transcoded then server.StopVideo()
            else if msg.isFullResult() then
            	Debug("MediaPlayer::playVideo::VideoScreenEvent::isFullResult: position -> " + tostr(lastPosition))
    			played = true
                if transcoded then server.StopVideo()
                success = true
            else if msg.isStreamStarted() then
            	Debug("MediaPlayer::playVideo::VideoScreenEvent::isStreamStarted: position -> " + tostr(lastPosition))
            	Debug("Message data -> " + tostr(msg.GetInfo()))

                if msg.GetInfo().IsUnderrun = true then
                    underrunCount = underrunCount + 1
                    if underrunCount = 4 and not GetGlobalAA().DoesExist("underrun_warning_shown") then
                        GetGlobalAA().AddReplace("show_underrun_warning", "1")
                    end if
                end if
            else
                Debug("Unknown event: " + tostr(msg.GetType()) + " msg: " + tostr(msg.GetMessage()))
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
        { title: "10.0 Mbps, 1080p", EnumValue: "10" }
        { title: "12.0 Mbps, 1080p", EnumValue: "11" }
        { title: "20.0 Mbps, 1080p", EnumValue: "12" }
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

    if item.preferredMediaItem <> invalid AND item.preferredMediaItem.preferredPart <> invalid then
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
    end if

    ' Audio streams
    Debug("Found audio streams: " + tostr(audioStreams.Count()))
    if audioStreams.Count() > 0 then
        obj.Prefs["audio"] = {
            values: audioStreams,
            label: "Audio Stream",
            heading: "Select an audio stream",
            default: defaultAudio
        }
    end if

    ' Subtitle streams
    Debug("Found subtitle streams: " + tostr(subtitleStreams.Count() - 1))
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
                Debug("Closing video options screen")
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

Function shouldUseSoftSubs(stream) As Boolean
    if RegRead("softsubtitles", "preferences", "1") = "0" then return false
    if stream.codec <> "srt" then return false

    ' TODO(schuyler) If Roku adds support for non-Latin characters, remove
    ' this hackery. To the extent that we continue using this hackery, it
    ' seems that the Roku requires UTF-8 subtitles but only supports characters
    ' from Windows-1252. This should be the full set of languages that are
    ' completely representable in Windows-1252. PMS should specifically be
    ' returning ISO 639-2/B language codes.

    if m.SoftSubLanguages = invalid then
        m.SoftSubLanguages = {
            afr: 1,
            alb: 1,
            baq: 1,
            bre: 1,
            cat: 1,
            dan: 1,
            eng: 1,
            fao: 1,
            glg: 1,
            ger: 1,
            ice: 1,
            may: 1,
            gle: 1,
            ita: 1,
            lat: 1,
            ltz: 1,
            nor: 1,
            oci: 1,
            por: 1,
            roh: 1,
            gla: 1,
            spa: 1,
            swa: 1,
            swe: 1,
            wln: 1,
            est: 1,
            fin: 1,
            fre: 1,
            dut: 1
        }
    end if

    if stream.languageCode = invalid OR m.SoftSubLanguages.DoesExist(stream.languageCode) then return true

    return false
End Function

