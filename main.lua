local anim8 = require 'lib/anim8'
local sti = require 'lib/sti'
local bump = require "lib/bump"

animationSpeed = 0.11
virtualWidth = 480 -- 480 * 4 = 1920
virtualHeight = 270 -- 270 * 4 = 1080
tileSize = 16
tileWidth = virtualWidth / tileSize -- 30
tileHeight = 16 -- virtualHeight / tileSize = 16.875, round to 16
canvas = nil

function love.load()
    player = {
        x = virtualWidth/2,
        y = virtualHeight/2, 
        w = 16,
        h = 16,
        speed = 40,
        flipH = false,
        moving = false,
        onGround = false,
        vy = 0,
    }

    love.window.setTitle("Charalva")
    love.window.setMode(0, 0, {resizable = true})
    canvas = love.graphics.newCanvas(virtualWidth, virtualHeight)
    canvas:setFilter("nearest", "nearest")
    world = bump.newWorld()
    gameMap = sti('tiled/map.lua', { "bump" })
    gameMap:bump_init(world)
    world:add(player, player.x, player.y, player.w, player.h)

    
    player.image = love.graphics.newImage("/assets/player.png")
    player.image:setFilter("nearest", "nearest")
    local g = anim8.newGrid(64, 64, player.image:getWidth(), player.image:getHeight())
    player.animations = {
        idle = anim8.newAnimation(g('1-7', 1), animationSpeed),
        run = anim8.newAnimation(g('1-8', 2), animationSpeed),
        atk1 = anim8.newAnimation(g('9-17', 4), animationSpeed),
    }
    
    player.animation = player.animations.idle
end

function love.update(dt)
    local moving = false
    local gravity = 400  -- pixels per second squared
    local onGround = false

    -- Horizontal movement
    local dx = 0
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        dx = -player.speed * dt
        player.flipH = true
        moving = true
    end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        dx = player.speed * dt
        player.flipH = false
        moving = true
    end

    -- Apply gravity
    player.vy = player.vy + gravity * dt

    -- Movement goals
    local goalX = player.x + dx
    local goalY = player.y + player.vy * dt

    -- Move and handle collision using bump
    local actualX, actualY, cols, len = world:move(player, goalX, goalY)

    player.x, player.y = actualX, actualY
    player.onGround = false

    -- Collision resolution
    for i = 1, len do
        local col = cols[i]
        if col.normal.y < 0 then  -- landed on top of something
            player.vy = 0
            player.onGround = true
        elseif col.normal.y > 0 then  -- hit head on ceiling
            player.vy = 0
        end
    end

    -- Animation logic 
    if player.animation ~= player.animations.atk1 then
        if moving then
            player.animation = player.animations.run
        else
            player.animation = player.animations.idle
        end
    end

    player.animation:update(dt)

    -- If attack animation finished, return to idle/run
    if player.animation == player.animations.atk1 and player.animation.position == #player.animation.frames then
        if moving then
            player.animation = player.animations.run
        else
            player.animation = player.animations.idle
        end
    end

    gameMap:update(dt)
end

function love.draw()
    -- Draw everything to the virtual canvas
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    -- Draw map to canvas
    gameMap:draw()
    -- Draw player
    local scaleX = player.flipH and -1 or 1
    local offsetX = 30
    player.animation:draw(player.image, player.x, player.y, 0, scaleX, 1, offsetX, 23)
    love.graphics.setCanvas()
    -- Now scale the canvas to fit the actual window, using integer scale for pixel-perfect rendering
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    local scale = math.floor(math.min(ww / virtualWidth, wh / virtualHeight))
    if scale < 1 then scale = 1 end
    local offsetXScreen = math.floor((ww - virtualWidth * scale) / 2)
    local offsetYScreen = math.floor((wh - virtualHeight * scale) / 2)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, ww, wh) -- black bars
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas, offsetXScreen, offsetYScreen, 0, scale, scale)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
      -- Jump (optional)
    if key == "space" and player.onGround then
        player.vy = -160  -- jump velocity
        player.onGround = false
    end
    if key == "x" then
        player.animation = player.animations.atk1
        player.animation:gotoFrame(1)
        player.animation:resume()
    end
    if key == "o" then
        local isFullscreen = love.window.getFullscreen()
        if isFullscreen then
            love.window.setFullscreen(false)
            love.window.setMode(virtualWidth * 2, virtualHeight * 2, {fullscreen = false, resizable = true})
        else
            love.window.setFullscreen(true, "desktop")
        end
    end
end
