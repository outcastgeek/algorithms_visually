//! Bit Explorer — interactive visualization of 2^n exponential growth.
//! Tabbed progressive disclosure: switch between 1, 2, 4, and 8-bit modes
//! to see how each added bit doubles the number of possible patterns.
//! Left column: toggle pads + value panel + counter.
//! Right column: pattern gallery adapting to N.
//! Bottom panel: binary breakdown detail.
const std = @import("std");
const rl = @import("raylib");
const theme = @import("../ui/theme.zig");
const animate = @import("../ui/animate.zig");
const ui_draw = @import("../ui/draw.zig");
const BitGrid = @import("../ui/bit_grid.zig").BitGrid;

// ════════════════════════════════════════════════════════════════
// Window & layout constants
// ════════════════════════════════════════════════════════════════

const SCREEN_W: i32 = 1400;
const SCREEN_H: i32 = 900;

const HEADER_H: f32 = 65;
const CONTENT_TOP: f32 = 74;
const MARGIN: f32 = 32;

const LEFT_W: f32 = 460;
const LEFT_X: f32 = MARGIN;
const GAP: f32 = 24;
const RIGHT_X: f32 = LEFT_X + LEFT_W + GAP;
const RIGHT_W: f32 = @as(f32, @floatFromInt(SCREEN_W)) - RIGHT_X - MARGIN;

const BOTTOM_H: f32 = 200;
const BOTTOM_Y: f32 = @as(f32, @floatFromInt(SCREEN_H)) - 16 - BOTTOM_H;
const CONTENT_BOTTOM: f32 = BOTTOM_Y - 12;

// ════════════════════════════════════════════════════════════════
// Bit count enum
// ════════════════════════════════════════════════════════════════

const BitCount = enum(u4) {
    one = 1,
    two = 2,
    four = 4,
    eight = 8,

    fn maxVal(self: BitCount) u8 {
        return switch (self) {
            .one => 1,
            .two => 3,
            .four => 15,
            .eight => 255,
        };
    }

    fn patternCount(self: BitCount) u16 {
        return switch (self) {
            .one => 2,
            .two => 4,
            .four => 16,
            .eight => 256,
        };
    }

    fn asUsize(self: BitCount) usize {
        return @intFromEnum(self);
    }
};

const bit_count_values = [4]BitCount{ .one, .two, .four, .eight };
const bit_count_labels = [4][:0]const u8{ "1", "2", "4", "8" };

// ════════════════════════════════════════════════════════════════
// Per-cell animation
// ════════════════════════════════════════════════════════════════

const CellAnim = struct {
    press_t: f32 = 0.0,
    flash_t: f32 = 0.0,
};

// ════════════════════════════════════════════════════════════════
// Counter mode
// ════════════════════════════════════════════════════════════════

const CountMode = struct {
    active: bool = false,
    value: u16 = 0,
    timer: f32 = 0,

    fn tick(self: *CountMode, dt: f32, max: u16, fast: bool) ?u8 {
        if (!self.active) return null;
        const delay: f32 = if (fast) 0.040 else 0.180;
        self.timer += dt;
        if (self.timer >= delay) {
            self.timer -= delay;
            const result: u8 = @intCast(self.value);
            self.value += 1;
            if (self.value >= max) {
                self.active = false;
                self.value = 0;
            }
            return result;
        }
        return null;
    }

    fn toggle(self: *CountMode) void {
        self.active = !self.active;
        if (self.active) {
            self.value = 0;
            self.timer = 0;
        }
    }

    fn stop(self: *CountMode) void {
        self.active = false;
    }

    fn progress(self: *const CountMode, max: u16) f32 {
        if (max <= 1) return 0;
        return @as(f32, @floatFromInt(self.value)) / @as(f32, @floatFromInt(max));
    }
};

// ════════════════════════════════════════════════════════════════
// App state
// ════════════════════════════════════════════════════════════════

const App = struct {
    bit_count: BitCount = .one,
    current_value: u8 = 0,
    grid: BitGrid,

    // Tab bar
    tab_rects: [4]rl.Rectangle = undefined,
    tab_hover: ?u2 = null,

    // Gallery
    gallery_hovered: ?u16 = null,
    gallery_cell_rects: [256]rl.Rectangle = undefined,
    gallery_cell_anims: [256]CellAnim = [_]CellAnim{.{}} ** 256,

    // Counter
    counter: CountMode = .{},
    speed_fast: bool = false,
    count_btn_rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    speed_rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 },

    // Animation
    total_time: f32 = 0,

    fn syncFromValue(self: *App) void {
        self.grid.fromUnsigned(@as(u32, self.current_value));
    }
};

// ════════════════════════════════════════════════════════════════
// Local colors
// ════════════════════════════════════════════════════════════════

const very_dim = rl.Color{ .r = 58, .g = 77, .b = 96, .a = 255 };
const cell_dark = rl.Color{ .r = 12, .g = 17, .b = 24, .a = 255 };
const cell_hover = rl.Color{ .r = 21, .g = 32, .b = 48, .a = 255 };
const cell_selected = rl.Color{ .r = 18, .g = 42, .b = 56, .a = 255 };
const cell_border = rl.Color{ .r = 26, .g = 37, .b = 48, .a = 180 };

// ════════════════════════════════════════════════════════════════
// Header bar: title + tabs + formula
// ════════════════════════════════════════════════════════════════

fn layoutTabs(app: *App) void {
    const total_w = 4 * 56 + 3 * 12;
    const x0: f32 = (@as(f32, @floatFromInt(SCREEN_W)) - @as(f32, @floatFromInt(total_w))) * 0.5;
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        app.tab_rects[i] = .{
            .x = x0 + @as(f32, @floatFromInt(i)) * (56 + 12),
            .y = 10,
            .width = 56,
            .height = 44,
        };
    }
}

