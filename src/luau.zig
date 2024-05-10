const std = @import("std");

const c = @import("c.zig");

inline fn to_bool(i: c_int) bool {
    return i != 0;
}

pub const CompileOptions = extern struct {
    optimizationLevel: i32 = 1,
    debugLevel: i32 = 1,
    typeLevelInfo: i32 = 0,
    coverageLevel: i32 = 0,
    vectorLib: ?*[*c]u8 = null,
    vectorCtor: ?*[*c]u8 = null,
    vectorType: ?*[*c]u8 = null,
    mutableGlobals: ?*[*c]u8 = null,
};

pub const LuauState = c.lua_State;

pub const ZigFn = *const fn (L: ?*LuauState) callconv(.C) c_int;
pub const ZigContinueFn = *const fn (L: ?*LuauState, status: c_int) callconv(.C) c_int;

fn luau_allocator(allocator_opaque: *anyopaque, ptr_opaque: [*]u8, osize: usize, nsize: usize) callconv(.C) ?*anyopaque {
    const allocator: *std.mem.Allocator = @ptrCast(@alignCast(allocator_opaque));

    const ptr = ptr_opaque[0..osize];

    if (nsize == 0) {
        allocator.free(ptr);
        return null;
    }

    const realloc = allocator.realloc(ptr, nsize) catch unreachable;
    return realloc.ptr;
}

// -------------------------------------------------------------
// State Manipulation
// -------------------------------------------------------------

pub inline fn new_state(alloc: std.mem.Allocator) *LuauState {
    return c.lua_newstate(@ptrCast(&luau_allocator), @ptrCast(alloc.ptr)).?;
}

pub inline fn close(L: *LuauState) void {
    c.lua_close(L);
}

pub inline fn new_thread(L: *LuauState) *LuauState {
    return c.lua_newthread(L);
}

pub inline fn main_thread(L: *LuauState) *LuauState {
    return c.lua_mainthread(L);
}

pub inline fn reset_thread(L: *LuauState) void {
    c.lua_resetthread(L);
}

pub inline fn is_thread_reset(L: *LuauState) bool {
    return to_bool(c.lua_isthreadreset(L));
}

// -------------------------------------------------------------
// Basic Stack Manipulation
// -------------------------------------------------------------

pub inline fn abs_index(L: *LuauState, idx: i32) i32 {
    return @as(i32, c.lua_absindex(L, @as(c_int, idx)));
}

pub inline fn get_top(L: *LuauState) i32 {
    return @as(i32, c.lua_gettop(L));
}

pub inline fn set_top(L: *LuauState, idx: i32) void {
    c.lua_settop(L, @as(c_int, idx));
}

pub inline fn push_value(L: *LuauState, idx: i32) void {
    c.lua_pushvalue(L, @as(c_int, idx));
}

pub inline fn remove(L: *LuauState, idx: i32) void {
    c.lua_remove(L, @as(c_int, idx));
}

pub inline fn insert(L: *LuauState, idx: i32) void {
    c.lua_insert(L, @as(c_int, idx));
}

pub inline fn replace(L: *LuauState, idx: i32) void {
    c.lua_replace(L, @as(c_int, idx));
}

pub inline fn check_stack(L: *LuauState, size: i32) i32 {
    return @as(i32, c.lua_checkstack(L, @as(c_int, size)));
}

pub inline fn raw_check_stack(L: *LuauState, size: i32) void {
    c.lua_rawcheckstack(L, @as(c_int, size));
}

pub inline fn xmove(from: *LuauState, to: *LuauState, n: i32) void {
    c.lua_xmove(from, to, @as(c_int, n));
}

pub inline fn xpush(from: *LuauState, to: *LuauState, idx: i32) void {
    c.lua_xpush(from, to, @as(c_int, idx));
}

// -------------------------------------------------------------
// Access Functions
// -------------------------------------------------------------

pub inline fn is_number(L: *LuauState, idx: i32) bool {
    return to_bool(c.lua_isnumber(L, @as(c_int, idx)));
}

pub inline fn is_string(L: *LuauState, idx: i32) bool {
    return to_bool(c.lua_isstring(L, @as(c_int, idx)));
}

pub inline fn is_cfunction(L: *LuauState, idx: i32) bool {
    return to_bool(c.lua_iscfunction(L, @as(c_int, idx)));
}

pub inline fn is_Lfunction(L: *LuauState, idx: i32) bool {
    return to_bool(c.lua_isLfunction(L, @as(c_int, idx)));
}

