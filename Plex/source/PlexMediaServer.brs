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
    pms.name = pmsName
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
    pms.Rate = rate
    pms.setPref = setpref
    pms.ExecuteCommand = issueCommand
    pms.ExecutePostCommand = issuePostCommand
    pms.UpdateAudioStreamSelection = updateAudioStreamSelection
    pms.UpdateSubtitleStreamSelection = updateSubtitleStreamSelection
    pms.TranscodedImage = TranscodedImage
    pms.ConstructVideoItem = pmsConstructVideoItem
    pms.TranscodingVideoUrl = TranscodingVideoUrl
    pms.TranscodingAudioUrl = TranscodingAudioUrl
    pms.ConvertTranscodeURLToLoopback = ConvertTranscodeURLToLoopback
    pms.Log = pmsLog

    ' Set to false if a version check fails
    pms.SupportsAudioTranscoding = true
    pms.IsConfigured = false

    return pms
End Function

'* This needs a HTTP PUT command that does not exist in the Roku API but it's faked with a POST
Function updateAudioStreamSelection(partId As String, audioStreamId As String)
    commandUrl = "/library/parts/"+partId+"?audioStreamID="+audioStreamId
    m.ExecutePostCommand(commandUrl)
End Function

Function updateSubtitleStreamSelection(partId As String, subtitleStreamId As String)
    subtitle = invalid
    if subtitleStreamId <> invalid then
        subtitle = subtitleStreamId
    endif
    commandUrl = "/library/parts/"+partId+"?subtitleStreamID="+subtitle
    m.ExecutePostCommand(commandUrl)
End Function

Function issuePostCommand(commandPath)
    commandUrl = m.serverUrl + commandPath
    print "Executing POST command with full command URL:";commandUrl
    request = m.CreateRequest("", commandUrl)
    request.PostFromString("")
End Function

Function progress(key, identifier, time)
    commandUrl = "/:/progress?key="+HttpEncode(key)+"&identifier="+identifier+"&time="+time.tostr()
    m.ExecuteCommand(commandUrl)
End Function

Function scrobble(key, identifier)
    commandUrl = "/:/scrobble?key="+HttpEncode(key)+"&identifier="+identifier
    m.ExecuteCommand(commandUrl)
End Function

Function unscrobble(key, identifier)
    commandUrl = "/:/unscrobble?key="+HttpEncode(key)+"&identifier="+identifier
    m.ExecuteCommand(commandUrl)
End Function

Function rate(key, identifier, rating)
    commandUrl = "/:/rate?key="+HttpEncode(key)+"&identifier="+identifier+"&rating="+rating
    m.ExecuteCommand(commandUrl)
End Function

Function setpref(key, identifier, value)
    commandUrl = key+"/set?"+identifier+"="+value
    m.ExecuteCommand(commandUrl)
End Function

Function issueCommand(commandPath)
    commandUrl = m.serverUrl + commandPath
    print "Executing command with full command URL:";commandUrl
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
        print "Fetching content from server at query URL:"; httpRequest.GetUrl()
        response = GetToStringWithTimeout(httpRequest, 60)
        xml=CreateObject("roXMLElement")
        if not xml.Parse(response) then
            print "Can't parse feed:";response
        endif
            
        xmlResult.xml = xml
        xmlResult.sourceUrl = httpRequest.GetUrl()
    endif
    return xmlResult
End Function

Function IndirectMediaXml(server, originalKey, postURL) As Object
    if postURL <> invalid then
        crlf = Chr(13) + Chr(10)

        print "Fetching content for indirect video POST URL: "; postURL
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
            print "Retrieved data from postURL, posting to resolve container"
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
            print "Failed to retrieve data from postURL"
        end if
    else
        httpRequest = server.CreateRequest("", originalKey)
        print "Fetching content from server at query URL:"; httpRequest.GetUrl()
        response = GetToStringWithTimeout(httpRequest, 60)
    end if

    xml=CreateObject("roXMLElement")
    if not xml.Parse(response) then
        print "Can't parse feed:";response
        return originalKey
    endif
    return xml
End Function
        
