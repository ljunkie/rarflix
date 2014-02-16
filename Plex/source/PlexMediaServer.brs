'*
'* Facade to a PMS server responsible for fetching PMS meta-data and
'* formatting into Roku format as well providing the interface to the
'* streaming media
'*

'* Constructor for a specific PMS instance identified via the URL and
'* human readable name, which can be used in section names
Function newPlexMediaServer(pmsUrl, pmsName, machineID, useMyPlexToken=true) As Object
    pms = CreateObject("roAssociativeArray")
    pms.serverUrl = pmsUrl
    pms.name = firstOf(pmsName, "Unknown")
    pms.machineID = machineID
    pms.owned = true
    pms.synced = false
    pms.online = false
    pms.local = false
    pms.AccessToken = invalid
    pms.StopVideo = stopTranscode
    pms.StartTranscode = StartTranscodingSession
    pms.PingTranscode = pingTranscode
    pms.CreateRequest = pmsCreateRequest
    pms.GetQueryResponse = xmlContent
    pms.Timeline = pmsTimeline
    pms.Scrobble = scrobble
    pms.Unscrobble = unscrobble
    pms.Delete = pmsDelete
    pms.Rate = rate
    pms.setPref = setpref
    pms.ExecuteCommand = issueCommand
    pms.ExecutePostCommand = issuePostCommand
    pms.UpdateStreamSelection = pmsUpdateStreamSelection
    pms.TranscodedImage = TranscodedImage
    pms.ConstructVideoItem = pmsConstructVideoItem
    pms.ClassicTranscodingVideoUrl = classicTranscodingVideoUrl
    pms.UniversalTranscodingVideoUrl = universalTranscodingVideoUrl
    pms.TranscodingVideoUrl = TranscodingVideoUrl
    pms.TranscodingAudioUrl = TranscodingAudioUrl
    pms.ConvertURLToLoopback = ConvertURLToLoopback
    pms.IsRequestToServer = pmsIsRequestToServer
    pms.AddDirectPlayInfo = pmsAddDirectPlayInfo
    pms.Log = pmsLog
    pms.SendWOL = pmsSendWOL
    pms.putOnDeck = pmsPutOnDeck

    ' RARflix Tools
    '  - maybe more to come, but I'd prefer these part of the PMS
    '  2013-12-27: PosterTranscoder - will allow watched status and progress indicator overlay on Posters/Thumbs
    pms.rarflixtools = invalid

    ' Set to false if a version check fails
    pms.SupportsAudioTranscoding = true
    pms.SupportsVideoTranscoding = true
    pms.SupportsPhotoTranscoding = true
    pms.SupportsUniversalTranscoding = true
    pms.AllowsMediaDeletion = false
    pms.IsConfigured = false
    pms.IsAvailable = false
    pms.IsSecondary = false
    pms.SupportsMultiuser = false

    ' For using the view controller for HTTP requests
    pms.ScreenID = -3
    pms.OnUrlEvent = pmsOnUrlEvent

    pms.lastTimelineItem = invalid
    pms.lastTimelineState = invalid
    pms.timelineTimer = createTimer()
    pms.timelineTimer.SetDuration(15000, true)

    return pms
End Function

Function newSyntheticPlexMediaServer(pmsUrl, machineID, token) As Object
    Debug("Creating synthetic server for " + tostr(machineID) + " at " + tostr(pmsUrl))
    pms = newPlexMediaServer(pmsUrl, invalid, machineID)
    pms.owned = false
    pms.online = true
    pms.AccessToken = token
    return pms
End Function

'* This needs a HTTP PUT command that does not exist in the Roku API but it's faked with a POST
Function pmsUpdateStreamSelection(streamType As String, partId As String, streamId As String)
    commandUrl = "/library/parts/"+partId+"?" + streamType + "StreamID="+streamId
    m.ExecutePostCommand(commandUrl)
End Function

Function issuePostCommand(commandPath)
    commandUrl = m.serverUrl + commandPath
    Debug("Executing POST command with full command URL: " + commandUrl)
    request = m.CreateRequest("", commandUrl)
    request.PostFromString("")
End Function

Sub pmsPutOnDeck(item)
    if item = invalid then return
    ' use the existing view offset ( this should already be onDeck, but possible onDeck weeks expired)
    if item.viewOffset <> invalid AND val(item.viewOffset) > 0 then
        time = item.viewOffset
    else 
        time = 10*1000
    end if

    m.Timeline(item, "stopped", time)
end sub

Sub pmsTimeline(item, state, time)
    itemsEqual = (item <> invalid AND m.lastTimelineItem <> invalid AND item.ratingKey = m.lastTimelineItem.ratingKey)

    ' extra precaution -- probably not needed as the issue stemmed from an item not have a RawLength (duration)
    if m.lastTimelineStateCount = invalid then m.lastTimelineStateCount = 0
    m.lastTimelineStateCount = m.lastTimelineStateCount+1

    if itemsEqual AND state = m.lastTimelineState AND NOT m.timelineTimer.IsExpired() and m.lastTimelineStateCount < 30 then return

    m.lastTimelineStateCount = 0
    m.timelineTimer.Mark()
    m.lastTimelineItem = item
    m.lastTimelineState = state

    encoder = CreateObject("roUrlTransfer")

    query = "time=" + tostr(time)
    query = query + "&duration=" + tostr(item.RawLength)
    query = query + "&state=" + state
    if item.guid <> invalid then query = query + "&guid=" + encoder.Escape(item.guid)
    if item.ratingKey <> invalid then query = query + "&ratingKey=" + encoder.Escape(tostr(item.ratingKey))
    if item.url <> invalid then query = query + "&url=" + encoder.Escape(item.url)
    if item.key <> invalid then query = query + "&key=" + encoder.Escape(item.key)
    if item.sourceUrl <> invalid then query = query + "&containerKey=" + encoder.Escape(item.sourceUrl)
 
    request = m.CreateRequest("", "/:/timeline?" + query)
    context = CreateObject("roAssociativeArray")
    context.requestType = "timeline"

    GetViewController().StartRequest(request, m, context)
