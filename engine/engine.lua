game = {}

game.keys = {
    "d", "f", "j", "k"
}

game.highspeed = 1 --lmao iidx term
game.inputoffset = 0

function game:load(sobj)
    -- Loads a song and begins gameplay.

    if game.audio then
        game.audio:stop()
        game.audio:release()
    end

    local song = sobj.id
    self:init()
    local h = love.filesystem.getInfo("songs/"..song, nil)
    if not h then error("Attempted to load non-existent song folder: "..song) end
    game.chart = json.decode(love.filesystem.read(string.format('songs/%s/%s.json', song, song)))
    table.sort(game.chart.notes, function(a, b) return a.beat < b.beat end) -- !!IMPORTANT!!
    local audio = love.audio.newSource(string.format("songs/%s/%s", song, game.chart.audio), "static")
    game.audio = audio
    game:switchState("game")
end

function game:init()
    game.beat = 0
    game.currentbpm = 0
    game.spb = 0

    game.started = false

    game.clear = true

    game.curr = {}
    game.curr.bpm = 1
    game.curr.note = 1

    game.judgments = {
        0, 0, 0, 0, 0
    }

    game.judgewindows = {
        0.033,
        0.066,
        0.133,
        0.300,
        -1
    }
    game.lastjudge = 0
    game.lastjudgetime = 0
    game.combo = 0
end

function game:calcnoteoffset()
    return game.inputoffset + (game.chart.offset or 0)
end

function game:update()
    if not game.started then
        game.started = true
        game.audio:play()
    end

    if game.beat >= (game.chart.bpms[game.curr.bpm] or {math.huge})[1] then
        game.bpm = game.chart.bpms[game.curr.bpm][2]
        game.curr.bpm = game.curr.bpm + 1
        game.spb = 60/game.bpm
    end

    local curr_audiopos = game.audio:tell() + game:calcnoteoffset()

    local ind, bobj = findclosestnote()
    if bobj then
        local note_audiopos = (bobj.beat*60) / game.bpm

        print(curr_audiopos, note_audiopos)
        if curr_audiopos >= note_audiopos+game.judgewindows[4]/2 then
            game:registerjudgment(5)
        end
    end

    game.beat = (curr_audiopos - game:calcnoteoffset())/game.spb
end

function game:registerjudgment(t)
    game.judgments[t] = game.judgments[t] + 1
    game.lastjudge = t
    game.lastjudgetime = love.timer.getTime()
    game.curr.note = game.curr.note + 1
    if t == 4 or t == 5 then
        game.combo = 0
    else
        game.combo = game.combo + 1
    end
end

function game:checkinput()
    local ind, bobj = findclosestnote()
    if not bobj then return true end
    local note_audiopos = (bobj.beat*60) / game.bpm
    local curr_audiopos = game.audio:tell() + game:calcnoteoffset()

    local jud = 1

    -- UHHHH

    local i = bobj.notes
    if love.keyboard.isDown(game.keys[i]) then
        for jud=1,4 do
            if note_audiopos <= curr_audiopos + game.judgewindows[jud]/2 and note_audiopos >= curr_audiopos - game.judgewindows[jud]/2 then
                game:registerjudgment(jud)
                return false
            end
        end
        return true
    end
end

function game:checkinputex() -- i win, bitch
    local stop_infinite_looping_you_fuck = 0
    while not game:checkinput() or stop_infinite_looping_you_fuck > LANE_COUNT do
        stop_infinite_looping_you_fuck = stop_infinite_looping_you_fuck + 1
        if stop_infinite_looping_you_fuck > LANE_COUNT then break end
    end
end