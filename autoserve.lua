local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ==========================================
-- CONFIGURATION
-- ==========================================
local TARGET_MIN = 0.75 -- Start of the rainbow/purple zone (0.0 to 1.0)
local TARGET_MAX = 0.95 -- End of the rainbow/purple zone
local DELAY_SECONDS = 3.0 -- Seconds to hold movement before looking for rainbow

-- Screen coordinates for your Toss button (percentages of your screen size)
-- Default is set to the bottom-right area (85% across, 80% down)
local TOSS_SCREEN_X = 0.85 
local TOSS_SCREEN_Y = 0.80 

-- Create UI Toggle Button
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TSO_FixedAutoHit"
screenGui.ResetOnSpawn = false
screenGui.Parent = (CoreGui:FindFirstChild("RobloxGui") and CoreGui) or playerGui

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 150, 0, 45)
button.Position = UDim2.new(0.5, -75, 0.08, 0)
button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
button.BackgroundTransparency = 0.5 -- Semi-transparent
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.TextTransparency = 0.1
button.Font = Enum.Font.GothamBold
button.TextSize = 13
button.Text = "Auto-Toss: OFF"
button.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

local enabled = false
local enableTime = 0

-- ==========================================
-- DRAGGABLE + TAP TOGGLE LOGIC (MOBILE)
-- ==========================================
local dragging = false
local dragStart = nil
local startPos = nil
local moved = false

button.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		moved = false
		dragStart = input.Position
		startPos = button.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.MouseMovement) then
		local delta = input.Position - dragStart
		if delta.Magnitude > 8 then
			moved = true
			button.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		if dragging then
			dragging = false
			if not moved then
				enabled = not enabled
				if enabled then
					enableTime = os.clock()
					button.Text = "Auto-Toss: ON"
					button.BackgroundColor3 = Color3.fromRGB(40, 170, 80)
				else
					button.Text = "Auto-Toss: OFF"
					button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
					pcall(function()
						local char = player.Character
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if hum then hum:Move(Vector3.zero, true) end
					end)
				end
			end
		end
	end
end)

-- ==========================================
-- INDICATOR & DIRECT SCREEN-TAP LOGIC
-- ==========================================
local function getActiveIndicator()
	for _, desc in ipairs(playerGui:GetDescendants()) do
		if desc:IsA("GuiObject") and (desc.Name == "Indicator" or desc.Name == "Tracker" or desc.Name == "Arrow") then
			if desc.Parent and (desc.Parent.Name:lower():find("bar") or desc.Parent.Name:lower():find("power") or desc.Parent.Name:lower():find("charge")) then
				return desc
			end
		end
	end
	return nil
end

local function triggerTossButton()
	local cam = workspace.CurrentCamera
	if VirtualInputManager and cam then
		local screenX = cam.ViewportSize.X * TOSS_SCREEN_X
		local screenY = cam.ViewportSize.Y * TOSS_SCREEN_Y
		
		-- Simulate touch down (State 0) then touch up (State 2) at the exact coordinates
		VirtualInputManager:SendTouchEvent(1, 0, screenX, screenY)
		task.wait(0.03)
		VirtualInputManager:SendTouchEvent(1, 2, screenX, screenY)
	end
end

RunService.RenderStepped:Connect(function()
	if not enabled then return end

	-- 1. Walk straight forward relative to the character's facing direction
	pcall(function()
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		if humanoid and rootPart then
			local forwardDir = rootPart.CFrame.LookVector
			humanoid:Move(Vector3.new(forwardDir.X, 0, forwardDir.Z).Unit, false)
		end
	end)

	-- 2. Wait 3 seconds before checking for rainbow
	if os.clock() - enableTime < DELAY_SECONDS then
		return
	end

	-- 3. Check if indicator is in the rainbow zone, then toss & stop
	local indicator = getActiveIndicator()
	if indicator and indicator.Visible then
		local parent = indicator.Parent
		if parent and parent:IsA("GuiObject") then
			local relativeX = (indicator.AbsolutePosition.X - parent.AbsolutePosition.X) / parent.AbsoluteSize.X

			if relativeX >= TARGET_MIN and relativeX <= TARGET_MAX then
				enabled = false
				button.Text = "Auto-Toss: OFF"
				button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

				pcall(function()
					local char = player.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if hum then hum:Move(Vector3.zero, true) end
				end)

				triggerTossButton()
			end
		end
	end
end)
