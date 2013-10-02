
Function newVideoMetadata(container, item, detailed=false) As Object
    ' Videos only have a grandparent thumb in situations where we prefer it,
    ' so pass that to the base constructor.
    video = createBaseMetadata(container, item, item@grandparentThumb)

    if item@grandparentThumb <> invalid AND item@thumb <> invalid AND video.server <> invalid then
        sizes = ImageSizes(container.ViewGroup, item@type)

        video.SDGridThumb = video.server.TranscodedImage(container.sourceUrl, item@grandparentThumb, sizes.sdWidth, sizes.sdHeight)
        video.HDGridThumb = video.server.TranscodedImage(container.sourceUrl, item@grandparentThumb, sizes.hdWidth, sizes.hdHeight)
        video.SDDetailThumb = video.server.TranscodedImage(container.sourceUrl, item@thumb, sizes.sdWidth, sizes.sdHeight)
        video.HDDetailThumb = video.server.TranscodedImage(container.sourceUrl, item@thumb, sizes.hdWidth, sizes.hdHeight)
    end if

    video.Refresh = videoRefresh
    video.ParseDetails = videoParseDetails
    video.SelectPartForOffset = videoSelectPartForOffset
    video.PickMediaItem = PickMediaItem
    video.ParseVideoMedia = ParseVideoMedia

    if item = invalid then return video

    video.mediaContainerIdentifier = container.xml@identifier
    video.ratingKey = item@ratingKey
    video.id = item@id
    video.ContentType = item@type
    if video.ContentType = invalid then
        '* treat video items with no content type as clips
        video.ContentType = "clip"
    endif
    video.isLibraryContent = (video.mediaContainerIdentifier = "com.plexapp.plugins.library")

    video.ReleaseDate = item@originallyAvailableAt

    length = item@duration
    if length <> invalid then
        video.Length = int(val(length)/1000)
        video.RawLength = int(val(length))
    endif

    if container.ViewGroup = "Details" OR container.ViewGroup = "InfoList" then
        video.ShortDescriptionLine2 = item@summary
    endif

    ' TODO(schuyler): Is there a less hacky way to decide this?
    if video.mediaContainerIdentifier = "com.plexapp.plugins.myplex" AND video.id <> invalid then
        video.DetailUrl = "/pms/playlists/items/" + video.id
        video.Key = RewriteNodeKey(video.Key)
    end if

    setVideoBasics(video, container, item)

    if detailed AND NOT item.Media.IsEmpty() then
        ' Also sets media and preferredMediaItem
        video.ParseDetails()
    else
        setVideoDetails(video, container, item, false)

        if video.preferredMediaItem = invalid then
            video.HasDetails = true
        end if
    end if

    return video
End Function

