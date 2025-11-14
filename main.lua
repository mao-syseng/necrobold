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
bumpDebug = false

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
        spriteOffsetX = 32, -- adjust as needed for your sprite
        spriteOffsetY = 48, -- adjust as needed for your sprite
        airMove = 0, -- horizontal speed while in air
    }

    love.window.setTitle("Charalva")
    love.window.setMode(0, 0, {resizable = true})
    canvas = love.graphics.newCanvas(virtualWidth, virtualHeight)
    canvas:setFilter("nearest", "nearest")
    world = bump.newWorld()
    gameMap = sti('tiled/map.lua', { "bump" })
    gameMap:bump_init(world)
    world:add(player, player.x, player.y, player.w/2, player.h/2)

    
    player.image = love.graphics.newImage("/assets/player.png")
    player.image:setFilter("nearest", "nearest")
    local g = anim8.newGrid(64, 64, player.image:getWidth(), player.image:getHeight())
    player.animations = {
        idle = anim8.newAnimation(g('1-7', 1), animationSpeed),
        run = anim8.newAnimation(g('1-8', 2), animationSpeed),
        atk1 = anim8.newAnimation(g('9-17', 4), animationSpeed),
        jump = anim8.newAnimation(g('1-1', 7), animationSpeed), -- adjust frames as needed
        fall = anim8.newAnimation(g('1-1', 8), animationSpeed), -- adjust frames as needed
    }
    
    player.animation = player.animations.idle
end

function love.update(dt)
    local moving = false
    local gravity = 400  -- pixels per second squared
    local onGround = false

    -- Horizontal movement (block if jumping/falling)

    local dx = 0
    if player.onGround and player.animation ~= player.animations.jump and player.animation ~= player.animations.fall then
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
        player.airMove = 0 -- reset airMove on ground
    else
        -- In air: use airMove for horizontal movement
        dx = player.airMove * dt
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
    if not player.onGround then
        if player.vy < 0 then
            player.animation = player.animations.jump
        else
            player.animation = player.animations.fall
        end
    elseif player.animation ~= player.animations.atk1 then
        if moving then
            player.animation = player.animations.run
        else
            player.animation = player.animations.idle
        end
    end

    player.animation:update(dt)

    -- If attack animation finished, return to idle/run/jump/fall
    if player.animation == player.animations.atk1 and player.animation.position == #player.animation.frames then
        if not player.onGround then
            if player.vy < 0 then
                player.animation = player.animations.jump
            else
                player.animation = player.animations.fall
            end
        elseif moving then
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
    local offsetX = player.flipH and (64 - player.spriteOffsetX - (player.w /2)) or player.spriteOffsetX -- the offset is different depending on if the sprite is flipped or not. This is pretty bad and must be an easier fix, but did this with trial and error and works for now.
    player.animation:draw(
        player.image,
        player.x + player.w/2,
        player.y + player.h,
        0,
        scaleX,
        1,
        offsetX,
        player.spriteOffsetY
    )
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

    -- Debug: draw all bump collision boxes (in screen space) if enabled
    if bumpDebug then
        love.graphics.push()
        love.graphics.translate(offsetXScreen, offsetYScreen)
        love.graphics.scale(scale, scale)
        love.graphics.setColor(1, 0, 0, 0.7)
        for _, item in ipairs(world:getItems()) do
            local x, y, w, h = world:getRect(item)
            love.graphics.rectangle("line", x, y, w, h)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.pop()
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    if key == "space" and player.onGround then
        player.vy = -160  -- jump velocity
        player.onGround = false
        -- Set airMove to current movement direction
        if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
            player.airMove = -player.speed
        elseif love.keyboard.isDown("right") or love.keyboard.isDown("d") then
            player.airMove = player.speed
        else
            player.airMove = 0
        end
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