pub inline fn is_userdata(L: *LuauState, idx: i32) bool {
    return to_bool(c.lua_isuserdata(L, @as(c_int, idx)));
}

pub inline fn type_of(L: *LuauState, idx: i32) bool {
    return @as(i32, c.lua_type(L, @as(c_int, idx)));
}

pub inline fn type_name(L: *LuauState, tp: i32) []u8 {
    const name = c.lua_typename(L, @as(c_int, tp));
    const name_slice: []u8 = std.mem.span(name);
    return name_slice;
}

pub inline fn equal(L: *LuauState, idx1: i32, idx2: i32) bool {
    return to_bool(c.lua_equal(L, @as(c_int, idx1), @as(c_int, idx2)));
}

pub inline fn raw_equal(L: *LuauState, idx1: i32, idx2: i32) bool {
    return to_bool(c.lua_rawequal(L, @as(c_int, idx1), @as(c_int, idx2)));
}

pub inline fn less_than(L: *LuauState, idx1: i32, idx2: i32) bool {
    return to_bool(c.lua_lessthan(L, @as(c_int, idx1), @as(c_int, idx2)));
}

pub inline fn to_numberx(L: *LuauState, idx: i32, is_num: *bool) f64 {
    var is_num_c: c_int = undefined;
    const num = @as(f64, c.lua_tonumberx(L, @as(c_int, idx), &is_num_c));
    is_num.* = to_bool(is_num);
    return num;
}

pub inline fn to_integerx(L: *LuauState, idx: i32, is_num: *bool) i32 {
    var is_num_c: c_int = undefined;
    const num = @as(i32, c.lua_tointegerx(L, @as(c_int, idx), &is_num_c));
    is_num.* = to_bool(is_num);
    return num;
}

pub inline fn to_unsignedx(L: *LuauState, idx: i32, is_num: *bool) u32 {
    var is_num_c: c_int = undefined;
    const num = @as(u32, c.lua_tounsignedx(L, @as(c_int, idx), &is_num_c));
    is_num.* = to_bool(is_num);
    return num;
}

pub inline fn to_vector(L: *LuauState, idx: i32) ?@Vector(3, f32) {
    const vec_array_opt: ?*[3]f32 = c.lua_tovector(L, @as(c_int, idx));
    if (vec_array_opt) |vec_array| {
        const vec: @Vector(3, f32) = vec_array[1..3].*;
        return vec;
    }
    return null;
}

pub inline fn to_boolean(L: *LuauState, idx: i32) bool {
    return to_bool(c.lua_toboolean(L, @as(c_int, idx)));
}

pub inline fn to_string(L: *LuauState, idx: i32) []u8 {
    const len: usize = undefined;
    const c_str = c.lua_tolstring(L, @as(c_int, idx), &len);
    return c_str[0..len];
}

pub inline fn to_string_atom(L: *LuauState, idx: i32, atom: ?*i32) []u8 {
    var c_atom: c_int = undefined;
    const c_str = c.lua_tostringatom(L, @as(c_int, idx), &c_atom);
    if (atom) |atom_ptr| {
        atom_ptr.* = @as(i32, c_atom);
    }
    return c_str[0..std.mem.len(c_str)];
}

pub inline fn namecall_atom(L: *LuauState, atom: ?*i32) []u8 {
    var c_atom: c_int = undefined;
    const c_str = c.lua_namecallatom(L, &c_atom);
    if (atom) |atom_ptr| {
        atom_ptr.* = @as(i32, c_atom);
    }
    return c_str[0..std.mem.len(c_str)];
}

pub inline fn obj_len(L: *LuauState, idx: i32) i32 {
    return @as(i32, c.lua_objlen(L, @as(c_int, idx)));
}

pub inline fn to_c_function(L: *LuauState, idx: i32) void {
    _ = L;
    _ = idx;
    @panic("not yet implemented");
}

pub inline fn to_light_userdata(L: *LuauState, idx: i32) *anyopaque {
    return c.lua_tolightuserdata(L, @as(c_int, idx));
}

pub inline fn to_light_userdata_tagged(L: *LuauState, idx: i32, tag: i32) *anyopaque {
    return c.lua_tolightuserdata(L, @as(c_int, idx), @as(c_int, tag));
}

pub inline fn to_userdata(L: *LuauState, idx: i32) *anyopaque {
    return c.lua_touserdata(L, @as(c_int, idx));
}

pub inline fn to_userdata_tagged(L: *LuauState, idx: i32, tag: i32) *anyopaque {
    return c.lua_touserdata(L, @as(c_int, idx), @as(c_int, tag));
}

