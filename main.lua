local cinematicSettings = {
    Active = false,
    CurrentStyle = "Orbit",
    Speed = 1,
    FOV = 70,
    ShakeIntensity = 1,
    Tilt = 0,               -- Dutch Angle/Tilt setting
    VelocityZoom = false,
    PostProcessing = false,  -- Cinematic Lighting toggle
    Target = nil            -- Target lock variable (Nil defaults to Self)
}

-- Modern Styling Theme Colors
local COLOR_BG = Color3.fromRGB(15, 15, 20)
local COLOR_HEADER = Color3.fromRGB(22, 22, 28)
local COLOR_ACCENT = Color3.fromRGB(114, 137, 218) -- Soft Amethyst Neon
local COLOR_ACCENT_HOVER = Color3.fromRGB(135, 155, 235)
local COLOR_TEXT = Color3.fromRGB(245, 245, 250)
local COLOR_TEXT_MUTED = Color3.fromRGB(160, 160, 170)
local COLOR_GREEN = Color3.fromRGB(46, 204, 113)
local COLOR_RED = Color3.fromRGB(231, 76, 60)

local FontFace = Enum.Font.GothamBold
local FontFaceMedium = Enum.Font.GothamMedium

-- Clipboard Copy Functionality
local function copyToClipboard(text)
    local copied = false
    local set_clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if set_clip then
        local success = pcall(function()
            set_clip(text)
        end)
        copied = success
    end
    return copied
end

-- Fail-safe Event Connection Wrapper
local function safeConnect(signal, callback)
    return signal:Connect(function(...)
        local args = {...}
        local success, err = xpcall(function()
            callback(unpack(args))
        end, function(err)
            local traceback = debug.traceback()
            local fullError = "[CINEMATIC RUNTIME ERROR]\nMessage: " .. tostring(err) .. "\n\nTraceback:\n" .. traceback
            local copied = copyToClipboard(fullError)
            
            warn("[Cinematic GUI Error]: " .. tostring(err))
            if copied then
                print("[Cinematic GUI]: Error details successfully copied to clipboard.")
            else
                print("[Cinematic GUI]: Failed to copy to clipboard. Executor lacks setclipboard permission.")
            end
        end)
    end)
end