fn drawHeader(app: *const App) void {
    // Title
    rl.drawText("BIT EXPLORER", @intFromFloat(MARGIN), 20, 15, theme.text_dim);
    rl.drawText("Feel the exponential growth", @intFromFloat(MARGIN), 40, 11, very_dim);

    // Tab label
    const bits_label = "BITS:";
    const bw = rl.measureText(bits_label, 11);
    rl.drawText(bits_label, @as(i32, @intFromFloat(app.tab_rects[0].x)) - bw - 12, 26, 11, very_dim);

    // Tabs
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        const r = app.tab_rects[i];
        const is_active = bit_count_values[i] == app.bit_count;
        const is_hov = if (app.tab_hover) |h| h == @as(u2, @intCast(i)) else false;

        // Background
        if (is_active) {
            rl.drawRectangleRounded(r, 0.5, 12, rl.Color{ .r = 0, .g = 229, .b = 255, .a = 30 });
            // Glow
            const glow = rl.Rectangle{ .x = r.x - 4, .y = r.y - 4, .width = r.width + 8, .height = r.height + 8 };
            rl.drawRectangleRounded(glow, 0.5, 12, rl.Color{ .r = 0, .g = 229, .b = 255, .a = 10 });
        } else if (is_hov) {
            rl.drawRectangleRounded(r, 0.5, 12, rl.Color{ .r = 0, .g = 229, .b = 255, .a = 20 });
        } else {
            rl.drawRectangleRounded(r, 0.5, 12, rl.Color{ .r = 15, .g = 25, .b = 35, .a = 255 });
        }
        // Border
        const bc = if (is_active or is_hov) theme.accent else theme.panel_border;
        rl.drawRectangleRoundedLinesEx(r, 0.5, 12, 1.0, bc);
        // Label
        const label = bit_count_labels[i];
        const tw = rl.measureText(label, 18);
        const tx: i32 = @intFromFloat(r.x + (r.width - @as(f32, @floatFromInt(tw))) * 0.5);
        const ty: i32 = @intFromFloat(r.y + 12);
        const tc = if (is_active) theme.accent else if (is_hov) theme.accent else theme.text_dim;
        rl.drawText(label, tx, ty, 18, tc);
    }

    // Formula: 2^N = X patterns
    const n = app.bit_count.asUsize();
    const pc = app.bit_count.patternCount();
    var n_buf: [4]u8 = undefined;
    const n_txt = std.fmt.bufPrintZ(&n_buf, "{d}", .{n}) catch "?";
    var pc_buf: [8]u8 = undefined;
    const pc_txt = std.fmt.bufPrintZ(&pc_buf, "{d}", .{pc}) catch "?";

    const right_edge: i32 = SCREEN_W - @as(i32, @intFromFloat(MARGIN));
    // "X patterns" right-aligned
    const pat_label = " patterns";
    const pat_w = rl.measureText(pat_label, 12);
    const pc_w = rl.measureText(pc_txt, 28);
    const eq_w = rl.measureText(" = ", 12);
    const sup_w = rl.measureText(n_txt, 10);
    const base_w = rl.measureText("2", 14);
    const total_fw = base_w + sup_w + eq_w + pc_w + pat_w;
    const fx = right_edge - total_fw;

    rl.drawText("2", fx, 22, 14, theme.text_dim);
    rl.drawText(n_txt, fx + base_w, 16, 10, theme.accent);
    rl.drawText(" = ", fx + base_w + sup_w, 22, 12, theme.text_dim);
    // Glow behind pattern count
    const pc_x = fx + base_w + sup_w + eq_w;
    const pc_glow = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 30 };
    rl.drawText(pc_txt, pc_x - 1, 10, 28, pc_glow);
    rl.drawText(pc_txt, pc_x + 1, 10, 28, pc_glow);
    rl.drawText(pc_txt, pc_x, 10, 28, theme.text);
    rl.drawText(pat_label, pc_x + pc_w, 22, 12, theme.text_dim);

    // Header separator line
    const sep_y: i32 = @intFromFloat(HEADER_H);
    const half_sw = @divTrunc(SCREEN_W, 2);
    const sep_clear = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 0 };
    const sep_mid = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 40 };
    rl.drawRectangleGradientH(0, sep_y, half_sw, 1, sep_clear, sep_mid);
    rl.drawRectangleGradientH(half_sw, sep_y, SCREEN_W - half_sw, 1, sep_mid, sep_clear);
}

// ════════════════════════════════════════════════════════════════
// Left column: bit pads + value panel + counter
// ════════════════════════════════════════════════════════════════

fn layoutBitPad(app: *App) void {
    if (app.bit_count == .eight) {
        app.grid.pad_height = 52;
        app.grid.nibble_gap = 8;
    } else {
        app.grid.pad_height = 80;
        app.grid.nibble_gap = 0;
    }
    app.grid.layoutInRect(LEFT_X, CONTENT_TOP + 16, LEFT_W);
}