Sub setVideoBasics(video, container, item)

    video.viewOffset = item@viewOffset
    video.viewCount = item@viewCount
    video.Watched = video.viewCount <> invalid AND val(video.viewCount) > 0

    video.ShortDescriptionLine1 = firstOf(item@title, item@name)


    'grandparentKey -- for episode - RR
    if item@grandparentKey <> invalid then
       video.grandparentKey = item@grandparentKey
    end if
    if item@grandparentTitle <> invalid then
       video.ShowTitle = item@grandparentTitle
    end if

    if item@parentKey <> invalid then
        video.parentKey = item@parentKey
        if video.showTitle = invalid then
            if container.xml@grandparentTitle <> invalid then 
                video.ShowTitle = container.xml@grandparentTitle
            else if container.xml@title2 <> invalid then 
                video.ShowTitle = container.xml@title2
            else
                video.ShowTitle = "invalid"
            end if
        end if

        if video.grandparentKey = invalid and container.xml@key <> invalid then 
            video.grandparentKey = "/library/metadata/" + tostr(container.xml@key)
            Debug("----- setting grandparent key to " + video.grandparentKey + " " + video.showTitle)
        end if
    end if

    ' Bookmark position represents the last watched so a video could be marked watched but
    ' have a bookmark not at the end if it was a subsequent viewing
    video.BookmarkPosition = 0
    if video.viewOffset <> invalid AND val(video.viewOffset) > 0 then
        video.BookmarkPosition = int(val(video.viewOffset)/1000)
    else if video.Watched then
        video.BookmarkPosition = video.Length
    end if

    video.ShortDescriptionLine2 = firstOf(item@sourceTitle, item@tagline, video.ShortDescriptionLine2)

    if container.ViewGroup = "episode" OR item@type = "episode" then
        episodeStr = invalid
        seasonStr = invalid
        if item@grandparentTitle <> invalid then
            video.ShortDescriptionLine1 = item@grandparentTitle + ": " + video.ShortDescriptionLine1
        end if
        if item@index <> invalid then
            video.EpisodeNumber = item@index
            episode = "Episode " + item@index
            if val(item@index) >= 10 then
                episodeStr = "E" + item@index
            else
                episodeStr = "E0" + item@index
            end if
        else
            video.EpisodeNumber = 0
            episode = "Episode ??"
        end if
        parentIndex = firstOf(item@parentIndex, container.xml@parentIndex)
        if parentIndex <> invalid then
            video.ShortDescriptionLine2 = "Season " + parentIndex + " - " + episode
            video.parentIndex = parentIndex

            if val(parentIndex) >= 10 then
                seasonStr = "S" + parentIndex
            else
                seasonStr = "S0" + parentIndex
            end if
        else
            video.ShortDescriptionLine2 = episode
        end if
        if video.ReleaseDate <> invalid then
            video.ShortDescriptionLine2 = video.ShortDescriptionLine2 + " - " + video.ReleaseDate
        end if

        if episodeStr <> invalid AND seasonStr <> invalid then
             ' ljunkie - always show season/episode - keeps the formatting standard
             video.EpisodeStr = seasonStr + " " + episodeStr
            'if container.xml@mixedParents = "1" then
            '   video.EpisodeStr = seasonStr + " " + episodeStr
            'else
            '    video.EpisodeStr = episodeStr
            'end if
            video.OrigReleaseDate = video.ReleaseDate
            video.ReleaseDate = video.EpisodeStr
            video.TitleSeason = firstOf(item@title, item@name) + " - " + video.EpisodeStr
        end if
    else if video.ContentType = "clip" then
        video.ReleaseDate = firstOf(video.ReleaseDate, item@subtitle)
    end if

    video.CleanTitle = video.ShortDescriptionLine1

    'ljunkie - search title for RT and Trailers. We will use CleanTitle unless overridden
    if RegRead("rf_searchtitle", "preferences", "title") = "originalTitle" then    
        video.RFSearchTitle = firstOf(item@originalTitle, item@title, item@name)
    else 
        video.RFSearchTitle = firstOf(item@title, item@name)
    end if
    'ljunkie - end search title

    if tostr(video.EpisodeStr) <> "invalid" then
        video.ShortDescriptionLine1 = video.CleanTitle + " - " + tostr(video.EpisodeStr)
    end if

    ' if a video has ever been watch mark as such, else mark partially if there's a recorded offset
    ' ljunkie - we should mark it as watched & partially watched -- otherwise it's confusing when watched content is ondeck
    watched_status = "invalid"
    if video.Watched AND video.viewOffset <> invalid AND val(video.viewOffset) > 0 then
       watched_status = " (Watched+Restarted)" ' try and keep it show "Watched+Partially Watched" seems to long
    else if video.Watched then
       watched_status = " (Watched)"
    else if video.viewOffset <> invalid AND val(video.viewOffset) > 0 then
       watched_status = " (Partially Watched)"
    end if

    if watched_status <> "invalid" then 
        video.ShortDescriptionLine1 = video.ShortDescriptionLine1 + watched_status
        if video.TitleSeason <> invalid then 
            video.TitleSeason = video.TitleSeason + watched_status
        end if
    end if 

    video.Title = video.ShortDescriptionLine1


    video.Rating = firstOf(item@contentRating, container.xml@grandparentContentRating)
    rating = item@rating
    ropt = RegRead("rf_user_rating_only", "preferences","user_prefer") ' ljunkie - how should we display user/default star ratings

    if rating <> invalid then
        if ropt = "disabled" or ropt = "user_prefer" then
            video.origStarRating = int(val(rating)*10) ' base line for user rating
            video.StarRating = int(val(rating)*10) ' set star rating if user_rating_only is disabled
        else 
            video.origStarRating = 0
        end if 
    endif

    userRating = item@userRating
    if userRating <> invalid then
	video.UserRating =  int(val(userRating)*10)
        ' if prefer user rating OR we ONLY show user ratings, then override the starRating if it exists
        if ropt = "user_prefer" or ropt = "user_only" then
            video.StarRating =  int(val(userRating)*10)
        end if
    else
	video.UserRating =  0
    endif


    if item.user@id <> invalid then 
        ' save any variables we change for later
        video.nowPlaying_orig_title = video.title
        video.nowPlaying_orig_description = video.description
        video.description = "Progress: " + GetDurationString(int(video.viewoffset.toint()/1000),1,1,1) + " on " + firstof(item.Player@title, item.Player@platform)
        video.title = UcaseFirst(item.user@title,true) + " " + UcaseFirst(item.Player@state) + ": "  + video.CleanTitle
        ' set nowPlaying info for later
        video.nowPlaying_maid = item.Player@machineIdentifier ' use to verify the stream we are syncing is the same
        video.nowPlaying_user = item.user@title
        video.nowPlaying_state = item.Player@state
        video.nowPlaying_platform = item.Player@platform
        video.nowPlaying_platform_title = item.Player@title
    end if


    video.guid = item@guid
    video.url = item@url
