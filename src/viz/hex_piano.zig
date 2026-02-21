//! Hex Piano -- interactive 16-bit binary number pad with hex digit input.
//! Clickable bits with hex-forward readouts, hex digit pads for nibble-level
//! manipulation, byte decomposition, and endianness display.
//! Neon cyber aesthetic.
const std = @import("std");
const rl = @import("raylib");
const theme = @import("../ui/theme.zig");
const animate = @import("../ui/animate.zig");
const BitGrid = @import("../ui/bit_grid.zig").BitGrid;
const ui_draw = @import("../ui/draw.zig");

// ════════════════════════════════════════════════════════════════
// Layout constants
// ════════════════════════════════════════════════════════════════

const SCREEN_W: i32 = 1400;
const SCREEN_H: i32 = 800;
const MARGIN: f32 = 28;
const SW: f32 = @floatFromInt(SCREEN_W);

const PAD_Y: f32 = 168;
const PAD_H: f32 = 96;
const PAD_BOTTOM: f32 = PAD_Y + PAD_H; // 264
const HEX_PAD_Y: f32 = PAD_BOTTOM + 26; // 290
const HEX_PAD_H: f32 = 56;
const HEX_SECTION_EXTRA: f32 = HEX_PAD_H + 12; // 68

// ════════════════════════════════════════════════════════════════
// Hex pad state
// ════════════════════════════════════════════════════════════════

const HexPad = struct {
    rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    flash_t: f32 = 0.0,
    press_t: f32 = 0.0,
};

// ════════════════════════════════════════════════════════════════
// App state
// ════════════════════════════════════════════════════════════════

const App = struct {
    grid: BitGrid,
    hex_pads: [4]HexPad = [_]HexPad{.{}} ** 4,
    /// Which nibble (0-3, MSB to LSB) has keyboard focus. null = none.
    hex_cursor: ?u2 = null,
    cursor_time: f32 = 0.0,
};

// ════════════════════════════════════════════════════════════════
// Hex pad layout
// ════════════════════════════════════════════════════════════════

fn layoutHexPads(app: *App) void {
    const hex_pad_w: f32 = 80;
    var g: usize = 0;
    while (g < 4) : (g += 1) {
        const first = g * 4;
        const last = first + 3;
        const cx = (app.grid.pads[first].rect.x +
            app.grid.pads[last].rect.x +
            app.grid.pads[last].rect.width) * 0.5;
        app.hex_pads[g].rect = .{
            .x = cx - hex_pad_w * 0.5,
            .y = HEX_PAD_Y,
            .width = hex_pad_w,
            .height = HEX_PAD_H,
        };
    }
}

// ════════════════════════════════════════════════════════════════
// Hex hero panel (large centered hex value at top)
// ════════════════════════════════════════════════════════════════

fn drawHexHeroPanel(grid: *const BitGrid) void {
    const u = grid.toUnsigned();
    const panel_y: f32 = 12;
    const panel_h: f32 = 68;
    const panel_w: f32 = SW - MARGIN * 2;
    const rect = rl.Rectangle{ .x = MARGIN, .y = panel_y, .width = panel_w, .height = panel_h };

    rl.drawRectangleRounded(rect, 0.04, 8, theme.panel_bg);
    rl.drawRectangleRoundedLinesEx(rect, 0.04, 8, 1.0, theme.panel_border);
    const bar_w: i32 = @intFromFloat(panel_w - 4);
    const bar_x: i32 = @intFromFloat(MARGIN + 2);
    const half_w = @divTrunc(bar_w, 2);
    const cyan_clear = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 0 };
    const cyan_mid = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 200 };
    rl.drawRectangleGradientH(bar_x, @intFromFloat(panel_y), half_w, 2, cyan_clear, cyan_mid);
    rl.drawRectangleGradientH(bar_x + half_w, @intFromFloat(panel_y), bar_w - half_w, 2, cyan_mid, cyan_clear);

    const lw = rl.measureText("HEX", 11);
    rl.drawText("HEX", @intFromFloat(MARGIN + (panel_w - @as(f32, @floatFromInt(lw))) * 0.5), @intFromFloat(panel_y + 10), 11, theme.text_dim);

    var hex_buf: [16]u8 = undefined;
    const hex_txt = std.fmt.bufPrintZ(&hex_buf, "0x{X:0>4}", .{@as(u16, @intCast(u & 0xFFFF))}) catch "0x0000";
    const vw = rl.measureText(hex_txt, 36);
    const vx: i32 = @intFromFloat(MARGIN + (panel_w - @as(f32, @floatFromInt(vw))) * 0.5);
    const vy: i32 = @intFromFloat(panel_y + 28);
    const val_glow = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = 30 };
    rl.drawText(hex_txt, vx - 1, vy, 36, val_glow);
    rl.drawText(hex_txt, vx + 1, vy, 36, val_glow);
    rl.drawText(hex_txt, vx, vy, 36, theme.text);
}

