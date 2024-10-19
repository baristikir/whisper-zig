const std = @import("std");
const c = @import("c.zig");

const WHISPER_SAMPLE_RATE = c.WHISPER_SAMPLE_RATE;

pub fn readWav(allocator: std.mem.Allocator, fpath: []const u8, pcmf32: *std.ArrayList(f32)) !bool {
    var wav: c.drwav = undefined;
    var wav_data = std.ArrayList(u8).init(allocator);
    defer wav_data.deinit();

    if (c.drwav_init_file(&wav, fpath.ptr, null) == 0) {
        if (c.drwav_init_memory(&wav, wav_data.items.ptr, wav_data.items.len, null) == 0) {
            std.debug.print("error: Failed to read wav data as wav\n", .{});
            return false;
        }
        std.debug.print("error: Failed to open '{s}' as WAV file\n", .{fpath});
        return false;
    }
    defer _ = c.drwav_uninit(&wav);

    if (wav.channels != 1 and wav.channels != 2) {
        std.debug.print("{s}: WAV file '{s}' must be mono or stereo\n", .{ @src().fn_name, fpath });
        return false;
    }

    if (wav.sampleRate != WHISPER_SAMPLE_RATE) {
        std.debug.print("{s}: WAV file '{s}' must be {} kHz\n", .{ @src().fn_name, fpath, WHISPER_SAMPLE_RATE / 1000 });
        return false;
    }

    if (wav.bitsPerSample != 16) {
        std.debug.print("{s}: WAV file '{s}' must be 16-bit\n", .{ @src().fn_name, fpath });
        return false;
    }

    const n = wav.totalPCMFrameCount;

    var pcm16 = try std.ArrayList(i16).initCapacity(allocator, n * @as(usize, @intCast(wav.channels)));
    defer pcm16.deinit();

    const frames_read = c.drwav_read_pcm_frames_s16(&wav, n, @alignCast(@ptrCast(pcm16.items.ptr)));
    if (frames_read == 0) {
        std.debug.print("error: Failed to read any PCM frames \n", .{});
        return false;
    }

    try pcm16.resize(frames_read * @as(usize, wav.channels));
    try pcmf32.resize(frames_read);
    if (wav.channels == 1) {
        var i: usize = 0;
        for (pcmf32.items) |*item| {
            item.* = @as(f32, @floatFromInt(pcm16.items[i])) / 32768.0;
            i += 1;
        }
    } else {
        var i: usize = 0;
        for (pcmf32.items) |*item| {
            item.* = @as(f32, @floatFromInt(pcm16.items[2 * i])) + @as(f32, @floatFromInt(pcm16.items[2 * i + 1])) / 65536.0;
            i += 1;
        }
    }

    return true;
}