fn drawLeftColumn(app: *const App) void {
    // "TOGGLE BITS" label
    rl.drawText("TOGGLE BITS", @intFromFloat(LEFT_X), @intFromFloat(CONTENT_TOP), 11, very_dim);

    // Bit pads
    app.grid.draw();

    // Value panel
    const panel_y: f32 = CONTENT_TOP + 16 + app.grid.pad_height + 20;
    const panel_h: f32 = 140;
    ui_draw.glassPanel(LEFT_X, panel_y, LEFT_W, panel_h);

    const value = app.current_value;
    const n = app.bit_count.asUsize();

    // BINARY label + colored string
    rl.drawText("BINARY", @intFromFloat(LEFT_X + 16), @intFromFloat(panel_y + 16), 11, very_dim);
    drawColoredBinary(value, n, @intFromFloat(LEFT_X + 16), @intFromFloat(panel_y + 34), 24);

    // DECIMAL
    rl.drawText("DECIMAL", @intFromFloat(LEFT_X + 16), @intFromFloat(panel_y + 70), 11, very_dim);
    var dec_buf: [4]u8 = undefined;
    const dec_txt = std.fmt.bufPrintZ(&dec_buf, "{d}", .{value}) catch "?";
    const dec_glow = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 30 };
    const dec_x: i32 = @intFromFloat(LEFT_X + 16);
    const dec_y: i32 = @intFromFloat(panel_y + 88);
    rl.drawText(dec_txt, dec_x - 1, dec_y, 36, dec_glow);
    rl.drawText(dec_txt, dec_x + 1, dec_y, 36, dec_glow);
    rl.drawText(dec_txt, dec_x, dec_y, 36, theme.text);

    // HEX
    var hex_buf: [8]u8 = undefined;
    const hex_txt = std.fmt.bufPrintZ(&hex_buf, "0x{X:0>2}", .{value}) catch "0x00";
    const hex_w = rl.measureText(hex_txt, 22);
    rl.drawText("HEX", @as(i32, @intFromFloat(LEFT_X + LEFT_W - 16)) - hex_w, @intFromFloat(panel_y + 70), 11, very_dim);
    rl.drawText(hex_txt, @as(i32, @intFromFloat(LEFT_X + LEFT_W - 16)) - hex_w, @intFromFloat(panel_y + 92), 22, theme.text);

    // Counter controls
    drawCounterControls(app, panel_y + panel_h + 16);
}

fn drawColoredBinary(value: u8, n: usize, x: i32, y: i32, font_size: i32) void {
    const on_color = theme.bit_on;
    const off_color = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 90 };
    var x_cursor: i32 = x;
    const char_w: i32 = @divTrunc(font_size * 3, 4) + 2;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const bit_idx = n - 1 - i;
        const bit_val: u1 = @intCast((value >> @intCast(bit_idx)) & 1);
        const chr: [:0]const u8 = if (bit_val == 1) "1" else "0";
        const color = if (bit_val == 1) on_color else off_color;
        if (bit_val == 1) {
            const glow = rl.Color{ .r = 90, .g = 240, .b = 140, .a = 40 };
            rl.drawText(chr, x_cursor - 1, y, font_size, glow);
            rl.drawText(chr, x_cursor + 1, y, font_size, glow);
        }
        rl.drawText(chr, x_cursor, y, font_size, color);
        x_cursor += char_w;
        if (i == 3 and n > 4) x_cursor += 8;
    }
}

fn drawCounterControls(app: *const App, y: f32) void {
    ui_draw.glassPanel(LEFT_X, y, LEFT_W, 70);

    // COUNT button
    const btn_r = app.count_btn_rect;
    const is_active = app.counter.active;
    const m = rl.getMousePosition();
    const btn_hov = rl.checkCollisionPointRec(m, btn_r);
    const btn_bg_a: u8 = if (is_active) 38 else if (btn_hov) 30 else 15;
    const btn_border_a: u8 = if (is_active) 255 else if (btn_hov) 153 else 77;
    rl.drawRectangleRounded(btn_r, 0.15, 4, rl.Color{ .r = 0, .g = 229, .b = 255, .a = btn_bg_a });
    rl.drawRectangleRoundedLinesEx(btn_r, 0.15, 4, 1.0, rl.Color{ .r = 0, .g = 229, .b = 255, .a = btn_border_a });
    const btn_label: [:0]const u8 = if (is_active) "STOP" else "COUNT";
    const btw = rl.measureText(btn_label, 12);
    rl.drawText(btn_label, @intFromFloat(btn_r.x + (btn_r.width - @as(f32, @floatFromInt(btw))) * 0.5), @intFromFloat(btn_r.y + 10), 12, theme.accent);

    // Speed toggle
    const sr = app.speed_rect;
    const track_bg = if (app.speed_fast) rl.Color{ .r = 0, .g = 229, .b = 255, .a = 38 } else rl.Color{ .r = 26, .g = 32, .b = 48, .a = 255 };
    rl.drawRectangleRounded(sr, 0.5, 12, track_bg);
    const track_border = if (app.speed_fast) rl.Color{ .r = 0, .g = 229, .b = 255, .a = 102 } else theme.panel_border;
    rl.drawRectangleRoundedLinesEx(sr, 0.5, 12, 1.0, track_border);
    const knob_x: f32 = if (app.speed_fast) sr.x + 26 else sr.x + 2;
    const knob_color = if (app.speed_fast) theme.accent else theme.text_dim;
    rl.drawCircle(@intFromFloat(knob_x + 9), @intFromFloat(sr.y + 12), 9, knob_color);
    // Labels
    rl.drawText("SLOW", @intFromFloat(sr.x - 38), @intFromFloat(sr.y + 6), 10, if (!app.speed_fast) theme.text_dim else very_dim);
    rl.drawText("FAST", @intFromFloat(sr.x + sr.width + 8), @intFromFloat(sr.y + 6), 10, if (app.speed_fast) theme.accent else very_dim);

    // Progress
    if (app.counter.active) {
        const max = app.bit_count.patternCount();
        var prog_buf: [16]u8 = undefined;
        const prog_txt = std.fmt.bufPrintZ(&prog_buf, "{d}/{d}", .{ app.counter.value, max }) catch "?/?";
        rl.drawText(prog_txt, @intFromFloat(LEFT_X + LEFT_W - 80), @intFromFloat(y + 16), 11, theme.text_dim);
        // Progress bar
        const bar_x: f32 = LEFT_X + 16;
        const bar_y: f32 = y + 54;
        const bar_w: f32 = LEFT_W - 32;
        rl.drawRectangleRounded(.{ .x = bar_x, .y = bar_y, .width = bar_w, .height = 3 }, 0.5, 4, rl.Color{ .r = 15, .g = 25, .b = 35, .a = 255 });
        const fill_w = bar_w * app.counter.progress(max);
        if (fill_w > 1) {
            rl.drawRectangleRounded(.{ .x = bar_x, .y = bar_y, .width = fill_w, .height = 3 }, 0.5, 4, theme.accent);
        }
    }
}