// ════════════════════════════════════════════════════════════════
// Secondary readout panels (decimal, signed, bytes)
// ════════════════════════════════════════════════════════════════

fn drawSecondaryPanels(grid: *const BitGrid) void {
    const u = grid.toUnsigned();
    const n = grid.bit_count;

    const sign_mask: u32 = @as(u32, 1) << @intCast(n - 1);
    const s: i64 = if ((u & sign_mask) == 0)
        @intCast(u)
    else
        @as(i64, @intCast(u)) - (@as(i64, 1) << @intCast(n));

    const high_byte: u8 = @intCast((u >> 8) & 0xFF);
    const low_byte: u8 = @intCast(u & 0xFF);

    var dec_buf: [32]u8 = undefined;
    const dec_txt = std.fmt.bufPrintZ(&dec_buf, "{d}", .{u}) catch "0";

    var s_buf: [32]u8 = undefined;
    const s_txt = std.fmt.bufPrintZ(&s_buf, "{d}", .{s}) catch "0";

    var byte_buf: [16]u8 = undefined;
    const byte_txt = std.fmt.bufPrintZ(&byte_buf, "0x{X:0>2} : 0x{X:0>2}", .{ high_byte, low_byte }) catch "0x00 : 0x00";

    const panel_y: f32 = 88;
    const panel_h: f32 = 52;
    const gap: f32 = 12;
    const panel_w: f32 = (SW - MARGIN * 2 - gap * 2) / 3.0;

    const labels = [_][:0]const u8{ "DECIMAL", "SIGNED (2's COMP)", "BYTES (HI : LO)" };
    const values = [_][:0]const u8{ dec_txt, s_txt, byte_txt };

    var p: usize = 0;
    while (p < 3) : (p += 1) {
        const px = MARGIN + @as(f32, @floatFromInt(p)) * (panel_w + gap);
        const rect = rl.Rectangle{ .x = px, .y = panel_y, .width = panel_w, .height = panel_h };

        rl.drawRectangleRounded(rect, 0.08, 8, theme.panel_bg);
        rl.drawRectangleRoundedLinesEx(rect, 0.08, 8, 1.0, theme.panel_border);
        rl.drawRectangle(@intFromFloat(px + 2), @intFromFloat(panel_y), @intFromFloat(panel_w - 4), 2, theme.panel_accent);

        const lw = rl.measureText(labels[p], 10);
        const lx: i32 = @intFromFloat(px + (panel_w - @as(f32, @floatFromInt(lw))) * 0.5);
        rl.drawText(labels[p], lx, @intFromFloat(panel_y + 8), 10, theme.text_dim);

        const vw = rl.measureText(values[p], 24);
        const vx: i32 = @intFromFloat(px + (panel_w - @as(f32, @floatFromInt(vw))) * 0.5);
        const val_glow = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = 25 };
        rl.drawText(values[p], vx - 1, @intFromFloat(panel_y + 24), 24, val_glow);
        rl.drawText(values[p], vx + 1, @intFromFloat(panel_y + 24), 24, val_glow);
        rl.drawText(values[p], vx, @intFromFloat(panel_y + 24), 24, theme.text);
    }
}

// ════════════════════════════════════════════════════════════════
// Binary string (centered, nibble-spaced)
// ════════════════════════════════════════════════════════════════

fn drawBinaryString(grid: *const BitGrid, y: i32) void {
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
        if (i + 1 < grid.bit_count and (i + 1) % 4 != 0) {
            buf[pos] = ' ';
            pos += 1;
        }
    }
    buf[pos] = 0;
    const txt: [:0]const u8 = buf[0..pos :0];

    const tw = rl.measureText(txt, 16);
    const tx: i32 = @divTrunc(SCREEN_W - tw, 2);
    rl.drawText(txt, tx, y, 16, theme.text_binary);
}

