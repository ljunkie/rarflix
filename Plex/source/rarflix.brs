' other functions required for my mods
Sub InitRARFlix() 
    RegRead("rf_bcdynamic", "preferences","enabled")
    RegRead("rf_rottentomatoes", "preferences","enabled")
    RegRead("rf_trailers", "preferences","enabled")
    RegRead("rf_tvwatch", "preferences","enabled")
    RegRead("rf_uw_movie_rows", "preferences","enabled")
    RegRead("rf_searchtitle", "preferences","title")

    ' ljunkie Youtube Trailers (extended to TMDB)
    m.youtube = InitYouTube()

    Debug("=======================RARFLIX SETTINGS ====================================")
    Debug("rf_bcdynamic: " + tostr(RegRead("rf_bcdynamic", "preferences")))
    Debug("rf_rottentomatoes: " + tostr(RegRead("rf_rottentomatoes", "preferences")))
    Debug("rf_trailers: " + tostr(RegRead("rf_trailers", "preferences")))
    Debug("rf_tvwatch: " + tostr(RegRead("rf_tvwatch", "preferences")))
    Debug("rf_uw_movie_rows: " + tostr(RegRead("rf_uw_movie_rows", "preferences")))
    Debug("rf_searchtitle: " + tostr(RegRead("rf_searchtitle", "preferences")))
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

    obj.Screen.SetHeader("RARFlix Preferences")

    obj.AddItem({title: "Rotten Tomatoes"}, "rf_rottentomatoes", obj.GetEnumValue("rf_rottentomatoes"))
    obj.AddItem({title: "Movie Trailers"}, "rf_trailers", obj.GetEnumValue("rf_trailers"))
    obj.AddItem({title: "Trailers/Rotten Tomatoes Search by"}, "rf_searchtitle", obj.GetEnumValue("rf_searchtitle"))
    obj.AddItem({title: "Dynamic Headers"}, "rf_bcdynamic", obj.GetEnumValue("rf_bcdynamic"))
    obj.AddItem({title: "TV Titles (Watched Status)"}, "rf_tvwatch", obj.GetEnumValue("rf_tvwatch"))
    obj.AddItem({title: "Clock on Home Screen"}, "rf_hs_clock", obj.GetEnumValue("rf_hs_clock"))
    obj.AddItem({title: "Hide Rows"}, "hide_rows_prefs")
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
        { title: "Recently Released/Aired", key: "newest" },
        { title: "Unwatched", key: "unwatched" },
        { title: "Recently Added (unwatched)", key: "all?type=1&unwatched=1&sort=addedAt:desc" },
        { title: "Recently Released (unwatched)", key: "all?type=1&unwatched=1&sort=originallyAvailableAt:desc" },
        { title: "Recently Viewed", key: "recentlyViewed" },
        { title: "Recently Viewed Shows", key: "recentlyViewedShows" },
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

    for each item in PlexRows
        rf_hide_key = "rf_hide_"+item.key
        if item.key = "_search_" then item.key = "search" 'special case
        values = [
            { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: item.title },
            { title: "Show", EnumValue: "show", ShortDescriptionLine2: item.title },
        ]
        obj.Prefs[rf_hide_key] = {
           values: values,
           heading: "Show or Hide Row",
           default: "show"
        }
        obj.AddItem({title: item.title}, rf_hide_key, obj.GetEnumValue(rf_hide_key))
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
    print "------ requesting metadata to get required librarySection " + server.serverUrl + obj.item.metadata.key
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
        print "unexpected error in RFshowCastAndCrewScreen"
        return -1
    end if

    return obj.screen
end function

Function RFCastAndCrewHandleMessage(msg) As Boolean
    obj = m.viewcontroller.screens.peek()
    handled = false

    if type(msg) = "roPosterScreenEvent" then
        handled = true
        print "showPosterScreen | msg = "; msg.GetMessage() " | index = "; msg.GetIndex()
        if msg.isListItemSelected() then
            print "list item selected | current show = "; msg.GetIndex() 
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

    ' we can modify this if PMS ever keeps images for other cast & crew members. Actors only for now: http://10.69.1.12:32400/library/sections/6/actor
    print "------ requesting FULL list of actors to supply images " + server.serverurl + "/library/sections/" + librarySection + "/actor"
    container = createPlexContainerForUrl(server, server.serverurl, "/library/sections/" + librarySection + "/actor")

    'names = container.GetNames()
    keys = container.GetKeys()
    list = []
    sizes = ImageSizes("movie", "movie")
    for each i in item.metadata.castcrewList
        for index = 0 to keys.Count() - 1
            if keys[index] = i.id then 

                default_img = container.xml.Directory[index]@thumb
                i.imageSD = server.TranscodedImage(server.serverurl, default_img, sizes.sdWidth, sizes.sdHeight)
                i.imageHD = server.TranscodedImage(server.serverurl, default_img, sizes.hdWidth, sizes.hdHeight)
                if server.AccessToken <> invalid then 
                    i.imageSD = i.imageSD + "&X-Plex-Token=" + server.AccessToken
                    i.imageHD = i.imageHD + "&X-Plex-Token=" + server.AccessToken
                end if
                exit for
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

' Screen show show Movies with Actor/Director/Writer/etc.. 
Function RFcreateItemsForCastCrewScreen(obj as Object, idx as integer) As Integer
    cast = obj.item.metadata.castcrewlist[idx]
    server = obj.item.metadata.server
    librarySection = obj.librarySection

    if librarySection <> invalid then 
        dummyItem = CreateObject("roAssociativeArray")
        if lcase(cast.itemtype) = "writer" or lcase(cast.itemtype) = "producer" then ' writer and producer are not listed secondaries ( must use filter - hack in PlexMediaServer.brs:FullUrl function )
            dummyItem.sourceUrl = server.serverurl + "/library/sections/" + librarySection + "/all"
            dummyItem.key = "filter?type=1&" + lcase(cast.itemtype) + "=" + cast.id + "&X-Plex-Container-Start=0" ' prepend "filter" to the key, is the key to the hack
        else
            dummyItem.sourceUrl = server.serverurl + "/library/sections/" + librarySection + "/" + lcase(cast.itemtype) + "/" + cast.id
            dummyItem.key = ""
        end if

	print "-------------------------- " + dummyItem.sourceUrl + dummyItem.key
        print "------ requesting metadata to get required librarySection " + server.serverUrl + "library/sections/" + librarySection
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
        Debug( "------------ trying to get movies for cast member: " + cast.name + ":" + lcase(cast.itemtype) + " @ " + dummyItem.sourceUrl)
        m.ViewController.CreateScreenForItem(dummyItem, invalid, breadcrumbs)
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

