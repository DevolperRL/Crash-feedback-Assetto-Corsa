local SOUND_FILE = 'sound.mp3'
local IMAGE_FILE = 'hit.png'
local SOUND_DURATION = 12.0 
local FLASH_DURATION = .5  
local FLASH_COOLDOWN = 1.5  

local settings = ac.storage{
  touchDistance = 3.0,
  maxDistance = 15.0, 
  smoothSpeed = 4.0   
}

ac.log('[ProximitySound] script loaded')

local player = nil
local playerOk, playerErr = pcall(function()
  player = ui.MediaPlayer(SOUND_FILE)
end)
if playerOk then
  ac.log('[ProximitySound] ui.MediaPlayer created OK')
else
  ac.log('[ProximitySound] FAILED to create MediaPlayer: ' .. tostring(playerErr))
end

local soundElapsed = 0
local currentVolume = 0
local lastDistance = -1

local flashUntil = 0
local flashCooldownUntil = 0

local collisionOk, collisionErr = pcall(function()
  ac.onCarCollision(0, function(otherCarIndex, ...)
    ac.log('[ProximitySound] onCarCollision fired, otherCarIndex = ' .. tostring(otherCarIndex))
    local isCarHit = type(otherCarIndex) == 'number' and otherCarIndex >= 0
    if not isCarHit then
      ac.log('[ProximitySound] ignored (not a car, likely wall/track object)')
      return
    end
    local now = os.clock()
    if now >= flashCooldownUntil then
      flashUntil = now + FLASH_DURATION
      flashCooldownUntil = now + FLASH_COOLDOWN
      ac.log('[ProximitySound] car collision confirmed, flashing image')
    end
  end)
end)
if collisionOk then
  ac.log('[ProximitySound] ac.onCarCollision registered OK')
else
  ac.log('[ProximitySound] FAILED to register onCarCollision: ' .. tostring(collisionErr))
end

local function distanceToNearestCar()
  local sim = ac.getSim()
  local player = ac.getCar(0)
  if not player then return nil end

  local best = nil
  local count = sim.carsCount or 1
  for i = 1, count - 1 do
    local car = ac.getCar(i)
    if car then
      local dx = car.position.x - player.position.x
      local dy = car.position.y - player.position.y
      local dz = car.position.z - player.position.z
      local d = math.sqrt(dx * dx + dy * dy + dz * dz)
      if not best or d < best then best = d end
    end
  end
  return best
end

function script.update(dt)
  local ok, dist = pcall(distanceToNearestCar)
  if ok and dist then
    lastDistance = dist
    local t = (dist - settings.touchDistance) / math.max(0.01, settings.maxDistance - settings.touchDistance)
    t = math.max(0, math.min(1, t))
    local targetVolume = 1 - t
    currentVolume = currentVolume + (targetVolume - currentVolume) * math.min(1, dt * settings.smoothSpeed)
  end

  if player then
    pcall(function() player:setVolume(currentVolume) end)
    soundElapsed = soundElapsed + dt
    if soundElapsed <= dt then
      pcall(function() player:play() end)
    elseif soundElapsed >= SOUND_DURATION then
      soundElapsed = 0
      pcall(function() player:play() end)
    end
  end
end

function script.windowMain(dt)
  ui.text('Nearest car distance: ' .. (lastDistance >= 0 and string.format('%.1f m', lastDistance) or 'n/a'))
  ui.text('Current volume: ' .. string.format('%.0f%%', currentVolume * 100))
  ui.separator()
  if not player then
    ui.textWrapped('MediaPlayer failed to load "' .. SOUND_FILE .. '". Check the file exists in this app\'s folder.')
  end
end

function script.windowSettings(dt)
  ui.text('Proximity Sound — settings')
  ui.separator()
  local c1, v1 = ui.slider('##touch', settings.touchDistance, 0.5, 10, 'Touch distance: %.1f m')
  if c1 then settings.touchDistance = v1 end
  local c2, v2 = ui.slider('##max', settings.maxDistance, 2, 50, 'Max distance: %.1f m')
  if c2 then settings.maxDistance = v2 end
  local c3, v3 = ui.slider('##smooth', settings.smoothSpeed, 0.5, 15, 'Smoothing speed: %.1f')
  if c3 then settings.smoothSpeed = v3 end
end

function fullscreenFlash()
  if os.clock() < flashUntil then
    local size = ac.getUI().windowSize
    ui.transparentWindow('ProximitySoundFlash', vec2(0, 0), size, false, false, function()
      local ok = pcall(function()
        ui.image(IMAGE_FILE, size, rgbm.colors.white)
      end)
      if not ok then
        ui.text('Could not load ' .. IMAGE_FILE)
      end
    end)
  end
end