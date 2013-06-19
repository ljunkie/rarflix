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
    obj.Cleanup = videoPlayerCleanup

    obj.SeekValue = seekValue
    obj.DirectPlayOptions = directPlayOptions
    obj.CreateVideoPlayer = videoPlayerCreateVideoPlayer

    obj.pingTimer = invalid
    obj.lastPosition = 0
    obj.isPlayed = false
    obj.playbackError = false
    obj.underrunCount = 0
    obj.playbackTimer = createTimer()
    obj.timelineTimer = invalid
    obj.playState = "buffering"
    obj.bufferingTimer = createTimer()

    obj.ShowPlaybackError = videoPlayerShowPlaybackError
    obj.SendTimeline = videoPlayerSendTimeline

    obj.curPart = metadata.SelectPartForOffset(seekValue)

    return obj
End Function

Sub videoPlayerShow()
    ' We only fall back automatically if we originally tried to Direct Play
    ' and the preference allows fallback. One potential quirk is that we do
    ' fall back if there was progress on the Direct Play attempt. This should
    ' be quite uncommon, but if something happens part way through the file
    ' that the device can't handle, we at least give transcoding (from there)
    ' a shot.

    if NOT m.playbackError then
        m.Screen = m.CreateVideoPlayer()
    else if (m.DirectPlayOptions = 0 OR m.DirectPlayOptions = 2) AND NOT m.IsTranscoded then
        m.playbackError = false
        m.DirectPlayOptions = 3
        m.Screen = m.CreateVideoPlayer()
    else
        Debug("Error while playing video, nothing left to fall back to")
        m.ShowPlaybackError()
        m.Screen = invalid
        m.popOnActivate = true
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

        m.timelineTimer = createTimer()
        m.timelineTimer.Name = "timeline"
        m.timelineTimer.SetDuration(15000, true)
        m.ViewController.AddTimer(m.timelineTimer, m)

        m.playbackTimer.Mark()
        m.Screen.Show()
    else
        m.ViewController.PopScreen(m)
    end if
End Sub

Function videoPlayerCreateVideoPlayer()
    Debug("MediaPlayer::playVideo: Displaying video: " + tostr(m.Item.title))
    server = m.Item.server
    mediaItem = m.Item.preferredMediaItem

    ' This is unusual, but if we're in a fallback scenario where Direct Play
    ' faild part way through, use the last reported position as the offset
    ' for the transcoder.
    if m.lastPosition > 0 then
        startOffset = m.lastPosition
    else
        startOffset = int(m.SeekValue/1000)
    end if

    if mediaItem <> invalid AND mediaItem.parts.Count() > mediaItem.curPartIndex then
        m.curPartOffset = int(mediaItem.parts[mediaItem.curPartIndex].startOffset / 1000)
        startOffset = startOffset - m.curPartOffset
        if startOffset < 0 then startOffset = 0
    else
        m.curPartOffset = 0
    end if

    if (mediaItem <> invalid AND mediaItem.forceTranscode <> invalid) AND (m.DirectPlayOptions <> 1 AND m.DirectPlayOptions <> 2) then
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

    videoItem = server.ConstructVideoItem(m.Item, startOffset, m.DirectPlayOptions < 3, m.DirectPlayOptions = 1 OR m.DirectPlayOptions = 2)

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
    videoPlayer.EnableCookies()

    ' If we're playing the video from the server, add appropriate X-Plex
    ' headers.
    if server.IsRequestToServer(videoItem.StreamUrls[0]) then
        AddPlexHeaders(videoPlayer, server.AccessToken)
    end if

    videoPlayer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    videoPlayer.SetCertificatesDepth(5)
    videoPlayer.SetContent(videoItem)

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
        dialog.Item = m.Item
        dialog.Show()
    end if

    if m.Item.RestoreSubtitleID <> invalid then
        Debug("Restoring subtitle selection")
        m.Item.server.UpdateStreamSelection("subtitle", m.Item.RestoreSubtitlePartID, m.Item.RestoreSubtitleID)
    end if
End Sub

