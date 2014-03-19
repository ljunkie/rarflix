'* Rob Reed: Cast and Crew functions
'*
'* uses the SearchDataLoader.brs

' Function to create posterScreen for Actors/Writers/Directors/etc content ( movies, shows, series, seasons, etc)
function RFcreateCastAndCrewScreen(item as object) as Dynamic
    ' check if content has a grandparentKey -- if so, we need to get the cast
    ' from that ( api for episode/season do not list Roles correctly )
    if item.metadata.grandparentkey <> invalid then
        Debug(tostr(item.metadata.type) + " not supported " + item.metadata.key + " -- using the grandParentkey" + tostr(item.metadata.grandparentkey))
        item.metadata.castcrewlist = getCastAndCrew(item, item.metadata.grandparentkey)
    else
        Debug(tostr(item.metadata.type) + " is supported -- using the key" + tostr(item.metadata.key))
        item.metadata.castcrewlist = getCastAndCrew(item, invalid)
    end if

    if type(item.metadata.castcrewlist) = "roArray" and item.metadata.castcrewlist.count() > 0 then
        screen = createPosterScreen(item, m.viewcontroller, "arced-portrait")
        screen.show = showCastAndCrewScreen
        screen.noRefresh = true
        screen.HandleMessage = RFCastAndCrewHandleMessage ' override default Handler
        screen.ScreenName = "Cast & Crew List"
        screen.screen.SetContentList(getPostersForCastCrew(item))

        breadcrumbs = ["The Cast & Crew", firstof(item.metadata.cleantitle, item.metadata.umtitle, item.metadata.title)]
        m.viewcontroller.InitializeOtherScreen(screen, breadcrumbs)
    else
        ' Give EU a message that we couldn't find any cast members for the content ( probably not scraped yet )
        ShowErrorDialog("Could not find any Cast or Crew memebers", firstof(item.metadata.cleantitle, item.metadata.umtitle, item.metadata.title))
        return invalid
    end if

    return screen
end function

sub showCastAndCrewScreen()
    m.screen.show()
end sub

Function RFCastAndCrewHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roPosterScreenEvent" then
        handled = true
        if msg.isListItemSelected() then
            cast = m.item.metadata.castcrewlist[msg.GetIndex()]
            cast.server = m.item.metadata.server
            ' create the gridScreen for the cast member ( uses a modified search loader )
            if cast.id <> invalid and cast.name <> invalid then
                displaymode_grid = RegRead("rf_grid_displaymode", "preferences", "photo-fit")
                grid_style = RegRead("rf_grid_style", "preferences","flat-portrait")
                screen = createGridScreen(m.viewcontroller, grid_style, invalid, displaymode_grid)
                screen.Loader = createSearchLoader("invalid",cast) ' including the cast array - causes search loader to function differently
                screen.Loader.Listener = screen
                breadcrumbs = [cast.itemtype,cast.name]
                screen.ScreenName = "Cast and Crew"
                screen.disableFullGrid = true
                m.viewcontroller.InitializeOtherScreen(screen, breadcrumbs)
                screen.Show()
            else
                Debug("Cast name and id are not set for " +  tostr(cast.name) + ":" + tostr(m.item.metadata.key))
            end if
        else if ((msg.isRemoteKeyPressed() AND msg.GetIndex() = 10) OR msg.isButtonInfo()) then ' ljunkie - use * for more options on focused item
            rfBasicDialog(m)
        else if msg.isScreenClosed() then
            handled = true
            m.ViewController.PopScreen(m)
        end if
    end If

 return handled
End Function

