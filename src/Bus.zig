const std = @import("std");
const cpu = @import("Cpu.zig");
const ppu = @import("Ppu.zig");
const apu = @import("Apu.zig");
const mapper = @import("Mapper.zig");

pub const Bus = struct {
    addr_bus: u16 = 0,
    data_bus: u8 = 0,
    cpu_ptr: *cpu.Cpu = undefined,
    ppu_ptr: *ppu.Ppu = undefined,
    apu_ptr: *apu.Apu = undefined,
    catridge_ptr: *mapper.Cartridge = undefined,
    mutex: *std.Thread.Mutex = undefined,

    pub fn getMmo(self: *Bus) void {
        if (self.addr_bus <= 0x1FFF) {
            self.data_bus = self.cpu_ptr.*.memory[self.addr_bus % 0x800];
        } else if (self.addr_bus <= 0x3FFF) {
            if (self.mutex.tryLock()) {
                self.data_bus = self.ppu_ptr.*.PpuMmo(self.addr_bus);
                std.debug.print("Mutex Read Aquired! data:{d}, address: {d}\n\n", .{ self.data_bus, self.addr_bus });
                self.mutex.unlock();
            }
        } else if (self.addr_bus <= 0x401F) {
            return;
        } else if (self.addr_bus >= 0x6000) {
            self.data_bus = self.catridge_ptr.getCpuData(self.addr_bus);
        }
    }

    pub fn putMmi(self: *Bus) void {
        if (self.addr_bus <= 0x1FFF) {
            self.cpu_ptr.memory[self.addr_bus % 0x800] = self.data_bus;
        } else if (self.addr_bus <= 0x3FFF) {
            if (self.mutex.tryLock()) {
                std.debug.print("Mutex Aquired! data:{d}, address: {d}\n\n", .{ self.data_bus, self.addr_bus });
                self.ppu_ptr.ppuMmi(self.addr_bus, self.data_bus);
                self.mutex.unlock();
            }
        } else if (self.addr_bus == 0x4014) {
            self.mutex.lock();
            self.oam_dma();
            if (self.cpu_ptr.odd_cycle == 1) {
                self.cpu_ptr.cycle(std.time.nanoTimestamp(), 514);
            } else {
                self.cpu_ptr.cycle(std.time.nanoTimestamp(), 513);
            }
            self.mutex.unlock();
        } else if (self.addr_bus <= 0x401F) {
            //apu stuff
            return;
        } else if (self.addr_bus >= 0x6000) {
            self.catridge_ptr.putCpuData(self.addr_bus, self.data_bus);
        }
    }

    pub fn oam_dma(self: *Bus) void {
        const addr_buffer = self.addr_bus;
        const dma_addr: u16 = @as(u16, self.data_bus) << 8;
        self.ppu_ptr.oam_addr = 0;

        for (0..256) |i| {
            self.addr_bus = dma_addr + @as(u16, @intCast(i));
            self.getMmo();
            self.ppu_ptr.ppuMmi(0x2004, self.data_bus);
        }

        self.addr_bus = addr_buffer;
    }
};
