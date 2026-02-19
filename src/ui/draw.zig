//! Shared drawing primitives reusable across visualizations.
//! Glow layers, section panels, section titles, formula footers.
const std = @import("std");
const rl = @import("raylib");
const theme = @import("theme.zig");

// ── Glow ──────────────────────────────────────────────────────

/// Draw a single glow layer: an expanded translucent rounded rect.
/// Used by BitGrid pads, 1-bit ON card, and any future glowing element.
pub fn glowLayer(r: rl.Rectangle, expand: f32, base_color: rl.Color, intensity: f32) void {
    const alpha: u8 = @intFromFloat(std.math.clamp(
        @as(f32, @floatFromInt(base_color.a)) * intensity,
        0.0,
        255.0,
    ));
    const gc = rl.Color{ .r = base_color.r, .g = base_color.g, .b = base_color.b, .a = alpha };
    const gr = rl.Rectangle{
        .x = r.x - expand,
        .y = r.y - expand,
        .width = r.width + expand * 2,
        .height = r.height + expand * 2,
    };
    rl.drawRectangleRounded(gr, 0.15, 8, gc);
}

// ── Section panel ─────────────────────────────────────────────

/// Draw a rounded panel with border and top cyan accent bar gradient.
/// Reusable for any visualization section (bit patterns, future vizs).
pub fn sectionPanel(x: f32, y: f32, w: f32, h: f32, bg_color: rl.Color) void {
    const rect = rl.Rectangle{ .x = x, .y = y, .width = w, .height = h };
    rl.drawRectangleRounded(rect, 0.02, 8, bg_color);
    rl.drawRectangleRoundedLinesEx(rect, 0.02, 8, 1.0, theme.panel_border);
    // Cyan accent bar (gradient: transparent -> cyan -> transparent)
    const bar_w: i32 = @intFromFloat(w - 4);
    const bar_x: i32 = @intFromFloat(x + 2);
    const bar_y: i32 = @intFromFloat(y);
    const half_w = @divTrunc(bar_w, 2);
    const cyan_clear = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 0 };
    const cyan_mid = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 200 };
    rl.drawRectangleGradientH(bar_x, bar_y, half_w, 2, cyan_clear, cyan_mid);
    rl.drawRectangleGradientH(bar_x + half_w, bar_y, bar_w - half_w, 2, cyan_mid, cyan_clear);
    // Subtle bleed below accent bar
    const bleed = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 8 };
    const bleed_clear = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 0 };
    rl.drawRectangleGradientV(@intFromFloat(x), @intFromFloat(y + 2), @intFromFloat(w), 20, bleed, bleed_clear);
}

// ── Section title ─────────────────────────────────────────────

/// Draw cyan text with 4-offset glow behind it. Font size 20.
pub fn sectionTitle(t: [:0]const u8, x: i32, y: i32) void {
    const glow = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 50 };
    rl.drawText(t, x - 1, y, 20, glow);
    rl.drawText(t, x + 1, y, 20, glow);
    rl.drawText(t, x, y - 1, 20, glow);
    rl.drawText(t, x, y + 1, 20, glow);
    rl.drawText(t, x, y, 20, theme.text_binary);
}

// ── Formula footer ────────────────────────────────────────────

/// Draw "prefix" in dim + "result" in cyan. Used for "2^n = X" footers.
pub fn formulaFooter(prefix: [:0]const u8, result: [:0]const u8, x: i32, y: i32) void {
    const pw = rl.measureText(prefix, 11);
    rl.drawText(prefix, x, y, 11, theme.text_dim);
    rl.drawText(result, x + pw, y, 11, theme.text_binary);
}

// ── Glass panel ──────────────────────────────────────────────

/// Draw a glass panel: semi-transparent bg, border, top cyan gradient bar, bleed glow.
pub fn glassPanel(x: f32, y: f32, w: f32, h: f32) void {
    const rect = rl.Rectangle{ .x = x, .y = y, .width = w, .height = h };
    rl.drawRectangleRounded(rect, 0.02, 8, rl.Color{ .r = 15, .g = 25, .b = 35, .a = 217 });
    rl.drawRectangleRoundedLinesEx(rect, 0.02, 8, 1.0, theme.panel_border);
    // Cyan accent bar (gradient: transparent -> cyan -> transparent)
    const bar_w: i32 = @intFromFloat(w - 4);
    const bar_x: i32 = @intFromFloat(x + 2);
    const bar_y: i32 = @intFromFloat(y);
    const half_w = @divTrunc(bar_w, 2);
    const cyan_clear = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 0 };
    const cyan_mid = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 200 };
    rl.drawRectangleGradientH(bar_x, bar_y, half_w, 2, cyan_clear, cyan_mid);
    rl.drawRectangleGradientH(bar_x + half_w, bar_y, bar_w - half_w, 2, cyan_mid, cyan_clear);
    // Bleed glow below bar
    const bleed = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 15 };
    const bleed_clear = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 0 };
    rl.drawRectangleGradientV(@intFromFloat(x), @intFromFloat(y + 2), @intFromFloat(w), 20, bleed, bleed_clear);
}

// ── Pill badge ───────────────────────────────────────────────

/// Draw a rounded pill badge with text. Returns width for cursor advancement.
pub fn pillBadge(x: f32, y: f32, label: [:0]const u8, is_on: bool) f32 {
    const tw = rl.measureText(label, 10);
    const tw_f: f32 = @floatFromInt(tw);
    const pw: f32 = tw_f + 14;
    const ph: f32 = 22;
    const rect = rl.Rectangle{ .x = x, .y = y, .width = pw, .height = ph };
    const bg = if (is_on) rl.Color{ .r = 90, .g = 240, .b = 140, .a = 25 } else rl.Color{ .r = 15, .g = 25, .b = 35, .a = 200 };
    const border = if (is_on) rl.Color{ .r = 90, .g = 240, .b = 140, .a = 100 } else theme.panel_border;
    const text_color = if (is_on) theme.bit_on else theme.text_dim;
    rl.drawRectangleRounded(rect, 0.5, 12, bg);
    rl.drawRectangleRoundedLinesEx(rect, 0.5, 12, 1.0, border);
    rl.drawText(label, @intFromFloat(x + 7), @intFromFloat(y + 5), 10, text_color);
    return pw;
}
