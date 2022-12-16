const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Server = @import("Server.zig");

const log = std.log.scoped(.input_manager);

const InputManager = @This(); // {

// TODO: multi-seat
seat: *wlr.Seat,

listeners: struct {
    new_input: wl.Listener(*wlr.InputDevice),

    fn init(self: *@This()) void {
        inline for (.{
            .{ "new_input", handleNewInput },
        }) |ldata| {
            @field(self, ldata.@"0").setNotify(ldata.@"1");
        }
    }
},

pub fn init(
    self: *InputManager,
    wl_server: *wl.Server,
    backend: *wlr.Backend,
) !void {
    self.seat = try wlr.Seat.create(wl_server, "default");

    _ = try wlr.DataDeviceManager.create(wl_server);

    self.listeners.init();

    backend.events.new_input.add(&self.listeners.new_input);
}

// happy little no-op for now :)
pub fn deinit(self: *InputManager) void {
    _ = self;
}

// Handlers

fn handleNewInput(
    listener: *wl.Listener(*wlr.InputDevice),
    device: *wlr.InputDevice,
) void {
    const self = InputManager.fromListener("new_input", listener);

    log.debug("new input: {s}", .{device.name});

    switch (device.type) {
        else => log.warn("unhandled input device type: {s}", .{
            @tagName(device.type),
        }),
    }

    _ = self;
}

// Util

inline fn server(self: *InputManager) *Server {
    @fieldParentPtr(Server, "input_manager", self);
}

inline fn fromListener(
    comptime listener_name: []const u8,
    listener_ptr: anytype,
) *@This() {
    switch (@typeInfo(@TypeOf(listener_ptr))) {
        .Pointer => return @fieldParentPtr(
            @This(),
            "listeners",
            @fieldParentPtr(
                Listeners: {
                    const s: @This() = undefined;
                    break :Listeners @TypeOf(s.listeners);
                },
                listener_name,
                listener_ptr,
            ),
        ),
        else => @compileError("listener_ptr should be a pointer"),
    }
}
