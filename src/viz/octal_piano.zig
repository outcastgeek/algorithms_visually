//! Octal Piano -- interactive 12-bit binary number pad with octal digit input.
//! Clickable bits with octal-forward readouts, octal digit pads for 3-bit group
//! manipulation, cross-base comparison panel, and digit mapping display.
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

const SCREEN_W: i32 = 1200;
const SCREEN_H: i32 = 800;
const MARGIN: f32 = 28;
const SW: f32 = @floatFromInt(SCREEN_W);

const PAD_Y: f32 = 168;
const PAD_H: f32 = 96;
const PAD_BOTTOM: f32 = PAD_Y + PAD_H; // 264
const OCT_PAD_Y: f32 = PAD_BOTTOM + 26; // 290
const OCT_PAD_H: f32 = 56;
const OCT_SECTION_EXTRA: f32 = OCT_PAD_H + 12; // 68

const NUM_BITS: usize = 12;
const BITS_PER_DIGIT: usize = 3;
const NUM_OCT_DIGITS: usize = NUM_BITS / BITS_PER_DIGIT; // 4

// ════════════════════════════════════════════════════════════════
// Octal pad state
// ════════════════════════════════════════════════════════════════

const OctPad = struct {
    rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    flash_t: f32 = 0.0,
    press_t: f32 = 0.0,
};

// ════════════════════════════════════════════════════════════════
// App state
// ════════════════════════════════════════════════════════════════

const App = struct {
    grid: BitGrid,
    oct_pads: [NUM_OCT_DIGITS]OctPad = [_]OctPad{.{}} ** NUM_OCT_DIGITS,
    /// Which octal digit (0-3, MSB to LSB) has keyboard focus. null = none.
    oct_cursor: ?u2 = null,
    cursor_time: f32 = 0.0,
};

// ════════════════════════════════════════════════════════════════
// Octal pad layout
// ════════════════════════════════════════════════════════════════

fn layoutOctPads(app: *App) void {
    const oct_pad_w: f32 = 80;
    var g: usize = 0;
    while (g < NUM_OCT_DIGITS) : (g += 1) {
        const first = g * BITS_PER_DIGIT;
        const last = first + BITS_PER_DIGIT - 1;
        const cx = (app.grid.pads[first].rect.x +
            app.grid.pads[last].rect.x +
            app.grid.pads[last].rect.width) * 0.5;
        app.oct_pads[g].rect = .{
            .x = cx - oct_pad_w * 0.5,
            .y = OCT_PAD_Y,
            .width = oct_pad_w,
            .height = OCT_PAD_H,
        };
    }
}

// ════════════════════════════════════════════════════════════════
// Octal hero panel (large centered octal value at top)
// ════════════════════════════════════════════════════════════════

fn drawOctalHeroPanel(grid: *const BitGrid) void {
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

    const lw = rl.measureText("OCTAL", 11);
    rl.drawText("OCTAL", @intFromFloat(MARGIN + (panel_w - @as(f32, @floatFromInt(lw))) * 0.5), @intFromFloat(panel_y + 10), 11, theme.text_dim);

    // Format as 0oNNNN (4 octal digits)
    var oct_buf: [8]u8 = undefined;
    const oct_txt = formatOctal(u, &oct_buf);
    const vw = rl.measureText(oct_txt, 36);
    const vx: i32 = @intFromFloat(MARGIN + (panel_w - @as(f32, @floatFromInt(vw))) * 0.5);
    const vy: i32 = @intFromFloat(panel_y + 28);
    const val_glow = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = 30 };
    rl.drawText(oct_txt, vx - 1, vy, 36, val_glow);
    rl.drawText(oct_txt, vx + 1, vy, 36, val_glow);
    rl.drawText(oct_txt, vx, vy, 36, theme.text);
}

/// Format a value as "0oNNNN" (4 octal digits, zero-padded).
fn formatOctal(value: u32, buf: *[8]u8) [:0]const u8 {
    buf[0] = '0';
    buf[1] = 'o';
    var i: usize = 0;
    while (i < NUM_OCT_DIGITS) : (i += 1) {
        const shift: u5 = @intCast((NUM_OCT_DIGITS - 1 - i) * BITS_PER_DIGIT);
        const digit: u3 = @intCast((value >> shift) & 0o7);
        buf[2 + i] = '0' + @as(u8, digit);
    }
    buf[2 + NUM_OCT_DIGITS] = 0;
    return buf[0 .. 2 + NUM_OCT_DIGITS :0];
}

