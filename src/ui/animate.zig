//! Animation interpolation and easing utilities.
const std = @import("std");
const rl = @import("raylib");

/// Linearly interpolate between two byte values.
/// `t` is clamped to [0, 1]. Returns a value between `a` and `b`.
pub fn lerpByte(a: u8, b: u8, t: f32) u8 {
    const tt = std.math.clamp(t, 0.0, 1.0);
    const af: f32 = @floatFromInt(a);
    const bf: f32 = @floatFromInt(b);
    return @intFromFloat(std.math.clamp(af + (bf - af) * tt, 0.0, 255.0));
}

/// Linearly interpolate between two colors (all four RGBA channels).
pub fn lerpColor(a: rl.Color, b: rl.Color, t: f32) rl.Color {
    return .{
        .r = lerpByte(a.r, b.r, t),
        .g = lerpByte(a.g, b.g, t),
        .b = lerpByte(a.b, b.b, t),
        .a = lerpByte(a.a, b.a, t),
    };
}

/// Decay a value toward zero. Useful for press/pulse animation timers.
/// Returns max(0, value - dt * rate).
pub fn decay(value: f32, dt: f32, rate: f32) f32 {
    return @max(0.0, value - dt * rate);
}

/// Smoothstep ease-in-out. Maps t in [0,1] to a smooth S-curve.
pub fn smoothstep(t: f32) f32 {
    const tt = std.math.clamp(t, 0.0, 1.0);
    return tt * tt * (3.0 - 2.0 * tt);
}
