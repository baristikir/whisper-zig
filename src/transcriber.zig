const std = @import("std");
const c = @import("c.zig");

pub const Segment = struct {
    text: []const u8,
};

ctx: *c.whisper_context,
allocator: std.mem.Allocator,
const Transcriber = @This();

pub fn init(allocator: std.mem.Allocator, model_name: []const u8) !Transcriber {
    const model_path = try std.fmt.allocPrintZ(allocator, "./whisper.cpp/models/{s}", .{model_name});
    defer allocator.free(model_path);

    const cparams = c.whisper_context_default_params();
    const ctx = c.whisper_init_from_file_with_params(model_path.ptr, cparams) orelse {
        std.debug.print("Error: Whisper initialization failed.\n", .{});
        return error.WhisperInitFailed;
    };

    return Transcriber{
        .ctx = ctx,
        .allocator = allocator,
    };
}
pub fn deinit(self: *Transcriber) void {
    c.whisper_free(self.ctx);
}

pub fn transcribe_file(self: *Transcriber, audio_buf: *std.ArrayList(f32)) !void {
    const wparams = c.whisper_full_default_params(c.WHISPER_SAMPLING_GREEDY);
    const whisper_ret: c_int = c.whisper_full(self.ctx, wparams, @ptrCast(@alignCast(audio_buf.items.ptr)), @intCast(audio_buf.items.len));
    if (whisper_ret != 0) {
        std.debug.print("Error: whisper_ret\n", .{});
        return error.Whisper;
    }
}

pub fn get_segments(self: *Transcriber) !std.ArrayList(Segment) {
    var segments = std.ArrayList(Segment).init(self.allocator);
    errdefer segments.deinit();

    const n_segments = c.whisper_full_n_segments(self.ctx);

    var i: u8 = 0;
    while (i < n_segments) : (i += 1) {
        const c_segment_text = c.whisper_full_get_segment_text(self.ctx, i);
        // Convert [*c]const u8 (C-style string null-terminated) to a Zig slice []const u8
        const segment_text = try self.allocator.dupe(u8, std.mem.span(c_segment_text));
        errdefer self.allocator.free(segment_text);

        const segment = Segment{ .text = segment_text };
        try segments.append(segment);
    }

    return segments;
}
