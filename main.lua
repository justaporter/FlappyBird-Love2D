local WIN_W, WIN_H
local SCALE

local BASE_H = 512
local GRAVITY_BASE = 1000
local FLAP_VEL_BASE = -320
local MAX_FALL_BASE = 400
local PIPE_SPEED_BASE = 138
local FLAP_FRAME_TIME = 0.12
local FLAP_ROT_HOLD_T = 0.12

local MENU_BOUNCE_PERIOD = 0.9
local MENU_BOUNCE_AMP_BASE = 5
local MENU_UI_SCALE = 2.5
local MENU_ICON_TO_TEXT_RATIO = 0.62
local MENU_ICON_EXTRA_LIFT_BASE = 0.5
local MENU_ICON_GAP_BASE = 8
local MENU_LOGO_Y_FRAC = 0.13
local MENU_BTN_GAP_ABOVE_BAR_BASE = 10
local MENU_BTN_PRESS_SINK_BASE = 0.75
local MENU_BTN_PRESS_SCALE = 0.985
local MENU_BTN_PRESS_DURATION = 0.12
local MENU_COPYRIGHT_SCALE = 1.4
local MENU_COPYRIGHT_Y_FRAC = 0.32

local READY_UI_SCALE = 2.5
local READY_LOGO_Y_FRAC = 0.06
local READY_WORD_GAP_BASE = 3
local READY_POINTER_Y_FRAC = 0.32
local READY_POINTER_CORE_CENTER_FRAC = 0.231

local GRAVITY, FLAP_VEL, MAX_FALL, PIPE_SPEED
local GROUND_Y
local BIRD_X

local GAP_HEIGHT_FRAC = 0.21
local GAP_HEIGHT

local PIPE_SPACING_SCALE = 0.89
local SPAWN_INTERVAL_MIN = 1.2 * PIPE_SPACING_SCALE
local SPAWN_INTERVAL_MAX = 1.9 * PIPE_SPACING_SCALE
local MAX_GAP_SHIFT_FRAC = 0.46
local SURPRISE_SHIFT_CHANCE = 0.35
local EDGE_MARGIN_FRAC = 0.055
local MAX_GAP_SHIFT, EDGE_MARGIN

local BIRD_COLORS = { "yellow" }
local PIPE_COLOR = "green"
local PIPE_CAP_PX = 12
local PIPE_SPRITE_SCALE = 2

local images = {}
local sounds = {}

local state = "menu"
local paused = false
local bg_variant = "day"
local bird_color = "yellow"
local last_gap_center = nil

local bird = {}
local pipes = {}
local base_x = 0
local menu_t = 0
local menu_bounce_off = 0
local menu_start_pressed = false
local menu_start_press_t = 0
local go_ok_pressed = false
local go_ok_press_t = 0
local pause_btn_pressed = false
local pause_btn_press_t = 0
local flap
local togglePause
local score = 0
local best = 0
local prev_best = 0
local BEST_SAVE_FILE = "best_score.txt"

local function loadBestScore()
    local contents = love.filesystem.read(BEST_SAVE_FILE)
    return tonumber(contents) or 0
end

local function saveBestScore(value)
    love.filesystem.write(BEST_SAVE_FILE, tostring(value))
end

local pipe_spawn_timer = 0
local flash = 0
local is_new_best = false
local medal_sparkle = nil
local medal_sparkle_turn = nil

local GO_BANNER_APPEAR_DELAY_T = 0.5
local GO_BANNER_FADE_T = 0.16
local GO_BANNER_DROP_T = 0.28
local GO_BANNER_SLIDE_T = math.max(GO_BANNER_FADE_T, GO_BANNER_DROP_T)
local GO_BANNER_START_Y_FRAC = 0.85
local GO_BANNER_SPRITE_SCALE = 2.2
local GO_BANNER_Y_FRAC = 0.19
local GO_PANEL_START_Y_FRAC = 0.88
local GO_PANEL_DELAY_T = 0.5
local GO_PANEL_SLIDE_T = 0.6
local GO_TALLY_DELAY_T = 0.15
local GO_TALLY_RATE = 14
local GO_TALLY_MIN_T = 0.5
local GO_TALLY_MAX_T = 1.6
local GO_BEST_DELAY_T = 0.2
local GO_BUTTONS_DELAY_T = 0.15
local GO_BUTTONS_FADE_T = 0.2

local MEDAL_THRESHOLDS = {
    { min = 40, name = "platinum" },
    { min = 30, name = "gold" },
    { min = 20, name = "silver" },
    { min = 10, name = "bronze" },
}

local function medalForScore(s)
    for _, m in ipairs(MEDAL_THRESHOLDS) do
        if s >= m.min then return m.name end
    end
    return nil
end

local PANEL_UI_SCALE = 2.5
local MEDAL_CIRCLE_CENTER_X_FRAC = 0.208
local MEDAL_CIRCLE_CENTER_Y_FRAC = 0.543

local PAUSE_BTN_UI_SCALE = 2.5
local PAUSE_BTN_MARGIN_BASE = 14
local PAUSE_BTN_Y_NUDGE_BASE = 6