Function DirectMediaXml(server, queryUrl) As Object
    httpRequest = server.CreateRequest("", queryUrl)
    print "Fetching content from server at query URL:"; httpRequest.GetUrl()
    response = GetToStringWithTimeout(httpRequest, 60)
    xml=CreateObject("roXMLElement")
    if not xml.Parse(response) then
        print "Can't parse feed:";response
        return originalKey
    endif
    return xml
End Function

'* TODO: this assumes one part media. Implement multi-part at some point.
Function pmsConstructVideoItem(item, seekValue, allowDirectPlay)
    video = CreateObject("roAssociativeArray")
    video.PlayStart = seekValue
    video.Title = item.Title

    identifier = item.mediaContainerIdentifier
    httpCookies = ""
    userAgent = ""
    key = ""
    ratingKey = ""
    mediaItem = item.preferredMediaItem

    if identifier = "com.plexapp.plugins.library" then
        ' Regular library video
        mediaKey = mediaItem.preferredPart.key
        key = item.key
        ratingKey = item.ratingKey
        videoRes = mediaItem.videoresolution
    else if mediaItem = invalid then
        ' Plugin video
        mediaKey = item.key
        videoRes = item.videoresolution
    else
        ' Plugin video, possibly indirect
        mediaKey = mediaItem.preferredPart.key
        postURL = mediaItem.preferredPart.postURL
        videoRes = mediaItem.videoresolution
        if mediaItem.indirect then
            mediaKeyXml = IndirectMediaXml(m, mediaKey, postURL)
            mediaKey = mediaKeyXml.Video.Media.Part[0]@key
            httpCookies = firstOf(mediaKeyXml@httpCookies, "")
            userAgent = firstOf(mediaKeyXml@userAgent, "")
            print "Indirect video item, cookies: "; httpCookies
            print "Indirect video item, UA: "; userAgent
        end if
    end if

    deviceInfo = CreateObject("roDeviceInfo")
    quality = "SD"
    if deviceInfo.GetDisplayType() = "HDTV" then quality = "HD"
    print "Setting stream quality:";quality

    if allowDirectPlay AND mediaItem <> invalid then
        print "Checking to see if direct play of video is possible"
        qualityPref = firstOf(RegRead("quality", "preferences"), "7").toInt()
        if qualityPref >= 9 then
            maxResolution = 1080
        else if qualityPref >= 6 then
            maxResolution = 720
        else if qualityPref >= 5 then
            maxResolution = 480
        else
            maxResolution = 0
        end if
        print "Max resolution:"; maxResolution

        print "Media item optimized for streaming: "; mediaItem.optimized
        if mediaItem.optimized = "true" OR mediaItem.optimized = "1" then
            print "Media item container: "; mediaItem.container
            print "Media item video codec: "; mediaItem.videoCodec
            print "Media item audio codec: "; mediaItem.audioCodec

            if mediaItem.container = "mp4" AND mediaItem.videoCodec = "h264" AND (mediaItem.audioCodec = "aac" OR mediaItem.audioCodec = "mp3") then
                resolution = firstOf(mediaItem.videoResolution, "0").toInt()
                print "Media item resolution:"; resolution; ", max is"; maxResolution
                if resolution <= maxResolution then
                    print "Will try to direct play "; mediaKey
                    video.StreamUrls = [mediaKey]
                    video.StreamBitrates = [0]
                    video.StreamQualities = [quality]
                    video.StreamFormat = "mp4"
                    video.FrameRate = item.FrameRate
                    video.IsTranscoded = false
                    return video
                end if
            end if
        end if
    end if

    video.IsTranscoded = true
    
	'Check to see if the video is fullHD or not
    if RegRead("quality", "preferences") = "9" and videoRes = "1080" then
		device = CreateObject("roDeviceInfo")
		version = device.GetVersion()
			major = Mid(version, 3, 1)
			minor = Mid(version, 5, 2)
			build = Mid(version, 8, 5)
		print "Device Version:" + major +"." + minor +" build "+build
		if major.toInt() < 4  then
			if RegRead("legacy1080p","preferences") = "enabled" then
				video.fullHD = true
				video.framerate = 30
				frSetting = RegRead("legacy1080pframerate","preferences")
				if frSetting = "24" then
					video.framerate = 24
				else if frSetting = "auto" and item.preferredMediaItem.framerate = "24"					
					video.framerate = 24
				end if
			end if
		else 
			video.fullHD = true
		endif
	endif
	printAA(video)
    video.StreamBitrates = [0]
    video.StreamQualities = [quality]
    video.StreamFormat = "hls"
    url = m.TranscodingVideoUrl(mediaKey, item, httpCookies, userAgent)
    if url = invalid then return invalid
    video.StreamUrls = [url]

    return video