// ════════════════════════════════════════════════════════════════
// Nibble labels (4 groups below binary pads)
// ════════════════════════════════════════════════════════════════

fn drawNibbleLabels16(grid: *const BitGrid, y: i32) void {
    if (grid.bit_count < 16) return;
    const u = grid.toUnsigned();
    const nibbles = [4]u8{
        @intCast((u >> 12) & 0xF),
        @intCast((u >> 8) & 0xF),
        @intCast((u >> 4) & 0xF),
        @intCast(u & 0xF),
    };

    var g: usize = 0;
    while (g < 4) : (g += 1) {
        const first = g * 4;
        const last = first + 3;
        const cx = (grid.pads[first].rect.x + grid.pads[last].rect.x + grid.pads[last].rect.width) * 0.5;

        var label_buf: [24]u8 = undefined;
        const txt = std.fmt.bufPrintZ(&label_buf, "NIBBLE {d} (0x{X})", .{ 3 - g, nibbles[g] }) catch "?";
        const tw = rl.measureText(txt, 11);
        rl.drawText(txt, @intFromFloat(cx - @as(f32, @floatFromInt(tw)) * 0.5), y, 11, theme.text_dim);
    }
}

// ════════════════════════════════════════════════════════════════
// Nibble dividers (3 vertical lines at nibble boundaries)
// ════════════════════════════════════════════════════════════════

fn drawNibbleDividers(grid: *const BitGrid) void {
    if (grid.bit_count < 16 or grid.nibble_gap < 2) return;

    var g: usize = 1;
    while (g < 4) : (g += 1) {
        const pad_before = grid.pads[g * 4 - 1].rect;
        const pad_after = grid.pads[g * 4].rect;
        const div_x: i32 = @intFromFloat((pad_before.x + pad_before.width + pad_after.x) * 0.5);
        const top_y: i32 = @intFromFloat(pad_before.y + pad_before.height * 0.1);
        const bot_y: i32 = @intFromFloat(pad_before.y + pad_before.height * 0.9);
        const mid_y = @divTrunc(top_y + bot_y, 2);

        const is_byte_boundary = (g == 2);
        const alpha: u8 = if (is_byte_boundary) 50 else 25;
        const div_clear = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = 0 };
        const div_mid = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = alpha };
        rl.drawRectangleGradientV(div_x, top_y, 1, mid_y - top_y, div_clear, div_mid);
        rl.drawRectangleGradientV(div_x, mid_y, 1, bot_y - mid_y, div_mid, div_clear);

        if (is_byte_boundary) {
            const label = "BYTE";
            const lw = rl.measureText(label, 9);
            rl.drawText(label, div_x - @divTrunc(lw, 2), bot_y + 4, 9, rl.Color{ .r = 0, .g = 229, .b = 255, .a = 60 });
        }
    }
}

// ════════════════════════════════════════════════════════════════
// Hex digit pads (4 pads, one per nibble)
// ════════════════════════════════════════════════════════════════

