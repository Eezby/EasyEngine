local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Promise = require(script.Parent.Promise)
local Signal = require(script.Parent.Signal)

local Configuration = require(script.Configuration)
local LifecycleFunction = require(script.LifecycleFunction)

local EasyEngine = {}
EasyEngine.Modules = {
    Configuration = Configuration,
    LifecycleFunction = LifecycleFunction
}

EasyEngine.Booted = false
EasyEngine.BootedFromTraceback = nil
EasyEngine.BootStartTime = nil
EasyEngine.BootTotalTime = nil
EasyEngine.Configuration = nil
EasyEngine.BootModules = {}
EasyEngine.BootRequiredModules = {}

EasyEngine.ServerBootFinished = Signal.new()
EasyEngine.ClientBootFinished = Signal.new()

local function debugPrint(configuration: Configuration.ConfigurationType, ...)
    if configuration.debugMode then
        local prefix = if RunService:IsServer() then "🟩" else "🟦"
        print(`{prefix} [EasyEngine]`, ...)
    end
end

local function errorPrint(...)
    local prefix = if RunService:IsServer() then "🟩" else "🟦"
    print(`{prefix}🟥 [EasyEngine]`, ...)
end

local function getModuleTotalDescendants(directory: Instance)
    local total = 0
    for _,descendant in directory:GetDescendants() do
        if not descendant:IsA("ModuleScript") then
            continue
        end

        total = total + 1
    end

    return total
end

local function getDirectoryContext(directory: Instance)
    if directory == ReplicatedStorage or directory:IsDescendantOf(ReplicatedStorage) then
        return "Shared"
    elseif directory == ServerScriptService then
        return "Server"
    elseif directory == ServerStorage then
        return "Server"
    elseif directory:IsDescendantOf(Players.LocalPlayer) then
        return "Client"
    end
end

function EasyEngine.Boot(configuration: Configuration.ConfigurationType)
    if EasyEngine.Booted then
        error(`EasyEngine already booted from: {EasyEngine.BootedFromTraceback}`)
    end

    EasyEngine.Booted = true
    EasyEngine.BootedFromTraceback = debug.traceback()
    EasyEngine.BootStartTime = os.clock()
    EasyEngine.Configuration = configuration

    debugPrint(EasyEngine.Configuration, `Boot started`)

    -- Wait for server to boot before client boots
    if RunService:IsClient() then
        if not script:GetAttribute("ServerBooted") then
            script:GetAttributeChangedSignal("ServerBooted"):Wait()
        end
    end

    EasyEngine._GetModules()
    EasyEngine._RequireModules()

    for _,lifecycleFunction in EasyEngine.Configuration.lifecycle do
        EasyEngine._RunLifecycleFunction(lifecycleFunction)
    end

    EasyEngine._FinishBoot()
end

function EasyEngine.GetCurrentBootTime()
    return os.clock() - EasyEngine.BootStartTime
end

-------------------------------------------------
-- Internal functions
-------------------------------------------------

function EasyEngine._GetModules()
    for _,directory in EasyEngine.Configuration.directories do
        for _,descendant in directory:GetDescendants() do
            if not descendant:IsA("ModuleScript") then
                continue
            end

            if EasyEngine.Configuration.blacklist[descendant:GetFullName()] == true then
                continue
            end

            table.insert(EasyEngine.BootModules, descendant)
        end
    end

    debugPrint(EasyEngine.Configuration, `Modules found: {#EasyEngine.BootModules}`)
end

function EasyEngine._RequireModules()
    local requirePromises = {}

    for _,module in EasyEngine.BootModules do
        local promise = Promise.new(function(resolve: () -> nil)
            EasyEngine.BootRequiredModules[module] = require(module)
            resolve()
        end):catch(function(errorMessage: string)
            errorPrint(`Error requiring module {module:GetFullName()}: {errorMessage}`)
        end)

        table.insert(requirePromises, promise)
    end

    Promise.allSettled(requirePromises):await()

    debugPrint(EasyEngine.Configuration, `Modules required: {#requirePromises}`)
end

function EasyEngine._RunLifecycleFunction(lifecycleFunction: LifecycleFunction.LifecycleFunctionType)
    local lifecyclePromises = {}

    for module,requiredModule in EasyEngine.BootRequiredModules do
        local success, hasLifecycleFunction = pcall(function()
            return requiredModule[lifecycleFunction.name] ~= nil
        end)

        if not success then
            continue
        end

        if not hasLifecycleFunction then
            continue
        end

        if not lifecycleFunction.isAsync then
            local promise = Promise.new(function(resolve: () -> nil)
                requiredModule[lifecycleFunction.name]()
                resolve()
            end):catch(function(errorMessage: string)
                errorPrint(`Error running lifecycle function {lifecycleFunction.name} in {module:GetFullName()}: {errorMessage}`)
            end)

            if lifecycleFunction.timeout > 0 then
                promise = promise:timeout(lifecycleFunction.timeout)
            end

            table.insert(lifecyclePromises, promise)
        else
            task.spawn(requiredModule[lifecycleFunction.name])
        end
    end

    if not lifecycleFunction.isAsync then
        Promise.allSettled(lifecyclePromises):await()
    end

    debugPrint(EasyEngine.Configuration, `Lifecycle function {lifecycleFunction.name} ran on {#lifecyclePromises} modules`)
end

function EasyEngine._FinishBoot()
    EasyEngine.BootTotalTime = os.clock() - EasyEngine.BootStartTime

    if RunService:IsServer() then
        EasyEngine.ServerBootFinished:Fire()

        script:SetAttribute("ServerBooted", true)
        debugPrint(EasyEngine.Configuration, `Server booted: {EasyEngine.BootTotalTime}s`)
    elseif RunService:IsClient() then
        EasyEngine.ClientBootFinished:Fire()

        script:SetAttribute("ClientBooted", true)
        debugPrint(EasyEngine.Configuration, `Client booted: {EasyEngine.BootTotalTime}s`)
    end
end

return EasyEngine