'*
'* Facade to a PMS server responsible for fetching PMS meta-data and
'* formatting into Roku format as well providing the interface to the
'* streaming media
'*

'* Constructor for a specific PMS instance identified via the URL and
'* human readable name, which can be used in section names
Function newPlexMediaServer(pmsUrl, pmsName, machineID) As Object
    pms = CreateObject("roAssociativeArray")
    pms.serverUrl = pmsUrl
    pms.name = firstOf(pmsName, "Unknown")
    pms.machineID = machineID
    pms.owned = true
    pms.online = false
    pms.StopVideo = stopTranscode
    pms.StartTranscode = StartTranscodingSession
    pms.PingTranscode = pingTranscode
    pms.CreateRequest = pmsCreateRequest
    pms.GetQueryResponse = xmlContent
    pms.SetProgress = progress
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

    ' Set to false if a version check fails
    pms.SupportsAudioTranscoding = true
    pms.SupportsVideoTranscoding = true
    pms.SupportsPhotoTranscoding = true
    pms.SupportsUniversalTranscoding = true
    pms.AllowsMediaDeletion = false
    pms.IsConfigured = false
    pms.IsAvailable = false

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

Function progress(key, identifier, time)
    if identifier <> invalid then
        commandUrl = "/:/progress?key="+HttpEncode(key)+"&identifier="+identifier+"&time="+time.tostr()
        m.ExecuteCommand(commandUrl)
    end if
End Function

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

Function pmsCreateRequest(sourceUrl, key) As Object
    url = FullUrl(m.serverUrl, sourceUrl, key)
    req = CreateURLTransferObject(url)
    if m.AccessToken <> invalid then
        req.AddHeader("X-Plex-Token", m.AccessToken)
    end if
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

'* TODO: this assumes one part media. Implement multi-part at some point.
Function pmsConstructVideoItem(item, seekValue, allowDirectPlay, forceDirectPlay)
    video = CreateObject("roAssociativeArray")
    video.PlayStart = seekValue
    video.Title = item.Title

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

    if identifier = "com.plexapp.plugins.library" then
        ' Regular library video
        mediaKey = part.key
        key = item.key
        ratingKey = item.ratingKey
        videoRes = mediaItem.videoresolution
    else if mediaItem = invalid  OR part = invalid then
        ' Plugin video
        mediaKey = item.key
        videoRes = item.videoresolution
    else
        ' Plugin video, possibly indirect
        mediaKey = part.key
        postURL = part.postURL
        videoRes = mediaItem.videoresolution
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

    deviceInfo = CreateObject("roDeviceInfo")
    quality = "SD"
    if deviceInfo.GetDisplayType() = "HDTV" then quality = "HD"
    Debug("Setting stream quality: " + quality)
    video.StreamQualities = [quality]

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

    if forceDirectPlay then
        if mediaItem = invalid then
            Debug("Can't direct play, plugin video has no media item!")
            return invalid
        else if left(mediaKey, 5) = "plex:" then
            Debug("Can't direct play plex: URLs: " + tostr(mediaKey))
            return invalid
        else
            video.IndirectHttpHeaders = headers
            m.AddDirectPlayInfo(video, item, mediaKey)
            return video
        end if
    else if allowDirectPlay AND mediaItem <> invalid then
        Debug("Checking to see if direct play of video is possible")
        qualityPref = RegRead("quality", "preferences", "7").toInt()
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
    video.HDBranded = item.HDBranded

	'We are transcoding, don't set fullHD if quality isn't 1080p
    if RegRead("quality", "preferences") <> "9" then
        video.fullHD = False
	endif

    video.StreamBitrates = [0]
    video.StreamFormat = "hls"
    video.SwitchingStrategy = "no-adaptation"
    url = m.TranscodingVideoUrl(mediaKey, item, headers)
    if url = invalid then return invalid
    video.StreamUrls = [url]

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
    return finalUrl
End Function


'* Constructs an image based on a PMS url with the specific width and height.
Function TranscodedImage(queryUrl, imagePath, width, height, forceBackgroundColor="363636") As String
    imageUrl = FullUrl(m.serverUrl, queryUrl, imagePath)
    if NOT m.SupportsPhotoTranscoding then return imageUrl
    imageUrl = m.ConvertURLToLoopback(imageUrl)
    encodedUrl = HttpEncode(imageUrl)
    image = m.serverUrl + "/photo/:/transcode?url="+encodedUrl+"&width="+width+"&height="+height
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
    return m.Cookie
End Function

'*
'* Construct the Plex transcoding URL.
'*
Function TranscodingVideoUrl(videoUrl As String, item As Object, httpHeaders As Object)
    ' TODO(schuyler): Once we're comfortable with the percentage of users using
    ' an adequate version, we can probably remove the classic transcoder. Doing
    ' so will actually lead to a variety of changes, since we can let PMS worry
    ' about stuff like indirect resolution and there's no need to have httpHeaders
    ' here.

    if m.SupportsUniversalTranscoding AND RegRead("transcoder_version", "preferences", "universal") = "universal" then
        return m.UniversalTranscodingVideoUrl(videoUrl, item)
    else
        return m.ClassicTranscodingVideoUrl(videoUrl, item, httpHeaders)
    end if