End Sub

Function scrobble(key, identifier)
    if identifier <> invalid then
        commandUrl = "/:/scrobble?key="+HttpEncode(key)+"&identifier="+identifier
        m.ExecuteCommand(commandUrl)
    end if
End Function

Function unscrobble(key, identifier)
    if identifier <> invalid then
        commandUrl = "/:/unscrobble?key="+HttpEncode(key)+"&identifier="+identifier
        m.ExecuteCommand(commandUrl)
    end if
End Function

Sub pmsDelete(key)
    if key <> invalid then
        Debug("Deleting media at " + key)
        request = m.CreateRequest("", key + "?_method=DELETE")
        request.PostFromString("")
    end if
End Sub

Function rate(key, identifier, rating)
    commandUrl = "/:/rate?key="+HttpEncode(key)+"&identifier="+identifier+"&rating="+rating
    m.ExecuteCommand(commandUrl)
End Function

Function setpref(key, identifier, value)
    commandUrl = key+"/set?"+identifier+"="+HttpEncode(value)
    m.ExecuteCommand(commandUrl)
End Function

Function issueCommand(commandPath)
    commandUrl = m.serverUrl + commandPath
    Debug("Executing command with full command URL: " + commandUrl)
    request = m.CreateRequest("", commandUrl)
    request.GetToString()
End Function

Function pmsCreateRequest(sourceUrl, key, appendToken=true, connectionUrl=invalid) As Object
    url = FullUrl(firstOf(connectionUrl, m.serverUrl), sourceUrl, key)

    ' ljunkie - attempt to convert older API library call to a new filtered call that support paging
    url = convertToFilter(m,url)

    req = CreateURLTransferObject(url)
    AddAccountHeaders(req, m.AccessToken)
    req.AddHeader("X-Plex-Client-Capabilities", Capabilities())
    req.AddHeader("Accept", "application/xml")
    req.SetCertificatesFile("common:/certs/ca-bundle.crt")
    return req
End Function

Function xmlContent(sourceUrl, key) As Object
    xmlResult = CreateObject("roAssociativeArray")
    xmlResult.server = m
    if key = "apps" then
        '* Fake a minimal server response with a new viewgroup
        xml=CreateObject("roXMLElement")
        xml.Parse("<MediaContainer viewgroup='apps'/>")
        xmlResult.xml = xml
        xmlResult.sourceUrl = invalid
    else
        httpRequest = m.CreateRequest(sourceUrl, key)
        Debug("Fetching content from server at query URL: " + tostr(httpRequest.GetUrl()))
        response = GetToStringWithTimeout(httpRequest, 60)
        xml=CreateObject("roXMLElement")
        if not xml.Parse(response) then
            Debug("Can't parse feed: " + tostr(response))
        endif

        xmlResult.xml = xml
        xmlResult.sourceUrl = httpRequest.GetUrl()

        Debug("Finished - Fetching content from server at query URL: " + tostr(httpRequest.GetUrl()))
    endif
    return xmlResult
End Function

Function IndirectMediaXml(server, originalKey, postURL)
    response = invalid
    if postURL <> invalid then
        crlf = Chr(13) + Chr(10)

        Debug("Fetching content for indirect video POST URL: " + postURL)
        httpRequest = server.CreateRequest("", postURL)
        if httpRequest.AsyncGetToString() then
            while true
                msg = wait(60000, httpRequest.GetPort())
                if msg = invalid then
                    httpRequest.AsyncCancel()
                    exit while
                else if type(msg) = "roUrlEvent" AND msg.GetInt() = 1 then
                    postBody = box("")
                    for each header in msg.GetResponseHeadersArray()
                        for each name in header
                            headerStr = name + ": " + header[name] + crlf
                            postBody.AppendString(headerStr, Len(headerStr))
                        next
                    next
                    postBody.AppendString(crlf, 2)

                    getBody = msg.GetString()
                    postBody.AppendString(getBody, len(getBody))

                    exit while
                end if
            end while
        end if

        if postBody <> invalid then
            Debug("Retrieved data from postURL, posting to resolve container")
            if instr(1, originalKey, "?") > 0 then
                url = originalKey + "&postURL=" + HttpEncode(postURL)
            else
                url = originalKey + "?postURL=" + HttpEncode(postURL)
            end if
            httpRequest = server.CreateRequest("", url)
            if httpRequest.AsyncPostFromString(postBody) then
                while true
                    msg = wait(60000, httpRequest.GetPort())
                    if msg = invalid then
                        httpRequest.AsyncCancel()
                        exit while
                    else if type(msg) = "roUrlEvent" AND msg.GetInt() = 1 then
                        response = msg.GetString()
                        exit while
                    end if
                end while
            end if
        else
            Debug("Failed to retrieve data from postURL")
        end if
    else
        httpRequest = server.CreateRequest("", originalKey)
        Debug("Fetching content from server at query URL: " + tostr(httpRequest.GetUrl()))
        response = GetToStringWithTimeout(httpRequest, 60)
    end if

    if response = invalid then
        Debug("Failed to resolve indirect with postURL")
        return invalid
    end if

    xml=CreateObject("roXMLElement")
    if not xml.Parse(response) then
        Debug("Can't parse feed: " + tostr(response))
        return invalid
    endif
    return xml
