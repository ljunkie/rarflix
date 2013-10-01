' other functions required for my mods
Sub InitRARFlix() 
    'RegDelete("rf_unwatched_limit", "preferences")
    'RegDelete("rf_user_rating_only", "preferences")
 
    RegRead("rf_bcdynamic", "preferences","enabled")
    RegRead("rf_rottentomatoes", "preferences","enabled")
    RegRead("rf_rottentomatoes_score", "preferences","audience")
    RegRead("rf_trailers", "preferences","enabled")
    RegRead("rf_tvwatch", "preferences","enabled")
    RegRead("rf_searchtitle", "preferences","title")
    RegRead("rf_rowfilter_limit", "preferences","200") ' no toggle yet
    RegRead("rf_hs_clock", "preferences", "enabled")
    RegRead("rf_focus_unwatched", "preferences", "enabled")
    RegRead("rf_user_rating_only", "preferences", "user_prefer") ' this will show the original star rating as the users if it exists. seems safe to set at first
    RegRead("rf_up_behavior", "preferences", "exit") ' default is exit screen ( except for home )

    ' ljunkie Youtube Trailers (extended to TMDB)
    m.youtube = InitYouTube()

    Debug("=======================RARFLIX SETTINGS ====================================")
    Debug("rf_bcdynamic: " + tostr(RegRead("rf_bcdynamic", "preferences")))
    Debug("rf_hs_clock: " + tostr(RegRead("rf_hs_clock", "preferences")))
    Debug("rf_rottentomatoes: " + tostr(RegRead("rf_rottentomatoes", "preferences")))
    Debug("rf_rottentomatoes_score: " + tostr(RegRead("rf_rottentomatoes_score", "preferences")))
    Debug("rf_trailers: " + tostr(RegRead("rf_trailers", "preferences")))
    Debug("rf_tvwatch: " + tostr(RegRead("rf_tvwatch", "preferences")))
    Debug("rf_searchtitle: " + tostr(RegRead("rf_searchtitle", "preferences")))
    Debug("rf_rowfilter_limit: " + tostr(RegRead("rf_rowfilter_limit", "preferences")))
    Debug("rf_focus_unwatched: " + tostr(RegRead("rf_focus_unwatched", "preferences")))
    Debug("rf_user_rating_only: " + tostr(RegRead("rf_user_rating_only", "preferences")))
    Debug("rf_up_behavior: " + tostr(RegRead("rf_up_behavior", "preferences")))
    Debug("============================================================================")

end sub


Function GetDurationString( Seconds As Dynamic, emptyHr = 0 As Integer, emptyMin = 0 As Integer, emptySec = 0 As Integer  ) As String
   datetime = CreateObject( "roDateTime" )

   if (type(Seconds) = "roString") then
       TotalSeconds% = Seconds.toint()
   else if (type(Seconds) = "roInteger") or (type(Seconds) = "Integer") then
       TotalSeconds% = Seconds
   else
       return "Unknown"
   end if

   datetime.FromSeconds( TotalSeconds% )
      
   hours = datetime.GetHours().ToStr()
   minutes = datetime.GetMinutes().ToStr()
   seconds = datetime.GetSeconds().ToStr()
   
   duration = ""
   If hours <> "0" or emptyHr = 1 Then
      duration = duration + hours + "h "
   End If

   If minutes <> "0" or emptyMin = 1 Then
      duration = duration + minutes + "m "
   End If
   If seconds <> "0" or emptySec = 1 Then
      duration = duration + seconds + "s"
   End If
   
   Return duration
End Function

Function RRmktime( epoch As Integer, localize = 1 as Integer) As String
    datetime = CreateObject("roDateTime")
    datetime.FromSeconds(epoch)
    if localize = 1 then 
        datetime.ToLocalTime()
    end if
    hours = datetime.GetHours()
    minutes = datetime.GetMinutes()
    seconds = datetime.GetSeconds()
       
    duration = ""
    hour = hours
    If hours = 0 Then
       hour = 12
    End If

    If hours > 12 Then
        hour = hours-12
    End If

    If hours >= 0 and hours < 12 Then
        AMPM = "am"
    else
        AMPM = "pm"
    End if
       
    minute = minutes.ToStr()
    If minutes < 10 Then
      minute = "0" + minutes.ToStr()
    end if

    result = hour.ToStr() + ":" + minute + AMPM

    Return result
End Function

Function RRbitrate( bitrate As Float) As String
    speed = bitrate/1000/1000
    ' brightscript doesn't have sprintf ( only include on decimal place )
    speed = speed * 10
    speed = speed + 0.5
    speed = fix(speed)
    speed = speed / 10
    format = "mbps"
    if speed < 1 then
      speed = speed*1000
      format = "kbps"
    end if
    return tostr(speed) + format