pub inline fn userdata_tag(L: *LuauState, idx: i32) i32 {
    return @as(i32, c.lua_userdatatag(L, @as(c_int, idx)));
}

pub inline fn light_userdata_tag(L: *LuauState, idx: i32) i32 {
    return @as(i32, c.lua_lightuserdatatag(L, @as(c_int, idx)));
}

pub inline fn to_thread(L: *LuauState, idx: i32) *LuauState {
    return c.lua_tothread(L, @as(c_int, idx));
}

pub inline fn to_buffer(L: *LuauState, idx: i32) *anyopaque {
    return c.lua_tobuffer(L, @as(c_int, idx));
}

pub inline fn to_pointer(L: *LuauState, idx: i32) *anyopaque {
    return c.lua_topointer(L, @as(c_int, idx));
}

// -------------------------------------------------------------
// Push Functions
// -------------------------------------------------------------

pub inline fn push_nil(L: *LuauState) void {
    c.lua_pushnil(L);
}

pub inline fn push_number(L: *LuauState, n: f64) void {
    c.lua_pushnumber(L, n);
}

pub inline fn push_integer(L: *LuauState, n: i32) void {
    c.lua_pushinteger(L, @as(c_int, n));
}

pub inline fn push_unsigned(L: *LuauState, n: u32) void {
    c.lua_pushunsigned(L, @as(c_uint, n));
}

pub inline fn push_vector(L: *LuauState, vec: @Vector(3, f32)) void {
    c.lua_pushvector(L, vec[0], vec[1], vec[2]);
}

pub inline fn push_string(L: *LuauState, str: [*:0]const u8) void {
    c.lua_pushlstring(L, str, std.mem.len(str));
}

pub inline fn push_c_closure_k(L: *LuauState, func: ZigFn, debug_name: [*:0]const u8, nup: i32, cont: ?ZigContinueFn) void {
    c.lua_pushcclosurek(L, func, debug_name, @as(c_int, nup), cont);
}

pub inline fn push_boolean(L: *LuauState, b: bool) void {
    c.lua_pushboolean(L, @as(c_int, if (b) 1 else 0));
}

pub inline fn push_thread(L: *LuauState) void {
    c.lua_pushthread(L);
}

pub inline fn push_light_userdata_tagged(L: *LuauState, p: *anyopaque, tag: i32) void {
    c.lua_pushlightuserdatatagged(L, p, @as(c_int, tag));
}

pub inline fn new_userdata_tagged(L: *LuauState, size: usize, tag: i32) *anyopaque {
    return c.lua_newuserdatatagged(L, size, @as(c_int, tag));
}

pub inline fn new_userdata_dtor(L: *LuauState, size: usize, dtor: *anyopaque) *anyopaque {
    _ = L;
    _ = size;
    _ = dtor;
    @panic("not yet implemented");
}

pub inline fn new_buffer(L: *LuauState, size: usize) *anyopaque {
    return c.lua_newbuffer(L, size);
}

// -------------------------------------------------------------
// Get Functions
// -------------------------------------------------------------

pub inline fn get_table(L: *LuauState, idx: i32) i32 {
    return @as(i32, c.lua_gettable(L, @as(c_int, idx)));
}

pub inline fn get_field(L: *LuauState, idx: i32, k: [*:0]const u8) i32 {
    return @as(i32, c.lua_getfield(L, @as(c_int, idx), k));
}

pub inline fn raw_get_field(L: *LuauState, idx: i32, k: [*:0]const u8) i32 {
    return @as(i32, c.lua_rawgetfield(L, @as(c_int, idx), k));
}

pub inline fn raw_get(L: *LuauState, idx: i32) i32 {
    return @as(i32, c.lua_rawget(L, @as(c_int, idx)));
}

pub inline fn raw_get_i(L: *LuauState, idx: i32, n: i32) i32 {
    return @as(i32, c.lua_rawget(L, @as(c_int, idx), @as(c_int, n)));
}

pub inline fn create_table(L: *LuauState, n_arr: i32, n_rec: i32) void {
    c.lua_createtable(L, @as(c_int, n_arr), @as(c_int, n_rec));
}

pub inline fn set_readonly(L: *LuauState, idx: i32, enabled: bool) void {
    c.lua_setreadonly(L, @as(c_int, idx), @as(c_int, if (enabled) 1 else 0));
}

pub inline fn get_readonly(L: *LuauState, idx: i32) bool {
    return to_bool(c.lua_getreadonly(L, @as(c_int, idx)));
}