// ════════════════════════════════════════════════════════════════
// Gallery: right column, adapts to N
// ════════════════════════════════════════════════════════════════

fn layoutGallery(app: *App) void {
    const gx: f32 = RIGHT_X + 16;
    const gy: f32 = CONTENT_TOP + 28;
    const gw: f32 = RIGHT_W - 32;
    const gh: f32 = CONTENT_BOTTOM - gy - 8;

    switch (app.bit_count) {
        .one => layoutGallery1(app, gx, gy, gw, gh),
        .two => layoutGallery2(app, gx, gy, gw, gh),
        .four => layoutGallery4(app, gx, gy, gw, gh),
        .eight => layoutGallery8(app, gx, gy, gw, gh),
    }
}

fn layoutGallery1(app: *App, gx: f32, gy: f32, gw: f32, gh: f32) void {
    const gap: f32 = 24;
    const cw = (gw - gap) / 2.0;
    app.gallery_cell_rects[0] = .{ .x = gx, .y = gy, .width = cw, .height = gh };
    app.gallery_cell_rects[1] = .{ .x = gx + cw + gap, .y = gy, .width = cw, .height = gh };
}

fn layoutGallery2(app: *App, gx: f32, gy: f32, gw: f32, gh: f32) void {
    const gap: f32 = 16;
    const cw = (gw - gap) / 2.0;
    const ch = (gh - gap) / 2.0;
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        const col: f32 = @floatFromInt(i % 2);
        const row: f32 = @floatFromInt(i / 2);
        app.gallery_cell_rects[i] = .{
            .x = gx + col * (cw + gap),
            .y = gy + row * (ch + gap),
            .width = cw,
            .height = ch,
        };
    }
}

fn layoutGallery4(app: *App, gx: f32, gy: f32, gw: f32, gh: f32) void {
    const gap: f32 = 10;
    const cw = (gw - 3 * gap) / 4.0;
    const ch = (gh - 3 * gap) / 4.0;
    var i: usize = 0;
    while (i < 16) : (i += 1) {
        const col: f32 = @floatFromInt(i % 4);
        const row: f32 = @floatFromInt(i / 4);
        app.gallery_cell_rects[i] = .{
            .x = gx + col * (cw + gap),
            .y = gy + row * (ch + gap),
            .width = cw,
            .height = ch,
        };
    }
}

fn layoutGallery8(app: *App, gx: f32, gy: f32, gw: f32, gh: f32) void {
    // 16x16 grid with row/col headers
    const hdr_w: f32 = 30; // row header width
    const hdr_h: f32 = 18; // col header height
    const gap: f32 = 2;
    const cell_w = (gw - hdr_w - 15 * gap) / 16.0;
    const cell_h = (gh - hdr_h - 15 * gap) / 16.0;
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const col: f32 = @floatFromInt(i % 16);
        const row: f32 = @floatFromInt(i / 16);
        app.gallery_cell_rects[i] = .{
            .x = gx + hdr_w + col * (cell_w + gap),
            .y = gy + hdr_h + row * (cell_h + gap),
            .width = cell_w,
            .height = cell_h,
        };
    }
}

fn drawGallery(app: *const App) void {
    // Section label
    rl.drawText("ALL PATTERNS", @intFromFloat(RIGHT_X), @intFromFloat(CONTENT_TOP), 11, very_dim);
    var count_buf: [16]u8 = undefined;
    const count_txt = std.fmt.bufPrintZ(&count_buf, "{d} patterns", .{app.bit_count.patternCount()}) catch "?";
    const cw = rl.measureText(count_txt, 11);
    rl.drawText(count_txt, @as(i32, @intFromFloat(RIGHT_X + RIGHT_W)) - cw, @intFromFloat(CONTENT_TOP), 11, theme.accent);

    // Gallery panel
    ui_draw.glassPanel(RIGHT_X, CONTENT_TOP + 14, RIGHT_W, CONTENT_BOTTOM - CONTENT_TOP - 14);

    switch (app.bit_count) {
        .one => drawGallery1(app),
        .two => drawGallery2(app),
        .four => drawGallery4(app),
        .eight => drawGallery8(app),
    }
}

fn drawGallery1(app: *const App) void {
    var i: usize = 0;
    while (i < 2) : (i += 1) {
        const r = app.gallery_cell_rects[i];
        const val: u8 = @intCast(i);
        const is_sel = app.current_value == val;
        const is_hov = if (app.gallery_hovered) |h| h == @as(u16, @intCast(i)) else false;
        const anim = app.gallery_cell_anims[i];

        const bg = if (is_sel) cell_selected else if (is_hov) cell_hover else cell_dark;
        rl.drawRectangleRounded(r, 0.04, 6, bg);
        const bc = if (is_sel) theme.accent else if (is_hov) rl.Color{ .r = 0, .g = 229, .b = 255, .a = 100 } else cell_border;
        rl.drawRectangleRoundedLinesEx(r, 0.04, 6, if (is_sel) @as(f32, 2.0) else @as(f32, 1.0), bc);

        if (is_sel) {
            const glow = rl.Rectangle{ .x = r.x - 4, .y = r.y - 4, .width = r.width + 8, .height = r.height + 8 };
            rl.drawRectangleRounded(glow, 0.06, 8, rl.Color{ .r = 0, .g = 229, .b = 255, .a = 12 });
        }

        // Flash
        if (anim.flash_t > 0.01) {
            const fa: u8 = @intFromFloat(std.math.clamp(anim.flash_t * 80.0, 0.0, 255.0));
            rl.drawRectangleRounded(r, 0.04, 6, rl.Color{ .r = 0, .g = 229, .b = 255, .a = fa });
        }

        // Mini bit square
        const sq_size: f32 = 40;
        const sq_x: f32 = r.x + (r.width - sq_size) * 0.5;
        const sq_y: f32 = r.y + r.height * 0.25;
        if (val == 1) {
            rl.drawRectangleRounded(.{ .x = sq_x - 4, .y = sq_y - 4, .width = sq_size + 8, .height = sq_size + 8 }, 0.12, 4, rl.Color{ .r = 90, .g = 240, .b = 140, .a = 25 });
            rl.drawRectangleRounded(.{ .x = sq_x, .y = sq_y, .width = sq_size, .height = sq_size }, 0.12, 4, theme.bit_on);
        } else {
            rl.drawRectangleRounded(.{ .x = sq_x, .y = sq_y, .width = sq_size, .height = sq_size }, 0.12, 4, rl.Color{ .r = 26, .g = 32, .b = 48, .a = 255 });
        }

        // Large decimal
        const label: [:0]const u8 = if (val == 0) "0" else "1";
        const tw = rl.measureText(label, 48);
        const tx: i32 = @intFromFloat(r.x + (r.width - @as(f32, @floatFromInt(tw))) * 0.5);
        const ty: i32 = @intFromFloat(r.y + r.height * 0.50);
        rl.drawText(label, tx, ty, 48, theme.text);

        // OFF/ON label
        const sub: [:0]const u8 = if (val == 0) "OFF" else "ON";
        const sw = rl.measureText(sub, 14);
        const sx: i32 = @intFromFloat(r.x + (r.width - @as(f32, @floatFromInt(sw))) * 0.5);
        rl.drawText(sub, sx, @intFromFloat(r.y + r.height * 0.72), 14, if (val == 0) theme.text_dim else theme.bit_on);
    }
}

