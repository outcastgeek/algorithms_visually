//! Bit Piano -- interactive binary number pad.
//! Clickable bits with live decimal, hex, and signed two's complement readouts.
//! Neon cyber aesthetic with glowing pads, HUD readout panels, and CRT effects.
const std = @import("std");
const rl = @import("raylib");
const theme = @import("../ui/theme.zig");
const BitGrid = @import("../ui/bit_grid.zig").BitGrid;

const App = struct {
    grid: BitGrid,
};

// ════════════════════════════════════════════════════════════════
// Readout panels (HUD-style top section)
// ════════════════════════════════════════════════════════════════

fn drawReadoutPanels(grid: *const BitGrid, screen_w: i32) void {
    const u = grid.toUnsigned();
    const n = grid.bit_count;

    // Signed two's complement (i64 to handle bit_count up to 32)
    const sign_mask: u32 = @as(u32, 1) << @intCast(n - 1);
    const s: i64 = if ((u & sign_mask) == 0)
        @intCast(u)
    else
        @as(i64, @intCast(u)) - (@as(i64, 1) << @intCast(n));

    // Format value strings
    var hex_buf: [16]u8 = undefined;
    const hex_txt = if (n <= 8)
        std.fmt.bufPrintZ(&hex_buf, "0x{X:0>2}", .{@as(u8, @intCast(u & 0xFF))}) catch "0x00"
    else if (n <= 16)
        std.fmt.bufPrintZ(&hex_buf, "0x{X:0>4}", .{@as(u16, @intCast(u & 0xFFFF))}) catch "0x0000"
    else
        std.fmt.bufPrintZ(&hex_buf, "0x{X:0>8}", .{u}) catch "0x00000000";

    var dec_buf: [32]u8 = undefined;
    const dec_txt = std.fmt.bufPrintZ(&dec_buf, "{d}", .{u}) catch "0";

    var s_buf: [32]u8 = undefined;
    const s_txt = std.fmt.bufPrintZ(&s_buf, "{d}", .{s}) catch "0";

    // Panel layout
    const panel_h: f32 = 72;
    const panel_y: f32 = 16;
    const margin: f32 = 28;
    const gap: f32 = 12;
    const sw: f32 = @floatFromInt(screen_w);
    const panel_w: f32 = (sw - margin * 2 - gap * 2) / 3.0;

    const labels = [_][:0]const u8{ "DECIMAL", "HEX", "SIGNED (2's COMP)" };
    const values = [_][:0]const u8{ dec_txt, hex_txt, s_txt };

    var p: usize = 0;
    while (p < 3) : (p += 1) {
        const px = margin + @as(f32, @floatFromInt(p)) * (panel_w + gap);
        const rect = rl.Rectangle{ .x = px, .y = panel_y, .width = panel_w, .height = panel_h };

        // Panel background
        rl.drawRectangleRounded(rect, 0.08, 8, theme.panel_bg);
        // Panel border
        rl.drawRectangleRoundedLinesEx(rect, 0.08, 8, 1.0, theme.panel_border);
        // Cyan accent bar at top
        rl.drawRectangle(@intFromFloat(px + 2), @intFromFloat(panel_y), @intFromFloat(panel_w - 4), 2, theme.panel_accent);

        // Label (small, dim, centered)
        const lw = rl.measureText(labels[p], 11);
        const lx: i32 = @intFromFloat(px + (panel_w - @as(f32, @floatFromInt(lw))) * 0.5);
        rl.drawText(labels[p], lx, @intFromFloat(panel_y + 16), 11, theme.text_dim);

        // Value (large, bright, centered with glow)
        const vw = rl.measureText(values[p], 32);
        const vx: i32 = @intFromFloat(px + (panel_w - @as(f32, @floatFromInt(vw))) * 0.5);
        const vy: i32 = @intFromFloat(panel_y + 34);
        // Glow behind value
        const val_glow = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = 30 };
        rl.drawText(values[p], vx - 1, vy, 32, val_glow);
        rl.drawText(values[p], vx + 1, vy, 32, val_glow);
        rl.drawText(values[p], vx, vy, 32, theme.text);
    }
}

// ════════════════════════════════════════════════════════════════
// Binary string display (centered above pads)
// ════════════════════════════════════════════════════════════════

fn drawBinaryString(grid: *const BitGrid, screen_w: i32, y: i32) void {
    var buf: [72]u8 = undefined;
    var pos: usize = 0;
    var i: usize = 0;
    while (i < grid.bit_count) : (i += 1) {
        if (i > 0 and i % 4 == 0) {
            buf[pos] = ' ';
            pos += 1;
            buf[pos] = ' ';
            pos += 1;
        }
        buf[pos] = if (grid.bits[i]) '1' else '0';
        pos += 1;
        // space between digits within a nibble
        if (i + 1 < grid.bit_count and (i + 1) % 4 != 0) {
            buf[pos] = ' ';
            pos += 1;
        }
    }
    buf[pos] = 0;
    const txt: [:0]const u8 = buf[0..pos :0];

    const tw = rl.measureText(txt, 16);
    const tx: i32 = @divTrunc(screen_w - tw, 2);
    rl.drawText(txt, tx, y, 16, theme.text_binary);
}

// ════════════════════════════════════════════════════════════════
// Nibble labels (below pads)
// ════════════════════════════════════════════════════════════════

