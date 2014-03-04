'*
'* Base springboard screen on top of which audio/video/photo players are used.
'*

Function itemIsRefreshable(item) As Boolean
    return item <> invalid and type(item) = "roAssociativeArray" AND item.refresh <> invalid
End Function

Function createBaseSpringboardScreen(context, index, viewController, includePredicate=itemIsRefreshable) As Object
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    screen = CreateObject("roSpringboardScreen")
    screen.SetMessagePort(obj.Port)

    screen.UseStableFocus(true) ' ljunkie - setting this globally - might want to toggle this or only enable for Video?

    ' Filter out anything in the context that can't be shown on a springboard.
    contextCopy = []
    i = 0
    offset = 0
    for each item in context
        if includePredicate(item) then
            contextCopy.Push(item)
            item.OrigIndex = i - offset
        else if i < index then
            offset = offset + 1
        end if
        i = i + 1
    next

    index = index - offset

    ' Standard properties for all our Screen types
    obj.Item = contextCopy[index]
    obj.Screen = screen
    obj.Show = sbShow
    obj.HandleMessage = sbHandleMessage

    ' Some properties that allow us to move between items in whatever
    ' container got us to this point.
    obj.Context = contextCopy
    obj.CurIndex = index
    obj.AllowLeftRight = contextCopy.Count() > 1
    obj.WrapLeftRight = obj.AllowLeftRight

    obj.IsShuffled = false
    obj.Shuffle = sbShuffle
    obj.Unshuffle = sbUnshuffle

    obj.Refresh = sbRefresh
    obj.GotoNextItem = sbGotoNextItem
    obj.GotoPrevItem = sbGotoPrevItem

    ' Properties/methods to facilitate setting up buttons in the UI
    obj.buttonCommands = invalid
    obj.buttonCount = 0
    obj.ClearButtons = sbClearButtons
    obj.AddButton = sbAddButton
    obj.AddRatingButton = sbAddRatingButton

    ' Methods that will need to be provided by subclasses
    obj.SetupButtons = invalid
    obj.GetMediaDetails = invalid

    obj.thumbnailsToReset = []

    ' Stretched and cropped posters both look kind of terrible, so zoom.
    screen.SetDisplayMode("zoom-to-fill")

    return obj
End Function

Sub sbShuffle()
    ' Our context is already a copy of the original, so we can safely shuffle
    ' in place. Mixing up the list means that all the navigation will work as
    ' expected without needing a bunch of special logic elsewhere.

    m.CurIndex = ShuffleArray(m.Context, m.CurIndex)
End Sub

Sub sbUnshuffle()
    m.CurIndex = UnshuffleArray(m.Context, m.CurIndex)
End Sub

Sub sbShow()
    ' Refresh calls m.Screen.Show()
    m.Refresh()
End Sub

Function sbHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roSpringboardScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            for each item in m.thumbnailsToReset
                if item.SDGridThumb <> invalid then
                    item.SDPosterUrl = item.SDGridThumb
                    item.HDPosterUrl = item.HDGridThumb
                end if
            next
            m.thumbnailsToReset.Clear()

            m.ViewController.PopScreen(m)
            NowPlayingManager().location = "navigation"
        else if msg.isButtonPressed() then
            buttonCommand = m.buttonCommands[str(msg.getIndex())]
            Debug("Unhandled button press: " + tostr(buttonCommand))
        else if msg.isRemoteKeyPressed() then
            '* index=4 -> left ; index=5 -> right
            if msg.getIndex() = 4 then
                m.GotoPrevItem()
            else if msg.getIndex() = 5 then
                m.GotoNextItem()
            endif
        end if
    end if

    return handled
End Function