fn drawHexPads(app: *const App) void {
    const u = app.grid.toUnsigned();
    const pulse = (std.math.sin(app.cursor_time * 2.0) + 1.0) * 0.5;
    const m = rl.getMousePosition();

    var g: usize = 0;
    while (g < 4) : (g += 1) {
        const pad = app.hex_pads[g];
        const r = pad.rect;
        const shift_amt: u5 = @intCast((3 - g) * 4);
        const nibble_val: u4 = @intCast((u >> shift_amt) & 0xF);
        const has_value = nibble_val != 0;
        const is_focused = if (app.hex_cursor) |cur| cur == @as(u2, @intCast(g)) else false;
        const is_hovered = rl.checkCollisionPointRec(m, r);

        // Glow (non-zero nibbles)
        if (has_value) {
            const glow_strength: f32 = if (is_hovered or is_focused) 1.3 else (0.7 + pulse * 0.3);
            ui_draw.glowLayer(r, 10, theme.glow_outer, glow_strength);
            ui_draw.glowLayer(r, 5, theme.glow_mid, glow_strength);
        }

        // 3D depth edge
        const depth: f32 = 3.0;
        const depth_visible = depth * (1.0 - pad.press_t);
        if (depth_visible > 0.5) {
            const depth_r = rl.Rectangle{
                .x = r.x,
                .y = r.y + r.height - depth_visible,
                .width = r.width,
                .height = depth + pad.press_t * 2.0,
            };
            const depth_color = if (has_value) theme.pad_depth_on else theme.pad_depth_off;
            rl.drawRectangleRounded(depth_r, 0.15, 6, depth_color);
        }

        // Pad body
        var body_r = r;
        body_r.y += pad.press_t * 2.0;
        body_r.height = @max(1.0, body_r.height - pad.press_t * 2.0);

        const body_color = if (has_value) theme.pad_on_bg else theme.pad_off_bg;
        rl.drawRectangleRounded(body_r, 0.10, 8, body_color);

        // Border
        const border_color = if (is_hovered or is_focused)
            (if (has_value) theme.pad_on_hover else theme.pad_off_hover)
        else
            (if (has_value) theme.pad_on_border else theme.pad_off_border);
        const border_w: f32 = if (is_focused) 2.5 else if (is_hovered) 2.0 else 1.5;
        rl.drawRectangleRoundedLinesEx(body_r, 0.10, 8, border_w, border_color);

        // Focus cursor (pulsing cyan border)
        if (is_focused) {
            const cursor_alpha: u8 = @intFromFloat(std.math.clamp(
                120.0 + 80.0 * std.math.sin(app.cursor_time * 4.0),
                40.0,
                200.0,
            ));
            rl.drawRectangleRoundedLinesEx(body_r, 0.10, 8, 2.0, rl.Color{
                .r = theme.accent.r,
                .g = theme.accent.g,
                .b = theme.accent.b,
                .a = cursor_alpha,
            });
        }

        // Flash overlay
        if (pad.flash_t > 0.01) {
            const flash_alpha: u8 = @intFromFloat(std.math.clamp(
                @as(f32, @floatFromInt(theme.flash.a)) * pad.flash_t,
                0.0,
                255.0,
            ));
            rl.drawRectangleRounded(body_r, 0.10, 8, rl.Color{
                .r = theme.flash.r,
                .g = theme.flash.g,
                .b = theme.flash.b,
                .a = flash_alpha,
            });
        }

        // Hex digit text (large, centered)
        var hex_char_buf: [2]u8 = undefined;
        const hex_char = std.fmt.bufPrintZ(&hex_char_buf, "{X}", .{nibble_val}) catch "0";
        const font_size: i32 = 30;
        const tw = rl.measureText(hex_char, font_size);
        const tx: i32 = @intFromFloat(body_r.x + (body_r.width - @as(f32, @floatFromInt(tw))) * 0.5);
        const ty: i32 = @intFromFloat(body_r.y + (body_r.height - @as(f32, @floatFromInt(font_size))) * 0.5);

        if (has_value) {
            rl.drawText(hex_char, tx - 1, ty, font_size, theme.text_glow);
            rl.drawText(hex_char, tx + 1, ty, font_size, theme.text_glow);
            rl.drawText(hex_char, tx, ty, font_size, theme.text_on);
        } else {
            rl.drawText(hex_char, tx, ty, font_size, theme.text_off);
        }

        // "0x_" label above pad
        const label = "0x_";
        const lw = rl.measureText(label, 10);
        rl.drawText(label, @intFromFloat(r.x + (r.width - @as(f32, @floatFromInt(lw))) * 0.5), @intFromFloat(r.y - 14), 10, theme.text_dim);
    }
}

// ════════════════════════════════════════════════════════════════
// Hex-binary connection lines (on hover/focus)
// ════════════════════════════════════════════════════════════════