End Function

Function RRbreadcrumbDate(myscreen) As Object
    if RegRead("rf_hs_clock", "preferences", "enabled") = "enabled" then
        screenName = firstOf(myScreen.ScreenName, type(myScreen.Screen))
        if screenName <> invalid and screenName = "Home" then 
            Debug("update " + screenName + " screen time")
            date = CreateObject("roDateTime")
            date.ToLocalTime() ' localizetime
            timeString = RRmktime(date.AsSeconds(),0)
            dateString = date.AsDateString("short-month-short-weekday")
            myscreen.Screen.SetBreadcrumbEnabled(true)
            myscreen.Screen.SetBreadcrumbText(dateString, timeString)
        else 
            Debug("will NOT update " + screenName + " screen time. " + screenName +"=Home")
        end if
    end if
End function

Function createRARFlixPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)
    obj.HandleMessage = prefsRARFflixHandleMessage

    ' Deprecated : part of Hide Rows 
    ' Show 2 new fows for movies (unwatched: recenlty added and recently released )
    '    rf_uw_movie_row_prefs = [
    '        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Recenlty Added (unwatched)" + chr(10) + "Recenlty Released (unwatched)" },
    '        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: "Recenlty Added (unwatched)" + chr(10) + "Recenlty Released (unwatched)" },
    '    ]
    '    obj.Prefs["rf_uw_movie_rows"] = {
    '        values: rf_uw_movie_row_prefs,
    '        heading: "Add unwatched Movie Rows",
    '        default: "enabled"
    '    }


    ' Home Screen clock
    rf_hs_clock_prefs = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Show clock on Home Screen" },
        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: "Show clock on Home Screen" },
    ]
    obj.Prefs["rf_hs_clock"] = {
        values: rf_hs_clock_prefs,
        heading: "Date and Time",
        default: "enabled"
    }

    ' Rotten Tomatoes
    rt_prefs = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Display Ratings from RottenTomatoes" },
        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: "Display Ratings from RottenTomatoes" },
    ]
    obj.Prefs["rf_rottentomatoes"] = {
        values: rt_prefs,
        heading: "Movie Ratings from Critics and Users",
        default: "enabled"
    }

    ' Rotten Tomatoes
    rt_prefs_score = [
        { title: "Critic's", EnumValue: "critic", ShortDescriptionLine2: "Use Critic's Score" },
        { title: "Audience's", EnumValue: "audience", ShortDescriptionLine2: "Use Audience's Score" },
    ]
    obj.Prefs["rf_rottentomatoes_score"] = {
        values: rt_prefs_score,
        heading: "Score to display on the Movie Details Screen",
        default: "audience"
    }

    ' RT/Trailers - search title
    rt_prefs = [
        { title: "Title", EnumValue: "title", ShortDescriptionLine2: "Search by Movie Title" },
        { title: "Original Title", EnumValue: "originalTitle", ShortDescriptionLine2: "Search by Original Movie Title" },
    ]
    obj.Prefs["rf_searchtitle"] = {
        values: rt_prefs,
        heading: "Search by Title or 'Original' Title",
        default: "title"
    }

    ' Trailers
    trailer_prefs = [
        { title: "Enabled TMDB & Youtube", EnumValue: "enabled", ShortDescriptionLine2: "Display Movie Trailers" + chr(10) + "themoviedb.org and Youtube" },
        { title: "Enabled TMDB w/ Youtube Fallback", EnumValue: "enabled_tmdb_ytfb", ShortDescriptionLine2: "Display Movie Trailers" + chr(10) + "themoviedb.org or Fallback to Youtube" },
        { title: "Disabled", EnumValue: "disabled"}

    ]
    obj.Prefs["rf_trailers"] = {
        values: trailer_prefs,
        heading: "Show Movie Trailer button",
        default: "enabled_tmdb_yt"
    }

    ' Breadcrumb fixes
    bc_prefs = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Update header when browsing " +chr(10)+ "On Deck, Recently Added, etc.."  },
        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: "Update header when browsing " +chr(10)+ "On Deck, Recently Added, etc.."  },


    ]
    obj.Prefs["rf_bcdynamic"] = {
        values: bc_prefs,
        heading: "Update Header (top right)",
        default: "enabled"
    }

    ' TV Watched status next to ShowTITLE
    tv_watch_prefs = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Dexter (watched)" + chr(10) + "Dexter (1 of 12 watched)" },
        { title: "Disabled", EnumValue: "disabled" },

    ]
    obj.Prefs["rf_tvwatch"] = {
        values: tv_watch_prefs,
        heading: "Append the watched status to TV Show Titles",
        default: "enabled"
    }

    ' focus to the unwatched item in a postescreen -  maybe others later
    focus_unwatched = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "",}
        { title: "Disabled", EnumValue: "disabled" },

    ]
    obj.Prefs["rf_focus_unwatched"] = {
        values: focus_unwatched,
        heading: "Focus on the first Unwatched item"
        default: "enabled"
    }


    ' user ratings only
    user_ratings = [
        { title: "Only Your Ratings", EnumValue: "user_only", ShortDescriptionLine2: "Display your Star Ratings Only",}
        { title: "Prefer Your Ratings", EnumValue: "user_prefer", ShortDescriptionLine2: "Prefer your Ratings over the Default",}
        { title: "Default", EnumValue: "disabled" },

    ]
    obj.Prefs["rf_user_rating_only"] = {
        values: user_ratings,
        heading: "Only show or Prefer your Star Ratings"
        default: "disabled"
    }

    ' user ratings only
    up_behavior = [
        { title: "Previous Screen", EnumValue: "exit", ShortDescriptionLine2: "Go to the Previous Screen (go back)",}
        { title: "Do Nothing", EnumValue: "stop", ShortDescriptionLine2: "Stay on Screen (do nothing)",}

    ]
    obj.Prefs["rf_up_behavior"] = {
        values: up_behavior,
        heading: "Up Key action when Top Row is Selected",
        default: "exit"
    }


    filter_limit = [
        { title: "100", EnumValue: "100" },
        { title: "200", EnumValue: "200" },
        { title: "300", EnumValue: "300", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "400", EnumValue: "400", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "500", EnumValue: "500", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "600", EnumValue: "600", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "700", EnumValue: "700", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "800", EnumValue: "800", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "900", EnumValue: "900", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "1000", EnumValue: "1000", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "1500", EnumValue: "1500", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "All", EnumValue: "9999", ShortDescriptionLine2: "May cause Plex to be Sluggish.. really?"},
    ]
    obj.Prefs["rf_rowfilter_limit"] = {
        values: filter_limit,
        heading: "Item limit for Unwatched Recently Added & Released [movies]",
        default: "200"
    }


    obj.Screen.SetHeader("RARFlix Preferences")

    obj.AddItem({title: "Hide Rows",ShortDescriptionLine2: "Sorry for the confusion..."}, "hide_rows_prefs")
    obj.AddItem({title: "Section Display", ShortDescriptionLine2: "a plex original, for easy access"}, "sections")

    obj.AddItem({title: "Movie Trailers", ShortDescriptionLine2: "Got Trailers?"}, "rf_trailers", obj.GetEnumValue("rf_trailers"))
    obj.AddItem({title: "Rotten Tomatoes", ShortDescriptionLine2: "Movie Ratings from Rotten Tomatoes"}, "rf_rottentomatoes", obj.GetEnumValue("rf_rottentomatoes"))
    obj.AddItem({title: "Rotten Tomatoes Score", ShortDescriptionLine2: "Who do you trust more..." + chr(10) + "A Critic or an Audience?"}, "rf_rottentomatoes_score", obj.GetEnumValue("rf_rottentomatoes_score"))
    obj.AddItem({title: "Trailers/Tomatoes Search by", ShortDescriptionLine2: "You probably don't want to change this"}, "rf_searchtitle", obj.GetEnumValue("rf_searchtitle"))
    obj.AddItem({title: "Dynamic Headers", ShortDescriptionLine2: "Info on the top Right of the Screen"}, "rf_bcdynamic", obj.GetEnumValue("rf_bcdynamic"))
    obj.AddItem({title: "TV Show (Watched Status)", ShortDescriptionLine2: "feels good enabled"}, "rf_tvwatch", obj.GetEnumValue("rf_tvwatch"))
    obj.AddItem({title: "Focus on Unwatched", ShortDescriptionLine2: "Default to the first unwatched item"}, "rf_focus_unwatched", obj.GetEnumValue("rf_focus_unwatched"))
    obj.AddItem({title: "Clock on Home Screen"}, "rf_hs_clock", obj.GetEnumValue("rf_hs_clock"))
    obj.AddItem({title: "Unwatched Added/Released", ShortDescriptionLine2: "Item limit for unwatched Recently Added &" + chr(10) +"Recently Released rows [movies]"}, "rf_rowfilter_limit", obj.GetEnumValue("rf_rowfilter_limit"))
    obj.AddItem({title: "Star Ratings Override", ShortDescriptionLine2: "Only show or Prefer"+chr(10)+"Star Ratings that you have set"}, "rf_user_rating_only", obj.GetEnumValue("rf_user_rating_only"))
    obj.AddItem({title: "Up Button (row screens)", ShortDescriptionLine2: "What to do when the UP button is " + chr(10) + "pressed on a screen with rows"}, "rf_up_behavior", obj.GetEnumValue("rf_up_behavior"))
    ' now part of the Hide Rows
    ' obj.AddItem({title: "Unwatched Movie Rows"}, "rf_uw_movie_rows", obj.GetEnumValue("rf_uw_movie_rows"))

    obj.AddItem({title: "Close"}, "close")
    return obj