End Function

Function universalTranscodingVideoUrl(videoUrl As String, item As Object)
    if NOT m.SupportsVideoTranscoding then return invalid

    Debug("Constructing transcoding video URL for " + videoUrl)

    fullKey = m.ConvertURLToLoopback(FullUrl(m.serverUrl, item.sourceUrl, item.key))
    extras = ""

    builder = NewHttp(m.serverUrl + "/video/:/transcode/universal/start.m3u8")

    builder.AddParam("protocol", "hls")
    builder.AddParam("path", fullKey)
    builder.AddParam("session", GetGlobal("rokuUniqueId"))
    builder.AddParam("waitForSegments", "1")
    builder.AddParam("directPlay", "0")

    versionArr = GetGlobal("rokuVersionArr", [0, 0])
    directPlayOptions = RegRead("directplay", "preferences", "0")
    if (versionArr[0] >= 4 AND directPlayOptions <> "4") OR directPlayOptions = "3" then
        builder.AddParam("directStream", "1")
    else
        builder.AddParam("directStream", "0")
    end if

    quality = RegRead("quality", "preferences", "7").toInt()
    builder.AddParam("videoQuality", GetGlobal("TranscodeVideoQualities")[quality])
    builder.AddParam("videoResolution", GetGlobal("TranscodeVideoResolutions")[quality])
    builder.AddParam("maxVideoBitrate", GetGlobal("TranscodeVideoBitrates")[quality])

    builder.AddParam("subtitleSize", RegRead("subtitle_size", "preferences", "125"))
    builder.AddParam("audioBoost", RegRead("audio_boost", "preferences", "100"))

    if item.preferredMediaItem <> invalid then
        builder.AddParam("partIndex", tostr(item.preferredMediaItem.curPartIndex))
    end if

    ' Augement the server's profile for things that depend on the Roku's configuration.
    device = CreateObject("roDeviceInfo")

    builder.AddParam("X-Plex-Platform", "Roku")

    if device.HasFeature("5.1_surround_sound") and versionArr[0] >= 4 then
        if RegRead("fivepointone", "preferences", "1") = "1" then
            extras = extras + "add-transcode-target-audio-codec(type=videoProfile&context=streaming&protocol=hls&audioCodec=ac3)"
        end if
    end if

    ' Theoretically we can handle H.264 level like this...
    'extras = extras + "+add-limitation(scope=videoCodec&scopeName=h264&type=upperBound&name=video.level&value=" + RegRead("level", "preference", "40") + "&isRequired=true)+"

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

    if not(RegExists("level", "preferences")) then RegWrite("level", "40", "preferences")

    path = "/video/:/transcode/segmented/start.m3u8?"

    query = "offset=0"
    if identifier <> invalid then
        query = query + "&identifier=" + identifier
    end if
    query = query + "&ratingKey=" + ratingKey
    if len(fullKey) > 0 then
        query = query + "&key=" + HttpEncode(fullKey)
    end if
    if left(videoUrl, 4) = "plex" then
        query = query + "&webkit=1"
    end if

    currentQuality = RegRead("quality", "preferences", "7")
    if currentQuality = "Auto" then
        query = query + "&minQuality=4&maxQuality=8"
    else
        query = query + "&quality=" + currentQuality
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
    level = RegRead("level", "preferences", "40")
    'do checks to see if 5.1 is supported, else use stereo
    device = CreateObject("roDeviceInfo")
    audio = "aac"
    versionArr = GetGlobal("rokuVersionArr", [0])
    major = versionArr[0]

    ' It's referred to as 5.1 by the feature, but the Roku is just passing the
    ' signal through and theoretically doesn't care if it's 7.1.
    if device.HasFeature("5.1_surround_sound") and major >= 4 then
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
    httpRequest.AsyncGetToString()

    ' If we let the log request go out of scope it will get canceled, but we
    ' definitely don't want to block waiting for the response. So, we'll hang
    ' onto one log request at a time. If two log requests are made in rapid
    ' succession then it's possible for the first to be canceled by the second,
    ' caveat emptor. If it's really important, pass the timeout parameter and
    ' make it a blocking request.

    if timeout > 0 then
        GetToStringWithTimeout(httpRequest, timeout)
    else
        GetGlobalAA().AddReplace("log_request", httpRequest)
    end if
End Sub

Sub pmsAddDirectPlayInfo(video, item, mediaKey)
    mediaFullUrl = FullUrl(m.serverUrl, "", mediaKey)
    Debug("Will try to direct play " + tostr(mediaFullUrl))
    video.StreamUrls = [mediaFullUrl]
    video.StreamBitrates = [item.preferredMediaItem.bitrate]
    video.FrameRate = item.FrameRate
    video.IsTranscoded = false
    video.StreamFormat = firstOf(item.preferredMediaItem.container, "mp4")

    part = item.preferredMediaItem.parts[item.preferredMediaItem.curPartIndex]
    if part <> invalid AND part.subtitles <> invalid AND part.subtitles.Codec = "srt" then
        video.SubtitleUrl = FullUrl(m.serverUrl, "", part.subtitles.key) + "?encoding=utf-8"
    end if

    PrintAA(video)
End Sub

