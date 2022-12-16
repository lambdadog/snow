const std = @import("std");

const Server = @import("Server.zig");

pub fn main() anyerror!void {
    var server: Server = undefined;
    try server.init();
    defer server.deinit();

    try server.backend.start();

    std.log.info("WAYLAND_DISPLAY is {s}", .{server.getSocket()});
    std.log.info("DISPLAY is {s}", .{server.xwayland.display_name});

    std.log.info("starting server...", .{});
    server.wl_server.run();
    std.log.info("shutting down...", .{});
}