End Function

Function prefsRARFflixHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
            m.ViewController.Home.Refresh(m.Changes) ' include the Changes for homescreen refresh ( might be useful to add this to the main ALL *HandleMessages functions )
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "hide_rows_prefs" then
                screen = createHideRowsPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Hide Rows Preferences"])
                screen.Show()
            else if command = "sections" then
                screen = createSectionDisplayPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Section Display Preferences"])
                screen.Show()
            else if command = "close" then
                m.Screen.Close()
            else
                m.HandleEnumPreference(command, msg.GetIndex())
            end if
        end if
    end if

    return handled
End Function

Function createHideRowsPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)
    obj.HandleMessage = prefsRARFflixHandleMessage

    'a little cleaner: if Plex adds/changes rows it will be in PreferenceScreen.brs:createSectionDisplayPrefsScreen()
    PlexRows = [
        { title: "All Items", key: "all" },
        { title: "On Deck", key: "onDeck" },
        { title: "Recently Added", key: "recentlyAdded" },
        { title: "Recently Released", key: "newest" },
        { title: "Unwatched", key: "unwatched" },
        { title: "[movie] Recently Added (uw)", key: "all?type=1&unwatched=1&sort=addedAt:desc" }, 'movie/film for now
        { title: "[movie] Recently Released (uw)", key: "all?type=1&unwatched=1&sort=originallyAvailableAt:desc" }, 'movie/film for now
        { title: "Recently Viewed", key: "recentlyViewed" },
        { title: "[tv] Recently Viewed Shows", key: "recentlyViewedShows" },
        { title: "By Album", key: "albums" },
        { title: "By Collection", key: "collection" },
        { title: "By Genre", key: "genre" },
        { title: "By Year", key: "year" },
        { title: "By Decade", key: "decade" },
        { title: "By Director", key: "director" },
        { title: "By Actor", key: "actor" },
        { title: "By Country", key: "country" },
        { title: "By Content Rating", key: "contentRating" },
        { title: "By Rating", key: "rating" },
        { title: "By Resolution", key: "resolution" },
        { title: "By First Letter", key: "firstCharacter" },
        { title: "By Folder", key: "folder" },
        { title: "Search", key: "_search_" }
    ]
    obj.Screen.SetHeader("Hide or Show Rows for Library Sections")

    ReorderItemsByKeyPriority(PlexRows, RegRead("section_row_order", "preferences", ""))

    for each item in PlexRows
        if item.key = "_search_" then item.key = "search" 'special case
        rf_hide_key = "rf_hide_"+item.key

        ' allow one to Hide Recently Released and Recently Added if Movie/Show/Music - would really be nice to reorder per section.. but that's another time (TODO)
        if item.key = "newest" or item.key = "recentlyAdded" then 
            itypes = [
                { type: "movie", short: "[movie]", },
                { type: "artist", short: "[music]", },
                { type: "show", short: "[tv]", newest: "Recently Aired" },
            ]

            for each it in itypes
                new_hide_key = rf_hide_key + "_" + it.type
                title = it.short + " " + item.title
                if it[item.key] <> invalid then title = it.short + " " + it[item.key]

                values = [
                    { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: title },
                    { title: "Show", EnumValue: "show", ShortDescriptionLine2: title },
                ]
                obj.Prefs[new_hide_key] = {
                    values: values,
                    heading: "Show or Hide Row",
                    default: "show"
                }
                if (it.type = "artist" and item.key <> "newest") or ( it.type <> "artist")   then
                    obj.AddItem({title: title}, new_hide_key, obj.GetEnumValue(new_hide_key))
                end if
            end for
        end if ' else  -- allow other sections to hide recenltyAdded/released normally

        if item.key = "recentlyAdded" then item.title = "[other] Recently Added"
        if item.key = "newest" then item.title = "[other] Recently Released"
        values = [
            { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: item.title },
            { title: "Show", EnumValue: "show", ShortDescriptionLine2: item.title },
        ]
        obj.Prefs[rf_hide_key] = {
            values: values,
            heading: "Show or Hide Row",
            default: "show"
        }
        if NOT item.key = "newest" then ' others don't have this yet
            obj.AddItem({title: item.title}, rf_hide_key, obj.GetEnumValue(rf_hide_key))
        end if
    next
   
    obj.AddItem({title: "Close"}, "close")
    return obj
