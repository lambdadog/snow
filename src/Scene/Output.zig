const std = @import("std");

const pixman = @import("pixman");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const ally = @import("../main.zig").ally;
const log = std.log.scoped(.output);

const Output = @This(); // {

output_layout: *wlr.OutputLayout,

wlr_output: *wlr.Output,
damage: *wlr.OutputDamage,

renderer: *wlr.Renderer,

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
    renderer: *wlr.Renderer,
) !*Output {
    const self = try ally.create(Output);
    errdefer ally.destroy(self);

    self.output_layout = output_layout;

    self.wlr_output = wlr_output;
    // We're going to be querying the output layout later, so we need
    // to get this ctx from just the wlr_output
    self.wlr_output.data = @ptrToInt(self);

    self.damage = try wlr.OutputDamage.create(self.wlr_output);

    self.renderer = renderer;

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

    var now: std.os.timespec = undefined;
    std.os.clock_gettime(std.os.CLOCK.MONOTONIC, &now) catch {
        @panic("CLOCK_MONOTONIC not supported.");
    };

    var needs_frame: bool = undefined;
    var damage_region: pixman.Region32 = undefined;
    damage_region.init();
    defer damage_region.deinit();

    self.damage.attachRender(&needs_frame, &damage_region) catch |err| {
        log.err("failed to attach renderer: {}", .{err});
        return;
    };

    if (!needs_frame) {
        log.debug("no damage, rolling back :)", .{});
        self.wlr_output.rollback();
        return;
    }

    self.renderer.begin(
        @intCast(u32, self.wlr_output.width),
        @intCast(u32, self.wlr_output.height),
    );
    defer {
        self.renderer.end();
        self.wlr_output.commit() catch {
            log.err("output commit failed on {s}", .{self.wlr_output.name});
        };
    }

    //const baby_blue = [4]f32{ 0.537, 0.812, 0.941, 1.0 };
    const bg_color = [4]f32{ 0.604, 0.796, 0.965, 1.0 };
    self.renderer.clear(&bg_color);
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
