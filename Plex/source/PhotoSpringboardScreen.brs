Function itemIsPhoto(item) As Boolean
    return item <> invalid AND item.NodeName = "Photo"
End Function

Function createPhotoSpringboardScreen(context, index, viewController) As Object
    ' verify we have all the context loaded
    newObj = {}:newObj.context = context
    PhotoPlayerCheckLoaded(newObj,index)

    obj = createBaseSpringboardScreen(newObj.context, index, viewController, itemIsPhoto)
 
    obj.GoToNextItem = sbPhotoGoToNextItem
    obj.GoToPrevItem = sbPhotoGoToPrevItem

    obj.screen.SetDisplayMode("photo-fit") 
    obj.screen.SetPosterStyle("rounded-rect-16x9-generic") ' makes more sense for photos (opt2: rounded-square-generic)
    obj.SetupButtons = photoSetupButtons
    obj.MoreButton = photoSprintBoardMoreButton
    obj.GetMediaDetails = photoGetMediaDetails
    obj.ShufflePlay = (RegRead("slideshow_shuffle_play", "preferences", "0") = "1")

    obj.superHandleMessage = obj.HandleMessage
    obj.HandleMessage = photoHandleMessage

    return obj
End Function

' duplicated sbGoToNextItem() with extra logic to lazy load
function sbPhotoGoToNextItem() as Boolean
    if NOT m.AllowLeftRight then return false

    if fromFullGrid() and m.FullContext = invalid then GetPhotoContextFromFullGrid(m,invalid)
    '    if m.item.nodename = "Photo" then 
    '        GetPhotoContextFromFullGrid(m,invalid)
    '    end if
    'end if

    Debug("----- sbPhotoGoToNextItem(): we have " + tostr(m.Context.Count()) + " items total")

    maxIndex = m.Context.Count() - 1
    index = m.CurIndex
    newIndex = index

    if index < maxIndex then
        newIndex = index + 1
    else if m.WrapLeftRight then
        newIndex = 0
    end if

    if index <> newIndex then
        m.CurIndex = newIndex

        m.Item = m.Context[newIndex]
        ' m.item.url is expected, if not we need to load this
        if m.item.url = invalid then  
            Debug("----lazy load item" + tostr(m.item.key))
            container = createPlexContainerForUrl(m.item.server, invalid, m.item.key)
            if container <> invalid then 
                item = container.getmetadata()[0]
                if item <> invalid then 
                    ' anything we need to set before we reset the item
                    ' * OrigIndex might exist if shuffled
                    if m.item.OrigIndex <> invalid then item.OrigIndex = m.item.OrigIndex

                    m.item = item
                    m.Context[newIndex] = item
                end if
            end if
        end if

        m.Refresh()
        return true
    end if

    return false
End Function

' duplicated sbGoToPrevItem() with extra logic to lazy load
function sbPhotoGoToPrevItem() as Boolean
    if NOT m.AllowLeftRight then return false

    if fromFullGrid() and m.FullContext = invalid then GetPhotoContextFromFullGrid(m,invalid)
    '    if m.item.nodename = "Photo" then 
    '        GetPhotoContextFromFullGrid(m,invalid)
    '    end if
    'end if

    Debug("----- sbPhotoGoToPrevItem(): we have " + tostr(m.Context.Count()) + " items total")

    maxIndex = m.Context.Count() - 1
    index = m.CurIndex
    newIndex = index

    if index > 0 then
        newIndex = index - 1
    else if m.WrapLeftRight then
        newIndex = maxIndex
    end if

    if index <> newIndex then
        m.CurIndex = newIndex

        m.Item = m.Context[newIndex]
        ' m.item.url is expected, if not we need to load this
        if m.item.url = invalid then  
            Debug("----lazy load item" + tostr(m.item.key))
            container = createPlexContainerForUrl(m.item.server, invalid, m.item.key)
            if container <> invalid then 
                item = container.getmetadata()[0]
                if item <> invalid then 
                    ' anything we need to set before we reset the item
                    ' * OrigIndex might exist if shuffled
                    if m.item.OrigIndex <> invalid then item.OrigIndex = m.item.OrigIndex

                    m.item = item
                    m.Context[newIndex] = item
                end if
            end if
        end if

        m.Refresh()
        return true
    end if

    return false
End Function


Sub photoSetupButtons()
    m.ClearButtons()

    'if m.metadata.starrating = invalid then 'ljunkie - don't show stars if invalid
    ' it's a bit redundant -- we already show the rating as a button ( so hide them )
    m.Screen.SetStaticRatingEnabled(false)
    'end if

    if m.IsShuffled or m.ShufflePlay then
        m.AddButton("Slideshow Shuffled", "slideshow")
    else 
        m.AddButton("Slideshow", "slideshow")
    end if 
    m.AddButton("Show", "show")
    m.AddButton("Next Photo", "next")
    m.AddButton("Previous Photo", "prev")

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
    description = getExifDesc(content,false,true)
    if description <> invalid then
        content.description = description
        content.SBdescription = description
    end if

    m.metadata = content
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
            if buttonCommand = "slideshow" or buttonCommand = "show"  then
                ' Playing Photos from springBoard in a FULL grid context
                if buttonCommand = "slideshow" then GetPhotoContextFromFullGrid(m,m.item.origindex) 
                ' for now we will skip loading the full context when we "SHOW" an image -- need to load though on the "next" request
                if m.context.count() = 0 then
                    ShowErrorDialog("Sorry! We were unable to load your photos.","Warning")
                else 
                    ' Global Shuffle
                    if m.shuffleplay = true then
                        ' show a shuffling dialog if item count > 1k
                        dialog = invalid
                        if m.context.count() > 1000 then
                            text = "shuffling"
                            if m.IsShuffled then text = "unshuffling"
                            dialog=ShowPleaseWait(text + " items... please wait...","")
                        end if

                        m.Shuffle()
                        m.IsShuffled = true

                        ' shuffling can be quick on newer devices, so intead of a < 1 sec blip, let's show the shuffling items for at least a second
                        if dialog <> invalid then
                            sleep(1000)
                            dialog.close()
                        end if
                        m.Refresh()
                    end if

                    m.IsShuffled = (m.IsShuffled = 1)
                    Debug("photoHandleMessage:: springboard Start slideshow with " + tostr(m.context.count()) + " items")
                    Debug("starting at index: " + tostr(m.curindex))
                    m.ViewController.CreateICphotoPlayer(m, m.CurIndex, true, m.IsShuffled, NOT(buttonCommand = "show"))
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
        Debug("checking if we need to load context before we shuffle items!")
        GetPhotoContextFromFullGrid(obj,obj.item.origindex) 

        ' show a shuffling dialog if item count > 1k
        dialog = invalid
        if obj.context.count() > 1000 then 
            text = "shuffling"
            if obj.IsShuffled then text = "unshuffling"
            dialog=ShowPleaseWait(text + " items... please wait...","")
        end if

        if obj.IsShuffled then
            obj.Unshuffle()
            obj.IsShuffled = false
            m.SetButton(command, "Shuffle: Off")
        else
            obj.Shuffle()
            obj.IsShuffled = true
            m.SetButton(command, "Shuffle: On")
        end if

        ' shuffling can be quick on newer devices, so intead of a < 1 sec blip, let's show the shuffling items for at least a second
        if dialog <> invalid then 
             sleep(1000) 
             dialog.close()
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
