const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const ally = @import("../main.zig").ally;
const log = std.log.scoped(.output);

const Output = @This(); // {

output_layout: *wlr.OutputLayout,
wlr_output: *wlr.Output,

link: wl.list.Link,

listeners: struct {
    frame: wl.Listener(*wlr.Output),
    destroy: wl.Listener(*wlr.Output),

    fn init(self: *@This()) void {
        inline for (.{
            .{ "frame", handleFrame },
            .{ "destroy", handleDestroy },
        }) |ldata| {
            @field(self, ldata.@"0").setNotify(ldata.@"1");
        }
    }
},

pub fn create(
    output_layout: *wlr.OutputLayout,
    wlr_output: *wlr.Output,
) !*Output {
    const self = try ally.create(Output);
    errdefer ally.destroy(self);

    self.output_layout = output_layout;

    self.wlr_output = wlr_output;
    // We're going to be querying the output layout later, so we need
    // to get this ctx from just the wlr_output
    self.wlr_output.data = @ptrToInt(self);

    self.listeners.init();

    self.wlr_output.events.frame.add(&self.listeners.frame);
    self.wlr_output.events.destroy.add(&self.listeners.destroy);

    self.output_layout.addAuto(self.wlr_output);

    return self;
}

pub fn fromWlrOutput(wlr_output: *wlr.Output) void {
    return @intToPtr(*Output, wlr_output.data orelse @panic("Uninitialized output!"));
}

// Handlers

// frame: wl.Listener(*wlr.Output),
fn handleFrame(
    listener: *wl.Listener(*wlr.Output),
    _: *wlr.Output,
) void {
    const self = Output.fromListener("frame", listener);

    log.debug("frame on {s}", .{self.wlr_output.name});
}

// destroy: wl.Listener(*wlr.Output),
fn handleDestroy(
    listener: *wl.Listener(*wlr.Output),
    _: *wlr.Output,
) void {
    const self = Output.fromListener("destroy", listener);

    log.debug("destroying {s}", .{self.wlr_output.name});

    // no-op for now...
    self.output_layout.remove(self.wlr_output);

    ally.destroy(self);
}

// Util

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
