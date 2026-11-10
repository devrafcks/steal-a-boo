--[[
	UIController.luau — kit de UI: ScreenGui raiz, escala responsiva (celular e PC),
	botões grandes com "squash", painéis modais, toasts e confirmação.
	Toda a UI é criada por código (sem imagens externas).
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local UI = {}

UI.Theme = {
	Panel = Color3.fromRGB(45, 28, 80),
	PanelLight = Color3.fromRGB(70, 45, 120),
	Stroke = Color3.fromRGB(20, 10, 40),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(200, 185, 230),
	Pink = Color3.fromRGB(255, 95, 170),
	Yellow = Color3.fromRGB(255, 205, 60),
	Cyan = Color3.fromRGB(70, 210, 255),
	Green = Color3.fromRGB(80, 220, 120),
	Orange = Color3.fromRGB(255, 150, 60),
	Red = Color3.fromRGB(255, 80, 90),
	Grey = Color3.fromRGB(120, 110, 140),
	Font = Enum.Font.FredokaOne,
	FontBold = Enum.Font.GothamBold,
	FontTitle = Enum.Font.LuckiestGuy,
}
local T = UI.Theme

local TOAST_COLORS = {
	info = T.PanelLight,
	success = Color3.fromRGB(50, 160, 90),
	warn = Color3.fromRGB(200, 130, 30),
	danger = Color3.fromRGB(200, 50, 70),
	rare = Color3.fromRGB(150, 60, 220),
}

function UI.make(className: string, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function UI.corner(parent: Instance, radius: number?)
	return UI.make("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function UI.stroke(parent: Instance, thickness: number?, color: Color3?)
	return UI.make("UIStroke", {
		Thickness = thickness or 3,
		Color = color or T.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UI.text(parent: Instance, props)
	local t = UI.make("TextLabel", {
		BackgroundTransparency = 1,
		Font = props.Font or T.Font,
		TextColor3 = props.Color or T.Text,
		TextScaled = props.TextScaled ~= false,
		TextSize = props.TextSize or 18,
		Text = props.Text or "",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
		TextWrapped = true,
		RichText = props.RichText or false,
		ZIndex = props.ZIndex or 1,
		Name = props.Name or "Text",
		Parent = parent,
	})
	if props.Stroke ~= false then
		UI.make("UIStroke", { Thickness = 1.5, Color = T.Stroke, Parent = t })
	end
	if props.MaxTextSize then
		UI.make("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize, Parent = t })
	end
	return t
end

-- Efeito "squash" ao clicar
function UI.squash(gui: GuiObject)
	local scale = gui:FindFirstChild("SquashScale") or UI.make("UIScale", { Name = "SquashScale", Parent = gui })
	scale.Scale = 0.88
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

function UI.button(parent: Instance, props)
	local b = UI.make("TextButton", {
		Name = props.Name or "Button",
		AutoButtonColor = false,
		BackgroundColor3 = props.Color or T.Pink,
		Size = props.Size or UDim2.fromOffset(120, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		Text = "",
		ZIndex = props.ZIndex or 1,
		Parent = parent,
	})
	UI.corner(b, props.Radius or 12)
	UI.stroke(b, 3)
	UI.make(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)), Parent = b }
	)
	local label = UI.text(b, {
		Text = props.Text or "",
		Size = UDim2.new(1, -10, 1, -6),
		Position = UDim2.fromOffset(5, 3),
		MaxTextSize = props.MaxTextSize or 26,
		ZIndex = (props.ZIndex or 1) + 1,
		Name = "Label",
	})
	b.MouseButton1Click:Connect(function()
		if b:GetAttribute("Disabled") then
			return
		end
		UI.squash(b)
		if props.OnClick then
			props.OnClick()
		end
	end)
	return b, label
end

function UI.setDisabled(button: GuiButton, disabled: boolean, color: Color3?)
	button:SetAttribute("Disabled", disabled)
	if disabled then
		button.BackgroundColor3 = T.Grey
	elseif color then
		button.BackgroundColor3 = color
	end
end

----------------------------------------------------------------------
-- Raiz e escala
----------------------------------------------------------------------
UI.root = UI.make("ScreenGui", {
	Name = "StealABooUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = false,
	Parent = player:WaitForChild("PlayerGui"),
})
local rootScale = UI.make("UIScale", { Parent = UI.root })

local function updateScale()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local v = cam.ViewportSize
	rootScale.Scale = math.clamp(math.min(v.X / 1280, v.Y / 760), 0.55, 1.25)
	UI.isPhone = v.X < 900 or v.Y < 500
end
updateScale()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

-- Camada para modais (por cima do HUD)
UI.modalLayer = UI.make(
	"Frame",
	{ Name = "Modals", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = UI.root }
)
UI.overlay = UI.make(
	"Frame",
	{ Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 90, Parent = UI.root }
)

----------------------------------------------------------------------
-- Painéis modais (um aberto por vez)
----------------------------------------------------------------------
local panels: { [string]: { frame: Frame, onOpen: (() -> ())? } } = {}
local openName: string? = nil

function UI.panel(name: string, title: string, size: UDim2, onOpen: (() -> ())?)
	local frame = UI.make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = size,
		BackgroundColor3 = T.Panel,
		Visible = false,
		ZIndex = 50,
		Parent = UI.modalLayer,
	})
	UI.corner(frame, 18)
	UI.stroke(frame, 4)
	UI.text(frame, {
		Text = title,
		Font = T.FontTitle,
		Size = UDim2.new(1, -120, 0, 46),
		Position = UDim2.fromOffset(20, 10),
		XAlign = Enum.TextXAlignment.Left,
		Color = T.Yellow,
		ZIndex = 51,
		Name = "Title",
	})
	UI.button(frame, {
		Name = "Close",
		Text = "X",
		Color = T.Red,
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -54, 0, 10),
		ZIndex = 52,
		OnClick = function()
			UI.close(name)
		end,
	})
	local body = UI.make("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.new(1, -32, 1, -80),
		ZIndex = 51,
		Parent = frame,
	})
	panels[name] = { frame = frame, onOpen = onOpen }
	return frame, body
end

function UI.open(name: string)
	if openName and openName ~= name then
		UI.close(openName)
	end
	local p = panels[name]
	if not p then
		return
	end
	openName = name
	p.frame.Visible = true
	UI.squash(p.frame)
	if p.onOpen then
		task.spawn(p.onOpen)
	end
end

function UI.close(name: string)
	local p = panels[name]
	if p then
		p.frame.Visible = false
	end
	if openName == name then
		openName = nil
	end
end

function UI.toggle(name: string)
	if openName == name then
		UI.close(name)
	else
		UI.open(name)
	end
end

function UI.isOpen(name: string): boolean
	return openName == name
end

----------------------------------------------------------------------
-- Toasts
----------------------------------------------------------------------
local toastHolder = UI.make("Frame", {
	Name = "Toasts",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 74),
	Size = UDim2.fromOffset(520, 300),
	BackgroundTransparency = 1,
	ZIndex = 80,
	Parent = UI.root,
})
UI.make("UIListLayout", {
	Padding = UDim.new(0, 6),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = toastHolder,
})
local toastCount = 0

