const std = @import("std");
const rl = @import("raylib");
const picture_unit = @import("ppu");

pub fn draw(io: std.Io, ppu: *picture_unit.Ppu) !void {
    const width = 1280;
    const height = 1200;
    rl.initWindow(width, height, "Devooty's Nes");
    defer rl.closeWindow();

    var screen: [184320]u8 = std.mem.zeroes([184320]u8);
    const image: rl.Image = .{ .data = &screen, .format = .uncompressed_r8g8b8, .mipmaps = 1, .height = 240, .width = 256 };
    const bitmap = try rl.loadTextureFromImage(image);

    _ = io;
    var vblank = false;
    while (true) {
        if (ppu.status & 0x80 == 0x80 and !vblank) {
            rl.beginDrawing();

            vblank = true;
            rl.clearBackground(rl.Color.black);
            GetScreen(&screen, ppu.bitmap, ppu.pallet_memory);

            rl.updateTexture(bitmap, &screen);

            rl.drawTextureEx(bitmap, .{ .x = 0, .y = 0 }, 0, 4, rl.Color.white);
            rl.endDrawing();
        } else {
            vblank = false;
        }
    }
    // }
}

fn GetScreen(screen: *[184320]u8, bitmap: *[240][256]u5, pallet: [32]u8) void {
    var pixel: u8 = 0;
    for (bitmap, 0..) |row, y_pos| {
        for (row, 0..) |column, x_pos| {
            pixel = pallet[column];
            switch (pixel) {
                0 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x62;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x62;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x62;
                },
                0x1 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x00;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x2E;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x98;
                },
                0x2 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x0C;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x11;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xC2;
                },
                0x3 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x3B;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x00;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xC2;
                },
                0x4 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x65;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x00;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x98;
                },
                0x5 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x7D;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x00;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x4E;
                },
                0x6 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x7D;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x00;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x00;
                },
                0x7 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x65;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x19;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x00;
                },
                0x8 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x3B;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x36;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x00;
                },
                0x9 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x0C;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x4F;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x00;
                },
                0xA => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x00;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x5B;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x00;
                },
                0xB => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x00;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x59;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x00;
                },
                0xC => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x00;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x49;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x4E;
                },
                0xD, 0xE, 0xF, 0x1D, 0x1E, 0x1F, 0x2E, 0x2F, 0x3E, 0x3F => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x0;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x0;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x0;
                },
                0x10 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xAB;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xAB;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xAB;
                },
                0x11 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x00;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x64;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xF4;
                },
                0x12 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x35;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x3C;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xFF;
                },
                0x13 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x76;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x1B;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xFF;
                },
                0x14 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xAE;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x0A;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xF4;
                },
                0x15 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xCF;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x0C;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x8F;
                },
                0x16 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xCF;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x23;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x1C;
                },
                0x17 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xAE;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x47;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x00;
                },
                0x18 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x76;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x6F;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x00;
                },
                0x19 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x35;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x90;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x00;
                },
                0x1A => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x00;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xA1;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x00;
                },
                0x1B => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x00;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x9E;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x1C;
                },
                0x1C => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x00;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x88;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x8F;
                },
                0x20, 0x30 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xFF;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xFF;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xFF;
                },
                0x21 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x4A;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xB5;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xFF;
                },
                0x22 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x85;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x8C;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xFF;
                },
                0x23 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xC8;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x6A;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xFF;
                },
                0x24 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xFF;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x58;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xFF;
                },
                0x25 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xFF;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x5B;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xE2;
                },
                0x26 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xFF;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x72;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x6A;
                },
                0x27 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xFF;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x97;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x02;
                },
                0x28 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xC8;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xC1;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x00;
                },
                0x29 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x85;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xE3;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x00;
                },
                0x2A => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x4A;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xF5;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x02;
                },
                0x2B => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x29;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xF2;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x6A;
                },
                0x2C => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x29;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xDB;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xE2;
                },
                0x2D => {
                    screen[(y_pos * 768) + x_pos * 3] = 0x4E;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0x4E;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x4E;
                },
                0x31 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xB6;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xE1;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xFF;
                },
                0x32 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xCE;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xD1;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xFF;
                },
                0x33 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xE9;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xC3;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xFF;
                },
                0x34 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xFF;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xBC;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xFF;
                },
                0x35 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xFF;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xBD;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xF4;
                },
                0x36 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xFF;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xC6;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xC3;
                },
                0x37 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xFF;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xD5;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x9A;
                },
                0x38 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xE9;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xE6;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x81;
                },
                0x39 => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xCE;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xF4;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0x81;
                },
                0x3A => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xB6;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xE1;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xFF;
                },
                0x3B => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xA9;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xFA;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xC3;
                },
                0x3C => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xA9;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xF0;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xF4;
                },
                0x3D => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xB8;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xB8;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xB8;
                },
                else => {
                    screen[(y_pos * 768) + x_pos * 3] = 0xFF;
                    screen[(y_pos * 768) + x_pos * 3 + 1] = 0xFF;
                    screen[(y_pos * 768) + x_pos * 3 + 2] = 0xFF;
                },
            }
        }
    }
}
