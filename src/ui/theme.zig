//! Neon cyber aesthetic color palette and drawing helpers.
//! Dark backgrounds, bright cyan/green for active elements, gray for text.
const rl = @import("raylib");

// ── Background ───────────────────────────────────────────────
/// Deep dark blue-gray, used for gradient top.
pub const background_top = rl.Color{ .r = 10, .g = 14, .b = 20, .a = 255 };

/// Near-black, used for gradient bottom.
pub const background_bottom = rl.Color{ .r = 20, .g = 28, .b = 38, .a = 255 };

// ── Legacy flat pad colors (kept for compatibility) ──────────
/// Dark gray-blue for inactive/off bits.
pub const bit_off = rl.Color{ .r = 45, .g = 52, .b = 60, .a = 255 };

/// Bright green for active/on bits.
pub const bit_on = rl.Color{ .r = 90, .g = 240, .b = 140, .a = 255 };

// ── Text ─────────────────────────────────────────────────────
/// Light near-white for primary text.
pub const text = rl.Color{ .r = 230, .g = 235, .b = 245, .a = 255 };

/// Dimmed gray for secondary/label text.
pub const text_dim = rl.Color{ .r = 85, .g = 102, .b = 119, .a = 255 };

/// Very dim text for OFF bit values.
pub const text_off = rl.Color{ .r = 46, .g = 61, .b = 76, .a = 255 };

/// Bright white for ON bit value text.
pub const text_on = rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };

/// Glow behind ON value text (drawn slightly offset).
pub const text_glow = rl.Color{ .r = 90, .g = 240, .b = 140, .a = 80 };

/// Cyan for binary readout string.
pub const text_binary = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 255 };

/// Dim text for help lines.
pub const text_help = rl.Color{ .r = 74, .g = 90, .b = 106, .a = 255 };

// ── Accent / utility ─────────────────────────────────────────
/// Bright cyan for highlights and accents.
pub const accent = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 255 };

/// Warm orange for warnings or attention.
pub const warning = rl.Color{ .r = 255, .g = 180, .b = 60, .a = 255 };

// ── Pad ON state ─────────────────────────────────────────────
/// Dark green fill for an ON pad body.
pub const pad_on_bg = rl.Color{ .r = 14, .g = 34, .b = 24, .a = 255 };

/// Green border for an ON pad.
pub const pad_on_border = rl.Color{ .r = 90, .g = 240, .b = 140, .a = 200 };

/// Brighter border when hovering an ON pad.
pub const pad_on_hover = rl.Color{ .r = 141, .g = 252, .b = 184, .a = 255 };

/// Dim green for ON pad bit-index label.
pub const pad_on_index = rl.Color{ .r = 90, .g = 240, .b = 140, .a = 128 };

// ── Pad OFF state ────────────────────────────────────────────
/// Very dark fill for an OFF pad body.
pub const pad_off_bg = rl.Color{ .r = 21, .g = 29, .b = 38, .a = 255 };

/// Dim border for an OFF pad.
pub const pad_off_border = rl.Color{ .r = 28, .g = 37, .b = 48, .a = 180 };

/// Slightly brighter border when hovering an OFF pad.
pub const pad_off_hover = rl.Color{ .r = 40, .g = 58, .b = 80, .a = 220 };

/// Dim text for OFF pad bit-index label.
pub const pad_off_index = rl.Color{ .r = 40, .g = 53, .b = 64, .a = 255 };

// ── 3D depth edge (drawn below pad body) ─────────────────────
pub const pad_depth_on = rl.Color{ .r = 42, .g = 112, .b = 69, .a = 255 };
pub const pad_depth_off = rl.Color{ .r = 12, .g = 17, .b = 24, .a = 255 };

// ── Glow layers (translucent, drawn behind ON pads) ──────────
pub const glow_inner = rl.Color{ .r = 90, .g = 240, .b = 140, .a = 55 };
pub const glow_mid = rl.Color{ .r = 90, .g = 240, .b = 140, .a = 35 };
pub const glow_outer = rl.Color{ .r = 90, .g = 240, .b = 140, .a = 18 };

// ── Flash overlay (white-green burst on toggle) ──────────────
pub const flash = rl.Color{ .r = 200, .g = 255, .b = 220, .a = 120 };

// ── Panel / readout ──────────────────────────────────────────
pub const panel_bg = rl.Color{ .r = 15, .g = 24, .b = 34, .a = 230 };
pub const panel_border = rl.Color{ .r = 30, .g = 45, .b = 61, .a = 200 };
pub const panel_accent = rl.Color{ .r = 0, .g = 229, .b = 255, .a = 255 };

// ── Separator ────────────────────────────────────────────────
pub const separator = rl.Color{ .r = 30, .g = 45, .b = 61, .a = 160 };

// ════════════════════════════════════════════════════════════════
// Drawing helpers
// ════════════════════════════════════════════════════════════════

/// Draw the standard dark gradient background across the full window.
pub fn drawBackground(width: i32, height: i32) void {
    rl.clearBackground(background_top);
    rl.drawRectangleGradientV(0, 0, width, height, background_top, background_bottom);
}

/// Draw a vignette effect (darkened edges) over the window.
/// Call after background but before interactive content.
pub fn drawVignette(width: i32, height: i32) void {
    const edge = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 70 };
    const clear = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
    const band_h: i32 = @divTrunc(width, 7);
    const band_v: i32 = @divTrunc(height, 6);
    // Left
    rl.drawRectangleGradientH(0, 0, band_h, height, edge, clear);
    // Right
    rl.drawRectangleGradientH(width - band_h, 0, band_h, height, clear, edge);
    // Top
    rl.drawRectangleGradientV(0, 0, width, band_v, edge, clear);
    // Bottom
    rl.drawRectangleGradientV(0, height - band_v, width, band_v, clear, edge);
}

/// Draw CRT-style horizontal scanlines across the full window.
/// Call as the very last draw step, over all other content.
pub fn drawScanlines(width: i32, height: i32) void {
    const line_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 18 };
    var y: i32 = 0;
    while (y < height) : (y += 3) {
        rl.drawLine(0, y, width, y, line_color);
    }
}
