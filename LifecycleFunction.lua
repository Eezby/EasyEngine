local LifecycleFunction = {}
LifecycleFunction.__index = LifecycleFunction

export type LifecycleFunctionType = {
    name: string,
    isAsync: boolean
}

function LifecycleFunction.new(name: string): LifecycleFunctionType
    local self: LifecycleFunctionType = {
        name = name,
        async = false,
        timeout = -1
    }

    return setmetatable(self, LifecycleFunction)
end

function LifecycleFunction:Async(isAsync: boolean)
    self.isAsync = isAsync
    return self
end

function LifecycleFunction:Timeout(timeout: number)
   self.timeout = timeout
   return self
end

return LifecycleFunction