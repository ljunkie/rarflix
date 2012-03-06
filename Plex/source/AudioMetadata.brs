'*
'* Metadata objects for audio data (albums, artists, tracks)
'*

Function createBaseAudioMetadata(container, item) As Object
    metadata = createBaseMetadata(container, item)

    metadata.ratingKey = item@ratingKey

    ' We never need to fetch and parse additional details for audio metadata
    metadata.HasDetails = True

    return metadata
End Function

Function newArtistMetadata(container, item, detailed=true) As Object
    artist = createBaseAudioMetadata(container, item)

    artist.Artist = item@title
    artist.ContentType = "artist"
    artist.mediaContainerIdentifier = container.xml@identifier
    if artist.Type = invalid then artist.Type = "artist"

    if detailed then
        artist.Categories = CreateObject("roArray", 5, true)
        for each genre in item.Genre
            artist.Categories.Push(genre@tag)
        next
    end if

    if artist.Title = invalid then
        artist.Title = item@artist
        artist.ShortDescriptionLine1 = artist.Title
    end if

    return artist
End Function

Function newAlbumMetadata(container, item, detailed=true) As Object
    album = createBaseAudioMetadata(container, item)

    album.ContentType = "album"
    album.mediaContainerIdentifier = container.xml@identifier
    if album.Type = invalid then album.Type = "album"

    album.Artist = firstOf(item@parentTitle, container.xml@parentTitle, item@artist)
    album.Album = firstOf(item@title, item@album)
    album.ReleaseDate = firstOf(item@originallyAvailableAt, item@year)

    if album.Title = invalid then
        album.Title = album.Album
        album.ShortDescriptionLine1 = album.Title
    end if

    return album
End Function

Function newTrackMetadata(container, item, detailed=true) As Object
    track = createBaseAudioMetadata(container, item)

    track.ContentType = "audio"
    track.mediaContainerIdentifier = container.xml@identifier
    if track.Type = invalid then track.Type = "track"

    if container.xml@mixedParents = "1" then
        track.Artist = firstOf(item@grandparentTitle, item@artist)
        track.Album = firstOf(item@parentTitle, item@album, "Unknown Album")
        track.ReleaseDate = item@parentYear
        track.AlbumYear = item@parentYear
    else
        track.Artist = firstOf(container.xml@grandparentTitle, item@artist)
        track.Album = firstOf(container.xml@parentTitle, item@album, "Unknown Album")
        track.ReleaseDate = container.xml@parentYear
        track.AlbumYear = container.xml@parentYear
    end if

    track.EpisodeNumber = item@index
    duration = firstOf(item@duration, item@totalTime)
    if duration <> invalid then track.Duration = int(val(duration)/1000)
    track.Length = track.Duration

    if track.Title = invalid then
        track.Title = item@track
        track.ShortDescriptionLine1 = track.Title
    end if

    media = item.Media[0]

    if media <> invalid
        part = media.Part[0]
        codec = media@audioCodec
        key = part@key
    else
        ' TODO(schuyler): How are we supposed to figure this out? Infer from
        ' the URL, hoping that it has an extension in a predictable place?
        codec = "mp3"
        key = item@key
    end if

    if codec = "mp3" OR codec = "wmv" OR codec = "aac" then
        track.StreamFormat = codec
        track.Url = FullUrl(track.server.serverUrl, track.sourceUrl, key)
    else
        track.StreamFormat = "mp3"
        track.Url = track.server.TranscodingAudioUrl(key, track)
    end if

    return track
End Function
