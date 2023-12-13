
local logger = require("logger")
local Player = require("Player")
local tableUtils = require("tableUtils")
local sceneManager = require("scenes.sceneManager")
local GameModes = require("GameModes")
local class = require("class")

-- A Battle Room is a session of matches, keeping track of the room number, player settings, wins / losses etc
BattleRoom =
  class(
  function(self, mode)
    assert(mode)
    self.mode = mode
    self.players = {}
    self.spectators = {}
    self.spectating = false
    self.trainingModeSettings = nil
    self.allAssetsLoaded = false
    self.ranked = false
  end
)

function BattleRoom.createFromReplay(replay)
  replay.gameMode.playerCount = #replay.players
  replay.gameMode.richPresenceLabel = "Replay"
  replay.gameMode.scene = "ReplayGame"
  local battleRoom = BattleRoom(replay.gameMode)

  for i = 1, #replay.players do
    local rpp = replay.players[i]
    local player = Player(rpp.name, rpp.publicId)
    player.playerNumber = i
    player.wins = rpp.wins
    player.settings.panelId = rpp.settings.panelId
    player.settings.characterId = CharacterLoader.resolveCharacterSelection(rpp.settings.characterId)
    player.settings.inputMethod = rpp.settings.inputMethod
    -- style will be obsolete for replays with style-independent levelData
    player.settings.style = rpp.settings.style
    player.settings.level = rpp.settings.level
    player.settings.difficulty = rpp.settings.difficulty
    player.settings.levelData = rpp.settings.levelData
    player.settings.allowAdjacentColors = rpp.settings.allowAdjacentColors
    --player.settings.levelData = rpp.settings.levelData
    battleRoom:addPlayer(player)
  end

  return battleRoom
end

function BattleRoom.createFromServerMessage(message)
  -- TODO for networking
end

function BattleRoom.createLocalFromGameMode(gameMode)
  local battleRoom = BattleRoom(gameMode)

  -- always use the global local player
  battleRoom:addPlayer(LocalPlayer)
  for i = 2, gameMode.playerCount do
    battleRoom:addPlayer(Player.getLocalPlayer())
  end

  if gameMode.style ~= GameModes.Styles.CHOOSE then
    for i = 1, #battleRoom.players do
      battleRoom.players[i]:setStyle(gameMode.style)
    end
  end

  return battleRoom
end

function BattleRoom.setWinCounts(self, winCounts)
  for i = 1, winCounts do
    self.players[i].wins = winCounts[i]
  end
end

function BattleRoom:setRatings(ratings)
  for i = 1, #self.players do
    self.players[i].rating = ratings[i]
  end
end