End Function

Function DirectMediaXml(server, queryUrl) As Object
    httpRequest = server.CreateRequest("", queryUrl)
    Debug("Fetching content from server at query URL: " + tostr(httpRequest.GetUrl()))
    response = GetToStringWithTimeout(httpRequest, 60)
    xml=CreateObject("roXMLElement")
    if not xml.Parse(response) then
        Debug("Can't parse feed: " + tostr(response))
        return originalKey
    endif
    return xml
End Function

Function pmsConstructVideoItem(item, seekValue, allowDirectPlay, forceDirectPlay)
    video = CreateObject("roAssociativeArray")
    video.PlayStart = seekValue
    video.Title = firstOf(item.CleanTitle, item.Title)

    identifier = item.mediaContainerIdentifier
    headers = []
    key = ""
    ratingKey = ""
    mediaItem = item.preferredMediaItem
    if mediaItem <> invalid then
        part = mediaItem.parts[mediaItem.curPartIndex]
    else
        part = invalid
    end if

    ' add Video Relase date to support releaseDate option in Roku HUD - RR
    video.ReleaseDate = tostr(item.ReleaseDate)

    ' set title to title + episode if episode - RR
    if item.EpisodeStr <> invalid then
      video.title = video.title + " - " + item.EpisodeStr
      ' item.TitleSeason could be used instead -- but it removes the Show Title. 
    end if

    if identifier = "com.plexapp.plugins.library" then
        ' Regular library video
        mediaKey = part.key
        key = item.key
        ratingKey = item.ratingKey
        videoRes = mediaItem.videoresolution
        audioCh = mediaitem.audioChannels
        audioCodec = mediaItem.audioCodec
    else if mediaItem = invalid  OR part = invalid then
        ' Plugin video
        mediaKey = item.key
        videoRes = item.videoresolution
        audioCh = item.audioChannels
        audioCodec = item.audioCodec
    else
        ' Plugin video, possibly indirect
        mediaKey = part.key
        postURL = part.postURL
        videoRes = mediaItem.videoresolution
        audioCh = mediaItem.audioChannels
        audioCodec = mediaItem.audioCodec
        if mediaItem.indirect then
            mediaKeyXml = IndirectMediaXml(m, mediaKey, postURL)
            if mediaKeyXml = invalid then
                Debug("Failed to resolve indirect media")
                dlg = createBaseDialog()
                dlg.Title = "Video Unavailable"
                dlg.Text = "Sorry, but we can't play this video. The original video may no longer be available, or it may be in a format that isn't supported."
                dlg.Show(true)
                return invalid
            end if
            mediaKey = mediaKeyXml.Video.Media.Part[0]@key

            if mediaKeyXml@httpHeaders <> invalid AND mediaKeyXml@httpHeaders <> "" then
                tokens = strTokenize(mediaKeyXml@httpHeaders, "&")
                for each token in tokens
                    arr = strTokenize(token, "=")
                    value = {}
                    value[arr[0]] = firstOf(arr[1], " ")
                    headers.Push(value)
                    Debug("Indirect video item header: " + tostr(value))
                next
            end if

            ' HACK
            ' Nothing interesting about the media should have changed while
            ' resolving the indirect, but some plugins use indirect to
            ' optimistically say they'll be MP4s and then wind up being RTMP.
            ' So we do a special check for that that avoids a failed direct
            ' play.
            newContainer = firstOf(parseMediaContainer(mediaKeyXml.Video.Media), mediaItem.container)
            if newContainer <> mediaItem.container then
                mediaItem.container = newContainer
                mediaItem.canDirectPlay = invalid
                Debug("After resolving indirect, set format to " + newContainer)
            end if
        end if
    end if
    ' ADD videoRes for HUD - RR
    video.videoRes = videoRes
    video.audioCh = audioCh
    video.audioCodec = audioCodec

    quality = "SD"
    if GetGlobal("DisplayType") = "HDTV" then quality = "HD"
    Debug("Setting stream quality: " + quality)
    video.StreamQualities = [quality]
    video.HDBranded = item.HDBranded

	'Setup 1080p metadata
    if videoRes = "1080" then
        versionArr = GetGlobal("rokuVersionArr", [0])
        major = versionArr[0]
		if major < 4  then
			if RegRead("legacy1080p","preferences") = "enabled" then
				video.fullHD = true
				video.framerate = 30
				frSetting = RegRead("legacy1080pframerate","preferences","auto")
				if frSetting = "24" then
					video.framerate = 24
				else if frSetting = "auto" and item.framerate = 24 then
					video.framerate = 24
				end if
			end if
		else
			video.fullHD = true
		endif
	endif

    ' Indexes
    if part <> invalid then
        if part.indexes["sd"] <> invalid then video.SDBifUrl = part.indexes["sd"]
        if part.indexes["hd"] <> invalid then video.HDBifUrl = part.indexes["hd"]
    end if

    qualityPref = GetQualityForItem(item)

    if forceDirectPlay then
        if mediaItem = invalid then
            ' If it looks like it might be an MP4, let the user force a Direct
            ' Play. This is mostly a concession for iTunes content (including
            ' podcasts).
            extension = Right(mediaKey, 4)
            if extension = ".mp4" OR extension = ".m4v" OR extension = ".mov" then
                m.AddDirectPlayInfo(video, item, mediaKey)
                return video
            else
                Debug("Can't direct play, plugin video has no media item!")
                return invalid
            end if
        else if left(mediaKey, 5) = "plex:" OR mediaItem.container = "webkit" then
            Debug("Can't direct play plex: URLs: " + tostr(mediaKey))
            return invalid
        else
            video.IndirectHttpHeaders = headers
            m.AddDirectPlayInfo(video, item, mediaKey)
            return video
        end if
    else if allowDirectPlay AND mediaItem <> invalid then
        Debug("Checking to see if direct play of video is possible")
        if qualityPref >= 9 then
            maxResolution = 1080
        else if qualityPref >= 6 then
            maxResolution = 720
        else if qualityPref >= 5 then
            maxResolution = 480
        else
            maxResolution = 0
        end if
        Debug("Max resolution: " + tostr(maxResolution))

        ' Make sure we have a current value for the surround sound support
        SupportsSurroundSound(false, true)
        if (videoCanDirectPlay(mediaItem))
            resolution = firstOf(mediaItem.videoResolution, "0").toInt()
            Debug("Media item resolution: " + tostr(resolution) + ", max is " + tostr(maxResolution))
            if resolution <= maxResolution then
                video.IndirectHttpHeaders = headers
                m.AddDirectPlayInfo(video, item, mediaKey)
                return video
            end if
        end if
    end if

    video.IsTranscoded = true

	'We are transcoding, don't set fullHD if quality isn't 1080p
    if qualityPref < 9 then
        video.fullHD = False
	endif

    video.StreamBitrates = [0]
    video.StreamFormat = "hls"
    video.SwitchingStrategy = "no-adaptation"
    url = m.TranscodingVideoUrl(mediaKey, item, headers, seekValue)
    if url = invalid then return invalid
    video.StreamUrls = [url]

    if m.TranscodeServer <> invalid then
        video.TranscodeServer = m.TranscodeServer
    else
        video.TranscodeServer = m
    end if

    ' If we have SRT subtitles, let the Roku display them itself. They'll
    ' usually be more readable, and it might let us direct stream.

    if mediaItem <> invalid then
        if part <> invalid AND part.subtitles <> invalid AND shouldUseSoftSubs(part.subtitles) then
            Debug("Disabling subtitle selection temporarily")
            video.SubtitleUrl = FullUrl(m.serverUrl, "", part.subtitles.key) + "?encoding=utf-8"
            m.UpdateStreamSelection("subtitle", part.id, "")
            item.RestoreSubtitleID = part.subtitles.id
            item.RestoreSubtitlePartID = part.id
        end if
    end if

    printAA(video)
    return video