fn drawGallery2(app: *const App) void {
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        const r = app.gallery_cell_rects[i];
        const val: u8 = @intCast(i);
        const is_sel = app.current_value == val;
        const is_hov = if (app.gallery_hovered) |h| h == @as(u16, @intCast(i)) else false;
        const anim = app.gallery_cell_anims[i];

        const bg = if (is_sel) cell_selected else if (is_hov) cell_hover else cell_dark;
        rl.drawRectangleRounded(r, 0.04, 6, bg);
        const bc = if (is_sel) theme.accent else if (is_hov) rl.Color{ .r = 0, .g = 229, .b = 255, .a = 100 } else cell_border;
        rl.drawRectangleRoundedLinesEx(r, 0.04, 6, if (is_sel) @as(f32, 2.0) else @as(f32, 1.0), bc);

        if (anim.flash_t > 0.01) {
            const fa: u8 = @intFromFloat(std.math.clamp(anim.flash_t * 80.0, 0.0, 255.0));
            rl.drawRectangleRounded(r, 0.04, 6, rl.Color{ .r = 0, .g = 229, .b = 255, .a = fa });
        }

        // Mini bit row
        drawMiniBitRow(r.x + r.width * 0.5 - 32, r.y + r.height * 0.20, val, 2, 28);

        // Decimal
        var dec_buf: [4]u8 = undefined;
        const dec_txt = std.fmt.bufPrintZ(&dec_buf, "{d}", .{val}) catch "?";
        const tw = rl.measureText(dec_txt, 36);
        rl.drawText(dec_txt, @intFromFloat(r.x + (r.width - @as(f32, @floatFromInt(tw))) * 0.5), @intFromFloat(r.y + r.height * 0.45), 36, theme.text);

        // Binary string
        var bin_buf: [4]u8 = undefined;
        const bin_txt = std.fmt.bufPrintZ(&bin_buf, "{b:0>2}", .{val}) catch "??";
        const bw = rl.measureText(bin_txt, 14);
        rl.drawText(bin_txt, @intFromFloat(r.x + (r.width - @as(f32, @floatFromInt(bw))) * 0.5), @intFromFloat(r.y + r.height * 0.72), 14, theme.accent);
    }
}

fn drawGallery4(app: *const App) void {
    var i: usize = 0;
    while (i < 16) : (i += 1) {
        const r = app.gallery_cell_rects[i];
        const val: u8 = @intCast(i);
        const is_sel = app.current_value == val;
        const is_hov = if (app.gallery_hovered) |h| h == @as(u16, @intCast(i)) else false;
        const anim = app.gallery_cell_anims[i];

        const bg = if (is_sel) cell_selected else if (is_hov) cell_hover else cell_dark;
        rl.drawRectangleRounded(r, 0.04, 6, bg);
        const bc = if (is_sel) theme.accent else if (is_hov) rl.Color{ .r = 0, .g = 229, .b = 255, .a = 100 } else cell_border;
        rl.drawRectangleRoundedLinesEx(r, 0.04, 6, if (is_sel) @as(f32, 1.5) else @as(f32, 1.0), bc);

        if (anim.flash_t > 0.01) {
            const fa: u8 = @intFromFloat(std.math.clamp(anim.flash_t * 80.0, 0.0, 255.0));
            rl.drawRectangleRounded(r, 0.04, 6, rl.Color{ .r = 0, .g = 229, .b = 255, .a = fa });
        }

        // Mini bit row
        drawMiniBitRow(r.x + r.width * 0.5 - 36, r.y + 12, val, 4, 16);

        // Decimal
        var dec_buf: [4]u8 = undefined;
        const dec_txt = std.fmt.bufPrintZ(&dec_buf, "{d}", .{val}) catch "?";
        const tw = rl.measureText(dec_txt, 24);
        rl.drawText(dec_txt, @intFromFloat(r.x + (r.width - @as(f32, @floatFromInt(tw))) * 0.5), @intFromFloat(r.y + r.height * 0.42), 24, theme.text);

        // Binary
        var bin_buf: [6]u8 = undefined;
        const bin_txt = std.fmt.bufPrintZ(&bin_buf, "{b:0>4}", .{val}) catch "????";
        const bw = rl.measureText(bin_txt, 11);
        rl.drawText(bin_txt, @intFromFloat(r.x + (r.width - @as(f32, @floatFromInt(bw))) * 0.5), @intFromFloat(r.y + r.height - 20), 11, very_dim);
    }
}

