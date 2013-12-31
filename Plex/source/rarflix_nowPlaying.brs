Sub rf_homeNowPlayingChange()
    ' RefreshData() -  homeRefreshData() this would refresh all.. but we don't want to do that ( I think )
    ' might be usful to check audio now playing too

    rowkey = "now_playing"
    m.contentArray[m.RowIndexes[rowkey]].refreshContent = []
    m.contentArray[m.RowIndexes[rowkey]].loadedServers.Clear()

    re = CreateObject("roRegex", "my.plexapp.com", "i")        
    for each server in GetOwnedPlexMediaServers()
        if re.IsMatch(server.serverurl) then 
            Debug("Skipping now playing session check on 'cloud sync' server: " + server.serverurl)
        else if server.isavailable and server.supportsmultiuser then ' only query server if available and supportsmultiuser (assuming nowPlaying works with multiuser enabled)
            m.CreateServerRequests(server, true, true, invalid, rowkey) ' only request the nowPlaying;/status/sessions
        end if
    next

End Sub

sub rf_updateNowPlayingSB(screen)
    orig_offset = screen.metadata.viewOffset
    new_metadata = rfUpdateNowPlayingMetadata(screen.metadata)

    if new_metadata.viewOffset <> invalid then
        screen.metadata.isStopped = invalid
        screen.metadata.description = " * Progress: " + GetDurationString(int(new_metadata.viewOffset.toint()/1000),0,1,1) ' update progress - if we exit player
        if new_metadata.length <> invalid then 
            screen.metadata.description = screen.metadata.description + " [" + percentComplete(new_metadata.viewOffset,new_metadata.length) + "%]"
        end if
        screen.metadata.viewOffset = new_metadata.viewOffset ' set new offset
    else 
        screen.metadata.isStopped = true
        screen.metadata.description = " * User has stopped watching"
        screen.metadata.viewOffset = orig_offset
        Debug("---- setting the video Offset to your offset (not remote) " + tostr(orig_offset) + " - user has stopped but you should be able to resume!")
    end if

    screen.metadata.description = screen.metadata.description + " on " + firstof(screen.metadata.nowplaying_platform_title, screen.metadata.nowplaying_platform, "")
    if new_metadata.server.name <> invalid then screen.metadata.description = screen.metadata.description + " [" + new_metadata.server.name + "]" ' show the server 
    screen.metadata.nowPlaying_progress = screen.metadata.description
    screen.metadata.description = screen.metadata.description + chr(10) + screen.metadata.nowPlaying_orig_description ' append the original description
   
    ' on the spring board - we also only want to show the original title - the breadcrumbs will have the user
    if new_metadata.episodestr <> invalid then 
        screen.metadata.titleseason = new_metadata.cleantitle + " - " + new_metadata.episodestr
    else
        screen.metadata.title = new_metadata.cleantitle
    end if
    screen.Screen.setContent(screen.metadata)
    Debug("Refreshing nowPlaying videoSpringBoard content")
end sub

function rfUpdateNowPlayingMetadata(metadata,time = 0 as integer) as object
    container = createPlexContainerForUrl(metadata.server, metadata.server.serverurl, "/status/sessions")
    keys = container.getkeys()
    found = false

    ' ljunkie - only allow Video for now ( Track/Photo? are now valid, but untested and break )
    for index = 0 to container.xml.Video.count() - 1      '    for index = 0 to keys.Count() - 1
        Debug("Searching for key:" + tostr(metadata.key) + " and machineID:" + tostr(metadata.nowPlaying_maid) ) ' verify same machineID to sync (multiple people can be streaming same content)
        if keys[index] = metadata.key and container.xml.Video[index].Player@machineIdentifier = metadata.nowPlaying_maid then 
            Debug("----- nowPlaying match: key:" + tostr(metadata.key) + ", machineID:" + tostr(metadata.nowPlaying_maid) + " @ " + tostr(metadata.server.serverurl) + "/status/sessions")
            found = true
            Debug("----- prev offset " + tostr(metadata.viewOffset))
            metadata = container.metadata[index]
            if metadata.viewOffset <> invalid then 
                metadata.viewOffset = tostr(metadata.viewOffset.toint() + int(time)) ' just best guess. add on a few seconds since it takes time to buffer
            else 
                metadata.viewOffset = "0"
            end if
            Debug("-----  new offset " + tostr(metadata.viewOffset))
            if time > 0 then  debug("----- added " + tostr(int(time/1000)) + " seconds to offset for sync")
            exit for
        end if
    end for

    if NOT found then
        metadata.viewOffset = invalid
    end if

    return metadata
end function