End Function


' Function to create screen for Actors/Writers/Directors/etc for a given Movie Title
function RFcreateCastAndCrewScreen(item as object) as Dynamic
    obj = CreateObject("roAssociativeArray")
    obj = createPosterScreen(item, m.viewcontroller)
    screenName = "Cast & Crew List"
    obj.HandleMessage = RFCastAndCrewHandleMessage ' override default Handler

    server = obj.item.metadata.server
    Debug("------ requesting metadata to get required librarySection " + server.serverUrl + obj.item.metadata.key)
    container = createPlexContainerForUrl(server, server.serverUrl, obj.item.metadata.key)

    if container <> invalid then
        obj.librarySection = container.xml@librarySectionID
        obj.screen.SetContentList(getPostersForCastCrew(item,obj.librarySection))
        obj.ScreenName = screenName

        breadcrumbs = ["The Cast & Crew", firstof(item.metadata.umtitle, item.metadata.title)]
        m.viewcontroller.AddBreadcrumbs(obj, breadcrumbs)
        m.viewcontroller.UpdateScreenProperties(obj)
        m.viewcontroller.PushScreen(obj)
    else
        Debug("FAIL: unexpected error in RFshowCastAndCrewScreen")
        return -1
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
            'print "list item selected | current show = "; msg.GetIndex() 
            RFcreateItemsForCastCrewScreen(obj,msg.GetIndex())
        else if msg.isScreenClosed() then
            handled = true
            m.ViewController.PopScreen(obj)
        end if
    end If

 return handled
