const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSafe });

    const use_native_char_encoding = b.option(
        bool,
        "native_char_encoding",
        "Whether to use native char encoding",
    );

    const options = b.addOptions();
    options.addOption(bool, "native_char_encoding", use_native_char_encoding orelse false);

    const root_module = b.addModule("root", .{ .root_source_file = b.path("src/nfd.zig") });
    root_module.addOptions("build_options", options);

    const lib = b.addStaticLibrary(.{
        .name = "nfd",
        .target = target,
        .optimize = optimize,
    });
    const cflags = &.{};
    switch (target.result.os.tag) {
        .windows => {
            lib.addCSourceFiles(.{
                .files = &.{"nativefiledialog-extended/nfd_win.cpp"},
                .flags = cflags,
            });
        },
        .macos => {
            lib.addCSourceFiles(.{
                .files = &.{"nativefiledialog-extended/nfd_cocoa.m"},
                .flags = cflags,
            });
        },
        else => if (isLinuxDesktopLike(target.result.os.tag)) {
            const Backend = enum { gtk, portal };
            const backend = Backend.portal;
            switch (backend) {
                .gtk => {
                    lib.addCSourceFiles(.{
                        .files = &.{"nativefiledialog-extended/nfd_gtk.cpp"},
                        .flags = cflags,
                    });
                },
                .portal => {
                    lib.addIncludePath(.{ .cwd_relative = "/usr/include/dbus-1.0" });
                    lib.addIncludePath(.{ .cwd_relative = try std.fs.path.join(b.allocator, &.{
                        "/usr/lib",
                        try target.result.linuxTriple(b.allocator),
                        "dbus-1.0/include",
                    }) });
                    lib.addCSourceFiles(.{
                        .files = &.{"nativefiledialog-extended/nfd_portal.cpp"},
                        .flags = cflags,
                    });
                    lib.linkSystemLibrary("dbus-1");
                },
            }
        } else {
            @panic("Unsupported target");
        },
    }
    lib.linkLibC();

    b.installArtifact(lib);
}

fn isLinuxDesktopLike(tag: std.Target.Os.Tag) bool {
    return switch (tag) {
        .linux,
        .freebsd,
        .openbsd,
        .dragonfly,
        => true,
        else => false,
    };
}