sub setnowplayingGlobals() 
    ' only set nowplaying globals if notifications are enabled (row loader will always call the plexcontainerforurl)
    ' TODO: this will need some work for Video, Audio, Photo...
    if RegRead("rf_notify","preferences","enabled") <> "disabled" then
        np = []
        this_maid = GetGlobalAA().Lookup("rokuUniqueID")
        for each server in GetOwnedPlexMediaServers()
            if server.isavailable and server.supportsmultiuser then ' only query server if available and supportsmultiuser (assuming nowPlaying works with multiuser enabled)
                container = createPlexContainerForUrl(server, server.serverurl, "/status/sessions")
                ' ljunkie - for now, we have limited this to Now Playing VIDEO
                if container <> invalid and container.xml <> invalid and type(container.xml.Video) = "roXMLList" and container.getkeys().count() > 0 then
                    keys = container.getkeys()
                    for index = 0 to container.xml.Video.count() - 1 ' for index = 0 to keys.Count() - 1
                        libraryKey = container.xml.Video[index]@key
                        ratingKey = container.xml.Video[index]@ratingkey
                        if ratingKey <> invalid and container.xml.Video.count() > index then 
                            maid = container.xml.Video[index].Player@machineIdentifier
                            user = container.xml.Video[index].User@title
                            ' match metadata for key to now playing item
                            ' metadata = container.metadata[index]
                            for i = 0 to container.metadata.count() 
                                if container.metadata[i].key = libraryKey then 
                                    metadata = container.metadata[i]
                                    exit for
                                end if 
                            end for 
                            platform = firstof(container.xml.Video[index].Player@title, container.xml.Video[index].Player@platform, "")
                            length = invalid
                            if container.xml.Video[index]@duration <> invalid then 
                                length = firstof(tostr((container.xml.Video[index]@duration).toint()/1000), 0)
                            end if
                            if metadata.episodestr <> invalid then 
                                title = metadata.cleantitle + " - " + metadata.episodestr
                            else
                                title = metadata.cleantitle
                            end if
                            if this_maid <> maid then np.Push({maid: maid, title: title, user: user, key: ratingKey, platform: platform, length: length, item: metadata})
                        end if
                    end for
                 end if
            end if
        end for
        GetGlobalAA().rf_nowPlaying = [] 
        GetGlobalAA().AddReplace("rf_nowPlaying", np)
    end if
end sub

function getNowPlayingNotifications() as object
    if RegRead("rf_notify","preferences","enabled") = "disabled" then return invalid

    notify = []
    np = GetGlobalAA().rf_nowPlaying
    found = []

    ' iterate through now playing content and set the first unnotified object ( we will grab any others on the next run )
    ' we might want to combined then..
    if type(np) = "roArray" and np.count() > 0 then
        for each i in np
             nkey = i.maid + "_" + i.key ' this is in case the same machine can play two video.. PMS doesn't allow it ( so overkill )
             if RegRead(nkey, "rf_notified","false") <> "true" then 
                i.type = "start"
                i.title = i.item.title
                i.text = i.item.description
                if RegRead("rf_notify_np_type","preferences","all") <> "stop"  then 
                    notify.Push(i) ' set return object
                else 
                    Debug("skipping start notification due to prefs")
                end if
                RegWrite(nkey, "true", "rf_notified") 
		' TODO - this global should really be an AA
                GetGlobalAA().AddReplace(nkey + "_user", i.user)
                GetGlobalAA().AddReplace(nkey + "_title", i.item.CleanTitle)
                GetGlobalAA().AddReplace(nkey + "_length", i.length) 
            end if
            GetGlobalAA().AddReplace(nkey + "_viewOffset", i.item.viewOffset)
            found.Push(nkey) ' save all now playing for the next checks
        next
    end if

    ' Check to verify all seen players are still playing.. otherwise we want to unset (maybe notify at some point) to be able to notify again
    seen = GetGlobalAA().nowplaying_cur
    if type(seen) = "roArray" and seen.count() > 0 then
        for each maid in seen
            Debug( "----- checking if " + tostr(maid) + " is playing")
            RFinarray = false
            for each f_maid in found 
                if f_maid = maid then RFinarray = true
            next    

            if NOT RFinarray then ' if NOT inArray(seen,found) then -- very bad TOFI
                ' notification for stopped content - we will need to grab the itemKey if we want to link the video
                n = CreateObject("roAssociativeArray")
                n.type = "stop" 
                n.title = UcaseFirst(GetGlobalAA().Lookup(maid + "_user"),true) + " stopped " + GetGlobalAA().Lookup(maid + "_title")

                n.viewOffset = GetGlobalAA().Lookup(maid + "_viewOffset")
                n.length = GetGlobalAA().Lookup(maid + "_length")
                if n.length <> invalid then 
                    n.title = "[" + percentComplete(n.viewOffset,n.length.toInt(),true) + "%]" + " " + n.title
                end if
                n.text = ""
                if RegRead("rf_notify_np_type","preferences","all") <> "start"  then 
                    notify.Push(n) 
                else 
                    Debug("skipping stop notification due to prefs")
                end if
                RegDelete(maid, "rf_notified")
                GetGlobalAA().Delete(maid + "_user")
                GetGlobalAA().Delete(maid + "_title")
                GetGlobalAA().Delete(maid + "_length")
                GetGlobalAA().Delete(maid + "_viewOffset")
                Debug("---- removing " + tostr(maid) + " from 'rf_notified' -- video playback stopped")
            else
                Debug("----- " + tostr(maid) + " is found (currently playing)")
            end if
        next
    end if    

    ' now unset/set currently playing content
    GetGlobalAA().nowplaying_cur = [] 
    GetGlobalAA().AddReplace("nowplaying_cur", found)

    if notify.count() > 0 then return notify
    return invalid