End Sub

Function videoParseDetails()
    if m.HasDetails then return m

    ' Don't bother trying to request bogus (webkit) keys
    container = invalid
    if left(m.Key, 5) <> "plex:" then
        ' Channels don't understand checkFiles, and the framework gets angry
        ' about things it doesn't understand.
        if m.isLibraryContent then
            if Instr(1, m.Key, "?") > 0 then
                detailKey = m.Key + "&checkFiles=1"
            else
                detailKey = m.Key + "?checkFiles=1"
            end if
        else
            detailKey = m.Key
        end if
        container = createPlexContainerForUrl(m.server, m.sourceUrl, detailKey)
    end if

    if container <> invalid then
        videoItemXml = container.xml.Video[0]
        setVideoDetails(m, container, videoItemXml)
    end if

    m.HasDetails = true

    return m
End Function

Sub setVideoDetails(video, container, videoItemXml, hasDetails=true)
    ' Fix some items that might have been modified for the grid view.
    if video.OrigReleaseDate <> invalid then
        video.ReleaseDate = video.OrigReleaseDate
    end if

    ' Everything else requires a Video item, which we might not have for clips.
    if videoItemXml = invalid then return

    ' ljunkie - actors/directors/writers screen addition
    video.CastCrewList   = []

    default_img = "/:/resources/actor-icon.png"
    sizes = ImageSizes("movie", "movie")

    SDThumb = video.server.TranscodedImage(video.server.serverurl, default_img, sizes.sdWidth, sizes.sdHeight)
    HDThumb = video.server.TranscodedImage(video.server.serverurl, default_img, sizes.hdWidth, sizes.hdHeight)
    if video.server.AccessToken <> invalid then
        SDThumb = SDThumb + "&X-Plex-Token=" + video.server.AccessToken
        HDThumb = HDThumb + "&X-Plex-Token=" + video.server.AccessToken
    end if
    ' end thumbs - ljunkie

    'ondeck doesn't give actor/director/etc id's -- so we will force this in rarflix.brs:getPostersForCastCrew
    ' so we will end up doing this all over again in the getPostersForCastCrew
    video.Actors = CreateObject("roArray", 15, true)
    for each Actor in videoItemXml.Role
        video.CastCrewList.Push({ name: Actor@tag, id: Actor@id, role: Actor@role, imageHD: HDThumb, imageSD: SDThumb, itemtype: "Actor" })
        video.Actors.Push(Actor@tag) ' original field
    next

    video.Director = CreateObject("roArray", 3, true)
    for each Director in videoItemXml.Director
        video.CastCrewList.Push({ name: Director@tag, id: Director@id, imageHD: HDThumb, imageSD: SDThumb, itemtype: "Director" })
        video.Director.Push(Director@tag) ' original field
    next

    for each Producer in videoItemXml.Producer
        video.CastCrewList.Push({ name: Producer@tag, id: Producer@id, imageHD: HDThumb, imageSD: SDThumb, itemtype: "producer" })
        ' video.Producer.Push(Producer@tag) ' not implemented
    next

    for each Writer in videoItemXml.Writer
        video.CastCrewList.Push({ name: Writer@tag, id: Writer@id, imageHD: HDThumb, imageSD: SDThumb, itemtype: "Writer" })
        ' video.Writer.Push(Writer@tag) ' not implemented
    next

    'if videoItemXml.user@id <> invalid then 
    '    video.ReleaseDate = videoItemXml.user@title + " " + videoItemXml.Player@state + " on " + firstof(videoItemXml.Player@title, videoItemXml.Player@platform)
    'end if

    video.Categories = CreateObject("roArray", 15, true)
    for each Category in videoItemXml.Genre
        video.Categories.Push(Category@tag)
    next

    ' TODO: review the logic here. Last media item wins. Is this what we want?
    for each MediaItem in videoItemXml.Media
        videoResolution = MediaItem@videoResolution
        if videoResolution = "1080" OR videoResolution = "720" then
            video.HDBranded = true
        endif
        frameRate = MediaItem@videoFrameRate
        if frameRate <> invalid then
            if frameRate = "24p" then
                video.FrameRate = 24
            else if frameRate = "NTSC"
                video.FrameRate = 30
            endif
        endif
        video.OptimizedForStreaming = MediaItem@optimizedForStreaming
    next

    video.ParseVideoMedia(videoItemXml, container.sourceUrl)
    video.PickMediaItem(hasDetails)