Sub videoPlayerShowPlaybackError()
    dialog = createBaseDialog()

    if m.curPart <> invalid AND NOT m.curPart.exists then
        dialog.Title = "Video Unavailable"
        dialog.Text = "Please check that this file exists and the necessary drive is mounted."
    else if m.curPart <> invalid AND NOT m.curPart.accessible then
        dialog.Title = "Video Unavailable"
        dialog.Text = "Please check that this file exists and has appropriate permissions."
    else if m.DirectPlayOptions = 1 then
        dialog.Title = "Direct Play Unavailable"
        dialog.Text = "This video isn't supported for Direct Play."
    else if m.Item.server <> invalid AND m.Item.server.SupportsVideoTranscoding = false then
        dialog.Title = "Transcoding Unavailable"
        dialog.Text = "Your Plex Media Server doesn't support video transcoding."
    else ' This should imply m.IsTranscoding, but make sure we always show something
        ' Nothing left to fall back to, tell the user
        dialog.Title = "Video Unavailable"
        dialog.Text = "We're unable to play this video, make sure the server is running and has access to this video."
    end if

    dialog.Show()
End Sub

Function videoPlayerHandleMessage(msg) As Boolean
    handled = false
    server = m.Item.server

    if type(msg) = "roVideoScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.timelineTimer.Active = false
            m.playState = "stopped"
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isScreenClosed: position -> " + tostr(m.lastPosition))
            m.SendTimeline()
            if m.IsTranscoded then server.StopVideo()

            ' Send an analytics event.
            startOffset = int(m.SeekValue/1000)
            amountPlayed = m.lastPosition - startOffset
            if amountPlayed > m.playbackTimer.GetElapsedSeconds() then amountPlayed = m.playbackTimer.GetElapsedSeconds()
            Debug("Sending analytics event, appear to have watched video for " + tostr(amountPlayed) + " seconds")
            m.ViewController.Analytics.TrackEvent("Playback", firstOf(m.Item.ContentType, "clip"), m.Item.mediaContainerIdentifier, amountPlayed)

            mediaItem = m.Item.preferredMediaItem

            ' If there was an error, try again on the current part. If there's
            ' a potential fallback, it'll be tried, otherwise an error will be
            ' shown. If we played the current part and there are more parts,
            ' increment the part index and show another video player. Otherwise,
            ' we're done.

            if m.playbackError then
                m.Show()
            else if m.isPlayed AND mediaItem <> invalid AND (mediaItem.parts.Count() - 1) > mediaItem.curPartIndex then
                mediaItem.curPartIndex = mediaItem.curPartIndex + 1
                mediaItem.parts[mediaItem.curPartIndex].startOffset = m.lastPosition * 1000
                m.isPlayed = false
                m.Show()
            else
                m.ViewController.PopScreen(m)
            end if
        else if msg.isPlaybackPosition() then
            if m.bufferingTimer <> invalid then
                m.ViewController.Analytics.TrackTiming(m.bufferingTimer.GetElapsedMillis(), "buffering", tostr(m.IsTranscoded), m.Item.mediaContainerIdentifier)
                m.bufferingTimer = invalid
            end if
            mediaItem = m.Item.preferredMediaItem
            m.lastPosition = m.curPartOffset + msg.GetIndex()
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isPlaybackPosition: set progress -> " + tostr(1000*m.lastPosition))

            if mediaItem <> invalid AND validint(mediaItem.duration) > 0 then
                playedFraction = (m.lastPosition * 1000)/mediaItem.duration
                if playedFraction > 0.90 then
                    m.isPlayed = true
                end if
            end if
            m.playState = "playing"
            m.SendTimeline(true)
        else if msg.isRequestFailed() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - message = " + tostr(msg.GetMessage()))
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - data = " + tostr(msg.GetData()))
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - index = " + tostr(msg.GetIndex()))
            m.playbackError = true
        else if msg.isPaused() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isPaused: position -> " + tostr(m.lastPosition))
            m.playState = "paused"
            m.SendTimeline()
        else if msg.isResumed() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isResumed")
            m.playState = "playing"
            m.SendTimeline()
        else if msg.isPartialResult() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isPartialResult: position -> " + tostr(m.lastPosition))
            m.playState = "stopped"
            m.SendTimeline()
            if m.IsTranscoded then server.StopVideo()
        else if msg.isFullResult() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isFullResult: position -> " + tostr(m.lastPosition))
            m.isPlayed = true
            m.playState = "stopped"
            m.SendTimeline()
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
        else if msg.GetType() = 31 then
            ' TODO(schuyler): DownloadDuration is completely incomprehensible to me.
            ' It doesn't seem like it could be seconds or milliseconds, and I couldn't
            ' seem to do anything to artificially affect it by tweaking PMS.
            segInfo = msg.GetInfo()
            Debug("Downloaded segment " + tostr(segInfo.Sequence) + " in " + tostr(segInfo.DownloadDuration) + "?s (" + tostr(segInfo.SegSize) + " bytes, buffer is now " + tostr(segInfo.BufferLevel) + "/" + tostr(segInfo.BufferSize))
        else if msg.GetType() = 27 then
            ' This is an HLS Segment Info event. We don't really need to do
            ' anything with it. It includes info like the stream bandwidth,
            ' sequence, URL, and start time.
        else
            Debug("Unknown event: " + tostr(msg.GetType()) + " msg: " + tostr(msg.GetMessage()))
        end if
    end if

    return handled
