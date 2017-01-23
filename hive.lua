#!/usr/bin/env lua
--
-- hive.lua
--
-- Created by Ruibin.Chow on 2017/01/21.
-- Copyright (c) 2017年 Ruibin.Chow All rights reserved.

local HIVEFILE = "Hivefile"
local Github = "github.com"
local git = "git"
local CURRENT_VERSION = "0.0.1"

local Hivefile_KEY_ACTION = "action"
local Hivefile_KEY_NAME = "name"
local Hivefile_KEY_TYPE = "type"
local Hivefile_KEY_VALUE = "value"

local HiveDir = "Hive"
local HiveCache = HiveDir .. "/Cache"
local HiveCheckouts = HiveDir .. "/" .. "Checkouts"
local HiveUpdate = false

function fileExists(path)
    local file = io.open(path, "rb")
    if file then file:close() end
    return file ~= nil
end

function splitStringByChar(szFullString, szSeparator)  
    local nFindStartIndex = 1
    local nSplitIndex = 1  
    local nSplitArray = {}  
    while true do  
        local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)  
        if not nFindLastIndex then  
            nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))  
            break  
        end  
        nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)  
        nFindStartIndex = nFindLastIndex + string.len(szSeparator)  
        nSplitIndex = nSplitIndex + 1  
    end  
    return nSplitArray  
end

function trim(s) 
    return (string.gsub(s, "^%s*(.-)%s*$", "%1")) 
end

function processEachLine(lineTable)
    tempList = {}
    tempList[Hivefile_KEY_ACTION] = lineTable[1]
    tempList[Hivefile_KEY_NAME] = string.sub(lineTable[2], 2, -2)
    if #lineTable > 2 then
        typeArray = splitStringByChar(lineTable[3], "=>")
        tempList[Hivefile_KEY_TYPE] = typeArray[1]
        tempList[Hivefile_KEY_VALUE] = string.sub(typeArray[2], 2, -2)
    end
    -- print(tempList)
    return tempList
end

function readHivefile()
    local file = io.open(HIVEFILE);
    if file == nil then 
        print("It must have Hivefile!")
        return nil
    end 
    -- local data = file:read("*a") -- 读取所有内容
    local hivefileTable = {}
    local index = 1
    for line in file:lines() do
        if #line ~= 0 and string.sub(line, 1, 1) ~= "#" then
            local lineString = trim(line)
            -- print(lineString) -- 这里就是每次取一行
            local lineTable = splitStringByChar(lineString, " ")
            hivefileTable[index] = processEachLine(lineTable)
            index = index + 1
        end
    end
    file:close()
    return hivefileTable
end

function help()
    local  str = [[
Available commands:
    create            Create a blank Hivefile
    checkout          Check out the project's dependencies
    update            Update the project's dependencies
    version           Display the current version of Hive
    help              Display general or command-specific helps

Hivefile Example

    Github "zruibin/RBMenu" 
    #Github "zruibin/RBMenu" master
    #Github "zruibin/RBMenu" tag=>"xx.xx"
    #Github "zruibin/RBMenu" commit=>"..."

    #coding
    git "https://coding.net/zruibin/h5.git" 
    #git "https://coding.net/zruibin/h5.git" master
    #git "https://coding.net/zruibin/h5.git" tag=>"xx.xx"
    #git "https://coding.net/zruibin/h5.git" commit=>".."

    #location
    git "zruibin/axle" path=>"../Project/axle"
    ]]
    print(str)
end

function version()
    print(CURRENT_VERSION)
end

function authRepo(cacheLog, type, version)
    if HiveUpdate == false then return true end
    if fileExists(cacheLog) == false then return true end
    if type == "master" or type == "path" or type == nil then return true end

    local file = io.open(cacheLog, "r")
    local data = file:read("*a") -- 读取所有内容
    file:close()
    if version ~= data then return true end

    return false
end

function cacheRepo(value)
    print("------------------------------------------------------------")
    local action = value[Hivefile_KEY_ACTION]
    -- commit 或 tag 相等就跳过
    local  type = value[Hivefile_KEY_TYPE]
    local url = value[Hivefile_KEY_NAME]
    
    local package = nil
    if action ~= git then
        package = splitStringByChar(value[Hivefile_KEY_NAME], "/")  -- Github
        url = "https://github.com/" .. value[Hivefile_KEY_NAME] .. ".git"
    else
        if type ~= "path" then
            local tempPackage = splitStringByChar(url, "/")
            tempName = tempPackage[#tempPackage-1] .. "/" .. string.sub(tempPackage[#tempPackage],1, -5)
            package = splitStringByChar(tempName, "/")
        else
            package = splitStringByChar(url, "/")
            url = value[Hivefile_KEY_VALUE]
        end
    end

    local name = package[2]

    local version = ""
    if value[Hivefile_KEY_VALUE] ~= nil then version = value[Hivefile_KEY_VALUE] end

    -- if true then return end

    local cacheDir = HiveCache .. "/" .. name
    print(cacheDir)
    local projectDir = HiveCheckouts .. "/" .. name
    local project = projectDir .. ".zip"

    local cacheLog = cacheDir .. "/cache.log"

    if authRepo(cacheLog, type, version) or type == "path" then
        if fileExists(cacheDir) then os.execute("rm -rf  " .. cacheDir) end
      
        os.execute("git clone --bare " .. url .. " " .. cacheDir)
        local archiveVerion = version
        if archiveVerion == "" or type == "path" then archiveVerion = "master" end
        os.execute("git archive --remote=" .. cacheDir .. " --format zip --output " .. project .. " " .. archiveVerion)

        os.execute("rm -rf " .. projectDir)
        os.execute("unzip " .. project .. " -d " .. projectDir)
        os.execute("rm " .. project)

        -- 记录已下载的
        local file = io.open(cacheLog, "w");
        file:write(version)
        file:close()
     end    
end

function checkout()
    local hivefileTable = readHivefile()
    if hivefileTable == nil then return end
    if not fileExists(HiveDir) then os.execute("mkdir " .. HiveDir) end
    if not fileExists(HiveCache) then os.execute("mkdir " .. HiveCache) end
    if not fileExists(HiveCheckouts) then os.execute("mkdir " .. HiveCheckouts) end

    for i=1, #hivefileTable do
        cacheRepo(hivefileTable[i])
    end
end

function update()
    HiveUpdate = true
    checkout()
end

function create()
    local file = io.open(HIVEFILE, "w");
    file:write("#This is a blank Hivefile")
    file:close()
end

function Main()
    local action = arg[1]
    if action == nil or action == "checkout" then checkout() end
    if action == "update" then update() end
    if action == "create" then create() end
    if action == "help" then help() end
    if action == "version" then version() end
    if action == "clean" then os.execute("rm -rf " .. HiveDir) end
end

Main()