pub inline fn set_safe_env(L: *LuauState, idx: i32, enabled: bool) void {
    c.lua_setsafeenv(L, @as(c_int, idx), @as(c_int, if (enabled) 1 else 0));
}

pub inline fn get_metatable(L: *LuauState, idx: i32) i32 {
    return @as(i32, c.lua_getmetatable(L, @as(c_int, idx)));
}

pub inline fn get_f_env(L: *LuauState, idx: i32) void {
    c.lua_getfenv(L, @as(c_int, idx));
}

// -------------------------------------------------------------
// Set Functions
// -------------------------------------------------------------

pub inline fn set_table(L: *LuauState, idx: i32) void {
    c.lua_settable(L, @as(c_int, idx));
}

pub inline fn set_field(L: *LuauState, idx: i32, k: [*:0]const u8) void {
    c.lua_setfield(L, @as(c_int, idx), k);
}

pub inline fn raw_set_field(L: *LuauState, idx: i32, k: [*:0]const u8) void {
    c.lua_rawsetfield(L, @as(c_int, idx), k);
}

pub inline fn raw_set(L: *LuauState, idx: i32) void {
    c.lua_rawset(L, @as(c_int, idx));
}

pub inline fn raw_set_i(L: *LuauState, idx: i32, n: i32) void {
    c.lua_rawseti(L, @as(c_int, idx), @as(c_int, n));
}

pub inline fn set_metatable(L: *LuauState, idx: i32) i32 {
    return @as(i32, c.lua_setmetatable(L, @as(c_int, idx)));
}

pub inline fn set_f_env(L: *LuauState, idx: i32) i32 {
    return @as(i32, c.lua_setfenv(L, @as(c_int, idx)));
}

// -------------------------------------------------------------
// Load and Call functions
// -------------------------------------------------------------

pub inline fn load(L: *LuauState, bytecode: [*:0]u8) i32 {
    const len = std.mem.len(bytecode);
    return @as(i32, c.luau_load(L, "=test", bytecode, len, 0));
}

pub inline fn call(L: *LuauState, n_args: i32, n_results: i32) void {
    c.lua_call(L, @as(c_int, n_args), @as(c_int, n_results));
}

pub inline fn pcall(L: *LuauState, n_args: i32, n_results: i32, err_func: i32) i32 {
    return @as(i32, c.lua_pcall(L, @as(c_int, n_args), @as(c_int, n_results), @as(c_int, err_func)));
}

// -------------------------------------------------------------
// Coroutine functions
// -------------------------------------------------------------

pub inline fn co_yield(L: *LuauState, n_results: i32) i32 {
    return @as(i32, c.lua_yield(L, @as(c_int, n_results)));
}

pub inline fn co_break(L: *LuauState) i32 {
    return @as(i32, c.lua_break(L));
}

pub inline fn co_resume(L: *LuauState, from: ?*LuauState, n_args: i32) i32 {
    return @as(i32, c.lua_resume(L, from, @as(c_int, n_args)));
}

pub inline fn co_resume_error(L: *LuauState, from: ?*LuauState) i32 {
    return @as(i32, c.lua_resumeerror(L, from));
}

pub inline fn co_status(L: *LuauState) i32 {
    return @as(i32, c.lua_status(L));
}

pub inline fn co_coroutine_status(L: *LuauState) i32 {
    return @as(i32, c.lua_costatus(L));
}

pub inline fn co_is_yieldable(L: *LuauState) bool {
    return to_bool(c.lua_isyieldable(L));
}

pub inline fn get_thread_data(L: *LuauState) *anyopaque {
    return c.lua_getthreaddata(L);
}

pub inline fn set_thread_data(L: *LuauState, data: *anyopaque) void {
    return c.lua_setthreaddata(L, data);
}

// -------------------------------------------------------------
// Garbage collection functions
// -------------------------------------------------------------

pub inline fn gc(L: *LuauState, what: i32, data: i32) i32 {
    return @as(i32, c.lua_gc(L, @as(c_int, what), @as(c_int, data)));
}

// -------------------------------------------------------------
// Memory statistics functions
// -------------------------------------------------------------

pub inline fn set_memory_category(L: *LuauState, category: i32) void {
    c.lua_setmemcat(L, @as(c_int, category));
}

pub inline fn total_bytes(L: *LuauState, category: i32) usize {
    return c.lua_totalbytes(L, @as(c_int, category));
}

