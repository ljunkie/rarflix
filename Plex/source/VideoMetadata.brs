
Function newVideoMetadata(container, item, detailed=false) As Object
    video = createBaseMetadata(container, item)

    video.Refresh = videoRefresh
    video.ParseDetails = videoParseDetails

    if item = invalid then return video

    video.mediaContainerIdentifier = container.xml@identifier
    video.ratingKey = item@ratingKey
    video.ContentType = item@type
    if video.ContentType = invalid then
        '* treat video items with no content type as clips
        video.ContentType = "clip" 
    endif

    video.ReleaseDate = item@originallyAvailableAt

    length = item@duration
    if length <> invalid then
        video.Length = int(val(length)/1000)
        video.RawLength = val(length)
    endif

    if container.ViewGroup = "Details" OR container.ViewGroup = "InfoList" then
        video.ShortDescriptionLine2 = item@summary
    endif

    setVideoBasics(video, container, item)
	
    if detailed then
        ' Also sets media and preferredMediaItem
        video.ParseDetails()
    else
        video.media = ParseVideoMedia(item)
        video.preferredMediaItem = PickMediaItem(video.media)
    end if

    return video
End Function

Sub setVideoBasics(video, container, item)
    video.viewOffset = item@viewOffset
    video.viewCount = item@viewCount
    video.Watched = video.viewCount <> invalid AND val(video.viewCount) > 0

    video.ShortDescriptionLine1 = firstOf(item@title, item@name)

    ' if a video has ever been watch mark as such, else mark partially if there's a recorded
    ' offset
    if video.Watched then
        video.ShortDescriptionLine1 = video.ShortDescriptionLine1 + " (Watched)"
    else if video.viewOffset <> invalid AND val(video.viewOffset) > 0 then
        video.ShortDescriptionLine1 = video.ShortDescriptionLine1 + " (Partially Watched)"
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
            video.EpisodeStr = seasonStr + episodeStr
            video.OrigReleaseDate = video.ReleaseDate
            video.ReleaseDate = video.EpisodeStr
            video.TitleSeason = video.Title + " - " + video.EpisodeStr
        end if
    else if video.ContentType = "clip" then
        video.ReleaseDate = firstOf(video.ReleaseDate, item@subtitle)
    end if

    video.Title = video.ShortDescriptionLine1

    if container.xml@mixedParents = "1" then
        if video.server <> invalid AND item@grandparentThumb <> invalid then
            sizes = ImageSizes(container.ViewGroup, item@type)                                                                                    
            video.SDPosterURL = video.server.TranscodedImage(container.sourceUrl, item@grandparentThumb, sizes.sdWidth, sizes.sdHeight)
            video.HDPosterURL = video.server.TranscodedImage(container.sourceUrl, item@grandparentThumb, sizes.hdWidth, sizes.hdHeight)
        end if
    end if

    video.Rating = item@contentRating
    rating = item@rating
    if rating <> invalid then
        video.StarRating = int(val(rating)*10)
    endif

    userRating = item@userRating
    if userRating <> invalid then
	video.UserRating =  int(val(userRating)*10)
    else 
	video.UserRating =  0
    endif
End Sub

Function videoParseDetails()
    if m.HasDetails then return m

    ' Don't bother trying to request bogus (webkit) keys
    if left(m.Key, 5) <> "plex:" then
        container = createPlexContainerForUrl(m.server, m.sourceUrl, m.Key)
        videoItemXml = container.xml.Video[0]

        setVideoDetails(m, container, videoItemXml)
    end if

    m.HasDetails = true

    return m
End Function

