Function showPreferenceScreen (item, viewController)
	
	port = CreateObject("roMessagePort")
	screen = createObject("roListScreen")
	screen.setMessagePort(port)
	screen.setTitle("Preferences")
    server = item.server

    container = createPlexContainerForUrl(server, item.sourceUrl, item.key)
    
    prefArray = CreateObject("roArray", 6 , true)
    
    prefArray.Push({label: "Close Preferences"})
    screen.addContent({title: "Close Preferences"})
    for each prefItem in container.xml.Setting
        prefArray.Push(prefItem)
        'Start getting values
        value = prefItem@value
        if value = ""  then
			value = prefItem@default
        end if
        'If an enum, get the value from the values attribute
        if prefItem@type = "enum" then
			r = CreateObject("roRegex", "\|", "")
			valuesList = r.Split(prefItem@values)
			value = valuesList[value.toint()]
        end if
        'If hidden, replace value with *
        if prefItem@option = "hidden" then
			r = CreateObject("roRegex", ".","i")
			value = r.ReplaceAll(value, "\*")

        end if
        
        buttonTitle = prefItem@label
        if value <>  "" then
			buttonTitle = buttonTitle + ": " +value		
        end if
        screen.addContent({title: buttonTitle})
    next
    
    
    
    
	screen.show()
	while true 
        msg = wait(0, screen.GetMessagePort()) 
        if type(msg) = "roListScreenEvent"
            if msg.isScreenClosed() then
                exit while
             else if msg.isListItemSelected() then
                if msg.getIndex() = 0 then
                    print "Closing Preferences"
                    screen.close()
                else 
                    showInput(prefArray[msg.getIndex()],item, screen, msg.getIndex())
                end if
            end if 
        end if
	end while
End Function

Function showInput (inputItem,item,screen, buttonIndex)
	if inputItem@secure = "true" then		
		popup = createObject("roMessageDialog")
		popup.setMessagePort(port)
		popup.setTitle("Secure Preferences Not Supported")
		popup.setText("The Roku client does not support the setting of secure preferences.  Please use another client to configure this preference")
		popup.addButton(0,"Close")
		popup.show()
		while true
			dlgMsg = wait(0, popup.GetMessagePort())
			if type(dlgMsg) = "roMessageDialogEvent"
				if msg.isScreenClosed() then
					exit while
				else if msg.isButtonPressed() then
					if msg.GetIndex() =0  then
						popup.close()						
					end if
				end if
			end if
		end while
	else
		if inputItem@type = "text"  then
			showTextInput(inputItem,item,screen, buttonIndex)
		else if inputItem@type = "bool"  then
			showBoolInput(inputItem,item,screen, buttonIndex)
		else if inputItem@type = "enum"  then
			ShowEnumInput(inputItem,item,screen, buttonIndex)
		end if
	end if
End Function


Function showTextInput (inputItem,item,parentScreen, buttonIndex) 
	port = createObject("roMessagePort")


		
	keyb = CreateObject("roKeyboardScreen")    
	keyb.SetMessagePort(port)
	keyb.SetDisplayText("Enter " + inputItem@label)		
	keyb.AddButton(1, "Done") 
	keyb.AddButton(2, "Close")
	keyb.setTitle(inputItem@label)
	if inputItem@value = "" then
		keyb.setText(inputItem@default)		
	else
		keyb.setText(inputItem@value)		
	end if
	if inputItem@option = "hidden" then
		keyb.setSecureText(true)
	end if
	keyb.Show()
	while true 
		msg = wait(0, keyb.GetMessagePort()) 
		if type(msg) = "roKeyboardScreenEvent" then
			if msg.isScreenClosed() then
				print "Exiting keyboard dialog screen"
				return 0
			else if msg.isButtonPressed() then
				if msg.getIndex() = 1 then
					inputItem.addattribute("value",keyb.getText())
					item.server.setPref(item.key,inputItem@id, keyb.getText())
					if inputItem@option <> "hidden" then
						parentScreen.setItem(buttonIndex, {title: inputItem@label + ": "+ keyb.getText()})						
					end if
					keyb.close()
				else if msg.getIndex() =2 then
					keyb.close()
				end if				
			end if 
		end if
	end while



End Function



Function showBoolInput (inputItem,item,parentScreen, buttonIndex) 
	port = CreateObject("roMessagePort")
	screen = createObject("roListScreen")
	screen.setMessagePort(port)
	screen.setTitle(inputItem@label)
	screen.setHeader("")
	screen.setContent([{title: "true"},{title: "false"}])
	
	value = inputItem@value
	if value = ""  then
		value = inputItem@default
	endif
	
	if value = "true" then
		screen.setFocusedListItem(0)
	else if value = "true" then
		screen.setFocusedListItem(1)
	end if
	 
    
    
    
	screen.show()
	while true 
        msg = wait(0, screen.GetMessagePort()) 
        if type(msg) = "roListScreenEvent"
            if msg.isScreenClosed() then
                exit while
             else if msg.isListItemSelected() then
                if msg.getIndex() = 0 then
					inputItem.addattribute("value","true")
                    item.server.setPref(item.key,inputItem@id, "true")
                    parentScreen.setItem(buttonIndex, {title: inputItem@label + ": true"})
                    screen.close()
                else
					inputItem.addattribute("value","false")
                    item.server.setPref(item.key,inputItem@id, "false")
                    parentScreen.setItem(buttonIndex, {title: inputItem@label + ": false"})
                    screen.close()
                end if
            end if 
        end if
	end while

End Function


Function showEnumInput (inputItem,item,parentScreen, buttonIndex) 
	port = CreateObject("roMessagePort")
	screen = createObject("roListScreen")
	screen.setMessagePort(port)
	screen.setTitle(inputItem@label)
	screen.setHeader("")
	r = CreateObject("roRegex", "\|", "")
	valuesList = r.Split(inputItem@values)
	
	for each valueOption in valuesList
		print valueOption
		screen.AddContent({title: valueOption})
	next
	
	value = inputItem@value
	if value = ""  then
		value = inputItem@default
	endif
	
	screen.setFocusedListItem(value.toint())
	
	

	
	screen.show()
	while true 
        msg = wait(0, screen.GetMessagePort()) 
        if type(msg) = "roListScreenEvent"
            if msg.isScreenClosed() then
                exit while
             else if msg.isListItemSelected() then
                inputItem.addattribute("value",msg.getIndex().tostr())
                item.server.setPref(item.key,inputItem@id, msg.getIndex().tostr())
                parentScreen.setItem(buttonIndex, {title: inputItem@label + ": "+ valuesList[msg.getIndex()]})
                screen.close()
                
            end if 
        end if
	end while
End Function