fn drawHexBinaryConnections(app: *const App) void {
    const m = rl.getMousePosition();

    var g: usize = 0;
    while (g < 4) : (g += 1) {
        const hex_pad = app.hex_pads[g];
        const is_hex_hovered = rl.checkCollisionPointRec(m, hex_pad.rect);
        const is_focused = if (app.hex_cursor) |cur| cur == @as(u2, @intCast(g)) else false;

        const first = g * 4;
        var bit_hovered = false;
        var bi: usize = first;
        while (bi < first + 4) : (bi += 1) {
            if (app.grid.hovered != null and app.grid.hovered.? == bi) {
                bit_hovered = true;
            }
        }

        const active = is_hex_hovered or is_focused or bit_hovered;
        if (!active) continue;

        // Connection lines from binary pads to hex pad
        const hex_cx: i32 = @intFromFloat(hex_pad.rect.x + hex_pad.rect.width * 0.5);
        const hex_top: i32 = @intFromFloat(hex_pad.rect.y);
        const line_alpha: u8 = if (is_hex_hovered or is_focused) 60 else 35;
        const line_color = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = line_alpha };

        bi = first;
        while (bi < first + 4) : (bi += 1) {
            const bit_rect = app.grid.pads[bi].rect;
            const bit_cx: i32 = @intFromFloat(bit_rect.x + bit_rect.width * 0.5);
            const bit_bot: i32 = @intFromFloat(bit_rect.y + bit_rect.height);
            rl.drawLine(bit_cx, bit_bot + 2, hex_cx, hex_top - 2, line_color);
        }

        // Highlight the 4 binary pads when hex pad is active
        if (is_hex_hovered or is_focused) {
            bi = first;
            while (bi < first + 4) : (bi += 1) {
                rl.drawRectangleRounded(app.grid.pads[bi].rect, 0.08, 8, rl.Color{
                    .r = theme.accent.r,
                    .g = theme.accent.g,
                    .b = theme.accent.b,
                    .a = 20,
                });
            }
        }

        // Highlight hex pad when a binary pad in the nibble is hovered
        if (bit_hovered and !is_hex_hovered) {
            rl.drawRectangleRounded(hex_pad.rect, 0.10, 8, rl.Color{
                .r = theme.accent.r,
                .g = theme.accent.g,
                .b = theme.accent.b,
                .a = 25,
            });
        }
    }
}

// ════════════════════════════════════════════════════════════════
// Hex input handling (click, scroll, keyboard)
// ════════════════════════════════════════════════════════════════

fn handleHexInput(app: *App) void {
    const m = rl.getMousePosition();
    const wheel = rl.getMouseWheelMove();

    // Mouse interaction on hex pads (process first hovered only)
    var g: usize = 0;
    while (g < 4) : (g += 1) {
        if (!rl.checkCollisionPointRec(m, app.hex_pads[g].rect)) continue;

        const shift: u5 = @intCast((3 - g) * 4);
        var u_val = app.grid.toUnsigned();
        const current: u8 = @intCast((u_val >> shift) & 0xF);
        var changed = false;

        // Left click: increment (wraps F -> 0)
        if (rl.isMouseButtonPressed(.left)) {
            const new_val: u8 = (current + 1) & 0xF;
            u_val = (u_val & ~(@as(u32, 0xF) << shift)) | (@as(u32, new_val) << shift);
            changed = true;
        }

        // Right click: decrement (wraps 0 -> F)
        if (rl.isMouseButtonPressed(.right)) {
            const new_val: u8 = (current -% 1) & 0xF;
            u_val = (u_val & ~(@as(u32, 0xF) << shift)) | (@as(u32, new_val) << shift);
            changed = true;
        }

        // Mouse wheel
        if (wheel > 0.0) {
            const new_val: u8 = (current + 1) & 0xF;
            u_val = (u_val & ~(@as(u32, 0xF) << shift)) | (@as(u32, new_val) << shift);
            changed = true;
        } else if (wheel < 0.0) {
            const new_val: u8 = (current -% 1) & 0xF;
            u_val = (u_val & ~(@as(u32, 0xF) << shift)) | (@as(u32, new_val) << shift);
            changed = true;
        }

        if (changed) {
            app.grid.fromUnsigned(u_val);
            app.hex_pads[g].flash_t = 1.0;
            app.hex_pads[g].press_t = 1.0;
            app.hex_cursor = @intCast(g);
        }
        break; // Only process first hovered hex pad
    }

    // Keyboard navigation: Tab / arrows
    if (rl.isKeyPressed(.tab) or rl.isKeyPressed(.right)) {
        if (app.hex_cursor) |cur| {
            app.hex_cursor = if (cur < 3) cur + 1 else 0;
        } else {
            app.hex_cursor = 0;
        }
    }
    if (rl.isKeyPressed(.left)) {
        if (app.hex_cursor) |cur| {
            app.hex_cursor = if (cur > 0) cur - 1 else 3;
        } else {
            app.hex_cursor = 3;
        }
    }

    // Click outside hex pads: dismiss cursor
    if (rl.isMouseButtonPressed(.left) and app.hex_cursor != null) {
        var over_hex = false;
        var h: usize = 0;
        while (h < 4) : (h += 1) {
            if (rl.checkCollisionPointRec(m, app.hex_pads[h].rect)) {
                over_hex = true;
                break;
            }
        }
        if (!over_hex) app.hex_cursor = null;
    }

    // Backspace: clear focused nibble to 0
    if (rl.isKeyPressed(.backspace)) {
        if (app.hex_cursor) |cur| {
            const shift: u5 = @intCast((3 - @as(usize, cur)) * 4);
            var u_val = app.grid.toUnsigned();
            u_val = u_val & ~(@as(u32, 0xF) << shift);
            app.grid.fromUnsigned(u_val);
            app.hex_pads[cur].flash_t = 1.0;
        }
    }

    // Keyboard hex digit input (0-9, A-F)
    var ch = rl.getCharPressed();
    while (ch != 0) {
        if (charToHexValue(ch)) |val| {
            if (app.hex_cursor == null) {
                app.hex_cursor = 0;
            }
            const cur = app.hex_cursor.?;
            const shift: u5 = @intCast((3 - @as(usize, cur)) * 4);
            var u_val = app.grid.toUnsigned();
            u_val = (u_val & ~(@as(u32, 0xF) << shift)) | (@as(u32, val) << shift);
            app.grid.fromUnsigned(u_val);
            app.hex_pads[cur].flash_t = 1.0;
            app.hex_pads[cur].press_t = 1.0;
            // Auto-advance to next nibble
            if (cur < 3) {
                app.hex_cursor = cur + 1;
            }
        }
        ch = rl.getCharPressed();
    }
}

