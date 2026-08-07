const std = @import("std");
const components = @import("nes");
const display = @import("Display.zig");
const rl = @import("raylib");

pub fn main(init: std.process.Init) !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const allocator = init.gpa;

    //    var nes: components.Nes = .{ .Cpu = .{}, .Ppu = .{ .mutex = &lock }, .Bus = .{ .mutex = &lock } };
    //   nes.init();
    var nes = try allocator.create(components.Nes);
    defer allocator.destroy(nes);

    nes.init();

    nes.Ppu.bitmap = try allocator.create([240][256]u5);
    defer allocator.destroy(nes.Ppu.bitmap);

    var args = init.minimal.args.iterate();
    const io = init.io;
    var path: ?[]u8 = null;

    while (true) {
        const argument = args.next();
        if (argument == null) {
            break;
        }
        if (std.mem.eql(u8, argument.?, "-p")) {
            const path_arg = args.next();
            path = @constCast(path_arg.?[0..path_arg.?.len]);
        }
    }

    if (path == null) {
        std.debug.print("No Path variable found!\n", .{});
        return;
    }

    std.debug.print("Path: {s}\n", .{path.?});

    const working_directory = std.Io.Dir.cwd();

    var ines_file = try working_directory.openFile(io, path.?, .{});
    var read_buff: [1024]u8 = undefined;
    var ines_reader = ines_file.reader(io, &read_buff);
    var ines_interf = &ines_reader.interface;

    defer ines_file.close(io);

    try ines_reader.seekTo(0);

    //768000
    const rom = try ines_interf.allocRemaining(allocator, .limited(768000));
    defer allocator.free(rom);

    std.debug.print("Rom Loaded: {d}!\n\n", .{rom.len});

    //initwindow
    rl.initWindow(1280, 1200, "Devooty's Nes");
    defer rl.closeWindow();

    var screen: [184320]u8 = std.mem.zeroes([184320]u8);
    const image: rl.Image = .{ .data = &screen, .format = .uncompressed_r8g8b8, .mipmaps = 1, .height = 240, .width = 256 };
    const screen_texture = try rl.loadTextureFromImage(image);
    nes.Ppu.screen_texture = screen_texture;
    nes.Ppu.screen = &screen;

    try nes.Mapper.mapper_init(@constCast(&rom), allocator);
    //program start
    nes.Ppu.nametable_mirroring = nes.Mapper.mirroring;

    //boostrap sequence
    {
        nes.Cpu.pc -= 1;
        const lsb: u16 = nes.Cpu.GetImmediate();

        nes.Cpu.pc += 1;
        const msb: u16 = nes.Cpu.GetImmediate();

        nes.Bus.addr_bus = msb << 8;
        nes.Bus.addr_bus |= lsb;
        std.debug.print("Initialization Address: 0x{x}\n\n", .{nes.Bus.addr_bus});

        nes.Cpu.pc = nes.Bus.addr_bus;
    }

    const clock: std.Io.Clock = .awake;
    var prev_time = clock.now(io);
    var current_time = clock.now(io);
    var first = true;
    //change this shit.
    {
        while (!rl.windowShouldClose()) {
            //do all the operations then check to see if the elapsed time has passed
            // if (nes.Cpu.wait_time < cpu_timer.read()) {
            //     cpu_timer.reset();
            //     nes.Cpu.wait_time = 0;
            //     nes.Cpu.operate();
            //  }

            if (nes.Cpu.cycles < 114) {
                nes.Cpu.operate();
            } else {
                current_time = clock.now(io);
                if (first) {
                    std.debug.print("CPU: {d}ns, {d} CYCLES\n", .{ current_time.toNanoseconds() - prev_time.toNanoseconds(), nes.Cpu.cycles });
                    first = false;
                }
                if (current_time.nanoseconds < prev_time.addDuration(nes.Cpu.wait_time).nanoseconds) {
                    continue;
                }
                nes.Ppu.operate();
                nes.Cpu.cycles = 0;
                nes.Cpu.wait_time.nanoseconds = 0;
                prev_time = clock.now(io);
                first = true;
            }
        }
    }
    try nes.Mapper.deinit(allocator);
}

pub fn masterClock(nes: *components.Nes, cpu_timer: *std.time.Timer) void {
    //    var timer = try std.time.Timer.start();
    while (true) {
        if (nes.Cpu.wait_time < cpu_timer.read()) {
            cpu_timer.reset();
            nes.Cpu.wait_time = 0;
            nes.Cpu.operate();
        }
        if (nes.Cpu.cycles >= 114) {
            //           timer.reset();
            nes.Ppu.operate();
            //          const time = timer.read();
            //         std.debug.print("PPU Scanline Time: {d} ns\n", .{time});
            nes.Cpu.cycles -= 114;
        }
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
