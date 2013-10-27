'*****************************************************************
'**  Security Pin Screen
'**
'*****************************************************************
Library "v30/bslCore.brs" 
'*****************************************************************
' This file introduces security pins for PLEX 
' Security PINS are simply any sequence of keys on the remote.
' Note that currently the keys are limited to just the direction keys
' but that can be changed at any time.
'
'The lowest level is accessed by createSecurityPINEntryScreen()
'and following the usual ViewController methods.  That said there are
'two defined methods and wrapper for these.   
'
'Security pins can be verified by calling VerifySecurityPin().  See the 
'function docs for exact specs but this opens up two screens.  The first
'screen is simply to keep the user from seeing the Home screen whenever
'a bad password is entered.  This has built-in functionality to exit plex
'when a bad password is entered.  It is also flexible enough to be 
'called at anytime, in preparation for multiple users down the road
'
'Security pins can be entered by calling SetSecurityPin().  See the 
'PreferencesScreens.brs for an implementation.  Otherwise is very
'similar to VerifySecurityPin()
'
'*****************************************************************

'*************************************************************************************
'
' Routines for drawing the actual PIN entry screen
'
'*************************************************************************************
'Creates screen for PIN entry
Function createSecurityPINEntryScreen(viewController) as object
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    obj.pinCode = ""
    obj.maxPinLength = 20
    obj.txtMasked = "**********************"
    obj.Screen = CreateObject("roImageCanvas")
    obj.Show = securityPINEntryShow
    obj.HandleMessage = securityPINEntryHandleMessage
    return obj
End Function

'Shows PIN entry screen.  OK Button is nice to have on for setting a new PIN.  if pinToVerify is set, then window will be closed once the PIN is entered
'if blocking=true then uses own messagePort and blocks global message loop
Sub securityPINEntryShow(newDialogText=invalid as object, newDialogText2=invalid as object, showOKButton=true as boolean, pinToVerify="" as string, blocking=false as boolean)
    canvasRect = m.screen.GetCanvasRect()   'get screen size
    dialogText = "Enter Security PIN for Plex." 'default text
    dialogText2 = "Enter PIN Code using direction arrows on your remote control."   'default text
    if newDialogText <> invalid then dialogText = newDialogText
    if newDialogText2 <> invalid then dialogText2 = newDialogText2
    pinRect = {}
    dlgRect = {} 
    dlgRect2 = {}
    fontRegistry = CreateObject("roFontRegistry")
    fontCurrent = fontRegistry.GetDefaultFont()

    pinRectHeight = int(fontCurrent.GetOneLineHeight() * 3)  'arbitrary number to create space for the large font with border area
    'use the middle of the screen for the PIN code 
    pinRect.w = canvasRect.w    
    pinRect.h = fontCurrent.GetOneLineHeight() 'actual size to use
    pinRect.x = 0 'int((canvasRect.w - pinRect.w) / 2)
    pinRect.y = int((canvasRect.h - pinRect.h) / 2)
    'use 1/4 vertical screen size above and below the pinRect
    dlgRect.w = int((canvasRect.w * 2) / 3) 'horizontally use 2/3 of screen 
    dlgRect.h = int((canvasRect.h * 1) / 4) 'use 1/4 of the vertical screen size  
    dlgRect.x = int((canvasRect.w - dlgRect.w) / 2)
    dlgRect.y = int(((canvasRect.h - pinRectHeight) / 2) - dlgRect.h)
    dlgRect2.w = dlgRect.w
    dlgRect2.h = dlgRect.h
    dlgRect2.x = dlgRect.x
    dlgRect2.y = int(((canvasRect.h + pinRectHeight) / 2))
    if (pinToVerify <> invalid) and (pinToVerify.Len() > 0) then
        m.pinToVerify = pinToVerify
    end if
    m.canvasItems = [
        { 
            Text:"[press arrows]"
            TextAttrs:{Color:"#AAAAAA", Font:"Huge",HAlign:"Center", VAlign:"Top",Direction:"LeftToRight"}
            TargetRect:pinRect
        },
        { 
            Text:dialogText
            TextAttrs:{Color:"#999999", Font:"Large",HAlign:"Center", VAlign:"Bottom", Direction:"LeftToRight"}
            TargetRect:dlgRect
        },
        { 
            Text:dialogText2
            TextAttrs:{Color:"#999999", Font:"Large",HAlign:"Center", VAlign:"Top", Direction:"LeftToRight"}
            TargetRect:dlgRect2
        },
    ] 
    m.screen.SetLayer(0, {Color:"#" + GetGlobalAA().Lookup("rfBGcolor"), CompositionMode:"Source"})   'Set opaque background as transparent doesn't draw correctly when content is updated  
    m.screen.SetRequireAllImagesToDraw(true)
    m.screen.SetLayer(1, m.canvasItems)
    if showOKButton = true then
        m.screen.AddButton(0, "OK")
    end if
    if blocking then    'use own message port and block the global message loop
        m.Port = CreateObject("roMessagePort")
    end if
    m.Screen.SetMessagePort(m.Port)
    m.Screen.Show()
    if blocking then
        while m.ScreenID = m.ViewController.Screens.Peek().ScreenID
            msg = wait(0, m.Port)
            m.HandleMessage(msg)
        end while    
    end if 