fn drawGallery8(app: *const App) void {
    // Column headers (0..F)
    if (app.gallery_cell_rects[0].width > 0) {
        var col: usize = 0;
        while (col < 16) : (col += 1) {
            const r = app.gallery_cell_rects[col];
            var buf: [2]u8 = undefined;
            const txt = std.fmt.bufPrintZ(&buf, "{X}", .{col}) catch "?";
            const tw = rl.measureText(txt, 10);
            rl.drawText(txt, @intFromFloat(r.x + (r.width - @as(f32, @floatFromInt(tw))) * 0.5), @intFromFloat(r.y - 16), 10, theme.text_dim);
        }
    }
    // Row headers
    var row: usize = 0;
    while (row < 16) : (row += 1) {
        const r = app.gallery_cell_rects[row * 16];
        var buf: [4]u8 = undefined;
        const val: u8 = @intCast(row * 16);
        const txt = std.fmt.bufPrintZ(&buf, "{X:0>2}", .{val}) catch "??";
        const tw = rl.measureText(txt, 10);
        rl.drawText(txt, @intFromFloat(r.x - @as(f32, @floatFromInt(tw)) - 6), @intFromFloat(r.y + (r.height - 10) * 0.5), 10, theme.text_dim);
    }

    // Cells
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const r = app.gallery_cell_rects[i];
        const val: u8 = @intCast(i);
        const is_sel = app.current_value == val;
        const is_hov = if (app.gallery_hovered) |h| h == @as(u16, @intCast(i)) else false;
        const anim = app.gallery_cell_anims[i];

        // Value-based background intensity
        const intensity: f32 = @as(f32, @floatFromInt(val)) / 255.0;
        const bg_r: u8 = @intFromFloat(12 + intensity * 20);
        const bg_g: u8 = @intFromFloat(17 + intensity * 15);
        const bg_b: u8 = @intFromFloat(24 + intensity * 24);
        const bg = if (is_sel) cell_selected else if (is_hov) cell_hover else rl.Color{ .r = bg_r, .g = bg_g, .b = bg_b, .a = 255 };
        rl.drawRectangleRec(r, bg);

        if (is_sel) {
            rl.drawRectangleRec(.{ .x = r.x - 1, .y = r.y - 1, .width = r.width + 2, .height = r.height + 2 }, rl.Color{ .r = 0, .g = 229, .b = 255, .a = 40 });
            rl.drawRectangleRec(r, cell_selected);
        }

        if (anim.flash_t > 0.01) {
            const fa: u8 = @intFromFloat(std.math.clamp(anim.flash_t * 100.0, 0.0, 255.0));
            rl.drawRectangleRec(r, rl.Color{ .r = 0, .g = 229, .b = 255, .a = fa });
        }

        // Text
        var buf: [4]u8 = undefined;
        const txt = std.fmt.bufPrintZ(&buf, "{d}", .{val}) catch "?";
        const font_sz: i32 = 9;
        const tw = rl.measureText(txt, font_sz);
        const text_color = if (is_sel or is_hov) theme.text else if (val >= 128) rl.Color{ .r = 136, .g = 153, .b = 170, .a = 255 } else theme.text_dim;
        rl.drawText(txt, @intFromFloat(r.x + (r.width - @as(f32, @floatFromInt(tw))) * 0.5), @intFromFloat(r.y + (r.height - @as(f32, @floatFromInt(font_sz))) * 0.5), font_sz, text_color);
    }
}

fn drawMiniBitRow(x: f32, y: f32, value: u8, bits: usize, sq_size: f32) void {
    const gap: f32 = 4;
    var i: usize = 0;
    while (i < bits) : (i += 1) {
        const bit_idx = bits - 1 - i;
        const bit_val: u1 = @intCast((value >> @intCast(bit_idx)) & 1);
        const sx = x + @as(f32, @floatFromInt(i)) * (sq_size + gap);
        const rect = rl.Rectangle{ .x = sx, .y = y, .width = sq_size, .height = sq_size };
        if (bit_val == 1) {
            rl.drawRectangleRounded(rect, 0.12, 4, theme.bit_on);
        } else {
            rl.drawRectangleRounded(rect, 0.12, 4, rl.Color{ .r = 26, .g = 32, .b = 48, .a = 255 });
        }
    }
}

// ════════════════════════════════════════════════════════════════
// Bottom info panel
// ════════════════════════════════════════════════════════════════

