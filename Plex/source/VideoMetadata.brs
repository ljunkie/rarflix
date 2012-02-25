
Function newVideoMetadata(container, item, detailed=false) As Object
    video = createBaseMetadata(container, item)

    if item = invalid then return video

    video.mediaContainerIdentifier = container.xml@identifier
    video.ratingKey = item@ratingKey
    video.ContentType = item@type
    if video.ContentType = invalid then
        '* treat video items with no content type as clips
        video.ContentType = "clip" 
    endif

    video.ReleaseDate = item@originallyAvailableAt
    video.viewOffset = item@viewOffset
    video.viewCount = item@viewCount

    length = item@duration
    if length <> invalid then
        video.Length = int(val(length)/1000)
        video.RawLength = val(length)
    endif

    video.Watched = video.viewCount <> invalid AND val(video.viewCount) > 0
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
    else if video.Watched AND length <> invalid then
        video.BookmarkPosition = int(val(length)/1000)
    end if

    video.ShortDescriptionLine2 = firstOf(item@sourceTitle, item@tagline, video.ShortDescriptionLine2)

    if container.ViewGroup = "episode" then
        if item@grandparentTitle <> invalid then
            video.ShortDescriptionLine1 = item@grandparentTitle + ": " + video.ShortDescriptionLine1
        end if
        if item@index <> invalid then
            video.EpisodeNumber = item@index
            episode = "Episode " + item@index
        else
            video.EpisodeNumber = 0
            episode = "Episode ??"
        end if
        if item@parentIndex <> invalid then
            video.TitleSeason = video.Title + " Season " + item@parentIndex
            video.ShortDescriptionLine2 = "Season " + item@parentIndex + " - " + episode
        else
            video.ShortDescriptionLine2 = episode
        end if
        if video.ReleaseDate <> invalid then
            video.ShortDescriptionLine2 = video.ShortDescriptionLine2 + " - " + video.ReleaseDate
        end if
    end if

    video.Title = video.ShortDescriptionLine1

    if container.ViewGroup = "Details" OR container.ViewGroup = "InfoList" then
        video.ShortDescriptionLine2 = item@summary
    endif

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
	
    video.ParseDetails = videoParseDetails

    if detailed then
        ' Also sets media and preferredMediaItem
        video.ParseDetails()
    else
        video.media = ParseVideoMedia(item)
        video.preferredMediaItem = PickMediaItem(video.media)
    end if

    return video
End Function

Function videoParseDetails()
    if m.HasDetails then return m

    container = createPlexContainerForUrl(m.server, m.sourceUrl, m.Key)
    videoItemXml = container.xml.Video[0]

    video = m

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

    return video
End Function

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
		media.parts = CreateObject("roArray", 3, true)
		for each MediaPart in MediaItem.Part
			part = CreateObject("roAssociativeArray")
			part.id = MediaPart@id
			part.key = MediaPart@key
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
	if mediaItems.count()  = 0 then
		return mediaItems[0]
	else
		return mediaItems[0]
	endif
End Function

