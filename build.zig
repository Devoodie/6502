const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const mapper = b.addModule("mapper", .{ .root_source_file = b.path("src/Mapper.zig") });
    const bus = b.addModule("bus", .{ .root_source_file = b.path("src/Bus.zig") });
    const ppu = b.addModule("ppu", .{ .root_source_file = b.path("src/Ppu.zig") });
    const cpu = b.addModule("cpu", .{ .root_source_file = b.path("src/Cpu.zig") });
    //    const apu = b.addModule("apu", .{ .root_source_file = "src/Apu.zig"});
    const nes = b.addModule("nes", .{ .root_source_file = b.path("src/Nes.zig") });
    const unit_test = b.addModule("test", .{ .root_source_file = b.path("test/JsonTests.zig") });
    const json = b.addModule("json", .{ .root_source_file = b.path("test/Json.zig") });

    const display = b.addModule("display", .{ .root_source_file = b.path("src/Display.zig") });

    bus.addImport("cpu", cpu);
    bus.addImport("ppu", ppu);
    bus.addImport("mapper", mapper);

    cpu.addImport("bus", bus);
    ppu.addImport("ppu", ppu);

    ppu.addImport("mapper", mapper);

    nes.addImport("cpu", cpu);
    nes.addImport("ppu", ppu);
    nes.addImport("bus", bus);
    nes.addImport("mapper", mapper);

    json.addImport("nes", nes);
    json.addImport("cpu", cpu);

    display.addImport("ppu", ppu);

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    const exe = b.addExecutable(.{
        .name = "nes",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);
    exe.root_module.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);
    exe.root_module.addImport("nes", nes);
    exe.root_module.addImport("test", unit_test);
    exe.root_module.addImport("display", display);
    exe.root_module.addImport("ppu", ppu);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .name = "json_tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/JsonTests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    lib_unit_tests.root_module.addImport("mapper", mapper);
    lib_unit_tests.root_module.addImport("json", json);
    lib_unit_tests.root_module.addImport("nes", nes);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
