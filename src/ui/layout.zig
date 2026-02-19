//! Common layout calculations for centering and spacing elements.
const rl = @import("raylib");

/// Return a rectangle of given size centered within the screen area.
pub fn centerRect(screen_w: i32, screen_h: i32, width: f32, height: f32) rl.Rectangle {
    return .{
        .x = (@as(f32, @floatFromInt(screen_w)) - width) * 0.5,
        .y = (@as(f32, @floatFromInt(screen_h)) - height) * 0.5,
        .width = width,
        .height = height,
    };
}
