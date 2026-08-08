const component = @import("bus");
const std = @import("std");

pub const StatusRegister = struct {
    carry: u1 = 0,
    zero: u1 = 0,
    interrupt_dsble: u1 = 0,
    break_inter: u1 = 0,
    decimal: u1 = 0,
    overflow: u1 = 0,
    negative: u1 = 0,
};

pub const Cpu = struct {
    memory: [2048]u8 = undefined,
    accumulator: u8 = 0,
    x_register: u8 = 0,
    y_register: u8 = 0,
    pc: u16 = 0xFFFC,
    stack_pointer: u8 = 0xFD,
    status: StatusRegister = .{},
    bus: *component.Bus = undefined,
    instruction: u8 = undefined,
    irq_line: u1 = 0,
    extra_cycle: u8 = 0,
    odd_cycle: u1 = 0,
    wait_time: std.Io.Duration = .fromNanoseconds(0),
    cycles: u64 = 0,

    // the cycles highly effect the speed of the program as intended!
    pub fn cycle(self: *Cpu, cycles: u16) void {
        self.cycles += cycles;

        self.wait_time.nanoseconds += @as(i96, cycles) * 559;
        self.odd_cycle +%= @intCast(cycles % 2);
    }

    pub fn stackPush(self: *Cpu, data: u8) void {
        self.bus.addr_bus = @as(u16, self.stack_pointer) + 0x100;
        self.bus.data_bus = data;
        self.bus.putMmi();
        self.stack_pointer -%= 1;
    }

    pub fn stackPop(self: *Cpu) u8 {
        self.stack_pointer +%= 1;
        self.bus.addr_bus = @as(u16, self.stack_pointer) + 0x100;
        self.bus.getMmo();
        return self.bus.data_bus;
    }

    pub fn stackPushAddress(self: *Cpu, address: u16) void {
        const highbyte: u8 = @truncate(address >> 8);
        const lowbyte: u8 = @truncate(address & 0xFF);

        //std.debug.print("Push Address High Byte: 0x{X}\n", .{highbyte});
        //std.debug.print("Push Address Low Byte: 0x{X}\n", .{lowbyte});

        self.bus.addr_bus = @as(u16, self.stack_pointer) + 0x100;
        self.bus.data_bus = highbyte;

        self.bus.putMmi();
        self.stack_pointer -%= 1;

        self.bus.data_bus = lowbyte;
        self.bus.addr_bus = @as(u16, self.stack_pointer) + 0x100;
        self.bus.putMmi();
        self.stack_pointer -%= 1;
    }

    pub fn stackPopAddress(self: *Cpu) u16 {
        var address: u16 = 0;
        self.stack_pointer +%= 1;
        self.bus.addr_bus = @as(u16, self.stack_pointer) + 0x100;
        self.bus.getMmo();
        const lowbyte: u16 = self.bus.data_bus;

        self.stack_pointer +%= 1;
        self.bus.addr_bus = @as(u16, self.stack_pointer) + 0x100;
        self.bus.getMmo();
        const highbyte: u16 = self.bus.data_bus;

        //std.debug.print("Pop Address Low Byte: 0x{X}\n", .{lowbyte});
        //std.debug.print("Pop Address High Byte: 0x{X}\n", .{highbyte});

        address = (highbyte << 8) | lowbyte;
        //std.debug.print("Pop Address: 0x{X}\n\n", .{address});
        return address;
    }
    //GOOD
    pub fn GetIndirectY(self: *Cpu) u8 {
        // get zeropage address
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        const zero_page = self.bus.data_bus;

        self.bus.addr_bus = self.bus.data_bus;
        self.bus.getMmo();

        const sum = @addWithOverflow(self.bus.data_bus, self.y_register);

        self.bus.addr_bus = zero_page +% 1;
        self.bus.getMmo();

        var addr: u16 = sum[0];

        addr |= @as(u16, self.bus.data_bus +% sum[1]) << 8;

        self.bus.addr_bus = addr;
        self.bus.getMmo();

        return self.bus.data_bus;
    }
    //GOOD
    pub fn setIndirectY(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        const zero_page = self.bus.data_bus;

        self.bus.addr_bus = self.bus.data_bus;
        self.bus.getMmo();

        const sum = @addWithOverflow(self.bus.data_bus, self.y_register);

        self.bus.addr_bus = zero_page +% 1;
        self.bus.getMmo();

        var addr: u16 = sum[0];

        addr |= @as(u16, self.bus.data_bus +% sum[1]) << 8;

        self.bus.addr_bus = addr;
        self.bus.data_bus = data;

        self.bus.putMmi();
    }
    //GOOD
    pub fn GetIndirectX(self: *Cpu) u8 {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        const lsb = self.bus.data_bus +% self.x_register;

        self.bus.addr_bus = lsb;
        self.bus.getMmo();

        const low_bytes = self.bus.data_bus;

        //high bytes
        self.bus.addr_bus = lsb +% 1;
        self.bus.getMmo();

        self.bus.addr_bus = self.bus.data_bus;
        self.bus.addr_bus <<= 8;
        self.bus.addr_bus |= low_bytes;

        self.bus.getMmo();

        return self.bus.data_bus;
    }
    //GOOD
    pub fn setIndirectX(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        const lsb = self.bus.data_bus +% self.x_register;

        self.bus.addr_bus = lsb;
        self.bus.getMmo();

        const low_bytes = self.bus.data_bus;

        //high bytes
        self.bus.addr_bus = lsb +% 1;
        self.bus.getMmo();

        self.bus.addr_bus = self.bus.data_bus;
        self.bus.addr_bus <<= 8;
        self.bus.addr_bus |= low_bytes;

        self.bus.data_bus = data;
        self.bus.putMmi();
    }

    //GOOD
    pub fn GetZeroPageY(self: *Cpu) u8 {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        const addr: u8 = self.bus.data_bus +% self.y_register;
        self.bus.addr_bus = addr;
        self.bus.getMmo();

        return self.bus.data_bus;
    }
    //GOOD
    pub fn setZeroPageY(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        const addr: u8 = self.bus.data_bus +% self.y_register;
        self.bus.addr_bus = addr;
        self.bus.data_bus = data;

        self.bus.putMmi();
    }
    // GOOD
    pub fn GetZeroPageX(self: *Cpu) u8 {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        const addr: u8 = self.bus.data_bus +% self.x_register;
        self.bus.addr_bus = addr;
        self.bus.getMmo();

        return self.bus.data_bus;
    }
    //GOOD
    pub fn setZeroPageX(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        const addr: u8 = self.bus.data_bus +% self.x_register;
        self.bus.addr_bus = addr;
        self.bus.data_bus = data;

        self.bus.putMmi();
    }
    //GOOD
    pub fn GetAbsoluteIndexed(self: *Cpu, xory: u1) u8 {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();
        var addr: u16 = 0;
        self.extra_cycle = 0;
        var addend: u8 = undefined;

        if (xory == 0) {
            addend = self.x_register;
        } else {
            addend = self.y_register;
        }
        const sum = @addWithOverflow(self.bus.data_bus, addend);

        self.bus.addr_bus = self.pc +% 2;
        self.bus.getMmo();
        addr |= @as(u16, self.bus.data_bus) << 8;

        if (sum[1] == 1) {
            self.extra_cycle = 1;
            addr +%= 0x100;
            addr += sum[0];
        } else {
            addr += sum[0];
        }

        self.bus.addr_bus = addr;
        self.bus.getMmo();
        return self.bus.data_bus;
    }

    pub fn setAbsoluteIndexed(self: *Cpu, xory: u1, data: u8) void {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();
        var addr: u16 = 0;
        self.extra_cycle = 0;
        var addend: u8 = undefined;

        if (xory == 0) {
            addend = self.x_register;
        } else {
            addend = self.y_register;
        }
        const sum = @addWithOverflow(self.bus.data_bus, addend);

        self.bus.addr_bus = self.pc +% 2;
        self.bus.getMmo();
        addr = @as(u16, self.bus.data_bus) << 8;

        if (sum[1] == 1) {
            self.extra_cycle = 1;
            addr +%= 0x100;
            addr += sum[0];
        } else {
            addr += sum[0];
        }

        self.bus.addr_bus = addr;
        self.bus.data_bus = data;
        self.bus.putMmi();
    }
    //GOOD
    pub fn GetZeroPage(self: *Cpu) u8 {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        self.bus.addr_bus = self.bus.data_bus;
        self.bus.getMmo();

        return self.bus.data_bus;
    }
    //GOOD
    pub fn setZeroPage(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        self.bus.addr_bus = self.bus.data_bus;
        self.bus.data_bus = data;
        self.bus.putMmi();
    }
    //GOOD
    pub fn GetImmediate(self: *Cpu) u8 {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        return self.bus.data_bus;
    }
    //GOOD
    pub fn setImmediate(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.data_bus = data;

        self.bus.putMmi();
    }

    pub fn GetAbsolute(self: *Cpu) u8 {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        var addr: u16 = self.bus.data_bus;

        self.bus.addr_bus = self.pc +% 2;
        self.bus.getMmo();

        addr |= @as(u16, self.bus.data_bus) << 8;
        //std.debug.print("Absolute Address: 0x{X}!\n", .{addr});
        self.bus.addr_bus = addr;
        self.bus.getMmo();

        return self.bus.data_bus;
    }

    pub fn setAbsolute(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        var addr: u16 = self.bus.data_bus;

        self.bus.addr_bus = self.pc +% 2;
        self.bus.getMmo();

        addr |= @as(u16, self.bus.data_bus) << 8;

        self.bus.addr_bus = addr;
        self.bus.data_bus = data;

        self.bus.putMmi();
    }

    pub fn branchRelative(self: *Cpu) void {
        const low_byte: u8 = @truncate(self.pc & 0xFF);
        const offset: u8 = self.GetImmediate();
        const signed_value: u7 = @intCast(offset & 0b1111111);
        var unsigned_value: u8 = undefined;
        //std.debug.print("Previous Address: 0x{X}!\n", .{self.pc});

        if (offset >> 7 == 1) {
            unsigned_value = ~(signed_value);
            unsigned_value += 1;
            const difference = @subWithOverflow(low_byte, @as(u8, unsigned_value));
            self.extra_cycle = difference[1];
            self.pc &= 0xFF00;
            self.pc |= difference[0];
            //std.debug.print("Difference: {d}\n", .{difference[0]});

            self.pc -%= @as(u16, @intCast(self.extra_cycle)) << 8;
        } else {
            const sum = @addWithOverflow(low_byte, @as(u8, signed_value));
            self.extra_cycle = sum[1];
            self.pc &= 0xFF00;
            self.pc |= sum[0];
            self.pc +%= @as(u16, self.extra_cycle) << 8;
            //std.debug.print("New Address: 0x{X}!\n\n", .{self.pc});
        }
    }

    pub fn jump(self: *Cpu) void {
        if (self.instruction & 0xF0 == 0x60) {
            //indirect
            self.bus.addr_bus = self.pc +% 1;
            self.bus.getMmo();

            const low_byte = self.bus.data_bus;
            //std.debug.print("LSB: 0x{X}\n", .{self.bus.data_bus});

            self.bus.addr_bus = self.pc +% 2;
            self.bus.getMmo();

            //std.debug.print("MSB: 0x{X}\n", .{self.bus.data_bus});

            self.bus.addr_bus = self.bus.data_bus;
            self.bus.addr_bus <<= 8;
            self.bus.addr_bus |= low_byte;
            //std.debug.print("Address of LSB: 0x{X}\n", .{self.bus.addr_bus});
            self.bus.getMmo();

            var addr: u16 = self.bus.data_bus;

            if (low_byte == 0xFF) {
                self.bus.addr_bus -%= 255;
            } else {
                self.bus.addr_bus +%= 1;
            }
            self.bus.getMmo();

            addr |= @as(u16, self.bus.data_bus) << 8;
            self.pc = addr;

            self.cycle(5);
        } else {
            //absolute
            self.bus.addr_bus = self.pc +% 1;
            self.bus.getMmo();

            const low_byte = self.bus.data_bus;

            self.bus.addr_bus = self.pc +% 2;
            self.bus.getMmo();

            self.pc = self.bus.data_bus;
            self.pc <<= 8;
            self.pc |= low_byte;
            self.cycle(3);
        }
    }

    pub fn xToAccumulator(self: *Cpu) void {
        self.accumulator = self.x_register;
        if (self.accumulator == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.accumulator >> 7);

        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn yToAccumulator(self: *Cpu) void {
        self.accumulator = self.y_register;
        if (self.accumulator == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.accumulator >> 7);

        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn accumulatorToX(self: *Cpu) void {
        self.x_register = self.accumulator;
        if (self.x_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.x_register >> 7);

        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn stackPointerToX(self: *Cpu) void {
        self.x_register = self.stack_pointer;
        if (self.x_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.x_register >> 7);

        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn xToStackPointer(self: *Cpu) void {
        self.stack_pointer = self.x_register;

        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn accumulatorToY(self: *Cpu) void {
        self.y_register = self.accumulator;
        if (self.y_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.y_register >> 7);

        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn pushAccumulator(self: *Cpu) void {
        self.stackPush(self.accumulator);
        self.pc +%= 1;
        self.cycle(3);
    }

    pub fn pullAccumulator(self: *Cpu) void {
        self.accumulator = self.stackPop();
        if (self.accumulator == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.accumulator >> 7);
        self.pc +%= 1;
        self.cycle(4);
    }

    pub fn pullStatus(self: *Cpu) void {
        const status = self.stackPop();

        self.status.negative = @truncate(status >> 7);
        self.status.overflow = @truncate((status >> 6) & 0b1);
        self.status.decimal = @truncate((status >> 3) & 0b1);
        self.status.interrupt_dsble = @truncate((status >> 2) & 0b1);
        self.status.zero = @truncate((status >> 1) & 0b1);
        self.status.carry = @truncate(status & 0b1);

        self.pc +%= 1;
        self.cycle(4);
    }

    pub fn pushStatus(self: *Cpu) void {
        var status: u8 = 0;

        status |= self.status.negative;
        status <<= 1;
        status |= self.status.overflow;
        status <<= 1;
        status |= 1;
        status <<= 1;
        status |= 1;
        status <<= 1;
        status |= self.status.decimal;
        status <<= 1;
        status |= self.status.interrupt_dsble;
        status <<= 1;
        status |= self.status.zero;
        status <<= 1;
        status |= self.status.carry;
        self.stackPush(status);

        self.pc +%= 1;
        self.cycle(3);
    }

    pub fn nop(self: *Cpu) void {
        switch (self.instruction) {
            0x04, 0x44, 0x64 => {
                self.pc +%= 2;
                self.cycle(3);
            },
            0x14, 0x34, 0x54, 0x74, 0xB4, 0xF4, 0xD4 => {
                self.pc +%= 2;
                self.cycle(4);
            },
            0x80, 0x89, 0x82, 0xC2, 0xE2 => {
                self.pc +%= 2;
                self.cycle(2);
            },
            0x1C, 0x3C, 0x5C, 0x7C, 0xDC, 0xFC, 0x0C => {
                self.pc +%= 3;
                self.cycle(4);
            },
            else => {
                self.pc +%= 1;
                self.cycle(2);
            },
        }
    }

    pub fn compareAccumulator(self: *Cpu) void {
        var value: u8 = 0;
        var instr_cycle: u8 = 0;
        if (self.instruction & 0xF0 == 0xD0) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    value = self.GetIndirectY();

                    self.pc +%= 2;
                    instr_cycle = @as(u8, self.extra_cycle) + 5;
                    break :indirecty;
                },
                5 => zero_pagex: {
                    value = self.GetZeroPageX();

                    self.pc +%= 2;
                    instr_cycle = 4;
                    break :zero_pagex;
                },
                9 => absolutey: {
                    value = self.GetAbsoluteIndexed(1);

                    self.pc +%= 3;
                    instr_cycle = @as(u8, self.extra_cycle) + 4;
                    break :absolutey;
                },
                0xD => absolutex: {
                    value = self.GetAbsoluteIndexed(0);

                    self.pc +%= 3;
                    instr_cycle = @as(u8, self.extra_cycle) + 4;
                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Logical XOR)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    value = self.GetIndirectX();

                    self.pc +%= 2;
                    instr_cycle = 6;
                    break :indirectx;
                },
                5 => zero_page: {
                    value = self.GetZeroPage();

                    self.pc +%= 2;
                    instr_cycle = 3;
                    break :zero_page;
                },
                9 => immediate: {
                    value = self.GetImmediate();

                    self.pc +%= 2;
                    instr_cycle = 2;
                    break :immediate;
                },
                0xD => absolute: {
                    value = self.GetAbsolute();

                    self.pc +%= 3;
                    instr_cycle = 4;
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Logical XOR)!\n", .{});
                    break :default;
                },
            }
        }

        const result = @subWithOverflow(self.accumulator, value);
        //std.debug.print("Accumulator: {d},\n Memory Value: {d},\n Result: {d}\n", .{ self.accumulator, value, result[0] });

        self.status.carry = ~result[1];

        if (result[0] == 0) {
            self.status.zero = 1;
            self.status.carry = 1;
        } else {
            self.status.zero = 0;
        }

        self.status.negative = @truncate(result[0] >> 7);

        if (self.accumulator == value) {
            self.status.negative = 0;
        } else {
            self.status.negative = @truncate(self.accumulator -% value >> 7);
        }
    }

    pub fn compareYRegister(self: *Cpu) void {
        var value: u8 = 0;
        var instr_cycle: u8 = 0;
        switch (self.instruction & 0xF) {
            0 => immediate: {
                value = self.GetImmediate();

                self.pc +%= 2;
                instr_cycle = 2;
                break :immediate;
            },
            4 => zeropage: {
                value = self.GetZeroPage();

                self.pc +%= 2;
                instr_cycle = 3;
                break :zeropage;
            },
            0xC => absolute: {
                value = self.GetAbsolute();

                self.pc +%= 3;
                instr_cycle = 4;
                break :absolute;
            },
            else => default: {
                //std.debug.print("No Valid Addressing Mode Found (Compare Y Register)!\n", .{});
                break :default;
            },
        }

        const result = @subWithOverflow(self.y_register, value);

        self.status.carry = ~result[1];

        if (result[0] == 0) {
            self.status.zero = 1;
            self.status.carry = 1;
        } else {
            self.status.zero = 0;
        }

        self.status.negative = @truncate(result[0] >> 7);
    }

    pub fn compareXRegister(self: *Cpu) void {
        var value: u8 = 0;
        var instr_cycle: u8 = 0;
        switch (self.instruction & 0xF) {
            0 => immediate: {
                value = self.GetImmediate();

                self.pc +%= 2;
                instr_cycle = 2;
                break :immediate;
            },
            4 => zeropage: {
                value = self.GetZeroPage();

                self.pc +%= 2;
                instr_cycle = 3;
                break :zeropage;
            },
            0xC => absolute: {
                value = self.GetAbsolute();

                self.pc +%= 3;
                instr_cycle = 4;
                break :absolute;
            },
            else => default: {
                //std.debug.print("No Valid Addressing Mode Found (Compare X Register)!\n", .{});
                break :default;
            },
        }
        const result = @subWithOverflow(self.x_register, value);

        self.status.carry = ~result[1];

        if (result[0] == 0) {
            self.status.zero = 1;
            self.status.carry = 1;
        } else {
            self.status.zero = 0;
        }

        self.status.negative = @truncate(result[0] >> 7);
    }

    pub fn branchNoCarry(self: *Cpu) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        if (self.status.carry == 0) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc +%= 2;
        self.cycle(self.extra_cycle + 2 + success);
    }

    pub fn branchOnCarry(self: *Cpu) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        if (self.status.carry == 1) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc +%= 2;
        self.cycle(self.extra_cycle + success);
    }

    pub fn branchOnZero(self: *Cpu) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        //std.debug.print("Zero Status: {d}\n\n", .{self.status.zero});

        if (self.status.zero == 1) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc +%= 2;
        self.cycle(self.extra_cycle + 2 + success);
    }

    pub fn branchNoZero(self: *Cpu) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        //std.debug.print("Zero Status: {d}\n\n", .{self.status.zero});

        if (self.status.zero == 0) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc +%= 2;
        const cycles = 2 + @as(u8, success) + self.extra_cycle;
        self.cycle(cycles);
    }

    pub fn branchNoNegative(self: *Cpu) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        if (self.status.negative == 0) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc +%= 2;
        self.cycle(self.extra_cycle + 2 + success);
    }

    pub fn branchOnNegative(self: *Cpu) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        if (self.status.negative == 1) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc +%= 2;
        self.cycle(self.extra_cycle + 2 + success);
    }

    pub fn branchNoOverflow(self: *Cpu) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        if (self.status.overflow == 0) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc +%= 2;
        self.cycle(self.extra_cycle + 2 + success);
    }

    pub fn branchOnOverflow(self: *Cpu) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        if (self.status.overflow == 1) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc +%= 2;
        self.cycle(self.extra_cycle + 2 + success);
    }

    pub fn increment(self: *Cpu) void {
        var value: u8 = 0;
        if (self.instruction & 0xF0 == 0xF0) {
            switch (self.instruction & 0xF) {
                6 => zeropagex: {
                    value = self.GetZeroPageX() +% 1;
                    self.setZeroPageX(value);
                    self.pc +%= 2;
                    self.cycle(6);
                    break :zeropagex;
                },
                0xE => absolutex: {
                    value = self.GetAbsoluteIndexed(0) +% 1;
                    self.setAbsoluteIndexed(0, value);
                    self.pc +%= 3;
                    self.cycle(7);
                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Valid Addressing Mode found (Increment)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                6 => zeropage: {
                    value = self.GetZeroPage() +% 1;
                    self.setZeroPage(value);
                    self.pc +%= 2;
                    self.cycle(5);
                    break :zeropage;
                },
                0xE => absolute: {
                    value = self.GetAbsolute() +% 1;
                    self.setAbsolute(value);
                    self.pc +%= 3;
                    self.cycle(6);
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Valid Addressing Mode found (Increment)!\n", .{});
                    break :default;
                },
            }
        }
        if (value == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(value >> 7);
    }

    pub fn incrementXRegister(self: *Cpu) void {
        self.x_register +%= 1;
        if (self.x_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.x_register >> 7);

        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn incrementYRegister(self: *Cpu) void {
        self.y_register +%= 1;
        if (self.y_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.y_register >> 7);

        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn decrement(self: *Cpu) void {
        var value: u8 = 0;
        if (self.instruction & 0xF0 == 0xD0) {
            switch (self.instruction & 0xF) {
                6 => zeropagex: {
                    value = self.GetZeroPageX() -% 1;
                    self.setZeroPageX(value);

                    self.pc +%= 2;
                    self.cycle(6);
                    break :zeropagex;
                },
                0xE => absolutex: {
                    value = self.GetAbsoluteIndexed(0) -% 1;
                    self.setAbsoluteIndexed(0, value);

                    self.pc +%= 3;
                    self.cycle(7);
                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Valid Addressing Mode found (Increment)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                6 => zeropage: {
                    value = self.GetZeroPage() -% 1;
                    self.setZeroPage(value);

                    self.pc +%= 2;
                    self.cycle(5);
                    break :zeropage;
                },
                0xE => absolute: {
                    value = self.GetAbsolute() -% 1;
                    self.setAbsolute(value);

                    self.pc +%= 3;
                    self.cycle(6);
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Valid Addressing Mode found (Increment)!\n", .{});
                    break :default;
                },
            }
        }
        if (value == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(value >> 7);
    }

    pub fn decrementY(self: *Cpu) void {
        self.y_register -%= 1;

        if (self.y_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.y_register >> 7);

        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn decrementX(self: *Cpu) void {
        self.x_register -%= 1;

        if (self.x_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.x_register >> 7);

        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn loadXRegister(self: *Cpu) void {
        if (self.instruction & 0xF0 == 0xA0) {
            switch (self.instruction & 0xF) {
                2 => immediate: {
                    self.x_register = self.GetImmediate();
                    self.pc +%= 2;
                    self.cycle(2);
                    break :immediate;
                },
                6 => zeropage: {
                    self.x_register = self.GetZeroPage();
                    self.pc +%= 2;
                    self.cycle(3);
                    break :zeropage;
                },
                0xE => absolute: {
                    self.x_register = self.GetAbsolute();
                    self.pc +%= 3;
                    self.cycle(4);
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Valid Addressing Mode found (Load Y Register)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                0x6 => zeropagey: {
                    self.x_register = self.GetZeroPageY();
                    self.pc +%= 2;
                    self.cycle(4);
                    break :zeropagey;
                },
                0xE => absolutey: {
                    self.x_register = self.GetAbsoluteIndexed(1);
                    self.pc +%= 3;
                    self.cycle(4 + self.extra_cycle);
                    break :absolutey;
                },
                else => default: {
                    //std.debug.print("No Valid Addressing Mode found (Load Y Register)!\n", .{});
                    break :default;
                },
            }
        }
        if (self.x_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.x_register >> 7);
    }

    pub fn loadYRegister(self: *Cpu) void {
        if (self.instruction & 0xF0 == 0xA0) {
            switch (self.instruction & 0xF) {
                0 => immediate: {
                    self.y_register = self.GetImmediate();
                    self.pc +%= 2;
                    self.cycle(2);
                    break :immediate;
                },
                4 => zeropage: {
                    self.y_register = self.GetZeroPage();
                    self.pc +%= 2;
                    self.cycle(3);
                    break :zeropage;
                },
                0xC => absolute: {
                    self.y_register = self.GetAbsolute();
                    self.pc +%= 3;
                    self.cycle(4);
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Valid Addressing Mode found (Load Y Register)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                0x4 => zeropagex: {
                    self.y_register = self.GetZeroPageX();
                    self.pc +%= 2;
                    self.cycle(4);
                    break :zeropagex;
                },
                0xC => absolutex: {
                    self.y_register = self.GetAbsoluteIndexed(0);
                    self.pc +%= 3;
                    self.cycle(4 + self.extra_cycle);
                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Valid Addressing Mode found (Load Y Register)!\n", .{});
                    break :default;
                },
            }
        }
        if (self.y_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.y_register >> 7);
    }

    pub fn forceInterrupt(self: *Cpu) void {
        self.stackPushAddress(self.pc + 2);
        self.status.break_inter = 1;
        self.pushStatus();

        self.status.break_inter = 0;
        self.status.interrupt_dsble = 1;

        self.pc = 0xFFFD;
        //little endian
        var address: u16 = self.GetImmediate();
        self.pc +%= 1;
        address |= @as(u16, self.GetImmediate()) << 8;

        self.pc = address;
        self.cycle(4);
    }

    pub fn interruptRequest(self: *Cpu, vector: u16) void {
        self.stackPushAddress(self.pc);
        self.pushStatus();

        self.pc = vector - 1;
        var address: u16 = self.GetImmediate();
        self.pc +%= 1;
        address |= @as(u16, self.GetImmediate()) << 8;

        self.pc = address;
        self.cycle(4);
    }

    pub fn returnInterrupt(self: *Cpu) void {
        const status = self.stackPop();
        self.status.negative = @truncate(status >> 7);
        self.status.overflow = @truncate((status >> 6) & 0b1);
        self.status.decimal = @truncate((status >> 3) & 0b1);
        self.status.interrupt_dsble = @truncate((status >> 2) & 0b1);
        self.status.zero = @truncate((status >> 1) & 0b1);
        self.status.carry = @truncate(status & 0b1);
        self.pc = self.stackPopAddress();
        self.cycle(6);
    }

    pub fn jumpSubroutine(self: *Cpu) void {
        self.stackPushAddress(self.pc + 2);
        //std.debug.print("Return Address: 0x{X}\n\n", .{self.pc + 2});

        self.bus.addr_bus = self.pc +% 1;
        self.bus.getMmo();

        var addr: u16 = self.bus.data_bus;

        self.bus.addr_bus = self.pc +% 2;
        self.bus.getMmo();

        addr |= @as(u16, self.bus.data_bus) << 8;

        self.pc = addr;
        //std.debug.print("Stack Pointer: 0x{X}\n", .{self.stack_pointer});

        self.cycle(6);
    }

    pub fn returnSubroutine(self: *Cpu) void {
        self.pc = self.stackPopAddress();
        self.pc +%= 1;
        //std.debug.print("Stack Pointer: 0x{X}\n", .{self.stack_pointer});
        self.cycle(6);
    }

    pub fn subtractWithCarry(self: *Cpu) void {
        var value: u8 = 0;
        var instr_cycle: u8 = 0;
        if (self.instruction & 0xF0 == 0xF0) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    value = self.GetIndirectY();

                    self.pc +%= 2;
                    instr_cycle = @as(u8, self.extra_cycle) + 5;
                    break :indirecty;
                },
                5 => zero_pagex: {
                    value = self.GetZeroPageX();

                    self.pc +%= 2;
                    instr_cycle = 4;
                    break :zero_pagex;
                },
                9 => absolutey: {
                    value = self.GetAbsoluteIndexed(1);

                    self.pc +%= 3;
                    instr_cycle = @as(u8, self.extra_cycle) + 4;
                    break :absolutey;
                },
                0xD => absolutex: {
                    value = self.GetAbsoluteIndexed(0);

                    self.pc +%= 3;
                    instr_cycle = @as(u8, self.extra_cycle) + 4;
                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Add With Carry)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    value = self.GetIndirectX();

                    self.pc +%= 2;
                    instr_cycle = 6;
                    break :indirectx;
                },
                5 => zero_page: {
                    value = self.GetZeroPage();

                    self.pc +%= 2;
                    instr_cycle = 3;
                    break :zero_page;
                },
                9 => immediate: {
                    value = self.GetImmediate();

                    self.pc +%= 2;
                    instr_cycle = 2;
                    break :immediate;
                },
                0xD => absolute: {
                    value = self.GetAbsolute();

                    self.pc +%= 3;
                    instr_cycle = 4;
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Add With Carry)!\n", .{});
                    break :default;
                },
            }
        }

        const result = self.accumulator +% ~value +% self.status.carry;

        if (result > self.accumulator or (self.status.carry == 0 and self.accumulator +% self.status.carry == result)) {
            self.status.carry = 0;
        } else {
            self.status.carry = 1;
        }

        self.status.overflow = @truncate(((result ^ self.accumulator) & (result ^ ~value) & 0x80) >> 7);
        self.accumulator = result;

        if (self.accumulator == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.accumulator >> 7);
    }

    pub fn loadAccumulator(self: *Cpu) void {
        if (self.instruction & 0xF0 == 0xB0) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    self.accumulator = self.GetIndirectY();
                    self.pc +%= 2;
                    self.cycle(5 + @as(u8, self.extra_cycle));
                    break :indirecty;
                },
                5 => zero_pagex: {
                    self.accumulator = self.GetZeroPageX();
                    self.pc +%= 2;
                    self.cycle(4);
                    break :zero_pagex;
                },
                9 => absolutey: {
                    self.accumulator = self.GetAbsoluteIndexed(1);
                    self.pc +%= 3;
                    self.cycle(4 + @as(u8, self.extra_cycle));
                    break :absolutey;
                },
                0xD => absolutex: {
                    self.accumulator = self.GetAbsoluteIndexed(0);
                    self.pc +%= 3;
                    self.cycle(4 + @as(u8, self.extra_cycle));
                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Load Accumulator)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    self.accumulator = self.GetIndirectX();
                    self.pc +%= 2;
                    self.cycle(6);
                    break :indirectx;
                },
                5 => zero_page: {
                    self.accumulator = self.GetZeroPage();
                    self.pc +%= 2;
                    self.cycle(3);
                    break :zero_page;
                },
                9 => immediate: {
                    self.accumulator = self.GetImmediate();
                    self.pc +%= 2;
                    self.cycle(2);
                    break :immediate;
                },
                0xD => absolute: {
                    self.accumulator = self.GetAbsolute();
                    self.pc +%= 3;
                    self.cycle(4);
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Load Accumulator)!\n", .{});
                    break :default;
                },
            }
        }
        //big fucking issue and if this is in every instruction this has scary implications
        if (self.accumulator == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.accumulator >> 7);
        //std.debug.print("Accumulator: 0x{X}\n\n", .{self.accumulator});
    }

    pub fn storeYRegister(self: *Cpu) void {
        if (self.instruction & 0xF0 == 0x90) {
            self.setZeroPageX(self.y_register);
            self.pc +%= 2;
            self.cycle(4);
        } else {
            switch (self.instruction & 0xF) {
                4 => zeropage: {
                    self.setZeroPage(self.y_register);
                    self.pc +%= 2;
                    self.cycle(3);
                    break :zeropage;
                },
                0xC => absolute: {
                    self.setAbsolute(self.y_register);
                    self.pc +%= 3;
                    self.cycle(4);
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Valid Addresing mode found (Store Y Register!\n", .{});
                    break :default;
                },
            }
        }
    }

    pub fn storeXRegister(self: *Cpu) void {
        if (self.instruction & 0xF0 == 0x90) {
            self.setZeroPageY(self.x_register);
            self.pc +%= 2;
            self.cycle(4);
        } else {
            switch (self.instruction & 0xF) {
                6 => zeropage: {
                    self.setZeroPage(self.x_register);
                    self.pc +%= 2;
                    self.cycle(3);
                    break :zeropage;
                },
                0xE => absolute: {
                    self.setAbsolute(self.x_register);
                    self.pc +%= 3;
                    self.cycle(4);
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Valid Addresing mode found (Store X Register!\n", .{});
                    break :default;
                },
            }
        }
    }

    pub fn storeAccumulator(self: *Cpu) void {
        if (self.instruction & 0xF0 == 0x90) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    self.setIndirectY(self.accumulator);
                    self.pc +%= 2;
                    self.cycle(6);
                    break :indirecty;
                },
                5 => zero_pagex: {
                    self.setZeroPageX(self.accumulator);
                    self.pc +%= 2;
                    self.cycle(4);
                    break :zero_pagex;
                },
                9 => absolutey: {
                    self.setAbsoluteIndexed(1, self.accumulator);
                    self.pc +%= 3;
                    self.cycle(5);
                    break :absolutey;
                },
                0xD => absolutex: {
                    self.setAbsoluteIndexed(0, self.accumulator);
                    self.pc +%= 3;
                    self.cycle(5);
                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Logical XOR)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    self.setIndirectX(self.accumulator);
                    self.pc +%= 2;
                    self.cycle(6);
                    break :indirectx;
                },
                5 => zero_page: {
                    self.setZeroPage(self.accumulator);
                    self.pc +%= 2;
                    self.cycle(3);
                    break :zero_page;
                },
                0xD => absolute: {
                    self.setAbsolute(self.accumulator);
                    self.pc +%= 3;
                    self.cycle(4);
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Logical XOR)!\n", .{});
                    break :default;
                },
            }
        }
        //std.debug.print("Accumulator: {d}\n", .{self.accumulator});
    }

    pub fn logicalShiftRight(self: *Cpu) void {
        var result: u8 = 0;
        if (self.instruction & 0xF0 == 0x50) {
            switch (self.instruction & 0xF) {
                6 => zeropagex: {
                    const value = self.GetZeroPageX();
                    result = value >> 1;
                    self.setZeroPageX(result);

                    self.status.carry = @truncate(value & 0b1);

                    self.pc +%= 2;
                    self.cycle(6);

                    break :zeropagex;
                },
                0xE => absolutex: {
                    const value = self.GetAbsoluteIndexed(0);
                    result = value >> 1;
                    self.setAbsoluteIndexed(0, result);

                    self.status.carry = @truncate(value & 0b1);

                    self.pc +%= 3;
                    self.cycle(7);

                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                6 => zeropage: {
                    const value = self.GetZeroPage();
                    result = value >> 1;
                    self.setZeroPage(result);

                    self.status.carry = @truncate(value & 0b1);

                    self.pc +%= 2;
                    self.cycle(5);

                    break :zeropage;
                },
                0xA => accumulator: {
                    self.status.carry = @truncate(self.accumulator & 0b1);
                    result = self.accumulator >> 1;
                    self.accumulator = result;

                    self.pc +%= 1;
                    self.cycle(2);
                    break :accumulator;
                },
                0xE => absolute: {
                    const value = self.GetAbsolute();
                    result = value >> 1;
                    self.setAbsolute(result);

                    self.status.carry = @truncate(value & 0b1);

                    self.pc +%= 3;
                    self.cycle(6);

                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
                    break :default;
                },
            }
        }
        if (result == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(result >> 7);
    }

    pub fn rotateLeft(self: *Cpu) void {
        var result: u8 = 0;
        if (self.instruction & 0xF0 == 0x30) {
            switch (self.instruction & 0xF) {
                6 => zeropagex: {
                    const value = self.GetZeroPageX();
                    result = value << 1;
                    result |= self.status.carry;

                    self.status.carry = @truncate(value >> 7);

                    self.setZeroPageX(result);

                    self.pc +%= 2;
                    self.cycle(6);

                    break :zeropagex;
                },
                0xE => absolutex: {
                    const value = self.GetAbsoluteIndexed(0);
                    result = value << 1;
                    result |= self.status.carry;

                    self.status.carry = @truncate(value >> 7);

                    self.setAbsoluteIndexed(0, result);

                    self.pc +%= 3;
                    self.cycle(7);

                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                6 => zeropage: {
                    const value = self.GetZeroPage();
                    result = value << 1;
                    result |= self.status.carry;

                    self.status.carry = @truncate(value >> 7);

                    self.setZeroPage(result);

                    self.pc +%= 2;
                    self.cycle(5);

                    break :zeropage;
                },
                0xA => accumulator: {
                    const carry = self.status.carry;
                    self.status.carry = @truncate(self.accumulator >> 7);

                    result = self.accumulator << 1;
                    result |= carry;
                    self.accumulator = result;

                    self.pc +%= 1;
                    self.cycle(2);
                    break :accumulator;
                },
                0xE => absolute: {
                    const value = self.GetAbsolute();
                    result = value << 1;
                    result |= self.status.carry;

                    self.status.carry = @truncate(value >> 7);

                    self.setAbsolute(result);

                    self.pc +%= 3;
                    self.cycle(6);

                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
                    break :default;
                },
            }
        }
        if (result == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(result >> 7);
    }

    pub fn rotateRight(self: *Cpu) void {
        var result: u8 = 0;
        if (self.instruction & 0xF0 == 0x70) {
            switch (self.instruction & 0xF) {
                6 => zeropagex: {
                    const value = self.GetZeroPageX();
                    result = value >> 1;
                    result |= @as(u8, self.status.carry) << 7;

                    self.status.carry = @truncate(value & 0b1);

                    self.setZeroPageX(result);

                    self.pc +%= 2;
                    self.cycle(6);

                    break :zeropagex;
                },
                0xE => absolutex: {
                    const value = self.GetAbsoluteIndexed(0);
                    result = value >> 1;
                    result |= @as(u8, self.status.carry) << 7;

                    self.status.carry = @truncate(value & 0b1);

                    self.setAbsoluteIndexed(0, result);

                    self.pc +%= 3;
                    self.cycle(7);

                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                6 => zeropage: {
                    const value = self.GetZeroPage();
                    result = value >> 1;
                    result |= @as(u8, self.status.carry) << 7;

                    self.status.carry = @truncate(value & 0b1);

                    self.setZeroPage(result);

                    self.pc +%= 2;
                    self.cycle(5);

                    break :zeropage;
                },
                0xA => accumulator: {
                    const carry: u8 = self.status.carry;
                    self.status.carry = @truncate(self.accumulator & 0b1);
                    result = self.accumulator >> 1;
                    result |= carry << 7;
                    self.accumulator = result;

                    self.pc +%= 1;
                    self.cycle(2);
                    break :accumulator;
                },
                0xE => absolute: {
                    const value = self.GetAbsolute();
                    result = value >> 1;
                    result |= @as(u8, self.status.carry) << 7;

                    self.status.carry = @truncate(value & 0b1);

                    self.setAbsolute(result);

                    self.pc +%= 3;
                    self.cycle(6);

                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
                    break :default;
                },
            }
        }
        if (result == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(result >> 7);
    }

    pub fn arithmeticShiftLeft(self: *Cpu) void {
        if (self.instruction & 0xF0 == 0x10) {
            switch (self.instruction & 0xF) {
                6 => zeropagex: {
                    const value = @shlWithOverflow(self.GetZeroPageX(), 1);
                    self.setZeroPageX(value[0]);

                    self.status.carry = value[1];
                    if (value[0] == 0) {
                        self.status.zero = 1;
                    } else {
                        self.status.zero = 0;
                    }
                    self.status.negative = @truncate(value[0] >> 7);

                    self.pc +%= 2;
                    self.cycle(6);

                    break :zeropagex;
                },
                0xE => absolutex: {
                    const value = @shlWithOverflow(self.GetAbsoluteIndexed(0), 1);
                    self.setAbsoluteIndexed(0, value[0]);

                    self.status.carry = value[1];
                    if (value[0] == 0) {
                        self.status.zero = 1;
                    } else {
                        self.status.zero = 0;
                    }
                    self.status.negative = @truncate(value[0] >> 7);

                    self.pc +%= 3;
                    self.cycle(7);
                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                6 => zeropage: {
                    const value = @shlWithOverflow(self.GetZeroPage(), 1);
                    self.setZeroPage(value[0]);

                    self.status.carry = value[1];
                    if (value[0] == 0) {
                        self.status.zero = 1;
                    } else {
                        self.status.zero = 0;
                    }
                    self.status.negative = @truncate(value[0] >> 7);

                    self.pc +%= 2;
                    self.cycle(5);
                    break :zeropage;
                },
                0xA => accumulator: {
                    const value = @shlWithOverflow(self.accumulator, 1);
                    self.accumulator = value[0];

                    self.status.carry = value[1];
                    if (self.accumulator == 0) {
                        self.status.zero = 1;
                    } else {
                        self.status.zero = 0;
                    }
                    self.status.negative = @truncate(self.accumulator >> 7);

                    self.pc +%= 1;
                    self.cycle(2);
                    break :accumulator;
                },
                0xE => absolute: {
                    const value = @shlWithOverflow(self.GetAbsolute(), 1);
                    self.setAbsolute(value[0]);

                    self.status.carry = value[1];
                    if (value[0] == 0) {
                        self.status.zero = 1;
                    } else {
                        self.status.zero = 0;
                    }
                    self.status.negative = @truncate(value[0] >> 7);

                    self.pc +%= 3;
                    self.cycle(6);
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
                    break :default;
                },
            }
        }
        //std.debug.print("Accumulator: {d}!\n", .{self.accumulator});
    }

    pub fn addWithCarry(self: *Cpu) void {
        var value: u8 = 0;
        var instr_cycles: u8 = 0;
        if (self.instruction & 0xF0 == 0x70) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    value = self.GetIndirectY();

                    self.pc +%= 2;
                    instr_cycles = @as(u8, self.extra_cycle) + 5;
                    break :indirecty;
                },
                5 => zero_pagex: {
                    value = self.GetZeroPageX();

                    self.pc +%= 2;
                    instr_cycles = 4;
                    break :zero_pagex;
                },
                9 => absolutey: {
                    value = self.GetAbsoluteIndexed(1);
                    //std.debug.print("Accumulator: {d}\n", .{self.accumulator});

                    self.pc +%= 3;
                    instr_cycles = @as(u8, self.extra_cycle) + 4;
                    break :absolutey;
                },
                0xD => absolutex: {
                    value = self.GetAbsoluteIndexed(0);

                    self.pc +%= 3;
                    instr_cycles = @as(u8, self.extra_cycle) + 4;
                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Add With Carry)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    value = self.GetIndirectX();

                    self.pc +%= 2;
                    instr_cycles = 6;
                    break :indirectx;
                },
                5 => zero_page: {
                    value = self.GetZeroPage();

                    self.pc +%= 2;
                    instr_cycles = 3;
                    break :zero_page;
                },
                9 => immediate: {
                    value = self.GetImmediate();

                    self.pc +%= 2;
                    instr_cycles = 2;
                    break :immediate;
                },
                0xD => absolute: {
                    value = self.GetAbsolute();

                    self.pc +%= 3;
                    instr_cycles = 4;
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Add With Carry)!\n", .{});
                    break :default;
                },
            }
        }
        const result: u8 = self.accumulator +% value +% self.status.carry;

        if (result < self.accumulator or (self.status.carry == 1 and result == self.accumulator)) {
            self.status.carry = 1;
        } else {
            self.status.carry = 0;
        }

        self.status.overflow = @truncate(((result ^ self.accumulator) & (result ^ value) & 0x80) >> 7);

        self.accumulator = result;
        if (self.accumulator == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.accumulator >> 7);
        self.cycle(instr_cycles);
    }

    pub fn clearCarry(self: *Cpu) void {
        self.status.carry = 0;
        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn clearDecimal(self: *Cpu) void {
        self.status.decimal = 0;
        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn clearInterrupt(self: *Cpu) void {
        self.status.interrupt_dsble = 0;
        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn clearOverflow(self: *Cpu) void {
        self.status.overflow = 0;
        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn setCarry(self: *Cpu) void {
        self.status.carry = 1;
        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn setDecimal(self: *Cpu) void {
        self.status.decimal = 1;
        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn setInterrupt(self: *Cpu) void {
        self.status.interrupt_dsble = 1;
        self.pc +%= 1;
        self.cycle(2);
    }

    pub fn bitTest(self: *Cpu) void {
        switch (self.instruction & 0xF) {
            4 => zero_page: {
                const value = self.GetZeroPage();
                const result = value & self.accumulator;

                self.status.negative = @truncate(value >> 7);
                self.status.overflow = @truncate((value >> 6) & 0b1);
                if (result == 0) {
                    self.status.zero = 1;
                } else {
                    self.status.zero = 0;
                }

                self.pc +%= 2;
                self.cycle(3);
                break :zero_page;
            },
            0xC => absolute: {
                const value = self.GetAbsolute();
                const result = value & self.accumulator;

                self.status.negative = @truncate(value >> 7);
                self.status.overflow = @truncate((value >> 6) & 0b1);
                if (result == 0) {
                    self.status.zero = 1;
                } else {
                    self.status.zero = 0;
                }

                self.pc +%= 3;
                self.cycle(4);
                break :absolute;
            },
            else => default: {
                //std.debug.print("No Addressing Mode found (Bit Test)!\n", .{});
                break :default;
            },
        }
    }

    pub fn exclusiveOr(self: *Cpu) void {
        if (self.instruction & 0xF0 == 0x50) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    self.accumulator ^= self.GetIndirectY();

                    self.pc +%= 2;
                    self.cycle(5 + self.extra_cycle);
                    break :indirecty;
                },
                5 => zero_pagex: {
                    self.accumulator ^= self.GetZeroPageX();

                    self.pc +%= 2;
                    self.cycle(4);
                    break :zero_pagex;
                },
                9 => absolutey: {
                    self.accumulator ^= self.GetAbsoluteIndexed(1);

                    self.pc +%= 3;
                    self.cycle(4 + self.extra_cycle);
                    break :absolutey;
                },
                0xD => absolutex: {
                    self.accumulator ^= self.GetAbsoluteIndexed(0);

                    self.pc +%= 3;
                    self.cycle(4 + self.extra_cycle);
                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Logical XOR)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    self.accumulator ^= self.GetIndirectX();

                    self.pc +%= 2;
                    self.cycle(6);
                    break :indirectx;
                },
                5 => zero_page: {
                    self.accumulator ^= self.GetZeroPage();

                    self.pc +%= 2;
                    self.cycle(3);
                    break :zero_page;
                },
                9 => immediate: {
                    self.accumulator ^= self.GetImmediate();

                    self.pc +%= 2;
                    self.cycle(2);
                    break :immediate;
                },
                0xD => absolute: {
                    self.accumulator ^= self.GetAbsolute();

                    self.pc +%= 3;
                    self.cycle(4);
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Logical XOR)!\n", .{});
                    break :default;
                },
            }
        }
        if (self.accumulator == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.accumulator >> 7);
    }

    pub fn logicalOr(self: *Cpu) void {
        if (self.instruction & 0xF0 == 0x10) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    self.accumulator |= self.GetIndirectY();

                    self.pc +%= 2;
                    self.cycle(5 + self.extra_cycle);
                    break :indirecty;
                },
                5 => zero_pagex: {
                    self.accumulator |= self.GetZeroPageX();

                    self.pc +%= 2;
                    self.cycle(4);
                    break :zero_pagex;
                },
                9 => absolutey: {
                    self.accumulator |= self.GetAbsoluteIndexed(1);

                    self.pc +%= 3;
                    self.cycle(4 + self.extra_cycle);
                    break :absolutey;
                },
                0xD => absolutex: {
                    self.accumulator |= self.GetAbsoluteIndexed(0);

                    self.pc +%= 3;
                    self.cycle(4 + self.extra_cycle);
                    break :absolutex;
                },
                else => default: {
                    //std.debug.print("No Addresing Mode found (Logical Or)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    self.accumulator |= self.GetIndirectX();

                    self.pc +%= 2;
                    self.cycle(6);
                    break :indirectx;
                },
                5 => zero_page: {
                    self.accumulator |= self.GetZeroPage();

                    self.pc +%= 2;
                    self.cycle(3);
                    break :zero_page;
                },
                9 => immediate: {
                    self.accumulator |= self.GetImmediate();

                    self.pc +%= 2;
                    self.cycle(2);
                    break :immediate;
                },
                0xD => absolute: {
                    self.accumulator |= self.GetAbsolute();

                    self.pc +%= 3;
                    self.cycle(4);
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode Found (Logical Or)\n!", .{});
                    break :default;
                },
            }
        }
        if (self.accumulator == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.accumulator >> 7);
    }

    pub fn logicalAnd(self: *Cpu) void {
        //I know its an annd because the lowest nib % 4 == 1
        if (self.instruction & 0xF0 == 0x30) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    self.accumulator &= self.GetIndirectY();

                    self.pc +%= 2;
                    self.cycle(5 + self.extra_cycle);
                    break :indirecty;
                },
                5 => zero_pagex: {
                    self.accumulator &= self.GetZeroPageX();
                    self.pc +%= 2;
                    self.cycle(4);
                    break :zero_pagex;
                },
                9 => absolute_y: {
                    self.accumulator &= self.GetAbsoluteIndexed(1);

                    self.pc +%= 3;
                    self.cycle(4 + self.extra_cycle);
                    break :absolute_y;
                },
                0xD => absolute_x: {
                    self.accumulator &= self.GetAbsoluteIndexed(0);

                    self.pc +%= 3;
                    self.cycle(4 + self.extra_cycle);
                    break :absolute_x;
                },
                else => default: {
                    //std.debug.print("No Addressing mode found (Logical And)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    self.accumulator &= self.GetIndirectX();

                    self.pc +%= 2;
                    self.cycle(6);
                    break :indirectx;
                },
                5 => zero_page: {
                    self.accumulator &= self.GetZeroPage();

                    self.pc +%= 2;
                    self.cycle(3);
                    break :zero_page;
                },
                9 => immediate: {
                    self.accumulator &= self.GetImmediate();

                    self.pc +%= 2;
                    self.cycle(2);
                    break :immediate;
                },
                0xD => absolute: {
                    self.accumulator &= self.GetAbsolute();

                    self.pc +%= 3;
                    self.cycle(4);
                    break :absolute;
                },
                else => default: {
                    //std.debug.print("No Addressing Mode found (Logical And)!\n", .{});
                    break :default;
                },
            }
        }
        if (self.accumulator == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.accumulator >> 7);
    }

    pub fn operate(self: *Cpu) void {
        self.execute();
        //if there's a non-maskable interrupt /detect and handle
        if (self.bus.ppu_ptr.nmi == 1) {
            //std.debug.print("Non-maskable Interrupt!\n\n", .{});
            self.interruptRequest(0xFFFA);
            self.bus.ppu_ptr.nmi = 0;
        } else if (self.irq_line == 1 and self.status.interrupt_dsble != 1) {
            //std.debug.print("Interrupt Request!\n\n", .{});
            self.interruptRequest(0xFFFE);
            self.irq_line = 0;
        }
    }

    pub fn execute(self: *Cpu) void {
        //instruction decode
        self.bus.addr_bus = self.pc;
        self.bus.getMmo();

        self.instruction = self.bus.data_bus;

        const first_nib = (self.instruction & 0xF);
        const second_nib = (self.instruction & 0xF0);

        //std.debug.print("Instruction: 0x{X}, Address: 0x{X}!\n", .{ self.instruction, self.pc });
        //instruction execute
        switch (first_nib % 4) {
            0 => CONTROL: {
                // std.debug.print("CONTROL\n", .{});
                switch (self.instruction) {
                    0x00 => {
                        self.forceInterrupt();
                        //std.debug.print("6502: Force Interrupt Found!\n", .{});
                        break :CONTROL;
                    },
                    0x04, 0x0C, 0x14, 0x1C, 0x34, 0x3C, 0x44, 0x54, 0x5C, 0x64, 0x74, 0x7C, 0x80, 0xD4, 0xDC, 0xF4, 0xFC => {
                        self.nop();
                        //std.debug.print("6502: NOP Found!\n", .{});
                        break :CONTROL;
                    },
                    0x08 => {
                        self.pushStatus();
                        //std.debug.print("6502: PHP Found!\n", .{});
                        break :CONTROL;
                    },
                    0x10 => {
                        self.branchNoNegative();
                        //std.debug.print("6502: BPL Found!\n", .{});
                        break :CONTROL;
                    },
                    0x18 => {
                        self.clearCarry();
                        //std.debug.print("6502: CLC Found!\n", .{});
                        break :CONTROL;
                    },
                    0x20 => {
                        self.jumpSubroutine();
                        //std.debug.print("6502: JSR Found!\n", .{});
                        break :CONTROL;
                    },
                    0x24, 0x2C => {
                        self.bitTest();
                        //std.debug.print("6502: BIT Found!\n", .{});
                        break :CONTROL;
                    },
                    0x28 => {
                        self.pullStatus();
                        //std.debug.print("6502: PLP Found!\n", .{});
                        break :CONTROL;
                    },
                    0x30 => {
                        self.branchOnNegative();
                        //std.debug.print("6502: BMI Found!\n", .{});
                        break :CONTROL;
                    },
                    0x38 => {
                        self.setCarry();
                        //std.debug.print("6502: SEC Found!\n", .{});
                        break :CONTROL;
                    },
                    0x40 => {
                        self.returnInterrupt();
                        //std.debug.print("6502: RTI Found!\n", .{});
                        break :CONTROL;
                    },
                    0x48 => {
                        self.pushAccumulator();
                        //std.debug.print("6502: PHA Found!\n", .{});
                        break :CONTROL;
                    },
                    0x4C, 0x6C => {
                        self.jump();
                        //std.debug.print("6502: JMP Found!\n", .{});
                        break :CONTROL;
                    },
                    0x50 => {
                        self.branchNoOverflow();
                        //std.debug.print("6502: BVC Found!\n", .{});
                        break :CONTROL;
                    },
                    0x58 => {
                        self.clearInterrupt();
                        //std.debug.print("6502: CLI Found!\n", .{});
                        break :CONTROL;
                    },
                    0x60 => {
                        self.returnSubroutine();
                        //std.debug.print("6502: RTS Found!\n", .{});
                        break :CONTROL;
                    },
                    0x68 => {
                        self.pullAccumulator();
                        //std.debug.print("6502: PLA Found!\n", .{});
                        break :CONTROL;
                    },
                    0x70 => {
                        self.branchOnOverflow();
                        //std.debug.print("6502: BVS Found!\n", .{});
                        break :CONTROL;
                    },
                    0x78 => {
                        self.setInterrupt();
                        //std.debug.print("6502: SEI Found!\n", .{});
                        break :CONTROL;
                    },
                    0x84, 0x8C, 0x94 => {
                        self.storeYRegister();
                        //std.debug.print("6502: STY Found!\n", .{});
                        break :CONTROL;
                    },
                    0x88 => {
                        self.decrementY();
                        //std.debug.print("6502: DEY Found!\n", .{});
                        break :CONTROL;
                    },
                    0x90 => {
                        self.branchNoCarry();
                        //std.debug.print("6502: BCC Found!\n", .{});
                        break :CONTROL;
                    },
                    0x98 => {
                        self.yToAccumulator();
                        //std.debug.print("6502: TYA Found!\n", .{});
                        break :CONTROL;
                        //SHY is 0x9C
                    },
                    0xA0, 0xA4, 0xAC, 0xB4, 0xBC => {
                        //complete this instruction
                        self.loadYRegister();
                        //std.debug.print("6502: LDY Found!\n", .{});
                        break :CONTROL;
                    },
                    0xA8 => {
                        self.accumulatorToY();
                        //std.debug.print("6502: TAY Found!\n", .{});
                        break :CONTROL;
                    },
                    0xB0 => {
                        self.branchOnCarry();
                        //std.debug.print("6502: BCS Found!\n", .{});
                        break :CONTROL;
                    },
                    0xB8 => {
                        self.clearOverflow();
                        //std.debug.print("6502: CLV Found!\n", .{});
                        break :CONTROL;
                    },
                    0xC0, 0xC4, 0xCC => {
                        self.compareYRegister();
                        //std.debug.print("6502: CPY Found!\n", .{});
                        break :CONTROL;
                    },
                    0xC8 => {
                        self.incrementYRegister();
                        //std.debug.print("6502: INY Found!\n", .{});
                        break :CONTROL;
                    },
                    0xD0 => {
                        self.branchNoZero();
                        //std.debug.print("6502: BNE Found!\n", .{});
                        break :CONTROL;
                    },
                    0xD8 => {
                        self.clearDecimal();
                        //std.debug.print("6502: CLD Found!\n", .{});
                        break :CONTROL;
                    },
                    0xE0, 0xE4, 0xEC => {
                        self.compareXRegister();
                        //std.debug.print("6502: CPX Found!\n", .{});
                        break :CONTROL;
                    },
                    0xE8 => {
                        self.incrementXRegister();
                        //std.debug.print("6502: INX Found!\n", .{});
                        break :CONTROL;
                    },
                    0xF0 => {
                        self.branchOnZero();
                        //std.debug.print("6502: BEQ Found!\n", .{});
                        break :CONTROL;
                    },
                    0xF8 => {
                        self.setDecimal();
                        //std.debug.print("6502: SED Found!\n", .{});
                        break :CONTROL;
                    },
                    else => {
                        break :CONTROL;
                    },
                }
            },
            1 => ALU: {
                switch (second_nib) {
                    0x00, 0x10 => {
                        self.logicalOr();
                        //std.debug.print("6502: ORA Found!\n", .{});
                        break :ALU;
                    },
                    0x20, 0x30 => {
                        self.logicalAnd();
                        //std.debug.print("6502: AND Found!\n", .{});
                        break :ALU;
                    },
                    0x40, 0x50 => {
                        self.exclusiveOr();
                        //std.debug.print("6502: EOR Found!\n", .{});
                        break :ALU;
                    },
                    0x60, 0x70 => {
                        self.addWithCarry();
                        //std.debug.print("6502: ADC Found!\n", .{});
                        break :ALU;
                    },
                    0x80, 0x90 => {
                        if (self.instruction == 0x89) {
                            self.nop();
                            //std.debug.print("6502: NOP Found!\n", .{});
                        } else {
                            self.storeAccumulator();
                            //std.debug.print("6502: STA Found!\n", .{});
                        }
                        break :ALU;
                    },
                    0xA0, 0xB0 => {
                        self.loadAccumulator();
                        //std.debug.print("6502: LDA Found!\n", .{});
                        break :ALU;
                    },
                    0xC0, 0xD0 => {
                        self.compareAccumulator();
                        //std.debug.print("6502: CMP Found!\n", .{});
                        break :ALU;
                    },
                    0xE0, 0xF0 => {
                        self.subtractWithCarry();
                        //std.debug.print("6502: SBC Found!\n", .{});
                        break :ALU;
                    },
                    else => {
                        //std.debug.print("6502: No Valid Instruction Found!\n", .{});
                        break :ALU;
                    },
                }
            },
            2 => RMW: {
                switch (second_nib) {
                    0x00, 0x10 => {
                        if (self.instruction == 0x02 or self.instruction == 0x12) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x1A) {
                            self.nop();
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else {
                            self.arithmeticShiftLeft();
                            //std.debug.print("6502: ASL Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0x20, 0x30 => {
                        if (self.instruction == 0x22 or self.instruction == 0x32) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x3A) {
                            self.nop();
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else {
                            self.rotateLeft();
                            //std.debug.print("6502: ROL Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0x40, 0x50 => {
                        if (self.instruction == 0x42 or self.instruction == 0x52) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x5A) {
                            self.nop();
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else {
                            self.logicalShiftRight();
                            //std.debug.print("6502: LSR Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0x60, 0x70 => {
                        if (self.instruction == 0x62 or self.instruction == 0x72) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x7A) {
                            self.nop();
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else {
                            self.rotateRight();
                            //std.debug.print("6502: ROR Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0x80, 0x90 => {
                        if (self.instruction == 0x92) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x82) {
                            self.nop();
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x86 or self.instruction == 0x8E or self.instruction == 0x96) {
                            self.storeXRegister();
                            //std.debug.print("6502: STX Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x8A) {
                            self.xToAccumulator();
                            //std.debug.print("6502: TXA Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x9A) {
                            self.xToStackPointer();
                            //std.debug.print("6502: TXS Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0xA0, 0xB0 => {
                        if (self.instruction == 0xB2) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0xAA) {
                            self.accumulatorToX();
                            //std.debug.print("6502: TAX Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0xBA) {
                            self.stackPointerToX();
                            //std.debug.print("6502: TSX Found!\n", .{});
                            break :RMW;
                        } else {
                            self.loadXRegister();
                            //std.debug.print("6502: LDX Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0xC0, 0xD0 => {
                        if (self.instruction == 0xE2) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0xC2 or self.instruction == 0xDA) {
                            self.nop();
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0xCA) {
                            self.decrementX();
                            //std.debug.print("6502: DEX found!\n", .{});
                        } else {
                            self.decrement();
                            //std.debug.print("6502: DEC Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0xE0, 0xF0 => {
                        if (self.instruction == 0xF2) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0xE2 or self.instruction == 0xEA or self.instruction == 0xFA) {
                            self.nop();
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else {
                            self.increment();
                            //std.debug.print("6502: INC Found!\n", .{});
                            break :RMW;
                        }
                    },
                    else => {
                        //std.debug.print("6502: No Valid Instruction Found!\n", .{});
                        break :RMW;
                    },
                }
            },
            else => default: {
                //std.debug.print("6502: No Valid Instruction Found!\n", .{});
                break :default;
            },
        }
    }
};