End Function

Function stopTranscode()
    stopTransfer = CreateObject("roUrlTransfer")
    stopTransfer.SetUrl(m.serverUrl + "/video/:/transcode/segmented/stop")
    stopTransfer.AddHeader("Cookie", m.Cookie) 
    content = stopTransfer.GetToString()
End Function

Function pingTranscode()
    pingTransfer = CreateObject("roUrlTransfer")
    pingTransfer.SetUrl(m.serverUrl + "/video/:/transcode/segmented/ping")
    pingTransfer.AddHeader("Cookie", m.Cookie) 
    content = pingTransfer.GetToString()
End Function

'* Constructs a Full URL taking into account relative/absolute. Relative to the 
'* source URL, and absolute URLs, so
'* relative to the server URL
Function FullUrl(serverUrl, sourceUrl, key) As String
    'print "Full URL"
    'print "ServerURL:";serverUrl
    'print "SourceURL:";sourceUrl
    'print "Key:";key
    finalUrl = ""
    if left(key, 4) = "http" then
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
    'print "FinalURL:";finalUrl
    return finalUrl
End Function

Function ResolveUrl(serverUrl As String, sourceUrl As String, uri As String) As String
    return FullUrl(serverUrl, sourceUrl, uri)
End Function


'* Constructs an image based on a PMS url with the specific width and height. 
Function TranscodedImage(queryUrl, imagePath, width, height) As String
    imageUrl = FullUrl(m.serverUrl, queryUrl, imagePath)
    imageUrl = m.ConvertTranscodeURLToLoopback(imageUrl)
    encodedUrl = HttpEncode(imageUrl)
    image = m.serverUrl + "/photo/:/transcode?url="+encodedUrl+"&width="+width+"&height="+height
    'print "Final Image URL:";image
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
Function TranscodingVideoUrl(videoUrl As String, item As Object, httpCookies As String, userAgent As String)
    print "Constructing transcoding video URL for "+videoUrl
    if userAgent <> invalid then
        print "User Agent: ";userAgent
    end if

    key = ""
    ratingKey = ""
    identifier = item.mediaContainerIdentifier
    if identifier = "com.plexapp.plugins.library" then
        key = item.key
        ratingKey = item.ratingKey
    end if

    location = ResolveUrl(m.serverUrl, item.sourceUrl, videoUrl)
    location = m.ConvertTranscodeURLToLoopback(location)
    print "Location:";location
    if len(key) = 0 then
        fullKey = ""
    else
        fullKey = ResolveUrl(m.serverUrl, item.sourceUrl, key)
    end if
    print "Original key:";key
    print "Full key:";fullKey
    
    if not(RegExists("quality", "preferences")) then RegWrite("quality", "7", "preferences")
    if not(RegExists("level", "preferences")) then RegWrite("level", "40", "preferences")
    print "REG READ LEVEL "; RegRead("level", "preferences")

    path = "/video/:/transcode/segmented/start.m3u8?"

    query = "offset=0"
    query = query + "&identifier=" + identifier
    query = query + "&ratingKey=" + ratingKey
    if len(fullKey) > 0 then
        query = query + "&key=" + HttpEncode(fullKey)
    end if
    if left(videoUrl, 4) = "plex" then
        query = query + "&webkit=1"
    end if

    currentQuality = RegRead("quality", "preferences")
    if currentQuality = "Auto" then
        query = query + "&minQuality=4&maxQuality=8"
    else
        query = query + "&quality=" + currentQuality
    end if

    query = query + "&url=" + HttpEncode(location)
    query = query + "&3g=0"
    query = query + "&httpCookies=" + HttpEncode(httpCookies)
    query = query + "&userAgent=" + HttpEncode(userAgent)

    publicKey = "KQMIY6GATPC63AIMC4R2"
    time = LinuxTime().tostr()
    msg = path + query + "@" + time
    finalMsg = HMACHash(msg)

    query = query + "&X-Plex-Access-Key=" + publicKey
    query = query + "&X-Plex-Access-Time=" + time
    query = query + "&X-Plex-Access-Code=" + HttpEncode(finalMsg)
    query = query + "&X-Plex-Client-Capabilities=" + HttpEncode(Capabilities())

    finalUrl = m.serverUrl + path + query
    print "Final URL:";finalUrl
    return finalUrl
