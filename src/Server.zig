const std = @import("std");

const pixman = @import("pixman");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");
const xkb = @import("xkbcommon");

const ally = std.heap.c_allocator;

const Server = @This(); // {

wl_server: *wl.Server,

socket_buf: [11]u8,

sigint_source: *wl.EventSource,
sigterm_source: *wl.EventSource,

backend: *wlr.Backend,
renderer: *wlr.Renderer,
allocator: *wlr.Allocator,

// TODO: multi-seating
seat: *wlr.Seat,
output_layout: *wlr.OutputLayout,
xdg_shell: *wlr.XdgShell,
xwayland: *wlr.Xwayland,

// outputs: wl.list.Head(Output, "link"),
// keyboards: wl.list.Head(Keyboard, "link"),
// views: wl.list.head(View, "link"),

listeners: struct {
    new_input: wl.Listener(*wlr.InputDevice),
    new_output: wl.Listener(*wlr.Output),
    new_xdg_surface: wl.Listener(*wlr.XdgSurface),
    new_xwayland_surface: wl.Listener(*wlr.XwaylandSurface),

    fn setup(self: *@This()) void {
        inline for (.{
            .{ "new_input", handleNewInput },
            .{ "new_output", handleNewOutput },
            .{ "new_xdg_surface", handleNewXdgSurface },
            .{ "new_xwayland_surface", handleNewXwaylandSurface },
        }) |ldata| {
            @field(self, ldata.@"0").setNotify(ldata.@"1");
        }
    }
},

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

    // wlroots components
    self.backend = try wlr.Backend.autocreate(self.wl_server);
    errdefer self.backend.destroy();

    self.renderer = try wlr.Renderer.autocreate(self.backend);
    errdefer self.renderer.destroy();

    try self.renderer.initServer(self.wl_server);

    self.allocator = try wlr.Allocator.autocreate(
        self.backend,
        self.renderer,
    );
    errdefer self.allocator.destroy();

    const compositor = try wlr.Compositor.create(
        self.wl_server,
        self.renderer,
    );
    _ = try wlr.DataDeviceManager.create(self.wl_server);

    self.seat = try wlr.Seat.create(self.wl_server, "default");
    errdefer self.seat.destroy();

    self.output_layout = try wlr.OutputLayout.create();
    errdefer self.output_layout.destroy();

    self.xdg_shell = try wlr.XdgShell.create(self.wl_server);

    self.xwayland = try wlr.Xwayland.create(
        self.wl_server,
        compositor,
        false,
    );
    errdefer self.xwayland.destroy();

    // // linked lists
    // self.outputs.init();
    // self.keyboards.init();
    // self.views.init();

    // listeners
    self.listeners.setup();

    self.backend.events.new_input.add(&self.listeners.new_input);
    self.backend.events.new_output.add(&self.listeners.new_output);
    self.xdg_shell.events.new_surface.add(&self.listeners.new_xdg_surface);
    self.xwayland.events.new_surface.add(&self.listeners.new_xwayland_surface);

    // socket
    const socket = try self.wl_server.addSocketAuto(&self.socket_buf);
    for (socket[0..socket.len]) |b, i| self.socket_buf[i] = b;
    // 0-terminate
    self.socket_buf[socket.len] = 0;
}

pub fn deinit(self: *Server) void {
    self.xwayland.destroy();
    self.output_layout.destroy();
    self.seat.destroy();
    self.allocator.destroy();
    self.renderer.destroy();
    self.backend.destroy();

    self.sigterm_source.remove();
    self.sigint_source.remove();

    self.wl_server.destroyClients();
    self.wl_server.destroy();
}

// Interface

pub inline fn getSocket(self: *Server) [*:0]const u8 {
    return @ptrCast([*:0]const u8, &self.socket_buf);
}

// Handlers

// new_input: wl.Listener(*wlr.InputDevice),
fn handleNewInput(
    listener: *wl.Listener(*wlr.InputDevice),
    device: *wlr.InputDevice,
) void {
    const self = Server.fromListener("new_input", listener);

    std.log.debug("new input: {s}", .{device.name});

    _ = self;
}

// new_output: wl.Listener(*wlr.Output),
fn handleNewOutput(
    listener: *wl.Listener(*wlr.Output),
    output: *wlr.Output,
) void {
    const self = Server.fromListener("new_output", listener);

    std.log.debug("new output: {s}", .{output.name});

    _ = self;
}

// new_xdg_surface: wl.Listener(*wlr.XdgSurface),
fn handleNewXdgSurface(
    listener: *wl.Listener(*wlr.XdgSurface),
    xdg_surface: *wlr.XdgSurface,
) void {
    const self = Server.fromListener("new_xdg_surface", listener);

    switch (xdg_surface.role) {
        .toplevel => {
            std.log.debug("new xdg toplevel surface: {s}", .{
                xdg_surface.role_data.toplevel.title orelse "(title unset)",
            });
        },
        .popup => {
            std.log.debug("new xdg popup surface", .{});
        },
        .none => unreachable,
    }

    _ = self;
}

// new_xwayland_surface: wl.Listener(*wlr.XwaylandSurface),
fn handleNewXwaylandSurface(
    listener: *wl.Listener(*wlr.XwaylandSurface),
    xwayland_surface: *wlr.XwaylandSurface,
) void {
    const self = Server.fromListener("new_xwayland_surface", listener);

    std.log.debug("new xwayland surface: {s}", .{
        xwayland_surface.title orelse "(title unset)",
    });

    _ = self;
}

fn handleTerminate(
    _: c_int,
    self: *Server,
) c_int {
    self.wl_server.terminate();
    return 0;
}

// Util

fn fromListener(
    comptime listener_name: []const u8,
    listener_ptr: anytype,
) *Server {
    switch (@typeInfo(@TypeOf(listener_ptr))) {
        .Pointer => return @fieldParentPtr(
            Server,
            "listeners",
            @fieldParentPtr(
                Listeners: {
                    const s: Server = undefined;
                    break :Listeners @TypeOf(s.listeners);
                },
                listener_name,
                listener_ptr,
            ),
        ),
        else => @compileError("listener_ptr should be a pointer"),
    }
}
