/*
    Ring Raylib for Android — Demo
    Multi-screen showcase: menu, touch demo, gui controls, info.
*/

load "raylib.ring"

InitWindow(0, 0, "Ring Raylib Demo")
screenW = GetScreenWidth()
screenH = GetScreenHeight()
if screenW = 0 or screenH = 0
    screenW = GetMonitorWidth(0)
    screenH = GetMonitorHeight(0)
ok
if screenW = 0 or screenH = 0
    screenW = 720
    screenH = 1280
ok
if screenW > screenH
    nTmp = screenW
    screenW = screenH
    screenH = nTmp
ok

SetTargetFPS(60)

# UI scale — baseline 720x1280, fits any device, capped to avoid bitmap blur
uiScale = screenW / 720.0
tmpScale = screenH / 1280.0
if tmpScale < uiScale
    uiScale = tmpScale
ok
if uiScale < 1
    uiScale = 1
ok
if uiScale > 2
    uiScale = 2
ok

# State
currentScreen = 1          # 1=menu, 2=touch, 3=gui, 4=info
circleRadius = ui(70)
circleColor = BLUE
bgColor = RAYWHITE
showFps = true
animTime = 0

# Touch state
touchX = 0
touchY = 0
touchCount = 0
lastGesture = GESTURE_NONE

# Slider demo
sliderVal = 50
progressVal = 0

# Toggle
soundOn = true

# ComboBox
comboActive = 0

# Spinner
spinVal = 0

# Checkbox
check1 = true
check2 = false

# Toggle group
tgActive = 0

# ListView
listScroll = 0
listActive = 0

# Color picker
pickColor = RED

while !WindowShouldClose()
    animTime += GetFrameTime()
    screenW = GetScreenWidth()
    screenH = GetScreenHeight()
    if screenW > screenH
        nTmp = screenW
        screenW = screenH
        screenH = nTmp
    ok
    uiScale = screenW / 720.0
    tmpScale = screenH / 1280.0
    if tmpScale < uiScale
        uiScale = tmpScale
    ok
    if uiScale < 1
        uiScale = 1
    ok
    if uiScale > 2
        uiScale = 2
    ok


    # Scale raygui globally: 0=DEFAULT, 16=TEXT_SIZE, 17=TEXT_SPACING, 12=BORDER_WIDTH
    GuiSetStyle(0, 16, ui(20))
    GuiSetStyle(0, 17, ui(1))
    GuiSetStyle(0, 12, ui(2))
    GuiSetStyle(12, 16, ui(30))
    GuiSetStyle(12, 17, ui(8))
    GuiSetStyle(0, 13, ui(8))

    touchCount = GetTouchPointCount()
    if touchCount > 0
        touchX = GetTouchX()
        touchY = GetTouchY()
    ok

    if IsGestureDetected(GESTURE_TAP)
        lastGesture = GESTURE_TAP
    ok
    if IsGestureDetected(GESTURE_DOUBLETAP)
        lastGesture = GESTURE_DOUBLETAP
    ok
    if IsGestureDetected(GESTURE_SWIPE_RIGHT)
        lastGesture = GESTURE_SWIPE_RIGHT
        if currentScreen > 1
            currentScreen--
        ok
    ok
    if IsGestureDetected(GESTURE_SWIPE_LEFT)
        lastGesture = GESTURE_SWIPE_LEFT
        if currentScreen < 4
            currentScreen++
        ok
    ok

    BeginDrawing()
    ClearBackground(bgColor)

    if currentScreen = 1
        drawMenu()
    but currentScreen = 2
        drawTouch()
    but currentScreen = 3
        drawGui()
    but currentScreen = 4
        drawInfo()
    ok

    # Bottom nav bar
    navH = ui(85)
    navY = screenH - navH
    DrawRectangle(0, navY, screenW, navH, Fade(DARKGRAY, 0.9))
    DrawLine(0, navY, screenW, navY, LIGHTGRAY)

    btnW = screenW / 4
    navLabels = ["Menu", "Touch", "GUI", "Info"]
    for i = 1 to 4
        x = (i-1) * btnW
        if GuiButton(Rectangle(x, navY, btnW, navH), navLabels[i])
            currentScreen = i
        ok
        if i = currentScreen
            DrawRectangle(x, navY, btnW, navH, Fade(BLUE, 0.3))
        ok
    next

    if showFps
        DrawFPS(ui(10), ui(10))
    ok

    EndDrawing()
