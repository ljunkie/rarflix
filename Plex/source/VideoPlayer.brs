'*
'* A wrapper around a video player that implements are screen interface.
'*

Function createVideoPlayerScreen(metadata, seekValue, directPlayOptions, viewController)
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    obj.Item = metadata

    obj.Show = videoPlayerShow
    obj.HandleMessage = videoPlayerHandleMessage
    obj.OnTimerExpired = videoPlayerOnTimerExpired

    obj.SeekValue = seekValue
    obj.DirectPlayOptions = directPlayOptions
    obj.CreateVideoPlayer = videoPlayerCreateVideoPlayer

    obj.pingTimer = invalid
    obj.lastPosition = 0
    obj.isPlayed = false
    obj.playbackError = false
    obj.underrunCount = 0

    obj.Cleanup = videoPlayerCleanup
    obj.ShowPlaybackError = videoPlayerShowPlaybackError

    return obj
End Function

Sub videoPlayerShow()
    if NOT m.playbackError then
        m.Screen = m.CreateVideoPlayer()
    else if m.DirectPlayOptions = 0 OR m.DirectPlayOptions = 2 then
        m.DirectPlayOptions = 3
        m.Screen = m.CreateVideoPlayer()
    else
        Debug("Error while playing video, nothing left to fall back to")
        m.ShowPlaybackError()
        m.Screen = invalid
    end if

    if m.Screen <> invalid then
        if m.IsTranscoded then
            Debug("Starting to play transcoded video", m.Item.server)

            if m.pingTimer = invalid then
                m.pingTimer = createTimer()
                m.pingTimer.Name = "ping"
                m.pingTimer.SetDuration(60005, true)
                m.ViewController.AddTimer(m.pingTimer, m)
            end if

            m.pingTimer.Active = true
            m.pingTimer.Mark()
        else
            Debug("Starting to direct play video", m.Item.server)
        end if

        m.Screen.Show()
    else
        m.ViewController.PopScreen(m)
        m.Cleanup()
    end if
End Sub

Function videoPlayerCreateVideoPlayer()
    Debug("MediaPlayer::playVideo: Displaying video: " + tostr(m.Item.title))
    seconds = int(m.SeekValue/1000)
    server = m.Item.server

    if (m.Item.preferredMediaItem <> invalid AND m.Item.preferredMediaItem.forceTranscode <> invalid) AND (m.DirectPlayOptions <> 1 AND m.DirectPlayOptions <> 2) then
        m.DirectPlayOptions = 4
    end if

    origDirectPlayOptions = RegRead("directplay", "preferences", "0")
    if origDirectPlayOptions <> m.DirectPlayOptions.tostr() then
        Debug("Temporarily overwriting direct play preference to: " + tostr(m.DirectPlayOptions))
        RegWrite("directplay", m.DirectPlayOptions.tostr(), "preferences")
        RegWrite("directplay_restore", origDirectPlayOptions, "preferences")
        Capabilities(true)
    else
        origDirectPlayOptions = invalid
    end if

    videoItem = server.ConstructVideoItem(m.Item, seconds, m.DirectPlayOptions < 3, m.DirectPlayOptions = 1 OR m.DirectPlayOptions = 2)

    if videoItem = invalid then
        Debug("Can't play video, server was unable to construct video item", server)
        if m.DirectPlayOptions >= 3 OR m.DirectPlayOptions = 1 then
            m.ShowPlaybackError()
            return invalid
        else
            ' Force transcoding this time
            m.DirectPlayOptions = 3
            return m.CreateVideoPlayer()
        end if
    end if

    videoPlayer = CreateObject("roVideoScreen")
    videoPlayer.SetMessagePort(m.Port)
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

    m.IsTranscoded = videoItem.IsTranscoded

    return videoPlayer
End Function

Sub videoPlayerCleanup()
    origDirectPlayOptions = RegRead("directplay_restore", "preferences", invalid)
    if origDirectPlayOptions <> invalid then
        Debug("Restoring direct play options to: " + origDirectPlayOptions)
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
            m.Item.preferredMediaItem = PickMediaItem(m.Item.media, m.Item.HasDetails)
            m.OrigQuality = dialog.Quality
        end if
    end if

    if m.Item.RestoreSubtitleID <> invalid then
        Debug("Restoring subtitle selection")
        m.Item.server.UpdateSubtitleStreamSelection(m.Item.RestoreSubtitlePartID, m.Item.RestoreSubtitleID)
    end if
