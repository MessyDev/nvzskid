--[[

	Universal Aimbot Module by Exunys © CC0 1.0 Universal (2023 - 2024)
	https://github.com/Exunys

]]

--// Cache

local game, workspace = game, workspace
local getrawmetatable, getmetatable, setmetatable, pcall, getgenv, next, tick = getrawmetatable, getmetatable, setmetatable, pcall, getgenv, next, tick
local Vector2new, Vector3zero, CFramenew, Color3fromRGB, Color3fromHSV, Drawingnew, TweenInfonew = Vector2.new, Vector3.zero, CFrame.new, Color3.fromRGB, Color3.fromHSV, Drawing.new, TweenInfo.new
local getupvalue, mousemoverel, tablefind, tableremove, stringlower, stringsub, mathclamp = debug.getupvalue, mousemoverel or (Input and Input.MouseMove), table.find, table.remove, string.lower, string.sub, math.clamp

local GameMetatable = getrawmetatable and getrawmetatable(game) or {
	-- Auxillary functions - if the executor doesn't support "getrawmetatable".

	__index = function(self, Index)
		return self[Index]
	end,

	__newindex = function(self, Index, Value)
		self[Index] = Value
	end
}

local __index = GameMetatable.__index
local __newindex = GameMetatable.__newindex

local getrenderproperty, setrenderproperty = getrenderproperty or __index, setrenderproperty or __newindex

local GetService = __index(game, "GetService")

--// Services

local RunService = GetService(game, "RunService")
local UserInputService = GetService(game, "UserInputService")
local TweenService = GetService(game, "TweenService")
local Players = GetService(game, "Players")

--// Service Methods

local LocalPlayer = __index(Players, "LocalPlayer")
local Camera = __index(workspace, "CurrentCamera")

local FindFirstChild, FindFirstChildOfClass = __index(game, "FindFirstChild"), __index(game, "FindFirstChildOfClass")

local function SafeFindFirstChild(Object, ...)
        return typeof(Object) == "Instance" and FindFirstChild(Object, ...)
end

local function SafeFindFirstChildOfClass(Object, ...)
        return typeof(Object) == "Instance" and FindFirstChildOfClass(Object, ...)
end
local GetDescendants = __index(game, "GetDescendants")
local WorldToViewportPoint = __index(Camera, "WorldToViewportPoint")
local GetPartsObscuringTarget = __index(Camera, "GetPartsObscuringTarget")
local GetMouseLocation = __index(UserInputService, "GetMouseLocation")
local GetPlayers = __index(Players, "GetPlayers")
local GetPlayerFromCharacter = __index(Players, "GetPlayerFromCharacter")
local GetChildren = __index(workspace, "GetChildren")

--// Variables

local RequiredDistance, Typing, Running, ServiceConnections, Animation, OriginalSensitivity = 2000, false, false, {}
local Connect, Disconnect = __index(game, "DescendantAdded").Connect

--[[
local Degrade = false

do
	xpcall(function()
		local TemporaryDrawing = Drawingnew("Line")
		getrenderproperty = getupvalue(getmetatable(TemporaryDrawing).__index, 4)
		setrenderproperty = getupvalue(getmetatable(TemporaryDrawing).__newindex, 4)
		TemporaryDrawing.Remove(TemporaryDrawing)
	end, function()
		Degrade, getrenderproperty, setrenderproperty = true, function(Object, Key)
			return Object[Key]
		end, function(Object, Key, Value)
			Object[Key] = Value
		end
	end)

	local TemporaryConnection = Connect(__index(game, "DescendantAdded"), function() end)
	Disconnect = TemporaryConnection.Disconnect
	Disconnect(TemporaryConnection)
end
]]

--// Checking for multiple processes

if ExunysDeveloperAimbot and ExunysDeveloperAimbot.Exit then
	ExunysDeveloperAimbot:Exit()
end

--// Environment

getgenv().ExunysDeveloperAimbot = {
	DeveloperSettings = {
		UpdateMode = "RenderStepped",
		TeamCheckOption = "TeamColor",
		RainbowSpeed = 1 -- Bigger = Slower
	},

        Settings = {
                Enabled = true,

                DetectionMode = "Both", -- "Players", "NPCs" or "Both"
                TeamCheck = false,
                AliveCheck = true,
                WallCheck = false,

		OffsetToMoveDirection = false,
		OffsetIncrement = 15,

		Sensitivity = 0, -- Animation length (in seconds) before fully locking onto target
		Sensitivity2 = 3.5, -- mousemoverel Sensitivity

		LockMode = 1, -- 1 = CFrame; 2 = mousemoverel
		LockPart = "Head", -- Body part to lock on

		TriggerKey = Enum.UserInputType.MouseButton2,
		Toggle = false
	},

	FOVSettings = {
		Enabled = true,
		Visible = true,

		Radius = 90,
		NumSides = 60,

		Thickness = 1,
		Transparency = 1,
		Filled = false,

		RainbowColor = false,
		RainbowOutlineColor = false,
		Color = Color3fromRGB(255, 255, 255),
		OutlineColor = Color3fromRGB(0, 0, 0),
		LockedColor = Color3fromRGB(255, 150, 150)
	},

	Blacklisted = {},
	FOVCircleOutline = Drawingnew("Circle"),
	FOVCircle = Drawingnew("Circle")
}