End Sub

Function securityPINEntryHandleMessage(msg) As Boolean
    handled = false

    'Debug("securityPINEntryHandleMessage")
    if type(msg) = "roImageCanvasEvent" then
        handled = true
        if msg.isScreenClosed() then
            'Debug("Exiting PIN screen")
            if m.ViewController.afterCloseCallback <> invalid
                m.ViewController.afterCloseCallback.pinCode = m.pinCode 'store pinCode in callback obj
            end if
            m.ViewController.PopScreen(m)
        else if (msg.isRemoteKeyPressed()) then
            codes = bslUniversalControlEventCodes() 'print codes
            i = msg.GetIndex()
            If i=codes.button_up_pressed Then
                m.pinCode = m.pinCode + "U"
            Else If i=codes.button_down_pressed Then
                m.pinCode = m.pinCode + "D"
            Else If i=codes.button_right_pressed Then
                m.pinCode = m.pinCode + "R"
            Else If i=codes.button_left_pressed Then
                m.pinCode = m.pinCode + "L"
            end if
            if (m.pinToVerify <> invalid) and (m.pinToVerify = m.pinCode) then  'Immediately exit once correct PIN is entered
                m.Screen.Close()
            else If i=codes.button_back_pressed Then   ' Back - Close the screen and exit without the pinCode
                m.pinCode = ""
                m.Screen.Close()
            Else If i=codes.button_select_pressed Then  'this only shows up when there is no OK button
                m.Screen.Close()
            else 
                'Debug("Key Pressed:" + AnyToString(msg.GetIndex()) + ", pinCode:" + AnyToString(m.pinCode))
                m.pinCode = left(m.pinCode, m.maxPinLength)   'limit to maxPinLength characters
                m.canvasItems[0].Text = left(m.txtMasked, m.pinCode.Len())  'm.canvasItems[0].Text = m.pinCode to display code
                m.Screen.SetLayer(1, m.canvasItems)
            end if
       else if (msg.isButtonPressed()) then 'OK Button was pressed
           m.Screen.Close()
       end if
    end if    
    return handled
End Function

'*************************************************************************************
'
' Routines for verifying a PIN, either at startup or on a user change
'
'*************************************************************************************
'Enter PIN code.  if exitAppOnFailure then this returns what happened by setting screen.pinOK=true (invalid if not).  Use the "Activated" function to catch this returning
'Returns the screen object to the facade screen
function VerifySecurityPin(viewController, pinToValidate as String, exitAppOnFailure=false as Boolean, numRetries=5 as Integer) as object
    'Debug("VerifySecurityPin")
    'create master screen for verifying PIN
    screen = createSecurityPinScreen(viewController, pinToValidate)

    'members for verifying code
    screen.numRetries = numRetries
    screen.exitAppOnFailure = exitAppOnFailure
    screen.Activate = VerifySecurityPinActivate

    ViewController.InitializeOtherScreen(screen, invalid)
    return screen
End function

