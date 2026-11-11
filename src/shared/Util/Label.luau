--[[
	Label.luau — legenda de botões e pads do chão.

	Fica numa "pílula" escura arredondada, FLUTUANDO bem acima do botão (lift em studs, padrão 6,5),
	então o piso e a própria peça nunca cobrem o texto. Aparece só de perto (maxDistance)
	para não poluir a tela. O BillboardGui se chama "Label" e o texto "Text" (o PlotService
	troca esse texto em runtime, ex.: "Cofre: $1.2K").
]]
local Label = {}

local BACK = Color3.fromRGB(32, 18, 58)

-- opts: width, height (px), lift (studs acima do centro da peça), color (texto e borda), maxDistance
function Label.pill(parent: Instance, text: string, opts: { [string]: any }?): BillboardGui
	local o = opts or {}
	local accent: Color3 = o.color or Color3.new(1, 1, 1)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(o.width or 200, o.height or 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, o.lift or 6.5, 0)
	gui.AlwaysOnTop = o.alwaysOnTop == true -- por padrão NÃO: a altura resolve, e assim muro e chão ainda escondem de longe
	gui.MaxDistance = o.maxDistance or 42
	gui.LightInfluence = 0

	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = BACK
	t.BackgroundTransparency = 0.18
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = accent
	t.Text = text
	t.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = t

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = accent
	stroke.Transparency = 0.25
	stroke.Parent = t

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = t

	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 28
	limit.Parent = t

	gui.Parent = parent
	return gui
end

return Label