End Function

Function getPostersForCastCrew(item As Object, librarySection as string) As Object
    server = item.metadata.server
  
    ' current issue - Producers/Writer ID's are not available yet unless we are in the context of a video
    ' I had a hack below to set the id name match, but that only works for actors/directors since those urls are available
    ' so we have to be lame and just grant the metadata again... same idea as VideoMetaData.brs:setVideoDetails
    container = createPlexContainerForUrl(item.metadata.server, item.metadata.server.serverUrl, item.metadata.key)        
    castxml = container.xml.Video[0]
    'stop

    default_img = "/:/resources/actor-icon.png"
    sizes = ImageSizes("movie", "movie")

    SDThumb = item.metadata.server.TranscodedImage(item.metadata.server.serverurl, default_img, sizes.sdWidth, sizes.sdHeight)
    HDThumb = item.metadata.server.TranscodedImage(item.metadata.server.serverurl, default_img, sizes.hdWidth, sizes.hdHeight)
    if item.metadata.server.AccessToken <> invalid then
        SDThumb = SDThumb + "&X-Plex-Token=" + item.metadata.server.AccessToken
        HDThumb = HDThumb + "&X-Plex-Token=" + item.metadata.server.AccessToken
    end if

    CastCrewList   = []
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

    item.metadata.castcrewList = CastCrewList ' lets override it now that we have valid metadata for cast members

    ' we can modify this if PMS ever keeps images for other cast & crew members. Actors only for now: http://10.69.1.12:32400/library/sections/6/actor
    Debug("------ requesting FULL list of actors to supply images " + server.serverurl + "/library/sections/" + librarySection + "/actor")
    container_a = createPlexContainerForUrl(server, server.serverurl, "/library/sections/" + librarySection + "/actor")
    a_names = container_a.GetNames()
    a_keys = container_a.GetKeys()

    ' we will enable this again if Directors ever get thumbs..
    'Debug("------ requesting FULL list of actors to supply images " + server.serverurl + "/library/sections/" + librarySection + "/director")
    'container_d = createPlexContainerForUrl(server, server.serverurl, "/library/sections/" + librarySection + "/director")
    'd_names = container_d.GetNames()
    'd_keys = container_d.GetKeys()

    list = []
    sizes = ImageSizes("movie", "movie")

    for each i in item.metadata.castcrewList
        found = false
        for index = 0 to a_keys.Count() - 1
            if lcase(i.itemtype) = "actor" then  ' yea, only use the actors container if the item type is an actor
                ' sometimes the @id is not supplied in the PMS xml api -- so we will force it
                if i.id = invalid and a_names[index] = i.name then 
                  Debug("---- no cast.id from XML - forcing actor key to " + i.name + " to " + a_keys[index])
                  i.id = a_keys[index]
                end if
                if a_keys[index] = i.id then 
                    found = true
                    if container_a.xml.Directory[index]@thumb <> invalid then 
                        default_img = container_a.xml.Directory[index]@thumb
                        i.imageSD = server.TranscodedImage(server.serverurl, default_img, sizes.sdWidth, sizes.sdHeight)
                        i.imageHD = server.TranscodedImage(server.serverurl, default_img, sizes.hdWidth, sizes.hdHeight)
                        if server.AccessToken <> invalid then 
                            i.imageSD = i.imageSD + "&X-Plex-Token=" + server.AccessToken
                            i.imageHD = i.imageHD + "&X-Plex-Token=" + server.AccessToken
                        end if
                    end if
                    exit for
                end if
            else
                ' we will try and use the actor poster if the name matches
                if a_names[index] = i.name then 
                    Debug("---- non actor NAME match -- lets use thumb " + i.name + " to " + a_keys[index])
                    if container_a.xml.Directory[index]@thumb <> invalid then 
                        default_img = container_a.xml.Directory[index]@thumb
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

        ' Enable this if Directors ever get thumbs -- and remove the routine above using the actors image if the names match
        '        if NOT found then 
        '            for index = 0 to d_keys.Count() - 1
        '                ' sometimes the @id is not supplied in the PMS xml api -- so we will force it
        '                if i.id = invalid and d_names[index] = i.name then 
        '                  Debug("---- no cast.id from XML - forcing actor key to " + i.name + " to " + d_keys[index])
        '                  i.id = d_keys[index]
        '                end if
        '                if d_keys[index] = i.id then 
        '                    found = true
        '                    if container_d.xml.Directory[index]@thumb <> invalid then  ' these dont exist yet.. but maybe someday?
        '                        default_img = container_d.xml.Directory[index]@thumb
        '                        i.imageSD = server.TranscodedImage(server.serverurl, default_img, sizes.sdWidth, sizes.sdHeight)
        '                        i.imageHD = server.TranscodedImage(server.serverurl, default_img, sizes.hdWidth, sizes.hdHeight)
        '                        if server.AccessToken <> invalid then 
        '                            i.imageSD = i.imageSD + "&X-Plex-Token=" + server.AccessToken
        '                            i.imageHD = i.imageHD + "&X-Plex-Token=" + server.AccessToken
        '                        end if
        '                    end if
        '                    exit for
        '                end if
        '            end for
        '        end if

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

