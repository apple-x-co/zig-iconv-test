const std = @import("std");
const c = @cImport({
    @cInclude("iconv.h");
});

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

fn encode(allocator: std.mem.Allocator, iconv: c.iconv_t, string: *[]const u8) ![:0]const u8 {
    var input_ptr = string.*;
    var input_length: usize = string.len;

    var output_ptr = try allocator.alloc(u8, string.len * 4);
    for (output_ptr[0..]) |*b| b.* = 0;
    var output = output_ptr;
    var output_length: usize = string.len * 4;

    _ = c.iconv(iconv, @as([*c][*c]u8, @ptrCast(&input_ptr)), &input_length, @as([*c][*c]u8, @ptrCast(&output_ptr)), &output_length);

    var index = std.mem.indexOf(u8, output, "\x00").?;
    var buff = try allocator.dupeZ(u8, output[0..index]);
    allocator.free(output);

    return buff;
}

test "encode" {
    const allocator = std.testing.allocator;
    const cd = c.iconv_open("SHIFT-JIS", "UTF-8");
    defer _ = c.iconv_close(cd);

    var input = "こんにちは";
    var slice: []const u8 = input[0..];
    const sjis = try encode(allocator, cd, &slice);
    defer allocator.free(sjis);

    const file = try std.fs.cwd().createFile("sjis.txt", .{});
    defer file.close();
    try file.writeAll(sjis);
}

test "encode2" {
    const allocator = std.testing.allocator;

    const cd = c.iconv_open("SHIFT-JIS", "UTF-8");
    defer _ = c.iconv_close(cd);

    const file2 = try std.fs.cwd().createFile("sjis2.txt", .{});
    defer file2.close();

    const input = "こんにちは";
    var iter = (try std.unicode.Utf8View.init(input)).iterator();
    while (iter.nextCodepoint()) |cp| {
        std.debug.print("0x{x} is {u}\n", .{ cp, cp });

        var buf: [4]u8 = undefined;
        var s = try std.fmt.bufPrintZ(&buf, "{u}", .{cp});

        var slice: []const u8 = s[0..];
        const sjis = try encode(allocator, cd, &slice);
        defer allocator.free(sjis);

        try file2.writeAll(sjis);
    }
}
