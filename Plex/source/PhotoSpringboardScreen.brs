Function itemIsPhoto(item) As Boolean
    return item <> invalid AND item.NodeName = "Photo"
End Function

Function createPhotoSpringboardScreen(context, index, viewController) As Object
    obj = createBaseSpringboardScreen(context, index, viewController, itemIsPhoto)

    obj.screen.SetDisplayMode("photo-fit") 
    obj.screen.SetPosterStyle("rounded-rect-16x9-generic") ' makes more sense for photos (opt2: rounded-square-generic)
    obj.SetupButtons = photoSetupButtons
    obj.MoreButton = photoSprintBoardMoreButton
    obj.GetMediaDetails = photoGetMediaDetails

    obj.superHandleMessage = obj.HandleMessage
    obj.HandleMessage = photoHandleMessage

    return obj
End Function

Sub photoSetupButtons()
    m.ClearButtons()

    'if m.metadata.starrating = invalid then 'ljunkie - don't show stars if invalid
    ' it's a bit redundant -- we already show the rating as a button ( so hide them )
    m.Screen.SetStaticRatingEnabled(false)
    'end if

    print "woooo hoooo setup buttongs"
    print m
    if m.IsShuffled then 
        m.AddButton("Slideshow Shuffled", "ICslideshow")
    else 
        m.AddButton("Slideshow", "ICslideshow")
    end if 
    ' m.AddButton("Slideshow Shuffled", "ICslideshowShuffled")-- it's handled by the more/* button ( toggle slideshow )
    m.AddButton("Show", "ICshow")
    m.AddButton("Next Photo", "next")
    m.AddButton("Previous Photo", "prev")

    print m.metadata
    if m.metadata.UserRating = invalid then m.metadata.UserRating = 0
    if m.metadata.StarRating = invalid then
        if m.metadata.UserRating <> invalid and m.metadata.UserRating > 0 then 
            m.metadata.StarRating = m.metadata.UserRating
        else 
            m.metadata.StarRating = 0
        end if
    endif

    if m.metadata.origStarRating = invalid then
        m.metadata.origStarRating = 0
    endif

    m.AddRatingButton(m.metadata.UserRating, m.metadata.origStarRating, "ratePhoto")
    ' When delete is present, put delete and rate in a separate dialog. -- nah, we still have enough room
    '    if m.metadata.server.AllowsMediaDeletion AND m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then
    m.AddButton("More...", "more")
    '    else

End Sub

Sub photoGetMediaDetails(content)
    ' ljunkie - refresh exif for descriptions ( we lazy load this on the grid )
    if content.ExifSBloaded = invalid then
        description = getExifData(content,false)
        if description <> invalid then
            content.description = description
            content.SBdescription = description
            content.ExifSBloaded = true ' make sure we don't load it again
        end if
    end if

    m.metadata = content
    m.media = invalid
End Sub

Function photoHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roSpringboardScreenEvent" then
        if ((msg.isRemoteKeyPressed() AND msg.GetIndex() = 10) OR msg.isButtonInfo()) then
            m.MoreButton()
        else if msg.isButtonPressed() then
            handled = true
            buttonCommand = m.buttonCommands[str(msg.getIndex())]
            Debug("Button command: " + tostr(buttonCommand))
            ' deprecated old commands
            'if buttonCommand = "show" then
            '    Debug("photoHandleMessage:: Show photo fullscreen")
            '    m.ViewController.CreatePhotoPlayer(m.Item)
            'else if buttonCommand = "slideshow" then
            '    ' Playing Photos from springBoard in a FULL grid context
            '    GetContextFromFullGrid(m,m.focusedIndex) 
	    '    if m.context.count() = 0 then
            '        ShowErrorDialog("Sorry! We were unable to load your photos.","Warning")
            '    else 
            '        Debug("photoHandleMessage:: springboard Start slideshow with " + tostr(m.context.count()) + " items")
            '        Debug("starting at index: " + tostr(m.curindex))
            '        m.ViewController.CreatePhotoPlayer(m.Context, m.CurIndex, true, m.IsShuffled)
            '    end if
            if buttonCommand = "ICslideshow" or buttonCommand = "ICshow" or buttonCommand = "ICslideshowShuffled" then
                ' Playing Photos from springBoard in a FULL grid context
                GetContextFromFullGrid(m,m.item.origindex) 
		if m.context.count() = 0 then
                    ShowErrorDialog("Sorry! We were unable to load your photos.","Warning")
                else 
                    m.IsShuffled = (buttonCommand = "ICslideshowShuffled" or m.IsShuffled = 1)
                    ' shuffle and reset curIndex 
                    if m.IsShuffled then m.curindex = ShuffleArray(m.Context, m.curindex)
                    Debug("photoHandleMessage:: springboard Start slideshow with " + tostr(m.context.count()) + " items")
                    Debug("starting at index: " + tostr(m.curindex))
                    m.ViewController.CreateICphotoPlayer(m.Context, m.CurIndex, true, m.IsShuffled, NOT(buttonCommand = "ICshow"))
                end if
            else if buttonCommand = "next" then
                Debug("photoHandleMessage:: show next photo")
                 m.GotoNextItem()
            else if buttonCommand = "prev" then
                Debug("photoHandleMessage:: show previous photo")
                 m.GotoPrevItem()
            else if buttonCommand = "ratePhoto" then
                Debug("photoHandleMessage:: Rate photo for key " + tostr(m.metadata.ratingKey))
                rateValue% = (msg.getData() /10)
                m.metadata.UserRating = msg.getdata()
                if m.metadata.ratingKey = invalid then
                    m.metadata.ratingKey = 0
                end if
                m.Item.server.Rate(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier,rateValue%.ToStr())
            else if buttonCommand = "more" then
                m.MoreButton()
            else
                handled = false
            end if
        end if
    end if

    return handled OR m.superHandleMessage(msg)
End Function

sub photoSprintBoardMoreButton()
                dialog = createBaseDialog()
                dialog.Title = ""
                dialog.Text = ""
                dialog.Item = m.metadata
                if m.IsShuffled then
                    dialog.SetButton("shuffle", "Shuffle: On")
                else
                    dialog.SetButton("shuffle", "Shuffle: Off")
                end if
                dialog.SetButton("rate", "_rate_")
                if m.metadata.server.AllowsMediaDeletion AND m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then
                    dialog.SetButton("delete", "Delete permanently")
                end if
                dialog.SetButton("close", "Back")
                dialog.HandleButton = photoDialogHandleButton
                dialog.ParentScreen = m
                dialog.Show()
end sub

Function photoDialogHandleButton(command, data) As Boolean
    ' We're evaluated in the context of the dialog, but we want to be in
    ' the context of the original screen.
    obj = m.ParentScreen

    if command = "delete" then
        obj.metadata.server.delete(obj.metadata.key)
        obj.closeOnActivate = true
        return true
    else if command = "shuffle" then
        if obj.IsShuffled then
            obj.Unshuffle()
            obj.IsShuffled = false
            m.SetButton(command, "Shuffle: Off")
        else
            obj.Shuffle()
            obj.IsShuffled = true
            m.SetButton(command, "Shuffle: On")
        end if
        m.Refresh()
        obj.Refresh()
    else if command = "rate" then
        Debug("photoHandleMessage:: Rate audio for key " + tostr(obj.metadata.ratingKey))
        rateValue% = (data /10)
        obj.metadata.UserRating = data
        if obj.metadata.ratingKey <> invalid then
            obj.Item.server.Rate(obj.metadata.ratingKey, obj.metadata.mediaContainerIdentifier, rateValue%.ToStr())
        end if
        obj.Refresh()
    else if command = "close" then
        return true
    end if
    return false
End Function