' Screen show show Movies with Actor/Director/Writer/etc.. 
Function RFcreateItemsForCastCrewScreen(obj as Object, idx as integer) As Integer
    cast = obj.item.metadata.castcrewlist[idx]
    server = obj.item.metadata.server
    librarySection = obj.librarySection
    if librarySection <> invalid and cast.id <> invalid then 
        dummyItem = CreateObject("roAssociativeArray")
        if lcase(cast.itemtype) = "writer" or lcase(cast.itemtype) = "producer" then ' writer and producer are not listed secondaries ( must use filter - hack in PlexMediaServer.brs:FullUrl function )
            dummyItem.sourceUrl = server.serverurl + "/library/sections/" + librarySection + "/all"
            dummyItem.key = "filter?type=1&" + lcase(cast.itemtype) + "=" + cast.id + "&X-Plex-Container-Start=0" ' prepend "filter" to the key, is the key to the hack
        else
            dummyItem.sourceUrl = server.serverurl + "/library/sections/" + librarySection + "/" + lcase(cast.itemtype) + "/" + cast.id
            dummyItem.key = ""
        end if
	Debug("------ item sourceurl+key " + dummyItem.sourceUrl + dummyItem.key)

        Debug("------ requesting metadata to get required librarySection " + server.serverUrl + "library/sections/" + librarySection)
        container = createPlexContainerForUrl(server, server.serverUrl, "library/sections/" + librarySection)        
        bctype1 = "Content"
        if container.xml@title1 <> invalid then bctype1 = container.xml@title1 

        if cast.itemtype = "writer" then
            bctype2 = "Written by"
        else if cast.itemtype = "producer" then 
            bctype2 = "Produced by"
        else if cast.itemtype = "director" then 
            bctype2 = "Directed by"
        else
            bctype2 = "with"
        end if
        
        breadcrumbs = [server.name,bctype1 + " " + bctype2 + " " + cast.name]
        dummyItem.server = server
        dummyItem.viewGroup = "secondary"
        Debug( "----- trying to get movies for cast member: " + cast.name + ":" + lcase(cast.itemtype) + " @ " + dummyItem.sourceUrl)
        m.ViewController.CreateScreenForItem(dummyItem, invalid, breadcrumbs)
        else
            Debug("cannot link cast member to item; cast.id:" + tostr(cast.id) + " librarySection:" + librarySection)
        end if
    return 1
End Function


