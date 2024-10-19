const std = @import("std");

fn setupWhisper(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const lib = b.addStaticLibrary(.{
        .name = "whisper",
        .target = exe.root_module.resolved_target.?,
        .optimize = std.builtin.OptimizeMode.ReleaseFast,
    });

    lib.linkLibC();
    lib.linkLibCpp();

    lib.addIncludePath(b.path("whisper.cpp"));
    lib.addIncludePath(b.path("whisper.cpp/include"));
    lib.addIncludePath(b.path("whisper.cpp/ggml/include"));

    const whisper_files: []const []const u8 = &.{
        "ggml/src/ggml.c", "ggml/src/ggml-alloc.c", "ggml/src/ggml-backend.c", "ggml/src/ggml-quants.c", "src/whisper.cpp",
    };

    for (whisper_files) |f| {
        lib.addCSourceFile(.{ .file = b.path(b.pathJoin(&.{ "whisper.cpp", f })) });
    }

    if (exe.root_module.resolved_target.?.result.os.tag == .linux) {
        lib.defineCMacro("_GNU_SOURCE", "");
    }

    exe.addIncludePath(b.path("whisper.cpp"));
    exe.addIncludePath(b.path("whisper.cpp/include"));
    exe.addIncludePath(b.path("whisper.cpp/ggml/include"));

    exe.linkLibrary(lib);
}

fn setupDrWav(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const drwav_files: []const []const u8 = &.{"dr_wav.c"};

    for (drwav_files) |f| {
        exe.addCSourceFile(.{ .file = b.path(b.pathJoin(&.{ "drwav", f })) });
    }

    exe.defineCMacro("DR_WAV_IMPLEMENTATION", null);
    exe.addIncludePath(b.path("drwav"));
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "whisper-zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    setupDrWav(b, exe);
    setupWhisper(b, exe);
    exe.linkLibC();
    exe.linkLibCpp();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    setupDrWav(b, exe_tests);
    setupWhisper(b, exe_tests);
    exe_tests.linkLibC();
    exe_tests.linkLibCpp();

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_tests.step);

    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    setupDrWav(b, main_tests);
    setupWhisper(b, main_tests);
    main_tests.linkLibC();
    main_tests.linkLibCpp();

    const run_main_tests = b.addRunArtifact(main_tests);
    const main_tests_step = b.step("test-main", "Run tests in main.zig");
    main_tests_step.dependOn(&run_main_tests.step);
}