Sub setVideoDetails(video, container, videoItemXml)
    ' Fix some items that might have been modified for the grid view.
    if video.OrigReleaseDate <> invalid then
        video.ReleaseDate = video.OrigReleaseDate
    end if

    ' Everything else requires a Video item, which we might not have for clips.
    if videoItemXml = invalid then return

    video.Actors = CreateObject("roArray", 15, true)
    for each Actor in videoItemXml.Role
        video.Actors.Push(Actor@tag)
    next
    video.Director = CreateObject("roArray", 3, true)
    for each Director in videoItemXml.Director
        video.Director.Push(Director@tag)
    next
    video.Categories = CreateObject("roArray", 15, true)
    for each Category in videoItemXml.Genre
        video.Categories.Push(Category@tag)
    next

    art = videoItemXml@thumb
    if video.server <> invalid AND art <> invalid then
        sizes = ImageSizes(container.ViewGroup, video.type)
        video.SDPosterURL = video.server.TranscodedImage(container.sourceUrl, art, sizes.sdWidth, sizes.sdHeight)
        video.HDPosterURL = video.server.TranscodedImage(container.sourceUrl, art, sizes.hdWidth, sizes.hdHeight)
    end if

    ' TODO: review the logic here. Last media item wins. Is this what we want?
    ' TODO: comment out HD for now - does it fix the SD playing regression?
    for each MediaItem in videoItemXml.Media
        videoResolution = MediaItem@videoResolution
        if videoResolution = "1080" OR videoResolution = "720" then
            '	video.IsHD = true
            video.HDBranded = true
        endif
        'if videoResolution = "1080" then
        '	video.FullHD = true
        'endif
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

    video.media = ParseVideoMedia(videoItemXml)
    video.preferredMediaItem = PickMediaItem(video.media)
End Sub

Function ParseVideoMedia(videoItem) As Object
    mediaArray = CreateObject("roArray", 5, true)
	for each MediaItem in videoItem.Media
		media = CreateObject("roAssociativeArray")
		media.indirect = false
		if MediaItem@indirect <> invalid AND MediaItem@indirect = "1" then
			media.indirect = true
		end if
		media.identifier = MediaItem@id
		media.audioCodec = MediaItem@audioCodec
		media.videoCodec = MediaItem@videoCodec
		media.videoResolution = MediaItem@videoResolution
		media.container = MediaItem@container
        media.optimized = MediaItem@optimizedForStreaming
		media.parts = CreateObject("roArray", 3, true)
		for each MediaPart in MediaItem.Part
			part = CreateObject("roAssociativeArray")
			part.id = MediaPart@id
			part.key = MediaPart@key
            part.postURL = MediaPart@postURL
			part.streams = CreateObject("roArray", 5, true)
			for each StreamItem in MediaPart.Stream
				stream = CreateObject("roAssociativeArray")
				stream.id = StreamItem@id
				stream.streamType = StreamItem@streamType
				stream.codec = StreamItem@codec
				stream.language = StreamItem@language
				stream.selected = StreamItem@selected
				stream.channels = StreamItem@channels
				part.streams.Push(stream)
			next
			media.parts.Push(part)
		next
		'* TODO: deal with multiple parts correctly. Not sure how audio etc selection works
		'* TODO: with multi-part
		media.preferredPart = media.parts[0]
		mediaArray.Push(media)
	next
	return mediaArray
End Function

'* Logic for choosing which Media item to use from the collection of possibles.
Function PickMediaItem(mediaItems) As Object
    quality = firstOf(RegRead("quality", "preferences"), "7").toInt()
    if quality >= 9 then
        maxResolution = 1080
    else if quality >= 6 then
        maxResolution = 720
    else if quality >= 5 then
        maxResolution = 480
    else
        maxResolution = 0
    end if
    print "Picking media item based on max resolution:"; maxResolution

    best = invalid
    for each mediaItem in mediaItems
        resolution = firstOf(mediaItem.videoResolution, "0").toInt()
        if resolution <= maxResolution then
            if best = invalid then best = mediaItem

            ' If it looks like direct play would work, return it immediately
            print "Media item optimized for streaming: "; mediaItem.optimized
            if (mediaItem.optimized = "true" OR mediaItem.optimized = "1") AND mediaItem.container = "mp4" AND mediaItem.videoCodec = "h264" AND (mediaItem.audioCodec = "aac" OR mediaItem.audioCodec = "mp3") then
                return mediaItem
            end if
        end if
    next

    return firstOf(best, mediaItems[0])
End Function

Sub videoRefresh(detailed=false)
    container = createPlexContainerForUrl(m.server, m.sourceUrl, m.Key)
    videoItemXml = container.xml.Video[0]

    if videoItemXml <> invalid then
        setVideoBasics(m, container, videoItemXml)

        if detailed then
            setVideoDetails(m, container, videoItemXml)
        end if
    end if
End Sub