Function sbRefresh(force=false)
    ' Don't show any sort of facade or loading dialog. We already have the
    ' metadata for all of our siblings, we don't have to fetch anything, and
    ' so the new screen usually comes up immediately. The dialog with the
    ' spinner ends up just flashing on the screen and being annoying.
    m.Screen.SetContent(invalid)

    if force then m.Item.Refresh(true)
    m.GetMediaDetails(m.Item)

    if m.AllowLeftRight then
        if m.WrapLeftRight then
            m.Screen.AllowNavLeft(true)
            m.Screen.AllowNavRight(true)
        else
            m.Screen.AllowNavLeft(m.CurIndex > 0)
            m.Screen.AllowNavRight(m.CurIndex < m.Context.Count() - 1)
        end if
    end if

    ' disable right/left for now -- until bug is fixed. Probably a better way to match this - but I don't know of it yet.
    ' We should allow this if the NEXT content type left or right is also a movie.. TODO
    '  ^ but again the user might wonder why it works sometimes and not others.. so maybe better to just keep disabled
    r = CreateObject("roRegex", "library/recentlyAdded", "") ' note: only affect global recentlyAdded ( allows different content types )
    if tostr(m.screenname) = "Preplay movie" and m.metadata.contenttype ="movie"  and r.Match(m.metadata.sourceurl)[0] <> invalid
            Debug("------------ disabled right/left buttons on Recently Added - Preplay screen - and override breadcrumbs")
            m.Screen.AllowNavLeft(false)
            m.Screen.AllowNavRight(false)
            m.screen.SetBreadcrumbText(m.metadata.server.name,"Recently Added")' override breadcrumb to - global recently added, let's show the server
    end if

    ' See if we should switch the poster
    if m.metadata.SDDetailThumb <> invalid then
        ' details Thumb is a "screenshot" preview of the video ( used for episodes )
        m.metadata.SDPosterUrl = m.metadata.SDDetailThumb
        m.metadata.HDPosterUrl = m.metadata.HDDetailThumb
        m.thumbnailsToReset.Push(m.metadata)
    else if m.metadata.SDsbThumb <> invalid then
        ' SDsbThumb is a large (in roku terms) thumb
        ' sometimes we have tiny images depending on the gridStyle we are in
        ' so we should use a large image for the springboard
        m.metadata.SDPosterUrl = m.metadata.SDsbThumb
        m.metadata.HDPosterUrl = m.metadata.HDsbThumb
        ' we will keep using the new (larger) thumbnail on re-entry.
        'm.thumbnailsToReset.Push(m.metadata)
    end if

    m.Screen.setContent(m.metadata)
    m.Screen.AllowUpdates(false)
    m.SetupButtons()
    m.Screen.AllowUpdates(true)
    if m.metadata.SDPosterURL <> invalid and m.metadata.HDPosterURL <> invalid then
        m.Screen.PrefetchPoster(m.metadata.SDPosterURL, m.metadata.HDPosterURL)
        SaveImagesForScreenSaver(m.metadata, ImageSizes(m.metadata.ViewGroup, m.metadata.Type))
    endif

    m.Screen.Show()
End Function

Function TimeDisplay(intervalInSeconds) As String
    hours = fix(intervalInSeconds/(60*60))
    remainder = intervalInSeconds - hours*60*60
    minutes = fix(remainder/60)
    seconds = remainder - minutes*60
    hoursStr = hours.tostr()
    if hoursStr.len() = 1 then
        hoursStr = "0"+hoursStr
    endif
    minsStr = minutes.tostr()
    if minsStr.len() = 1 then
        minsStr = "0"+minsStr
    endif
    secsStr = seconds.tostr()
    if secsStr.len() = 1 then
        secsStr = "0"+secsStr
    endif
    return hoursStr+":"+minsStr+":"+secsStr
End Function

Function sbGotoNextItem() As Boolean
    if NOT m.AllowLeftRight then return false

    ' load all contents (once) if we are coming from a full grid
    if fromFullGrid(true) and m.FullContext = invalid then GetContextFromFullGrid(m)

    Debug("----- GoToNextItem: we have " + tostr(m.Context.Count()) + " items total")

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
        m.Refresh()
        return true
    end if

    return false
End Function

Function sbGotoPrevItem() As Boolean
    if NOT m.AllowLeftRight then return false

    ' load all contents (once) if we are coming from a full grid
    if fromFullGrid(true) and m.FullContext = invalid then GetContextFromFullGrid(m)

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
        m.Refresh()
        return true
    end if

    return false
End Function

Sub sbClearButtons()
    m.buttonCommands = CreateObject("roAssociativeArray")
    m.Screen.ClearButtons()
    m.buttonCount = 0
End Sub

Sub sbAddButton(label, command)
    m.Screen.AddButton(m.buttonCount, label)
    m.buttonCommands[str(m.buttonCount)] = command
    m.buttonCount = m.buttonCount + 1
End Sub

Sub sbAddRatingButton(userRating, rating, command)
    if userRating = invalid then userRating = 0
    if rating = invalid then rating = 0
    m.Screen.AddRatingButton(m.buttonCount, userRating, rating)
    m.buttonCommands[str(m.buttonCount)] = command
    m.buttonCount = m.buttonCount + 1
End Sub