local SPARKLE_STAGE_T = 0.088
local SPARKLE_PULSE_T = SPARKLE_STAGE_T * 5
local SPARKLE_GAP_T = 0.19
local SPARKLE_TURN_T = SPARKLE_PULSE_T + SPARKLE_GAP_T
local SPARKLE_SCALE = 1.15
local SPARKLE_RADIUS_MIN_FRAC = 0
local SPARKLE_RADIUS_MAX_FRAC = 1.15
local PANEL_NUMBER_RIGHT_X_FRAC = 0.90
local PANEL_NUMBER_HEIGHT_FRAC = 0.15
local PANEL_SCORE_NUMBER_Y_FRAC = 0.29
local PANEL_BEST_NUMBER_Y_FRAC = 0.68
local NUMBER_DIGIT_GAP_BASE = 4
local PANEL_BEST_LABEL_LEFT_X_FRAC = 0.752
local PANEL_BEST_LABEL_VCENTER_Y_FRAC = 0.552
local PANEL_NEW_BADGE_Y_NUDGE_FRAC = 0
local PANEL_NEW_BADGE_SCALE = 1.0
local PANEL_NEW_BADGE_GAP_FRAC = 0.01

local gameover_t = 0
local go_tally_duration = GO_TALLY_MIN_T
local go_tally_start_t = 0
local go_best_start_t = 0
local go_best_tally_duration = GO_TALLY_MIN_T
local displayed_score = 0
local displayed_best = 0

local function easeOutCubic(t)
    t = math.max(0, math.min(1, t))
    local f = t - 1
    return f * f * f + 1
end

local function easeOutQuint(t)
    t = math.max(0, math.min(1, t))
    local f = t - 1
    return f * f * f * f * f + 1
end

local function easeInQuart(t)
    t = math.max(0, math.min(1, t))
    return t * t * t * t
end

local function loadImg(name)
    return love.graphics.newImage("assets/sprites/" .. name .. ".png")
end

local function playSound(name)
    local s = sounds[name]
    if s then
        s:stop()
        s:play()
    end
end

function recalcLayout()
    WIN_W, WIN_H = love.graphics.getDimensions()

    SCALE = WIN_H / BASE_H

    GRAVITY = GRAVITY_BASE * SCALE
    FLAP_VEL = FLAP_VEL_BASE * SCALE
    MAX_FALL = MAX_FALL_BASE * SCALE
    PIPE_SPEED = PIPE_SPEED_BASE * SCALE

    local ground_h = images and images.base and (images.base:getHeight() * SCALE) or (112 * SCALE)
    GROUND_Y = WIN_H - ground_h

    BIRD_X = math.floor(WIN_W * 0.12)

    GAP_HEIGHT = math.floor(GAP_HEIGHT_FRAC * WIN_H)
    MAX_GAP_SHIFT = math.floor(MAX_GAP_SHIFT_FRAC * WIN_H)
    EDGE_MARGIN = math.floor(EDGE_MARGIN_FRAC * WIN_H)
end

function love.load()
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")

    images.bg_day = loadImg("background-day")
    images.bg_night = loadImg("background-night")
    images.base = loadImg("base")
    images.gameover = loadImg("menu/text_game_over")
    images.digits = {}
    for i = 0, 9 do
        images.digits[i] = loadImg(tostring(i))
    end

    images.ready_logo_get = loadImg("menu/logo_get")
    images.ready_logo_ready = loadImg("menu/logo_ready")
    images.ready_tap_pointer = loadImg("menu/tap_pointer")

    images.menu_logo_flappy_bird = loadImg("menu/logo_flappy_bird")
    images.menu_lobby_bird = {
        loadImg("menu/lobby_bird_a"),
        loadImg("menu/lobby_bird_b"),
        loadImg("menu/lobby_bird_c"),
    }
    images.menu_btn_start = loadImg("menu/btn_start")
    images.menu_btn_score = loadImg("menu/btn_score")
    images.menu_bottom_bar = loadImg("base")
    images.menu_copyright = loadImg("menu/copyright_text")

    images.go_panel = loadImg("menu/panel_medal_score")
    images.go_medal = {
        bronze = loadImg("menu/medal_bronze"),
        silver = loadImg("menu/medal_silver"),
        gold = loadImg("menu/medal_gold"),
        platinum = loadImg("menu/medal_platinum"),
    }
    images.go_badge_new = loadImg("menu/badge_new")
    images.go_btn_ok = loadImg("menu/btn_ok")
    images.go_btn_share = loadImg("menu/btn_share")

    images.pause_icon = loadImg("menu/pause_icon")
    images.play_icon = loadImg("menu/play_icon")

    images.go_sparkle = {
        loadImg("menu/sparkle_1"),
        loadImg("menu/sparkle_2"),
        loadImg("menu/sparkle_3"),
    }

    images.pipe_top = loadImg("pipe-green-top")
    images.pipe_bottom = loadImg("pipe-green-bottom")

    do
        local tw, th = images.pipe_top:getDimensions()
        local bw, bh = images.pipe_bottom:getDimensions()

        images.pipe_top_cap_quad = love.graphics.newQuad(0, th - PIPE_CAP_PX, tw, PIPE_CAP_PX, tw, th)
        images.pipe_top_body_quad = love.graphics.newQuad(0, 0, tw, th - PIPE_CAP_PX, tw, th)

        images.pipe_bottom_cap_quad = love.graphics.newQuad(0, 0, bw, PIPE_CAP_PX, bw, bh)
        images.pipe_bottom_body_quad = love.graphics.newQuad(0, PIPE_CAP_PX, bw, bh - PIPE_CAP_PX, bw, bh)
    end

    images.birds = {}
    for _, c in ipairs(BIRD_COLORS) do
        images.birds[c] = {
            loadImg(c .. "bird-upflap"),
            loadImg(c .. "bird-midflap"),
            loadImg(c .. "bird-downflap"),
        }
    end

    for _, n in ipairs({ "wing", "point", "hit", "die", "swoosh" }) do
        sounds[n] = love.audio.newSource("assets/audio/" .. n .. ".wav", "static")
    end

    recalcLayout()
    best = loadBestScore()
    prev_best = best
    resetGame()

