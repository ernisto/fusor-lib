local package = script.Parent.Parent
local computed = require(package.state.computed)

--// Functinos
local function layer(parent)

    local layer1 = Instance.new('Frame', parent)
    layer1.Size = UDim2.new(1, 0, .2, 0)
    local list1 = Instance.new('UIListLayout', layer1)
    list1.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list1.VerticalAlignment = Enum.VerticalAlignment.Center
    list1.FillDirection = Enum.FillDirection.Horizontal
    list1.Padding = UDim.new(0.03, 0)
    layer1.BackgroundTransparency = 1.00

    return layer1
end
local function holder()

    local screen = Instance.new('ScreenGui')
    local holder = Instance.new('Frame', screen)
    holder.AnchorPoint = Vector2.new(.5, .5)
    holder.Position = UDim2.new(.5, 0, .5, 0)
    holder.Size = UDim2.new(0, 500, 0, 500)
    
    local layers = {} :: {Frame}
    local function getLayer(i)
        for j = math.min(1, #layers), i or 1 do
            layers[j] = layer(holder)
        end
        return layers[i or 1]
    end

    return holder, getLayer
end

--// Atoms
local function value(name: string, value, parent, isBusy, isUpdated)

    local frame = Instance.new('TextLabel', parent.value)
    frame.TextScaled = true
    frame.BackgroundColor3 = Color3.fromHSV(math.random(), 0.60, 1.00)
    frame.TextColor3 = Color3.new(1, 1, 1)
    frame.SizeConstraint = Enum.SizeConstraint.RelativeYY
    frame.AutomaticSize = Enum.AutomaticSize.X
    frame.Size = UDim2.new(.6, 0, .6, 0)

    local label = Instance.new('TextLabel', frame)
    label.AnchorPoint = Vector2.new(.5, .5)
    label.Position = UDim2.new(.5, 0, 1.25, 0)
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Size = UDim2.new(0, 100, .7, 0)
    label.TextScaled = true
    label.Text = name or `state<{typeof(value.value)}>`
    label.BackgroundTransparency = 1.00
    local stroke = Instance.new('UIStroke', label)
    -- stroke.Color = Color3.new(.2, .2, .2)
    stroke.Thickness = 3

    local padding = Instance.new('UIPadding', frame)
    padding.PaddingTop = UDim.new(.15, 0)
    padding.PaddingBottom = UDim.new(.15, 0)
    local corner = Instance.new('UICorner', frame)
    corner.CornerRadius = UDim.new(1, 0)
    local stroke2 = Instance.new('UIStroke', frame)
    stroke2.Transparency = .5
    -- stroke2.Color = Color3.new(1, 1, 1)
    stroke2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke2.Thickness = 3

    parent.listeners[{}] = function() frame.Parent = parent.value end
    table.insert(value, function() frame:Destroy() end)

    return frame, computed(value, function(use)
        
        frame.Text = tostring(value.value)
        frame.BackgroundColor3 = if use(isBusy) then Color3.new(1, .7, .3)
            elseif use(isUpdated) then Color3.new(.3, .7, 1)
            else Color3.new(.5, .5, .5)
        
        return os.clock()
    end)
end

return table.freeze{ layer = layer, value = value, holder = holder }