-- returns the total amount of games played, derived from the sum of wins across all players
-- (this means draws don't count as games)
function BattleRoom:totalGames()
  local totalGames = 0
  for i = 1, #self.players do
    totalGames = totalGames + self.players[i].wins
  end
  return totalGames
end

-- Returns the player with more win count.
-- TODO handle ties?
function BattleRoom:winningPlayer()
  if #self.players == 1 then
    return self.players[1]
  else
    if self.players[1].wins >= self.players[2].wins then
      return self.players[1]
    else
      return self.players[2]
    end
  end
end

-- creates a match with the players in the BattleRoom
function BattleRoom:createMatch()
  self.match = Match(self)

  for i = 1, #self.players do
    self.match:addPlayer(self.players[i])
  end

  return self.match
end

-- creates a new Player based on their minimum information and adds them to the BattleRoom
function BattleRoom:addNewPlayer(name, publicId, isLocal)
  local player = Player(name, publicId, isLocal)
  player.playerNumber = #self.players+1
  self.players[#self.players+1] = player
  return player
end

-- adds an existing Player to the BattleRoom
function BattleRoom:addPlayer(player)
  player.playerNumber = #self.players+1
  self.players[#self.players+1] = player
end

function BattleRoom:updateLoadingState()
  local fullyLoaded = true
  for i = 1, #self.players do
    local player = self.players[i]
    if not characters[player.settings.characterId].fully_loaded or not stages[player.settings.stageId].fully_loaded then
      fullyLoaded = false
    end
  end

  self.allAssetsLoaded = fullyLoaded

  if not self.allAssetsLoaded then
    self:startLoadingNewAssets()
  end
end

function BattleRoom:refreshReadyStates()
  -- ready should probably be a battleRoom prop, not a player prop? at least for local player(s)?
  for playerNumber = 1, #self.players do
    self.players[playerNumber].ready = tableUtils.trueForAll(self.players, function(pc)
      return (pc.hasLoaded or pc.isLocal) and pc.settings.wantsReady
    end) and self.allAssetsLoaded
  end
end

-- returns true if all players are ready, false otherwise
function BattleRoom:allReady()
  -- ready should probably be a battleRoom prop, not a player prop? at least for local player(s)?
  for playerNumber = 1, #self.players do
    if not self.players[playerNumber].ready then
      return false
    end
  end

  return true
end

function BattleRoom:updateRankedStatus(rankedStatus, comments)
  if self.online and self.mode.selectRanked and rankedStatus ~= self.ranked then
    self.ranked = rankedStatus
    self.rankedComments = comments
    -- legacy crutches
    if self.ranked then
      match_type = "Ranked"
    else
      match_type = "Casual"
    end
  else
    error("Trying to apply ranked state to the match even though it is either not online or does not support ranked")
  end
end

-- creates a match based on the room and player settings, starts it up and switches to the Game scene
function BattleRoom:startMatch(stageId, seed, replayOfMatch)
  -- TODO: lock down configuration to one per player to avoid macro like abuses via multiple configs

  local match
  if not self.match then
    match = self:createMatch()
  else
    match = self.match
  end

  match.replay = replayOfMatch
  match:setStage(stageId)
  match:setSeed(seed)

  if match_type == "Ranked" and not match.room_ratings then
    match.room_ratings = {}
  end

  match:start()

  replay = Replay.createNewReplay(match)
  -- game dies when using the fade transition for unclear reasons
  sceneManager:switchToScene(self.mode.scene, {match = self.match, nextScene = sceneManager.activeScene.name}, "none")

  -- to prevent the game from instantly restarting, unready all players
  for i = 1, #self.players do
    self.players[i]:setWantsReady(false)
  end
end

-- sets the style of "level" presets the players select from
-- 1 = classic
-- 2 = modern
-- in the future this may become a player only prop but for now it's battleRoom wide and players have to match
function BattleRoom:setStyle(styleChoice)
  -- style could be configurable per play instead but let's not for now
  if self.mode.style == GameModes.Styles.CHOOSE then
    self.style = styleChoice
    self.onStyleChanged(styleChoice)
  else
    error("Trying to set difficulty style in a game mode that doesn't support style selection")
  end
end

-- not player specific, so this gets a separate callback that can only be overwritten once
-- so the UI can update and load up the different controls for it
function BattleRoom.onStyleChanged(style, player)
end

function BattleRoom:startLoadingNewAssets()
  if CharacterLoader.loading_queue:len() == 0 then
    for i = 1, #self.players do
      local playerSettings = self.players[i].settings
      if not characters[playerSettings.characterId].fully_loaded then
        CharacterLoader.load(playerSettings.characterId)
      end
    end
  end
  if StageLoader.loading_queue:len() == 0 then
    for i = 1, #self.players do
      local playerSettings = self.players[i].settings
      if not stages[playerSettings.stageId].fully_loaded then
        StageLoader.load(playerSettings.stageId)
      end
    end
  end
end

function BattleRoom:update()
  -- here we fetch network updates and update the match setup if applicable

  -- if there are still unloaded assets, we can load them 1 asset a frame in the background
  StageLoader.update()
  CharacterLoader.update()

  if not self.match then
    -- the setup phase of the room
    self:updateLoadingState()
    self:refreshReadyStates()
    if self:allReady() then
      self:startMatch()
    end
  else
    -- the game phase of the room
  end
end

return BattleRoom