End Sub

Function parseMediaContainer(MediaItem)
    container = MediaItem@container

    ' Translate any containers that Roku expects to see with a different name
    if container = "asf" then container = "wmv"

    if MediaItem@protocol = "hls" then
        container = "hls"
    elseif MediaItem@protocol = "rtmp" then
        container = "rtmp"
    else if MediaItem@protocol = "webkit" then
        container = "webkit"
    end if

    return container
End Function

Sub ParseVideoMedia(videoItem, sourceUrl) As Object
    mediaArray = CreateObject("roArray", 5, true)

    ' myPlex content may have had details requested from the node, which may
    ' respond with relative URLs. Resolve URLs now so that when we go to play
    ' the video we don't think we have a relative URL relative to the server.
    baseUrl = m.server.serverUrl
    if Left(sourceUrl, 4) = "http" then
        slashIndex = instr(10, sourceUrl, "/")
        if slashIndex > 0 then
            baseUrl = Left(sourceUrl, slashIndex - 1)
        end if
    end if

	for each MediaItem in videoItem.Media
		media = CreateObject("roAssociativeArray")
		media.indirect = false
		if MediaItem@indirect <> invalid AND MediaItem@indirect = "1" then
			media.indirect = true
		end if
		media.identifier = MediaItem@id
		media.audioCodec = MediaItem@audioCodec
		media.audioChannels = MediaItem@audioChannels
		media.videoCodec = MediaItem@videoCodec
		media.videoResolution = MediaItem@videoResolution
        media.container = parseMediaContainer(MediaItem)
        media.aspectRatio = val(firstOf(MediaItem@aspectRatio, "0.0"))
        media.optimized = MediaItem@optimizedForStreaming
        media.duration = validint(strtoi(firstOf(MediaItem@duration, "0")))
        media.bitrate = validint(strtoi(firstOf(MediaItem@bitrate, "0")))
        media.width = validint(strtoi(firstOf(MediaItem@width, "0")))
        media.height = validint(strtoi(firstOf(MediaItem@height, "0")))

        bitrateSum = 0

        startOffset = 0
		media.parts = CreateObject("roArray", 3, true)
		for each MediaPart in MediaItem.Part
			part = CreateObject("roAssociativeArray")
			part.id = MediaPart@id
			part.key = FullUrl(baseUrl, "", MediaPart@key)
            part.postURL = MediaPart@postURL
			part.streams = CreateObject("roArray", 5, true)
            part.subtitles = invalid
            part.exists = MediaPart@exists <> "0"
            part.accessible = MediaPart@accessible <> "0"
            part.duration = validint(strtoi(firstOf(MediaPart@duration, "0")))
            part.hasChapterVideoStream = (MediaPart@hasChapterVideoStream = "1")
            part.startOffset = startOffset
            startOffset = startOffset + part.duration

            part.indexes = CreateObject("roAssociativeArray")
            if MediaPart@indexes <> invalid then
                indexKeys = strTokenize(MediaPart@indexes, ",")
                for each indexKey in indexKeys
                    part.indexes[indexKey] = m.server.serverUrl + "/library/parts/" + tostr(part.id) + "/indexes/" + indexKey + "?interval=" + RegRead("bif_interval", "preferences", "10000")
                next
            end if

			for each StreamItem in MediaPart.Stream
				stream = CreateObject("roAssociativeArray")
				stream.id = StreamItem@id
				stream.streamType = StreamItem@streamType
				stream.codec = firstOf(StreamItem@codec, StreamItem@format)
				stream.language = StreamItem@language
                stream.languageCode = StreamItem@languageCode
				stream.selected = StreamItem@selected
				stream.channels = StreamItem@channels
                stream.key = StreamItem@key

                if stream.selected <> invalid AND stream.streamType = "3" then
                    part.subtitles = stream
                end if

                if stream.streamType = "1" then
                    stream.cabac = StreamItem@cabac
                    stream.frameRate = StreamItem@frameRate
                    stream.level = StreamItem@level
                    stream.profile = StreamItem@profile
                    stream.refFrames = StreamItem@refFrames
                    stream.bitDepth = StreamItem@bitDepth
                    stream.anamorphic = (StreamItem@anamorphic = "1")
                end if

                bitrateSum = bitrateSum + validint(strtoi(firstOf(StreamItem@bitrate, "0")))

				part.streams.Push(stream)
			next
			media.parts.Push(part)
		next

        ' The overall bitrate had better be at least the sum of its parts
        if bitrateSum > media.bitrate then media.bitrate = bitrateSum

		'* TODO: deal with multiple parts correctly. Not sure how audio etc selection works
		'* TODO: with multi-part
		media.preferredPart = media.parts[0]
        media.curPartIndex = 0
		mediaArray.Push(media)
	next

    m.media = mediaArray
