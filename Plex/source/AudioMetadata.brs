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

    return artist
End Function

Function newAlbumMetadata(container, item, detailed=true) As Object
    album = createBaseAudioMetadata(container, item)

    album.ContentType = "album"
    album.mediaContainerIdentifier = container.xml@identifier
    if album.Type = invalid then album.Type = "album"

    album.Artist = firstOf(item@parentTitle, container.xml@parentTitle)
    album.Album = item@title
    album.ReleaseDate = firstOf(item@originallyAvailableAt, item@year)

    return album
End Function

Function newTrackMetadata(container, item, detailed=true) As Object
    track = createBaseAudioMetadata(container, item)

    track.ContentType = "audio"
    track.mediaContainerIdentifier = container.xml@identifier
    if track.Type = invalid then track.Type = "track"

    if container.xml@mixedParents = "1" then
        track.Artist = item@grandparentTitle
        track.Album = firstOf(item@parentTitle, "Unknown Album")
        track.ReleaseDate = item@parentYear
        track.AlbumYear = item@parentYear
    else
        track.Artist = container.xml@grandparentTitle
        track.Album = firstOf(container.xml@parentTitle, "Unknown Album")
        track.ReleaseDate = container.xml@parentYear
        track.AlbumYear = container.xml@parentYear
    end if

    track.EpisodeNumber = item@index
    if item@duration <> invalid then track.Duration = int(val(item@duration)/1000)
    track.Length = track.Duration

    media = item.Media[0]
    part = media.Part[0]

    if media@audioCodec = "mp3" OR media@audioCodec = "wmv" OR media@audioCodec = "aac" then
        track.StreamFormat = media@audioCodec
        track.Url = FullUrl(track.server.serverUrl, track.sourceUrl, part@key)
    else
        track.StreamFormat = "mp3"
        track.Url = track.server.TranscodingAudioUrl(part@key, track)
    end if

    return track
End Function