End Function

Function stopTranscode()
    if m.Cookie <> invalid then
        stopTransfer = CreateObject("roUrlTransfer")
        stopTransfer.SetUrl(m.serverUrl + "/video/:/transcode/segmented/stop")
        stopTransfer.AddHeader("Cookie", m.Cookie)
        content = stopTransfer.GetToString()
    else
        Debug("Can't send stop request, cookie wasn't set")
    end if
End Function

Function pingTranscode()
    if m.Cookie <> invalid then
        pingTransfer = CreateObject("roUrlTransfer")
        pingTransfer.SetUrl(m.serverUrl + "/video/:/transcode/segmented/ping")
        pingTransfer.AddHeader("Cookie", m.Cookie)
        content = pingTransfer.GetToString()
    else
        Debug("Can't send ping request, cookie wasn't set")
    end if
End Function

'* Constructs a Full URL taking into account relative/absolute. Relative to the
'* source URL, and absolute URLs, so
'* relative to the server URL
Function FullUrl(serverUrl, sourceUrl, key) As String
    finalUrl = ""
    if left(key, 4) = "http" OR left(key, 4) = "rtmp" then
        return key
    else if left(key, 4) = "plex" then
        url_start = Instr(1, key, "url=") + 4
        url_end = Instr(url_start, key, "&")
        url = Mid(key, url_start, url_end - url_start)
        o = CreateObject("roUrlTransfer")
        return o.Unescape(url)
    else if left(key, 6) = "filter" and sourceUrl <> invalid then ' ljunkie - special key to allow filter searches (currently used for Cast and Crew)
         finalUrl = sourceUrl + Right(key, len(key) - 6)
    else
        keyTokens = CreateObject("roArray", 2, true)
        if key <> Invalid then
            keyTokens = strTokenize(key, "?")
        else
            keyTokens.Push("")
        endif
        sourceUrlTokens = CreateObject("roArray", 2, true)
        if sourceUrl <> Invalid then
            sourceUrlTokens = strTokenize(sourceUrl, "?")
        else
            sourceUrlTokens.Push("")
        endif

        if keyTokens[0] = "" AND sourceUrlTokens[0] = "" then
            finalUrl = serverUrl
        else if keyTokens[0] = "" AND serverUrl = "" then
            finalUrl = sourceUrlTokens[0]
        else if keyTokens[0] <> invalid AND left(keyTokens[0], 1) = "/" then
            finalUrl = serverUrl+keyTokens[0]
        else
            if keyTokens[0] <> invalid then
                finalUrl = sourceUrlTokens[0]+"/"+keyTokens[0]
            else
                finalUrl = sourceUrlTokens[0]+"/"
            endif
        endif
        if keyTokens.Count() = 2 then 'OR sourceUrlTokens.Count() =2 then
            finalUrl = finalUrl + "?"
            if keyTokens.Count() = 2 then
                finalUrl = finalUrl + keyTokens[1]
                'if sourceUrlTokens.Count() = 2 then
                    'finalUrl = finalUrl + "&"
                'endif
            endif
            'if sourceUrlTokens.Count() = 2 then
                'finalUrl = finalUrl + sourceUrlTokens[1]
            'endif
        endif
    endif

    ' ljunkie - cleanup any double slashes ( the PMS api doesn't like it )
    '   definitely not a fault of the PMS (include non|encoded ://)
    '   2013-12-13: need to be careful here -- channel content has ...?url=//etc.. which is also valid
    ' NOTE: if these seems to cause other issues ( someone expecting double quotes, we may have to be more specific )
    remDS  = CreateObject("roRegex", "([^:|A|=]/)/+","")
    if remDS.IsMatch(finalUrl) then
        Debug("---- removing double slashes from URL: " + tostr(finalUrl))
        finalUrl = remDS.replaceall(finalUrl,"\1")
        Debug("----  removed double slashes from URL: " + tostr(finalUrl))
    end if

    return finalUrl
