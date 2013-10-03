'* Rob Reed: Cast and Crew functions
'*
'* uses the SearchDataLoader.brs to:
'*   Loads data for cast id into rows separated by content type. If and 
'*   result returns a reference to another search provider then another
'*   is started for that provider.
'*

' Function to create posterScreen for Actors/Writers/Directors/etc content ( movies, shows, series, seasons, etc)
function RFcreateCastAndCrewScreen(item as object) as Dynamic

    ' overwrite the castcrewlist array we might have set - many times it's imcomplete or empty (PMS is still implementing exposing Cast/Roles for content type)
    ' check if content has a grandparentKey -- if so, we need to get the cast from that ( api for episode/season do not list Roles correctly )
    if item.metadata.grandparentkey <> invalid then 
        item.metadata.castcrewlist = getCastAndCrew(item, item.metadata.grandparentkey)
    else
        item.metadata.castcrewlist = getCastAndCrew(item, invalid)
    end if

    if type(item.metadata.castcrewlist) = "roArray" and item.metadata.castcrewlist.count() > 0 then 
        obj = CreateObject("roAssociativeArray")
        obj = createPosterScreen(item, m.viewcontroller)
        screenName = "Cast & Crew List"
        obj.HandleMessage = RFCastAndCrewHandleMessage ' override default Handler
    

' TO REMOVE
' server = obj.item.metadata.server
' library section no longer needed
'        Debug("------ requesting metadata to get required librarySection " + server.serverUrl + obj.item.metadata.key)
'        container = createPlexContainerForUrl(server, server.serverUrl, obj.item.metadata.key)
    
