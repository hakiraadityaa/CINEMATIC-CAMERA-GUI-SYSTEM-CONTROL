local cinematicSettings = {
    Active = false,
    CurrentStyle = "Orbit",
    Speed = 1,
    FOV = 70,
    ShakeIntensity = 1,
    Tilt = 0,
    VelocityZoom = false,
    PostProcessing = false,
    Letterbox = false,
    Grid = false,
    CleanHUD = false,
    Target = nil,
    FreecamSpeed = 1.0     -- Drone fly speed scale (0.1x to 3.0x)
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
    local StarterGui = game:GetService("StarterGui")
    
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

    -- Camera & Freecam States Cache
    local originalCameraSubject = nil
    local originalCameraType = nil
    local originalFieldOfView = nil
    local originalCFrame = nil
    local cameraConnection = nil
    local staticPos = nil
    local activeEffects = {}
    local hiddenCustomGuis = {}

    -- Freecam Physics Variables
    local freecamCFrame = CFrame.new()
    local freecamVelocity = Vector3.new()
    local freecamPitch = 0
    local freecamYaw = 0
    local freecamTargetPitch = 0
    local freecamTargetYaw = 0
    local freecamMoveInput = Vector3.new()
    local mobileMoving = false

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
            TintColor = Color3.fromRGB(255, 252, 245)
        }, Lighting)
        table.insert(activeEffects, cc)
    end

    -- Target Selector Fallback resolver
    local function getFocusTarget()
        if cinematicSettings.Target then
            local char = nil
            if cinematicSettings.Target:IsA("Player") then
                char = cinematicSettings.Target.Character
            elseif cinematicSettings.Target:IsA("Model") then
                char = cinematicSettings.Target
            end
            
            if char and char.Parent and char:FindFirstChild("HumanoidRootPart") then
                return char.HumanoidRootPart
            end
        end
        return localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    end

    -- Cerdas Partial Search Algorithm
    local function findTargetByPartialName(name)
        name = name:lower():gsub("%s+", "")
        if name == "" or name == "me" or name == "self" then
            return nil
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower():sub(1, #name) == name or p.DisplayName:lower():sub(1, #name) == name then
                return p
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower():find(name, 1, true) or p.DisplayName:lower():find(name, 1, true) then
                return p
            end
        end
        return nil
    end

    -- Keyboard Movement Inputs (PC Compatibility)
    local function updateKeyboardInput()
        if not cinematicSettings.Active or cinematicSettings.CurrentStyle ~= "Freecam" then return end
        
        -- Ignore typing input if active
        if UserInputService:GetFocusedTextBox() then return end
        
        local x, y, z = 0, 0, 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then z = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then z = 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then x = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then x = 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then y = 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then y = -1 end
        
        -- Override if virtual mobile joystick is inactive
        if not mobileMoving then
            freecamMoveInput = Vector3.new(x, y, z)
        end
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
        
        local cam = workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Scriptable
        
        -- Inisialisasi posisi dan orientasi tanpa snapping jika memilih Freecam
        if cinematicSettings.CurrentStyle == "Freecam" then
            freecamCFrame = cam.CFrame
            local rx, ry, rz = freecamCFrame:ToOrientation()
            freecamPitch = math.clamp(math.degrees(rx), -85, 85)
            freecamYaw = math.degrees(ry)
            freecamTargetPitch = freecamPitch
            freecamTargetYaw = freecamYaw
            freecamVelocity = Vector3.new()
            freecamMoveInput = Vector3.new()
        end
        
        local angle = 0
        cameraConnection = RunService.RenderStepped:Connect(function(dt)
            local hrp = getFocusTarget()
            
            -- Freecam Mode Update Logic (v11.0.0 Feature)
            if cinematicSettings.CurrentStyle == "Freecam" then
                updateKeyboardInput()
                
                -- Smooth Angular Momentum interpolations
                freecamPitch = freecamPitch + (freecamTargetPitch - freecamPitch) * 0.15
                freecamYaw = freecamYaw + (freecamTargetYaw - freecamYaw) * 0.15
                freecamPitch = math.clamp(freecamPitch, -85, 85)
                
                local rotationCF = CFrame.Angles(0, math.rad(freecamYaw), 0) * CFrame.Angles(math.rad(freecamPitch), 0, 0)
                
                -- Translate direction inputs to current local camera coordinates
                local localMove = Vector3.new(freecamMoveInput.X, 0, freecamMoveInput.Z)
                local moveDir = rotationCF:VectorToWorldSpace(localMove)
                moveDir = moveDir + Vector3.new(0, freecamMoveInput.Y, 0) -- Vertical Ascend/Descend
                
                -- Velocity interpolation with Momentum/Friction damping
                local targetVelocity = moveDir * (25 * cinematicSettings.FreecamSpeed)
                freecamVelocity = freecamVelocity:Lerp(targetVelocity, 0.12)
                
                freecamCFrame = CFrame.new(freecamCFrame.Position + (freecamVelocity * dt)) * rotationCF
                cam.CFrame = freecamCFrame
                
                -- Field of view update safely
                cam.FieldOfView = cam.FieldOfView + (cinematicSettings.FOV - cam.FieldOfView) * 0.1
                return
            end
            
            -- Fallback safeguard for other camera presets
            if not hrp then return end
            angle = angle + dt * (cinematicSettings.Speed * 0.4)
            
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
                local dist = 14 + math.sin(angle) * 8
                local targetPos = hrp.Position + Vector3.new(0, 1.5, 0)
                local offset = -hrp.CFrame.LookVector * dist + Vector3.new(0, 2, 0)
                local targetCF = CFrame.new(hrp.Position + offset, targetPos)
                cam.CFrame = cam.CFrame:Lerp(targetCF, 0.08)

            elseif cinematicSettings.CurrentStyle == "Crane Shot" then
                local height = 3 + math.clamp(math.sin(angle) * 14, -2, 14)
                local offset = Vector3.new(math.cos(angle * 0.5) * 18, height, math.sin(angle * 0.5) * 18)
                local targetPos = hrp.Position + Vector3.new(0, 1.5, 0)
                local targetCF = CFrame.new(targetPos + offset, targetPos)
                cam.CFrame = cam.CFrame:Lerp(targetCF, 0.05)

            elseif cinematicSettings.CurrentStyle == "Side Profile" then
                local sideOffset = hrp.CFrame.RightVector * 15 + Vector3.new(0, 2, 0)
                local targetPos = hrp.Position + Vector3.new(0, 1, 0)
                local targetCF = CFrame.new(hrp.Position + sideOffset, targetPos)
                cam.CFrame = cam.CFrame:Lerp(targetCF, 0.08)

            elseif cinematicSettings.CurrentStyle == "Bodycam" then
                local char = hrp.Parent
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                local isMoving = hrp.AssemblyLinearVelocity.Magnitude > 2
                
                local bobX, bobY = 0, 0
                local speed = (humanoid and humanoid.WalkSpeed) or 16
                
                if isMoving then
                    local t = tick() * (speed * 0.75 * cinematicSettings.Speed)
                    bobY = math.sin(t) * 0.18 * cinematicSettings.ShakeIntensity
                    bobX = math.cos(t * 0.5) * 0.1 * cinematicSettings.ShakeIntensity
                else
                    local t = tick() * (2 * cinematicSettings.Speed)
                    bobY = math.sin(t) * 0.04
                    bobX = math.cos(t * 0.5) * 0.02
                end
                
                local bodycamOffset = Vector3.new(0, 1.4, 0.6)
                local chestPos = hrp.Position + hrp.CFrame.LookVector * bodycamOffset.Z + Vector3.new(0, bodycamOffset.Y, 0)
                local finalPos = chestPos + (hrp.CFrame.RightVector * bobX) + (Vector3.new(0, bobY, 0))
                local targetLook = hrp.Position + hrp.CFrame.LookVector * 20 + Vector3.new(0, 1.4, 0)
                
                local targetCF = CFrame.new(finalPos, targetLook)
                cam.CFrame = cam.CFrame:Lerp(targetCF, 0.16)
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

    -- Mouse Right-Click to Drag Look on PC
    safeConnect(UserInputService.InputChanged, function(input, processed)
        if processed then return end
        if cinematicSettings.Active and cinematicSettings.CurrentStyle == "Freecam" then
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or MainFrame.Visible == false then
                    local sensitivity = 0.15
                    freecamTargetYaw = freecamTargetYaw - (input.Delta.X * sensitivity)
                    freecamTargetPitch = freecamTargetPitch - (input.Delta.Y * sensitivity)
                end
            end
        end
    end)

    -- Character Re-spawn Safeguard
    safeConnect(localPlayer.CharacterAdded, function(newChar)
        if cinematicSettings.Active then
            newChar:WaitForChild("HumanoidRootPart")
            resetStyleVars()
        end
    end)

    -- Player Leaving Safeguard
    safeConnect(Players.PlayerRemoving, function(player)
        if cinematicSettings.Target and (cinematicSettings.Target == player or cinematicSettings.Target == player.Character) then
            cinematicSettings.Target = nil
            resetStyleVars()
            local targetCard = parentUI:FindFirstChild("CinematicGUI_Hakira") and parentUI.CinematicGUI_Hakira:FindFirstChild("TargetCard", true)
            local box = targetCard and targetCard:FindFirstChildOfClass("TextBox")
            if box then
                box.Text = "Target: Self"
                TweenService:Create(box.UIStroke, TweenInfo.new(0.3), { Color = COLOR_ACCENT }):Play()
            end
        end
    end)

    -- Build Base ScreenGui
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
        Visible = false
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
        Image = "rbxassetid://9886659671",
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

    -- 2. Style Selection Control Card
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

    -- Styles list containing "Freecam" Style #10 (v11.0.0 Feature)
    local styles = {"Orbit", "Epic Pan", "Dynamic Follow", "Handheld Shaky", "Static Scenic", "Dolly Zoom", "Crane Shot", "Side Profile", "Bodycam", "Freecam"}
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

    -- Camera Tilt / Dutch Angle Slider
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

    -- Cinematic Lighting Toggle Card (LayoutOrder 8)
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

    -- User-Friendly Target Lock Selection Card (LayoutOrder 9)
    local TargetCard = create("Frame", {
        Name = "TargetCard",
        Size = UDim2.new(0.92, 0, 0, 50),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0,
        LayoutOrder = 9
    }, ScrollFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 12) }, TargetCard)

    local TargetTitle = create("TextLabel", {
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

    local TargetSubtitle = create("TextLabel", {
        Name = "Subtitle",
        Size = UDim2.new(0.55, 0, 0.3, 0),
        Position = UDim2.new(0.05, 0, 0.55, 0),
        BackgroundTransparency = 1,
        Text = "Input username to track player",
        TextColor3 = COLOR_TEXT_MUTED,
        Font = FontFaceMedium,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left
    }, TargetCard)

    -- Target TextBox
    local TargetTextBox = create("TextBox", {
        Name = "TargetTextBox",
        Size = UDim2.new(0.35, 0, 0.6, 0),
        Position = UDim2.new(0.6, 0, 0.2, 0),
        BackgroundColor3 = COLOR_BG,
        Text = "Target: Self",
        PlaceholderText = "Type Name...",
        PlaceholderColor3 = COLOR_TEXT_MUTED,
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 9,
        BorderSizePixel = 0,
        ClearTextOnFocus = true,
        ClipsDescendants = true
    }, TargetCard)
    create("UICorner", { CornerRadius = UDim.new(0, 8) }, TargetTextBox)
    
    local TargetStroke = create("UIStroke", {
        Color = COLOR_ACCENT,
        Thickness = 1.2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    }, TargetTextBox)

    safeConnect(TargetTextBox.FocusLost, function()
        local rawInput = TargetTextBox.Text
        local cleanInput = rawInput:gsub("^Target:%s*", ""):gsub("%s+", "")
        
        if cleanInput == "" or cleanInput:lower() == "me" or cleanInput:lower() == "self" then
            cinematicSettings.Target = nil
            TargetTextBox.Text = "Target: Self"
            TweenService:Create(TargetStroke, TweenInfo.new(0.3), { Color = COLOR_ACCENT }):Play()
            resetStyleVars()
            return
        end
        
        local targetPlayer = findTargetByPartialName(cleanInput)
        if targetPlayer then
            cinematicSettings.Target = targetPlayer
            TargetTextBox.Text = "Target: " .. targetPlayer.Name:sub(1, 10)
            TweenService:Create(TargetStroke, TweenInfo.new(0.3), { Color = COLOR_GREEN }):Play()
            resetStyleVars()
        else
            TargetTextBox.Text = "NOT FOUND!"
            TweenService:Create(TargetStroke, TweenInfo.new(0.2), { Color = COLOR_RED }):Play()
            task.wait(1.5)
            
            if cinematicSettings.Target then
                TargetTextBox.Text = "Target: " .. cinematicSettings.Target.Name:sub(1, 10)
                TweenService:Create(TargetStroke, TweenInfo.new(0.3), { Color = COLOR_GREEN }):Play()
            else
                TargetTextBox.Text = "Target: Self"
                TweenService:Create(TargetStroke, TweenInfo.new(0.3), { Color = COLOR_ACCENT }):Play()
            end
        end
    end)

    -- =========================================================================
    -- OVERLAYS: CINEMASCOPE, GRID, & HUD HIDER
    -- =========================================================================

    -- Cinematic Letterbox Bars
    local TopBar = create("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 49,
        Visible = false
    }, ScreenGui)
    
    local BottomBar = create("Frame", {
        Name = "BottomBar",
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 1, 0),
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 49,
        Visible = false
    }, ScreenGui)

    -- Rule of Thirds Grid Overlay Frame
    local GridFrame = create("Frame", {
        Name = "GridFrame",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 48,
        Visible = false
    }, ScreenGui)
    
    create("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(0.333, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.7, BorderSizePixel = 0 }, GridFrame)
    create("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(0.666, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.7, BorderSizePixel = 0 }, GridFrame)
    create("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0.333, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.7, BorderSizePixel = 0 }, GridFrame)
    create("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0.666, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.7, BorderSizePixel = 0 }, GridFrame)

    -- Cinematic Letterbox Animation Toggle Card (LayoutOrder 11)
    local LetterboxCard = create("Frame", {
        Name = "LetterboxCard",
        Size = UDim2.new(0.92, 0, 0, 50),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0,
        LayoutOrder = 11
    }, ScrollFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 12) }, LetterboxCard)

    create("TextLabel", { Name = "Title", Size = UDim2.new(0.6, 0, 0.4, 0), Position = UDim2.new(0.05, 0, 0.15, 0), BackgroundTransparency = 1, Text = "Cinematic Letterbox (21:9)", TextColor3 = COLOR_TEXT, Font = FontFace, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left }, LetterboxCard)
    create("TextLabel", { Name = "Subtitle", Size = UDim2.new(0.6, 0, 0.3, 0), Position = UDim2.new(0.05, 0, 0.55, 0), BackgroundTransparency = 1, Text = "Enables smooth Cinemascope movie bars", TextColor3 = COLOR_TEXT_MUTED, Font = FontFaceMedium, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left }, LetterboxCard)

    local LetToggleBtn = create("TextButton", { Name = "LetToggleBtn", Size = UDim2.new(0.25, 0, 0.6, 0), Position = UDim2.new(0.7, 0, 0.2, 0), BackgroundColor3 = COLOR_RED, Text = "OFF", TextColor3 = COLOR_TEXT, Font = FontFace, TextSize = 10, BorderSizePixel = 0 }, LetterboxCard)
    create("UICorner", { CornerRadius = UDim.new(0, 8) }, LetToggleBtn)

    local function setLetterboxState(state)
        cinematicSettings.Letterbox = state
        if state then
            LetToggleBtn.Text = "ON"
            TweenService:Create(LetToggleBtn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_GREEN }):Play()
            TopBar.Visible = true
            BottomBar.Visible = true
            TweenService:Create(TopBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0.12, 0) }):Play()
            TweenService:Create(BottomBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0.12, 0) }):Play()
        else
            LetToggleBtn.Text = "OFF"
            TweenService:Create(LetToggleBtn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_RED }):Play()
            local t1 = TweenService:Create(TopBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.new(1, 0, 0, 0) })
            local t2 = TweenService:Create(BottomBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.new(1, 0, 0, 0) })
            t1:Play()
            t2:Play()
            task.spawn(function()
                t1.Completed:Wait()
                if not cinematicSettings.Letterbox then
                    TopBar.Visible = false
                    BottomBar.Visible = false
                end
            end)
        end
    end

    safeConnect(LetToggleBtn.MouseButton1Click, function()
        setLetterboxState(not cinematicSettings.Letterbox)
    end)

    -- Rule of Thirds Grid Toggle Card (LayoutOrder 12)
    local GridCard = create("Frame", {
        Name = "GridCard",
        Size = UDim2.new(0.92, 0, 0, 50),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0,
        LayoutOrder = 12
    }, ScrollFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 12) }, GridCard)

    create("TextLabel", { Name = "Title", Size = UDim2.new(0.6, 0, 0.4, 0), Position = UDim2.new(0.05, 0, 0.15, 0), BackgroundTransparency = 1, Text = "Rule of Thirds Grid", TextColor3 = COLOR_TEXT, Font = FontFace, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left }, GridCard)
    create("TextLabel", { Name = "Subtitle", Size = UDim2.new(0.6, 0, 0.3, 0), Position = UDim2.new(0.05, 0, 0.55, 0), BackgroundTransparency = 1, Text = "Displays 3x3 helper framing grid", TextColor3 = COLOR_TEXT_MUTED, Font = FontFaceMedium, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left }, GridCard)

    local GridToggleBtn = create("TextButton", { Name = "GridToggleBtn", Size = UDim2.new(0.25, 0, 0.6, 0), Position = UDim2.new(0.7, 0, 0.2, 0), BackgroundColor3 = COLOR_RED, Text = "OFF", TextColor3 = COLOR_TEXT, Font = FontFace, TextSize = 10, BorderSizePixel = 0 }, GridCard)
    create("UICorner", { CornerRadius = UDim.new(0, 8) }, GridToggleBtn)

    local function setGridState(state)
        cinematicSettings.Grid = state
        if state then
            GridToggleBtn.Text = "ON"
            TweenService:Create(GridToggleBtn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_GREEN }):Play()
            GridFrame.Visible = true
        else
            GridToggleBtn.Text = "OFF"
            TweenService:Create(GridToggleBtn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_RED }):Play()
            GridFrame.Visible = false
        end
    end

    safeConnect(GridToggleBtn.MouseButton1Click, function()
        setGridState(not cinematicSettings.Grid)
    end)

    -- Clean HUD Toggle Card (StarterGui & Custom Game UI Hider - LayoutOrder 13)
    local HUDCard = create("Frame", {
        Name = "HUDCard",
        Size = UDim2.new(0.92, 0, 0, 50),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0,
        LayoutOrder = 13
    }, ScrollFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 12) }, HUDCard)

    create("TextLabel", { Name = "Title", Size = UDim2.new(0.6, 0, 0.4, 0), Position = UDim2.new(0.05, 0, 0.15, 0), BackgroundTransparency = 1, Text = "Clean HUD Mode", TextColor3 = COLOR_TEXT, Font = FontFace, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left }, HUDCard)
    create("TextLabel", { Name = "Subtitle", Size = UDim2.new(0.6, 0, 0.3, 0), Position = UDim2.new(0.05, 0, 0.55, 0), BackgroundTransparency = 1, Text = "Hides all core and custom game GUIs", TextColor3 = COLOR_TEXT_MUTED, Font = FontFaceMedium, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left }, HUDCard)

    local HUDToggleBtn = create("TextButton", { Name = "HUDToggleBtn", Size = UDim2.new(0.25, 0, 0.6, 0), Position = UDim2.new(0.7, 0, 0.2, 0), BackgroundColor3 = COLOR_RED, Text = "OFF", TextColor3 = COLOR_TEXT, Font = FontFace, TextSize = 10, BorderSizePixel = 0 }, HUDCard)
    create("UICorner", { CornerRadius = UDim.new(0, 8) }, HUDToggleBtn)

    local function setCleanHUDState(state)
        cinematicSettings.CleanHUD = state
        if state then
            HUDToggleBtn.Text = "ON"
            TweenService:Create(HUDToggleBtn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_GREEN }):Play()
            pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
            
            local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
            if playerGui then
                hiddenCustomGuis = {}
                for _, gui in ipairs(playerGui:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Enabled == true and gui ~= ScreenGui then
                        table.insert(hiddenCustomGuis, gui)
                        pcall(function() gui.Enabled = false end)
                    end
                end
            end
        else
            HUDToggleBtn.Text = "OFF"
            TweenService:Create(HUDToggleBtn, TweenInfo.new(0.25), { BackgroundColor3 = COLOR_RED }):Play()
            pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
            
            for _, gui in ipairs(hiddenCustomGuis) do
                if gui and gui.Parent then
                    pcall(function() gui.Enabled = true end)
                end
            end
            hiddenCustomGuis = {}
        end
    end

    safeConnect(HUDToggleBtn.MouseButton1Click, function()
        setCleanHUDState(not cinematicSettings.CleanHUD)
    end)

    -- =========================================================================
    -- NEW HIGH-END UX ADDITIONS: TRANSPARENT VERTICAL FOV / ELEVATION SLIDER
    -- =========================================================================
    local FovSliderFrame = create("Frame", {
        Name = "FovSliderFrame",
        Size = UDim2.new(0, 20, 0, 0), -- Starts collapsed
        Position = UDim2.new(1, -25, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 60,
        Visible = false
    }, ScreenGui)

    local FovSliderTrack = create("Frame", {
        Name = "Track",
        Size = UDim2.new(0, 4, 1, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = COLOR_ACCENT,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0
    }, FovSliderFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 2) }, FovSliderTrack)

    local FovProgress = create("Frame", {
        Name = "Progress",
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 1, 0),
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = COLOR_ACCENT,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0
    }, FovSliderTrack)
    create("UICorner", { CornerRadius = UDim.new(0, 2) }, FovProgress)

    local FovKnob = create("Frame", {
        Name = "Knob",
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0.5, 0, 1, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLOR_TEXT,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0
    }, FovSliderTrack)
    create("UICorner", { CornerRadius = UDim.new(0, 7) }, FovKnob)
    create("UIStroke", { Color = COLOR_ACCENT, Thickness = 1.2, Transparency = 0.3 }, FovKnob)

    local FovLabel = create("TextLabel", {
        Name = "FovLabel",
        Size = UDim2.new(0, 40, 0, 15),
        Position = UDim2.new(-1, -6, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Text = "70°",
        TextColor3 = COLOR_TEXT,
        TextTransparency = 0.5,
        Font = FontFace,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right
    }, FovKnob)

    -- Dynamic Vertical Slider Drag Handler (Dual Mode: FOV / Freecam Elevation)
    local fovDragging = false
    local function updateVerticalSlider(input)
        local posY = input.Position.Y
        local trackPosY = FovSliderTrack.AbsolutePosition.Y
        local trackHeight = FovSliderTrack.AbsoluteSize.Y
        local percentage = 1 - math.clamp((posY - trackPosY) / trackHeight, 0, 1)
        
        if cinematicSettings.CurrentStyle == "Freecam" then
            -- Elevation Flight Joystick Mode (Relative to center spring 0.5)
            local offsetFromCenter = percentage - 0.5 -- range -0.5 to 0.5
            FovKnob.Position = UDim2.new(0.5, 0, 1 - percentage, 0)
            FovProgress.Size = UDim2.new(1, 0, percentage, 0)
            
            local vertInput = offsetFromCenter * 2.0 -- scale -1.0 to 1.0
            freecamMoveInput = Vector3.new(freecamMoveInput.X, vertInput, freecamMoveInput.Z)
            FovLabel.Text = vertInput > 0.15 and "▲" or (vertInput < -0.15 and "▼" or "•")
        else
            -- Standard FOV adjustments
            FovKnob.Position = UDim2.new(0.5, 0, 1 - percentage, 0)
            FovProgress.Size = UDim2.new(1, 0, percentage, 0)
            
            local targetFov = math.round(10 + (120 - 10) * percentage)
            cinematicSettings.FOV = targetFov
            FovLabel.Text = tostring(targetFov) .. "°"
        end
    end

    safeConnect(FovKnob.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            fovDragging = true
            TweenService:Create(FovKnob, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()
            TweenService:Create(FovLabel, TweenInfo.new(0.2), { TextTransparency = 0.1 }):Play()
        end
    end)

    safeConnect(UserInputService.InputChanged, function(input)
        if fovDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateVerticalSlider(input)
        end
    end)

    safeConnect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            fovDragging = false
            TweenService:Create(FovKnob, TweenInfo.new(0.2), { BackgroundTransparency = 0.4 }):Play()
            TweenService:Create(FovLabel, TweenInfo.new(0.2), { TextTransparency = 0.5 }):Play()
            
            -- Spring-back mechanical effect specifically for Elevation Flight Joystick
            if cinematicSettings.CurrentStyle == "Freecam" then
                TweenService:Create(FovKnob, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Position = UDim2.new(0.5, 0, 0.5, 0)
                }):Play()
                TweenService:Create(FovProgress, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = UDim2.new(1, 0, 0.5, 0)
                }):Play()
                freecamMoveInput = Vector3.new(freecamMoveInput.X, 0, freecamMoveInput.Z)
                FovLabel.Text = "↕"
            end
        end
    end)

    -- =========================================================================
    -- NEW MOBILE-ONLY FREECAM CONTROLS (MOVEPAD, ROTATEPAD, JOYSTICK)
    -- =========================================================================
    local FreecamControls = create("Frame", {
        Name = "FreecamControls",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 58,
        Visible = false
    }, ScreenGui)

    -- Left Touch Pad for movement joystick activation
    local LeftMovePad = create("Frame", {
        Name = "LeftMovePad",
        Size = UDim2.new(0.45, 0, 0.8, 0),
        Position = UDim2.new(0, 0, 0.15, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 59
    }, FreecamControls)

    -- Right Touch Pad for panning camera rotation yaw/pitch
    local RightRotatePad = create("Frame", {
        Name = "RightRotatePad",
        Size = UDim2.new(0.45, 0, 0.8, 0),
        Position = UDim2.new(0.5, 0, 0.15, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 59
    }, FreecamControls)

    -- Neon Virtual Joystick
    local JoyRing = create("Frame", {
        Name = "JoyRing",
        Size = UDim2.new(0, 70, 0, 70),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLOR_ACCENT,
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
        ZIndex = 60,
        Visible = false
    }, ScreenGui)
    create("UICorner", { CornerRadius = UDim.new(0, 35) }, JoyRing)
    create("UIStroke", { Color = COLOR_ACCENT, Thickness = 1.5, Transparency = 0.4 }, JoyRing)

    local JoyKnob = create("Frame", {
        Name = "JoyKnob",
        Size = UDim2.new(0, 30, 0, 30),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = COLOR_TEXT,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ZIndex = 61
    }, JoyRing)
    create("UICorner", { CornerRadius = UDim.new(0, 15) }, JoyKnob)

    -- Left Flight Speed Slider (Specifically for Drone velocity tuning)
    local SpeedSliderFrame = create("Frame", {
        Name = "SpeedSliderFrame",
        Size = UDim2.new(0, 20, 0, 0), -- Starts collapsed
        Position = UDim2.new(0, 25, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 60,
        Visible = false
    }, ScreenGui)

    local SpeedTrack = create("Frame", {
        Name = "Track",
        Size = UDim2.new(0, 4, 1, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = COLOR_ACCENT,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0
    }, SpeedSliderFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 2) }, SpeedTrack)

    local SpeedProgress = create("Frame", {
        Name = "Progress",
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 1, 0),
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = COLOR_ACCENT,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0
    }, SpeedTrack)
    create("UICorner", { CornerRadius = UDim.new(0, 2) }, SpeedProgress)

    local SpeedKnob = create("Frame", {
        Name = "Knob",
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0.5, 0, 1, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLOR_TEXT,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0
    }, SpeedTrack)
    create("UICorner", { CornerRadius = UDim.new(0, 7) }, SpeedKnob)
    create("UIStroke", { Color = COLOR_ACCENT, Thickness = 1.2, Transparency = 0.3 }, SpeedKnob)

    local SpeedLabel = create("TextLabel", {
        Name = "SpeedLabel",
        Size = UDim2.new(0, 40, 0, 15),
        Position = UDim2.new(2, 6, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Text = "1.0x",
        TextColor3 = COLOR_TEXT,
        TextTransparency = 0.5,
        Font = FontFace,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left
    }, SpeedKnob)

    -- Left Flight Speed Slider Drag Handler
    local speedDragging = false
    local function updateFlightSpeed(input)
        local posY = input.Position.Y
        local trackPosY = SpeedTrack.AbsolutePosition.Y
        local trackHeight = SpeedTrack.AbsoluteSize.Y
        local percentage = 1 - math.clamp((posY - trackPosY) / trackHeight, 0, 1)
        
        SpeedKnob.Position = UDim2.new(0.5, 0, 1 - percentage, 0)
        SpeedProgress.Size = UDim2.new(1, 0, percentage, 0)
        
        -- Map speed from 0.1x crawl speed to 3.0x high flyby speed
        local speedScale = math.round((0.1 + (3.0 - 0.1) * percentage) * 10) / 10
        cinematicSettings.FreecamSpeed = speedScale
        SpeedLabel.Text = tostring(speedScale) .. "x"
    end

    safeConnect(SpeedKnob.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            speedDragging = true
            TweenService:Create(SpeedKnob, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()
            TweenService:Create(SpeedLabel, TweenInfo.new(0.2), { TextTransparency = 0.1 }):Play()
        end
    end)

    safeConnect(UserInputService.InputChanged, function(input)
        if speedDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFlightSpeed(input)
        end
    end)

    safeConnect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            speedDragging = false
            TweenService:Create(SpeedKnob, TweenInfo.new(0.2), { BackgroundTransparency = 0.4 }):Play()
            TweenService:Create(SpeedLabel, TweenInfo.new(0.2), { TextTransparency = 0.5 }):Play()
        end
    end)

    -- Left Mobile Move Touchpad Gesture (Joystick Calculations)
    local moveTouchStart = nil
    safeConnect(LeftMovePad.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            mobileMoving = true
            local touchPos = input.Position
            moveTouchStart = touchPos
            
            JoyRing.Position = UDim2.new(0, touchPos.X, 0, touchPos.Y)
            JoyKnob.Position = UDim2.new(0.5, 0, 0.5, 0)
            JoyRing.Visible = true
            
            local dragConnection
            dragConnection = safeConnect(UserInputService.InputChanged, function(dragInput)
                if mobileMoving and (dragInput.UserInputType == Enum.UserInputType.Touch or dragInput.UserInputType == Enum.UserInputType.MouseMovement) then
                    local delta = dragInput.Position - moveTouchStart
                    local dist = delta.Magnitude
                    local dir = dist > 0.1 and delta.Unit or Vector3.new()
                    
                    local maxRadius = 35
                    JoyKnob.Position = UDim2.new(0.5, dir.X * math.min(dist, maxRadius), 0.5, dir.Y * math.min(dist, maxRadius))
                    
                    -- Screen Y vector points down, map directly to standard -Z forward, +Z back movement
                    freecamMoveInput = Vector3.new(dir.X, freecamMoveInput.Y, dir.Y)
                end
            end)
            
            local endConnection
            endConnection = safeConnect(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End then
                    mobileMoving = false
                    JoyRing.Visible = false
                    freecamMoveInput = Vector3.new(0, freecamMoveInput.Y, 0)
                    dragConnection:Disconnect()
                    endConnection:Disconnect()
                end
            end)
        end
    end)

    -- Right Mobile Rotate Touchpad Gesture (Look Around Calculations)
    local rotateTouchLast = nil
    local rotatingActive = false
    safeConnect(RightRotatePad.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            rotatingActive = true
            rotateTouchLast = input.Position
            
            local rotateConnection
            rotateConnection = safeConnect(UserInputService.InputChanged, function(dragInput)
                if rotatingActive and (dragInput.UserInputType == Enum.UserInputType.Touch or dragInput.UserInputType == Enum.UserInputType.MouseMovement) then
                    local currentPos = dragInput.Position
                    local delta = currentPos - rotateTouchLast
                    rotateTouchLast = currentPos
                    
                    local sensitivity = 0.25
                    freecamTargetYaw = freecamTargetYaw - (delta.X * sensitivity)
                    freecamTargetPitch = freecamTargetPitch - (delta.Y * sensitivity)
                end
            end)
            
            local endConnection
            endConnection = safeConnect(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End then
                    rotatingActive = false
                    rotateConnection:Disconnect()
                    endConnection:Disconnect()
                end
            end)
        end
    end)

    -- =========================================================================
    -- NEW HIGH-END UX ADDITIONS: CLOSE SCRIPT CONFIRMATION DIALOG MODAL
    -- =========================================================================
    local ConfirmOverlay = create("Frame", {
        Name = "ConfirmOverlay",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(10, 10, 14),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 110,
        Visible = false
    }, ScreenGui)

    local ConfirmCard = create("Frame", {
        Name = "ConfirmCard",
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 111
    }, ConfirmOverlay)
    create("UICorner", { CornerRadius = UDim.new(0, 14) }, ConfirmCard)
    local ConfirmStroke = create("UIStroke", { Color = COLOR_ACCENT, Thickness = 2, Transparency = 0.3 }, ConfirmCard)

    local ConfirmSizeConstraint = create("UISizeConstraint", {
        MinSize = Vector2.new(260, 130),
        MaxSize = Vector2.new(280, 140)
    }, ConfirmCard)

    local ConfirmTitle = create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0.9, 0, 0, 20),
        Position = UDim2.new(0.5, 0, 0.2, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = "CLOSE SCRIPT?",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 13,
        ZIndex = 112
    }, ConfirmCard)

    local ConfirmDesc = create("TextLabel", {
        Name = "Description",
        Size = UDim2.new(0.85, 0, 0, 35),
        Position = UDim2.new(0.5, 0, 0.45, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = "Active camera styles and visual post-processing effects will be terminated safely.",
        TextColor3 = COLOR_TEXT_MUTED,
        Font = FontFaceMedium,
        TextSize = 10,
        TextWrapped = true,
        ZIndex = 112
    }, ConfirmCard)

    -- Modal Buttons (Double layout horizontally)
    local CancelBtn = create("TextButton", {
        Name = "CancelBtn",
        Size = UDim2.new(0.42, 0, 0, 32),
        Position = UDim2.new(0.08, 0, 0.78, 0),
        BackgroundColor3 = COLOR_BG,
        BorderSizePixel = 0,
        Text = "Cancel",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 11,
        ZIndex = 112
    }, ConfirmCard)
    create("UICorner", { CornerRadius = UDim.new(0, 8) }, CancelBtn)
    local CancelStroke = create("UIStroke", { Color = COLOR_ACCENT, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.5 }, CancelBtn)

    local ExitConfirmBtn = create("TextButton", {
        Name = "ExitConfirmBtn",
        Size = UDim2.new(0.42, 0, 0, 32),
        Position = UDim2.new(0.5, 0, 0.78, 0),
        BackgroundColor3 = COLOR_RED,
        BorderSizePixel = 0,
        Text = "Confirm Exit",
        TextColor3 = COLOR_TEXT,
        Font = FontFace,
        TextSize = 11,
        ZIndex = 112
    }, ConfirmCard)
    create("UICorner", { CornerRadius = UDim.new(0, 8) }, ExitConfirmBtn)

    -- Modal Interactive Triggers
    local function openConfirmModal()
        ConfirmOverlay.Visible = true
        ConfirmCard.Size = UDim2.new(0, 0, 0, 0)
        ConfirmOverlay.BackgroundTransparency = 1
        
        TweenService:Create(ConfirmOverlay, TweenInfo.new(0.25), { BackgroundTransparency = 0.55 }):Play()
        TweenService:Create(ConfirmCard, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0.9, 0, 0.35, 0)
        }):Play()
    end

    local function closeConfirmModal()
        TweenService:Create(ConfirmOverlay, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
        local shrink = TweenService:Create(ConfirmCard, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0)
        })
        shrink:Play()
        task.spawn(function()
            shrink.Completed:Wait()
            if ConfirmOverlay.BackgroundTransparency == 1 then
                ConfirmOverlay.Visible = false
            end
        end)
    end

    safeConnect(CancelBtn.MouseButton1Click, closeConfirmModal)

    -- Exit Dialog Button Hover Animation System
    safeConnect(CancelBtn.MouseEnter, function()
        TweenService:Create(CancelBtn, TweenInfo.new(0.2), { BackgroundColor3 = COLOR_HEADER }):Play()
    end)
    safeConnect(CancelBtn.MouseLeave, function()
        TweenService:Create(CancelBtn, TweenInfo.new(0.2), { BackgroundColor3 = COLOR_BG }):Play()
    end)

    safeConnect(ExitConfirmBtn.MouseEnter, function()
        TweenService:Create(ExitConfirmBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(250, 96, 80) }):Play()
    end)
    safeConnect(ExitConfirmBtn.MouseLeave, function()
        TweenService:Create(ExitConfirmBtn, TweenInfo.new(0.2), { BackgroundColor3 = COLOR_RED }):Play()
    end)

    -- 5. Hide Control Card (Cinematic View - LayoutOrder 14)
    local HideCard = create("Frame", {
        Name = "HideCard",
        Size = UDim2.new(0.92, 0, 0, 48),
        BackgroundColor3 = COLOR_HEADER,
        BorderSizePixel = 0,
        LayoutOrder = 14
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
        
        -- Adapt Right Vertical Slider according to style (v11.0.0 Dual Layout)
        if cinematicSettings.CurrentStyle == "Freecam" then
            -- Change Right Slider to spring-back Elevation flight yoke
            FovKnob.Position = UDim2.new(0.5, 0, 0.5, 0)
            FovProgress.Size = UDim2.new(1, 0, 0.5, 0)
            FovLabel.Text = "↕"
            freecamMoveInput = Vector3.new(freecamMoveInput.X, 0, freecamMoveInput.Z)
            
            -- Enable left drone speed slider
            SpeedSliderFrame.Visible = true
            SpeedSliderFrame.Size = UDim2.new(0, 20, 0, 0)
            local speedPercent = (cinematicSettings.FreecamSpeed - 0.1) / (3.0 - 0.1)
            SpeedKnob.Position = UDim2.new(0.5, 0, 1 - speedPercent, 0)
            SpeedProgress.Size = UDim2.new(1, 0, speedPercent, 0)
            SpeedLabel.Text = tostring(cinematicSettings.FreecamSpeed) .. "x"
            
            TweenService:Create(SpeedSliderFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 20, 0.35, 0)
            }):Play()
            
            -- Display Mobile Invisible Freecam Touchpads
            FreecamControls.Visible = true
        else
            -- Change Right Slider to standard static FOV adjuster
            local fovPercent = (cinematicSettings.FOV - 10) / (120 - 10)
            FovKnob.Position = UDim2.new(0.5, 0, 1 - fovPercent, 0)
            FovProgress.Size = UDim2.new(1, 0, fovPercent, 0)
            FovLabel.Text = tostring(math.round(cinematicSettings.FOV)) .. "°"
        end
        
        FovSliderFrame.Visible = true
        FovSliderFrame.Size = UDim2.new(0, 20, 0, 0)
        TweenService:Create(FovSliderFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 20, 0.35, 0)
        }):Play()
    end

    local function showPanel()
        InvisibleRestoreBtn.Visible = false -- Deactivate Gesture Area
        MainFrame.Visible = true
        FreecamControls.Visible = false
        
        local expand = TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0.9, 0, 0.8, 0),
            BackgroundTransparency = 0
        })
        expand:Play()
        
        -- Collapse and Hide FOV/Elevation Vertical Slider
        local shrink = TweenService:Create(FovSliderFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 20, 0, 0)
        })
        shrink:Play()
        task.spawn(function()
            shrink.Completed:Wait()
            if MainFrame.Visible then
                FovSliderFrame.Visible = false
            end
        end)
        
        -- Collapse and Hide Speed Flight Slider
        if SpeedSliderFrame.Visible then
            local shrinkSpeed = TweenService:Create(SpeedSliderFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 20, 0, 0)
            })
            shrinkSpeed:Play()
            task.spawn(function()
                shrinkSpeed.Completed:Wait()
                if MainFrame.Visible then
                    SpeedSliderFrame.Visible = false
                end
            end)
        end
    end

    -- Double-Tap Gesture Logic (Fires on both PC Clicks and Mobile Touch Taps)
    local lastTap = 0
    local doubleTapThreshold = 0.40

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
        setLetterboxState(false)
        setGridState(false)
        setCleanHUDState(false) -- Restores game elements safely before unloading
        
        local fadeOut = TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1
        })
        fadeOut:Play()
        fadeOut.Completed:Wait()
        ScreenGui:Destroy()
    end

    safeConnect(CloseBtn.MouseButton1Click, openConfirmModal)
    safeConnect(ExitConfirmBtn.MouseButton1Click, closeUI)

    -- Guard for manual destruction from external forces (prevents memory leaks & UI breakages)
    safeConnect(ScreenGui.Destroying, function()
        setCinematicState(false)
        setLetterboxState(false)
        setGridState(false)
        setCleanHUDState(false) -- Failsafe restoration
    end)

    -- =========================================================================
    -- RUNNING LOADING SIMULATION & LAUNCH PROCESS (5-SECOND ACCUMULATIVE)
    -- =========================================================================
    task.spawn(function()
        -- Sequential steps designed to last exactly ~5 seconds in total wait time (v11.0.0 premium modules)
        local steps = {
            { progress = 0.15, message = "Inisialisasi Core Engine v11.0.0..." },
            { progress = 0.40, message = "Memuat Modul UI Sinematik, Grid, & Cinemascope..." },
            { progress = 0.65, message = "Mengkonfigurasi Kontrol Freecam & Virtual Joystick..." },
            { progress = 0.85, message = "Memasang Proteksi Failsafe & Auto-Clipboard Handler..." },
            { progress = 1.00, message = "Modul Siap! Membuka Panel..." }
        }

        for _, step in ipairs(steps) do
            local fillTween = TweenService:Create(ProgressBar, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(step.progress, 0, 1, 0)
            })
            fillTween:Play()
            StatusText.Text = step.message
            task.wait(1.0)
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
            local bgTween = TweenService:Create(element, tweenInfo, { BackgroundColor3 = COLOR_BG, BackgroundTransparency = 1 })
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

-- Finish (script by hakiraadityaa)