End Sub

Sub videoPlayerShowPlaybackError()
    if m.DirectPlayOptions >= 3 then
        ' Nothing left to fall back to, tell the user
        dialog = createBaseDialog()
        dialog.Title = "Video Unavailable"
        dialog.Text = "We're unable to play this video, make sure the server is running and has access to this video."
        dialog.Show()
    else if m.DirectPlayOptions = 1 then
        dialog = createBaseDialog()
        dialog.Title = "Direct Play Unavailable"
        dialog.Text = "This video isn't supported for Direct Play."
        dialog.Show()
    end if
End Sub

Function videoPlayerHandleMessage(msg) As Boolean
    handled = false
    server = m.Item.server

    Debug("MediaPlayer::playVideo: Reacting to video screen event message -> " + tostr(msg))

    if type(msg) = "roVideoScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isScreenClosed: position -> " + tostr(m.lastPosition))
            if m.Item.ratingKey <> invalid then
                if m.isPlayed then
                    Debug("MediaPlayer::playVideo::VideoScreenEvent::isScreenClosed: scrobbling media -> " + tostr(m.Item.ratingKey))
                    server.Scrobble(m.Item.ratingKey, m.Item.mediaContainerIdentifier)
                else
                    server.SetProgress(m.Item.ratingKey, m.Item.mediaContainerIdentifier, 1000 * m.lastPosition)
                end if
            end if
            if m.IsTranscoded then server.StopVideo()

            if m.playbackError then
                m.Show()
            else
                m.ViewController.PopScreen(m)
                m.Cleanup()
            end if
        else if msg.isPlaybackPosition() then
            m.lastPosition = msg.GetIndex()
            if m.pingTimer <> invalid then m.pingTimer.Mark()
            if m.Item.ratingKey <> invalid then
                if m.Item.Length <> invalid AND m.Item.Length > 0 then
                    playedFraction = m.lastPosition/m.Item.Length
                    Debug("MediaPlayer::playVideo::VideoScreenEvent::isPlaybackPosition: position -> " + tostr(m.lastPosition) + " playedFraction -> " + tostr(playedFraction))
                    if playedFraction > 0.90 then
                        m.isPlayed = true
                    end if
                end if
                Debug("MediaPlayer::playVideo::VideoScreenEvent::isPlaybackPosition: set progress -> " + tostr(1000*m.lastPosition))
                server.SetProgress(m.Item.ratingKey, m.Item.mediaContainerIdentifier, 1000*m.lastPosition)
            end if
        else if msg.isRequestFailed() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - message = " + tostr(msg.GetMessage()))
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - data = " + tostr(msg.GetData()))
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - index = " + tostr(msg.GetIndex()))
            m.playbackError = true
        else if msg.isPaused() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isPaused: position -> " + tostr(m.lastPosition))
        else if msg.isPartialResult() then
            if m.Item.Length <> invalid AND m.Item.Length > 0 then
                playedFraction = m.lastPosition/m.Item.Length
                Debug("MediaPlayer::playVideo::VideoScreenEvent::isPartialResult: position -> " + tostr(m.lastPosition) + " playedFraction -> " + tostr(playedFraction))
                if playedFraction > 0.90 then
                    m.isPlayed = true
                end if
            end if
            if m.IsTranscoded then server.StopVideo()
        else if msg.isFullResult() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isFullResult: position -> " + tostr(m.lastPosition))
            m.isPlayed = true
            if m.IsTranscoded then server.StopVideo()
        else if msg.isStreamStarted() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isStreamStarted: position -> " + tostr(m.lastPosition))
            Debug("Message data -> " + tostr(msg.GetInfo()))

            if msg.GetInfo().IsUnderrun = true then
                m.underrunCount = m.underrunCount + 1
                if m.underrunCount = 4 and not GetGlobalAA().DoesExist("underrun_warning_shown") then
                    GetGlobalAA().AddReplace("show_underrun_warning", "1")
                end if
            end if
        else
            Debug("Unknown event: " + tostr(msg.GetType()) + " msg: " + tostr(msg.GetMessage()))
        end if
    end if

    return handled
End Function

Sub videoPlayerOnTimerExpired(timer)
    if m.IsTranscoded then
        m.Item.server.PingTranscode()
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

Function videoGetEnumValue(key)
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