// -------------------------------------------------------------
// Miscellaneous functions
// -------------------------------------------------------------

pub inline fn lua_error(L: *LuauState) noreturn {
    c.lua_error(L);
}

pub inline fn next(L: *LuauState, idx: i32) bool {
    return to_bool(c.lua_next(L, @as(c_int, idx)));
}

pub inline fn raw_iter(L: *LuauState, idx: i32, iter: i32) i32 {
    return @as(i32, c.lua_rawiter(L, @as(c_int, idx), @as(c_int, iter)));
}

pub inline fn concat(L: *LuauState, n: i32) void {
    c.lua_concat(L, @as(c_int, n));
}

pub inline fn encode_pointer(L: *LuauState, p: usize) usize {
    return c.lua_encodepointer(L, p);
}

pub inline fn clock() f64 {
    return @as(f64, c.lua_clock());
}

pub inline fn set_userdata_tag(L: *LuauState, idx: i32, tag: i32) void {
    c.lua_setuserdatatag(L, @as(c_int, idx), @as(c_int, tag));
}

pub inline fn set_userdata_dtor(L: *LuauState, tag: i32, dtor: *anyopaque) void {
    c.lua_setuserdatadtor(L, @as(c_int, tag), dtor);
}

pub inline fn get_userdata_dtor(L: *LuauState, tag: i32) *anyopaque {
    return c.lua_getuserdatadtor(L, @as(c_int, tag));
}

pub inline fn set_light_userdata_name(L: *LuauState, tag: i32, name: [*:0]const u8) void {
    c.lua_setlightuserdataname(L, @as(c_int, tag), name);
}

pub inline fn get_light_userdata_name(L: *LuauState, tag: i32) [*:0]const u8 {
    return c.lua_getlightuserdataname(L, @as(c_int, tag));
}

pub inline fn clone_function(L: *LuauState, idx: i32) void {
    c.lua_clonefunction(L, @as(c_int, idx));
}

pub inline fn clear_table(L: *LuauState, idx: i32) void {
    c.lua_cleartable(L, @as(c_int, idx));
}

// -------------------------------------------------------------
// Reference system
// -------------------------------------------------------------

pub inline fn ref(L: *LuauState, idx: i32) i32 {
    return @as(i32, c.lua_ref(L, @as(c_int, idx)));
}

pub inline fn unref(L: *LuauState, idx: i32) void {
    c.lua_unref(L, @as(c_int, idx));
}

pub inline fn get_ref(L: *LuauState, r: i32) i32 {
    return raw_get_i(L, c.LUA_REGISTRYINDEX, r);
}

// -------------------------------------------------------------
// Helpful functions
// -------------------------------------------------------------

pub inline fn to_number(L: *LuauState, idx: i32) f64 {
    return @as(f64, c.lua_tonumberx(L, @as(c_int, idx), null));
}

pub inline fn to_integer(L: *LuauState, idx: i32) i32 {
    return @as(i32, c.lua_tointegerx(L, @as(c_int, idx), null));
}

pub inline fn to_unsigned(L: *LuauState, idx: i32) u32 {
    return @as(u32, c.lua_tounsignedx(L, @as(c_int, idx), null));
}

pub inline fn pop(L: *LuauState, n: i32) void {
    c.lua_settop(L, @as(c_int, -(n) - 1));
}

pub inline fn new_table(L: *LuauState) void {
    c.lua_createtable(L, 0, 0);
}

pub inline fn new_userdata(L: *LuauState, size: usize) *anyopaque {
    return c.lua_newuserdatatagged(L, size, 0);
}

pub inline fn str_len(L: *LuauState, idx: i32) i32 {
    return c.lua_objlen(L, @as(c_int, idx));
}

pub inline fn is_function(L: *LuauState, idx: i32) bool {
    return c.lua_type(L, @as(c_int, idx)) == c.LUA_TFUNCTION;
}

pub inline fn is_table(L: *LuauState, idx: i32) bool {
    return c.lua_type(L, @as(c_int, idx)) == c.LUA_TTABLE;
}

pub inline fn is_light_userdata(L: *LuauState, idx: i32) bool {
    return c.lua_type(L, @as(c_int, idx)) == c.LUA_TLIGHTUSERDATA;
}

pub inline fn is_nil(L: *LuauState, idx: i32) bool {
    return c.lua_type(L, @as(c_int, idx)) == c.LUA_TNIL;
}

pub inline fn is_boolean(L: *LuauState, idx: i32) bool {
    return c.lua_type(L, @as(c_int, idx)) == c.LUA_TBOOLEAN;
}

