'*
'* A list screen that can be used to reorder items.
'*

Function createReorderScreen(items, viewController)
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    imageDir = GetGlobalAA().Lookup("rf_theme_dir")

    screen = CreateObject("roListScreen")
    screen.SetMessagePort(obj.Port)

    screen.SetHeader("Select an item and move it up and down to reorder")

    obj.Screen = screen
    obj.Show = reorderShow
    obj.InitializeOrder = reorderInitializeOrder
    obj.Swap = reorderSwap
    obj.HandleMessage = reorderHandleMessage
    obj.ListScreenType = "reorder"

    ' We don't actually use the helpers from lsInitBaseListScreen, since this
    ' screen isn't command based. So don't bother calling it, just create the
    ' content array.
    obj.contentArray = []

    for each item in items
        if item.SDPosterURL = invalid then
            item.SDPosterURL = imageDir + "gear.png"
            item.HDPosterURL = imageDir + "gear.png"
        end if

        obj.contentArray.Push(item)
    end for

    ' ljunkie - add a close button. Required for legacy remotes to exit a list
    ' screen. Extra logic added below so we don't swap the close buttons (last)
    item = {}
    item.title = "Close"
    item.key = "close_reorder" ' something unique
    item.ignore = true         ' to ignore OnUserIput() on close
    obj.contentArray.Push(item)

    obj.FocusedIndex = 0
    obj.Selected = false

    return obj
End Function

Sub reorderShow()
    m.Screen.SetContent(m.contentArray)

    m.Screen.Show()
End Sub

Sub reorderInitializeOrder(keys)
    ReorderItemsByKeyPriority(m.contentArray, keys)
End Sub

Sub reorderSwap(index1, index2)
    item1 = m.contentArray[index1]
    item2 = m.contentArray[index2]

    m.contentArray[index2] = item1
    m.contentArray[index1] = item2

    m.Screen.SetItem(index1, item2)
    m.Screen.SetItem(index2, item1)
End Sub

Function reorderHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            if m.Listener <> invalid then
                first = true
                value = ""
                for each item in m.contentArray
                    if item.ignore = true then 
                        Debug("ignore passing value " + tostr(item.title) + " to m.Listener.OnUserInput()")
                    else
                        if first then
                            first = false
                        else
                            value = value + ","
                        end if
                        value = value + item.key
                    end if
                next
                m.Listener.OnUserInput(value, m)
            end if
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            ' last options is a close button
            if msg.GetIndex() >= m.contentarray.count()-1 then 
                m.Screen.Close()
                return true
            end if

            m.Selected = not m.Selected
            Debug("Selected item, now " + tostr(m.Selected))
            m.FocusedIndex = msg.GetIndex()
        else if msg.isListItemFocused() then
            ' last options is a close button ( unfocus - we will NOT swap )
            if msg.GetIndex() >= m.contentarray.count()-1 and m.Selected then 
               Debug("ignore selection -- last item (close)")
               m.Selected = false
               m.WasSelected = true
            end if
             
            ' restore selection/focusedIndex if we were selected, focused over close and then clicked up 
            if m.WasSelected = true and msg.GetIndex() < m.contentarray.count()-1 then 
                Debug("restore selection (last state selected)")
                m.FocusedIndex = msg.GetIndex()
                m.Selected = true
                m.WasSelected = invalid
            end if 

            if m.Selected then
                m.Swap(m.FocusedIndex, msg.GetIndex())
            end if
            m.FocusedIndex = msg.GetIndex()
        end if
    end if

    return handled
End Function
