'itei*
'* Metadata objects for photo data
'*

Function createBasePhotoMetadata(container, item) As Object
    metadata = createBaseMetadata(container, item)

    metadata.ratingKey = item@ratingKey

    ' photos don't have a default - so only userrating for now
    userRating = item@userRating
    if userRating <> invalid then
	metadata.UserRating =  int(val(userRating)*10)
        ' if prefer user rating OR we ONLY show user ratings, then override the starRating if it exists (isn't need for photos yet)
        ' refer to VideoMetadata if these defaults ever change
            metadata.StarRating =  int(val(userRating)*10)
    else
	metadata.UserRating =  0
    end if


    ' We never need to fetch and parse additional details for audio metadata
    metadata.HasDetails = True

    return metadata
End Function

Function newPhotoMetadata(container, item, detailed=true) As Object
    photo = createBasePhotoMetadata(container, item)

    photo.Title = item@title
    photo.mediaContainerIdentifier = container.xml@identifier
    photo.ContentType = "photo"
    if photo.Type = invalid then photo.Type = "photo"
    photo.media = ParsePhotoMedia(item)

    if photo.media.Count() > 0 AND photo.media[0].preferredPart <> invalid then
        photo.Url = FullUrl(photo.server.serverUrl, photo.sourceUrl, photo.media[0].preferredPart.key)
        'ljunkie - lets include some more details - maybe some point we can include the item key Media details that includes EXIF data
        ' that would cause major issues though with LARGE directories ( you know who I'm talking about... )
        photo.Description = ""
        if photo.media[0].width <> invalid and photo.media[0].height <> invalid then 
            photo.Description = photo.Description + tostr(photo.media[0].width) + " x " + tostr(photo.media[0].height) + chr(10)
        end if
        photo.Description = photo.Description + tostr(photo.media[0].container) + " aspect: " + tostr(photo.media[0].aspectratio)
    else
        photo.Url = FullUrl(photo.server.serverUrl, photo.sourceUrl, photo.key)
    end if

    photo.TextOverlayUL = photo.Title
    photo.TextOverlayBody = item@summary

    ' If there's no thumb, make a thumb out of the full URL.
    if photo.SDPosterURL = invalid OR Left(photo.SDPosterURL, 4) = "file" then
        sizes = ImageSizes("photos", "photo")
        photo.SDPosterURL = photo.server.TranscodedImage("", photo.Url, sizes.sdWidth, sizes.sdHeight)
        photo.HDPosterURL = photo.server.TranscodedImage("", photo.Url, sizes.hdWidth, sizes.hdHeight)
    end if

    ' Transcode if necessary
    if photo.media.Count() > 0 then
        format = UCase(firstOf(photo.media[0].container, "JPEG"))
        transcode = false
        size = GetGlobal("DisplaySize")

        ' JPEG and PNG are documented, GIF appears to work fine
        ' ljunkie - TODO - but it's also document the roku will cover the image back to a JPG ( is it faster to complete on the server )
        if format <> "JPEG" AND format <> "JPG" AND format <> "PNG" AND format <> "GIF" then
            Debug("Transcoding photo to JPEG from " + format)
            transcode = true
        else if photo.media[0].width > size.w OR photo.media[0].height > size.h then
            ' this will almost always happen.. i'm going to disable logging this. who is going to have images already in thumbnail format?
            ' Debug("Transcoding photo because it's unnecessarily large: " + tostr(photo.media[0].width) + "x" + tostr(photo.media[0].height))
            transcode = true
        else if photo.media[0].width <= 0 then
            Debug("Transcoding photo for fear that it requires EXIF rotation")
            transcode = true
        end if

        if transcode then
            photo.Url = photo.server.TranscodedImage("", photo.Url, size.w.toStr(), size.h.toStr())
        end if
    end if

    return photo
End Function

Function ParsePhotoMedia(photoItem) As Object
    mediaArray = CreateObject("roArray", 5, true)
    for each MediaItem in photoItem.Media
        media = CreateObject("roAssociativeArray")

        media.identifier = MediaItem@id
        media.container = MediaItem@container
        media.width = firstOf(MediaItem@width, "0").toint()
        media.height = firstOf(MediaItem@height, "0").toint()
        media.aspectratio = MediaItem@aspectRatio

        ' these will be invalid unless we directly query for the photo library key
        ' so don't expect this to be available all the time
        media.aperture = MediaItem@aperture
        media.exposure = MediaItem@exposure
        media.iso = MediaItem@iso
        media.lens = MediaItem@lens
        media.make = MediaItem@make
        media.model = MediaItem@model
        media.id = MediaItem@id

        media.parts = CreateObject("roArray", 2, true)
        for each MediaPart in MediaItem.Part
            part = CreateObject("roAssociativeArray")
            part.id = MediaPart@id
            part.key = MediaPart@key

            media.parts.Push(part)
        next

        media.preferredPart = media.parts[0]
        mediaArray.Push(media)
    next

    return mediaArray
End Function