-- Safe Initialization Wrapper
local initSuccess, initError = xpcall(function()
    -- Service References
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Lighting = game:GetService("Lighting")
    
    local localPlayer = Players.LocalPlayer
    local parentUI = nil
    
    -- Safe Parent Finder (CoreGui support fallback to PlayerGui)
    local coreGuiSuccess, _ = pcall(function()
        parentUI = game:GetService("CoreGui")
    end)
    if not coreGuiSuccess or not parentUI then
        parentUI = localPlayer:WaitForChild("PlayerGui")
    end

    -- Clean up any existing instances
    if parentUI:FindFirstChild("CinematicGUI_Hakira") then
        parentUI.CinematicGUI_Hakira:Destroy()
    end

    -- UI Creation Utilities
    local function create(className, properties, parent)
        local obj = Instance.new(className)
        for k, v in pairs(properties) do
            obj[k] = v
        end
        if parent then
            obj.Parent = parent
        end
        return obj
    end

    -- Camera States Cache
    local originalCameraSubject = nil
    local originalCameraType = nil
    local originalFieldOfView = nil
    local originalCFrame = nil
    local cameraConnection = nil
    local staticPos = nil
    local activeEffects = {}

    local function saveCamera()
        local cam = workspace.CurrentCamera
        originalCameraSubject = cam.CameraSubject
        originalCameraType = cam.CameraType
        originalFieldOfView = cam.FieldOfView
        originalCFrame = cam.CFrame
    end

    local function restoreCamera()
        local cam = workspace.CurrentCamera
        cam.CameraSubject = originalCameraSubject or (localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid"))
        cam.CameraType = originalCameraType or Enum.CameraType.Custom
        cam.FieldOfView = originalFieldOfView or 70
    end

    local function resetStyleVars()
        staticPos = nil
    end

    -- Dynamic Post Processing Control
    local function clearCinematicEffects()
        for _, fx in ipairs(activeEffects) do
            if fx and fx.Parent then
                fx:Destroy()
            end
        end
        activeEffects = {}
    end

    local function applyCinematicEffects()
        clearCinematicEffects()
        if not cinematicSettings.PostProcessing or not cinematicSettings.Active then return end
        
        local dof = create("DepthOfFieldEffect", {
            Name = "CinematicDoF_Hakira",
            FocusDistance = 16,
            InFocusRadius = 10,
            NearIntensity = 0.1,
            FarIntensity = 0.8
        }, Lighting)
        table.insert(activeEffects, dof)
        
        local bloom = create("BloomEffect", {
            Name = "CinematicBloom_Hakira",
            Intensity = 0.35,
            Size = 12,
            Threshold = 0.95
        }, Lighting)
        table.insert(activeEffects, bloom)

        local cc = create("ColorCorrectionEffect", {
            Name = "CinematicCC_Hakira",
            Contrast = 0.04,
            Saturation = 0.05,
            TintColor = Color3.fromRGB(255, 252, 245) -- Soft Warm Vibe
        }, Lighting)
        table.insert(activeEffects, cc)
    end

    -- Target Selector Fallback resolver
    local function getFocusTarget()
        if cinematicSettings.Target and cinematicSettings.Target.Parent and cinematicSettings.Target:FindFirstChild("HumanoidRootPart") then
            return cinematicSettings.Target.HumanoidRootPart
        end
        return localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    end

    local function stopCinematic()
        if cameraConnection then
            cameraConnection:Disconnect()
            cameraConnection = nil
        end
        clearCinematicEffects()
        restoreCamera()
    end

    local function startCinematic()
        stopCinematic()
        saveCamera()
        applyCinematicEffects()
        
        workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
        local angle = 0
        
        cameraConnection = RunService.RenderStepped:Connect(function(dt)
            local cam = workspace.CurrentCamera
            local hrp = getFocusTarget()
            if not hrp then return end
            
            angle = angle + dt * (cinematicSettings.Speed * 0.4)
            
            -- Camera Style Positioning Calculations
            if cinematicSettings.CurrentStyle == "Orbit" then
                local offset = Vector3.new(math.cos(angle) * 22, 5, math.sin(angle) * 22)
                local targetPos = hrp.Position + Vector3.new(0, 1.5, 0)
                local targetCF = CFrame.new(targetPos + offset, targetPos)
                cam.CFrame = cam.CFrame:Lerp(targetCF, 0.08)
                
            elseif cinematicSettings.CurrentStyle == "Epic Pan" then
                local offset = Vector3.new(math.sin(angle) * 16, 3, 16)
                local targetPos = hrp.Position + Vector3.new(0, 1, 0)
                local targetCF = CFrame.new(targetPos + offset, targetPos)
                cam.CFrame = cam.CFrame:Lerp(targetCF, 0.06)
                
            elseif cinematicSettings.CurrentStyle == "Dynamic Follow" then
                local targetPos = hrp.Position - hrp.CFrame.LookVector * 18 + Vector3.new(0, 4, 0)
                local targetCF = CFrame.new(targetPos, hrp.Position + Vector3.new(0, 1, 0))
                cam.CFrame = cam.CFrame:Lerp(targetCF, 0.05 * cinematicSettings.Speed)
                
            elseif cinematicSettings.CurrentStyle == "Handheld Shaky" then
                local trackingPos = hrp.Position - hrp.CFrame.LookVector * 16 + Vector3.new(0, 3.5, 0)
                local targetCF = CFrame.new(trackingPos, hrp.Position + Vector3.new(0, 1, 0))
                
                local t = tick() * (cinematicSettings.Speed * 2.2)
                local shakeX = math.noise(t, 10.5, 20.5) * (cinematicSettings.ShakeIntensity * 0.05)
                local shakeY = math.noise(t, 30.5, 40.5) * (cinematicSettings.ShakeIntensity * 0.05)
                local shakeZ = math.noise(t, 50.5, 60.5) * (cinematicSettings.ShakeIntensity * 0.03)
                
                cam.CFrame = cam.CFrame:Lerp(targetCF, 0.07) * CFrame.Angles(shakeX, shakeY, shakeZ)
                
            elseif cinematicSettings.CurrentStyle == "Static Scenic" then
                if not staticPos then
                    staticPos = hrp.Position + hrp.CFrame.LookVector * 22 + Vector3.new(12, 7, 8)
                end
                local targetCF = CFrame.new(staticPos, hrp.Position + Vector3.new(0, 1, 0))
                cam.CFrame = cam.CFrame:Lerp(targetCF, 0.04)

            elseif cinematicSettings.CurrentStyle == "Dolly Zoom" then
                -- Classic Hitchcock Vertigo effect
                local dist = 14 + math.sin(angle) * 8
                local targetPos = hrp.Position + Vector3.new(0, 1.5, 0)
                local offset = -hrp.CFrame.LookVector * dist + Vector3.new(0, 2, 0)
                local targetCF = CFrame.new(hrp.Position + offset, targetPos)
                cam.CFrame = cam.CFrame:Lerp(targetCF, 0.08)

            elseif cinematicSettings.CurrentStyle == "Crane Shot" then
                -- Tall sweep looking downward at target
                local height = 3 + math.clamp(math.sin(angle) * 14, -2, 14)
                local offset = Vector3.new(math.cos(angle * 0.5) * 18, height, math.sin(angle * 0.5) * 18)
                local targetPos = hrp.Position + Vector3.new(0, 1.5, 0)
                local targetCF = CFrame.new(targetPos + offset, targetPos)
                cam.CFrame = cam.CFrame:Lerp(targetCF, 0.05)

            elseif cinematicSettings.CurrentStyle == "Side Profile" then
                -- Sliding shot parallel to target side profile
                local sideOffset = hrp.CFrame.RightVector * 15 + Vector3.new(0, 2, 0)
                local targetPos = hrp.Position + Vector3.new(0, 1, 0)
                local targetCF = CFrame.new(hrp.Position + sideOffset, targetPos)
                cam.CFrame = cam.CFrame:Lerp(targetCF, 0.08)
            end
            
            -- Apply Dutch Angle Tilt
            if cinematicSettings.Tilt ~= 0 then
                cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(cinematicSettings.Tilt))
            end

            -- Speed-based FOV (Velocity Zoom Logic) & Dolly Zoom FOV override
            local targetFOV = cinematicSettings.FOV
            if cinematicSettings.CurrentStyle == "Dolly Zoom" then
                local dist = 14 + math.sin(angle) * 8
                targetFOV = math.clamp(70 * (14 / dist), 15, 110)
            elseif cinematicSettings.VelocityZoom then
                local currentSpeed = 0
                local linearVel = hrp:FindFirstChild("AssemblyLinearVelocity") or hrp:FindFirstChild("Velocity")
                if linearVel then
                    currentSpeed = typeof(linearVel) == "Vector3" and linearVel.Magnitude or linearVel.Value.Magnitude
                end
                local speedBonus = math.clamp(currentSpeed * 0.25, 0, 30)
                targetFOV = targetFOV + speedBonus
            end

            -- Exponential decay smoothing for Field of View transition
            cam.FieldOfView = cam.FieldOfView + (targetFOV - cam.FieldOfView) * 0.1
        end)
    end

    -- Character Re-spawn Safeguard
    safeConnect(localPlayer.CharacterAdded, function(newChar)
        if cinematicSettings.Active then
            newChar:WaitForChild("HumanoidRootPart")
            resetStyleVars()
        end
    end)

    -- Build Base ScreenGui (IgnoreGuiInset ensures proper full coverage)
    local ScreenGui = create("ScreenGui", {
        Name = "CinematicGUI_Hakira",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 99
    }, parentUI)

    -- =========================================================================
    -- EPIC LOADING SCREEN INTERFACE
    -- =========================================================================
    local LoadingFrame = create("Frame", {
        Name = "LoadingFrame",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(12, 12, 16),
        BorderSizePixel = 0,
        ZIndex = 100
    }, ScreenGui)

    -- Responsive Central Card
    local LoadingCard = create("Frame", {
        Name = "LoadingCard",
        Size = UDim2.new(0.9, 0, 0.65, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0,
        ZIndex = 101
    }, LoadingFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 16) }, LoadingCard)
    create("UIStroke", { Color = COLOR_ACCENT, Thickness = 2, Transparency = 0.4 }, LoadingCard)

    create("UISizeConstraint", {
        MinSize = Vector2.new(270, 350),
        MaxSize = Vector2.new(320, 390)
    }, LoadingCard)

    -- Rounded Profile Picture container
    local ProfileFrame = create("Frame", {
        Name = "ProfileFrame",
        Size = UDim2.new(0, 90, 0, 90),
        Position = UDim2.new(0.5, 0, 0.24, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLOR_BG,
        BorderSizePixel = 0,
        ZIndex = 102
    }, LoadingCard)
    create("UICorner", { CornerRadius = UDim.new(0, 45) }, ProfileFrame)
    create("UIStroke", { Color = COLOR_ACCENT, Thickness = 2 }, ProfileFrame)

    local ProfileImage = create("ImageLabel", {
        Name = "ProfileImage",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. localPlayer.UserId .. "&w=150&h=150",
        ZIndex = 103
    }, ProfileFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 45) }, ProfileImage)

    -- Welcome & Roblox User Metadata
    local WelcomeLabel = create("TextLabel", {
        Name = "WelcomeLabel",
        Size = UDim2.new(0.9, 0, 0, 15),
        Position = UDim2.new(0.5, 0, 0.42, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = "Welcome,",
        TextColor3 = COLOR_TEXT_MUTED,
        Font = FontFaceMedium,
        TextSize = 11,
        ZIndex = 102
    }, LoadingCard)

    local UserLabel = create("TextLabel", {
        Name = "UserLabel",
        Size = UDim2.new(0.9, 0, 0, 20),
        Position = UDim2.new(0.5, 0, 0.49, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = localPlayer.DisplayName .. " (@" .. localPlayer.Name .. ")",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 13,
        ZIndex = 102
    }, LoadingCard)

    local UserIdLabel = create("TextLabel", {
        Name = "UserIdLabel",
        Size = UDim2.new(0.9, 0, 0, 15),
        Position = UDim2.new(0.5, 0, 0.55, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = "User ID: " .. localPlayer.UserId,
        TextColor3 = COLOR_TEXT_MUTED,
        Font = FontFaceMedium,
        TextSize = 10,
        ZIndex = 102
    }, LoadingCard)

    -- Glowing Progress Bar Layout
    local TrackFrame = create("Frame", {
        Name = "TrackFrame",
        Size = UDim2.new(0.8, 0, 0, 6),
        Position = UDim2.new(0.5, 0, 0.72, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLOR_BG,
        BorderSizePixel = 0,
        ZIndex = 102
    }, LoadingCard)
    create("UICorner", { CornerRadius = UDim.new(0, 3) }, TrackFrame)

    local ProgressBar = create("Frame", {
        Name = "ProgressBar",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = COLOR_ACCENT,
        BorderSizePixel = 0,
        ZIndex = 103
    }, TrackFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 3) }, ProgressBar)
    create("UIStroke", { Color = COLOR_ACCENT, Thickness = 1.5, Transparency = 0.5 }, ProgressBar)

    local StatusText = create("TextLabel", {
        Name = "StatusText",
        Size = UDim2.new(0.9, 0, 0, 15),
        Position = UDim2.new(0.5, 0, 0.81, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = "Connecting to Workspace...",
        TextColor3 = COLOR_TEXT_MUTED,
        Font = FontFaceMedium,
        TextSize = 10,
        ZIndex = 102
    }, LoadingCard)

    -- Creator Attribution Label
    local CreatorLabel = create("TextLabel", {
        Name = "CreatorLabel",
        Size = UDim2.new(0.9, 0, 0, 15),
        Position = UDim2.new(0.5, 0, 0.92, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = "Script by hakiraadityaa",
        TextColor3 = COLOR_ACCENT,
        Font = FontFace,
        TextSize = 10,
        ZIndex = 102
    }, LoadingCard)

    -- =========================================================================
    -- INVISIBLE RESTORE ZONE & MAIN CONTROL GUI BUILD
    -- =========================================================================

    -- 100% Invisible Double-Tap Target Area at Pojok Kanan Atas
    local InvisibleRestoreBtn = create("TextButton", {
        Name = "InvisibleRestoreBtn",
        Size = UDim2.new(0, 120, 0, 120),
        Position = UDim2.new(1, 0, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Text = "",
        BorderSizePixel = 0,
        Active = true,
        Visible = false,
        ZIndex = 99
    }, ScreenGui)

    -- Main Control Window Frame
    local MainFrame = create("Frame", {
        Name = "MainFrame",
        Size = UDim2.new(0.9, 0, 0.8, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLOR_BG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false -- Kept invisible until loading screen finishes
    }, ScreenGui)
    create("UICorner", { CornerRadius = UDim.new(0, 16) }, MainFrame)
    
    local MainStroke = create("UIStroke", {
        Color = COLOR_ACCENT,
        Thickness = 2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Transparency = 0.3
    }, MainFrame)

    local MainSizeConstraint = create("UISizeConstraint", {
        MinSize = Vector2.new(280, 350),
        MaxSize = Vector2.new(350, 430)
    }, MainFrame)

    -- Header Panel
    local Header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0
    }, MainFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 16) }, Header)

    local HeaderCover = create("Frame", {
        Name = "HeaderCover",
        Size = UDim2.new(1, 0, 0, 15),
        Position = UDim2.new(0, 0, 1, -15),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0
    }, Header)

    local Title = create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0.65, 0, 0.5, 0),
        Position = UDim2.new(0.05, 0, 0.15, 0),
        BackgroundTransparency = 1,
        Text = "CINEMATIC CAMERA",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left
    }, Header)

    local Subtitle = create("TextLabel", {
        Name = "Subtitle",
        Size = UDim2.new(0.65, 0, 0.3, 0),
        Position = UDim2.new(0.05, 0, 0.55, 0),
        BackgroundTransparency = 1,
        Text = "Premium Control Panel",
        TextColor3 = COLOR_TEXT_MUTED,
        Font = FontFaceMedium,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left
    }, Header)

    -- Lucide Close Button (Image-based)
    local CloseBtn = create("ImageButton", {
        Name = "CloseBtn",
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(0.95, -22, 0.5, -9),
        BackgroundTransparency = 1,
        Image = "rbxassetid://9886659671", -- Lucide X Icon
        ImageColor3 = COLOR_TEXT_MUTED,
        BorderSizePixel = 0
    }, Header)

    -- Optimized Dragging System preventing layout jumps on mobile
    local dragStart, startPos
    local function updateDrag(input)
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    safeConnect(Header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            
            -- Lock positioning structure into absolute coordinates on drag state
            local absPos = MainFrame.AbsolutePosition
            local anchor = MainFrame.AnchorPoint
            local size = MainFrame.AbsoluteSize
            
            MainFrame.Position = UDim2.new(
                0, 
                absPos.X + (anchor.X * size.X), 
                0, 
                absPos.Y + (anchor.Y * size.Y)
            )
            startPos = MainFrame.Position
            
            local connection
            connection = safeConnect(UserInputService.InputChanged, function(changedInput)
                if changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch then
                    updateDrag(changedInput)
                end
            end)
            
            local endConnection
            endConnection = safeConnect(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End then
                    connection:Disconnect()
                    endConnection:Disconnect()
                end
            end)
        end
    end)

    -- Scroll Frame for settings elements
    local ScrollFrame = create("ScrollingFrame", {
        Name = "ScrollFrame",
        Size = UDim2.new(1, 0, 1, -60),
        Position = UDim2.new(0, 0, 0, 60),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = COLOR_ACCENT,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, MainFrame)

    create("UIListLayout", {
        Parent = ScrollFrame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        HorizontalAlignment = Enum.HorizontalAlignment.Center
    })

    create("UIPadding", {
        Parent = ScrollFrame,
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 15)
    })

    -- 1. Cinematic State Panel Card
    local StatusCard = create("Frame", {
        Name = "StatusCard",
        Size = UDim2.new(0.92, 0, 0, 60),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0,
        LayoutOrder = 1
    }, ScrollFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 12) }, StatusCard)

    local StatusTitle = create("TextLabel", {
        Name = "StatusTitle",
        Size = UDim2.new(0.6, 0, 0.4, 0),
        Position = UDim2.new(0.05, 0, 0.15, 0),
        BackgroundTransparency = 1,
        Text = "Cinematic Mode Status",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left
    }, StatusCard)

    local StatusText = create("TextLabel", {
        Name = "StatusText",
        Size = UDim2.new(0.6, 0, 0.3, 0),
        Position = UDim2.new(0.05, 0, 0.55, 0),
        BackgroundTransparency = 1,
        Text = "DISABLED",
        TextColor3 = COLOR_RED,
        Font = FontFaceMedium,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left
    }, StatusCard)

    local ToggleBtn = create("TextButton", {
        Name = "ToggleBtn",
        Size = UDim2.new(0.3, 0, 0.6, 0),
        Position = UDim2.new(0.65, 0, 0.2, 0),
        BackgroundColor3 = COLOR_RED,
        Text = "Enable",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 11,
        BorderSizePixel = 0
    }, StatusCard)
    create("UICorner", { CornerRadius = UDim.new(0, 8) }, ToggleBtn)

    local function setCinematicState(state)
        cinematicSettings.Active = state
        
        if state then
            StatusText.Text = "ACTIVE"
            StatusText.TextColor3 = COLOR_GREEN
            ToggleBtn.Text = "Disable"
            TweenService:Create(ToggleBtn, TweenInfo.new(0.3), { BackgroundColor3 = COLOR_GREEN }):Play()
            startCinematic()
        else
            StatusText.Text = "DISABLED"
            StatusText.TextColor3 = COLOR_RED
            ToggleBtn.Text = "Enable"
            TweenService:Create(ToggleBtn, TweenInfo.new(0.3), { BackgroundColor3 = COLOR_RED }):Play()
            stopCinematic()
        end
    end

    safeConnect(ToggleBtn.MouseButton1Click, function()
        setCinematicState(not cinematicSettings.Active)
    end)

    -- Hover Animations for Toggle Button
    safeConnect(ToggleBtn.MouseEnter, function()
        local targetColor = cinematicSettings.Active and Color3.fromRGB(56, 224, 123) or Color3.fromRGB(251, 96, 80)
        TweenService:Create(ToggleBtn, TweenInfo.new(0.2), { BackgroundColor3 = targetColor }):Play()
    end)
    safeConnect(ToggleBtn.MouseLeave, function()
        local targetColor = cinematicSettings.Active and COLOR_GREEN or COLOR_RED
        TweenService:Create(ToggleBtn, TweenInfo.new(0.2), { BackgroundColor3 = targetColor }):Play()
    end)

    -- 2. Style Selection Control Card (Expanded Presets)
    local StylesCard = create("Frame", {
        Name = "StylesCard",
        Size = UDim2.new(0.92, 0, 0, 105),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0,
        LayoutOrder = 2
    }, ScrollFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 12) }, StylesCard)

    create("TextLabel", {
        Name = "StylesTitle",
        Size = UDim2.new(0.9, 0, 0, 25),
        Position = UDim2.new(0.05, 0, 0.08, 0),
        BackgroundTransparency = 1,
        Text = "Movement Styles",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, StylesCard)

    local HorizontalScroll = create("ScrollingFrame", {
        Name = "HorizontalScroll",
        Size = UDim2.new(0.9, 0, 0, 60),
        Position = UDim2.new(0.05, 0, 0.35, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = COLOR_ACCENT,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X
    }, StylesCard)

    create("UIListLayout", {
        Parent = HorizontalScroll,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8)
    })

    -- Added 3 New Epic Presets: Dolly Zoom, Crane Shot, Side Profile
    local styles = {"Orbit", "Epic Pan", "Dynamic Follow", "Handheld Shaky", "Static Scenic", "Dolly Zoom", "Crane Shot", "Side Profile"}
    local styleButtons = {}

    local function selectStyle(styleName)
        cinematicSettings.CurrentStyle = styleName
        resetStyleVars()
        
        for name, btn in pairs(styleButtons) do
            if name == styleName then
                TweenService:Create(btn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_ACCENT }):Play()
                btn.UIStroke.Transparency = 0
                btn.TextColor3 = COLOR_BG
            else
                TweenService:Create(btn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_BG }):Play()
                btn.UIStroke.Transparency = 0.6
                btn.TextColor3 = COLOR_TEXT
            end
        end
    end

    for i, name in ipairs(styles) do
        local btn = create("TextButton", {
            Name = name .. "Btn",
            Size = UDim2.new(0, 105, 0, 42),
            BackgroundColor3 = COLOR_BG,
            BorderSizePixel = 0,
            Text = name,
            TextColor3 = COLOR_TEXT,
            Font = FontFaceMedium,
            TextSize = 10,
            LayoutOrder = i
        }, HorizontalScroll)
        create("UICorner", { CornerRadius = UDim.new(0, 8) }, btn)
        
        create("UIStroke", {
            Color = COLOR_ACCENT,
            Thickness = 1.5,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Transparency = 0.6
        }, btn)
        
        styleButtons[name] = btn
        
        safeConnect(btn.MouseButton1Click, function()
            selectStyle(name)
        end)
    end
    selectStyle("Orbit")

    -- 3. Universal Slider Card Builder Function
    local function createSlider(name, min, max, default, layoutOrder, callback)
        local SliderCard = create("Frame", {
            Name = name .. "Card",
            Size = UDim2.new(0.92, 0, 0, 65),
            BackgroundColor3 = COLOR_HEADER,
            BorderSizePixel = 0,
            LayoutOrder = layoutOrder
        }, ScrollFrame)
        create("UICorner", { CornerRadius = UDim.new(0, 12) }, SliderCard)

        create("TextLabel", {
            Name = "Title",
            Size = UDim2.new(0.6, 0, 0, 20),
            Position = UDim2.new(0.05, 0, 0.1, 0),
            BackgroundTransparency = 1,
            Text = name,
            TextColor3 = COLOR_TEXT,
            Font = FontFace,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left
        }, SliderCard)

        local ValueLabel = create("TextLabel", {
            Name = "Value",
            Size = UDim2.new(0.3, 0, 0, 20),
            Position = UDim2.new(0.65, 0, 0.1, 0),
            BackgroundTransparency = 1,
            Text = tostring(default),
            TextColor3 = COLOR_ACCENT,
            Font = FontFace,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right
        }, SliderCard)

        local SliderTrack = create("Frame", {
            Name = "Track",
            Size = UDim2.new(0.9, 0, 0, 5),
            Position = UDim2.new(0.05, 0, 0.65, 0),
            BackgroundColor3 = COLOR_BG,
            BorderSizePixel = 0
        }, SliderCard)
        create("UICorner", { CornerRadius = UDim.new(0, 3) }, SliderTrack)

        local Progress = create("Frame", {
            Name = "Progress",
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = COLOR_ACCENT,
            BorderSizePixel = 0
        }, SliderTrack)
        create("UICorner", { CornerRadius = UDim.new(0, 3) }, Progress)

        local Knob = create("Frame", {
            Name = "Knob",
            Size = UDim2.new(0, 12, 0, 12),
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = COLOR_TEXT,
            BorderSizePixel = 0
        }, SliderTrack)
        create("UICorner", { CornerRadius = UDim.new(0, 6) }, Knob)
        create("UIStroke", { Color = COLOR_ACCENT, Thickness = 1.5 }, Knob)

        local dragging = false
        
        local function updateValue(input)
            local posX = input.Position.X
            local trackPosX = SliderTrack.AbsolutePosition.X
            local trackWidth = SliderTrack.AbsoluteSize.X
            local percentage = math.clamp((posX - trackPosX) / trackWidth, 0, 1)
            
            Knob.Position = UDim2.new(percentage, 0, 0.5, 0)
            Progress.Size = UDim2.new(percentage, 0, 1, 0)
            
            local val = min + (max - min) * percentage
            if (max - min) <= 5 then
                val = math.round(val * 10) / 10
            else
                val = math.round(val)
            end
            
            ValueLabel.Text = tostring(val)
            callback(val)
        end

        safeConnect(Knob.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
            end
        end)

        safeConnect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateValue(input)
            end
        end)

        safeConnect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        
        -- Set default position
        local defPercent = (default - min) / (max - min)
        Knob.Position = UDim2.new(defPercent, 0, 0.5, 0)
        Progress.Size = UDim2.new(defPercent, 0, 1, 0)
    end

    -- Sliders Generation
    createSlider("Movement Speed", 0.1, 5, 1, 3, function(value)
        cinematicSettings.Speed = value
    end)

    createSlider("Field of View (FOV)", 10, 120, 70, 4, function(value)
        cinematicSettings.FOV = value
    end)

    createSlider("Shake Intensity", 0.1, 10, 1, 5, function(value)
        cinematicSettings.ShakeIntensity = value
    end)

    -- New Feature Slider: Camera Tilt / Dutch Angle (LayoutOrder 6)
    createSlider("Camera Tilt (Dutch Angle)", -30, 30, 0, 6, function(value)
        cinematicSettings.Tilt = value
    end)

    -- 4. Velocity Zoom Toggle Card (LayoutOrder 7)
    local VelZoomCard = create("Frame", {
        Name = "VelZoomCard",
        Size = UDim2.new(0.92, 0, 0, 50),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0,
        LayoutOrder = 7
    }, ScrollFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 12) }, VelZoomCard)

    create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0.6, 0, 0.4, 0),
        Position = UDim2.new(0.05, 0, 0.15, 0),
        BackgroundTransparency = 1,
        Text = "Velocity FOV Zoom",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, VelZoomCard)

    create("TextLabel", {
        Name = "Subtitle",
        Size = UDim2.new(0.6, 0, 0.3, 0),
        Position = UDim2.new(0.05, 0, 0.55, 0),
        BackgroundTransparency = 1,
        Text = "Adjusts zoom based on movement speed",
        TextColor3 = COLOR_TEXT_MUTED,
        Font = FontFaceMedium,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left
    }, VelZoomCard)

    local VelToggleBtn = create("TextButton", {
        Name = "VelToggleBtn",
        Size = UDim2.new(0.25, 0, 0.6, 0),
        Position = UDim2.new(0.7, 0, 0.2, 0),
        BackgroundColor3 = COLOR_RED,
        Text = "OFF",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 10,
        BorderSizePixel = 0
    }, VelZoomCard)
    create("UICorner", { CornerRadius = UDim.new(0, 8) }, VelToggleBtn)

    local function setVelocityZoomState(state)
        cinematicSettings.VelocityZoom = state
        if state then
            VelToggleBtn.Text = "ON"
            TweenService:Create(VelToggleBtn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_GREEN }):Play()
        else
            VelToggleBtn.Text = "OFF"
            TweenService:Create(VelToggleBtn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_RED }):Play()
        end
    end

    safeConnect(VelToggleBtn.MouseButton1Click, function()
        setVelocityZoomState(not cinematicSettings.VelocityZoom)
    end)

    -- New Feature Card: Cinematic Lighting Toggle Card (LayoutOrder 8)
    local LightingCard = create("Frame", {
        Name = "LightingCard",
        Size = UDim2.new(0.92, 0, 0, 50),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0,
        LayoutOrder = 8
    }, ScrollFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 12) }, LightingCard)

    create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0.6, 0, 0.4, 0),
        Position = UDim2.new(0.05, 0, 0.15, 0),
        BackgroundTransparency = 1,
        Text = "Cinematic Lighting (PP)",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, LightingCard)

    create("TextLabel", {
        Name = "Subtitle",
        Size = UDim2.new(0.6, 0, 0.3, 0),
        Position = UDim2.new(0.05, 0, 0.55, 0),
        BackgroundTransparency = 1,
        Text = "Enables DoF blur, warm grading & glow",
        TextColor3 = COLOR_TEXT_MUTED,
        Font = FontFaceMedium,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left
    }, LightingCard)

    local LightToggleBtn = create("TextButton", {
        Name = "LightToggleBtn",
        Size = UDim2.new(0.25, 0, 0.6, 0),
        Position = UDim2.new(0.7, 0, 0.2, 0),
        BackgroundColor3 = COLOR_RED,
        Text = "OFF",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 10,
        BorderSizePixel = 0
    }, LightingCard)
    create("UICorner", { CornerRadius = UDim.new(0, 8) }, LightToggleBtn)

    local function setLightingState(state)
        cinematicSettings.PostProcessing = state
        if state then
            LightToggleBtn.Text = "ON"
            TweenService:Create(LightToggleBtn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_GREEN }):Play()
            applyCinematicEffects()
        else
            LightToggleBtn.Text = "OFF"
            TweenService:Create(LightToggleBtn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_RED }):Play()
            clearCinematicEffects()
        end
    end

    safeConnect(LightToggleBtn.MouseButton1Click, function()
        setLightingState(not cinematicSettings.PostProcessing)
    end)

    -- New Feature Card: Target Lock Selection Card (LayoutOrder 9)
    local TargetCard = create("Frame", {
        Name = "TargetCard",
        Size = UDim2.new(0.92, 0, 0, 50),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0,
        LayoutOrder = 9
    }, ScrollFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 12) }, TargetCard)

    create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0.55, 0, 0.4, 0),
        Position = UDim2.new(0.05, 0, 0.15, 0),
        BackgroundTransparency = 1,
        Text = "Focus Target Lock",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, TargetCard)

    create("TextLabel", {
        Name = "Subtitle",
        Size = UDim2.new(0.55, 0, 0.3, 0),
        Position = UDim2.new(0.05, 0, 0.55, 0),
        BackgroundTransparency = 1,
        Text = "Focus camera style on another player",
        TextColor3 = COLOR_TEXT_MUTED,
        Font = FontFaceMedium,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left
    }, TargetCard)

    local TargetSelectBtn = create("TextButton", {
        Name = "TargetSelectBtn",
        Size = UDim2.new(0.32, 0, 0.6, 0),
        Position = UDim2.new(0.63, 0, 0.2, 0),
        BackgroundColor3 = COLOR_HEADER,
        Text = "Target: Self",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 9,
        BorderSizePixel = 0
    }, TargetCard)
    create("UICorner", { CornerRadius = UDim.new(0, 8) }, TargetSelectBtn)
    create("UIStroke", { Color = COLOR_ACCENT, Thickness = 1.2, Transparency = 0.5 }, TargetSelectBtn)

    -- Raycast Touch Target Selector Logic
    local selectionConnection = nil
    local function stopTargetSelection()
        if selectionConnection then
            selectionConnection:Disconnect()
            selectionConnection = nil
        end
    end

    local function startTargetSelection()
        stopTargetSelection()
        TargetSelectBtn.Text = "TAP A PLAYER..."
        TargetSelectBtn.BackgroundColor3 = COLOR_GREEN
        
        selectionConnection = safeConnect(UserInputService.InputBegan, function(input, processed)
            if processed then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local mousePos = input.Position
                if input.UserInputType == Enum.UserInputType.Touch then
                    mousePos = UserInputService:GetMouseLocation()
                end
                
                local camera = workspace.CurrentCamera
                local unitRay = camera:ScreenPointToRay(mousePos.X, mousePos.Y)
                
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = {localPlayer.Character}
                
                local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
                if result and result.Instance then
                    local model = result.Instance:FindFirstAncestorOfClass("Model")
                    if model and model:FindFirstChild("HumanoidRootPart") then
                        cinematicSettings.Target = model
                        TargetSelectBtn.Text = "Target: " .. model.Name:sub(1, 10)
                        TargetSelectBtn.BackgroundColor3 = COLOR_ACCENT
                        stopTargetSelection()
                        resetStyleVars()
                        return
                    end
                end
                
                -- Reset target if clicked on empty space
                cinematicSettings.Target = nil
                TargetSelectBtn.Text = "Target: Self"
                TargetSelectBtn.BackgroundColor3 = COLOR_HEADER
                stopTargetSelection()
                resetStyleVars()
            end
        end)
    end

    safeConnect(TargetSelectBtn.MouseButton1Click, function()
        startTargetSelection()
    end)

    -- 5. Hide Control Card (Cinematic View - LayoutOrder 10)
    local HideCard = create("Frame", {
        Name = "HideCard",
        Size = UDim2.new(0.92, 0, 0, 48),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0,
        LayoutOrder = 10
    }, ScrollFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 12) }, HideCard)

    local HideBtn = create("TextButton", {
        Name = "HideBtn",
        Size = UDim2.new(0.9, 0, 0.7, 0),
        Position = UDim2.new(0.05, 0, 0.15, 0),
        BackgroundColor3 = COLOR_ACCENT,
        BorderSizePixel = 0,
        Text = "Hide Panel to Record",
        TextColor3 = COLOR_BG,
        Font = FontFace,
        TextSize = 12
    }, HideCard)
    create("UICorner", { CornerRadius = UDim.new(0, 8) }, HideBtn)

    -- Hover Animations for Hide Button
    safeConnect(HideBtn.MouseEnter, function()
        TweenService:Create(HideBtn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_ACCENT_HOVER }):Play()
    end)
    safeConnect(HideBtn.MouseLeave, function()
        TweenService:Create(HideBtn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_ACCENT }):Play()
    end)

    -- Interactive Transitions for Hiding/Showing Main Panel
    local function hidePanel()
        local shrink = TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1
        })
        shrink:Play()
        shrink.Completed:Wait()
        MainFrame.Visible = false
        InvisibleRestoreBtn.Visible = true -- Activate Invisible Double-tap Zone
    end

    local function showPanel()
        InvisibleRestoreBtn.Visible = false -- Deactivate Gesture Area
        MainFrame.Visible = true
        local expand = TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0.9, 0, 0.8, 0),
            BackgroundTransparency = 0
        })
        expand:Play()
    end

    -- Double-Tap Gesture Logic (Fires on both PC Clicks and Mobile Touch Taps)
    local lastTap = 0
    local doubleTapThreshold = 0.40 -- Seconds threshold for double-tap detection

    safeConnect(InvisibleRestoreBtn.MouseButton1Click, function()
        local currentTick = tick()
        if (currentTick - lastTap) <= doubleTapThreshold then
            showPanel()
        else
            lastTap = currentTick
        end
    end)

    safeConnect(HideBtn.MouseButton1Click, hidePanel)

    -- Close & Exit Operations
    local function closeUI()
        setCinematicState(false)
        local fadeOut = TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1
        })
        fadeOut:Play()
        fadeOut.Completed:Wait()
        ScreenGui:Destroy()
    end

    safeConnect(CloseBtn.MouseButton1Click, closeUI)

    -- Guard for manual destruction from external forces (prevents memory leaks)
    safeConnect(ScreenGui.Destroying, function()
        setCinematicState(false)
        stopTargetSelection()
    end)

    task.spawn(function()
        -- Sequential steps designed to last exactly ~5 seconds in total wait time
        local steps = {
            { progress = 0.15, message = "Connecting to Local Workspace Modules..." },
            { progress = 0.40, message = "Loading Responsive GUI Components & Assets..." },
            { progress = 0.65, message = "Configuring Cinematic Presets & Movement Math..." },
            { progress = 0.85, message = "Injecting Failsafe Protection & Error Logger..." },
            { progress = 1.00, message = "System Ready! Booting Panel..." }
        }

        for _, step in ipairs(steps) do
            local fillTween = TweenService:Create(ProgressBar, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(step.progress, 0, 1, 0)
            })
            fillTween:Play()
            StatusText.Text = step.message
            task.wait(1.0) -- 5 steps * 1 second = 5.0 seconds total wait duration
        end

        -- Safe fade out helper for nested UI elements
        local function fadeOut(element, duration)
            local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            for _, child in ipairs(element:GetDescendants()) do
                if child:IsA("Frame") or child:IsA("ScrollingFrame") then
                    TweenService:Create(child, tweenInfo, { BackgroundTransparency = 1 }):Play()
                elseif child:IsA("TextLabel") or child:IsA("TextButton") then
                    TweenService:Create(child, tweenInfo, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
                    local stroke = child:FindFirstChildOfClass("UIStroke")
                    if stroke then
                        TweenService:Create(stroke, tweenInfo, { Transparency = 1 }):Play()
                    end
                elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
                    TweenService:Create(child, tweenInfo, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
                elseif child:IsA("UIStroke") then
                    TweenService:Create(child, tweenInfo, { Transparency = 1 }):Play()
                end
            end
            local bgTween = TweenService:Create(element, tweenInfo, { BackgroundTransparency = 1 })
            bgTween:Play()
            bgTween.Completed:Wait()
        end

        -- Destroy loading, and smoothly reveal the main controller panel
        fadeOut(LoadingFrame, 0.6)
        LoadingFrame:Destroy()

        MainFrame.Visible = true
        local intro = TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0.9, 0, 0.8, 0),
            BackgroundTransparency = 0
        })
        intro:Play()
    end)

end, function(err)
    local traceback = debug.traceback()
    local fullError = "[CINEMATIC INIT FAILURE]\nMessage: " .. tostring(err) .. "\n\nTraceback:\n" .. traceback
    local copied = copyToClipboard(fullError)
    
    warn("[Cinematic GUI Crash]: Initialization failed!")
    warn(fullError)
    if copied then
        print("[Cinematic GUI]: Complete traceback details copied to clipboard automatically.")
    end
end)