end

function love.resize(w, h)
    recalcLayout()

    pipes = {}
    pipe_spawn_timer = 0
    last_gap_center = nil
end

function resetGame()
    bird = {
        y = WIN_H / 2 - 12 * SCALE,
        vel = 0,
        rot = 0,
        rot_hold_t = 0,
        frame = 2,
        frame_t = 0,
    }
    pipes = {}
    base_x = 0
    score = 0
    pipe_spawn_timer = 0
    last_gap_center = nil
    bg_variant = (math.random() < 0.5) and "day" or "night"
    bird_color = BIRD_COLORS[math.random(#BIRD_COLORS)]
    state = "menu"

    paused = false
    gameover_t = 0
    displayed_score = 0
    displayed_best = prev_best
    is_new_best = false
    go_ok_pressed = false
    go_ok_press_t = 0
    pause_btn_pressed = false
    pause_btn_press_t = 0
    medal_sparkle = nil
    medal_sparkle_turn = nil
end

local function pipeCollisionLen()
    return GROUND_Y
end

local function currentPipeWidth()
    return images.pipe_top:getWidth() * SCALE * PIPE_SPRITE_SCALE
end

local function nextSpawnInterval()
    return SPAWN_INTERVAL_MIN + math.random() * (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN)
end

local function spawnPipe()
    local gap = GAP_HEIGHT
    local lo = math.floor(EDGE_MARGIN + gap / 2)
    local hi = math.floor(GROUND_Y - EDGE_MARGIN - gap / 2)

    local gap_center
    if last_gap_center and math.random() >= SURPRISE_SHIFT_CHANCE then

        local min_c = math.max(lo, last_gap_center - MAX_GAP_SHIFT)
        local max_c = math.min(hi, last_gap_center + MAX_GAP_SHIFT)
        if min_c > max_c then min_c, max_c = lo, hi end
        gap_center = math.random(min_c, max_c)
    else

        gap_center = math.random(lo, hi)
    end
    last_gap_center = gap_center

    table.insert(pipes, {
        x = WIN_W + 10,
        gap = gap,
        gap_center = gap_center,
        passed = false,
    })
end

local function birdRect()
    return BIRD_X - 12 * SCALE, bird.y - 8 * SCALE, 24 * SCALE, 16 * SCALE
end

local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

local function checkCollisions()
    local bx, by, bw, bh = birdRect()

    local pipe_w = currentPipeWidth()
    local pipe_h = pipeCollisionLen()
    for _, p in ipairs(pipes) do
        local top_h = p.gap_center - p.gap / 2
        local bot_y = p.gap_center + p.gap / 2

        if rectsOverlap(bx, by, bw, bh, p.x, top_h - pipe_h, pipe_w, pipe_h) then
            return true, true
        end
        if rectsOverlap(bx, by, bw, bh, p.x, bot_y, pipe_w, pipe_h) then
            return true, true
        end
    end

    if bird.y + 8 * SCALE >= GROUND_Y then
        return true, false
    end
    if bird.y - 8 * SCALE <= 0 then
        bird.y = 8 * SCALE
        bird.vel = 0
    end

    return false, false
end

function love.update(dt)
    dt = math.min(dt, 1 / 30)

    if pause_btn_pressed then
        pause_btn_press_t = pause_btn_press_t + dt
        if pause_btn_press_t >= MENU_BTN_PRESS_DURATION then
            pause_btn_pressed = false
            pause_btn_press_t = 0
            togglePause()
        end
    end

    if paused and state == "play" then
        return
    end

    if state == "menu" then
        menu_t = menu_t + dt

        local phase = (menu_t % MENU_BOUNCE_PERIOD) / MENU_BOUNCE_PERIOD
        menu_bounce_off = MENU_BOUNCE_AMP_BASE * SCALE * (1 - math.cos(2 * math.pi * phase)) / 2

        if menu_start_pressed then
            menu_start_press_t = menu_start_press_t + dt
            if menu_start_press_t >= MENU_BTN_PRESS_DURATION then
                menu_start_pressed = false
                menu_start_press_t = 0
                flap()
            end
        end

        base_x = (base_x - PIPE_SPEED * dt) % -(images.menu_bottom_bar:getWidth() * SCALE)
    elseif state == "ready" then
        base_x = (base_x - PIPE_SPEED * dt) % -(images.base:getWidth() * SCALE)
    elseif state == "play" then
        bird.vel = math.min(bird.vel + GRAVITY * dt, MAX_FALL)
        bird.y = bird.y + bird.vel * dt

        local vel_frac = bird.vel / SCALE
        if bird.rot_hold_t > 0 then
            bird.rot_hold_t = bird.rot_hold_t - dt
            bird.rot = math.max(-25, math.min(bird.rot, vel_frac * 0.15))
        elseif vel_frac < 0 then
            bird.rot = math.max(-25, vel_frac * 0.15)
        else
            bird.rot = math.min(90, vel_frac * 0.4)
        end

        base_x = (base_x - PIPE_SPEED * dt) % -(images.base:getWidth() * SCALE)

        pipe_spawn_timer = pipe_spawn_timer - dt
        if pipe_spawn_timer <= 0 then
            spawnPipe()
            pipe_spawn_timer = nextSpawnInterval()
        end

        local pipe_w = currentPipeWidth()
        for _, p in ipairs(pipes) do
            p.x = p.x - PIPE_SPEED * dt
            if not p.passed and p.x + pipe_w < BIRD_X then
                p.passed = true
                score = score + 1
                playSound("point")
            end
        end
        while #pipes > 0 and pipes[1].x < -pipe_w - 20 do
            table.remove(pipes, 1)
        end

        local collided, hit_pipe = checkCollisions()
        if collided then
            state = "gameover"
            gameover_t = 0
            displayed_score = 0
            displayed_best = 0
            is_new_best = score > best
            prev_best = best
            best = math.max(best, score)
            if is_new_best then
                saveBestScore(best)
            end

            go_tally_duration = math.max(GO_TALLY_MIN_T, math.min(GO_TALLY_MAX_T, score / GO_TALLY_RATE))
            go_best_tally_duration = math.max(GO_TALLY_MIN_T, math.min(GO_TALLY_MAX_T, (best - prev_best) / GO_TALLY_RATE))
            go_tally_start_t = GO_BANNER_APPEAR_DELAY_T + GO_BANNER_SLIDE_T + GO_PANEL_DELAY_T + GO_PANEL_SLIDE_T + GO_TALLY_DELAY_T
            go_best_start_t = go_tally_start_t
            playSound("hit")
            if hit_pipe then
                playSound("die")
            end
            flash = 0.15
        end
    elseif state == "gameover" then
        if bird.y + 8 * SCALE < GROUND_Y then
            bird.vel = math.min(bird.vel + GRAVITY * dt, MAX_FALL)
            bird.y = bird.y + bird.vel * dt
            local vel_frac = bird.vel / SCALE
            bird.rot = math.min(90, math.max(-25, vel_frac * 0.4))
        end
        updateGameoverSequence(dt)

        if go_ok_pressed then
            go_ok_press_t = go_ok_press_t + dt
            if go_ok_press_t >= MENU_BTN_PRESS_DURATION then
                go_ok_pressed = false
                go_ok_press_t = 0
                flap()
            end
        end
    end

    if flash > 0 then
        flash = flash - dt
    end

    bird.frame_t = bird.frame_t + dt
    if state ~= "gameover" and bird.frame_t > FLAP_FRAME_TIME then
        bird.frame_t = 0
        bird.frame = (bird.frame % 3) + 1
    end
end

function updateGameoverSequence(dt)
    gameover_t = gameover_t + dt
    if gameover_t <= go_tally_start_t then
        displayed_score = 0
    elseif gameover_t >= go_tally_start_t + go_tally_duration then
        displayed_score = score
    else
        local t = (gameover_t - go_tally_start_t) / go_tally_duration
        displayed_score = math.floor(t * score)
    end

    if gameover_t <= go_best_start_t then
        displayed_best = prev_best
    elseif gameover_t >= go_best_start_t + go_best_tally_duration then
        displayed_best = best
    else
        local t = (gameover_t - go_best_start_t) / go_best_tally_duration
        displayed_best = math.floor(prev_best + t * (best - prev_best))
    end
end

function flap()
    if paused then return end
    if state == "menu" then

        state = "ready"
        playSound("swoosh")
    elseif state == "ready" then
        state = "play"
        bird.vel = FLAP_VEL
        bird.rot_hold_t = FLAP_ROT_HOLD_T
        playSound("wing")
    elseif state == "play" then
        bird.vel = FLAP_VEL
        bird.rot_hold_t = FLAP_ROT_HOLD_T
        playSound("wing")
    elseif state == "gameover" then
        if bird.y + 8 * SCALE >= GROUND_Y then
            resetGame()
            playSound("swoosh")
        end
    end
end

function togglePause()

    if state ~= "play" then return end
    paused = not paused
end

function love.keypressed(key)
    if key == "escape" then
        togglePause()
    elseif key == "space" or key == "up" then
        flap()
    end
end

local function pointInRect(px, py, r)
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function handlePress(px, py)

    if state == "play" and px and py then
        local pause_rect = pauseButtonRect()
        if pointInRect(px, py, pause_rect) then
            pause_btn_pressed = true
            pause_btn_press_t = 0
            return
        end
    end
    if paused then return end
    if state == "menu" and px and py then
        local start_rect = menuButtonRects()
        if pointInRect(px, py, start_rect) then
            menu_start_pressed = true
            menu_start_press_t = 0
            return
        end
    end
    if state == "gameover" and px and py then
        if bird.y + 8 * SCALE >= GROUND_Y then
            local ok_rect, share_rect = gameoverButtonRects()
            if pointInRect(px, py, ok_rect) then
                go_ok_pressed = true
                go_ok_press_t = 0
            end

        end
        return
    end
    flap()
end

function love.mousepressed(x, y, button)
    if button == 1 then
        handlePress(x, y)
    end
end

function love.touchpressed(id, x, y)
    handlePress(x, y)
end

local function drawNumber(n, cx, y, scale)
    scale = scale or 1
    local gap = NUMBER_DIGIT_GAP_BASE * scale
    local str = tostring(n)
    local widths = {}
    local total = 0
    for i = 1, #str do
        local d = tonumber(str:sub(i, i))
        local w = images.digits[d]:getWidth() * scale
        widths[i] = w
        total = total + w + gap
    end
    total = total - gap
    local x = cx - total / 2
    for i = 1, #str do
        local d = tonumber(str:sub(i, i))
        love.graphics.draw(images.digits[d], x, y, 0, scale, scale)
        x = x + widths[i] + gap
    end
end

local function drawNumberRight(n, right_x, y, scale)
    scale = scale or 1
    local gap = NUMBER_DIGIT_GAP_BASE * scale
    local str = tostring(n)
    local total = 0
    for i = 1, #str do
        local d = tonumber(str:sub(i, i))
        total = total + images.digits[d]:getWidth() * scale + gap
    end
    total = total - gap
    local x = right_x - total
    local left_edge = x
    for i = 1, #str do
        local d = tonumber(str:sub(i, i))
        love.graphics.draw(images.digits[d], x, y, 0, scale, scale)
        x = x + images.digits[d]:getWidth() * scale + gap
    end
    return left_edge
end

function drawGameoverSequence()

    if gameover_t < GO_BANNER_APPEAR_DELAY_T then return end
    local reveal_t = gameover_t - GO_BANNER_APPEAR_DELAY_T

    local go_iw, go_ih = images.gameover:getWidth(), images.gameover:getHeight()
    local go_scale = SCALE * GO_BANNER_SPRITE_SCALE
    local go_h = go_ih * go_scale
    local go_center_x = WIN_W / 2
    local go_final_bottom_y = WIN_H * GO_BANNER_Y_FRAC + go_h

    local go_start_bottom_y = go_final_bottom_y * GO_BANNER_START_Y_FRAC
    local banner_alpha = math.min(1, reveal_t / GO_BANNER_FADE_T)
    local drop_t = math.min(1, reveal_t / GO_BANNER_DROP_T)
    local drop_eased = easeInQuart(drop_t)
    local go_bottom_y = go_start_bottom_y + (go_final_bottom_y - go_start_bottom_y) * drop_eased

    love.graphics.setColor(1, 1, 1, banner_alpha)
    love.graphics.draw(images.gameover, go_center_x, go_bottom_y, 0, go_scale, go_scale, go_iw / 2, go_ih)
    love.graphics.setColor(1, 1, 1, 1)

    local panel_start_t = GO_BANNER_SLIDE_T + GO_PANEL_DELAY_T
    if reveal_t < panel_start_t then return end

    local panel_ui_scale = SCALE * PANEL_UI_SCALE
    local panel_img = images.go_panel
    local panel_rect = gameoverPanelRect()
    local panel_w, panel_h = panel_rect.w, panel_rect.h
    local panel_x = panel_rect.x
    local panel_final_y = panel_rect.y
    local panel_t = easeOutQuint((reveal_t - panel_start_t) / GO_PANEL_SLIDE_T)
    local panel_start_y = WIN_H * GO_PANEL_START_Y_FRAC
    local panel_y = panel_start_y + (panel_final_y - panel_start_y) * panel_t

    love.graphics.setColor(1, 1, 1, panel_t)
    love.graphics.draw(panel_img, panel_x, panel_y, 0, panel_ui_scale, panel_ui_scale)

    local number_scale = (panel_h * PANEL_NUMBER_HEIGHT_FRAC) / images.digits[0]:getHeight()
    local score_right_x = panel_x + panel_w * PANEL_NUMBER_RIGHT_X_FRAC
    local score_y = panel_y + panel_h * PANEL_SCORE_NUMBER_Y_FRAC
    local best_y = panel_y + panel_h * PANEL_BEST_NUMBER_Y_FRAC
    drawNumberRight(displayed_score, score_right_x, score_y, number_scale)
    drawNumberRight(displayed_best, score_right_x, best_y, number_scale)

    love.graphics.setColor(1, 1, 1, 1)

    local tally_finish_t = go_tally_start_t + math.max(go_tally_duration, go_best_tally_duration)
    if gameover_t < tally_finish_t then return end

    if is_new_best then
        local badge_img = images.go_badge_new
        local badge_scale = panel_ui_scale * PANEL_NEW_BADGE_SCALE
        local badge_w = badge_img:getWidth() * badge_scale
        local badge_h = badge_img:getHeight() * badge_scale
        local badge_gap = panel_w * PANEL_NEW_BADGE_GAP_FRAC
        local label_left_x = panel_x + panel_w * PANEL_BEST_LABEL_LEFT_X_FRAC
        local label_vcenter_y = panel_y + panel_h * (PANEL_BEST_LABEL_VCENTER_Y_FRAC + PANEL_NEW_BADGE_Y_NUDGE_FRAC)
        local badge_x = label_left_x - badge_gap - badge_w
        local badge_y = label_vcenter_y - badge_h / 2
        love.graphics.draw(badge_img, badge_x, badge_y, 0, badge_scale, badge_scale)
    end

    local medal_name = medalForScore(score)
    if medal_name then
        local medal_img = images.go_medal[medal_name]
        local medal_w = medal_img:getWidth() * panel_ui_scale
        local medal_h = medal_img:getHeight() * panel_ui_scale
        local medal_cx = panel_x + panel_w * MEDAL_CIRCLE_CENTER_X_FRAC
        local medal_cy = panel_y + panel_h * MEDAL_CIRCLE_CENTER_Y_FRAC
        local medal_radius = math.min(medal_w, medal_h) / 2
        love.graphics.draw(medal_img, medal_cx - medal_w / 2, medal_cy - medal_h / 2, 0, panel_ui_scale, panel_ui_scale)

        local turn_number = math.floor(gameover_t / SPARKLE_TURN_T)
        local turn_t = gameover_t % SPARKLE_TURN_T
        if turn_number ~= medal_sparkle_turn then
            local angle = math.random() * math.pi * 2
            local radius = medal_radius * (SPARKLE_RADIUS_MIN_FRAC + math.random() * (SPARKLE_RADIUS_MAX_FRAC - SPARKLE_RADIUS_MIN_FRAC))
            medal_sparkle = { dx = math.cos(angle) * radius, dy = math.sin(angle) * radius }
            medal_sparkle_turn = turn_number
        end
        if turn_t < SPARKLE_PULSE_T then
            local stage = math.floor(turn_t / SPARKLE_STAGE_T) + 1
            local frame = ({ 1, 2, 3, 2, 1 })[stage]
            local sparkle_scale = panel_ui_scale * SPARKLE_SCALE
            local sparkle_img = images.go_sparkle[frame]
            local sw, sh = sparkle_img:getWidth() * sparkle_scale, sparkle_img:getHeight() * sparkle_scale
            love.graphics.draw(sparkle_img, medal_cx + medal_sparkle.dx - sw / 2, medal_cy + medal_sparkle.dy - sh / 2, 0, sparkle_scale, sparkle_scale)
        end
    end

    local buttons_start_t = tally_finish_t + GO_BEST_DELAY_T + GO_BUTTONS_DELAY_T
    if gameover_t < buttons_start_t then return end
    local buttons_t = math.min(1, (gameover_t - buttons_start_t) / GO_BUTTONS_FADE_T)
    local ok_rect, share_rect = gameoverButtonRects()
    local ok_draw_scale = panel_ui_scale
    local ok_draw_x, ok_draw_y = ok_rect.x, ok_rect.y
    if go_ok_pressed then
        ok_draw_scale = panel_ui_scale * MENU_BTN_PRESS_SCALE
        ok_draw_x = ok_rect.x + (ok_rect.w - ok_rect.w * MENU_BTN_PRESS_SCALE) / 2
        ok_draw_y = ok_rect.y + MENU_BTN_PRESS_SINK_BASE * panel_ui_scale
            + (ok_rect.h - ok_rect.h * MENU_BTN_PRESS_SCALE) / 2
    end
    love.graphics.setColor(1, 1, 1, buttons_t)
    love.graphics.draw(images.go_btn_ok, ok_draw_x, ok_draw_y, 0, ok_draw_scale, ok_draw_scale)
    love.graphics.draw(images.go_btn_share, share_rect.x, share_rect.y, 0, panel_ui_scale, panel_ui_scale)
    love.graphics.setColor(1, 1, 1, 1)
end

function pauseButtonRect()
    local ui_scale = SCALE * PAUSE_BTN_UI_SCALE
    local icon_w, icon_h = images.pause_icon:getWidth() * ui_scale, images.pause_icon:getHeight() * ui_scale
    local margin = PAUSE_BTN_MARGIN_BASE * ui_scale
    local y_nudge = PAUSE_BTN_Y_NUDGE_BASE * ui_scale
    return { x = margin, y = margin - y_nudge, w = icon_w, h = icon_h }
end

function drawPauseButton()
    local ui_scale = SCALE * PAUSE_BTN_UI_SCALE
    local rect = pauseButtonRect()
    local icon_img = paused and images.play_icon or images.pause_icon

    local draw_scale, draw_x, draw_y = ui_scale, rect.x, rect.y
    if pause_btn_pressed then
        draw_scale = ui_scale * MENU_BTN_PRESS_SCALE
        draw_x = rect.x + (rect.w - rect.w * MENU_BTN_PRESS_SCALE) / 2
        draw_y = rect.y + MENU_BTN_PRESS_SINK_BASE * ui_scale
            + (rect.h - rect.h * MENU_BTN_PRESS_SCALE) / 2
    end
    love.graphics.draw(icon_img, draw_x, draw_y, 0, draw_scale, draw_scale)
end

function gameoverPanelRect()
    local go_h = images.gameover:getHeight() * SCALE * GO_BANNER_SPRITE_SCALE
    local go_final_y = WIN_H * GO_BANNER_Y_FRAC
    local panel_ui_scale = SCALE * PANEL_UI_SCALE
    local panel_w = images.go_panel:getWidth() * panel_ui_scale
    local panel_h = images.go_panel:getHeight() * panel_ui_scale
    local panel_x = WIN_W / 2 - panel_w / 2
    local panel_y = go_final_y + go_h + WIN_H * 0.05
    return { x = panel_x, y = panel_y, w = panel_w, h = panel_h }
end

function gameoverButtonRects()
    local panel_ui_scale = SCALE * PANEL_UI_SCALE
    local panel = gameoverPanelRect()
    local ok_w, ok_h = images.go_btn_ok:getWidth() * panel_ui_scale, images.go_btn_ok:getHeight() * panel_ui_scale
    local share_w, share_h = images.go_btn_share:getWidth() * panel_ui_scale, images.go_btn_share:getHeight() * panel_ui_scale
    local btn_gap = 16 * panel_ui_scale
    local btns_w = ok_w + btn_gap + share_w
    local btns_x = panel.x + panel.w / 2 - btns_w / 2
    local btns_y = panel.y + panel.h + WIN_H * 0.04
    local ok_rect = { x = btns_x, y = btns_y, w = ok_w, h = ok_h }
    local share_rect = { x = btns_x + ok_w + btn_gap, y = btns_y, w = share_w, h = share_h }
    return ok_rect, share_rect
end

function menuButtonRects()
    local ui_scale = SCALE * MENU_UI_SCALE
    local bar_h = images.menu_bottom_bar:getHeight() * SCALE
    local bar_y = WIN_H - bar_h
    local btn_gap = 16 * ui_scale
    local start_w, start_h = images.menu_btn_start:getWidth() * ui_scale, images.menu_btn_start:getHeight() * ui_scale
    local score_w, score_h = images.menu_btn_score:getWidth() * ui_scale, images.menu_btn_score:getHeight() * ui_scale
    local btns_w = start_w + btn_gap + score_w
    local btns_x = WIN_W / 2 - btns_w / 2

    local btns_y = bar_y - MENU_BTN_GAP_ABOVE_BAR_BASE * ui_scale - start_h
    local start_rect = { x = btns_x, y = btns_y, w = start_w, h = start_h }
    local score_rect = { x = btns_x + start_w + btn_gap, y = btns_y, w = score_w, h = score_h }
    return start_rect, score_rect, bar_y, bar_h
end

function drawMenu()
    local ui_scale = SCALE * MENU_UI_SCALE
    local logo_img = images.menu_logo_flappy_bird
    local icon_img = images.menu_lobby_bird[bird.frame]

    local logo_w, logo_h = logo_img:getWidth() * ui_scale, logo_img:getHeight() * ui_scale

    local icon_scale = (logo_h * MENU_ICON_TO_TEXT_RATIO) / icon_img:getHeight()
    local icon_w, icon_h = icon_img:getWidth() * icon_scale, icon_img:getHeight() * icon_scale

    local icon_gap = MENU_ICON_GAP_BASE * ui_scale

    local lockup_w = logo_w + icon_gap + icon_w
    local lockup_x = WIN_W / 2 - lockup_w / 2
    local logo_top_y = WIN_H * MENU_LOGO_Y_FRAC + menu_bounce_off

    local logo_x, logo_y = lockup_x, logo_top_y

    love.graphics.draw(logo_img, logo_x, logo_y, 0, ui_scale, ui_scale)

    local icon_x = logo_x + logo_w + icon_gap
    local icon_y = logo_y + (logo_h - icon_h) / 2 - MENU_ICON_EXTRA_LIFT_BASE * ui_scale
    love.graphics.draw(icon_img, icon_x, icon_y, 0, icon_scale, icon_scale)

    local start_rect, score_rect, bar_y, bar_h = menuButtonRects()
    local start_draw_scale = ui_scale
    local start_draw_x, start_draw_y = start_rect.x, start_rect.y
    if menu_start_pressed then
        start_draw_scale = ui_scale * MENU_BTN_PRESS_SCALE

        start_draw_x = start_rect.x + (start_rect.w - start_rect.w * MENU_BTN_PRESS_SCALE) / 2
        start_draw_y = start_rect.y + MENU_BTN_PRESS_SINK_BASE * ui_scale
            + (start_rect.h - start_rect.h * MENU_BTN_PRESS_SCALE) / 2
    end
    love.graphics.draw(images.menu_btn_start, start_draw_x, start_draw_y, 0, start_draw_scale, start_draw_scale)
    love.graphics.draw(images.menu_btn_score, score_rect.x, score_rect.y, 0, ui_scale, ui_scale)

    local bar_w = images.menu_bottom_bar:getWidth() * SCALE
    local bar_tiles = math.ceil(WIN_W / bar_w) + 2
    for i = 0, bar_tiles - 1 do
        love.graphics.draw(images.menu_bottom_bar, base_x + i * bar_w, bar_y, 0, SCALE, SCALE)
    end

    local copy_scale = SCALE * MENU_COPYRIGHT_SCALE
    local copy_img = images.menu_copyright
    local copy_w, copy_h = copy_img:getWidth() * copy_scale, copy_img:getHeight() * copy_scale
    local cx = WIN_W / 2 - copy_w / 2
    local cy = bar_y + bar_h * MENU_COPYRIGHT_Y_FRAC
    love.graphics.draw(copy_img, cx, cy, 0, copy_scale, copy_scale)
end

function drawReady()
    local ui_scale = SCALE * READY_UI_SCALE

    local get_img, ready_img = images.ready_logo_get, images.ready_logo_ready
    local get_w, get_h = get_img:getWidth() * ui_scale, get_img:getHeight() * ui_scale
    local ready_w, ready_h = ready_img:getWidth() * ui_scale, ready_img:getHeight() * ui_scale
    local word_gap = READY_WORD_GAP_BASE * ui_scale
    local logo_w = get_w + word_gap + ready_w
    local logo_x = WIN_W / 2 - logo_w / 2
    local logo_y = WIN_H * READY_LOGO_Y_FRAC
    love.graphics.draw(get_img, logo_x, logo_y, 0, ui_scale, ui_scale)
    love.graphics.draw(ready_img, logo_x + get_w + word_gap, logo_y, 0, ui_scale, ui_scale)

    local pointer_img = images.ready_tap_pointer
    local pointer_w, pointer_h = pointer_img:getWidth() * ui_scale, pointer_img:getHeight() * ui_scale
    local pointer_x = WIN_W / 2 - pointer_w * READY_POINTER_CORE_CENTER_FRAC
    local pointer_y = WIN_H * READY_POINTER_Y_FRAC
    love.graphics.draw(pointer_img, pointer_x, pointer_y, 0, ui_scale, ui_scale)
end

function love.draw()
    local bg = (bg_variant == "day") and images.bg_day or images.bg_night

    local bg_w = bg:getWidth() * SCALE
    local bg_tiles = math.ceil(WIN_W / bg_w) + 2
    for i = 0, bg_tiles - 1 do
        love.graphics.draw(bg, i * bg_w, 0, 0, SCALE, SCALE)
    end

    local pipe_sx = SCALE * PIPE_SPRITE_SCALE
    local cap_h = PIPE_CAP_PX * pipe_sx
    for _, p in ipairs(pipes) do
        local top_h = p.gap_center - p.gap / 2
        local bot_y = p.gap_center + p.gap / 2

        love.graphics.draw(images.pipe_bottom, images.pipe_bottom_cap_quad, p.x, bot_y, 0, pipe_sx, pipe_sx)
        local bot_body_src_h = images.pipe_bottom:getHeight() - PIPE_CAP_PX
        local bot_body_len = (GROUND_Y - (bot_y + cap_h)) + 40
        if bot_body_len > 0 then
            love.graphics.draw(images.pipe_bottom, images.pipe_bottom_body_quad, p.x, bot_y + cap_h, 0, pipe_sx, bot_body_len / bot_body_src_h)
        end

        love.graphics.draw(images.pipe_top, images.pipe_top_cap_quad, p.x, top_h - cap_h, 0, pipe_sx, pipe_sx)
        local top_body_src_h = images.pipe_top:getHeight() - PIPE_CAP_PX
        local top_body_len = top_h - cap_h
        if top_body_len > 0 then
            love.graphics.draw(images.pipe_top, images.pipe_top_body_quad, p.x, 0, 0, pipe_sx, top_body_len / top_body_src_h)
        end
    end

    if state ~= "menu" then
        local base_w = images.base:getWidth() * SCALE
        local base_tiles = math.ceil(WIN_W / base_w) + 2
        for i = 0, base_tiles - 1 do
            love.graphics.draw(images.base, base_x + i * base_w, GROUND_Y, 0, SCALE, SCALE)
        end
    end

    if state == "menu" then

        drawMenu()
    else

        love.graphics.draw(
            images.birds[bird_color][bird.frame], BIRD_X, bird.y,
            math.rad(bird.rot), SCALE, SCALE, 17, 12
        )

        if state == "ready" then
            drawReady()
        elseif state == "play" then
            drawNumber(score, WIN_W / 2, WIN_H * 0.039, SCALE)
            drawPauseButton()
        elseif state == "gameover" then
            drawGameoverSequence()
        end
    end

    if flash > 0 then
        love.graphics.setColor(1, 1, 1, flash / 0.15 * 0.6)
        love.graphics.rectangle("fill", 0, 0, WIN_W, WIN_H)
        love.graphics.setColor(1, 1, 1, 1)
    end
end