// ════════════════════════════════════════════════════════════════
// Secondary readout panels (decimal, signed, hex)
// ════════════════════════════════════════════════════════════════

fn drawSecondaryPanels(grid: *const BitGrid) void {
    const u = grid.toUnsigned();
    const n = grid.bit_count;

    const sign_mask: u32 = @as(u32, 1) << @intCast(n - 1);
    const s: i64 = if ((u & sign_mask) == 0)
        @intCast(u)
    else
        @as(i64, @intCast(u)) - (@as(i64, 1) << @intCast(n));

    var dec_buf: [32]u8 = undefined;
    const dec_txt = std.fmt.bufPrintZ(&dec_buf, "{d}", .{u}) catch "0";

    var s_buf: [32]u8 = undefined;
    const s_txt = std.fmt.bufPrintZ(&s_buf, "{d}", .{s}) catch "0";

    // 12 bits = 3 hex digits
    var hex_buf: [16]u8 = undefined;
    const hex_txt = std.fmt.bufPrintZ(&hex_buf, "0x{X:0>3}", .{@as(u16, @intCast(u & 0xFFF))}) catch "0x000";

    const panel_y: f32 = 88;
    const panel_h: f32 = 52;
    const gap: f32 = 12;
    const panel_w: f32 = (SW - MARGIN * 2 - gap * 2) / 3.0;

    const labels = [_][:0]const u8{ "DECIMAL", "SIGNED (2's COMP)", "HEX" };
    const values = [_][:0]const u8{ dec_txt, s_txt, hex_txt };

    var p: usize = 0;
    while (p < 3) : (p += 1) {
        const px = MARGIN + @as(f32, @floatFromInt(p)) * (panel_w + gap);
        const rect = rl.Rectangle{ .x = px, .y = panel_y, .width = panel_w, .height = panel_h };

        rl.drawRectangleRounded(rect, 0.08, 8, theme.panel_bg);
        rl.drawRectangleRoundedLinesEx(rect, 0.08, 8, 1.0, theme.panel_border);
        rl.drawRectangle(@intFromFloat(px + 2), @intFromFloat(panel_y), @intFromFloat(panel_w - 4), 2, theme.panel_accent);

        const label_w = rl.measureText(labels[p], 10);
        const lx: i32 = @intFromFloat(px + (panel_w - @as(f32, @floatFromInt(label_w))) * 0.5);
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
// Binary string (centered, 3-bit grouped)
// ════════════════════════════════════════════════════════════════

fn drawBinaryString(grid: *const BitGrid, y: i32) void {
    var buf: [72]u8 = undefined;
    var pos: usize = 0;
    var i: usize = 0;
    while (i < grid.bit_count) : (i += 1) {
        // Double space between 3-bit groups
        if (i > 0 and i % BITS_PER_DIGIT == 0) {
            buf[pos] = ' ';
            pos += 1;
            buf[pos] = ' ';
            pos += 1;
        }
        buf[pos] = if (grid.bits[i]) '1' else '0';
        pos += 1;
        // Single space between bits within a group
        if (i + 1 < grid.bit_count and (i + 1) % BITS_PER_DIGIT != 0) {
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
// Octal digit labels (4 groups below binary pads)
// ════════════════════════════════════════════════════════════════

fn drawOctalLabels(grid: *const BitGrid, y: i32) void {
    const u = grid.toUnsigned();
    var g: usize = 0;
    while (g < NUM_OCT_DIGITS) : (g += 1) {
        const shift: u5 = @intCast((NUM_OCT_DIGITS - 1 - g) * BITS_PER_DIGIT);
        const digit: u3 = @intCast((u >> shift) & 0o7);
        const first = g * BITS_PER_DIGIT;
        const last = first + BITS_PER_DIGIT - 1;
        const cx = (grid.pads[first].rect.x + grid.pads[last].rect.x + grid.pads[last].rect.width) * 0.5;

        var label_buf: [24]u8 = undefined;
        const txt = std.fmt.bufPrintZ(&label_buf, "DIGIT {d} (0o{d})", .{ NUM_OCT_DIGITS - 1 - g, digit }) catch "?";
        const tw = rl.measureText(txt, 11);
        rl.drawText(txt, @intFromFloat(cx - @as(f32, @floatFromInt(tw)) * 0.5), y, 11, theme.text_dim);
    }
}

// ════════════════════════════════════════════════════════════════
// Octal dividers (3 vertical lines at 3-bit boundaries)
// ════════════════════════════════════════════════════════════════

fn drawOctalDividers(grid: *const BitGrid) void {
    if (grid.bit_count < NUM_BITS or grid.nibble_gap < 2) return;

    var g: usize = 1;
    while (g < NUM_OCT_DIGITS) : (g += 1) {
        const pad_before = grid.pads[g * BITS_PER_DIGIT - 1].rect;
        const pad_after = grid.pads[g * BITS_PER_DIGIT].rect;
        const div_x: i32 = @intFromFloat((pad_before.x + pad_before.width + pad_after.x) * 0.5);
        const top_y: i32 = @intFromFloat(pad_before.y + pad_before.height * 0.1);
        const bot_y: i32 = @intFromFloat(pad_before.y + pad_before.height * 0.9);
        const mid_y = @divTrunc(top_y + bot_y, 2);

        const alpha: u8 = 35;
        const div_clear = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = 0 };
        const div_mid = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = alpha };
        rl.drawRectangleGradientV(div_x, top_y, 1, mid_y - top_y, div_clear, div_mid);
        rl.drawRectangleGradientV(div_x, mid_y, 1, bot_y - mid_y, div_mid, div_clear);
    }
}

// ════════════════════════════════════════════════════════════════
// Octal digit pads (4 pads, one per 3-bit group)
// ════════════════════════════════════════════════════════════════

fn drawOctPads(app: *const App) void {
    const u = app.grid.toUnsigned();
    const pulse = (std.math.sin(app.cursor_time * 2.0) + 1.0) * 0.5;
    const m = rl.getMousePosition();

    var g: usize = 0;
    while (g < NUM_OCT_DIGITS) : (g += 1) {
        const pad = app.oct_pads[g];
        const r = pad.rect;
        const shift_amt: u5 = @intCast((NUM_OCT_DIGITS - 1 - g) * BITS_PER_DIGIT);
        const digit_val: u3 = @intCast((u >> shift_amt) & 0o7);
        const has_value = digit_val != 0;
        const is_focused = if (app.oct_cursor) |cur| cur == @as(u2, @intCast(g)) else false;
        const is_hovered = rl.checkCollisionPointRec(m, r);

        // Glow (non-zero digits)
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

        // Octal digit text (large, centered)
        var digit_char_buf: [2]u8 = undefined;
        digit_char_buf[0] = '0' + @as(u8, digit_val);
        digit_char_buf[1] = 0;
        const digit_char: [:0]const u8 = digit_char_buf[0..1 :0];
        const font_size: i32 = 30;
        const tw = rl.measureText(digit_char, font_size);
        const tx: i32 = @intFromFloat(body_r.x + (body_r.width - @as(f32, @floatFromInt(tw))) * 0.5);
        const ty: i32 = @intFromFloat(body_r.y + (body_r.height - @as(f32, @floatFromInt(font_size))) * 0.5);

        if (has_value) {
            rl.drawText(digit_char, tx - 1, ty, font_size, theme.text_glow);
            rl.drawText(digit_char, tx + 1, ty, font_size, theme.text_glow);
            rl.drawText(digit_char, tx, ty, font_size, theme.text_on);
        } else {
            rl.drawText(digit_char, tx, ty, font_size, theme.text_off);
        }

        // "0o_" label above pad
        const label = "0o_";
        const lw = rl.measureText(label, 10);
        rl.drawText(label, @intFromFloat(r.x + (r.width - @as(f32, @floatFromInt(lw))) * 0.5), @intFromFloat(r.y - 14), 10, theme.text_dim);
    }
}

// ════════════════════════════════════════════════════════════════
// Octal-binary connection lines (on hover/focus)
// ════════════════════════════════════════════════════════════════

fn drawOctBinaryConnections(app: *const App) void {
    const m = rl.getMousePosition();

    var g: usize = 0;
    while (g < NUM_OCT_DIGITS) : (g += 1) {
        const oct_pad = app.oct_pads[g];
        const is_oct_hovered = rl.checkCollisionPointRec(m, oct_pad.rect);
        const is_focused = if (app.oct_cursor) |cur| cur == @as(u2, @intCast(g)) else false;

        const first = g * BITS_PER_DIGIT;
        var bit_hovered = false;
        var bi: usize = first;
        while (bi < first + BITS_PER_DIGIT) : (bi += 1) {
            if (app.grid.hovered != null and app.grid.hovered.? == bi) {
                bit_hovered = true;
            }
        }

        const active = is_oct_hovered or is_focused or bit_hovered;
        if (!active) continue;

        // Connection lines from binary pads to octal pad
        const oct_cx: i32 = @intFromFloat(oct_pad.rect.x + oct_pad.rect.width * 0.5);
        const oct_top: i32 = @intFromFloat(oct_pad.rect.y);
        const line_alpha: u8 = if (is_oct_hovered or is_focused) 60 else 35;
        const line_color = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = line_alpha };

        bi = first;
        while (bi < first + BITS_PER_DIGIT) : (bi += 1) {
            const bit_rect = app.grid.pads[bi].rect;
            const bit_cx: i32 = @intFromFloat(bit_rect.x + bit_rect.width * 0.5);
            const bit_bot: i32 = @intFromFloat(bit_rect.y + bit_rect.height);
            rl.drawLine(bit_cx, bit_bot + 2, oct_cx, oct_top - 2, line_color);
        }

        // Highlight the 3 binary pads when octal pad is active
        if (is_oct_hovered or is_focused) {
            bi = first;
            while (bi < first + BITS_PER_DIGIT) : (bi += 1) {
                rl.drawRectangleRounded(app.grid.pads[bi].rect, 0.08, 8, rl.Color{
                    .r = theme.accent.r,
                    .g = theme.accent.g,
                    .b = theme.accent.b,
                    .a = 20,
                });
            }
        }

        // Highlight octal pad when a binary pad in the group is hovered
        if (bit_hovered and !is_oct_hovered) {
            rl.drawRectangleRounded(oct_pad.rect, 0.10, 8, rl.Color{
                .r = theme.accent.r,
                .g = theme.accent.g,
                .b = theme.accent.b,
                .a = 25,
            });
        }
    }
}

// ════════════════════════════════════════════════════════════════
// Octal input handling (click, scroll, keyboard)
// ════════════════════════════════════════════════════════════════

fn handleOctInput(app: *App) void {
    const m = rl.getMousePosition();
    const wheel = rl.getMouseWheelMove();

    // Mouse interaction on octal pads (process first hovered only)
    var g: usize = 0;
    while (g < NUM_OCT_DIGITS) : (g += 1) {
        if (!rl.checkCollisionPointRec(m, app.oct_pads[g].rect)) continue;

        const shift: u5 = @intCast((NUM_OCT_DIGITS - 1 - g) * BITS_PER_DIGIT);
        var u_val = app.grid.toUnsigned();
        const current: u8 = @intCast((u_val >> shift) & 0o7);
        var changed = false;

        // Left click: increment (wraps 7 -> 0)
        if (rl.isMouseButtonPressed(.left)) {
            const new_val: u8 = (current + 1) & 0x7;
            u_val = (u_val & ~(@as(u32, 0x7) << shift)) | (@as(u32, new_val) << shift);
            changed = true;
        }

        // Right click: decrement (wraps 0 -> 7)
        if (rl.isMouseButtonPressed(.right)) {
            const new_val: u8 = (current -% 1) & 0x7;
            u_val = (u_val & ~(@as(u32, 0x7) << shift)) | (@as(u32, new_val) << shift);
            changed = true;
        }

        // Mouse wheel
        if (wheel > 0.0) {
            const new_val: u8 = (current + 1) & 0x7;
            u_val = (u_val & ~(@as(u32, 0x7) << shift)) | (@as(u32, new_val) << shift);
            changed = true;
        } else if (wheel < 0.0) {
            const new_val: u8 = (current -% 1) & 0x7;
            u_val = (u_val & ~(@as(u32, 0x7) << shift)) | (@as(u32, new_val) << shift);
            changed = true;
        }

        if (changed) {
            app.grid.fromUnsigned(u_val);
            app.oct_pads[g].flash_t = 1.0;
            app.oct_pads[g].press_t = 1.0;
            app.oct_cursor = @intCast(g);
        }
        break; // Only process first hovered octal pad
    }

    // Keyboard navigation: Tab / arrows
    if (rl.isKeyPressed(.tab) or rl.isKeyPressed(.right)) {
        if (app.oct_cursor) |cur| {
            app.oct_cursor = if (cur < NUM_OCT_DIGITS - 1) cur + 1 else 0;
        } else {
            app.oct_cursor = 0;
        }
    }
    if (rl.isKeyPressed(.left)) {
        if (app.oct_cursor) |cur| {
            app.oct_cursor = if (cur > 0) cur - 1 else NUM_OCT_DIGITS - 1;
        } else {
            app.oct_cursor = NUM_OCT_DIGITS - 1;
        }
    }

    // Click outside octal pads: dismiss cursor
    if (rl.isMouseButtonPressed(.left) and app.oct_cursor != null) {
        var over_oct = false;
        var h: usize = 0;
        while (h < NUM_OCT_DIGITS) : (h += 1) {
            if (rl.checkCollisionPointRec(m, app.oct_pads[h].rect)) {
                over_oct = true;
                break;
            }
        }
        if (!over_oct) app.oct_cursor = null;
    }

    // Backspace: clear focused digit to 0
    if (rl.isKeyPressed(.backspace)) {
        if (app.oct_cursor) |cur| {
            const shift: u5 = @intCast((NUM_OCT_DIGITS - 1 - @as(usize, cur)) * BITS_PER_DIGIT);
            var u_val = app.grid.toUnsigned();
            u_val = u_val & ~(@as(u32, 0x7) << shift);
            app.grid.fromUnsigned(u_val);
            app.oct_pads[cur].flash_t = 1.0;
        }
    }

    // Keyboard octal digit input (0-7)
    var ch = rl.getCharPressed();
    while (ch != 0) {
        if (charToOctValue(ch)) |val| {
            if (app.oct_cursor == null) {
                app.oct_cursor = 0;
            }
            const cur = app.oct_cursor.?;
            const shift: u5 = @intCast((NUM_OCT_DIGITS - 1 - @as(usize, cur)) * BITS_PER_DIGIT);
            var u_val = app.grid.toUnsigned();
            u_val = (u_val & ~(@as(u32, 0x7) << shift)) | (@as(u32, val) << shift);
            app.grid.fromUnsigned(u_val);
            app.oct_pads[cur].flash_t = 1.0;
            app.oct_pads[cur].press_t = 1.0;
            // Auto-advance to next digit
            if (cur < NUM_OCT_DIGITS - 1) {
                app.oct_cursor = cur + 1;
            }
        }
        ch = rl.getCharPressed();
    }
}

fn charToOctValue(ch: i32) ?u3 {
    if (ch >= '0' and ch <= '7') return @intCast(ch - '0');
    return null;
}

// ════════════════════════════════════════════════════════════════
// Octal pad animation tick
// ════════════════════════════════════════════════════════════════

fn tickOctPads(app: *App, dt: f32) void {
    app.cursor_time = @mod(app.cursor_time + dt, std.math.tau);
    var g: usize = 0;
    while (g < NUM_OCT_DIGITS) : (g += 1) {
        app.oct_pads[g].press_t = animate.decay(app.oct_pads[g].press_t, dt, 8.0);
        app.oct_pads[g].flash_t = animate.decay(app.oct_pads[g].flash_t, dt, 5.0);
    }
}

// ════════════════════════════════════════════════════════════════
// Octal digit mapping + cross-base comparison panel
// ════════════════════════════════════════════════════════════════

fn drawOctalDecomposition(grid: *const BitGrid, y: f32) void {
    const u = grid.toUnsigned();
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

    // ── Left column: Octal Digit Mapping ──
    rl.drawText("OCTAL DIGIT MAPPING", @intFromFloat(col1_x), @intFromFloat(y + 16), 14, theme.accent);

    const row_h: f32 = 26;
    const label_sz: i32 = 14;
    var g: usize = 0;
    while (g < NUM_OCT_DIGITS) : (g += 1) {
        const digit_idx = NUM_OCT_DIGITS - 1 - g; // digit 3 first, digit 0 last
        const shift: u5 = @intCast(digit_idx * BITS_PER_DIGIT);
        const digit_val: u3 = @intCast((u >> shift) & 0o7);
        const high_bit = digit_idx * BITS_PER_DIGIT + BITS_PER_DIGIT - 1;
        const low_bit = digit_idx * BITS_PER_DIGIT;

        // Extract the 3 bits for this digit
        const b2: u1 = @intCast((u >> @intCast(high_bit)) & 1);
        const b1: u1 = @intCast((u >> @intCast(high_bit - 1)) & 1);
        const b0: u1 = @intCast((u >> @intCast(low_bit)) & 1);

        var row_buf: [48]u8 = undefined;
        const row_txt = std.fmt.bufPrintZ(&row_buf, "Digit {d}: b{d}-b{d} = {d}{d}{d} = 0o{d}", .{
            digit_idx, high_bit, low_bit, b2, b1, b0, digit_val,
        }) catch "?";

        const row_y: f32 = y + 40 + @as(f32, @floatFromInt(g)) * row_h;
        rl.drawText(row_txt, @intFromFloat(col1_x), @intFromFloat(row_y), label_sz, theme.text);
    }

    // Note at bottom of left column
    const note_y: f32 = y + 40 + @as(f32, @floatFromInt(NUM_OCT_DIGITS)) * row_h + 8;
    rl.drawText("Each octal digit = exactly 3 bits", @intFromFloat(col1_x), @intFromFloat(note_y), 12, theme.text_dim);

    // ── Right column: Cross-Base Comparison ──
    rl.drawText("CROSS-BASE COMPARISON", @intFromFloat(col2_x), @intFromFloat(y + 16), 14, theme.accent);

    const val_offset: f32 = 80;
    var base_y: f32 = y + 40;

    // Binary (grouped by 3)
    rl.drawText("Binary:", @intFromFloat(col2_x), @intFromFloat(base_y), label_sz, theme.text_dim);
    var bin_buf: [24]u8 = undefined;
    var bin_pos: usize = 0;
    var bi: usize = 0;
    while (bi < NUM_BITS) : (bi += 1) {
        if (bi > 0 and bi % BITS_PER_DIGIT == 0) {
            bin_buf[bin_pos] = ' ';
            bin_pos += 1;
        }
        const bit_idx = NUM_BITS - 1 - bi;
        bin_buf[bin_pos] = if (((u >> @intCast(bit_idx)) & 1) == 1) '1' else '0';
        bin_pos += 1;
    }
    bin_buf[bin_pos] = 0;
    const bin_txt: [:0]const u8 = bin_buf[0..bin_pos :0];
    rl.drawText(bin_txt, @intFromFloat(col2_x + val_offset), @intFromFloat(base_y), label_sz, theme.text_binary);

    base_y += row_h;

    // Octal
    rl.drawText("Octal:", @intFromFloat(col2_x), @intFromFloat(base_y), label_sz, theme.text_dim);
    var oct_fmt_buf: [8]u8 = undefined;
    const oct_txt = formatOctal(u, &oct_fmt_buf);
    const oct_glow = rl.Color{ .r = theme.accent.r, .g = theme.accent.g, .b = theme.accent.b, .a = 25 };
    const oct_x: i32 = @intFromFloat(col2_x + val_offset);
    rl.drawText(oct_txt, oct_x - 1, @intFromFloat(base_y), label_sz, oct_glow);
    rl.drawText(oct_txt, oct_x + 1, @intFromFloat(base_y), label_sz, oct_glow);
    rl.drawText(oct_txt, oct_x, @intFromFloat(base_y), label_sz, theme.text);

    base_y += row_h;

    // Hex
    rl.drawText("Hex:", @intFromFloat(col2_x), @intFromFloat(base_y), label_sz, theme.text_dim);
    var hex_buf: [8]u8 = undefined;
    const hex_txt = std.fmt.bufPrintZ(&hex_buf, "0x{X:0>3}", .{@as(u16, @intCast(u & 0xFFF))}) catch "0x000";
    rl.drawText(hex_txt, @intFromFloat(col2_x + val_offset), @intFromFloat(base_y), label_sz, theme.text);

    base_y += row_h;

    // Decimal
    rl.drawText("Decimal:", @intFromFloat(col2_x), @intFromFloat(base_y), label_sz, theme.text_dim);
    var dec_buf: [16]u8 = undefined;
    const dec_txt = std.fmt.bufPrintZ(&dec_buf, "{d}", .{u}) catch "0";
    rl.drawText(dec_txt, @intFromFloat(col2_x + val_offset), @intFromFloat(base_y), label_sz, theme.text);

    base_y += row_h + 8;

    // Note comparing groupings
    rl.drawText("12 bits = 4 octal digits = 3 hex digits", @intFromFloat(col2_x), @intFromFloat(base_y), 12, theme.text_dim);
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
    rl.drawText("Click bits to toggle  |  Leftmost = sign bit (b11)", 56, y, 16, theme.text_help);
    y += line_h;

    rl.drawText(">", 36, y, 16, theme.accent);
    rl.drawText("Octal pads: Left-click +1, Right-click -1, Scroll to cycle 0-7", 56, y, 16, theme.text_help);
    y += line_h;

    rl.drawText(">", 36, y, 16, theme.accent);
    rl.drawText("Type 0-7 to input octal digits  |  Tab/Arrows move cursor", 56, y, 16, theme.text_help);
    y += line_h;

    rl.drawText(">", 36, y, 16, theme.accent);
    rl.drawText("Backspace clears digit  |  Hover octal pad to see bit connection", 56, y, 16, theme.text_help);
    y += line_h + 6;

    rl.drawText(">", 36, y, 16, theme.accent);
    rl.drawText("Try: type '7777' -> 0o7777 = 4095 decimal = 0xFFF hex", 56, y, 16, theme.text_help);
    y += line_h;

    rl.drawText(">", 36, y, 16, theme.accent);
    rl.drawText("Note: each octal digit = exactly 3 bits (vs hex = 4 bits)", 56, y, 16, theme.text_help);
}

// ════════════════════════════════════════════════════════════════
// Entry point
// ════════════════════════════════════════════════════════════════

pub fn runOctalPiano() !void {
    rl.initWindow(SCREEN_W, SCREEN_H, "Octal Piano");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var app: App = .{ .grid = BitGrid.init(NUM_BITS) };
    app.grid.pad_height = PAD_H;
    app.grid.group_size = BITS_PER_DIGIT; // 3-bit grouping for octal
    app.grid.nibble_gap = 20;
    app.grid.layout(SCREEN_W, PAD_Y);
    layoutOctPads(&app);

    const pad_bottom_y: i32 = @intFromFloat(PAD_BOTTOM);
    const oct_off: i32 = @intFromFloat(OCT_SECTION_EXTRA);

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        // Input
        app.grid.handleInput();
        handleOctInput(&app);

        // Bidirectional sync: binary toggle -> octal pad flash
        if (app.grid.just_toggled) |toggled_bit| {
            const digit_index = toggled_bit / BITS_PER_DIGIT;
            app.oct_pads[digit_index].flash_t = 0.6;
        }

        // Animation
        app.grid.tick(dt);
        tickOctPads(&app, dt);

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        theme.drawBackground(SCREEN_W, SCREEN_H);
        theme.drawVignette(SCREEN_W, SCREEN_H);

        drawOctalHeroPanel(&app.grid);
        drawSecondaryPanels(&app.grid);
        drawBinaryString(&app.grid, 148);
        app.grid.draw();
        drawOctalDividers(&app.grid);
        drawOctalLabels(&app.grid, pad_bottom_y + 2);
        drawOctBinaryConnections(&app);
        drawOctPads(&app);
        drawSeparator(pad_bottom_y + 32 + oct_off);
        drawOctalDecomposition(&app.grid, @as(f32, @floatFromInt(pad_bottom_y + 42 + oct_off)));
        drawSeparator(pad_bottom_y + 250 + oct_off);
        drawHelpText(pad_bottom_y + 264 + oct_off);

        theme.drawScanlines(SCREEN_W, SCREEN_H);
    }
}
