const std = @import("std");
const c = @import("c.zig");
const drwav = @import("dr_wav.zig");
const Whisper = @import("whisper.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    if (args.len < 2) return error.ExpectedArgument;

    var model_name: ?[]const u8 = null;
    var wav_file_path: ?[]const u8 = null;

    // Extract argument values for -m and -f parameters.
    var i: u4 = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-m")) {
            i += 1;
            if (i < args.len) {
                // this will be current index + 1, so the after value of -m parameter will be taken
                model_name = args[i];
            } else {
                std.debug.print("Error: -m requires a path argument \n", .{});
                return;
            }
        } else if (std.mem.eql(u8, arg, "-f")) {
            i += 1;
            if (i < args.len) {
                // same as -m
                wav_file_path = args[i];
            } else {
                std.debug.print("Error: -f requires a file path argument \n", .{});
                return;
            }
        }
    }

    var whisper: ?Whisper = null;
    if (model_name) |n| {
        whisper = Whisper.init(gpa, n) catch |err| {
            std.debug.print("Error: Initializing Whisper {}\n", .{err});
            return;
        };
    } else {
        std.debug.print("No model name provided \n.", .{});
        return;
    }
    defer if (whisper) |*w| w.deinit();

    var pcmf32 = std.ArrayList(f32).init(gpa);
    defer pcmf32.deinit();

    if (wav_file_path) |path| {
        if (!try drwav.readWav(gpa, path, &pcmf32)) {
            std.debug.print("error: Reading WAV file\n", .{});
        }
    }

    try whisper.?.transcribe_file(&pcmf32);
    const segments = try whisper.?.get_segments();
    defer {
        for (segments.items) |segment| {
            gpa.free(segment.text);
        }
        segments.deinit();
    }

    for (segments.items, 0..) |segment, segment_index| {
        std.debug.print("Segment[{d}]: {s}\n", .{ segment_index, segment.text });
    }
}

test "instantiate whisper model" {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();

    const model_name = "ggml-base.en.bin";
    var whisper = Whisper.init(gpa, model_name) catch |err| {
        std.debug.print("Error: Initializing Whisper Model {}\n", .{err});
        return err;
    };
    defer whisper.deinit();

    std.debug.print("Whisper initialized successfully. \n", .{});
    try std.testing.expect(@intFromPtr(whisper.ctx) != 0);
}

test "transcribe sample" {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();

    const model_name = "ggml-base.en.bin";
    var whisper = Whisper.init(gpa, model_name) catch |err| {
        std.debug.print("Error: Initializing Whisper Model {}\n", .{err});
        return err;
    };
    defer whisper.deinit();

    std.debug.print("Whisper initialized successfully. \n", .{});

    // Sample WAVEFORM file from whisper.cpp
    const wav_file_path = "../whisper.cpp/samples/jfk.wav";

    // Audio buffer (PCM-f32 array)
    var pcmf32 = std.ArrayList(f32).init(gpa);
    defer pcmf32.deinit();

    // Load WAV data to audio buffer
    if (!try drwav.readWav(gpa, wav_file_path, &pcmf32)) {
        std.debug.print("error: Reading WAV file\n", .{});
        return error.WavRead;
    }

    try whisper.transcribe_file(&pcmf32);
    const segments = try whisper.get_segments();
    defer {
        for (segments.items) |segment| {
            gpa.free(segment.text);
        }
        segments.deinit();
    }

    for (segments.items, 0..) |segment, segment_index| {
        std.debug.print("Segment[{d}]: {s}\n", .{ segment_index, segment.text });
    }

    try std.testing.expect(segments.items.len == 1);
}
