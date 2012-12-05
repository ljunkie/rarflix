'*
'* A list screen that can be used to reorder items.
'*

Function createReorderScreen(items, viewController)
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

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
            item.SDPosterURL = "file://pkg:/images/gear.png"
            item.HDPosterURL = "file://pkg:/images/gear.png"
        end if

        obj.contentArray.Push(item)
    end for

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
                    if first then
                        first = false
                    else
                        value = value + ","
                    end if
                    value = value + item.key
                next
                m.Listener.OnUserInput(value, m)
            end if
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            m.Selected = not m.Selected
            Debug("Selected item, now " + tostr(m.Selected))
            m.FocusedIndex = msg.GetIndex()
        else if msg.isListItemFocused() then
            if m.Selected then
                m.Swap(m.FocusedIndex, msg.GetIndex())
            end if
            m.FocusedIndex = msg.GetIndex()
        end if
    end if

    return handled
End Function
