-- tweak for your repo
local installRepo = ""
local ref = "" -- leave blank for master
local repoPath = "" -- leave blank for /src
local minified = nil -- wheter or not to force your install to be minified
-- `nil` = use cc-updater global (defaults to true)
-- `true` = force this repo only to be minified (other repos still use global)
-- `false` = force this repo only to not be minified (other repos still use global)
-- Should stay `nil` in most cases since CC computers have file limits. `
--  false` is good for example/demo or other projects you want the user
--  to be able to easily read the code for

if installRepo == "" then
    error("installRepo is not configured")
end

local repoString = installRepo
if ref ~= "" then
    repoString = repoString .. "@" .. ref
end
if repoPath ~= "" then
    repoString = repoString .. ":" .. repoPath
end

local existingRepos = settings.get("ghu.extraRepos", {})
local addRepoIndex = #existingRepos + 1
for index, repo in ipairs(existingRepos) do
    if #repo >= #installRepo then
        if repo:sub(1, #installRepo) == installRepo then
            local matched = false
            if repoPath == "" then
                if repo:match("%:") ~= ":" then
                    matched = true
                end
            elseif repo:sub(#repo - #repoPath + 1) == repoPath then
                matched = true
            end
            if matched then
                addRepoIndex = index
                break
            end
        end
    end
end
existingRepos[addRepoIndex] = repoString
settings.set("ghu.extraRepos", existingRepos)
if minified ~= nil then
    settings.set(string.format("ghu.minified.%s", repoString), minified)
end
settings.save()

local ghuUpdatePath = settings.get("ghu.base", "/ghu") .. "core/programs/ghuupdate.lua"
if fs.exists(ghuUpdatePath) then
    if shell.run(ghuUpdatePath) then
        print("Install complete")
    end
else
    local ghBase = "https://raw.githubusercontent.com/"
    local updaterRepo = "AngellusMortis/cc-updater"
    local updaterRef = "master"
    local updaterUrl = ghBase .. updaterRepo .. "/" .. updaterRef .. "/install.lua"
    shell.run(string.format("wget run %s", updaterUrl))
end
