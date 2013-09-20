' other functions required for my mods
Sub InitRARFlix() 
    RegRead("rf_bcdynamic", "preferences","enabled")
    RegRead("rf_rottentomatoes", "preferences","enabled")
    RegRead("rf_trailers", "preferences","enabled")
    RegRead("rf_tvwatch", "preferences","enabled")
    RegRead("rf_uw_movie_rows", "preferences","enabled")

    ' ljunkie Youtube Trailers (extended to TMDB)
    m.youtube = InitYouTube()

    Debug("=======================RARFLIX SETTINGS ====================================")
    Debug("rf_bcdynamic: " + tostr(RegRead("rf_bcdynamic", "preferences")))
    Debug("rf_rottentomatoes: " + tostr(RegRead("rf_rottentomatoes", "preferences")))
    Debug("rf_trailers: " + tostr(RegRead("rf_trailers", "preferences")))
    Debug("rf_tvwatch: " + tostr(RegRead("rf_tvwatch", "preferences")))
    Debug("rf_uw_movie_rows: " + tostr(RegRead("rf_uw_movie_rows", "preferences")))
    Debug("============================================================================")

end sub



Function GetDurationString( TotalSeconds = 0 As Integer, emptyHr = 0 As Integer, emptyMin = 0 As Integer, emptySec = 0 As Integer  ) As String
   datetime = CreateObject( "roDateTime" )
   datetime.FromSeconds( TotalSeconds )
      
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



    ' this is nasty (thanks emacs macros)- we shoudl be pulling from the reorder_prefs -- but for another time
    all_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "All Items" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "All Items" },
    ]
    obj.Prefs["rf_hide_all"] = {
        values: all_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    onDeck_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "On Deck" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "On Deck" },
    ]
    obj.Prefs["rf_hide_onDeck"] = {
        values: onDeck_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    recentlyAdded_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "Recently Added" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "Recently Added" },
    ]
    obj.Prefs["rf_hide_recentlyAdded"] = {
        values: recentlyAdded_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    newest_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "Recently Released/Aired" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "Recently Released/Aired" },
    ]
    obj.Prefs["rf_hide_newest"] = {
        values: newest_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    recentlyAdded_uw_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "Recently Added (unwatched)" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "Recently Added (unwatched)" },
    ]
    obj.Prefs["rf_hide_recentlyAdded_uw"] = {
        values: recentlyAdded_uw_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    newest_uw_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "Recently Released (unwatched)" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "Recently Released (unwatched)" },
    ]
    obj.Prefs["rf_hide_newest_uw"] = {
        values: newest_uw_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    unwatched_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "Unwatched" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "Unwatched" },
    ]
    obj.Prefs["rf_hide_unwatched"] = {
        values: unwatched_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    recentlyViewed_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "Recently Viewed" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "Recently Viewed" },
    ]
    obj.Prefs["rf_hide_recentlyViewed"] = {
        values: recentlyViewed_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    recentlyViewedShows_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "Recently Viewed Show," }
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "Recently Viewed Shows" },
    ]
    obj.Prefs["rf_hide_recentlyViewedShows"] = {
        values: recentlyViewedShows_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    albums_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "By Album" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "By Album" },
    ]
    obj.Prefs["rf_hide_albums"] = {
        values: albums_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    collection_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "By Collection" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "By Collection" },
    ]
    obj.Prefs["rf_hide_collection"] = {
        values: collection_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    genre_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "By Genre" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "By Genre" },
    ]
    obj.Prefs["rf_hide_genre"] = {
        values: genre_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    year_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "By Year" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "By Year" },
    ]
    obj.Prefs["rf_hide_year"] = {
        values: year_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    decade_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "By Decade" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "By Decade" },
    ]
    obj.Prefs["rf_hide_decade"] = {
        values: decade_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    director_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "By Director" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "By Director" },
    ]
    obj.Prefs["rf_hide_director"] = {
        values: director_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    actor_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "By Actor" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "By Actor" },
    ]
    obj.Prefs["rf_hide_actor"] = {
        values: actor_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    country_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "By Country" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "By Country" },
    ]
    obj.Prefs["rf_hide_country"] = {
        values: country_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    contentRating_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "By Content Rating" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "By Content Rating" },
    ]
    obj.Prefs["rf_hide_contentRating"] = {
        values: contentRating_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    rating_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "By Rating" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "By Rating" },
    ]
    obj.Prefs["rf_hide_rating"] = {
        values: rating_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    resolution_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "By Resolution" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "By Resolution" },
    ]
    obj.Prefs["rf_hide_resolution"] = {
        values: resolution_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    firstCharacter_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "By First Letter" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "By First Letter" },
    ]
    obj.Prefs["rf_hide_firstCharacter"] = {
        values: firstCharacter_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    folder_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "By Folder" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "By Folder" },
    ]
    obj.Prefs["rf_hide_folder"] = {
        values: folder_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    search_prefs = [
        { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: "Search" },
        { title: "Show", EnumValue: "show", ShortDescriptionLine2: "Search" },
    ]
    obj.Prefs["rf_hide_search"] = {
        values: search_prefs,
        heading: "Show or Hide Row",
        default: "show"
    }
    
    obj.Screen.SetHeader("Hide or Show Rows for Library Sections")
    
    obj.AddItem({title: "All Items"}, "rf_hide_all", obj.GetEnumValue("rf_hide_all"))
    obj.AddItem({title: "On Deck"}, "rf_hide_onDeck", obj.GetEnumValue("rf_hide_onDeck"))
    obj.AddItem({title: "Recently Added (unwatched)"}, "rf_hide_recentlyAdded_uw", obj.GetEnumValue("rf_hide_recentlyAdded_uw"))
    obj.AddItem({title: "Recently Released (unwatched)"}, "rf_hide_newest_uw", obj.GetEnumValue("rf_hide_newest_uw"))
    obj.AddItem({title: "Recently Added"}, "rf_hide_recentlyAdded", obj.GetEnumValue("rf_hide_recentlyAdded"))
    obj.AddItem({title: "Recently Released/Aired"}, "rf_hide_newest", obj.GetEnumValue("rf_hide_newest"))
    obj.AddItem({title: "Unwatched"}, "rf_hide_unwatched", obj.GetEnumValue("rf_hide_unwatched"))
    obj.AddItem({title: "Recently Viewed"}, "rf_hide_recentlyViewed", obj.GetEnumValue("rf_hide_recentlyViewed"))
    obj.AddItem({title: "Recently Viewed Shows"}, "rf_hide_recentlyViewedShows", obj.GetEnumValue("rf_hide_recentlyViewedShows"))
    obj.AddItem({title: "By Album"}, "rf_hide_albums", obj.GetEnumValue("rf_hide_albums"))
    obj.AddItem({title: "By Collection"}, "rf_hide_collection", obj.GetEnumValue("rf_hide_collection"))
    obj.AddItem({title: "By Genre"}, "rf_hide_genre", obj.GetEnumValue("rf_hide_genre"))
    obj.AddItem({title: "By Year"}, "rf_hide_year", obj.GetEnumValue("rf_hide_year"))
    obj.AddItem({title: "By Decade"}, "rf_hide_decade", obj.GetEnumValue("rf_hide_decade"))
    obj.AddItem({title: "By Director"}, "rf_hide_director", obj.GetEnumValue("rf_hide_director"))
    obj.AddItem({title: "By Actor"}, "rf_hide_actor", obj.GetEnumValue("rf_hide_actor"))
    obj.AddItem({title: "By Country"}, "rf_hide_country", obj.GetEnumValue("rf_hide_country"))
    obj.AddItem({title: "By Content Rating"}, "rf_hide_contentRating", obj.GetEnumValue("rf_hide_contentRating"))
    obj.AddItem({title: "By Rating"}, "rf_hide_rating", obj.GetEnumValue("rf_hide_rating"))
    obj.AddItem({title: "By Resolution"}, "rf_hide_resolution", obj.GetEnumValue("rf_hide_resolution"))
    obj.AddItem({title: "By First Letter"}, "rf_hide_firstCharacter", obj.GetEnumValue("rf_hide_firstCharacter"))
    obj.AddItem({title: "By Folder"}, "rf_hide_folder", obj.GetEnumValue("rf_hide_folder"))
    obj.AddItem({title: "Search"}, "rf_hide_search", obj.GetEnumValue("rf_hide_search"))
    
    obj.AddItem({title: "Close"}, "close")
    return obj
End Function
