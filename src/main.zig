const std = @import("std");

const c = @cImport({
    @cInclude("luau/VM/include/lua.h");
    @cInclude("luau/VM/include/lualib.h");
    @cInclude("luau/Compiler/include/luacode.h");
});

const luau = @import("luau.zig");
const luau_lib = @import("luau-lib.zig");

const LuaState = c.lua_State;

fn read_script(allocator: std.mem.Allocator, path: []const u8) ![:0]u8 {
    const script = try std.fs.cwd().openFile(path, .{});
    defer script.close();

    const content = try script.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    const content_nullterm = try allocator.dupeZ(u8, content);
    return content_nullterm;
}

fn hello_world(L: ?*luau.LuauState) callconv(.C) i32 {
    _ = L;
    std.debug.print("hello from a function in zig!\n", .{});
    return 0;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const L = luau.new_state(allocator);
    defer luau.close(L);

    luau_lib.open_libs(L);
    luau_lib.sandbox(L);

    luau.push_c_function(L, &hello_world, "hello_world");
    luau.call(L, 0, 0);

    const source = try read_script(allocator, "hello.lua");
    defer allocator.free(source);

    const opts = luau.CompileOptions{
        .optimizationLevel = 1,
    };
    const bytecode = try luau.compile(allocator, source, opts);
    defer allocator.free(bytecode);

    const load_res = luau.load(L, bytecode);
    if (load_res != 0) {
        std.debug.print("failed to load\n", .{});
        return;
    }

    const status = luau.co_resume(L, null, 0);

    if (status == 0) {
        std.debug.print("success\n", .{});
    } else {
        std.debug.print("failed\n", .{});
    }
}
