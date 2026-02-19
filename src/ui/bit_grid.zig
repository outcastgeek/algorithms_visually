//! BitGrid -- an interactive row of clickable bit pads.
//!
//! Displays a binary number as individual toggleable bit squares.
//! Each bit is a rounded rectangle that can be clicked to flip 0/1,
//! with multi-layer glow, 3D depth illusion, press/flash animations,
//! and ambient pulse on active bits.
//!
//! Used by bit_piano, and reusable in any visualization that needs
//! an interactive binary number display.
const std = @import("std");
const rl = @import("raylib");
const theme = @import("theme.zig");
const animate = @import("animate.zig");

pub const MAX_BITS: usize = 32;

/// Visual state for a single bit pad.
const Pad = struct {
    rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    /// Animation timer: 1.0 = just pressed, decays to 0.0.
    press_t: f32 = 0.0,
    /// Flash overlay timer: 1.0 = just toggled, decays to 0.0.
    flash_t: f32 = 0.0,
};

/// An interactive row of toggleable bit squares.
pub const BitGrid = struct {
    bit_count: usize,
    bits: [MAX_BITS]bool = [_]bool{false} ** MAX_BITS,
    pads: [MAX_BITS]Pad = [_]Pad{.{}} ** MAX_BITS,
    hovered: ?usize = null,
    just_toggled: ?usize = null,

    /// Accumulated time for ambient pulse animation (sin wave).
    total_time: f32 = 0.0,
    /// Height of each pad in pixels. Default 90 preserves legacy behavior.
    pad_height: f32 = 90,
    /// Extra horizontal gap inserted at every nibble boundary (every 4 bits).
    /// Default 0 means no nibble grouping.
    nibble_gap: f32 = 0,

    /// Create a new BitGrid with the given number of bits, all initially off.
    pub fn init(bit_count: usize) BitGrid {
        std.debug.assert(bit_count > 0 and bit_count <= MAX_BITS);
        return .{ .bit_count = bit_count };
    }

    /// Compute pad rectangles to center the row horizontally at the given y offset.
    pub fn layout(self: *BitGrid, screen_width: i32, y_offset: f32) void {
        const count_f: f32 = @floatFromInt(self.bit_count);
        const margin: f32 = 18;
        const total_w: f32 = @as(f32, @floatFromInt(screen_width)) - margin * 2;
        const gap: f32 = 10;

        // Count nibble boundaries: gaps between groups of 4
        const nibble_boundaries: f32 = if (self.bit_count > 4)
            @floatFromInt((self.bit_count - 1) / 4)
        else
            0;
        const total_nibble_extra = nibble_boundaries * self.nibble_gap;

        const available = total_w - gap * (count_f - 1) - total_nibble_extra;
        const pad_w: f32 = @min(90, available / count_f);
        const pad_h: f32 = self.pad_height;

        const row_w = pad_w * count_f + gap * (count_f - 1) + total_nibble_extra;
        const x0 = (@as(f32, @floatFromInt(screen_width)) - row_w) * 0.5;

        var i: usize = 0;
        var x_cursor: f32 = x0;
        while (i < self.bit_count) : (i += 1) {
            // Insert nibble gap at 4-bit boundaries
            if (i > 0 and i % 4 == 0) {
                x_cursor += self.nibble_gap;
            }

            const old_press = self.pads[i].press_t;
            const old_flash = self.pads[i].flash_t;
            self.pads[i] = .{
                .rect = .{ .x = x_cursor, .y = y_offset, .width = pad_w, .height = pad_h },
                .press_t = old_press,
                .flash_t = old_flash,
            };
            x_cursor += pad_w + gap;
        }
    }

    /// Check mouse interaction. Call once per frame before drawing.
    pub fn handleInput(self: *BitGrid) void {
        self.hovered = null;
        self.just_toggled = null;
        const m = rl.getMousePosition();
        var i: usize = 0;
        while (i < self.bit_count) : (i += 1) {
            if (rl.checkCollisionPointRec(m, self.pads[i].rect)) {
                self.hovered = i;
                if (rl.isMouseButtonPressed(.left)) {
                    self.bits[i] = !self.bits[i];
                    self.just_toggled = i;
                    self.pads[i].press_t = 1.0;
                    self.pads[i].flash_t = 1.0;
                }
            }
        }
    }

    /// Update animation timers. Call once per frame.
    pub fn tick(self: *BitGrid, dt: f32) void {
        self.total_time = @mod(self.total_time + dt, std.math.tau);
        var i: usize = 0;
        while (i < self.bit_count) : (i += 1) {
            self.pads[i].press_t = animate.decay(self.pads[i].press_t, dt, 8.0);
            self.pads[i].flash_t = animate.decay(self.pads[i].flash_t, dt, 5.0);
        }
    }

    /// Draw all bit pads with glow, depth, hover, press, and flash effects.
    pub fn draw(self: *const BitGrid) void {
        // Ambient pulse: oscillates 0.0..1.0 for glow breathing on ON pads
        const pulse = (std.math.sin(self.total_time * 2.0) + 1.0) * 0.5;

        var i: usize = 0;
        while (i < self.bit_count) : (i += 1) {
            const on = self.bits[i];
            const pad = self.pads[i];
            const r = pad.rect;
            const is_hovered = (self.hovered != null and self.hovered.? == i);

            // ── Layer 1: Glow (ON pads only) ────────────────
            if (on) {
                const glow_strength: f32 = if (is_hovered) 1.3 else (0.7 + pulse * 0.3);
                drawGlowLayer(r, 14, theme.glow_outer, glow_strength);
                drawGlowLayer(r, 7, theme.glow_mid, glow_strength);
                drawGlowLayer(r, 3, theme.glow_inner, glow_strength);
            }

            // ── Layer 2: 3D depth edge ──────────────────────
            const depth: f32 = 4.0;
            const depth_visible = depth * (1.0 - pad.press_t);
            if (depth_visible > 0.5) {
                const depth_r = rl.Rectangle{
                    .x = r.x,
                    .y = r.y + r.height - depth_visible,
                    .width = r.width,
                    .height = depth + pad.press_t * 3.0,
                };
                const depth_color = if (on) theme.pad_depth_on else theme.pad_depth_off;
                rl.drawRectangleRounded(depth_r, 0.25, 6, depth_color);
            }

            // ── Layer 3: Pad body ───────────────────────────
            var body_r = r;
            body_r.y += pad.press_t * 3.0;
            body_r.height -= pad.press_t * 3.0;

            const body_color = if (on) theme.pad_on_bg else theme.pad_off_bg;
            rl.drawRectangleRounded(body_r, 0.08, 8, body_color);

            // Inner radial glow for ON pads (skip if pad is too small)
            if (on and body_r.width > 26 and body_r.height > 26) {
                const inner = rl.Rectangle{
                    .x = body_r.x + 12,
                    .y = body_r.y + 8,
                    .width = body_r.width - 24,
                    .height = body_r.height - 24,
                };
                rl.drawRectangleRounded(inner, 0.15, 8, rl.Color{ .r = 90, .g = 240, .b = 140, .a = 15 });
            }

            // ── Layer 4: Border ─────────────────────────────
            const border_color = if (is_hovered)
                (if (on) theme.pad_on_hover else theme.pad_off_hover)
            else
                (if (on) theme.pad_on_border else theme.pad_off_border);
            rl.drawRectangleRoundedLinesEx(body_r, 0.08, 8, if (is_hovered) @as(f32, 2.0) else @as(f32, 1.5), border_color);

            // ── Layer 5: Flash overlay ──────────────────────
            if (pad.flash_t > 0.01) {
                const flash_alpha: u8 = @intFromFloat(std.math.clamp(
                    @as(f32, @floatFromInt(theme.flash.a)) * pad.flash_t,
                    0.0,
                    255.0,
                ));
                const fc = rl.Color{ .r = theme.flash.r, .g = theme.flash.g, .b = theme.flash.b, .a = flash_alpha };
                rl.drawRectangleRounded(body_r, 0.08, 8, fc);
            }

            // ── Layer 6: Text ───────────────────────────────
            const bit_index = self.bit_count - 1 - i;

            // Bit index label (top, small)
            var idx_buf: [8]u8 = undefined;
            const idx_txt = std.fmt.bufPrintZ(&idx_buf, "b{d}", .{bit_index}) catch "b?";
            const idx_w = rl.measureText(idx_txt, 13);
            const idx_x: i32 = @intFromFloat(body_r.x + (body_r.width - @as(f32, @floatFromInt(idx_w))) * 0.5);
            const idx_y: i32 = @intFromFloat(body_r.y + 10);
            const idx_color = if (on) theme.pad_on_index else theme.pad_off_index;
            rl.drawText(idx_txt, idx_x, idx_y, 13, idx_color);

            // Bit value (center, large)
            const val_char: [:0]const u8 = if (on) "1" else "0";
            const val_size: i32 = if (self.pad_height >= 110) 38 else 26;
            const val_w = rl.measureText(val_char, val_size);
            const val_x: i32 = @intFromFloat(body_r.x + (body_r.width - @as(f32, @floatFromInt(val_w))) * 0.5);
            const val_y: i32 = @intFromFloat(body_r.y + body_r.height * 0.40);

            if (on) {
                // Glow behind "1" text
                rl.drawText(val_char, val_x - 1, val_y, val_size, theme.text_glow);
                rl.drawText(val_char, val_x + 1, val_y, val_size, theme.text_glow);
                rl.drawText(val_char, val_x, val_y - 1, val_size, theme.text_glow);
                rl.drawText(val_char, val_x, val_y + 1, val_size, theme.text_glow);
                rl.drawText(val_char, val_x, val_y, val_size, theme.text_on);
            } else {
                rl.drawText(val_char, val_x, val_y, val_size, theme.text_off);
            }
        }
    }

    /// Read the bits as an unsigned integer (MSB at index 0).
    pub fn toUnsigned(self: *const BitGrid) u32 {
        var v: u32 = 0;
        var i: usize = 0;
        while (i < self.bit_count) : (i += 1) {
            if (self.bits[i]) {
                const shift: u5 = @intCast(self.bit_count - 1 - i);
                v |= (@as(u32, 1) << shift);
            }
        }
        return v;
    }

    /// Set the bits from an unsigned integer value (MSB at index 0).
    pub fn fromUnsigned(self: *BitGrid, value: u32) void {
        var i: usize = 0;
        while (i < self.bit_count) : (i += 1) {
            const shift: u5 = @intCast(self.bit_count - 1 - i);
            self.bits[i] = ((value >> shift) & 1) == 1;
        }
    }
};

// ── Private helpers ──────────────────────────────────────────

/// Draw a single glow layer: an expanded translucent rounded rect.
fn drawGlowLayer(r: rl.Rectangle, expand: f32, base_color: rl.Color, intensity: f32) void {
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
