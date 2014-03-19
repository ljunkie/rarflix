'* Rob Reed: routines to sort a full grid (maybe rows)
'*  
'* 
'*
' TODO(ljunkie) - can these be extended into the normal rows?

Function gridsortDialogHandleButton(command, data) As Boolean
    obj = m.ParentScreen
    closeDialog = false

    if command = "close" then
        closeDialog = true
    else 
        validCommand = false
        for index = 0 to m.buttons.count()-1

            if m.buttons[index][command] <> invalid then

                print "found command: " + tostr(command)
                print "index: " + tostr(index)

                validCommand = true

                if m.item = invalid or (m.item.key = command) then 
                    Debug("toggle asc/desc for existing order selection: " + tostr(command))

                    curValue = m.buttons[index][command]
                    m.buttons[index] = invalid
                    m.buttons[index] = {}
 
                    rawKey = invalid
                    re= CreateObject("roRegex", "([^\:]+)", "")
                    match = re.match(command)
                    if match[0] <> invalid then rawKey = match[1]

                    if instr(1,command, "asc") > 0 then 
                        curOrder = "asc"
                        newOrder = "desc"
                    else 
                        curOrder = "desc"
                        newOrder = "asc"
                    end if

                    re= CreateObject("roRegex", ":" + curOrder, "")
                    command = re.ReplaceAll(command, ":" + newOrder) 
 
                    re= CreateObject("roRegex", "\[" + curOrder, "")
                    curValue = re.ReplaceAll(curValue, "[" + newOrder) 
 
                    m.buttons[index][command] = curValue
                   
                              
                end if

                ' we must exit after we match the command - index is used below
                exit for

            end if

        end for

        if index > m.buttons.count()-1 then 
           print "index" + tostr(index) + "it greater than buttons"
           print m.buttons.count()-1           
           return false
        end if
         
        ' do nothing if we have somehow passed an invalid sorting option
        if NOT validCommand return false 

        ' save the current selection in the dialogs context
        if m.item = invalid then m.item = {}

        ' update the dialog variable and text before refreshing
        m.item.key = command
        m.item.title = m.buttons[index][command]
        m.text = "Selected: " + tostr(m.item.title)
        m.StickyButton(m.item.key)

        m.refresh()

        ' we are handling the sort in a dialog of a dialog.
        gridSortSection(obj.parentscreen,command)

        m.handled = false
    end if

    return closeDialog

End Function