end
CloseWindow()

func drawMenu()
    title = "Ring Raylib 5.5"
    subTitle = "for Android"
    tw = MeasureText(title, ui(42))
    DrawText(title, (screenW - tw)/2, screenH*0.18, ui(42), DARKBLUE)
    tw2 = MeasureText(subTitle, ui(22))
    DrawText(subTitle, (screenW - tw2)/2, screenH*0.18 + ui(52), ui(22), GRAY)

    # Animated circle — all radii scaled
    cx = screenW/2
    cy = screenH*0.42
    r = ui(55) + sin(animTime*3) * ui(14)
    DrawCircle(cx, cy, r, Fade(BLUE, 0.5 + 0.3*sin(animTime*2)))
    DrawCircleLines(cx, cy, r + ui(14), Fade(DARKBLUE, 0.4))
    DrawCircleLines(cx, cy, r + ui(26), Fade(SKYBLUE, 0.2))

    # hint — split if too wide, guarantees fit on 480px devices
    label = "Swipe left/right or tap buttons below"
    fs = ui(16)
    lw = MeasureText(label, fs)
    if lw > screenW - ui(40)
        fs = ui(14)
        lw = MeasureText(label, fs)
    ok
    DrawText(label, (screenW - lw)/2, screenH*0.60, fs, DARKGRAY)

    # Touch info
    info = "Screen: " + screenW + "x" + screenH
    iw = MeasureText(info, ui(18))
    DrawText(info, (screenW - iw)/2, screenH*0.66, ui(18), GRAY)

    if touchCount > 0
        DrawCircle(touchX, touchY, ui(42), Fade(RED, 0.4))
    ok
end
func drawTouch()
    DrawText("Touch Demo", ui(20), ui(24), ui(36), DARKBLUE)
    DrawRectangle(ui(20), ui(68), screenW - ui(40), ui(4), BLUE)

    # Big touch area — taller
    areaY = ui(85)
    areaH = screenH - areaY - ui(175)
    DrawRectangle(ui(20), areaY, screenW - ui(40), areaH, Fade(LIGHTGRAY, 0.3))
    DrawRectangleLines(ui(20), areaY, screenW - ui(40), areaH, DARKGRAY)

    if touchCount > 0
        circleColor = RED
        DrawCircle(touchX, touchY, circleRadius, circleColor)
        DrawCircleLines(touchX, touchY, circleRadius, DARKBLUE)
    else
        circleColor = BLUE
        msg = "Touch anywhere"
        mw = MeasureText(msg, ui(24))
        DrawText(msg, (screenW - mw)/2, areaY + areaH/2, ui(24), GRAY)
    ok

    # Stats panel
    statY = screenH - ui(165)
    DrawRectangle(ui(20), statY, screenW - ui(40), ui(75), Fade(DARKGRAY, 0.85))
    DrawText("Points: " + touchCount + "  X: " + touchX + "  Y: " + touchY, ui(30), statY + ui(14), ui(22), WHITE)

    gestureName = "NONE"
    switch lastGesture
        on GESTURE_TAP gestureName = "TAP"
        on GESTURE_DOUBLETAP gestureName = "DOUBLE TAP"
        on GESTURE_HOLD gestureName = "HOLD"
        on GESTURE_SWIPE_RIGHT gestureName = "SWIPE RIGHT"
        on GESTURE_SWIPE_LEFT gestureName = "SWIPE LEFT"
        on GESTURE_SWIPE_UP gestureName = "SWIPE UP"
        on GESTURE_SWIPE_DOWN gestureName = "SWIPE DOWN"
    off
    DrawText("Gesture: " + gestureName, ui(30), statY + ui(42), ui(20), YELLOW)

    # Radius slider
    DrawText("Radius", ui(20), statY - ui(38), ui(18), DARKGRAY)
    circleRadius = GuiSlider(Rectangle(ui(90), statY - ui(42), screenW - ui(130), ui(32)), "", circleRadius, ui(10), ui(150), true)