fn charToHexValue(ch: i32) ?u4 {
    if (ch >= '0' and ch <= '9') return @intCast(ch - '0');
    if (ch >= 'a' and ch <= 'f') return @intCast(ch - 'a' + 10);
    if (ch >= 'A' and ch <= 'F') return @intCast(ch - 'A' + 10);
    return null;
}

// ════════════════════════════════════════════════════════════════
// Hex pad animation tick
// ════════════════════════════════════════════════════════════════

fn tickHexPads(app: *App, dt: f32) void {
    app.cursor_time = @mod(app.cursor_time + dt, std.math.tau);
    var g: usize = 0;
    while (g < 4) : (g += 1) {
        app.hex_pads[g].press_t = animate.decay(app.hex_pads[g].press_t, dt, 8.0);
        app.hex_pads[g].flash_t = animate.decay(app.hex_pads[g].flash_t, dt, 5.0);
    }
}

// ════════════════════════════════════════════════════════════════
// Byte decomposition panel
// ════════════════════════════════════════════════════════════════

fn drawByteDecomposition(grid: *const BitGrid, y: f32) void {
    const u = grid.toUnsigned();
    const high_byte: u8 = @intCast((u >> 8) & 0xFF);
    const low_byte: u8 = @intCast(u & 0xFF);
    const panel_w: f32 = SW - MARGIN * 2;
    const panel_h: f32 = 200;

    ui_draw.glassPanel(MARGIN, y, panel_w, panel_h);

    const half_w: f32 = panel_w * 0.5;
    const col1_x: f32 = MARGIN + 28;
    const col2_x: f32 = MARGIN + half_w + 28;

    // Vertical divider
    const div_x: i32 = @intFromFloat(MARGIN + half_w);
    const div_top: i32 = @intFromFloat(y + 12);
    const div_bot: i32 = @intFromFloat(y + panel_h - 12);
    const div_mid = @divTrunc(div_top + div_bot, 2);
    const dv_clear = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 0 };
    const dv_mid = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 25 };
    rl.drawRectangleGradientV(div_x, div_top, 1, div_mid - div_top, dv_clear, dv_mid);
    rl.drawRectangleGradientV(div_x, div_mid, 1, div_bot - div_mid, dv_mid, dv_clear);

    rl.drawText("HIGH BYTE (bits 15-8)", @intFromFloat(col1_x), @intFromFloat(y + 16), 14, theme.accent);
    drawByteDetail(high_byte, col1_x, y + 38);

    rl.drawText("LOW BYTE (bits 7-0)", @intFromFloat(col2_x), @intFromFloat(y + 16), 14, theme.accent);
    drawByteDetail(low_byte, col2_x, y + 38);

    // Endianness row
    const end_y: f32 = y + panel_h - 38;
    rl.drawText("ENDIANNESS:", @intFromFloat(col1_x), @intFromFloat(end_y), 14, theme.text_dim);

    var be_buf: [16]u8 = undefined;
    const be_txt = std.fmt.bufPrintZ(&be_buf, "Big: {X:0>2} {X:0>2}", .{ high_byte, low_byte }) catch "?";
    rl.drawText(be_txt, @intFromFloat(col1_x + 120), @intFromFloat(end_y), 14, theme.text);

    var le_buf: [16]u8 = undefined;
    const le_txt = std.fmt.bufPrintZ(&le_buf, "Little: {X:0>2} {X:0>2}", .{ low_byte, high_byte }) catch "?";
    rl.drawText(le_txt, @intFromFloat(col1_x + 280), @intFromFloat(end_y), 14, theme.text);

    // ASCII preview
    rl.drawText("ASCII:", @intFromFloat(col2_x), @intFromFloat(end_y), 14, theme.text_dim);
    var ascii_buf: [8]u8 = undefined;
    const hi_ch: u8 = if (high_byte >= 0x20 and high_byte <= 0x7E) high_byte else '.';
    const lo_ch: u8 = if (low_byte >= 0x20 and low_byte <= 0x7E) low_byte else '.';
    const ascii_txt = std.fmt.bufPrintZ(&ascii_buf, "'{c}{c}'", .{ hi_ch, lo_ch }) catch "?";
    rl.drawText(ascii_txt, @intFromFloat(col2_x + 64), @intFromFloat(end_y), 14, theme.text_binary);
}

