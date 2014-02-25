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

    if artist.Title = "" then
        artist.Title = firstOf(item@artist, "")
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

    epoch = item@addedAt
    if epoch <> invalid then 
        date = CreateObject("roDateTime")
        date.FromSeconds(epoch.toInt())
        date.ToLocalTime()
        album.AddDate = date.AsDateString("short-month-short-weekday")
        if album.ReleaseDate <> invalid then 
            album.ReleaseDate = "Released: " + album.ReleaseDate + chr(10) + "    Added: " + album.AddDate
        else 
            album.ReleaseDate = "Added: " + album.AddDate
        end if
    end if

    if album.Title = invalid then
        album.Title = album.Album
        album.ShortDescriptionLine1 = album.Title
    end if

    if container.xml@mixedParents = "1" then
        if album.Artist <> invalid then
            album.Title = album.Artist + ": " + album.Album
        end if
        album.ShortDescriptionLine2 = album.Artist
    end if

    return album
End Function

Function newTrackMetadata(container, item, detailed=true) As Object
    track = createBaseAudioMetadata(container, item)

    track.ContentType = "audio"
    track.mediaContainerIdentifier = container.xml@identifier
    if track.Type = invalid then track.Type = "track"

    ' ljunkie added some new hooks for the audio now playing row ( not 100% yet )
    ' /status/sessions doesn't containt container.xml@mixedParents, but it is
    if container.xml@mixedParents = "1" or InStr(0, container.sourceurl, "/status/sessions" ) > 0 then
        track.Artist = firstOf(item@grandparentTitle, item@artist)
        track.Album = firstOf(item@parentTitle, item@album, "Unknown Album")
        track.ReleaseDate = item@parentYear
        track.AlbumYear = item@parentYear
        track.ShortDescriptionLine2 = track.Album
    else
        track.Artist = firstOf(container.xml@grandparentTitle, item@artist)
        track.Album = firstOf(container.xml@parentTitle, item@album, "Unknown Album")
        track.ReleaseDate = container.xml@parentYear
        track.AlbumYear = container.xml@parentYear
    end if

    ' ljunkie - let eu prefer to show the track artist (fall back to already set track.artist)
    displayArtist = RegRead("rf_music_artist", "preferences", "track")
    if displayArtist = "track" then     
        track.Artist = firstOf(item@originalTitle, container.xml@title1, track.Artist)
    else if displayArtist = "various" then     
        r = CreateObject("roRegex", "various|invalid", "i") ' section too - those are not special
        if r.IsMatch(tostr(track.Artist)) then 
            track.Artist = firstOf(item@originalTitle, container.xml@title1, track.Artist)
        end if
    end if

    track.EpisodeNumber = item@index
    duration = firstOf(item@duration, item@totalTime)
    if duration <> invalid then
        track.Duration = int(val(duration)/1000)
        track.RawLength = int(val(duration))
    end if
    track.Length = track.Duration

    if track.Title = invalid then
        track.Title = item@track
        track.ShortDescriptionLine1 = track.Title
    end if

    track.Title = firstof(track.umtitle, track.title) ' ljunkie lame I know, but I am not sure where the album is being appended yet. seems to be inherited.

    media = item.Media[0]

    if media <> invalid
        part = media.Part[0]
        codec = media@audioCodec
        key = part@key
    else
        codec = invalid
        key = item@key
    end if

    if (codec = invalid OR codec = "") AND key <> invalid then
        ' It's probably the extension on the key, try to be lenient.
        codec = key.Tokenize(".").Peek()
        queryStart = instr(1, codec, "?")
        if queryStart > 0 then
            codec = left(codec, queryStart - 1)
        end if
        Debug("Audio codec wasn't set, inferred " + tostr(codec))
    end if

    ' If it's a .m4a, we're probably in the iTunes channel, and we don't know
    ' if it's AAC or ALAC. If the server supports transcoding, play it safe
    ' and transcode. If it doesn't, call it AAC and hope for the best.
    if codec = "m4a" AND NOT track.server.SupportsAudioTranscoding then
        codec = "aac"
    end if

    if codec = "mp3" OR codec = "wma" OR codec = "aac" OR (codec = "flac" AND CheckMinimumVersion(GetGlobal("rokuVersionArr", [0]), [5, 1])) then
        track.StreamFormat = codec
        track.Url = FullUrl(track.server.serverUrl, track.sourceUrl, key)
    else
        track.StreamFormat = "mp3"
        track.Url = track.server.TranscodingAudioUrl(key, track)
    end if

    ' Url being invalid has been observed to make the Roku die a very
    ' horrible death that requires a power cycle.
    if track.Url = invalid then
        track.Codec = "invalid"
        track.StreamFormat = "invalid"
        track.Url = ""
    end if

    track.CleanTitle = track.Title

    ' the Shared User Now Playing rows ( rarflix ) -- some hoods for the required metadata
    if item.user@title <> invalid then 
        ' save any variables we change for later
        track.nowPlaying_orig_title = track.title
        track.nowPlaying_orig_description = track.Artist + " : " + track.Album
        track.viewoffset = item@viewoffset      

        track.description = "" ' reset video Description -- blank but not invalid
        if track.viewoffset <> invalid then 
             track.description = "Progress: " + GetDurationString(int(track.viewoffset.toint()/1000),0,1,1)
             track.description = track.description + " [" + percentComplete(track.viewOffset,track.length) + "%]"
        else if item.Player@state <> invalid then
             track.description = item.Player@state
        end if

        track.description = track.description + " on " + firstof(item.Player@title, item.Player@platform)
        if track.server.name <> invalid then track.description = track.description + " [" + track.server.name + "]" ' show the server 
        track.nowPlaying_progress = track.description ' container for HUD notify

        ' append the original description if NOT invalid
        if track.nowPlaying_orig_description <> invalid then track.description = track.description + chr(10) + track.nowPlaying_orig_description

        ' prepend the "user:" to the video title
        track.title = UcaseFirst(item.user@title,true) + " " + UcaseFirst(item.Player@state) + ": "  + track.CleanTitle

        ' set nowPlaying info for later
        track.nowPlaying_maid = item.Player@machineIdentifier ' use to verify the stream we are syncing is the same
        track.nowPlaying_user = item.user@title
        track.nowPlaying_state = item.Player@state
        track.nowPlaying_platform = item.Player@platform
        track.nowPlaying_platform_title = item.Player@title
    end if
    ' end shared now playing metadata

    return track
End Function