End Function


'* Constructs an image based on a PMS url with the specific width and height.
Function TranscodedImage(queryUrl, imagePath, width, height, forceBackgroundColor=GetGlobalAA().Lookup("rfBGcolor")) As String
    imageUrl = FullUrl(m.serverUrl, queryUrl, imagePath)
    if NOT m.SupportsPhotoTranscoding then return imageUrl
    imageUrl = m.ConvertURLToLoopback(imageUrl)
    encodedUrl = HttpEncode(imageUrl)
    image = m.serverUrl + "/photo/:/transcode?url="+encodedUrl+"&width="+width+"&height="+height
    ' use the X-Plex-Token here :: headers are not useable in all scenarios
    if m.AccessToken <> invalid then image = image + "&X-Plex-Token=" + m.AccessToken
    if forceBackgroundColor <> invalid then
        image = image + "&format=jpeg&background=" + forceBackgroundColor
    end if
    return image
End Function

'* Starts a transcoding session by issuing a HEAD request and captures
'* the resultant session ID from the cookie that can then be used to
'* access and stop the transcoding
Function StartTranscodingSession(videoUrl)
    cookiesRequest = CreateObject("roUrlTransfer")
    cookiesRequest.SetUrl(videoUrl)
    cookiesHead = cookiesRequest.Head()
    m.Cookie = cookiesHead.GetResponseHeaders()["set-cookie"]

    if m.Cookie <> invalid then
        arr = strTokenize(m.Cookie, ";")
        m.Cookie = arr[0]
    end if

    return m.Cookie
End Function

'*
'* Construct the Plex transcoding URL.
'*
Function TranscodingVideoUrl(videoUrl As String, item As Object, httpHeaders As Object, seekValue=0)
    ' TODO(schuyler): Once we're comfortable with the percentage of users using
    ' an adequate version, we can probably remove the classic transcoder. Doing
    ' so will actually lead to a variety of changes, since we can let PMS worry
    ' about stuff like indirect resolution and there's no need to have httpHeaders
    ' here.

    ' The universal transcoder doesn't support old school XML with no Media
    ' elements, so check for that and use the old transcoder. It also won't
    ' work when analysis fails and there are no streams. The old transcoder
    ' may not work with those files anyway, but the universal transcoder will
    ' definitely fail.

    hasStreams = false
    if item.preferredMediaItem <> invalid then
        if item.preferredMediaItem.preferredPart <> invalid then
            hasStreams = (item.preferredMediaItem.preferredPart.streams.Count() > 0)
        end if
    end if

    if hasStreams AND m.SupportsUniversalTranscoding AND RegRead("transcoder_version", "preferences", "universal") = "universal" then
        return m.UniversalTranscodingVideoUrl(videoUrl, item, seekValue)
    else
        return m.ClassicTranscodingVideoUrl(videoUrl, item, httpHeaders)
    end if
End Function

