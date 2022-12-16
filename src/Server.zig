const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const InputManager = @import("InputManager.zig");
const Scene = @import("Scene.zig");

const Server = @This(); // {

wl_server: *wl.Server,

socket_buf: [11]u8,

backend: *wlr.Backend,

sigint_source: *wl.EventSource,
sigterm_source: *wl.EventSource,

scene: Scene,
input_manager: InputManager,

pub fn init(self: *Server) !void {
    self.wl_server = try wl.Server.create();
    errdefer self.wl_server.destroy();

    // SIGINT/SIGTERM handling
    const ev = self.wl_server.getEventLoop();
    self.sigint_source = try ev.addSignal(
        *Server,
        std.os.SIG.INT,
        handleTerminate,
        self,
    );
    errdefer self.sigint_source.remove();
    self.sigterm_source = try ev.addSignal(
        *Server,
        std.os.SIG.TERM,
        handleTerminate,
        self,
    );
    errdefer self.sigterm_source.remove();

    // backend is shared between scene and input manager so it lives
    // here :)
    self.backend = try wlr.Backend.autocreate(self.wl_server);
    errdefer self.backend.destroy();

    // snow components
    try self.scene.init(self.wl_server, self.backend);
    try self.input_manager.init(self.wl_server, self.backend);

    // socket
    const socket = try self.wl_server.addSocketAuto(&self.socket_buf);
    for (socket[0..socket.len]) |b, i| self.socket_buf[i] = b;
    // 0-terminate
    self.socket_buf[socket.len] = 0;
}

pub fn deinit(self: *Server) void {
    self.scene.deinit();
    self.input_manager.deinit();

    self.backend.destroy();

    self.sigterm_source.remove();
    self.sigint_source.remove();

    self.wl_server.destroyClients();
    self.wl_server.destroy();
}

// Interface

pub inline fn getWaylandDisplay(self: *Server) [*:0]const u8 {
    return @ptrCast([*:0]const u8, &self.socket_buf);
}

pub inline fn getX11Display(self: *Server) [*:0]const u8 {
    return self.scene.xwayland.display_name;
}

// Handlers

fn handleTerminate(
    _: c_int,
    self: *Server,
) c_int {
    self.wl_server.terminate();
    return 0;
}
