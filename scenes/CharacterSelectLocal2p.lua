local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local CharacterSelect = require("scenes.CharacterSelect")
local class = require("class")
local GameModes = require("GameModes")
local Grid = require("ui.Grid")
local MultiPlayerSelectionWrapper = require("ui.MultiPlayerSelectionWrapper")

--@module CharacterSelectLocal2p
-- 
local CharacterSelectLocal2p = class(
  function (self, sceneParams)
    self:load(sceneParams)
  end,
  CharacterSelect
)

CharacterSelectLocal2p.name = "Local2pMenu"
sceneManager:addScene(CharacterSelectLocal2p)

function CharacterSelectLocal2p:customLoad(sceneParams)
  if not GAME.battleRoom then
    GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.TWO_PLAYER_VS)
  end
  self:loadUserInterface()
end

function CharacterSelectLocal2p:loadUserInterface()
  self.ui.grid = Grid({x = 153, y = 60, unitSize = 108, gridWidth = 9, gridHeight = 6, unitMargin = 6})

  self.ui.panelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "center"})
  self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection)

  self.ui.stageSelection = MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  self.ui.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.ui.stageSelection)

  self.ui.levelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "center"})
  self.ui.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.ui.levelSelection)

  self.ui.readyButton = self:createReadyButton()
  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)

  local characterButtons = self:getCharacterButtons()
  local characterGridWidth, characterGridHeight = 9, 3
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)
  self.ui.grid:createElementAt(1, 3, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)

  self.ui.leaveButton = self:createLeaveButton()
  self.ui.grid:createElementAt(9, 6, 1, 1, "leaveButton", self.ui.leaveButton)

  local offset = 30
  for i = 1, #GAME.battleRoom.players do
    local player = GAME.battleRoom.players[i]
    local yOffsetSign = (#GAME.battleRoom.players / 2) - i > (#GAME.battleRoom.players / 2) and -1 or 1
    local yOffset = yOffsetSign * offset

    local panelCarousel = self:createPanelCarousel(player)
    panelCarousel.y = yOffset
    self.ui.panelSelection:addElement(panelCarousel, player)

    local stageCarousel = self:createStageCarousel(player)
    self.ui.stageSelection:addElement(stageCarousel, player)

    local levelSlider = self:createLevelSlider(player, 20)
    levelSlider.y = yOffset
    self.ui.levelSelection:addElement(levelSlider, player)

    local cursor = self:createCursor(self.ui.grid, player)
    cursor.raise1Callback = function()
      self.ui.characterGrid:turnPage(-1)
    end
    cursor.raise2Callback = function()
      self.ui.characterGrid:turnPage(1)
    end
    self.ui.cursors[i] = cursor
  end
end


return CharacterSelectLocal2p