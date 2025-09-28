local LifecycleFunction = require(script.Parent.LifecycleFunction)

local Configuration = {}
Configuration.__index = Configuration

export type ConfigurationType = {
    debugMode: boolean,
    lifecycle: {LifecycleFunction.LifecycleFunctionType}
}

function Configuration.new()
    return setmetatable({
        debugMode = false,
        lifecycle = {},
        directories = {},
        blacklist = {}
    }, Configuration)
end

function Configuration:Debug(debugMode: boolean)
    self.debugMode = debugMode
    return self
end

function Configuration:Lifecycle(lifecycle: {LifecycleFunction.LifecycleFunctionType})
    self.lifecycle = lifecycle
    return self
end

function Configuration:Directories(directories: {Instance})
    self.directories = directories
    return self
end

function Configuration:Blacklist(pathNames: {string})
    self.blacklist = pathNames
    return self
end

return Configuration