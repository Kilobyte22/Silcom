local hooks = {}

--[[
    Hook naming conventions:
    <component>:<element>
    Hook names are lowercase, with underscores.
    examples:
        sched:thread_death
        sandbox:setup_env
]]

function hook(what, callback)
    hooks[what] = hooks[what] or {} -- i miss rubys ||= operator D:
    table.insert(hooks[what], callback)
end

function callHook(what, ...)
    log('hook: '..what)
    local hooklist = hooks[what]
    if hooklist then
        for i = 1, #hooklist do
            hooklist[i](...)
        end
    end
end