fn drawByteDetail(byte: u8, x: f32, y: f32) void {
    const label_sz: i32 = 14;
    const val_sz: i32 = 14;
    const val_offset: f32 = 72;
    const row_h: f32 = 26;

    rl.drawText("Binary:", @intFromFloat(x), @intFromFloat(y), label_sz, theme.text_dim);
    var bin_buf: [12]u8 = undefined;
    const bin_txt = std.fmt.bufPrintZ(&bin_buf, "{b:0>4} {b:0>4}", .{ (byte >> 4) & 0xF, byte & 0xF }) catch "?";
    rl.drawText(bin_txt, @intFromFloat(x + val_offset), @intFromFloat(y), val_sz, theme.text_binary);

    rl.drawText("Hex:", @intFromFloat(x), @intFromFloat(y + row_h), label_sz, theme.text_dim);
    var hex_buf: [8]u8 = undefined;
    const hex_txt = std.fmt.bufPrintZ(&hex_buf, "0x{X:0>2}", .{byte}) catch "0x00";
    const hex_glow = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = 25 };
    const hex_x: i32 = @intFromFloat(x + val_offset);
    rl.drawText(hex_txt, hex_x - 1, @intFromFloat(y + row_h), val_sz, hex_glow);
    rl.drawText(hex_txt, hex_x + 1, @intFromFloat(y + row_h), val_sz, hex_glow);
    rl.drawText(hex_txt, @intFromFloat(x + val_offset), @intFromFloat(y + row_h), val_sz, theme.text);

    rl.drawText("Dec:", @intFromFloat(x), @intFromFloat(y + row_h * 2), label_sz, theme.text_dim);
    var dec_buf: [8]u8 = undefined;
    const dec_txt = std.fmt.bufPrintZ(&dec_buf, "{d}", .{byte}) catch "0";
    rl.drawText(dec_txt, @intFromFloat(x + val_offset), @intFromFloat(y + row_h * 2), val_sz, theme.text);

    const signed_val: i8 = @bitCast(byte);
    rl.drawText("Signed:", @intFromFloat(x), @intFromFloat(y + row_h * 3), label_sz, theme.text_dim);
    var s_buf: [8]u8 = undefined;
    const s_txt = std.fmt.bufPrintZ(&s_buf, "{d}", .{signed_val}) catch "0";
    rl.drawText(s_txt, @intFromFloat(x + val_offset), @intFromFloat(y + row_h * 3), val_sz, theme.text);
}