End Function

Sub videoPlayerOnTimerExpired(timer)
    if timer.Name = "ping" then
        m.Item.server.PingTranscode()
    else if timer.Name = "timeline"
        m.SendTimeline(true)
    end if
End Sub

Sub videoPlayerSendTimeline(force=false)
    ' We can only send the event if we have some basic info about the item
    if m.Item.ratingKey = invalid OR m.Item.RawLength = invalid OR m.Item.server = invalid then
        m.timelineTimer.Active = false
        return
    end if

    ' Avoid duplicates
    if m.playState = m.lastTimelineState AND NOT force then return

    m.lastTimelineState = m.playState
    m.Item.server.Timeline(m.Item, m.playState, 1000 * m.lastPosition, m.isPlayed)
    m.timelineTimer.Mark()
End Sub

Function qualityHandleButton(key, data) As Boolean
    if key = "quality" then
        quality = GetQualityForItem(m.Item)
        Debug("Lowering quality from original value: " + tostr(quality))
        newQuality = invalid

        if quality >= 10 then
            newQuality = 9
        else if quality >= 9 then
            newQuality = 7
        else if quality >= 6 then
            newQuality = 5
        else if quality >= 5 then
            newQuality = 4
        end if

        if newQuality <> invalid then
            Debug("New quality: " + tostr(newQuality))
            if m.Item.server <> invalid AND m.Item.server.local = true AND m.Item.isLibraryContent = true then
                RegWrite("quality", newQuality.tostr(), "preferences")
            else
                RegWrite("quality_remote", newQuality.tostr(), "preferences")
            end if
            RegDelete("quality_override", "preferences")
            m.Item.PickMediaItem(m.Item.HasDetails)
        end if
    end if
    return true
End Function