fn drawBottomPanel(app: *const App) void {
    ui_draw.glassPanel(MARGIN, BOTTOM_Y, @as(f32, @floatFromInt(SCREEN_W)) - 2 * MARGIN, BOTTOM_H);

    const value = app.current_value;
    const n = app.bit_count.asUsize();
    const third_w = (@as(f32, @floatFromInt(SCREEN_W)) - 2 * MARGIN) / 3.0;

    // Column 1: Binary breakdown
    rl.drawText("BINARY BREAKDOWN", @intFromFloat(MARGIN + 20), @intFromFloat(BOTTOM_Y + 16), 11, very_dim);
    drawBinaryBreakdown(value, n, @intFromFloat(MARGIN + 20), @intFromFloat(BOTTOM_Y + 40));

    // Column 2: Value (centered)
    const col2_x: f32 = MARGIN + third_w;
    // Gradient divider
    const div_x: i32 = @intFromFloat(col2_x);
    const div_top: i32 = @intFromFloat(BOTTOM_Y + 12);
    const div_bot: i32 = @intFromFloat(BOTTOM_Y + BOTTOM_H - 12);
    const div_mid = @divTrunc(div_top + div_bot, 2);
    const dv_clear = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 0 };
    const dv_mid = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 25 };
    rl.drawRectangleGradientV(div_x, div_top, 1, div_mid - div_top, dv_clear, dv_mid);
    rl.drawRectangleGradientV(div_x, div_mid, 1, div_bot - div_mid, dv_mid, dv_clear);

    rl.drawText("VALUE", @intFromFloat(col2_x + third_w * 0.5 - 20), @intFromFloat(BOTTOM_Y + 16), 11, very_dim);
    // Large decimal
    var dec_buf: [4]u8 = undefined;
    const dec_txt = std.fmt.bufPrintZ(&dec_buf, "{d}", .{value}) catch "?";
    const dec_w = rl.measureText(dec_txt, 52);
    const dec_cx: i32 = @intFromFloat(col2_x + third_w * 0.5 - @as(f32, @floatFromInt(dec_w)) * 0.5);
    rl.drawText(dec_txt, dec_cx, @intFromFloat(BOTTOM_Y + 46), 52, theme.text);
    // Hex
    var hex_buf: [8]u8 = undefined;
    const hex_txt = std.fmt.bufPrintZ(&hex_buf, "0x{X:0>2}", .{value}) catch "0x00";
    const hex_w = rl.measureText(hex_txt, 18);
    rl.drawText(hex_txt, @intFromFloat(col2_x + third_w * 0.5 - @as(f32, @floatFromInt(hex_w)) * 0.5), @intFromFloat(BOTTOM_Y + 108), 18, theme.text_dim);
    // Formula
    var n_buf2: [4]u8 = undefined;
    const n_txt2 = std.fmt.bufPrintZ(&n_buf2, "{d}", .{n}) catch "?";
    var pc_buf2: [8]u8 = undefined;
    const pc_txt2 = std.fmt.bufPrintZ(&pc_buf2, "{d}", .{app.bit_count.patternCount()}) catch "?";
    const f_base_w = rl.measureText("2", 12);
    const f_sup_w = rl.measureText(n_txt2, 9);
    const f_eq_w = rl.measureText(" = ", 12);
    const f_pc_w = rl.measureText(pc_txt2, 14);
    const f_total = f_base_w + f_sup_w + f_eq_w + f_pc_w;
    const f_x: i32 = @intFromFloat(col2_x + third_w * 0.5 - @as(f32, @floatFromInt(f_total)) * 0.5);
    rl.drawText("2", f_x, @intFromFloat(BOTTOM_Y + 140), 12, theme.text_dim);
    rl.drawText(n_txt2, f_x + f_base_w, @intFromFloat(BOTTOM_Y + 134), 9, theme.accent);
    rl.drawText(" = ", f_x + f_base_w + f_sup_w, @intFromFloat(BOTTOM_Y + 140), 12, theme.text_dim);
    rl.drawText(pc_txt2, f_x + f_base_w + f_sup_w + f_eq_w, @intFromFloat(BOTTOM_Y + 137), 14, theme.accent);

    // Column 3: Bit pills
    const col3_x: f32 = MARGIN + 2 * third_w;
    // Divider
    rl.drawRectangleGradientV(@intFromFloat(col3_x), div_top, 1, div_mid - div_top, dv_clear, dv_mid);
    rl.drawRectangleGradientV(@intFromFloat(col3_x), div_mid, 1, div_bot - div_mid, dv_mid, dv_clear);

    rl.drawText("BIT BREAKDOWN", @intFromFloat(col3_x + 20), @intFromFloat(BOTTOM_Y + 16), 11, very_dim);
    drawBitPills(value, n, col3_x + 20, BOTTOM_Y + 44);
}

fn drawBinaryBreakdown(value: u8, n: usize, x: i32, y: i32) void {
    const col_w: i32 = @max(28, @divTrunc(300, @as(i32, @intCast(n))));
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const bit_idx = n - 1 - i;
        const bit_val: u1 = @intCast((value >> @intCast(bit_idx)) & 1);
        const cx = x + @as(i32, @intCast(i)) * col_w;

        // Bit index label
        var idx_buf: [4]u8 = undefined;
        const idx_txt = std.fmt.bufPrintZ(&idx_buf, "b{d}", .{bit_idx}) catch "b?";
        rl.drawText(idx_txt, cx, y, 10, theme.text_dim);

        // Bit value
        const chr: [:0]const u8 = if (bit_val == 1) "1" else "0";
        const color = if (bit_val == 1) theme.bit_on else rl.Color{ .r = 46, .g = 61, .b = 76, .a = 255 };
        if (bit_val == 1) {
            const glow = rl.Color{ .r = 90, .g = 240, .b = 140, .a = 30 };
            rl.drawText(chr, cx - 1, y + 18, 28, glow);
            rl.drawText(chr, cx + 1, y + 18, 28, glow);
        }
        rl.drawText(chr, cx, y + 18, 28, color);

        // Power label
        var pow_buf: [16]u8 = undefined;
        const pow_val: u32 = @as(u32, 1) << @intCast(bit_idx);
        const pow_txt = std.fmt.bufPrintZ(&pow_buf, "2^{d}={d}", .{ bit_idx, pow_val }) catch "?";
        rl.drawText(pow_txt, cx, y + 54, 9, very_dim);

        // ON background tint
        if (bit_val == 1) {
            const tint_x = cx - 4;
            const tint_w = col_w - 4;
            rl.drawRectangle(tint_x, y - 2, tint_w, 80, rl.Color{ .r = 90, .g = 240, .b = 140, .a = 8 });
        }
    }
}

fn drawBitPills(value: u8, n: usize, x: f32, y: f32) void {
    var x_cursor: f32 = x;
    const row_h: f32 = 30;
    var cur_y: f32 = y;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const bit_idx = n - 1 - i;
        const bit_val: u1 = @intCast((value >> @intCast(bit_idx)) & 1);
        var buf: [8]u8 = undefined;
        const label = std.fmt.bufPrintZ(&buf, "b{d}={d}", .{ bit_idx, bit_val }) catch "?";
        const pw = ui_draw.pillBadge(x_cursor, cur_y, label, bit_val == 1);
        x_cursor += pw + 8;
        // Wrap after 4 pills
        if ((i + 1) % 4 == 0 and i + 1 < n) {
            x_cursor = x;
            cur_y += row_h;
        }
    }
}