End Sub

'* Logic for choosing which Media item to use from the collection of possibles.
Sub PickMediaItem(hasDetails)
    if m.isManuallySelectedMediaItem = true then return
    mediaItems = m.media
    quality = GetQualityForItem(m)
    if quality >= 9 then
        maxResolution = 1080
    else if quality >= 6 then
        maxResolution = 720
    else if quality >= 5 then
        maxResolution = 480
    else
        maxResolution = 0
    end if

    supportsSurround = SupportsSurroundSound(true) AND RegRead("fivepointone", "preferences", "1") <> "2"

    index = 0
    bestIndex = 0
    bestScore = -10000

    for each mediaItem in mediaItems
        score = 0
        resolution = firstOf(mediaItem.videoResolution, "0").toInt()

        ' If we'll be able to direct play, exit immediately
        if resolution <= maxResolution AND hasDetails = true AND videoCanDirectPlay(mediaItem) then
            bestScore = 100
            bestIndex = index
            exit for
        end if

        ' We can't direct play, so give points based on streams that we
        ' might be able to copy.

        if resolution <= maxResolution then
            score = score + 5
        end if

        if mediaItem.preferredPart <> invalid then
            if NOT (mediaItem.preferredPart.exists AND mediaItem.preferredPart.accessible) then
                score = score - 1000
            end if
            for each stream in mediaItem.preferredPart.streams
                if stream.streamType = "1" then
                    ' Video can be copied if it's H.264 and an ok resolution
                    if resolution <= maxResolution AND stream.codec = "h264" then
                        score = score + 20
                    end if
                else if stream.streamType = "2" then
                    channels = firstOf(stream.channels, "2").toInt()

                    if (stream.codec = "aac" AND channels <= 2) OR (stream.codec = "ac3" AND supportsSurround) then
                        score = score + 10
                    end if
                end if
            next
        end if

        if score > bestScore then
            bestScore = score
            bestIndex = index
        end if

        index = index + 1
    next

    if hasDetails = true then
        Debug("Picking best media item with score " + tostr(bestScore))
    end if

    m.preferredMediaItem = mediaItems[bestIndex]
    m.preferredMediaIndex = bestIndex