'Called when screen pops to top after the PIN entering screen completes
sub VerifySecurityPinActivate(priorScreen)
    'Debug("VerifySecurityPinActivate")
    if priorScreen.pinCode = m.pinToValidate then
        m.pinOK = true
        if m.ViewController.EnterSecurityCode <> invalid then m.ViewController.EnterSecurityCode = false
        m.screen.Close()    'Closing from within Activate never calls the message loop to pop the screen
        m.ViewController.PopScreen(m)   'close this screen
    else 'if type(screen.Screen) = "roImageCanvas"  'ensure that there wasn't some type of pop-up 'update:removed as I can't see how this can occur
        if m.numRetries <= 0 then
            if m.exitAppOnFailure = true then  'Close the home screen which causes an exit
                m.ViewController.PopScreen(m.ViewController.home)
            else
                m.screen.Close()    'Closing from within Activate never calls the message loop to pop the screen
                m.ViewController.PopScreen(m)   'close this screen
            end if
        else
            m.numRetries = m.numRetries - 1
            screen = createSecurityPINEntryScreen(m.ViewController)
            m.ViewController.InitializeOtherScreen(screen, invalid)
            screen.Show("Incorrect Code. Re-enter Security PIN.", invalid, false, m.pinToValidate)
        end if
    end if
End sub

'*************************************************************************************
'
' Routines for entering a PIN
'
'*************************************************************************************
'Returns the screen object to the facade screen.  New PIN is returned in screen.newPinCode
function SetSecurityPin(viewController) as object
    'Debug("SetSecurityPin")
    'create master screen for verifying PIN
    screen = createSecurityPinScreen(viewController, "")

    'members for verifying code
    screen.newPinCode = ""
    screen.Activate = SetSecurityPinActivate

    ViewController.InitializeOtherScreen(screen, invalid)
    return screen
End function

'Called when screen pops to top after the PIN entering screen completes.  Called after either a PIN has been entered or cancelled
sub SetSecurityPinActivate(priorScreen)
    'Debug("SetSecurityPinActivate")
    if (priorScreen.pinCode = invalid) or (priorScreen.pinCode ="") then    'either no code was entered or it was cancelled
        m.newPinCode = ""  'report back that no pin was created
        m.ViewController.PopScreen(m)   'close this screen
    else if m.newPinCode = "" then  'just entered the first pinCode.  re-enter to validate
        m.newPinCode = priorScreen.pinCode
        screen = createSecurityPINEntryScreen(m.ViewController)
        m.ViewController.InitializeOtherScreen(screen, invalid)
        screen.Show("Re-enter the PIN code to verify.", invalid, false, m.newPincode)
    else 'verify 2nd pinCode
        if m.newPinCode <> priorScreen.pinCode then  'pinCodes don't match
            m.newPinCode = ""  'report back that no pin was created
        end if
        m.ViewController.PopScreen(m)   'close this screen
    endif
End sub


'*************************************************************************************
'
' Shared routines for creating and managing PIN entry screens
'
'*************************************************************************************
'Common function to create screen.  Used both when verifying and setting PIN
function createSecurityPinScreen(viewController, pinToValidate = "" as string) as object
    'Debug("createSecurityPinScreen")
    'create master screen for verifying PIN
    screen = CreateObject("roAssociativeArray")
    initBaseScreen(screen, viewController)
    'use a blank screen to reduce the annoying flashing to the Home screen when a bad password is entered
    screen.Screen = CreateObject("roImageCanvas") 'using this screen type as it's lightweight and will block whats behind it
    screen.Screen.SetMessagePort(m.Port)
    screen.Show = securityPinShow
    screen.pinToValidate = pinToValidate
    screen.HandleMessage = securityPinHandleMessage
    return screen
End function

Function securityPinHandleMessage(msg) As Boolean
    handled = false
    
    'Debug("securityPinHandleMessage")
    if type(msg) = "roImageCanvasEvent" then
        handled = true
        if msg.isScreenClosed() then
            'Debug("Exiting PIN Verification facade screen")
            m.ViewController.PopScreen(m)
        end if
    end if
    return handled
End Function

sub securityPinShow(newDialogText=invalid as object, newDialogText2=invalid as object)
    'Debug("securityPinShow")
    'create the actual screen that blocks the background
    m.screen.SetLayer(0, {Color:"#" + GetGlobalAA().Lookup("rfBGcolor"), CompositionMode:"Source"})   'Set opaque background to keep from flashing    
    m.screen.SetRequireAllImagesToDraw(true)
    m.screen.Show()
    'Create first PIN verification screen
    m.pinScreen = createSecurityPINEntryScreen(m.ViewController)
    m.ViewController.InitializeOtherScreen(m.pinScreen, invalid)
    m.pinScreen.Show(newDialogText, newDialogText2, false, m.pinToValidate)
End sub




