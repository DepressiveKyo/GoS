local Heroes = {"All"} -- Works for all heroes

-- Constants and globals
local myHero = myHero

-- Utility functions
local function GetDistance(p1, p2)
    if not p1 or not p2 then return math.huge end
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return math.sqrt(dx * dx + dz * dz)
end

-- Position Tracker Class
class "PositionTracker"

function PositionTracker:__init()
    self.lastKeyPress = {
        numpad1 = 0,
        numpad2 = 0
    }
    self.keyDelay = 250 -- Delay between key presses to avoid spam
    
    self:LoadMenu()
    
    -- Callbacks
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    print("Position Tracker loaded successfully!")
    print("Key 1: Print Hero Position")
    print("Key 2: Print Mouse Position")
    print("Note: Configure keys in the menu")
end

function PositionTracker:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "PositionTracker", name = "Position Tracker - Depressive"})
    
    -- Main Settings
    self.Menu:MenuElement({id = "enabled", name = "Enable Position Tracker", value = true})
    self.Menu:MenuElement({id = "showDistance", name = "Show distance between positions", value = true})
    self.Menu:MenuElement({id = "keyDelay", name = "Key press delay (ms)", value = 250, min = 100, max = 1000, step = 50})
    
    -- Keys
    self.Menu:MenuElement({type = MENU, id = "keys", name = "Keybinds"})
    self.Menu.keys:MenuElement({id = "heroPos", name = "Print Hero Position", key = string.byte("1"), toggle = false, value = false}) -- Numpad 1
    self.Menu.keys:MenuElement({id = "mousePos", name = "Print Mouse Position", key = string.byte("2"), toggle = false, value = false}) -- Numpad 2
    
    -- Drawing
    self.Menu:MenuElement({type = MENU, id = "drawing", name = "Drawing"})
    self.Menu.drawing:MenuElement({id = "heroPos", name = "Draw Hero Position", value = true})
    self.Menu.drawing:MenuElement({id = "mousePos", name = "Draw Mouse Position", value = true})
    self.Menu.drawing:MenuElement({id = "line", name = "Draw Line Between Positions", value = true})
end

function PositionTracker:Draw()
    if myHero.dead or not self.Menu.enabled:Value() then return end
    
    -- Draw hero position
    if self.Menu.drawing.heroPos:Value() then
        Draw.Circle(myHero.pos, 80, Draw.Color(100, 0x00, 0xFF, 0x00))
        local heroText = string.format("Hero: %.0f, %.0f", myHero.pos.x, myHero.pos.z)
        Draw.Text(heroText, 16, myHero.pos2D.x - 50, myHero.pos2D.y - 60, Draw.Color(255, 0, 255, 0))
    end
    
    -- Draw mouse position
    if self.Menu.drawing.mousePos:Value() then
        local mousePos = Game.mousePos()
        if mousePos then
            Draw.Circle(mousePos, 60, Draw.Color(100, 0xFF, 0x00, 0x00))
            local mouseText = string.format("Mouse: %.0f, %.0f", mousePos.x, mousePos.z)
            local screenPos = mousePos:To2D()
            Draw.Text(mouseText, 16, screenPos.x - 50, screenPos.y - 40, Draw.Color(255, 255, 0, 0))
        end
    end
    
    -- Draw line between hero and mouse
    if self.Menu.drawing.line:Value() then
        local mousePos = Game.mousePos()
        if mousePos then
            Draw.Line(myHero.pos:To2D(), mousePos:To2D(), 2, Draw.Color(100, 0xFF, 0xFF, 0x00))
            
            -- Show distance in the middle of the line
            if self.Menu.showDistance:Value() then
                local distance = GetDistance(myHero.pos, mousePos)
                local midPoint = Vector(
                    (myHero.pos.x + mousePos.x) / 2,
                    myHero.pos.y,
                    (myHero.pos.z + mousePos.z) / 2
                )
                local midScreen = midPoint:To2D()
                local distanceText = string.format("Distance: %.0f", distance)
                Draw.Text(distanceText, 14, midScreen.x - 40, midScreen.y, Draw.Color(255, 255, 255, 0))
            end
        end
    end
end

function PositionTracker:Tick()
    if myHero.dead or Game.IsChatOpen() or not self.Menu.enabled:Value() then
        return
    end
    
    self.keyDelay = self.Menu.keyDelay:Value()
    
    -- Check Hero Position Key
    if self.Menu.keys.heroPos:Value() then
        if GetTickCount() - self.lastKeyPress.numpad1 > self.keyDelay then
            self:PrintHeroPosition()
            self.lastKeyPress.numpad1 = GetTickCount()
        end
    end
    
    -- Check Mouse Position Key
    if self.Menu.keys.mousePos:Value() then
        if GetTickCount() - self.lastKeyPress.numpad2 > self.keyDelay then
            self:PrintMousePosition()
            self.lastKeyPress.numpad2 = GetTickCount()
        end
    end
end

function PositionTracker:PrintHeroPosition()
    local pos = myHero.pos
    local heroName = myHero.charName or "Unknown"
    
    print("========================================")
    print("HERO POSITION - " .. heroName)
    print("========================================")
    print(string.format("X: %.2f", pos.x))
    print(string.format("Y: %.2f", pos.y))
    print(string.format("Z: %.2f", pos.z))
    print(string.format("Vector: Vector(%.2f, %.2f, %.2f)", pos.x, pos.y, pos.z))
    print("========================================")
end

function PositionTracker:PrintMousePosition()
    local mousePos = Game.mousePos()
    
    if not mousePos then
        print("========================================")
        print("MOUSE POSITION - ERROR")
        print("========================================")
        print("Could not get mouse position")
        print("========================================")
        return
    end
    
    print("========================================")
    print("MOUSE POSITION")
    print("========================================")
    print(string.format("X: %.2f", mousePos.x))
    print(string.format("Y: %.2f", mousePos.y))
    print(string.format("Z: %.2f", mousePos.z))
    print(string.format("Vector: Vector(%.2f, %.2f, %.2f)", mousePos.x, mousePos.y, mousePos.z))
    
    -- Also show distance from hero
    if self.Menu.showDistance:Value() then
        local distance = GetDistance(myHero.pos, mousePos)
        print(string.format("Distance from Hero: %.2f units", distance))
    end
    print("========================================")
end

-- Initialize the script
DelayAction(function()
    _G.PositionTracker = PositionTracker()
end, 1.0)