' Load the Cast and Crew list for given item - probably need better checks for what type of content it is
function getCastAndCrew(item as object, key = invalid) as object
    CastCrewList   = []

    if key = invalid then key = item.metadata.key ' let us override the key, otherwise, use the item.metadata.key

    container = createPlexContainerForUrl(item.metadata.server, item.metadata.server.serverUrl, key)
    ' we haven't Parsed anything yet.. the raw XML is available
    if container <> invalid and container.xml <> invalid and container.xml.Video <> invalid then
        if container.xml.Video[0] <> invalid then
            castxml = container.xml.Video[0]
        else if container.xml.Directory[0] <> invalid  then
            castxml = container.xml.Directory[0]
        end if
    end if
    container = invalid

    if type(castxml) = "roXMLElement" then
        default_img = "/:/resources/actor-icon.png"
        sizes = ImageSizes("movie", "movie")

        SDThumb = item.metadata.server.TranscodedImage(item.metadata.server.serverurl, default_img, sizes.sdWidth, sizes.sdHeight)
        HDThumb = item.metadata.server.TranscodedImage(item.metadata.server.serverurl, default_img, sizes.hdWidth, sizes.hdHeight)

        for each Actor in castxml.Role
            CastCrewList.Push({ name: Actor@tag, id: Actor@id, role: Actor@role, imageHD: HDThumb, imageSD: SDThumb, itemtype: "Actor" })
        next

        for each Director in castxml.Director
            CastCrewList.Push({ name: Director@tag, id: Director@id, imageHD: HDThumb, imageSD: SDThumb, itemtype: "Director" })
        next

        for each Producer in castxml.Producer
            CastCrewList.Push({ name: Producer@tag, id: Producer@id, imageHD: HDThumb, imageSD: SDThumb, itemtype: "Producer" })
        next

        for each Writer in castxml.Writer
            CastCrewList.Push({ name: Writer@tag, id: Writer@id, imageHD: HDThumb, imageSD: SDThumb, itemtype: "Writer" })
        next
    end if
    return CastCrewList
end function

Function getPostersForCastCrew(item As Object) As Object
    server = item.metadata.server ' we only need to query the specific server since this item exists on it

    ' TODO find a better way to get all PEOPLES thumbs
    ' current issue - Producers/Writer ID's are not available yet unless we are in the context of a video

    list = []
    sizes = ImageSizes("movie", "movie")

    for each i in item.metadata.castcrewList
        wkey = "/library/people/"+i.id+"/media"
        ' it would be nice if we could just get a full list of people from ther server, but not available - maybe later TODO
        container = createPlexContainerForUrl(server, server.serverurl, "/search/actor/?query=" + HttpEncode(i.name))
        ' we haven't Parsed anything yet.. the raw XML is available
        xml = container.xml
        keys = container.GetKeys()
        names = container.GetNames()
        container = invalid
        for index = 0 to keys.Count() - 1
            found = false
            if keys[index] = wkey then
                found = true
                if xml.Directory[index]@thumb <> invalid then
                    default_img = xml.Directory[index]@thumb
                    i.imageSD = server.TranscodedImage(server.serverurl, default_img, sizes.sdWidth, sizes.sdHeight)
                    i.imageHD = server.TranscodedImage(server.serverurl, default_img, sizes.hdWidth, sizes.hdHeight)
                end if
                exit for
            end if

            ' this is probably not needed -- but it might be useful for other characters than actors
            if NOT found then
                if names[index] = i.name then
                    found = true
                    if xml.Directory[index]@thumb <> invalid then
                        default_img = xml.Directory[index]@thumb
                        i.imageSD = server.TranscodedImage(server.serverurl, default_img, sizes.sdWidth, sizes.sdHeight)
                        i.imageHD = server.TranscodedImage(server.serverurl, default_img, sizes.hdWidth, sizes.hdHeight)
                    end if
                    exit for
                end if
            end if
        end for

        ' Lets set the second line to the cast member type
        ' If the cast member has a Role attribute, then we will
        ' override the cast member type with the Role
        ' - sometimes the Role name is also the cast members name ( exclude those )
    	DescriptionLine2 = i.itemtype
        if i.role <> invalid and i.role <> "" and i.role <> i.name then DescriptionLine2 = i.role

        values = {
            ShortDescriptionLine1:i.name,
            ShortDescriptionLine2: DescriptionLine2,
            SDPosterUrl:i.imageSD,
            HDPosterUrl:i.imageHD,
            itemtype: lcase(i.itemtype),
            }
        list.Push(values)

    next

    xml = invalid
    return list
End Function