// ════════════════════════════════════════════════════════════════
// Separator line
// ════════════════════════════════════════════════════════════════

fn drawSeparator(y: i32) void {
    const margin: i32 = 40;
    const mid = @divTrunc(SCREEN_W, 2);
    const sep_clear = rl.Color{ .r = theme.separator.r, .g = theme.separator.g, .b = theme.separator.b, .a = 0 };
    rl.drawRectangleGradientH(margin, y, mid - margin, 1, sep_clear, theme.separator);
    rl.drawRectangleGradientH(mid, y, SCREEN_W - margin - mid, 1, theme.separator, sep_clear);
}

// ════════════════════════════════════════════════════════════════
// Help text
// ════════════════════════════════════════════════════════════════

fn drawHelpText(y_start: i32) void {
    const line_h: i32 = 20;
    var y = y_start;

    rl.drawText(">", 36, y, 16, theme.accent);
    rl.drawText("Click bits to toggle  |  Leftmost = sign bit (b15)", 56, y, 16, theme.text_help);
    y += line_h;

    rl.drawText(">", 36, y, 16, theme.accent);
    rl.drawText("Hex pads: Left-click +1, Right-click -1, Scroll to cycle 0-F", 56, y, 16, theme.text_help);
    y += line_h;

    rl.drawText(">", 36, y, 16, theme.accent);
    rl.drawText("Type 0-9 / A-F to input hex digits  |  Tab/Arrows move cursor", 56, y, 16, theme.text_help);
    y += line_h;

    rl.drawText(">", 36, y, 16, theme.accent);
    rl.drawText("Backspace clears nibble  |  Hover hex pad to see bit connection", 56, y, 16, theme.text_help);
    y += line_h + 6;

    rl.drawText(">", 36, y, 16, theme.accent);
    rl.drawText("Try: type 'CAFE' -> 0xCAFE = 51966 decimal", 56, y, 16, theme.text_help);
    y += line_h;

    rl.drawText(">", 36, y, 16, theme.accent);
    rl.drawText("Try: 0xFF00 -> high byte only -> notice endian order", 56, y, 16, theme.text_help);
}

// ════════════════════════════════════════════════════════════════
// Entry point
// ════════════════════════════════════════════════════════════════

pub fn runHexPiano() !void {
    rl.initWindow(SCREEN_W, SCREEN_H, "Hex Piano");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var app: App = .{ .grid = BitGrid.init(16) };
    app.grid.pad_height = PAD_H;
    app.grid.nibble_gap = 20;
    app.grid.layout(SCREEN_W, PAD_Y);
    layoutHexPads(&app);

    const pad_bottom_y: i32 = @intFromFloat(PAD_BOTTOM);
    const hex_off: i32 = @intFromFloat(HEX_SECTION_EXTRA);

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        // Input
        app.grid.handleInput();
        handleHexInput(&app);

        // Bidirectional sync: binary toggle -> hex pad flash
        if (app.grid.just_toggled) |toggled_bit| {
            const nibble_index = toggled_bit / 4;
            app.hex_pads[nibble_index].flash_t = 0.6;
        }

        // Animation
        app.grid.tick(dt);
        tickHexPads(&app, dt);

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        theme.drawBackground(SCREEN_W, SCREEN_H);
        theme.drawVignette(SCREEN_W, SCREEN_H);

        drawHexHeroPanel(&app.grid);
        drawSecondaryPanels(&app.grid);
        drawBinaryString(&app.grid, 148);
        app.grid.draw();
        drawNibbleDividers(&app.grid);
        drawNibbleLabels16(&app.grid, pad_bottom_y + 2);
        drawHexBinaryConnections(&app);
        drawHexPads(&app);
        drawSeparator(pad_bottom_y + 32 + hex_off);
        drawByteDecomposition(&app.grid, @as(f32, @floatFromInt(pad_bottom_y + 42 + hex_off)));
        drawSeparator(pad_bottom_y + 250 + hex_off);
        drawHelpText(pad_bottom_y + 264 + hex_off);

        theme.drawScanlines(SCREEN_W, SCREEN_H);
    }
}
