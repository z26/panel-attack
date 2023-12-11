local UiElement = require("ui.UIElement")
local class = require("class")
local tableUtils = require("tableUtils")

-- StackPanel is a layouting element that stacks up all its children in one direction based on an alignment setting
-- Useful for auto-aligning multiple ui elements that only know one of their dimensions
local StackPanel = class(function(stackPanel, options)
  -- all children are aligned automatically towards that option inside the StackPanel
  -- possible values: "left", "right", "top", "bottom"
  stackPanel.alignment = options.alignment

  -- StackPanels are unidirectional but can go into either direction
  -- pixelsTaken tracks how many pixels are already taken in the direction the StackPanel propagates towards
  stackPanel.pixelsTaken = 0
  -- a stack panel does not have a size limit it's alignment dimension grows with its content
end,
UiElement)

local function applyStackPanelSettings(stackPanel, uiElement)
  if stackPanel.alignment == "left" then
    uiElement.hFill = false
    uiElement.hAlign = "left"
    uiElement.x = stackPanel.width
    stackPanel.pixelsTaken = stackPanel.pixelsTaken + uiElement.width
    stackPanel.width = stackPanel.pixelsTaken
  elseif stackPanel.alignment == "right" then
    uiElement.hFill = false
    uiElement.hAlign = "right"
    uiElement.x = - stackPanel.pixelsTaken
    stackPanel.pixelsTaken = stackPanel.pixelsTaken + uiElement.width
    stackPanel.width = stackPanel.pixelsTaken
  elseif stackPanel.alignment == "top" then
    uiElement.vFill = false
    uiElement.vAlign = "top"
    uiElement.y = stackPanel.pixelsTaken
    stackPanel.pixelsTaken = stackPanel.pixelsTaken + uiElement.height
    stackPanel.height = stackPanel.pixelsTaken
  elseif stackPanel.alignment == "bottom" then
    uiElement.vFill = false
    uiElement.vAlign = "bottom"
    uiElement.y = - stackPanel.pixelsTaken
    stackPanel.pixelsTaken = stackPanel.pixelsTaken + uiElement.height
    stackPanel.height = stackPanel.pixelsTaken
  end
end

function StackPanel:addElement(uiElement)
  applyStackPanelSettings(self, uiElement)

  self:addChild(uiElement)
end


function StackPanel:insertElementAtIndex(uiElement, index)
  -- add it at the end
  self:addElement(uiElement)

  -- swap the previous element with it while updating values until it reached the desired index
  for i = #self.children - 1, index, -1 do
    local otherElement = table.remove(self.children, i)
    if self.alignment == "left" then
      uiElement.x = otherElement.x
      otherElement.x = otherElement.x + uiElement.width
    elseif self.alignment == "right" then
      uiElement.x = otherElement.x
      otherElement.x = otherElement.x - uiElement.width
    elseif self.alignment == "top" then
      uiElement.y = otherElement.y
      otherElement.y = otherElement.y + uiElement.height
    elseif self.alignment == "bottom" then
      uiElement.y = otherElement.y
      otherElement.y = otherElement.y - uiElement.height
    end
    table.insert(self.children, i + 1, otherElement)
  end
end

function StackPanel:remove(uiElement)
  local index = tableUtils.indexOf(self.children, uiElement)

  -- swap the next element with it while updating values until it reached the end, then remove it
  for i = index + 1, #self.children do
    local otherElement = table.remove(self.children, i)
    if self.alignment == "left" then
      otherElement.x = uiElement.x
      uiElement.x = uiElement.x + otherElement.width
    elseif self.alignment == "right" then
      otherElement.x = uiElement.x
      uiElement.x = uiElement.x - otherElement.width
    elseif self.alignment == "top" then
      otherElement.y = uiElement.y
      uiElement.y = uiElement.y + otherElement.height
    elseif self.alignment == "bottom" then
      otherElement.y = uiElement.y
      uiElement.y = uiElement.y + otherElement.height
    end
    table.insert(self.children, i - 1, otherElement)
  end

  if self.alignment == "left" or self.alignment == "right" then
    self.width = self.width - uiElement.width
    self.pixelsTaken = self.width
  else
    self.height = self.height - uiElement.height
    self.pixelsTaken = self.height
  end
  uiElement:detach()
end

function StackPanel:drawSelf()
  if DEBUG_ENABLED then
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

return StackPanel