local function sanitize(text: string): string
	-- remove marcação RichText vinda de nomes de jogadores
	return (tostring(text):gsub("<", "‹"):gsub(">", "›"))
end

function UI.toast(text: string, kind: string?)
	toastCount += 1
	local children = toastHolder:GetChildren()
	local frames = {}
	for _, c in children do
		if c:IsA("Frame") then
			table.insert(frames, c)
		end
	end
	if #frames >= 4 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		frames[1]:Destroy()
	end
	local f = UI.make("Frame", {
		Name = "Toast",
		LayoutOrder = toastCount,
		BackgroundColor3 = TOAST_COLORS[kind or "info"] or T.PanelLight,
		Size = UDim2.fromOffset(500, 42),
		ZIndex = 80,
		Parent = toastHolder,
	})
	UI.corner(f, 12)
	UI.stroke(f, 3)
	UI.text(f, {
		Text = sanitize(text),
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		MaxTextSize = 22,
		ZIndex = 81,
	})
	UI.squash(f)
	task.delay(kind == "rare" and 5 or 3.5, function()
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			task.wait(0.3)
			f:Destroy()
		end
	end)
end

----------------------------------------------------------------------
-- Confirmação simples
----------------------------------------------------------------------
local confirmFrame, confirmBody = UI.panel("Confirm", "Tem certeza?", UDim2.fromOffset(460, 240))
local confirmText = UI.text(confirmBody, { Text = "", Size = UDim2.new(1, 0, 0, 80), MaxTextSize = 24, ZIndex = 52 })
local confirmCallback = nil
UI.button(confirmBody, {
	Text = "Sim!",
	Color = T.Green,
	Size = UDim2.fromOffset(180, 54),
	Position = UDim2.new(0.5, -190, 1, -60),
	ZIndex = 52,
	OnClick = function()
		UI.close("Confirm")
		if confirmCallback then
			confirmCallback()
		end
	end,
})
UI.button(confirmBody, {
	Text = "Cancelar",
	Color = T.Grey,
	Size = UDim2.fromOffset(180, 54),
	Position = UDim2.new(0.5, 10, 1, -60),
	ZIndex = 52,
	OnClick = function()
		UI.close("Confirm")
	end,
})
confirmFrame.ZIndex = 60

function UI.confirm(text: string, onYes: () -> ())
	confirmText.Text = text
	confirmCallback = onYes
	UI.open("Confirm")
end

return UI