Function universalTranscodingVideoUrl(videoUrl As String, item As Object, seekValue As Integer)
    if NOT m.SupportsVideoTranscoding then return invalid

    Debug("Constructing transcoding video URL for " + videoUrl)

    fullKey = m.ConvertURLToLoopback(FullUrl(m.serverUrl, item.sourceUrl, item.key))
    extras = ""

    builder = NewHttp(m.serverUrl + "/video/:/transcode/universal/start.m3u8")

    builder.AddParam("protocol", "hls")
    builder.AddParam("path", fullKey)
    builder.AddParam("session", GetGlobal("rokuUniqueId"))
    builder.AddParam("waitForSegments", "1")
    builder.AddParam("offset", tostr(seekValue))
    builder.AddParam("directPlay", "0")

    versionArr = GetGlobal("rokuVersionArr", [0, 0])
    directPlayOptions = RegRead("directplay", "preferences", "0")
    if (versionArr[0] >= 4 AND directPlayOptions <> "4") OR directPlayOptions = "3" then
        builder.AddParam("directStream", "1")
    else
        builder.AddParam("directStream", "0")
    end if

    quality = GetQualityForItem(item)
    builder.AddParam("videoQuality", GetGlobal("TranscodeVideoQualities")[quality])
    builder.AddParam("videoResolution", GetGlobal("TranscodeVideoResolutions")[quality])
    builder.AddParam("maxVideoBitrate", GetGlobal("TranscodeVideoBitrates")[quality])

    builder.AddParam("subtitleSize", RegRead("subtitle_size", "preferences", "125"))
    builder.AddParam("audioBoost", RegRead("audio_boost", "preferences", "100"))

    if item.preferredMediaItem <> invalid then
        if item.isManuallySelectedMediaItem = true then
            builder.AddParam("mediaIndex", tostr(item.preferredMediaIndex))
        end if
        builder.AddParam("partIndex", tostr(item.preferredMediaItem.curPartIndex))
    end if

    ' Augement the server's profile for things that depend on the Roku's configuration.

    builder.AddParam("X-Plex-Platform", "Roku")

    extras = "add-limitation(scope=videoCodec&scopeName=h264&type=upperBound&name=video.level&value=" + RegRead("level", "preferences", "41") + "&isRequired=true)"

    if SupportsSurroundSound(true, true) then
        if RegRead("fivepointone", "preferences", "1") = "1" then
            extras = extras + "+add-transcode-target-audio-codec(type=videoProfile&context=streaming&protocol=hls&audioCodec=ac3)"
        end if
    end if

    if Len(extras) > 0 then
        builder.AddParam("X-Plex-Client-Profile-Extra", extras)
    end if

    ' We're cheating, but unlike everywhere else, don't include the Roku build. This
    ' makes it easier for us to match against a firmware specific firmware.
    builder.AddParam("X-Plex-Platform-Version", tostr(versionArr[0]) + "." + tostr(versionArr[1]))
    builder.AddParam("X-Plex-Version", GetGlobal("appVersionStr"))
    builder.AddParam("X-Plex-Product", "Plex for Roku")
    builder.AddParam("X-Plex-Device", GetGlobal("rokuModel"))

    return builder.Http.GetUrl()
End Function

Function classicTranscodingVideoUrl(videoUrl As String, item As Object, httpHeaders As Object)
    if NOT m.SupportsVideoTranscoding then return invalid

    Debug("Constructing transcoding video URL for " + videoUrl)

    key = ""
    ratingKey = ""
    identifier = item.mediaContainerIdentifier
    if identifier = "com.plexapp.plugins.library" then
        key = item.key
        ratingKey = item.ratingKey
    end if

    location = FullUrl(m.serverUrl, item.sourceUrl, videoUrl)
    location = m.ConvertURLToLoopback(location)
    Debug("Location: " + tostr(location))
    if len(key) = 0 then
        fullKey = ""
    else
        fullKey = m.ConvertURLToLoopback(FullUrl(m.serverUrl, item.sourceUrl, key))
    end if
    Debug("Original key: " + tostr(key))
    Debug("Full key: " + tostr(fullKey))

    path = "/video/:/transcode/segmented/start.m3u8?"

    query = "offset=0"
    if identifier <> invalid then
        query = query + "&identifier=" + identifier
    end if
    query = query + "&ratingKey=" + HttpEncode(ratingKey)
    if len(fullKey) > 0 then
        query = query + "&key=" + HttpEncode(fullKey)
    end if
    if left(videoUrl, 4) = "plex" OR (item.preferredMediaItem <> invalid AND item.preferredMediaItem.container = "webkit") then
        query = query + "&webkit=1"
    end if

    currentQuality = GetQualityForItem(item)
    if currentQuality = 0 then
        query = query + "&minQuality=4&maxQuality=8"
    else
        query = query + "&quality=" + tostr(currentQuality)
    end if

    ' Forcing longer segment sizes usually mitigates some Roku 2 weirdness
    ' and makes videos load faster. Depending on the speed of the network
    ' and transcoding server though, it could be slower in some cases.
    segmentLength = RegRead("segment_length", "preferences", "10")
    if segmentLength <> "auto" then
        query = query + "&secondsPerSegment=" + segmentLength
    end if

    query = query + "&url=" + HttpEncode(location)
    query = query + "&3g=0"

    for each header in httpHeaders
        for each name in header
            if name = "Cookie" then
                query = query + "&httpCookies=" + HttpEncode(header[name])
            else if name = "User-Agent" then
                query = query + "&userAgent=" + HttpEncode(header[name])
            else
                Debug("Header can not be passed to transcoder at this time: " + name)
            end if
        next
    next

    subtitleSize = RegRead("subtitle_size", "preferences", "125")
    query = query + "&subtitleSize=" + subtitleSize

    audioBoost = RegRead("audio_boost", "preferences", "100")
    if audioBoost <> "100" then
        query = query + "&audioBoost=" + audioBoost
    end if

    publicKey = "KQMIY6GATPC63AIMC4R2"
    time = CreateObject("roDateTime").asSeconds().tostr()
    msg = path + query + "@" + time
    finalMsg = HMACHash(msg)

    query = query + "&X-Plex-Access-Key=" + publicKey
    query = query + "&X-Plex-Access-Time=" + time
    query = query + "&X-Plex-Access-Code=" + HttpEncode(finalMsg)
    query = query + "&X-Plex-Client-Capabilities=" + HttpEncode(Capabilities())

    finalUrl = m.serverUrl + path + query
    Debug("Final URL: " + finalUrl)
    return finalUrl