Function ShowPleaseWait(title As dynamic, text As dynamic) As Object
    if not isstr(title) title = ""
    if not isstr(text) text = ""

    port = CreateObject("roMessagePort")
    dialog = invalid

    'the OneLineDialog renders a single line of text better
    'than the MessageDialog.

    if text = ""
        dialog = CreateObject("roOneLineDialog")
    else
        dialog = CreateObject("roMessageDialog")
        dialog.SetText(text)
    end if

    dialog.SetMessagePort(port)
    dialog.SetTitle(title)
    dialog.ShowBusyAnimation()
    dialog.Show()
    return dialog
End Function



sub rfVideoMoreButton(obj as Object) as Dynamic
    dialog = createBaseDialog()
    dialog.Title = firstof(obj.metadata.showtitle, obj.metadata.umtitle, obj.metadata.title)
    dialog.Text = truncateString(obj.metadata.shortdescriptionline2,220)
    dialog.Item = obj.metadata
    'if obj.metadata.grandparentKey = invalid then
    if obj.metadata.ContentType = "movie"  then
        dialog.SetButton("options", "Playback options")
    end if

    ' display View All Seasons if we have grandparentKey -- entered from a episode
    if obj.metadata.grandparentKey <> invalid then ' global on deck does not work with this
    'if obj.metadata.ContentType = "show" or obj.metadata.ContentType = "episode"  then
        dialog.SetButton("showFromEpisode", "View All Seasons of " + obj.metadata.ShowTitle )
    end if
    ' display View specific season if we have parentKey/parentIndex -- entered from a episode
    if obj.metadata.parentKey <> invalid AND obj.metadata.parentIndex <> invalid then  ' global on deck does not work with this
    'if obj.metadata.ContentType = "show" or obj.metadata.ContentType = "episode"  then
       dialog.SetButton("seasonFromEpisode", "View Season " + obj.metadata.parentIndex)
    end if

    ' if obj.metadata.ContentType = "movie"  or obj.metadata.ContentType = "show"  or obj.metadata.ContentType = "episode"  then
    if obj.metadata.ContentType = "movie" then ' TODO - try and make this work with TV shows ( seems it only works for episodes -- but not well ) 
        dialog.SetButton("RFCastAndCrewList", "Cast & Crew")
    end if

    ' Trailers link - RR (last now that we include it on the main screen .. well before delete - people my be used to delete being second to last)
    'if obj.metadata.grandparentKey = invalid then
    if obj.metadata.ContentType = "movie" AND  RegRead("rf_trailers", "preferences", "disabled") <> "disabled" then 
        dialog.SetButton("getTrailers", "Trailer")
    end if

    supportedIdentifier = (obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" OR obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex")
    if supportedIdentifier then
        if obj.metadata.viewOffset <> invalid AND val(obj.metadata.viewOffset) > 0 then ' partially watched
            dialog.SetButton("unscrobble", "Mark as unwatched")
            dialog.SetButton("scrobble", "Mark as watched")
        else if obj.metadata.viewCount <> invalid AND val(obj.metadata.viewCount) > 0 then ' watched
            dialog.SetButton("unscrobble", "Mark as unwatched")
            ' no need to show watched button (already watched)
        else if obj.metadata.viewCount = invalid then  ' not watched
            dialog.SetButton("scrobble", "Mark as watched")
            ' no need to show unwatched 
        end if
    end if

    if obj.metadata.server.AllowsMediaDeletion AND obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then
        dialog.SetButton("delete", "Delete permanently")
    end if

    ' set this to last -- unless someone complains
    if obj.metadata.ContentType = "movie" or obj.metadata.ContentType = "episode" or obj.metadata.ContentType = "show"  then
        dialog.SetButton("rate", "_rate_")
    end if

    dialog.SetButton("close", "Back")
    dialog.HandleButton = videoDialogHandleButton
    dialog.ParentScreen = obj
    dialog.Show()
end sub


sub fakeRefresh(force=false) 
    Debug("refresh? nah... faked it for now...")
'fake it for now
end sub 