local Environment = getgenv().ExunysDeveloperAimbot

setrenderproperty(Environment.FOVCircle, "Visible", false)
setrenderproperty(Environment.FOVCircleOutline, "Visible", false)

--// Core Functions

local FixUsername = function(String)
	local Result

	for _, Value in next, GetPlayers(Players) do
		local Name = __index(Value, "Name")

		if stringsub(stringlower(Name), 1, #String) == stringlower(String) then
			Result = Name
		end
	end

	return Result
end

local GetRainbowColor = function()
	local RainbowSpeed = Environment.DeveloperSettings.RainbowSpeed

	return Color3fromHSV(tick() % RainbowSpeed / RainbowSpeed, 1, 1)
end

local ConvertVector = function(Vector)
	return Vector2new(Vector.X, Vector.Y)
end

local CancelLock = function()
	Environment.Locked = nil

	local FOVCircle = Environment.FOVCircle--Degrade and Environment.FOVCircle or Environment.FOVCircle.__OBJECT

	setrenderproperty(FOVCircle, "Color", Environment.FOVSettings.Color)
	__newindex(UserInputService, "MouseDeltaSensitivity", OriginalSensitivity)

	if Animation then
		Animation:Cancel()
	end
end

local function IsModel(Object)
        return Object and Object.IsA and Object:IsA("Model")
end

local function GetLockPart(Object, LockPart)
        if not IsModel(Object) then
                return
        end

        local Part = SafeFindFirstChild(Object, LockPart)

        if not Part then
                local Success, PrimaryPart = pcall(__index, Object, "PrimaryPart")

                Part = Success and PrimaryPart or nil
        end

        return Part
end

local function GetWorldDistance(Position)
        local LocalCharacter = __index(LocalPlayer, "Character")
        local LocalPart = LocalCharacter and (__index(LocalCharacter, "PrimaryPart") or SafeFindFirstChild(LocalCharacter, "HumanoidRootPart") or SafeFindFirstChild(LocalCharacter, "Head"))

        if not LocalPart then
                return math.huge
        end

        return (__index(LocalPart, "Position") - Position).Magnitude
end

local function IsVisible(TargetPart, LocalCharacter)
        if not TargetPart or not LocalCharacter then
                return false
        end

        local BlacklistTable = GetDescendants(LocalCharacter)
        local TargetParent = __index(TargetPart, "Parent")

        if TargetParent then
                for _, Value in next, GetDescendants(TargetParent) do
                        BlacklistTable[#BlacklistTable + 1] = Value
                end
        end

        local Parts = GetPartsObscuringTarget(Camera, {__index(TargetPart, "Position")}, BlacklistTable)

        for _, Part in next, Parts do
                local Success, CanCollide = pcall(__index, Part, "CanCollide")

                if Success and CanCollide then
                        return false
                end
        end

        return true
end

local GetClosestPlayer = function()
        local Settings = Environment.Settings
        local LockPartName = Settings.LockPart
        local Units = SafeFindFirstChild(workspace, "Units")
        local LocalCharacter = __index(LocalPlayer, "Character")

        RequiredDistance = Environment.FOVSettings.Enabled and Environment.FOVSettings.Radius or 2000

        local LocalTeamInstance = LocalCharacter and SafeFindFirstChild(LocalCharacter, "TEAM")
        local LocalTeam = LocalTeamInstance and __index(LocalTeamInstance, "Value")

        local BestCandidate, BestScreenDistance, BestWorldDistance

        for _, Character in next, Units and GetChildren(Units) or {} do
                if not IsModel(Character) then
                        continue
                end

                local Humanoid = SafeFindFirstChildOfClass(Character, "Humanoid")
                local LockPartInstance = GetLockPart(Character, LockPartName)
                local Player = Character and GetPlayerFromCharacter(Players, Character)
                local IsPlayer = Player ~= nil

                if Settings.DetectionMode == "Players" and not IsPlayer or Settings.DetectionMode == "NPCs" and IsPlayer then
                        continue
                end

                local Identifier = (IsPlayer and __index(Player, "Name")) or __index(Character, "Name")

                if Character == LocalCharacter or IsPlayer and Player == LocalPlayer or tablefind(Environment.Blacklisted, Identifier) or not LockPartInstance or not Humanoid then
                        continue
                end

                local TeamValue = SafeFindFirstChild(Character, "TEAM")
                TeamValue = TeamValue and __index(TeamValue, "Value")

                if Settings.TeamCheck and TeamValue and LocalTeam and TeamValue == LocalTeam then
                        continue
                end

                if Settings.AliveCheck and __index(Humanoid, "Health") <= 0 then
                        continue
                end

                local Vector, OnScreen, MouseDistance = WorldToViewportPoint(Camera, __index(LockPartInstance, "Position"))
                Vector = ConvertVector(Vector)
                MouseDistance = (GetMouseLocation(UserInputService) - Vector).Magnitude

                if MouseDistance > RequiredDistance or not OnScreen then
                        continue
                end

                if Settings.WallCheck and LocalCharacter and not IsVisible(LockPartInstance, LocalCharacter) then
                        continue
                end

                local WorldDistance = GetWorldDistance(__index(LockPartInstance, "Position"))

                if not BestCandidate or WorldDistance < BestWorldDistance or WorldDistance == BestWorldDistance and MouseDistance < BestScreenDistance then
                        BestCandidate = {Character = Character, Player = Player, Part = LockPartInstance, ScreenDistance = MouseDistance, WorldDistance = WorldDistance}
                        BestScreenDistance = MouseDistance
                        BestWorldDistance = WorldDistance
                end
        end

        if not BestCandidate then
                if Environment.Locked then
                        CancelLock()
                end

                return
        end

                local LockedEntry = Environment.Locked
                local LockedCharacter = LockedEntry and LockedEntry.Character
                local LockedPart = LockedEntry and (LockedEntry.Part or GetLockPart(LockedCharacter, LockPartName))

        if not LockedPart or Settings.WallCheck and not IsVisible(LockedPart, LocalCharacter) then
                LockedEntry = nil
        end

        if not LockedEntry or BestWorldDistance < (GetWorldDistance(__index(LockedPart, "Position")) or math.huge) then
                Environment.Locked = BestCandidate
        elseif Settings.WallCheck and not IsVisible(LockedPart, LocalCharacter) then
                CancelLock()
        end
end

local Load = function()
	OriginalSensitivity = __index(UserInputService, "MouseDeltaSensitivity")

	local Settings, FOVCircle, FOVCircleOutline, FOVSettings, Offset = Environment.Settings, Environment.FOVCircle, Environment.FOVCircleOutline, Environment.FOVSettings

	--[[
	if not Degrade then
		FOVCircle, FOVCircleOutline = FOVCircle.__OBJECT, FOVCircleOutline.__OBJECT
	end
	]]

	ServiceConnections.RenderSteppedConnection = Connect(__index(RunService, Environment.DeveloperSettings.UpdateMode), function()
		local OffsetToMoveDirection, LockPart = Settings.OffsetToMoveDirection, Settings.LockPart

		if FOVSettings.Enabled and Settings.Enabled then
			for Index, Value in next, FOVSettings do
				if Index == "Color" then
					continue
				end

				if pcall(getrenderproperty, FOVCircle, Index) then
					setrenderproperty(FOVCircle, Index, Value)
					setrenderproperty(FOVCircleOutline, Index, Value)
				end
			end

			setrenderproperty(FOVCircle, "Color", (Environment.Locked and FOVSettings.LockedColor) or FOVSettings.RainbowColor and GetRainbowColor() or FOVSettings.Color)
			setrenderproperty(FOVCircleOutline, "Color", FOVSettings.RainbowOutlineColor and GetRainbowColor() or FOVSettings.OutlineColor)

			setrenderproperty(FOVCircleOutline, "Thickness", FOVSettings.Thickness + 1)
			setrenderproperty(FOVCircle, "Position", GetMouseLocation(UserInputService))
			setrenderproperty(FOVCircleOutline, "Position", GetMouseLocation(UserInputService))
		else
			setrenderproperty(FOVCircle, "Visible", false)
			setrenderproperty(FOVCircleOutline, "Visible", false)
		end

                if Running and Settings.Enabled then
                        GetClosestPlayer()

                        if Environment.Locked then
                                local LockedEntry = Environment.Locked
                                local LockedCharacter = LockedEntry and LockedEntry.Character
local LockedHumanoid = LockedCharacter and SafeFindFirstChildOfClass(LockedCharacter, "Humanoid")
                                Offset = OffsetToMoveDirection and LockedHumanoid and __index(LockedHumanoid, "MoveDirection") * (mathclamp(Settings.OffsetIncrement, 1, 30) / 10) or Vector3zero

                                local LockedPart = LockedEntry and (LockedEntry.Part or GetLockPart(LockedCharacter, LockPart))

                                if not LockedPart then
                                        CancelLock()
                                        return
                                end

                                local LockedPosition_Vector3 = __index(LockedPart, "Position")
                                local LockedPosition = WorldToViewportPoint(Camera, LockedPosition_Vector3 + Offset)

				if Environment.Settings.LockMode == 2 then
					mousemoverel((LockedPosition.X - GetMouseLocation(UserInputService).X) / Settings.Sensitivity2, (LockedPosition.Y - GetMouseLocation(UserInputService).Y) / Settings.Sensitivity2)
				else
					if Settings.Sensitivity > 0 then
						Animation = TweenService:Create(Camera, TweenInfonew(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFramenew(Camera.CFrame.Position, LockedPosition_Vector3)})
						Animation:Play()
					else
						__newindex(Camera, "CFrame", CFramenew(Camera.CFrame.Position, LockedPosition_Vector3 + Offset))
					end

					__newindex(UserInputService, "MouseDeltaSensitivity", 0)
				end

				setrenderproperty(FOVCircle, "Color", FOVSettings.LockedColor)
			end
		end
	end)

	ServiceConnections.InputBeganConnection = Connect(__index(UserInputService, "InputBegan"), function(Input)
		local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle

		if Typing then
			return
		end

		if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
			if Toggle then
				Running = not Running

				if not Running then
					CancelLock()
				end
			else
				Running = true
			end
		end
	end)

	ServiceConnections.InputEndedConnection = Connect(__index(UserInputService, "InputEnded"), function(Input)
		local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle

		if Toggle or Typing then
			return
		end

		if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
			Running = false
			CancelLock()
		end
	end)
end

--// Typing Check

ServiceConnections.TypingStartedConnection = Connect(__index(UserInputService, "TextBoxFocused"), function()
	Typing = true
end)

ServiceConnections.TypingEndedConnection = Connect(__index(UserInputService, "TextBoxFocusReleased"), function()
	Typing = false
end)

--// Functions

function Environment.Exit(self) -- METHOD | ExunysDeveloperAimbot:Exit(<void>)
	assert(self, "EXUNYS_AIMBOT-V3.Exit: Missing parameter #1 \"self\" <table>.")

	for Index, _ in next, ServiceConnections do
		Disconnect(ServiceConnections[Index])
	end

	Load = nil; ConvertVector = nil; CancelLock = nil; GetClosestPlayer = nil; GetRainbowColor = nil; FixUsername = nil

	self.FOVCircle:Remove()
	self.FOVCircleOutline:Remove()
	getgenv().ExunysDeveloperAimbot = nil
end

function Environment.Restart() -- ExunysDeveloperAimbot.Restart(<void>)
	for Index, _ in next, ServiceConnections do
		Disconnect(ServiceConnections[Index])
	end

	Load()
end

function Environment.Blacklist(self, Username) -- METHOD | ExunysDeveloperAimbot:Blacklist(<string> Player Name)
	assert(self, "EXUNYS_AIMBOT-V3.Blacklist: Missing parameter #1 \"self\" <table>.")
	assert(Username, "EXUNYS_AIMBOT-V3.Blacklist: Missing parameter #2 \"Username\" <string>.")

	Username = FixUsername(Username)

	assert(self, "EXUNYS_AIMBOT-V3.Blacklist: User "..Username.." couldn't be found.")

	self.Blacklisted[#self.Blacklisted + 1] = Username
end

function Environment.Whitelist(self, Username) -- METHOD | ExunysDeveloperAimbot:Whitelist(<string> Player Name)
	assert(self, "EXUNYS_AIMBOT-V3.Whitelist: Missing parameter #1 \"self\" <table>.")
	assert(Username, "EXUNYS_AIMBOT-V3.Whitelist: Missing parameter #2 \"Username\" <string>.")

	Username = FixUsername(Username)

	assert(Username, "EXUNYS_AIMBOT-V3.Whitelist: User "..Username.." couldn't be found.")

	local Index = tablefind(self.Blacklisted, Username)

	assert(Index, "EXUNYS_AIMBOT-V3.Whitelist: User "..Username.." is not blacklisted.")

	tableremove(self.Blacklisted, Index)
end

function Environment.GetClosestPlayer() -- ExunysDeveloperAimbot.GetClosestPlayer(<void>)
	GetClosestPlayer()
	local Value = Environment.Locked
	CancelLock()

	return Value
end

Environment.Load = Load -- ExunysDeveloperAimbot.Load()

setmetatable(Environment, {__call = Load})

return Environment