end function

function percentComplete(viewOffset as dynamic, Length as dynamic, round=false as boolean) as String
   'TODO - check if string or integer just to be safe
   if viewOffset <> invalid and length <> invalid then 
       percent = int(((viewOffset.toInt()/1000)/length )*100)
       if round and percent > 90 then return "100"
       return tostr(percent)
   end if
   return "0"
end function

' This needs some work - rough draft - should add link to view videoDetial screen from here
Sub ShowNotifyDialog(obj As dynamic, notifyIndex = 0, isNowPlaying = false) 
    if m.viewcontroller.IsLocked <> invalid and m.viewcontroller.IsLocked then return
    Debug("showing Dialog notifications ")
    ' isNowPlaying is special - if true, we will show all the NowPlaying items when a user selectes to show the notification (allows this dialog to be used for other notifications)

    if type(obj) = "roArray" then
        notify = obj[notifyIndex]
    else
        notify = obj
        obj = []
        obj.push(notify)
    end if

    dialog = createBaseDialog()
    dialog.Title = notify.title
    dialog.Text = notify.text
    dialog.Item = notify
    dialog.idx = notifyIndex
    dialog.obj = obj
    dialog.isNowPlaying = isNowPlaying

    dialog.HandleButton = notifyDialogHandleButton
    if type(obj) = "roArray" and obj.Count() > 1 then
        dialog.SetButton("fwd", "Next")
        dialog.text = dialog.text + chr(10) ' for overlay 
        dialog.StaticText = tostr(obj.Count()) + " notifications "
    end if
    dialog.text = dialog.text + chr(10) ' for overlay 
    dialog.text = truncateString(dialog.text,200) ' for overlay 
    'dialog.sepBefore.Push("show")
    dialog.SetButton("show", "Show Now Playing")
    dialog.SetButton("close", "Close")
    dialog.Show()
End Sub

Function notifyDialogHandleButton(buttoncommand, index) As Boolean
    close_dialog = false
   
    dialog = m.viewcontroller.screens.peek()

    notify = dialog.obj[dialog.idx]
    total = dialog.obj.Count() -1

    refresh = false
    focusbutton = 0
    if buttonCommand = "show" then
        close_dialog = true

        items = []
        itemsIndex = dialog.idx
        if dialog.isNowPlaying then
            Debug("showing all the now playing items with this item focused in a springBoard screen")
            nowPlaying = GetGlobalAA().rf_nowPlaying
            for index = 0 to nowPlaying.Count() - 1
                if dialog.obj[dialog.idx].key = nowPlaying[index].key then
                    itemsIndex = index
                end if
                items.Push(nowPlaying[index].item)
            next
        else 
            for each i in dialog.obj 
                items.Push(i.item)
            next
        end if
        if items.count() > 0 then 
            m.ViewController.CreateScreenForItem(items, itemsIndex, invalid)
        else 
            ShowErrorDialog("No one is watching anything","Now Playing")
        end if 
    else if buttonCommand = "fwd" then
        dialog.idx = dialog.idx + 1
        if dialog.idx > dialog.obj.Count() - 1 then dialog.idx = 0
        notify = dialog.obj[dialog.idx]
        dialog.title = notify.title
	dialog.text = notify.text
	dialog.notify = notify
        refresh = true
    else if buttonCommand = "rev" then
        dialog.idx = dialog.idx - 1
        if dialog.idx < 0 then dialog.idx = dialog.obj.Count() - 1
        notify = dialog.obj[dialog.idx]
        dialog.title = notify.title
	dialog.text = notify.text
	dialog.notify = notify
        refresh = true
        if dialog.idx > 0 then 
            focusbutton = 1
        end if
    else if buttonCommand = "close" then
        close_dialog = true
    end if

    if refresh then 
        dialog.FocusedButton = focusbutton
        dialog.buttons = []
        if dialog.idx < total then 
            dialog.SetButton("fwd", "Next")
        else 
            dialog.text = dialog.text + chr(10) ' for overlay 
        end if
        if dialog.idx > 0 then
            dialog.SetButton("rev", "Previous")
        else 
            dialog.text = dialog.text + chr(10) ' for overlay 
        end if
        dialog.text = truncateString(dialog.text,200)
        dialog.SetButton("show", "Show Now Playing")
        dialog.SetButton("close", "Close")

        dialog.Refresh()
    end if

    return close_dialog
End Function