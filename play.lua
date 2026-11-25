local dfpwm = require("cc.audio.dfpwm")
local speakers = { peripheral.find("speaker") }

if #speakers == 0 then
    error("No speaker attached!")
end

local apiUrl = "https://api.github.com/repos/VEXGOS/1/contents/"
local headers = { ["User-Agent"] = "CC-Tweaked-Player" }

term.clear()
term.setCursorPos(1, 1)
print("Loading playlist from GitHub...")

local res, err = http.get(apiUrl, headers)
if not res then
    error("GitHub API error: " .. tostring(err))
end

local data = textutils.unserializeJSON(res.readAll())
res.close()

if type(data) ~= "table" then
    error("Failed to parse repository files.")
end

local tracks = {}
for _, item in ipairs(data) do
    if item.type == "file" and item.name:match("%.dfpwm$") then
        table.insert(tracks, {
            name = item.name:gsub("%.dfpwm$", ""),
            url = item.download_url
        })
    end
end

if #tracks == 0 then
    error("No .dfpwm files found in repository.")
end

local function playTrack(track)
    print("\nConnecting: " .. track.name)
    local audioRes, audioErr = http.get(track.url, headers)
    if not audioRes then
        print("Download error: " .. tostring(audioErr))
        return
    end

    print("Playing: " .. track.name .. " (Hold Ctrl+T to stop)")
    local decoder = dfpwm.make_decoder()

    while true do
        local chunk = audioRes.read(16 * 1024)
        if not chunk then break end
        local buffer = decoder(chunk)

        for _, sp in ipairs(speakers) do
            while not sp.playAudio(buffer, 3.0) do
                os.pullEvent("speaker_audio_empty")
            end
        end
    end

    audioRes.close()
    print("Finished.")
end

while true do
    term.clear()
    term.setCursorPos(1, 1)
    print("=== VEXGOS Music Player ===")
    for i, track in ipairs(tracks) do
        print(i .. ". " .. track.name)
    end
    print("0. Exit")
    write("\nSelect track number: ")

    local choice = tonumber(read())
    if choice == 0 then
        break
    elseif choice and tracks[choice] then
        playTrack(tracks[choice])
        sleep(1)
    else
        print("Invalid number!")
        sleep(1)
    end
end
