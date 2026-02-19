//! Message Box Demo -- raygui dialog example.
const rl = @import("raylib");
const rg = @import("raygui");

// `rl.getColor` only accepts a `u32`. Performing `@intCast` on the return value
// of `rg.getStyle` invokes checked undefined behavior from Zig when passed to
// `rl.getColor`, hence the custom implementation here.
fn getColor(hex: i32) rl.Color {
    var color: rl.Color = .black;
    // zig fmt: off
    color.r = @intCast((hex >> 24) & 0xFF);
    color.g = @intCast((hex >> 16) & 0xFF);
    color.b = @intCast((hex >> 8) & 0xFF);
    color.a = @intCast(hex & 0xFF);
    // zig fmt: on
    return color;
}

pub fn runMessageBox() !void {
    rl.initWindow(400, 200, "Message Box Demo");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var show_message_box = false;

    const color_int = rg.getStyle(.default, .{ .default = .background_color });

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(getColor(color_int));

        if (rg.button(.init(24, 24, 120, 30), "#191#Show Message"))
            show_message_box = true;

        if (show_message_box) {
            const result = rg.messageBox(
                .init(85, 70, 250, 100),
                "#191#Show Box",
                "Hi! This is a message",
                "Nice;Cool",
            );

            if (result >= 0) show_message_box = false;
        }
    }
}