fn drawNibbleLabels(grid: *const BitGrid, y: i32) void {
    if (grid.bit_count < 8) return;

    const u = grid.toUnsigned();
    const high_nibble = (u >> 4) & 0xF;
    const low_nibble = u & 0xF;

    // Center under each nibble group
    const pad0 = grid.pads[0].rect;
    const pad3 = grid.pads[3].rect;
    const high_cx = (pad0.x + pad3.x + pad3.width) * 0.5;

    const pad4 = grid.pads[4].rect;
    const pad7 = grid.pads[7].rect;
    const low_cx = (pad4.x + pad7.x + pad7.width) * 0.5;

    var high_buf: [24]u8 = undefined;
    const high_txt = std.fmt.bufPrintZ(&high_buf, "HIGH NIBBLE (0x{X})", .{high_nibble}) catch "HIGH";
    var low_buf: [24]u8 = undefined;
    const low_txt = std.fmt.bufPrintZ(&low_buf, "LOW NIBBLE (0x{X})", .{low_nibble}) catch "LOW";

    const hw = rl.measureText(high_txt, 12);
    rl.drawText(high_txt, @intFromFloat(high_cx - @as(f32, @floatFromInt(hw)) * 0.5), y, 12, theme.text_dim);

    const lw = rl.measureText(low_txt, 12);
    rl.drawText(low_txt, @intFromFloat(low_cx - @as(f32, @floatFromInt(lw)) * 0.5), y, 12, theme.text_dim);
}

// ════════════════════════════════════════════════════════════════
// Nibble gap divider (vertical line between nibble groups)
// ════════════════════════════════════════════════════════════════

fn drawNibbleDivider(grid: *const BitGrid) void {
    if (grid.bit_count < 8 or grid.nibble_gap < 2) return;

    const pad3 = grid.pads[3].rect;
    const pad4 = grid.pads[4].rect;
    const div_x: i32 = @intFromFloat((pad3.x + pad3.width + pad4.x) * 0.5);
    const top_y: i32 = @intFromFloat(pad3.y + pad3.height * 0.1);
    const bot_y: i32 = @intFromFloat(pad3.y + pad3.height * 0.9);

    // Subtle cyan vertical line
    const mid_y = @divTrunc(top_y + bot_y, 2);
    const div_clear = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = 0 };
    const div_mid = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = 25 };
    // Top half: transparent to cyan
    rl.drawRectangleGradientV(div_x, top_y, 1, mid_y - top_y, div_clear, div_mid);
    // Bottom half: cyan to transparent
    rl.drawRectangleGradientV(div_x, mid_y, 1, bot_y - mid_y, div_mid, div_clear);
}

// ════════════════════════════════════════════════════════════════
// Help text (terminal-style)
// ════════════════════════════════════════════════════════════════

fn drawHelpText(y_start: i32) void {
    const line_h: i32 = 24;
    // Prompt character
    rl.drawText(">", 36, y_start, 16, theme.accent);
    rl.drawText("Click bits to toggle  |  Leftmost = sign bit", 56, y_start, 16, theme.text_help);

    rl.drawText(">", 36, y_start + line_h, 16, theme.accent);
    rl.drawText("Try: 01111111 -> flip b7 -> 11111111 (-1 signed)", 56, y_start + line_h, 16, theme.text_help);

    rl.drawText(">", 36, y_start + line_h * 2, 16, theme.accent);
    rl.drawText("Try: 00000000 -> flip b7 -> 10000000 (-128)", 56, y_start + line_h * 2, 16, theme.text_help);
}

// ════════════════════════════════════════════════════════════════
// Section separator
// ════════════════════════════════════════════════════════════════

fn drawSeparator(screen_w: i32, y: i32) void {
    // Horizontal line that fades in from edges
    const margin: i32 = 40;
    const mid = @divTrunc(screen_w, 2);
    const sep_clear = rl.Color{ .r = theme.separator.r, .g = theme.separator.g, .b = theme.separator.b, .a = 0 };
    // Left half: transparent to separator
    rl.drawRectangleGradientH(margin, y, mid - margin, 1, sep_clear, theme.separator);
    // Right half: separator to transparent
    rl.drawRectangleGradientH(mid, y, screen_w - margin - mid, 1, theme.separator, sep_clear);
}

// ════════════════════════════════════════════════════════════════
// Entry point
// ════════════════════════════════════════════════════════════════

pub fn runBitPiano() !void {
    const w = 1000;
    const h = 500;
    rl.initWindow(w, h, "Bit Piano");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var app: App = .{ .grid = BitGrid.init(8) };
    app.grid.pad_height = 120;
    app.grid.nibble_gap = 24;
    app.grid.layout(w, 130);

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        app.grid.handleInput();
        app.grid.tick(dt);

        rl.beginDrawing();
        defer rl.endDrawing();

        // 1. Background gradient
        theme.drawBackground(w, h);

        // 2. Vignette (over background, under content)
        theme.drawVignette(w, h);

        // 3. Readout panels
        drawReadoutPanels(&app.grid, w);

        // 4. Binary string (between panels and pads)
        drawBinaryString(&app.grid, w, 98);

        // 5. Bit pads (glow + depth + body + border + flash + text)
        app.grid.draw();

        // 6. Nibble divider line
        drawNibbleDivider(&app.grid);

        // 7. Nibble labels
        drawNibbleLabels(&app.grid, @intFromFloat(130 + 120 + 10));

        // 8. Section separator
        drawSeparator(w, 290);

        // 9. Help text
        drawHelpText(308);

        // 10. Scanlines (absolute last)
        theme.drawScanlines(w, h);
    }
}