// ════════════════════════════════════════════════════════════════
// Tab switching
// ════════════════════════════════════════════════════════════════

fn switchBitCount(app: *App, new_count: BitCount) void {
    if (new_count == app.bit_count) return;
    app.counter.stop();
    app.bit_count = new_count;
    app.current_value = 0;

    app.grid.setBitCount(new_count.asUsize());
    layoutBitPad(app);

    app.gallery_cell_anims = [_]CellAnim{.{}} ** 256;
    app.gallery_hovered = null;
    layoutGallery(app);
}

// ════════════════════════════════════════════════════════════════
// Input handling
// ════════════════════════════════════════════════════════════════

fn handleInput(app: *App, dt: f32) void {
    const m = rl.getMousePosition();

    // Tab hover + click
    app.tab_hover = null;
    var ti: usize = 0;
    while (ti < 4) : (ti += 1) {
        if (rl.checkCollisionPointRec(m, app.tab_rects[ti])) {
            app.tab_hover = @intCast(ti);
            if (rl.isMouseButtonPressed(.left)) {
                switchBitCount(app, bit_count_values[ti]);
                return;
            }
        }
    }

    // BitGrid input (toggle pads)
    app.grid.handleInput();
    if (app.grid.just_toggled != null) {
        const val = app.grid.toUnsigned();
        app.current_value = @intCast(val & @as(u32, app.bit_count.maxVal()));
        app.gallery_cell_anims[app.current_value].flash_t = 1.0;
    }

    // Gallery input
    app.gallery_hovered = null;
    const count = app.bit_count.patternCount();
    var gi: usize = 0;
    while (gi < count) : (gi += 1) {
        if (rl.checkCollisionPointRec(m, app.gallery_cell_rects[gi])) {
            app.gallery_hovered = @intCast(gi);
            if (rl.isMouseButtonPressed(.left)) {
                app.current_value = @intCast(gi);
                app.syncFromValue();
                app.gallery_cell_anims[gi].press_t = 1.0;
                app.gallery_cell_anims[gi].flash_t = 1.0;
            }
            break;
        }
    }

    // Counter button
    if (rl.isMouseButtonPressed(.left) and rl.checkCollisionPointRec(m, app.count_btn_rect)) {
        app.counter.toggle();
    }

    // Speed toggle
    if (rl.isMouseButtonPressed(.left) and rl.checkCollisionPointRec(m, app.speed_rect)) {
        app.speed_fast = !app.speed_fast;
    }

    // Counter tick
    if (app.counter.tick(dt, count, app.speed_fast)) |v| {
        app.current_value = v;
        app.syncFromValue();
        app.gallery_cell_anims[v].press_t = 1.0;
        app.gallery_cell_anims[v].flash_t = 1.0;
    }

    // Keyboard
    if (rl.isKeyPressed(.one)) switchBitCount(app, .one);
    if (rl.isKeyPressed(.two)) switchBitCount(app, .two);
    if (rl.isKeyPressed(.four)) switchBitCount(app, .four);
    if (rl.isKeyPressed(.eight)) switchBitCount(app, .eight);
    if (rl.isKeyPressed(.space)) app.counter.toggle();
    if (rl.isKeyPressed(.right) or rl.isKeyPressed(.up)) {
        if (app.current_value < app.bit_count.maxVal()) {
            app.current_value += 1;
            app.syncFromValue();
            app.gallery_cell_anims[app.current_value].flash_t = 1.0;
        }
    }
    if (rl.isKeyPressed(.left) or rl.isKeyPressed(.down)) {
        if (app.current_value > 0) {
            app.current_value -= 1;
            app.syncFromValue();
            app.gallery_cell_anims[app.current_value].flash_t = 1.0;
        }
    }
}

// ════════════════════════════════════════════════════════════════
// Animation tick
// ════════════════════════════════════════════════════════════════

fn tickAnimations(app: *App, dt: f32) void {
    app.total_time = @mod(app.total_time + dt, std.math.tau);
    app.grid.tick(dt);
    const count = app.bit_count.patternCount();
    var i: usize = 0;
    while (i < count) : (i += 1) {
        app.gallery_cell_anims[i].press_t = animate.decay(app.gallery_cell_anims[i].press_t, dt, 8.0);
        app.gallery_cell_anims[i].flash_t = animate.decay(app.gallery_cell_anims[i].flash_t, dt, 5.0);
    }
}

// ════════════════════════════════════════════════════════════════
// Entry point
// ════════════════════════════════════════════════════════════════

pub fn runBitPatterns() !void {
    rl.initWindow(SCREEN_W, SCREEN_H, "Bit Explorer");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var app: App = .{ .grid = BitGrid.init(1) };

    // Layout
    layoutTabs(&app);
    layoutBitPad(&app);
    layoutGallery(&app);

    // Counter controls geometry
    const ctrl_y: f32 = CONTENT_TOP + 16 + app.grid.pad_height + 20 + 140 + 16;
    app.count_btn_rect = .{ .x = LEFT_X + 16, .y = ctrl_y + 14, .width = 90, .height = 36 };
    app.speed_rect = .{ .x = LEFT_X + 130, .y = ctrl_y + 20, .width = 48, .height = 24 };

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        handleInput(&app, dt);
        tickAnimations(&app, dt);

        // Recompute counter control y based on current grid height
        const new_ctrl_y: f32 = CONTENT_TOP + 16 + app.grid.pad_height + 20 + 140 + 16;
        app.count_btn_rect.y = new_ctrl_y + 14;
        app.speed_rect.y = new_ctrl_y + 20;

        rl.beginDrawing();
        defer rl.endDrawing();

        theme.drawBackground(SCREEN_W, SCREEN_H);
        theme.drawVignette(SCREEN_W, SCREEN_H);

        drawHeader(&app);
        drawLeftColumn(&app);
        drawGallery(&app);
        drawBottomPanel(&app);

        theme.drawScanlines(SCREEN_W, SCREEN_H);
    }
}