Function videoCanDirectPlay(mediaItem) As Boolean
    if mediaItem = invalid then
        Debug("Media item has no Video object, can't direct play")
        return false
    end if

    ' With the Roku 3, the surround sound support may have changed because of
    ' the headphones in the remote. If we have a cached direct play decision,
    ' we need to make sure the surround sound support hasn't changed and
    ' possibly reevaluate.
    surroundSound = SupportsSurroundSound(false, false)
    if mediaItem.canDirectPlay <> invalid AND surroundSound = mediaItem.cachedSurroundSound then
        return mediaItem.canDirectPlay
    end if
    mediaItem.canDirectPlay = false
    mediaItem.cachedSurroundSound = surroundSound

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
    ' But if there's a surround AAC stream before a stereo AAC stream, that
    ' doesn't work.

    stereoCodec = invalid
    surroundCodec = invalid
    secondaryStreamSelected = false
    surroundStreamFirst = false
    numAudioStreams = 0
    numVideoStreams = 0
    videoStream = invalid
    if mediaItem.preferredPart <> invalid then
        if mediaItem.preferredPart.hasChapterVideoStream then numVideoStreams = 1
        for each stream in mediaItem.preferredPart.streams
            if stream.streamType = "2" then
                numAudioStreams = numAudioStreams + 1
                numChannels = firstOf(stream.channels, "0").toint()
                if numChannels <= 2 then
                    if stereoCodec = invalid then
                        stereoCodec = stream.codec
                        surroundStreamFirst = (surroundCodec <> invalid)
                    else if stream.selected <> invalid then
                        secondaryStreamSelected = true
                    end if
                else if numChannels >= 6 then
                    ' The Roku is just passing through the surround sound, so
                    ' it theoretically doesn't care whether there were 6 channels
                    ' or 60.
                    if surroundCodec = invalid then
                        surroundCodec = stream.codec
                    else if stream.selected <> invalid then
                        secondaryStreamSelected = true
                    end if
                else
                    Debug("Unexpected channels on audio stream: " + tostr(stream.channels))
                end if
            else if stream.streamType = "1" then
                numVideoStreams = numVideoStreams + 1
                if videoStream = invalid OR stream.selected <> invalid then
                    videoStream = stream
                end if
            end if
        next
    end if

    Debug("Media item optimized for streaming: " + tostr(mediaItem.optimized))
    Debug("Media item container: " + tostr(mediaItem.container))
    Debug("Media item video codec: " + tostr(mediaItem.videoCodec))
    Debug("Media item audio codec: " + tostr(mediaItem.audioCodec))
    Debug("Media item subtitles: " + tostr(subtitleFormat))
    Debug("Media item stereo codec: " + tostr(stereoCodec))
    Debug("Media item surround codec: " + tostr(surroundCodec))
    Debug("Secondary audio stream selected: " + tostr(secondaryStreamSelected))
    Debug("Media item aspect ratio: " + tostr(mediaItem.aspectRatio))

    ' If no streams are provided, treat the Media audio codec as stereo.
    if numAudioStreams = 0 then
        stereoCodec = mediaItem.audioCodec
    end if

    ' Multiple video streams aren't supported, regardless of type.
    if numVideoStreams > 1 then
        Debug("videoCanDirectPlay: multiple video streams")
        return false
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

        if surroundStreamFirst AND surroundCodec = "aac" then
            Debug("videoCanDirectPlay: first audio stream is 5.1 AAC")
            return false
        end if

        if surroundSound AND (surroundCodec = "ac3" OR stereoCodec = "ac3") then
            mediaItem.canDirectPlay = true
            return true
        end if

        if stereoCodec = "aac" then
            mediaItem.canDirectPlay = true
            return true
        end if

        if stereoCodec = invalid AND numAudioStreams = 0 AND major >= 4 then
            ' If everything else looks ok and there are no audio streams, that's
            ' fine on Roku 2+.
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

        if surroundSound AND (surroundCodec = "ac3" OR stereoCodec = "ac3") then
            mediaItem.canDirectPlay = true
            return true
        end if

        if stereoCodec <> invalid AND (stereoCodec = "aac" OR stereoCodec = "mp3") then
            mediaItem.canDirectPlay = true
            return true
        end if

        Debug("videoCanDirectPlay: ac not aac/ac3/mp3")
        return false
    end if

    if mediaItem.container = "hls" then
        ' HLS is a bit of a special case. We can only direct play certain codecs,
        ' but PMS won't always successfully transcode the HLS.

        if isnonemptystr(mediaItem.videoCodec) AND mediaItem.videoCodec <> "h264" then
            Debug("videoCanDirectPlay: vc not h264")
            'return false
        end if

        if isnonemptystr(mediaItem.audioCodec) AND (mediaItem.audioCodec <> "aac" AND mediaItem.audioCodec <> "ac3" AND mediaItem.audioCodec <> "mp3") then
            Debug("videoCanDirectPlay: ac not aac/ac3/mp3")
            'return false
        end if

        mediaItem.canDirectPlay = true
        return true
    end if

    return false
End Function

Function shouldUseSoftSubs(stream) As Boolean
    if RegRead("softsubtitles", "preferences", "1") = "0" then return false
    if stream.codec <> "srt" or stream.key = invalid then return false

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
