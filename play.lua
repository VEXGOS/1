local dfpwm = require("cc.audio.dfpwm")
local speakers = { peripheral.find("speaker") }
local decoder = dfpwm.make_decoder()

local url = "https://raw.githubusercontent.com/VEXGOS/1/main/htxm.dfpwm"
local response = http.get(url)
if not response then error("Не вдалося завантажити трек") end

while true do
    local chunk = response.read(16 * 1024)
    if not chunk then break end
    local buffer = decoder(chunk)

    for _, sp in ipairs(speakers) do
        while not sp.playAudio(buffer, 3.0) do
            os.pullEvent("speaker_audio_empty")
        end
    end
end

response.close()