'        if container <> invalid then
'            obj.librarySection = container.xml@librarySectionID
'            obj.screen.SetContentList(getPostersForCastCrew(item,obj.librarySection))
' END REMOVE

        obj.screen.SetContentList(getPostersForCastCrew(item)
        obj.ScreenName = screenName
    
        breadcrumbs = ["The Cast & Crew", firstof(item.metadata.cleantitle, item.metadata.umtitle, item.metadata.title)]
        m.viewcontroller.AddBreadcrumbs(obj, breadcrumbs)
        m.viewcontroller.UpdateScreenProperties(obj)
        m.viewcontroller.PushScreen(obj)

    else 
        ' Give EU a message that we couldn't find any cast members for the content ( probably not scraped yet )
        ShowErrorDialog("Could not find any Cast or Crew memebers", firstof(item.metadata.cleantitle, item.metadata.umtitle, item.metadata.title))
        return invalid
    end if
    return obj.screen
end function

Function RFCastAndCrewHandleMessage(msg) As Boolean
    obj = m.viewcontroller.screens.peek()
    handled = false

    if type(msg) = "roPosterScreenEvent" then
        handled = true
        'print "showPosterScreen | msg = "; msg.GetMessage() " | index = "; msg.GetIndex()
        if msg.isListItemSelected() then
            cast = obj.item.metadata.castcrewlist[msg.GetIndex()]
            ' create the gridScreen for the cast member ( uses a modified search loader )
            if cast.id <> invalid and cast.name <> invalid then 
                screen = createGridScreen(m.viewcontroller, "flat-square") ' flat-movie - larger?
                screen.Loader = createSearchLoader("invalid",cast) ' including the cast array - causes search loader to function differently
                screen.Loader.Listener = screen
                breadcrumbs = [cast.itemtype,cast.name]
                screen.ScreenName = "Cast and Crew"
                m.viewcontroller.AddBreadcrumbs(screen, breadcrumbs)
                m.viewcontroller.UpdateScreenProperties(screen)
                m.viewcontroller.PushScreen(screen)
                screen.Show()
            else
                Debug("Cast name and id are not set for " +  tostr(cast.name) + ":" + tostr(obj.item.metadata.key))
            end if
        else if msg.isScreenClosed() then
            handled = true
            m.ViewController.PopScreen(obj)
        end if
    end If

 return handled
End Function

' Load the Cast and Crew list for given item - probably need better checks for what type of content it is
function getCastAndCrew(item as object, key = invalid) as object
    CastCrewList   = []

    if key = invalid then key = item.metadata.key ' let us override the key, otherwise, use the item.metadata.key

    container = createPlexContainerForUrl(item.metadata.server, item.metadata.server.serverUrl, key)        
    if container.xml.Video[0] <> invalid then 
        castxml = container.xml.Video[0]
    else if container.xml.Directory[0] <> invalid  then
       castxml = container.xml.Directory[0]
    end if

    if type(castxml) = "roXMLElement" then 
        default_img = "/:/resources/actor-icon.png"
        sizes = ImageSizes("movie", "movie")
    
        SDThumb = item.metadata.server.TranscodedImage(item.metadata.server.serverurl, default_img, sizes.sdWidth, sizes.sdHeight)
        HDThumb = item.metadata.server.TranscodedImage(item.metadata.server.serverurl, default_img, sizes.hdWidth, sizes.hdHeight)
        if item.metadata.server.AccessToken <> invalid then
            SDThumb = SDThumb + "&X-Plex-Token=" + item.metadata.server.AccessToken
            HDThumb = HDThumb + "&X-Plex-Token=" + item.metadata.server.AccessToken
        end if

        for each Actor in castxml.Role
            CastCrewList.Push({ name: Actor@tag, id: Actor@id, role: Actor@role, imageHD: HDThumb, imageSD: SDThumb, itemtype: "Actor" })
        next
    
        for each Director in castxml.Director
            CastCrewList.Push({ name: Director@tag, id: Director@id, imageHD: HDThumb, imageSD: SDThumb, itemtype: "Director" })
        next
    
        for each Producer in castxml.Producer
            CastCrewList.Push({ name: Producer@tag, id: Producer@id, imageHD: HDThumb, imageSD: SDThumb, itemtype: "producer" })
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
        wkey = "/lsibrary/people/"+i.id+"/media"
        ' it would be nice if we could just get a full list of people from ther server, but not available - maybe later TODO
        container = createPlexContainerForUrl(server, server.serverurl, "/search/actor/?query=" + HttpEncode(i.name))
        keys = container.GetKeys()

        for index = 0 to keys.Count() - 1
            found = false
            if keys[index] = wkey then 
                 found = true
                 if container.xml.Directory[index]@thumb <> invalid then 
                    default_img = container.xml.Directory[index]@thumb
                    i.imageSD = server.TranscodedImage(server.serverurl, default_img, sizes.sdWidth, sizes.sdHeight)
                    i.imageHD = server.TranscodedImage(server.serverurl, default_img, sizes.hdWidth, sizes.hdHeight)
                    if server.AccessToken <> invalid then 
                        i.imageSD = i.imageSD + "&X-Plex-Token=" + server.AccessToken
                        i.imageHD = i.imageHD + "&X-Plex-Token=" + server.AccessToken
                    end if
                end if
                exit for
            end if

            ' this is probably not needed -- but it might be useful for other characters than actors
            if NOT found then
                names = container.GetNames()
                if names[index] = i.name then 
                     found = true
                     if container.xml.Directory[index]@thumb <> invalid then 
                        default_img = container.xml.Directory[index]@thumb
                        i.imageSD = server.TranscodedImage(server.serverurl, default_img, sizes.sdWidth, sizes.sdHeight)
                        i.imageHD = server.TranscodedImage(server.serverurl, default_img, sizes.hdWidth, sizes.hdHeight)
                        if server.AccessToken <> invalid then 
                            i.imageSD = i.imageSD + "&X-Plex-Token=" + server.AccessToken
                            i.imageHD = i.imageHD + "&X-Plex-Token=" + server.AccessToken
                        end if
                    end if
                    exit for
                end if
            end if
        end for

        values = {
            ShortDescriptionLine1:i.name,
            ShortDescriptionLine2: i.itemtype,
            SDPosterUrl:i.imageSD,
            HDPosterUrl:i.imageHD,
            itemtype: lcase(i.itemtype),
            }
        list.Push(values)        

    next
    return list
End Function