' return all the valid sorting options for a library sections
' includes valid buttons for use and the current sorting method
' It will cache the valid sorts for a sections, so only one call
' *should* be made per sever section per seesion
function getSortingOption(server = invalid,sourceUrl = invalid)

    if server = invalid or sourceUrl = invalid then return invalid

    cacheKeys = getFilterSortCacheKeys(server,sourceurl)
    if cachekeys = invalid then return invalid
    sectionKey = cacheKeys.sectionKey

    validSorts = GetGlobal(cachekeys.sortCacheKey)

    if validSorts = invalid then 
        Debug("caching Valid Sorts for this section")
        ' set cache to empty ( not invalid -- so we don't keep retrying )
        GetGlobalAA().AddReplace(cachekeys.sortCacheKey, {})        
        typeKey = "?type="+tostr(cacheKeys.typeKey)
        if cacheKeys.typeKey = invalid then typeKey = ""
        obj = createPlexContainerForUrl(server, "", sectionKey + "/sorts" + typeKey)
        if obj <> invalid then 
            ' using an assoc array ( we might want more key/values later )
            GetGlobalAA().AddReplace(cachekeys.sortCacheKey, obj.getmetadata())        
            validSorts = GetGlobal(cachekeys.sortCacheKey)
        end if
    end if

    if validSorts = invalid or validSorts.count() = 0 then return invalid

    ' 3. try to determine the current sort if already in the url
    sortKey = invalid
    if sourceUrl <> invalid then 
        re = CreateObject("roRegex", "sort=([^\&\?]+)", "i")
        match = re.Match(sourceurl)
        if match[0] <> invalid then sortKey = match[1]
    end if

    ' maybe someday we will have a valid title per order
    ' I.E. mediaHeight, duration, addedAt, etc have different definitions for asc/desc
    orders = [{title: "desc", key: "desc"},{title: "asc", key: "asc"}]
    Buttons = []:Options = []

    ' determine all sorting options + buttons options ( in order to display )
    ' by default, we will use descending as the buttons unless a "default" is specified from the PMS
    for each item in validSorts

        if item.default = invalid
            ' use the valid sort.key/sort.title if already selected
            selectedKey = invalid
            for each order in orders
                if sortKey = item.key+":"+order.key then 
                    buttons.Push({ title: item.title + " [" + order.title + "]", key: item.key+":"+order.key})        
                    selectedKey = true
                end if
            end for

            ' default to desc as the first options for buttons
            if selectedKey = invalid then 
                Buttons.Push({ title: item.title + " [desc]", key: item.key+":desc"})        
            end if

        end if

        ' All Valid sort orders ( ordering of the array doesn't matter )
        for each order in orders
            options.Push({ title: item.title + " [" + order.title + "]", key: item.key+":"+order.key})        
        end for
    end for

    ' default sort at the beginning
    for each item in  validSorts
        if item.default <> invalid then 
            ' use the valid sort.key/sort.title if already selected
            selectedKey = invalid
            for each order in orders
                if sortKey = item.key+":"+order.key then 
                    buttons.Unshift({ title: item.title + " [" + order.title + "]", key: item.key+":"+order.key})        
                    selectedKey = true
                end if
            end for

            ' use the default if not selected
            if selectedKey = invalid then 
                Buttons.Unshift({ title: item.title + " [" + item.default + "]", key: item.key+":"+item.default})        
            end if
        end if
    end for

    ' container for result
    obj = {}
    obj.contentArray = options
    obj.buttons = buttons
    obj.curIndex = 0
    obj.buttonIndex = 0

    defaultSort = RegRead("section_sort", "preferences","titleSort:asc")

    ' lookup the current order: sort order is saved per section for the session of the channel
    if sortKey = invalid then sortKey = GetGlobalAA().lookup(cachekeys.sortValCacheKey)
    if sortkey = invalid or sortKey = "" then sortKey = defaultSort

    Debug("current sort key for: " + tostr(cachekeys.sortValCacheKey) + " val:" + tostr(GetGlobalAA().lookup(cachekeys.sortValCacheKey)))
    Debug("current sort key used: " + tostr(sortKey))

    ' current selection index of options
    for index = 0 to options.count()-1
        if options[index].key = sortKey then 
            obj.curIndex = index
        end if
    end for

    ' current selection index of buttons
    for index = 0 to buttons.count()-1
        if buttons[index].key = sortKey then 
            obj.buttonIndex = index
        end if
    end for

    ' choose the selected item from the contentArray ( all items )
    obj.item = obj.contentArray[obj.curIndex]

    ' return the default sort option if the required critera hasn't been matched
    return obj

end function