func drawGui()
    DrawText("GUI Controls", ui(20), ui(24), ui(36), DARKBLUE)
    DrawRectangle(ui(20), ui(68), screenW - ui(40), ui(4), BLUE)

    y = ui(85)
    rowH = ui(62)

    # Button row
    if GuiButton(Rectangle(ui(20), y, screenW/2 - ui(25), rowH), "Click Me")
        bgColor = RayLibColor(GetRandomValue(200, 255), GetRandomValue(200, 255), GetRandomValue(200, 255), 255)
    ok
    if GuiButton(Rectangle(screenW/2 + ui(5), y, screenW/2 - ui(25), rowH), "Reset BG")
        bgColor = RAYWHITE
    ok
    y += rowH + ui(14)

    # Slider
    DrawText("Value: " + sliderVal, ui(20), y, ui(20), DARKGRAY)
    sliderVal = GuiSlider(Rectangle(ui(120), y - ui(6), screenW - ui(140), ui(32)), "", sliderVal, 0, 100, true)
    y += ui(48)

    # Progress bar
    progressVal = sliderVal
    GuiProgressBar(Rectangle(ui(20), y, screenW - ui(40), ui(32)), "", progressVal, 0, 100, true)
    y += ui(48)

    # Checkbox boxes
    check1 = GuiCheckBox(Rectangle(ui(20), y, ui(36), ui(36)), "Show FPS", check1)
    showFps = check1
    check2 = GuiCheckBox(Rectangle(screenW/2, y, ui(36), ui(36)), "Sound", check2)
    soundOn = check2
    y += ui(52)

    # Toggle group
    tgActive = GuiToggleGroup(Rectangle(ui(20), y, screenW - ui(40), rowH), "Option A;Option B;Option C", tgActive)
    y += rowH + ui(14)

    # Value control — Spinner not registered, use SliderBar
    DrawText("" + spinVal, ui(20), y + ui(10), ui(18), DARKGRAY)
    spinVal = GuiSliderBar(Rectangle(ui(70), y, screenW - ui(90), ui(32)), "", spinVal, 0, 100, true)
    y += ui(48)

    # ComboBox
    comboActive = GuiComboBox(Rectangle(ui(20), y, screenW - ui(40), ui(48)), "Red;Green;Blue;Yellow", comboActive)
    switch comboActive
        on 0 pickColor = RED
        on 1 pickColor = GREEN
        on 2 pickColor = BLUE
        on 3 pickColor = YELLOW
    off
    y += ui(62)

    # Color preview
    DrawText("Color", ui(20), y + ui(10), ui(20), DARKGRAY)
    DrawRectangle(ui(90), y, screenW - ui(110), ui(45), pickColor)
    DrawRectangleLines(ui(90), y, screenW - ui(110), ui(45), DARKGRAY)
    y += ui(60)

    # ListView
    listActive = GuiListView(Rectangle(ui(20), y, screenW - ui(40), ui(130)), "Item 1;Item 2;Item 3;Item 4", listActive, listScroll, false)

func drawInfo()
    DrawText("Info", ui(20), ui(24), ui(36), DARKBLUE)
    DrawRectangle(ui(20), ui(68), screenW - ui(40), ui(4), BLUE)

    y = ui(95)
    lh = ui(36)

    info = [
        "Ring " + version(),
        "Raylib 5.5",
        "Raygui 5.0",
        "Screen: " + screenW + "x" + screenH,
        "FPS: " + GetFPS(),
        "Touch points: " + touchCount,
        "Frame time: " + GetFrameTime(),
        "Time: " + GetTime()
    ]

    for item in info
        DrawText(item, ui(30), y, ui(22), DARKGRAY)
        y += lh
    next

    # raylib logo placeholder
    cx = screenW/2
    cy = screenH - ui(165)
    DrawCircle(cx, cy, ui(52), Fade(BLUE, 0.6))
    DrawCircleLines(cx, cy, ui(64), DARKBLUE)
    DrawText("R", cx - ui(13), cy - ui(19), ui(38), WHITE)

func ui(n)
    return n * uiScale