sub rfVideoMoreButtonFromGrid(obj as Object) as Dynamic
    ' this should probably just be combined into rfVideoMoreButton  ( there are some caveats though and maybe more to come.. so until this has been finalized )
    dialog = createBaseDialog()
    if (obj.metadata.type = "season") then 
        dialog.Title = firstof(obj.metadata.title, obj.metadata.umtitle, obj.metadata.title)
        dialog.Text = ""
    else if (obj.metadata.type = "episode") then 
        dialog.Title = firstof(obj.metadata.showtitle, obj.metadata.title)
        dialog.Text = firstof(obj.metadata.shortdescriptionline2,  obj.metadata.shortdescriptionline1)
        dialog.Text = dialog.Text + chr(10) + chr(32) + chr(32) +chr(32) +firstof(obj.metadata.description, obj.metadata.umtitle)
    else 
        ' movies -- the description is too much
        dialog.Title = firstof(obj.metadata.showtitle, obj.metadata.umtitle, obj.metadata.title)
        dialog.Text = truncateString(obj.metadata.shortdescriptionline2,300)
     end if

    dialog.Item = obj.metadata

    if type(obj.Refresh) <> "Function" then 
      obj.Refresh = fakeRefresh ' sbRefresh is called normally - in a poster screen this doesn't happen?
    end if

    ' hack for global recenlty added ( tv shows are displayed as seasons )
    if (obj.metadata.type = "season") and obj.metadata.grandparentKey = invalid then 
        ' available: obj.metadata.key = "/library/metadata/88482/childen'
        re = CreateObject("roRegex", "/children.*", "i")
        obj.metadata.parentKey = re.ReplaceAll(obj.metadata.key, "")
        container = createPlexContainerForUrl(obj.metadata.server, obj.metadata.server.serverUrl, obj.metadata.parentKey)
        if container <> invalid then
            obj.metadata.grandparentKey = container.xml.Directory[0]@parentKey
            obj.metadata.parentIndex = container.xml.Directory[0]@index
            obj.metadata.ShowTitle = container.xml.Directory[0]@parentTitle
        end if
    else if (obj.metadata.type = "show") and obj.metadata.grandparentKey = invalid then 
        ' object type is a show -- we have all we need
        re = CreateObject("roRegex", "/children.*", "i")
        obj.metadata.grandparentKey = re.ReplaceAll(obj.metadata.key, "")
        obj.metadata.ShowTitle = firstof(obj.metadata.umtitle, obj.metadata.showtitle, obj.metadata.title)
        'end if
    else if obj.metadata.grandparentKey = invalid then 
         Debug("---- we should probably handle " + obj.metadata.type + "? figure out the parentKey/grandparentkey for: " + obj.metadata.key)
    end if
    ' end hack

    ' display View All Seasons if we have grandparentKey -- entered from a episode
    if obj.metadata.grandparentKey <> invalid then ' global on deck does not work with this
        dialog.SetButton("showFromEpisode", "View All Seasons of " + tostr(obj.metadata.ShowTitle) )
    end if
    ' display View specific season if we have parentKey/parentIndex -- entered from a episode
    if obj.metadata.parentKey <> invalid AND obj.metadata.parentIndex <> invalid then  ' global on deck does not work with this
       dialog.SetButton("seasonFromEpisode", "View Season " + obj.metadata.parentIndex)
    end if

    ' if obj.metadata.ContentType = "movie"  or obj.metadata.ContentType = "show"  or obj.metadata.ContentType = "episode"  then
    if obj.metadata.ContentType = "movie" then ' TODO - try and make this work with TV shows ( seems it only works for episodes -- but not well ) 
        dialog.SetButton("RFCastAndCrewList", "Cast & Crew")
    end if

    ' Trailers link - RR (last now that we include it on the main screen .. well before delete - people my be used to delete being second to last)
    'if obj.metadata.grandparentKey = invalid then
    if obj.metadata.ContentType = "movie" AND  RegRead("rf_trailers", "preferences", "disabled") <> "disabled" then 
        dialog.SetButton("getTrailers", "Trailer")
    end if

    supportedIdentifier = (obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" OR obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex")
    if supportedIdentifier then
        if obj.metadata.viewOffset <> invalid AND val(obj.metadata.viewOffset) > 0 then ' partially watched
            dialog.SetButton("unscrobble", "Mark as unwatched")
            dialog.SetButton("scrobble", "Mark as watched")
        else if obj.metadata.viewCount <> invalid AND val(obj.metadata.viewCount) > 0 then ' watched
            dialog.SetButton("unscrobble", "Mark as unwatched")
            ' no need to show watched button (already watched)
        else if obj.metadata.viewCount = invalid then  ' not watched
            dialog.SetButton("scrobble", "Mark as watched")
            ' no need to show unwatched 
        end if
    end if

    if obj.metadata.ContentType = "movie" or obj.metadata.ContentType = "episode" or obj.metadata.ContentType = "show"  then
        if obj.Item.StarRating = invalid then obj.Item.StarRating = 0
        if obj.Item.origStarRating = invalid then obj.Item.origStarRating = 0
        dialog.SetButton("rate", "_rate_")
    end if

    dialog.SetButton("close", "Back")
    dialog.HandleButton = videoDialogHandleButton
    dialog.ParentScreen = obj
    dialog.Show()
end sub
