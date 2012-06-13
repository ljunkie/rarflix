'*
'* Functions that can be added to roListScreen wrapper objects. The screens
'* tend to be different enough to warrant their own wrappers, but these
'* functions help unify the behavior (in the absence of real base classes).
'*

Sub lsInitBaseListScreen(obj)
    obj.contentArray = []

    obj.AddItem = lsAddItem
    obj.SetTitle = lsSetTitle
    obj.AppendValue = lsAppendValue
    obj.GetSelectedCommand = lsGetSelectedCommand
End Sub

Sub lsAddItem(item, command=invalid, value=invalid)
    if item.SDPosterURL = invalid then
        item.SDPosterURL = "file://pkg:/images/gear.png"
        item.HDPosterURL = "file://pkg:/images/gear.png"
    end if

    item.OrigTitle = item.Title
    item.CommandName = command

    if value <> invalid and value <> "" then
        item.Title = item.OrigTitle + ": " + value
    end if

    m.contentArray.Push(item)
    m.Screen.AddContent(item)
End Sub

Sub lsSetTitle(index, title)
    item = m.contentArray[index]
    item.Title = title
    m.Screen.SetItem(index, item)
End Sub

Sub lsAppendValue(index, value)
    if index = invalid then index = m.contentArray.Count() - 1
    item = m.contentArray[index]

    if value <> invalid and value <> "" then
        item.Title = item.OrigTitle + ": " + value
    else
        item.Title = item.OrigTitle
    end if

    m.Screen.SetItem(index, item)
End Sub

Function lsGetSelectedCommand(index)
    item = m.contentArray[index]
    if item <> invalid then
        return item.CommandName
    end if

    return invalid
End Function