pub inline fn is_vector(L: *LuauState, idx: i32) bool {
    return c.lua_type(L, @as(c_int, idx)) == c.LUA_TVECTOR;
}

pub inline fn is_thread(L: *LuauState, idx: i32) bool {
    return c.lua_type(L, @as(c_int, idx)) == c.LUA_TTHREAD;
}

pub inline fn is_buffer(L: *LuauState, idx: i32) bool {
    return c.lua_type(L, @as(c_int, idx)) == c.LUA_TBUFFER;
}

pub inline fn is_none(L: *LuauState, idx: i32) bool {
    return c.lua_type(L, @as(c_int, idx)) == c.LUA_TNONE;
}

pub inline fn is_none_or_nil(L: *LuauState, idx: i32) bool {
    return c.lua_type(L, @as(c_int, idx)) <= c.LUA_TNIL;
}

pub inline fn push_c_function(L: *LuauState, func: ZigFn, debug_name: [*:0]const u8) void {
    push_c_closure_k(L, func, debug_name, 0, null);
}

pub inline fn push_c_closure(L: *LuauState, func: ZigFn, debug_name: [*:0]const u8, nup: i32) void {
    push_c_closure_k(L, func, debug_name, nup, null);
}

pub inline fn set_global(L: *LuauState, name: [*:0]const u8) void {
    c.lua_setfield(L, c.LUA_GLOBALSINDEX, name);
}

pub inline fn get_global(L: *LuauState, name: [*:0]const u8) i32 {
    return @as(i32, c.lua_getfield(L, c.LUA_GLOBALSINDEX, name));
}

// -------------------------------------------------------------
// Debug API
// -------------------------------------------------------------

pub const LuauDebug = extern struct {
    name: [*:0]const u8,
    what: [*:0]const u8,
    source: [*:0]const u8,
    short_src: [*:0]const u8,
    linedefined: i32,
    currentline: i32,
    nupvals: u8,
    nparams: u8,
    isvararg: i8,
    userdata: *anyopaque,
    ssbuf: [256]u8,
};

pub inline fn stack_depth(L: *LuauState) i32 {
    return @as(i32, c.lua_stackdepth(L));
}

pub inline fn get_info(L: *LuauState, level: i32, what: [*:0]const u8, ar: *LuauDebug) i32 {
    c.lua_getinfo(L, @as(c_int, level), what, ar);
}

pub inline fn get_argument(L: *LuauState, level: i32, n: i32) i32 {
    return @as(i32, c.lua_getargument(L, @as(c_int, level), @as(c_int, n)));
}

pub inline fn get_local(L: *LuauState, level: i32, n: i32) [*:0]const u8 {
    return c.lua_getlocal(L, @as(c_int, level), @as(c_int, n));
}

pub inline fn set_local(L: *LuauState, level: i32, n: i32) [*:0]const u8 {
    return c.lua_setlocal(L, @as(c_int, level), @as(c_int, n));
}

pub inline fn get_upvalue(L: *LuauState, func_index: i32, n: i32) [*:0]const u8 {
    return c.lua_getupvalue(L, @as(c_int, func_index), @as(c_int, n));
}

pub inline fn set_upvalue(L: *LuauState, func_index: i32, n: i32) [*:0]const u8 {
    return c.lua_setupvalue(L, @as(c_int, func_index), @as(c_int, n));
}

pub inline fn single_step(L: *LuauState, enabled: bool) void {
    c.lua_singlestep(L, @as(c_int, if (enabled) 1 else 0));
}

pub inline fn breakpoint(L: *LuauState, func_index: i32, line: i32, enabled: bool) i32 {
    return @as(i32, c.lua_breakpoint(L, @as(c_int, func_index), @as(i32, line), @as(i32, if (enabled) 1 else 0)));
}

pub inline fn debug_trace(L: *LuauState) [*:0]const u8 {
    return c.lua_debugtrace(L);
}

pub fn compile(allocator: std.mem.Allocator, source: [*:0]u8, options: ?CompileOptions) ![:0]u8 {
    var outsize: usize = undefined;

    const opts_unwrapped = options orelse CompileOptions{};
    const opts = @as(*c.struct_lua_CompileOptions, @constCast(@ptrCast(@alignCast(&opts_unwrapped))));
    const bytecode = c.luau_compile(source, std.mem.len(source), opts, &outsize);
    defer std.c.free(bytecode);

    return try allocator.dupeZ(u8, bytecode[0..outsize]);
}