End Function

Function TranscodingAudioUrl(audioUrl As String, item As Object)
    if NOT m.SupportsAudioTranscoding then return invalid

    Debug("Constructing transcoding audio URL for " + audioUrl)

    location = FullUrl(m.serverUrl, item.sourceUrl, audioUrl)
    location = m.ConvertURLToLoopback(location)
    Debug("Location: " + tostr(location))

    path = "/music/:/transcode/generic.mp3?"

    query = "offset=0"
    query = query + "&format=mp3&audioCodec=libmp3lame"
    ' TODO(schuyler): Should we be doing something other than hardcoding these?
    ' If we don't pass a bitrate the server uses 64k, which we don't want.
    ' There was a rumor that the Roku didn't support 48000 samples, but that
    ' doesn't seem to be true.
    query = query + "&audioBitrate=320&audioSamples=44100"
    query = query + "&url=" + HttpEncode(location)
    query = query + "&X-Plex-Client-Capabilities=" + HttpEncode(Capabilities())

    finalUrl = m.serverUrl + path + query
    Debug("Final URL: " + finalUrl)
    return finalUrl
End Function

Function ConvertURLToLoopback(url) As String
    ' If the URL starts with our serverl URL, replace it with
    ' 127.0.0.1:32400.

    if m.IsRequestToServer(url) then
        url = "http://127.0.0.1:32400" + Right(url, len(url) - len(m.serverUrl))
    end if

    return url
End Function

Function pmsIsRequestToServer(url) As Boolean
    ' Ignore the port. If it's 80 or 443, it's possible that it'll be missing
    ' in one of the URLs.
    portIndex = instr(8, m.serverUrl, ":")
    if portIndex > 0 then
        schemeAndHost = Left(m.serverUrl, portIndex - 1)
    else
        schemeAndHost = m.serverUrl
    end if

    return (Left(url, len(schemeAndHost)) = schemeAndHost)
End Function

Function Capabilities(recompute=false) As String
    if NOT recompute then
        capaString = GetGlobalAA().Lookup("capabilities")
        if capaString <> invalid then return capaString
    end if

    protocols = "protocols=http-live-streaming,http-mp4-streaming,http-mp4-video,http-mp4-video-720p,http-streaming-video,http-streaming-video-720p"
    level = RegRead("level", "preferences", "41")
    'do checks to see if 5.1 is supported, else use stereo
    audio = "aac"
    versionArr = GetGlobal("rokuVersionArr", [0])
    major = versionArr[0]

    ' It's referred to as 5.1 by the feature, but the Roku is just passing the
    ' signal through and theoretically doesn't care if it's 7.1.
    if SupportsSurroundSound(true, true) then
        fiveone = RegRead("fivepointone", "preferences", "1")
        Debug("5.1 support set to: " + fiveone)

        if fiveone <> "2" then
            audio = audio + ",ac3{channels:8}"
        else
            Debug("5.1 support disabled via Tweaks")
        end if
    end if

    ' The Roku1 seems to be pretty picky about h.264 streams inside HLS, it
    ' will show very blocky video for certain streams that work fine in MP4.
    ' We can't really detect when this will be a problem, so just don't
    ' direct stream to a Roku1 by default.

    directPlayOptions = RegRead("directplay", "preferences", "0")
    if (major >= 4 AND directPlayOptions <> "4") OR directPlayOptions = "3" then
        decoders = "videoDecoders=mpeg4,h264{profile:high&resolution:1080&level:"+ level + "};audioDecoders="+audio
    else
        Debug("Disallowing direct streaming in capabilities string")
        decoders = "audioDecoders=" + audio
    end if

    player = ""
    if NOT GetGlobal("playsAnamorphic", false) then
        player = ";videoPlayer={playsAnamorphic:no}"
    end if

    capaString = protocols+";"+decoders + player
    Debug("Capabilities: " + capaString)
    GetGlobalAA().AddReplace("capabilities", capaString)
    return capaString
End Function

'*
'* HMAC encode the message
'*
Function HMACHash(msg As String) As String
    hmac = CreateObject("roHMAC")
    privateKey = CreateObject("roByteArray")
    privateKey.fromBase64String("k3U6GLkZOoNIoSgjDshPErvqMIFdE0xMTx8kgsrhnC0=")
    result = hmac.setup("sha256", privateKey)
    if result = 0
        message = CreateObject("roByteArray")
        message.fromAsciiString(msg)
        result = hmac.process(message)
        return result.toBase64String()
    end if
End Function