End Function

Function TranscodingAudioUrl(audioUrl As String, item As Object)
    if NOT m.SupportsAudioTranscoding then return invalid

    print "Constructing transcoding audio URL for "+audioUrl

    location = ResolveUrl(m.serverUrl, item.sourceUrl, audioUrl)
    location = m.ConvertTranscodeURLToLoopback(location)
    print "Location:";location
    
    path = "/music/:/transcode/generic.mp3?"

    query = "offset=0"
    query = query + "&format=mp3&audioCodec=libmp3lame"
    ' TODO(schuyler): Should we be doing something other than hardcoding these?
    ' If we don't pass a bitrate the server uses 64k, which we don't want.
    ' There was a rumor that the Roku didn't support 48000 samples, but that
    ' doesn't seem to be true.
    query = query + "&audioBitrate=160&audioSamples=44100"
    query = query + "&url=" + HttpEncode(location)
    query = query + "&X-Plex-Client-Capabilities=" + HttpEncode(Capabilities())

    finalUrl = m.serverUrl + path + query
    print "Final URL:";finalUrl
    return finalUrl
End Function

Function ConvertTranscodeURLToLoopback(url) As String
    ' If the URL starts with our serverl URL, replace it with
    ' 127.0.0.1:32400.

    'print "ConvertTranscodeURLToLoopback:: original URL: ";url
    if Left(url, len(m.serverUrl)) = m.serverUrl then
        url = "http://127.0.0.1:32400" + Right(url, len(url) - len(m.serverUrl))
    end if

    'print "ConvertTranscodeURLToLoopback:: processed URL: ";url
    return url
End Function

Function Capabilities(recompute=false) As String
    if NOT recompute then
        capaString = GetGlobalAA().Lookup("capabilities")
        if capaString <> invalid then return capaString
    end if

    protocols = "protocols=http-live-streaming,http-mp4-streaming,http-mp4-video,http-mp4-video-720p,http-streaming-video,http-streaming-video-720p"
    print "REG READ LEVEL "; RegRead("level", "preferences")
    level = firstOf(RegRead("level", "preferences"), "40")
    'do checks to see if 5.1 is supported, else use stereo
    device = CreateObject("roDeviceInfo")
    audio = "aac"
    version = device.GetVersion()
       major = Mid(version, 3, 1)
       minor = Mid(version, 5, 2)
       build = Mid(version, 8, 5)
    print "Device Version:" + major +"." + minor +" build "+build

    if device.HasFeature("5.1_surround_sound") and major.ToInt() >= 4 then
        if not(RegExists("fivepointone", "preferences")) then
            RegWrite("fivepointone", "1", "preferences")
        end if
        fiveone = RegRead("fivepointone", "preferences")
        print "5.1 support set to: ";fiveone
        
        if fiveone <> "2" then
            audio="ac3{channels:6}"
        else
            print "5.1 support disabled via Tweaks"
        end if
    end if 
    decoders = "videoDecoders=h264{profile:high&resolution:1080&level:"+ level + "};audioDecoders="+audio
    'anamorphic video causes problems, disable support for it
    'anamorphic = "playsAnamorphic=no"

    capaString = protocols+";"+decoders '+";"+anamorphic
    print "Capabilities: "+capaString
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

'*
'* Time since the start (of UNIX time)
'*
Function LinuxTime() As Integer
    time = CreateObject("roDateTime")
    return time.asSeconds()
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


