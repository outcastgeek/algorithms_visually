const std = @import("std");
const av = @import("algorithms_visually");

const Visualization = enum {
    bit_piano,
    bit_patterns,
    hex_piano,
    octal_piano,
    message_box,
};

fn printHelp() void {
    const help =
        \\Usage: zig build run -- <visualization>
        \\
        \\Available visualizations:
        \\  --bit-piano       Interactive binary number pad (8 bits)
        \\  --bit-patterns    Explore 2^n exponential growth (1, 2, 8 bits)
        \\  --hex-piano       Interactive hex number pad (16 bits)
        \\  --octal-piano     Interactive octal number pad (12 bits)
        \\  --message-box     Raygui dialog demo
        \\
        \\Options:
        \\  -h, --help        Show this help message
        \\
    ;
    std.debug.print(help, .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();
    _ = it.next(); // skip program name

    var selected: ?Visualization = null;

    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printHelp();
            return;
        } else if (std.mem.eql(u8, arg, "--bit-piano")) {
            selected = .bit_piano;
        } else if (std.mem.eql(u8, arg, "--bit-patterns")) {
            selected = .bit_patterns;
        } else if (std.mem.eql(u8, arg, "--hex-piano")) {
            selected = .hex_piano;
        } else if (std.mem.eql(u8, arg, "--octal-piano")) {
            selected = .octal_piano;
        } else if (std.mem.eql(u8, arg, "--message-box")) {
            selected = .message_box;
        } else {
            std.debug.print("Unknown argument: {s}\n\n", .{arg});
            printHelp();
            return error.InvalidArgument;
        }
    }

    if (selected) |viz| {
        switch (viz) {
            .bit_piano => try av.viz.bit_piano.runBitPiano(),
            .bit_patterns => try av.viz.bit_patterns.runBitPatterns(),
            .hex_piano => try av.viz.hex_piano.runHexPiano(),
            .octal_piano => try av.viz.octal_piano.runOctalPiano(),
            .message_box => try av.viz.message_box.runMessageBox(),
        }
    } else {
        printHelp();
    }
}