Sub pmsLog(msg as String, level=3 As Integer, timeout=0 As Integer)
    query = "source=roku&level=" + level.tostr() + "&message=" + HttpEncode(msg)
    httpRequest = m.CreateRequest("", "/log?" + query)

    ' If we let the log request go out of scope it will get canceled, but we
    ' definitely don't want to block waiting for the response. So, we'll hang
    ' onto one log request at a time. If two log requests are made in rapid
    ' succession then it's possible for the first to be canceled by the second,
    ' caveat emptor. If it's really important, pass the timeout parameter and
    ' make it a blocking request.

    if timeout > 0 then
        GetToStringWithTimeout(httpRequest, timeout)
    else
        context = CreateObject("roAssociativeArray")
        context.requestType = "log"
        GetViewController().StartRequest(httpRequest, m, context)
    end if
End Sub

Sub pmsAddDirectPlayInfo(video, item, mediaKey)
    if item.preferredMediaItem <> invalid then
        mediaItem = item.preferredMediaItem
    else
        ' Allow users to try forcing Direct Play on old school content by
        ' assuming it's an MP4.
        mediaItem = CreateObject("roAssociativeArray")
        mediaItem.bitrate = 0
        mediaItem.container = "mp4"
        mediaItem.parts = []
        mediaItem.curPartIndex = 0
    end if

    mediaFullUrl = FullUrl(m.serverUrl, item.sourceUrl, mediaKey)
    Debug("Will try to direct play " + tostr(mediaFullUrl))
    video.StreamUrls = [mediaFullUrl]
    video.StreamBitrates = [mediaItem.bitrate]
    video.FrameRate = item.FrameRate
    video.IsTranscoded = false
    video.StreamFormat = firstOf(mediaItem.container, "mp4")
    if video.StreamFormat = "hls" then video.SwitchingStrategy = "full-adaptation"

    part = mediaItem.parts[mediaItem.curPartIndex]
    if part <> invalid AND part.subtitles <> invalid AND part.subtitles.Codec = "srt" AND part.subtitles.key <> invalid then
        video.SubtitleUrl = FullUrl(m.serverUrl, "", part.subtitles.key) + "?encoding=utf-8"
    end if

    PrintAA(video)
End Sub

Sub pmsOnUrlEvent(msg, requestContext)
    ' Don't care about the response for any of our requests.
End Sub

Sub pmsSendWOL(screen=invalid)
    if m.machineID <> invalid then
        numReqToSend = 5

        mac = GetServerData(m.machineID, "Mac")

        if mac = invalid then return

        ' Broadcasting to 255.255.255.255 only works on some Rokus, but we
        ' can't reliably determine the broadcast address for our current
        ' interface. Try assuming a /24 network - we may need a toggle to 
        ' override the broadcast address

        ip = invalid
        subnetRegex = CreateObject("roRegex", "((\d+)\.(\d+)\.(\d+)\.)(\d+)", "")
        addr = GetFirstIPAddress()
        if addr <> invalid then
            match = subnetRegex.Match(addr)
            if match.Count() > 0 then
                ip = match[1] + "255"
                Debug("Using broadcast address " + ip)
            end if
        end if

        if ip = invalid then return

        ' only send the broadcast 5 (numReqToSend) times per requested mac address
        WOLcounterKey = "WOLCounter" + tostr(mac)
        if GetGlobalAA().lookup(WOLcounterKey) = invalid then GetGlobalAA().AddReplace(WOLcounterKey, 0)
        GetGlobalAA()[WOLcounterKey] = GetGlobalAA().[WOLcounterKey]  + 1

        ' return if we have already send enough requests
        if GetGlobalAA()[WOLcounterKey] > numReqToSend then 
            Debug(tostr(GetGlobalAA()[WOLcounterKey]) + " WOL requests have already been sent")
            GetGlobalAA().AddReplace(WOLcounterKey, 0)
            return
        end if

        ' Get our secure on pass
        pass = GetServerData(m.machineID, "WOLPass")
        if pass = invalid or Len(pass) <> 12 then pass = "ffffffffffff"
               
        header = "ffffffffffff"
        For k=1 To 16
            header = header + mac
        End For
        
        'Append our SecureOn password
        header = header + pass
        Debug ("pmsSendWOL:: header " + tostr(header))
        
        port = CreateObject("roMessagePort")
        addr = CreateObject("roSocketAddress")
        udp = CreateObject("roDatagramSocket")
        packet = CreateObject("roByteArray")
        udp.setMessagePort(port)
        udp.setBroadcast(true)
      
        addr.setHostname(ip)
        addr.setPort(9)
        udp.setSendToAddress(addr)
        
        packet.fromhexstring(header)
        udp.notifyReadable(true)
        sent = udp.send(packet,0,108)
        Debug ("pmsSendWOL:: Sent Magic Packet of " + tostr(sent) + " bytes to " + ip )
        udp.close()
        
        ' no more need for sleeping 'Sleep(100) -- timer will take care re-requesting the data
        if GetGlobalAA()[WOLcounterKey] <= numReqToSend then m.sendWOL(screen)

        ' add timer to create requests again (only if we made this request from the Home Screen)
        if screen <> invalid and screen.screenname = "Home" then 
            if screen.WOLtimer = invalid then 
                Debug("Created WOLtimer to refresh home screen data")
                screen.WOLtimer = createTimer()
                screen.WOLtimer.Name = "WOLsent"
                screen.WOLtimer.SetDuration(3*1000, false) ' 3 second time ( we will try 3 times )
                GetViewController().AddTimer(screen.WOLtimer, screen) 
            end if
            ' mark the request - we send multiple, so reset timer
            screen.WOLtimer.mark()
        end if

    end if
End Sub
