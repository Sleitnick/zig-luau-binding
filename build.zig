const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = std.builtin.OptimizeMode.ReleaseSmall });

    const luau = b.addStaticLibrary(.{
        .name = "luau",
        .target = target,
        .optimize = optimize,
        .pic = true,
        .single_threaded = true,
    });
    luau.linkLibCpp();
    luau.addIncludePath(.{ .path = "luau/Common/include" });
    luau.addIncludePath(.{ .path = "luau/Compiler/include" });
    luau.addIncludePath(.{ .path = "luau/Ast/include" });
    luau.addIncludePath(.{ .path = "luau/VM/include" });

    const luau_src_dirs = [_][]const u8{ "./luau/VM/src", "./luau/Compiler/src", "./luau/Ast/src" };

    // Add all Luau source files:
    for (luau_src_dirs, 0..) |dir_path, idx| {
        _ = idx;
        var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            // Skip if no ".c" included in path (which also would include .cpp):
            if (std.mem.count(u8, entry.name, ".c") == 0) continue;

            const path = try std.fmt.allocPrint(b.allocator, "{s}/{s}", .{ dir_path, entry.name });
            luau.addCSourceFile(.{
                .file = std.Build.LazyPath{ .path = path },
                .flags = &[_][]const u8{
                    "-std=c++17",
                    "-O2",
                    "-Wno-attributes",
                    "-Wall",
                    "-DLUA_API=extern\"C\"",
                    "-DLUACODE_API=extern\"C\"",
                },
            });
        }
    }

    const exe = b.addExecutable(.{
        .name = "zig-luau",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    exe.linkLibCpp();
    exe.addIncludePath(std.Build.LazyPath{ .path = "." });
    exe.linkLibrary(luau);

    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
