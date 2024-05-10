const luau = @import("luau.zig");

const c = @import("c.zig");

const LuauState = luau.LuauState;

pub inline fn open_libs(L: *LuauState) void {
    c.luaL_openlibs(L);
}

pub inline fn sandbox(L: *LuauState) void {
    c.luaL_sandbox(L);
}

pub inline fn sandbox_thread(L: *LuauState) void {
    c.luaL_sandboxthread(L);
}

pub inline fn new_state() *luau.LuauState {
    return c.luaL_newstate().?;
}
