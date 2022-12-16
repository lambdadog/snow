const std = @import("std");
const Builder = std.build.Builder;
const Pkg = std.build.Pkg;

const ScanProtocolsStep = @import("deps/zig-wayland/build.zig").ScanProtocolsStep;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const scanner = ScanProtocolsStep.create(b);
    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
    scanner.addSystemProtocol("unstable/xdg-output/xdg-output-unstable-v1.xml");

    // These must be manually kept in sync with the versions wlroots supports
    // until wlroots gives the option to request a specific version.
    scanner.generate("wl_compositor", 4);
    scanner.generate("wl_subcompositor", 1);
    scanner.generate("wl_shm", 1);
    scanner.generate("wl_output", 4);
    scanner.generate("wl_seat", 7);
    scanner.generate("wl_data_device_manager", 3);

    scanner.generate("xdg_wm_base", 2);

    const wayland_pkg = Pkg{
        .name = "wayland",
        .source = .{ .generated = &scanner.result },
    };
    const xkbcommon_pkg = Pkg{
        .name = "xkbcommon",
        .source = .{ .path = "deps/zig-xkbcommon/src/xkbcommon.zig" },
    };
    const pixman_pkg = Pkg{
        .name = "pixman",
        .source = .{ .path = "deps/zig-pixman/pixman.zig" },
    };
    const wlroots_pkg = Pkg{
        .name = "wlroots",
        .source = .{ .path = "deps/zig-wlroots/src/wlroots.zig" },
        .dependencies = &.{
            wayland_pkg,
            xkbcommon_pkg,
            pixman_pkg,
        },
    };
    const fcft_pkg = Pkg{
        .name = "fcft",
        .source = .{ .path = "deps/zig-fcft/fcft.zig" },
        .dependencies = &.{
            pixman_pkg,
        },
    };

    const run_step = b.step("run", "Run snow");
    const test_step = b.step("test", "Run unit tests");

    {
        const snow = b.addExecutable("snow", "src/main.zig");
        snow.setTarget(target);
        snow.setBuildMode(mode);

        snow.linkLibC();

        snow.step.dependOn(&scanner.step);
        scanner.addCSource(snow);

        snow.addPackage(wayland_pkg);
        snow.linkSystemLibrary("wayland-server");

        snow.addPackage(xkbcommon_pkg);
        snow.linkSystemLibrary("xkbcommon");

        snow.addPackage(pixman_pkg);
        snow.linkSystemLibrary("pixman-1");

        snow.addPackage(wlroots_pkg);
        snow.linkSystemLibrary("wlroots");

        snow.addPackage(fcft_pkg);
        snow.linkSystemLibrary("fcft");

        snow.install();

        {
            const run_cmd = snow.run();
            run_cmd.step.dependOn(b.getInstallStep());
            if (b.args) |args|
                run_cmd.addArgs(args);
            run_step.dependOn(&run_cmd.step);
        }

        {
            const snow_tests = b.addTest("src/main.zig");
            snow_tests.setTarget(target);
            snow_tests.setBuildMode(mode);

            test_step.dependOn(&snow_tests.step);
        }
    }
}