' re-sort a full grid screen from a dialog. This will reset the required sourceUrls
' and keys and will be refreshed by the paginatedData loader
sub gridSortSection(grid,sortKey = invalid)

    if sortKey = invalid then 
        Debug("gridSortSection:: sortKey is invalid")
    end if

    if grid = invalid or grid.loader = invalid or grid.loader.sourceurl = invalid or grid.loader.server = invalid then 
        Debug("gridSortSection:: grid is invalid or requied loader data is missing")
        return
    end if

    ' sort order is saved per section for the session of the channel
    cacheKeys = getFilterSortCacheKeys(grid.loader.server,grid.loader.sourceurl)
    if cachekeys = invalid then return
    GetGlobalAA().AddReplace(cachekeys.sortValCacheKey,sortKey)

    sourceurl = grid.loader.sourceurl
    if sourceurl <> invalid then 
        re = CreateObject("roRegex", "(sort=[^\&\?]+)", "i")

        if re.IsMatch(sourceurl) then 
            'if instr(1, sortKey, "titleSort:asc") > 0 then 
            '    re = CreateObject("roRegex", "([\?\&]sort=[^\&\?]+)", "i")
            '    sourceurl = re.ReplaceAll(sourceurl, "")
            'else 
                sourceurl = re.ReplaceAll(sourceurl, "sort="+sortKey)
            'end if
        else 
            'if instr(1, sortKey, "titleSort:asc") = 0 then 
                f = "?"
                if instr(1, sourceurl, "?") > 0 then f = "&"    
                sourceurl = sourceurl + f + "sort="+sortKey
            'end if
        end if

        grid.loader.sourceurl = sourceurl
        grid.loader.sortingForceReload = true
        if grid.loader.listener <> invalid and grid.loader.listener.loader <> invalid then 
            grid.loader.listener.loader.sourceurl = sourceurl
        end if
    end if

    contentArray =  grid.loader.contentArray
    if contentArray <> invalid and contentArray.count() > 0 then 
        for index = 0 to contentArray.count()-1
            if contentArray[index].key <> invalid then 
                re = CreateObject("roRegex", "(sort=[^\&\?]+)", "i")
                if re.IsMatch(contentArray[index].key) then
                    'if instr(1, sortKey, "titleSort:asc") > 0 then 
                    '    re = CreateObject("roRegex", "([\?\&]sort=[^\&\?]+)", "i")
                    '    contentArray[index].key = re.ReplaceAll(contentArray[index].key, "")
                    'else 
                        contentArray[index].key = re.ReplaceAll(contentArray[index].key, "sort="+sortKey)
                    'end if
                else 
                    'if instr(1, sortKey, "titleSort:asc") = 0 then 
                        f = "?"
                        if instr(1, contentArray[index].key, "?") > 0 then f = "&"    
                        contentArray[index].key = contentArray[index].key + f + "sort="+sortKey
                    'end if
                end if
             end if
        end for
    end if

end sub

' easy way to blindly throw in the button as an options. It will 
' not be added to the dialog unless valid
sub dialogSetSortingButton(dialog,obj) 
    if obj.isfullgrid = true and type(obj.screen) = "roGridScreen" then 
        'reFILT = CreateObject("roRegex", "/all", "i")
        reSORT = CreateObject("roRegex", "/all|/firstCharacter", "i")

        if obj.loader <> invalid and obj.loader.sourceurl <> invalid then 
            ' include the sorting options all the time
            sortText = ""
            sort = getSortingOption(obj.loader.server,obj.loader.sourceurl)
            if sort <> invalid and sort.item <> invalid and sort.item.title <> invalid then 
                sortText = sort.item.title
            end if

            ' ONLY allow filtering if the obj.loader is filterable
            if obj.loader.isFilterable = true then
                FilterSortText = "Filters: "
                if getFilterSortParams(obj.loader.server,obj.loader.sourceurl).hasFilters = true then 
                    FilterSortText = FilterSortText + "Enabled" 
                else 
                    FilterSortText = FilterSortText + "None" 
                end if

                if sortText <> "" then 
                    FilterSortText = FilterSortText + ", Sort: "+sortText
                end if
                dialog.SetButton("gotoFilters", FilterSortText)
            else if reSORT.IsMatch(obj.loader.sourceurl) and sortText <> "" then 
                ' fallback - show the sorting button if url endpoint allows sorting
                dialog.SetButton("SectionSorting", "Sort: " + sortText)
            end if
        else 
            ' TODO(ljunkie) - think about removing this -- waste of screen space
            ' however one my be wondering why the sorting option isn't showing up.
            'dialog.SetButton("SectionSortingDisabled", "Sorting: not available")
        end if
    end if
end sub

function createGridSortingDialog(screen,obj) 
    dialog = createBaseDialog()
    dialog.Title = "Sorting Options"

    sort = getSortingOption(obj.loader.server,obj.loader.sourceurl)
    if sort = invalid or sort.item = invalid or sort.contentarray = invalid or sort.contentarray.count() = 0 then return invalid
    if sort.buttons = invalid or sort.buttons.count() = 0 then return invalid

    dialog.Text = "Selection: " + tostr(sort.item.title)
    dialog.item = sort.item

    for each item in sort.buttons
        dialog.SetButton(item.key, item.title) 
    end for

    if sort.buttonIndex <> invalid then dialog.FocusedButton = sort.buttonIndex

    dialog.SetButton("close", "Close") ' back seems odd because we came from a dialog ( one might get confused )
    dialog.HandleButton = gridsortDialogHandleButton
    dialog.ParentScreen = screen
    return dialog
end function