End Sub

Function videoSelectPartForOffset(offset)
    mediaItem = m.preferredMediaItem
    if mediaItem = invalid then return invalid
    if mediaItem.parts.Count() = 0 then return invalid

    for i = 0 to mediaItem.parts.Count() - 1
        part = mediaItem.parts[i]
        if part.startOffset + part.duration > offset then
            mediaItem.curPartIndex = i
            return part
        end if
    end for

    mediaItem.curPartIndex = 0
    return mediaItem.parts[0]
End Function

Sub videoRefresh(detailed=false)
    if m.preferredMediaItem = invalid then return

    if m.DetailUrl <> invalid then
        detailKey = m.DetailUrl
    else if m.isLibraryContent then
        if Instr(1, m.Key, "?") > 0 then
            detailKey = m.Key + "&checkFiles=1"
        else
            detailKey = m.Key + "?checkFiles=1"
        end if
    else
        detailKey = m.Key
    end if
    container = createPlexContainerForUrl(m.server, m.sourceUrl, detailKey)
    videoItemXml = container.xml.Video[0]

    if videoItemXml <> invalid then
        setVideoBasics(m, container, videoItemXml)

        if detailed AND m.DetailUrl = invalid then
            setVideoDetails(m, container, videoItemXml)
        end if
    end if
End Sub

Function newSeasonMetadata(container, item) As Object
    ' Seasons often have their own posters, but in many circumstances we prefer
    ' show's poster.
    if container.xml@mixedParents = "1" then
        thumb = firstOf(item@parentThumb, item@thumb, container.xml@thumb)
    else
        thumb = invalid
    end if

    season = createBaseMetadata(container, item, thumb)

    season.HasDetails = true

    return season
End Function

Function RewriteNodeKey(key)
    nodePrefix = "http://node.plexapp.com:32400"
    primaryServer = GetPrimaryServer()
    if Left(key, Len(nodePrefix)) = nodePrefix AND primaryServer <> invalid then
        key = primaryServer.serverUrl + Mid(key, Len(nodePrefix) + 1)
        Debug("Rewrote node key to: " + key)
    end if
    return key
End Function
