const component = @import("Bus.zig");
const std = @import("std");

const StatusRegister = struct {
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
    irq_line: u1 = 1,
    extra_cycle: u8 = 0,
    odd_cycle: u1 = 0,
    wait_time: i128 = 0,

    pub fn cycle(self: *Cpu, prev_time: i128, cycles: u16) void {
        const wait_time: i128 = 559 * @as(i128, @intCast(cycles));
        std.debug.print("Cpu Wait Time: {d}!\n", .{wait_time});
        const goal_time = wait_time + prev_time;
        self.odd_cycle +%= @intCast(cycles % 2);
        self.wait_time = goal_time;
        //        std.debug.print("The cycles are {d}!\n", .{self.odd_cycle});

        //        while (std.time.nanoTimestamp() <= goal_time) {
        //           continue;
        //      }
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

        std.debug.print("Push Address Low Byte: 0x{X}\n", .{lowbyte});
        std.debug.print("Push Address High Byte: 0x{X}\n", .{highbyte});

        self.bus.addr_bus = @as(u16, self.stack_pointer) + 0x100;
        self.bus.data_bus = lowbyte;

        self.bus.putMmi();
        self.stack_pointer -%= 1;

        self.bus.data_bus = highbyte;
        self.bus.addr_bus = @as(u16, self.stack_pointer) + 0x100;
        self.bus.putMmi();
        self.stack_pointer -%= 1;
    }

    pub fn stackPopAddress(self: *Cpu) u16 {
        var address: u16 = 0;
        self.stack_pointer +%= 1;
        self.bus.addr_bus = @as(u16, self.stack_pointer) + 0x100;
        self.bus.getMmo();
        const highbyte: u16 = self.bus.data_bus;

        self.stack_pointer +%= 1;
        self.bus.addr_bus +%= 1;
        self.bus.getMmo();
        const lowbyte: u16 = self.bus.data_bus;

        std.debug.print("Pop Address Low Byte: 0x{X}\n", .{lowbyte});
        std.debug.print("Pop Address High Byte: 0x{X}\n", .{highbyte});

        address = (highbyte << 8) | lowbyte;
        std.debug.print("Pop Address: 0x{X}\n\n", .{address});
        return address;
    }
    //GOOD
    pub fn GetIndirectY(self: *Cpu) u8 {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();
        self.extra_cycle = 0;
        // get low order bytes
        const sum = @addWithOverflow(self.bus.data_bus, self.y_register);
        if (sum[1] == 1) {
            self.extra_cycle = 1;
        }
        const buffer = sum[0];

        self.bus.addr_bus = buffer;
        self.bus.getMmo();
        var addr: u16 = self.bus.data_bus;

        self.bus.addr_bus += 1;
        self.bus.getMmo();

        const high_bytes: u16 = @as(u16, @intCast(self.bus.data_bus + sum[1])) << 8;
        addr |= high_bytes;

        self.bus.addr_bus = addr;
        self.bus.getMmo();

        return self.bus.data_bus;
    }
    //GOOD
    pub fn setIndirectY(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();
        self.extra_cycle = 0;

        // get low order bytes
        const sum = @addWithOverflow(self.bus.data_bus, self.y_register);
        if (sum[1] == 1) {
            self.extra_cycle = 1;
        }
        var addr: u16 = sum[0];

        self.bus.addr_bus = addr + 0;
        self.bus.getMmo();

        const high_bytes: u16 = @as(u16, @intCast(self.bus.data_bus + sum[1])) << 8;
        addr |= high_bytes;

        self.bus.addr_bus = addr;
        self.bus.data_bus = data;
        self.bus.putMmi();
    }
    //GOOD
    pub fn GetIndirectX(self: *Cpu) u8 {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();

        self.bus.addr_bus = self.bus.data_bus +% self.x_register;
        self.bus.getMmo();

        const low_bytes = self.bus.data_bus;

        //high bytes
        self.bus.addr_bus += 1;
        self.bus.getMmo();

        self.bus.addr_bus = self.bus.data_bus;
        self.bus.addr_bus <<= 8;
        self.bus.addr_bus |= low_bytes;

        self.bus.getMmo();

        return self.bus.data_bus;
    }
    //GOOD
    pub fn setIndirectX(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();

        self.bus.addr_bus = self.bus.data_bus +% self.x_register;
        self.bus.getMmo();

        const low_bytes = self.bus.data_bus;

        //high bytes
        self.bus.addr_bus += 1;
        self.bus.getMmo();

        self.bus.addr_bus = self.bus.data_bus;
        self.bus.addr_bus <<= 8;
        self.bus.addr_bus |= low_bytes;

        self.bus.data_bus = data;
        self.bus.putMmi();
    }

    //GOOD
    pub fn GetZeroPageY(self: *Cpu) u8 {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();

        const addr: u8 = self.bus.data_bus +% self.y_register;
        self.bus.addr_bus = addr;
        self.bus.getMmo();

        return self.bus.data_bus;
    }
    //GOOD
    pub fn setZeroPageY(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();

        const addr: u8 = self.bus.data_bus +% self.y_register;
        self.bus.addr_bus = addr;
        self.bus.data_bus = data;

        self.bus.putMmi();
    }
    // GOOD
    pub fn GetZeroPageX(self: *Cpu) u8 {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();

        const addr: u8 = self.bus.data_bus +% self.x_register;
        self.bus.addr_bus = addr;
        self.bus.getMmo();

        return self.bus.data_bus;
    }
    //GOOD
    pub fn setZeroPageX(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();

        const addr: u8 = self.bus.data_bus +% self.x_register;
        self.bus.addr_bus = addr;
        self.bus.data_bus = data;

        self.bus.putMmi();
    }
    //GOOD
    pub fn GetAbsoluteIndexed(self: *Cpu, xory: u1) u8 {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();
        var addr: u16 = self.bus.data_bus;
        self.extra_cycle = 0;
        var addend: u8 = undefined;

        if (xory == 0) {
            addend = self.x_register;
        } else {
            addend = self.y_register;
        }
        const sum = @addWithOverflow(self.bus.data_bus, addend);

        self.bus.addr_bus = self.pc + 2;
        self.bus.getMmo();

        if (sum[1] == 1) {
            self.extra_cycle = 1;
            addr += 0x100;
            addr += sum[0];
        } else {
            addr += sum[0];
        }

        self.bus.addr_bus = addr;
        self.bus.getMmo();
        return self.bus.data_bus;
    }

    pub fn setAbsoluteIndexed(self: *Cpu, xory: u1, data: u8) void {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();
        var addr: u16 = self.bus.data_bus;
        self.extra_cycle = 0;
        var addend: u8 = undefined;

        if (xory == 0) {
            addend = self.x_register;
        } else {
            addend = self.y_register;
        }
        const sum = @addWithOverflow(self.bus.data_bus, addend);

        self.bus.addr_bus = self.pc + 2;
        self.bus.getMmo();

        if (sum[1] == 1) {
            self.extra_cycle = 1;
            addr += 0x100;
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
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();

        self.bus.addr_bus = self.bus.data_bus;
        self.bus.getMmo();

        return self.bus.data_bus;
    }
    //GOOD
    pub fn setZeroPage(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();

        self.bus.addr_bus = self.bus.data_bus;
        self.bus.data_bus = data;
        self.bus.putMmi();
    }
    //GOOD
    pub fn GetImmediate(self: *Cpu) u8 {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();

        return self.bus.data_bus;
    }
    //GOOD
    pub fn setImmediate(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc + 1;
        self.bus.data_bus = data;

        self.bus.putMmi();
    }

    pub fn GetAbsolute(self: *Cpu) u8 {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();

        var addr: u16 = self.bus.data_bus;

        self.bus.addr_bus = self.pc + 2;
        self.bus.getMmo();

        addr |= @as(u16, self.bus.data_bus) << 8;
        std.debug.print("Absolute Address: 0x{X}!\n", .{addr});
        self.bus.addr_bus = addr;
        self.bus.getMmo();

        return self.bus.data_bus;
    }

    pub fn setAbsolute(self: *Cpu, data: u8) void {
        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();

        var addr: u16 = self.bus.data_bus;

        self.bus.addr_bus = self.pc + 2;
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
        std.debug.print("Previous Address: 0x{X}!\n", .{self.pc});

        if (offset >> 7 == 1) {
            unsigned_value = ~(signed_value);
            unsigned_value += 1;
            const difference = @subWithOverflow(low_byte, @as(u8, unsigned_value));
            self.extra_cycle = difference[1];
            self.pc &= 0xFF00;
            self.pc |= difference[0];
            std.debug.print("Difference: {d}\n", .{difference[0]});

            self.pc -= @as(u16, @intCast(self.extra_cycle)) << 8;
        } else {
            const sum = @addWithOverflow(low_byte, @as(u8, signed_value));
            self.extra_cycle = sum[1];
            self.pc &= 0xFF00;
            self.pc |= sum[0];
            self.pc += @as(u16, self.extra_cycle) << 8;
            std.debug.print("New Address: 0x{X}!\n\n", .{self.pc});
        }
    }

    pub fn jump(self: *Cpu, time: i128) void {
        if (self.instruction & 0xF0 == 0x60) {
            //indirect
            self.bus.addr_bus = self.pc + 1;
            self.bus.getMmo();

            const low_byte = self.bus.data_bus;

            self.bus.addr_bus = self.pc + 2;
            self.bus.getMmo();

            self.bus.addr_bus = self.bus.data_bus;
            self.bus.addr_bus <<= 8;
            self.bus.addr_bus |= low_byte;
            self.bus.getMmo();

            var addr: u16 = self.bus.data_bus;
            addr <<= 8;

            self.bus.addr_bus += 1;
            self.bus.getMmo();

            addr |= self.bus.data_bus;
            self.pc = addr;

            self.cycle(time, 5);
        } else {
            //absolute
            self.bus.addr_bus = self.pc + 1;
            self.bus.getMmo();

            const low_byte = self.bus.data_bus;

            self.bus.addr_bus = self.pc + 2;
            self.bus.getMmo();

            self.pc = self.bus.data_bus;
            self.pc <<= 8;
            self.pc |= low_byte;
            self.cycle(time, 3);
        }
    }

    pub fn xToAccumulator(self: *Cpu, time: i128) void {
        self.accumulator = self.x_register;
        if (self.accumulator == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.accumulator >> 7);

        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn yToAccumulator(self: *Cpu, time: i128) void {
        self.accumulator = self.y_register;
        if (self.accumulator == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.accumulator >> 7);

        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn accumulatorToX(self: *Cpu, time: i128) void {
        self.x_register = self.accumulator;
        if (self.x_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.x_register >> 7);

        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn stackPointerToX(self: *Cpu, time: i128) void {
        self.x_register = self.stack_pointer;
        if (self.x_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.x_register >> 7);

        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn xToStackPointer(self: *Cpu, time: i128) void {
        self.stack_pointer = self.x_register;
        if (self.stack_pointer == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.stack_pointer >> 7);

        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn accumulatorToY(self: *Cpu, time: i128) void {
        self.y_register = self.accumulator;
        if (self.y_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.y_register >> 7);

        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn pushAccumulator(self: *Cpu, time: i128) void {
        self.stackPush(self.accumulator);
        self.pc += 1;
        self.cycle(time, 3);
    }

    pub fn pullAccumulator(self: *Cpu, time: i128) void {
        self.accumulator = self.stackPop();
        self.pc += 1;
        self.cycle(time, 4);
    }

    pub fn pullStatus(self: *Cpu, time: i128) void {
        const status = self.stackPop();

        self.status.negative = @truncate(status >> 7);
        self.status.overflow = @truncate((status >> 6) & 0b1);
        self.status.break_inter = @truncate(status >> 5);
        self.status.decimal = @truncate((status >> 4) & 0b1);
        self.status.interrupt_dsble = @truncate((status >> 3) & 0b1);
        self.status.zero = @truncate((status >> 2) & 0b1);
        self.status.carry = @truncate(status & 0b1);

        self.pc += 1;
        self.cycle(time, 4);
    }

    pub fn pushStatus(self: *Cpu, time: i128) void {
        var status: u8 = 0;

        status |= self.status.negative;
        status <<= 1;
        status |= self.status.overflow;
        status <<= 1;
        status |= self.status.break_inter;
        status <<= 2;
        status |= self.status.decimal;
        status <<= 1;
        status |= self.status.interrupt_dsble;
        status <<= 1;
        status |= self.status.zero;
        status <<= 1;
        status |= self.status.carry;
        self.stackPush(status);

        self.pc += 1;
        self.cycle(time, 3);
    }

    pub fn nop(self: *Cpu, time: i128) void {
        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn compareAccumulator(self: *Cpu, time: i128) void {
        var value: u8 = 0;
        if (self.instruction & 0xF0 == 0x50) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    value = self.GetIndirectY();
                    if (self.accumulator == value) {
                        self.status.carry = 1;
                        self.status.zero = 1;
                    } else if (self.accumulator > value) {
                        self.status.carry = 1;
                        self.status.zero = 0;
                    } else {
                        self.status.zero = 0;
                    }

                    self.pc += 2;
                    self.cycle(time, 5 + self.extra_cycle);
                    break :indirecty;
                },
                5 => zero_pagex: {
                    value = self.GetIndirectX();
                    if (self.accumulator == value) {
                        self.status.carry = 1;
                        self.status.zero = 1;
                    } else if (self.accumulator > value) {
                        self.status.carry = 1;
                        self.status.zero = 0;
                    } else {
                        self.status.zero = 0;
                    }

                    self.pc += 2;
                    self.cycle(time, 4);
                    break :zero_pagex;
                },
                9 => absolutey: {
                    value = self.GetAbsoluteIndexed(1);
                    if (self.accumulator == value) {
                        self.status.carry = 1;
                        self.status.zero = 1;
                    } else if (self.accumulator > value) {
                        self.status.carry = 1;
                        self.status.zero = 0;
                    } else {
                        self.status.zero = 0;
                    }

                    self.pc += 3;
                    self.cycle(time, 4 + self.extra_cycle);
                    break :absolutey;
                },
                0xD => absolutex: {
                    value = self.GetAbsoluteIndexed(1);
                    if (self.accumulator == value) {
                        self.status.carry = 1;
                        self.status.zero = 1;
                    } else if (self.accumulator > value) {
                        self.status.carry = 1;
                        self.status.zero = 0;
                    } else {
                        self.status.zero = 0;
                    }

                    self.pc += 3;
                    self.cycle(time, 4 + self.extra_cycle);
                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Logical XOR)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    value = self.GetIndirectX();
                    if (self.accumulator == value) {
                        self.status.carry = 1;
                        self.status.zero = 1;
                    } else if (self.accumulator > value) {
                        self.status.carry = 1;
                        self.status.zero = 0;
                    } else {
                        self.status.zero = 0;
                    }

                    self.pc += 2;
                    self.cycle(time, 6);
                    break :indirectx;
                },
                5 => zero_page: {
                    value = self.GetZeroPage();
                    if (self.accumulator == value) {
                        self.status.carry = 1;
                        self.status.zero = 1;
                    } else if (self.accumulator > value) {
                        self.status.carry = 1;
                        self.status.zero = 0;
                    } else {
                        self.status.zero = 0;
                    }

                    self.pc += 2;
                    self.cycle(time, 3);
                    break :zero_page;
                },
                9 => immediate: {
                    value = self.GetImmediate();
                    if (self.accumulator == value) {
                        self.status.carry = 1;
                        self.status.zero = 1;
                    } else if (self.accumulator > value) {
                        self.status.carry = 1;
                        self.status.zero = 0;
                    } else {
                        self.status.zero = 0;
                    }

                    self.pc += 2;
                    self.cycle(time, 2);
                    break :immediate;
                },
                0xD => absolute: {
                    value = self.GetAbsolute();
                    if (self.accumulator == value) {
                        self.status.carry = 1;
                        self.status.zero = 1;
                    } else if (self.accumulator > value) {
                        self.status.carry = 1;
                        self.status.zero = 0;
                    } else {
                        self.status.zero = 0;
                    }

                    self.pc += 3;
                    self.cycle(time, 4);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Logical XOR)!\n", .{});
                    break :default;
                },
            }
        }
        if (self.accumulator == value) {
            self.status.negative = 0;
        } else {
            self.status.negative = @truncate(self.accumulator -% value >> 7);
        }
    }

    pub fn compareYRegister(self: *Cpu, time: i128) void {
        var value: u8 = 0;
        switch (self.instruction & 0xF) {
            0 => immediate: {
                value = self.GetImmediate();
                if (self.y_register == value) {
                    self.status.carry = 1;
                    self.status.zero = 1;
                } else if (self.y_register > value) {
                    self.status.carry = 1;
                    self.status.zero = 0;
                } else {
                    self.status.zero = 0;
                }

                self.pc += 2;
                self.cycle(time, 2);
                break :immediate;
            },
            4 => zeropage: {
                value = self.GetZeroPage();
                if (self.y_register == value) {
                    self.status.carry = 1;
                    self.status.zero = 1;
                } else if (self.y_register > value) {
                    self.status.carry = 1;
                    self.status.zero = 0;
                } else {
                    self.status.zero = 0;
                }

                self.pc += 2;
                self.cycle(time, 3);
                break :zeropage;
            },
            0xC => absolute: {
                value = self.GetAbsolute();
                if (self.y_register == value) {
                    self.status.carry = 1;
                    self.status.zero = 1;
                } else if (self.y_register > value) {
                    self.status.carry = 1;
                    self.status.zero = 0;
                } else {
                    self.status.zero = 0;
                }

                self.pc += 3;
                self.cycle(time, 4);
                break :absolute;
            },
            else => default: {
                std.debug.print("No Valid Addressing Mode Found (Compare Y Register)!\n", .{});
                break :default;
            },
        }
        if (self.y_register == value) {
            self.status.negative = 0;
        } else {
            self.status.negative = @truncate(self.y_register -% value >> 7);
        }
    }

    pub fn compareXRegister(self: *Cpu, time: i128) void {
        var value: u8 = 0;
        switch (self.instruction & 0xF) {
            0 => immediate: {
                value = self.GetImmediate();
                if (self.x_register == value) {
                    self.status.carry = 1;
                    self.status.zero = 1;
                } else if (self.x_register > value) {
                    self.status.carry = 1;
                    self.status.zero = 0;
                } else {
                    self.status.zero = 0;
                }

                self.pc += 2;
                self.cycle(time, 2);
                break :immediate;
            },
            4 => zeropage: {
                value = self.GetZeroPage();
                if (self.x_register == value) {
                    self.status.carry = 1;
                    self.status.zero = 1;
                } else if (self.x_register > value) {
                    self.status.carry = 1;
                    self.status.zero = 0;
                } else {
                    self.status.zero = 0;
                }

                self.pc += 2;
                self.cycle(time, 3);
                break :zeropage;
            },
            0xC => absolute: {
                value = self.GetAbsolute();
                if (self.x_register == value) {
                    self.status.carry = 1;
                    self.status.zero = 1;
                } else if (self.x_register > value) {
                    self.status.carry = 1;
                    self.status.zero = 0;
                } else {
                    self.status.zero = 0;
                }

                self.pc += 3;
                self.cycle(time, 4);
                break :absolute;
            },
            else => default: {
                std.debug.print("No Valid Addressing Mode Found (Compare X Register)!\n", .{});
                break :default;
            },
        }
        if (self.x_register == value) {
            self.status.negative = 0;
        } else {
            self.status.negative = @truncate(self.x_register -% value >> 7);
        }
    }

    pub fn branchNoCarry(self: *Cpu, time: i128) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        if (self.status.carry == 0) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc += 2;
        self.cycle(time, self.extra_cycle + 2 + success);
    }

    pub fn branchOnCarry(self: *Cpu, time: i128) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        if (self.status.carry == 1) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc += 2;
        self.cycle(time, self.extra_cycle + success);
    }

    pub fn branchOnZero(self: *Cpu, time: i128) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        std.debug.print("Zero Status: {d}\n\n", .{self.status.zero});

        if (self.status.zero == 1) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc += 2;
        self.cycle(time, self.extra_cycle + 2 + success);
    }

    pub fn branchNoZero(self: *Cpu, time: i128) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        std.debug.print("Zero Status: {d}\n\n", .{self.status.zero});

        if (self.status.zero == 0) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc += 2;
        const cycles = 2 + @as(u8, success) + self.extra_cycle;
        self.cycle(time, cycles);
    }

    pub fn branchNoNegative(self: *Cpu, time: i128) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        if (self.status.negative == 0) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc += 2;
        self.cycle(time, self.extra_cycle + 2 + success);
    }

    pub fn branchOnNegative(self: *Cpu, time: i128) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        if (self.status.negative == 1) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc += 2;
        self.cycle(time, self.extra_cycle + 2 + success);
    }

    pub fn branchNoOverflow(self: *Cpu, time: i128) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        if (self.status.overflow == 0) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc += 2;
        self.cycle(time, self.extra_cycle + 2 + success);
    }

    pub fn branchOnOverflow(self: *Cpu, time: i128) void {
        var success: u1 = undefined;
        self.extra_cycle = 0;

        if (self.status.overflow == 1) {
            self.branchRelative();
            success = 1;
        } else {
            success = 0;
        }
        self.pc += 2;
        self.cycle(time, self.extra_cycle + 2 + success);
    }

    pub fn increment(self: *Cpu, time: i128) void {
        var value: u8 = 0;
        if (self.instruction & 0xF0 == 0xF0) {
            switch (self.instruction & 0xF) {
                6 => zeropagex: {
                    value = self.GetZeroPageX() +% 1;
                    self.setZeroPageX(value);
                    self.pc += 2;
                    self.cycle(time, 6);
                    break :zeropagex;
                },
                0xE => absolutex: {
                    value = self.GetAbsoluteIndexed(0) +% 1;
                    self.setAbsoluteIndexed(0, value);
                    self.pc += 3;
                    self.cycle(time, 7);
                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Valid Addressing Mode found (Increment)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                6 => zeropage: {
                    value = self.GetZeroPageX() +% 1;
                    self.setZeroPage(value);
                    self.pc += 2;
                    self.cycle(time, 5);
                    break :zeropage;
                },
                0xE => absolute: {
                    value = self.GetAbsolute() +% 1;
                    self.setAbsolute(value);
                    self.pc += 3;
                    self.cycle(time, 6);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Valid Addressing Mode found (Increment)!\n", .{});
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

    pub fn incrementXRegister(self: *Cpu, time: i128) void {
        self.x_register +%= 1;
        if (self.x_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.x_register >> 7);

        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn incrementYRegister(self: *Cpu, time: i128) void {
        self.y_register +%= 1;
        if (self.y_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.y_register >> 7);

        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn decrement(self: *Cpu, time: i128) void {
        var value: u8 = 0;
        if (self.instruction & 0xF0 == 0xD0) {
            switch (self.instruction & 0xF) {
                6 => zeropagex: {
                    value = self.GetZeroPageX() -% 1;
                    self.setZeroPageX(value);
                    self.pc += 2;
                    self.cycle(time, 6);
                    break :zeropagex;
                },
                0xE => absolutex: {
                    value = self.GetAbsoluteIndexed(0) -% 1;
                    self.setAbsoluteIndexed(0, value);
                    self.pc += 3;
                    self.cycle(time, 7);
                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Valid Addressing Mode found (Increment)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                6 => zeropage: {
                    value = self.GetZeroPageX() -% 1;
                    self.setZeroPage(value);
                    self.pc += 2;
                    self.cycle(time, 5);
                    break :zeropage;
                },
                0xE => absolute: {
                    value = self.GetAbsolute() -% 1;
                    self.setAbsolute(value);
                    self.pc += 3;
                    self.cycle(time, 6);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Valid Addressing Mode found (Increment)!\n", .{});
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

    pub fn decrementY(self: *Cpu, time: i128) void {
        self.y_register -%= 1;

        if (self.y_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.y_register >> 7);

        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn decrementX(self: *Cpu, time: i128) void {
        self.x_register -%= 1;

        if (self.x_register == 0) {
            self.status.zero = 1;
        } else {
            self.status.zero = 0;
        }
        self.status.negative = @truncate(self.x_register >> 7);

        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn loadXRegister(self: *Cpu, time: i128) void {
        if (self.instruction & 0xF0 == 0xA0) {
            switch (self.instruction & 0xF) {
                2 => immediate: {
                    self.x_register = self.GetImmediate();
                    self.pc += 2;
                    self.cycle(time, 2);
                    break :immediate;
                },
                6 => zeropage: {
                    self.x_register = self.GetZeroPage();
                    self.pc += 2;
                    self.cycle(time, 3);
                    break :zeropage;
                },
                0xE => absolute: {
                    self.x_register = self.GetAbsolute();
                    self.pc += 3;
                    self.cycle(time, 4);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Valid Addressing Mode found (Load Y Register)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                0x6 => zeropagey: {
                    self.y_register = self.GetZeroPageY();
                    self.pc += 2;
                    self.cycle(time, 4);
                    break :zeropagey;
                },
                0xE => absolutey: {
                    self.y_register = self.GetAbsoluteIndexed(1);
                    self.pc += 3;
                    self.cycle(time, 4 + self.extra_cycle);
                    break :absolutey;
                },
                else => default: {
                    std.debug.print("No Valid Addressing Mode found (Load Y Register)!\n", .{});
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

    pub fn loadYRegister(self: *Cpu, time: i128) void {
        if (self.instruction & 0xF0 == 0xA0) {
            switch (self.instruction & 0xF) {
                0 => immediate: {
                    self.y_register = self.GetImmediate();
                    self.pc += 2;
                    self.cycle(time, 2);
                    break :immediate;
                },
                4 => zeropage: {
                    self.y_register = self.GetZeroPage();
                    self.pc += 2;
                    self.cycle(time, 3);
                    break :zeropage;
                },
                0xC => absolute: {
                    self.y_register = self.GetAbsolute();
                    self.pc += 3;
                    self.cycle(time, 4);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Valid Addressing Mode found (Load Y Register)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                0x4 => zeropagex: {
                    self.y_register = self.GetZeroPageX();
                    self.pc += 2;
                    self.cycle(time, 4);
                    break :zeropagex;
                },
                0xC => absolutex: {
                    self.y_register = self.GetAbsoluteIndexed(0);
                    self.pc += 3;
                    self.cycle(time, 4 + self.extra_cycle);
                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Valid Addressing Mode found (Load Y Register)!\n", .{});
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

    pub fn forceInterrupt(self: *Cpu, time: i128) void {
        self.stackPushAddress(self.pc + 1);
        self.pushStatus(time);

        const new_time = std.time.nanoTimestamp();
        self.status.break_inter = 1;
        self.pc = 0xFFFD;
        //little endian
        var address: u16 = self.GetImmediate();
        self.pc += 1;
        address |= @as(u16, self.GetImmediate()) << 8;

        self.pc = address;
        self.cycle(new_time, 4);
    }

    pub fn interruptRequest(self: *Cpu, time: i128, vector: u16) void {
        self.stackPushAddress(self.pc);
        self.pushStatus(time);

        const new_time = std.time.nanoTimestamp();
        self.pc = vector - 1;
        var address: u16 = self.GetImmediate();
        self.pc += 1;
        address |= @as(u16, self.GetImmediate()) << 8;

        self.pc = address;
        self.cycle(new_time, 4);
    }

    pub fn returnInterrupt(self: *Cpu, time: i128) void {
        const status = self.stackPop();
        self.status.negative = @truncate(status >> 7);
        self.status.overflow = @truncate((status >> 6) & 0b1);
        self.status.break_inter = @truncate(status >> 5);
        self.status.decimal = @truncate((status >> 4) & 0b1);
        self.status.interrupt_dsble = @truncate((status >> 3) & 0b1);
        self.status.zero = @truncate((status >> 2) & 0b1);
        self.status.carry = @truncate(status & 0b1);
        self.pc = self.stackPopAddress();
        self.cycle(time, 6);
    }

    pub fn jumpSubroutine(self: *Cpu, time: i128) void {
        self.stackPushAddress(self.pc + 3);
        std.debug.print("Return Address: 0x{X}\n\n", .{self.pc + 3});

        self.bus.addr_bus = self.pc + 1;
        self.bus.getMmo();

        var addr: u16 = self.bus.data_bus;

        self.bus.addr_bus = self.pc + 2;
        self.bus.getMmo();

        addr |= @as(u16, self.bus.data_bus) << 8;

        self.pc = addr;
        std.debug.print("Stack Pointer: 0x{X}\n", .{self.stack_pointer});

        self.cycle(time, 6);
    }

    pub fn returnSubroutine(self: *Cpu, time: i128) void {
        self.pc = self.stackPopAddress();
        std.debug.print("Stack Pointer: 0x{X}\n", .{self.stack_pointer});
        self.cycle(time, 6);
    }

    pub fn subtractWithCarry(self: *Cpu, time: i128) void {
        if (self.instruction & 0xF0 == 0xF0) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    const negative: u1 = @intCast(self.accumulator >> 7);
                    const carry = 1 - self.status.carry;

                    const operation1 = @subWithOverflow(self.accumulator, self.GetIndirectY());
                    const difference = @subWithOverflow(operation1[0], carry);

                    self.accumulator = difference[0];
                    if (operation1[1] == 1 or difference[1] == 1) {
                        self.status.carry = 0;
                    } else {
                        self.status.carry = 1;
                    }
                    if (negative != difference[0] >> 7) {
                        self.status.overflow = 1;
                    } else {
                        self.status.overflow = 0;
                    }

                    self.pc += 2;
                    self.cycle(time, 5 + @as(u8, self.extra_cycle));
                    break :indirecty;
                },
                5 => zero_pagex: {
                    const negative: u1 = @intCast(self.accumulator >> 7);
                    const carry = 1 - self.status.carry;

                    const operation1 = @subWithOverflow(self.accumulator, self.GetZeroPageX());
                    const difference = @subWithOverflow(operation1[0], carry);

                    self.accumulator = difference[0];
                    if (operation1[1] == 1 or difference[1] == 1) {
                        self.status.carry = 0;
                    } else {
                        self.status.carry = 1;
                    }
                    if (negative != difference[0] >> 7) {
                        self.status.overflow = 1;
                    } else {
                        self.status.overflow = 0;
                    }
                    self.pc += 2;
                    self.cycle(time, 4);
                    break :zero_pagex;
                },
                9 => absolutey: {
                    const negative: u1 = @intCast(self.accumulator >> 7);
                    const carry = 1 - self.status.carry;

                    const operation1 = @subWithOverflow(self.accumulator, self.GetAbsoluteIndexed(1));
                    const difference = @subWithOverflow(operation1[0], carry);

                    self.accumulator = difference[0];
                    if (operation1[1] == 1 or difference[1] == 1) {
                        self.status.carry = 0;
                    } else {
                        self.status.carry = 1;
                    }
                    if (negative != difference[0] >> 7) {
                        self.status.overflow = 1;
                    } else {
                        self.status.overflow = 0;
                    }

                    self.pc += 3;
                    self.cycle(time, 4 + @as(u8, self.extra_cycle));
                    break :absolutey;
                },
                0xD => absolutex: {
                    const negative: u1 = @intCast(self.accumulator >> 7);
                    const carry = 1 - self.status.carry;

                    const operation1 = @subWithOverflow(self.accumulator, self.GetAbsoluteIndexed(0));
                    const difference = @subWithOverflow(operation1[0], carry);

                    self.accumulator = difference[0];
                    if (operation1[1] == 1 or difference[1] == 1) {
                        self.status.carry = 0;
                    } else {
                        self.status.carry = 1;
                    }

                    if (negative != difference[0] >> 7) {
                        self.status.overflow = 1;
                    } else {
                        self.status.overflow = 0;
                    }

                    self.pc += 3;
                    self.cycle(time, 4 + @as(u8, self.extra_cycle));
                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Add With Carry)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    const negative: u1 = @intCast(self.accumulator >> 7);
                    const carry = 1 - self.status.carry;

                    const operation1 = @subWithOverflow(self.accumulator, self.GetIndirectX());
                    const difference = @subWithOverflow(operation1[0], carry);

                    self.accumulator = difference[0];
                    if (operation1[1] == 1 or difference[1] == 1) {
                        self.status.carry = 0;
                    } else {
                        self.status.carry = 1;
                    }

                    if (negative != difference[0] >> 7) {
                        self.status.overflow = 1;
                    } else {
                        self.status.overflow = 0;
                    }

                    self.pc += 2;
                    self.cycle(time, 6);
                    break :indirectx;
                },
                5 => zero_page: {
                    const negative: u1 = @intCast(self.accumulator >> 7);
                    const carry = 1 - self.status.carry;

                    const operation1 = @subWithOverflow(self.accumulator, self.GetZeroPage());
                    const difference = @subWithOverflow(operation1[0], carry);

                    self.accumulator = difference[0];
                    if (operation1[1] == 1 or difference[1] == 1) {
                        self.status.carry = 0;
                    } else {
                        self.status.carry = 1;
                    }

                    if (negative != difference[0] >> 7) {
                        self.status.overflow = 1;
                    } else {
                        self.status.carry = 1;
                    }
                    self.pc += 2;
                    self.cycle(time, 3);
                    break :zero_page;
                },
                9 => immediate: {
                    const negative: u1 = @intCast(self.accumulator >> 7);
                    const carry = 1 - self.status.carry;

                    const operation1 = @subWithOverflow(self.accumulator, self.GetImmediate());
                    const difference = @subWithOverflow(operation1[0], carry);

                    self.accumulator = difference[0];
                    if (operation1[1] == 1 or difference[1] == 1) {
                        self.status.carry = 0;
                    } else {
                        self.status.carry = 1;
                    }
                    if (negative != difference[0] >> 7) {
                        self.status.overflow = 1;
                    } else {
                        self.status.overflow = 0;
                    }
                    self.pc += 2;
                    self.cycle(time, 2);
                    break :immediate;
                },
                0xD => absolute: {
                    const negative: u1 = @intCast(self.accumulator >> 7);
                    const carry = 1 - self.status.carry;

                    const operation1 = @subWithOverflow(self.accumulator, self.GetAbsolute());
                    const difference = @subWithOverflow(operation1[0], carry);

                    self.accumulator = difference[0];
                    if (operation1[1] == 1 or difference[1] == 1) {
                        self.status.carry = 0;
                    } else {
                        self.status.carry = 1;
                    }
                    if (negative != difference[0] >> 7) {
                        self.status.overflow = 1;
                    } else {
                        self.status.overflow = 0;
                    }

                    self.pc += 3;
                    self.cycle(time, 4);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Add With Carry)!\n", .{});
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

    pub fn loadAccumulator(self: *Cpu, time: i128) void {
        if (self.instruction & 0xF0 == 0xB0) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    self.accumulator = self.GetIndirectY();
                    self.pc += 2;
                    self.cycle(time, 5 + @as(u8, self.extra_cycle));
                    break :indirecty;
                },
                5 => zero_pagex: {
                    self.accumulator = self.GetZeroPageX();
                    self.pc += 2;
                    self.cycle(time, 4);
                    break :zero_pagex;
                },
                9 => absolutey: {
                    self.accumulator = self.GetAbsoluteIndexed(1);
                    self.pc += 3;
                    self.cycle(time, 4 + @as(u8, self.extra_cycle));
                    break :absolutey;
                },
                0xD => absolutex: {
                    self.accumulator = self.GetAbsoluteIndexed(0);
                    self.pc += 3;
                    self.cycle(time, 4 + @as(u8, self.extra_cycle));
                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Load Accumulator)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    self.accumulator = self.GetIndirectX();
                    self.pc += 2;
                    self.cycle(time, 6);
                    break :indirectx;
                },
                5 => zero_page: {
                    self.accumulator = self.GetZeroPage();
                    self.pc += 2;
                    self.cycle(time, 3);
                    break :zero_page;
                },
                9 => immediate: {
                    self.accumulator = self.GetImmediate();
                    self.pc += 2;
                    self.cycle(time, 2);
                    break :immediate;
                },
                0xD => absolute: {
                    self.accumulator = self.GetAbsolute();
                    self.pc += 3;
                    self.cycle(time, 4);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Load Accumulator)!\n", .{});
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
        std.debug.print("Accumulator: 0x{X}\n\n", .{self.accumulator});
    }

    pub fn storeYRegister(self: *Cpu, time: i128) void {
        if (self.instruction & 0xF0 == 0x90) {
            self.setZeroPageX(self.y_register);
            self.pc += 2;
            self.cycle(time, 4);
        } else {
            switch (self.instruction & 0xF) {
                4 => zeropage: {
                    self.setZeroPage(self.y_register);
                    self.pc += 2;
                    self.cycle(time, 3);
                    break :zeropage;
                },
                0xC => absolute: {
                    self.setAbsolute(self.y_register);
                    self.pc += 3;
                    self.cycle(time, 4);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Valid Addresing mode found (Store Y Register!\n", .{});
                    break :default;
                },
            }
        }
    }

    pub fn storeXRegister(self: *Cpu, time: i128) void {
        if (self.instruction & 0xF0 == 0x90) {
            self.setZeroPageY(self.x_register);
            self.pc += 2;
            self.cycle(time, 4);
        } else {
            switch (self.instruction & 0xF) {
                6 => zeropage: {
                    self.setZeroPage(self.x_register);
                    self.pc += 2;
                    self.cycle(time, 3);
                    break :zeropage;
                },
                0xE => absolute: {
                    self.setAbsolute(self.x_register);
                    self.pc += 3;
                    self.cycle(time, 4);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Valid Addresing mode found (Store X Register!\n", .{});
                    break :default;
                },
            }
        }
    }

    pub fn storeAccumulator(self: *Cpu, time: i128) void {
        if (self.instruction & 0xF0 == 0x90) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    self.setIndirectY(self.accumulator);
                    self.pc += 2;
                    self.cycle(time, 6);
                    break :indirecty;
                },
                5 => zero_pagex: {
                    self.setZeroPageX(self.accumulator);
                    self.pc += 2;
                    self.cycle(time, 4);
                    break :zero_pagex;
                },
                9 => absolutey: {
                    self.setAbsoluteIndexed(1, self.accumulator);
                    self.pc += 3;
                    self.cycle(time, 5);
                    break :absolutey;
                },
                0xD => absolutex: {
                    self.setAbsoluteIndexed(0, self.accumulator);
                    self.pc += 3;
                    self.cycle(time, 5);
                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Logical XOR)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    self.setIndirectX(self.accumulator);
                    self.pc += 2;
                    self.cycle(time, 6);
                    break :indirectx;
                },
                5 => zero_page: {
                    self.setZeroPage(self.accumulator);
                    self.pc += 2;
                    self.cycle(time, 3);
                    break :zero_page;
                },
                0xD => absolute: {
                    self.setAbsolute(self.accumulator);
                    self.pc += 3;
                    self.cycle(time, 4);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Logical XOR)!\n", .{});
                    break :default;
                },
            }
        }
    }

    pub fn logicalShiftRight(self: *Cpu, time: i128) void {
        var result: u8 = 0;
        if (self.instruction & 0xF0 == 0x50) {
            switch (self.instruction & 0xF) {
                6 => zeropagex: {
                    const value = self.GetZeroPageX();
                    result = value >> 1;
                    self.setZeroPageX(result);

                    self.status.carry = @truncate(value & 0b1);

                    self.pc += 2;
                    self.cycle(time, 6);

                    break :zeropagex;
                },
                0xE => absolutex: {
                    const value = self.GetAbsoluteIndexed(0);
                    result = value >> 1;
                    self.setAbsoluteIndexed(0, result);

                    self.status.carry = @truncate(value & 0b1);

                    self.pc += 3;
                    self.cycle(time, 7);

                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
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

                    self.pc += 2;
                    self.cycle(time, 5);

                    break :zeropage;
                },
                0xA => accumulator: {
                    self.status.carry = @truncate(self.accumulator & 0b1);
                    result = self.accumulator >> 1;
                    self.accumulator = result;

                    self.pc += 1;
                    self.cycle(time, 2);
                    break :accumulator;
                },
                0xE => absolute: {
                    const value = self.GetAbsolute();
                    result = value >> 1;
                    self.setAbsolute(result);

                    self.status.carry = @truncate(value & 0b1);

                    self.pc += 3;
                    self.cycle(time, 6);

                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
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

    pub fn rotateLeft(self: *Cpu, time: i128) void {
        var result: u8 = 0;
        if (self.instruction & 0xF0 == 0x50) {
            switch (self.instruction & 0xF) {
                6 => zeropagex: {
                    const value = self.GetZeroPageX();
                    result = value << 1;
                    result |= self.status.carry;

                    self.status.carry = @truncate(value >> 7);

                    self.setZeroPageX(result);

                    self.pc += 2;
                    self.cycle(time, 6);

                    break :zeropagex;
                },
                0xE => absolutex: {
                    const value = self.GetAbsoluteIndexed(0);
                    result = value << 1;
                    result |= self.status.carry;

                    self.status.carry = @truncate(value >> 7);

                    self.setAbsoluteIndexed(0, result);

                    self.pc += 3;
                    self.cycle(time, 7);

                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
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

                    self.pc += 2;
                    self.cycle(time, 5);

                    break :zeropage;
                },
                0xA => accumulator: {
                    const carry = self.status.carry;
                    self.status.carry = @truncate(self.accumulator >> 7);

                    result = self.accumulator << 1;
                    result |= carry;
                    self.accumulator = result;

                    self.pc += 1;
                    self.cycle(time, 2);
                    break :accumulator;
                },
                0xE => absolute: {
                    const value = self.GetAbsolute();
                    result = value << 1;
                    result |= self.status.carry;

                    self.status.carry = @truncate(value >> 7);

                    self.setAbsolute(result);

                    self.pc += 3;
                    self.cycle(time, 6);

                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
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

    pub fn rotateRight(self: *Cpu, time: i128) void {
        var result: u8 = 0;
        if (self.instruction & 0xF0 == 0x50) {
            switch (self.instruction & 0xF) {
                6 => zeropagex: {
                    const value = self.GetZeroPageX();
                    result = value >> 1;
                    result |= @as(u8, self.status.carry) << 7;

                    self.status.carry = @truncate(value & 0b1);

                    self.setZeroPageX(result);

                    self.pc += 2;
                    self.cycle(time, 6);

                    break :zeropagex;
                },
                0xE => absolutex: {
                    const value = self.GetAbsoluteIndexed(0);
                    result = value >> 1;
                    result |= @as(u8, self.status.carry) << 7;

                    self.status.carry = @truncate(value & 0b1);

                    self.setAbsoluteIndexed(0, result);

                    self.pc += 3;
                    self.cycle(time, 7);

                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
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

                    self.pc += 2;
                    self.cycle(time, 5);

                    break :zeropage;
                },
                0xA => accumulator: {
                    const carry: u8 = self.status.carry;
                    self.status.carry = @truncate(self.accumulator & 0b1);
                    result = self.accumulator >> 1;
                    result |= carry << 7;
                    self.accumulator = result;

                    self.pc += 1;
                    self.cycle(time, 2);
                    break :accumulator;
                },
                0xE => absolute: {
                    const value = self.GetAbsolute();
                    result = value >> 1;
                    result |= @as(u8, self.status.carry) << 7;

                    self.status.carry = @truncate(value & 0b1);

                    self.setAbsolute(result);

                    self.pc += 3;
                    self.cycle(time, 6);

                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
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

    pub fn arithmeticShiftLeft(self: *Cpu, time: i128) void {
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

                    self.pc += 2;
                    self.cycle(time, 6);

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

                    self.pc += 3;
                    self.cycle(time, 7);
                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
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

                    self.pc += 2;
                    self.cycle(time, 5);
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

                    self.pc += 1;
                    self.cycle(time, 2);
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

                    self.pc += 3;
                    self.cycle(time, 6);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Arithmetic Shift Left)!\n", .{});
                    break :default;
                },
            }
        }
    }

    pub fn addWithCarry(self: *Cpu, time: i128) void {
        if (self.instruction & 0xF0 == 0x70) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    const negative: u1 = @truncate(self.accumulator >> 7);
                    const carry = @addWithOverflow(self.accumulator, self.status.carry);
                    const sum = @addWithOverflow(self.GetIndirectY(), carry[0]);

                    if (carry[1] == 1 or sum[1] == 1) {
                        self.status.carry = 1;
                    } else {
                        self.status.carry = 0;
                    }
                    self.accumulator = sum[0];
                    if (negative != sum[0] >> 7) {
                        self.status.overflow = 1;
                    }

                    self.pc += 2;
                    self.cycle(time, @as(u8, self.extra_cycle) + 5);
                    break :indirecty;
                },
                5 => zero_pagex: {
                    const negative: u1 = @truncate(self.accumulator >> 7);
                    const carry = @addWithOverflow(self.accumulator, self.status.carry);
                    const sum = @addWithOverflow(self.GetIndirectY(), carry[0]);

                    if (carry[1] == 1 or sum[1] == 1) {
                        self.status.carry = 1;
                    } else {
                        self.status.carry = 0;
                    }

                    self.accumulator = sum[0];
                    if (negative != sum[0] >> 7) {
                        self.status.overflow = 1;
                    }

                    self.pc += 2;
                    self.cycle(time, 4);
                    break :zero_pagex;
                },
                9 => absolutey: {
                    const negative: u1 = @truncate(self.accumulator >> 7);
                    const carry = @addWithOverflow(self.accumulator, self.status.carry);
                    const sum = @addWithOverflow(self.GetIndirectY(), carry[0]);

                    if (carry[1] == 1 or sum[1] == 1) {
                        self.status.carry = 1;
                    } else {
                        self.status.carry = 0;
                    }
                    self.accumulator = sum[0];
                    if (negative != sum[0] >> 7) {
                        self.status.overflow = 1;
                    } else {
                        self.status.carry = 0;
                    }

                    self.pc += 3;
                    self.cycle(time, 4 + @as(u8, self.extra_cycle));
                    break :absolutey;
                },
                0xD => absolutex: {
                    const negative: u1 = @truncate(self.accumulator >> 7);
                    const carry = @addWithOverflow(self.accumulator, self.status.carry);
                    const sum = @addWithOverflow(self.GetIndirectY(), carry[0]);

                    if (carry[1] == 1 or sum[1] == 1) {
                        self.status.carry = 1;
                    } else {
                        self.status.carry = 0;
                    }
                    self.accumulator = sum[0];
                    if (negative != sum[0] >> 7) {
                        self.status.overflow = 1;
                    }

                    self.pc += 3;
                    self.cycle(time, 4 + @as(u8, self.extra_cycle));
                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Add With Carry)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    const negative: u1 = @truncate(self.accumulator >> 7);
                    const carry = @addWithOverflow(self.accumulator, self.status.carry);
                    const sum = @addWithOverflow(self.GetIndirectY(), carry[0]);

                    if (carry[1] == 1 or sum[1] == 1) {
                        self.status.carry = 1;
                    } else {
                        self.status.carry = 0;
                    }

                    self.accumulator = sum[0];
                    if (negative != sum[0] >> 7) {
                        self.status.overflow = 1;
                    } else {
                        self.status.overflow = 0;
                    }

                    self.pc += 2;
                    self.cycle(time, 6);
                    break :indirectx;
                },
                5 => zero_page: {
                    const negative: u1 = @truncate(self.accumulator >> 7);
                    const carry = @addWithOverflow(self.accumulator, self.status.carry);
                    const sum = @addWithOverflow(self.GetIndirectY(), carry[0]);

                    if (carry[1] == 1 or sum[1] == 1) {
                        self.status.carry = 1;
                    } else {
                        self.status.carry = 0;
                    }

                    self.accumulator = sum[0];
                    if (negative != sum[0] >> 7) {
                        self.status.overflow = 1;
                    } else {
                        self.status.overflow = 0;
                    }

                    self.pc += 2;
                    self.cycle(time, 3);
                    break :zero_page;
                },
                9 => immediate: {
                    const negative: u1 = @truncate(self.accumulator >> 7);
                    const carry = @addWithOverflow(self.accumulator, self.status.carry);
                    const sum = @addWithOverflow(self.GetIndirectY(), carry[0]);

                    if (carry[1] == 1 or sum[1] == 1) {
                        self.status.carry = 1;
                    } else {
                        self.status.carry = 0;
                    }
                    self.accumulator = sum[0];
                    if (negative != sum[0] >> 7) {
                        self.status.overflow = 1;
                    } else {
                        self.status.overflow = 0;
                    }

                    self.pc += 2;
                    self.cycle(time, 2);
                    break :immediate;
                },
                0xD => absolute: {
                    const negative: u1 = @truncate(self.accumulator >> 7);
                    const carry = @addWithOverflow(self.accumulator, self.status.carry);
                    const sum = @addWithOverflow(self.GetIndirectY(), carry[0]);

                    if (carry[1] == 1 or sum[1] == 1) {
                        self.status.carry = 1;
                    } else {
                        self.status.carry = 0;
                    }
                    self.accumulator = sum[0];
                    if (negative != sum[0] >> 7) {
                        self.status.overflow = 1;
                    } else {
                        self.status.overflow = 0;
                    }

                    self.pc += 3;
                    self.cycle(time, 4);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Add With Carry)!\n", .{});
                    break :default;
                },
            }
            if (self.accumulator == 0) {
                self.status.zero = 1;
            } else {
                self.status.zero = 0;
            }
            self.status.negative = @intCast(self.accumulator >> 7);
        }
    }

    pub fn clearCarry(self: *Cpu, time: i128) void {
        self.status.carry = 0;
        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn clearDecimal(self: *Cpu, time: i128) void {
        self.status.decimal = 0;
        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn clearInterrupt(self: *Cpu, time: i128) void {
        self.status.interrupt_dsble = 0;
        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn clearOverflow(self: *Cpu, time: i128) void {
        self.status.overflow = 0;
        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn setCarry(self: *Cpu, time: i128) void {
        self.status.carry = 1;
        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn setDecimal(self: *Cpu, time: i128) void {
        self.status.decimal = 1;
        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn setInterrupt(self: *Cpu, time: i128) void {
        self.status.interrupt_dsble = 1;
        self.pc += 1;
        self.cycle(time, 2);
    }

    pub fn bitTest(self: *Cpu, time: i128) void {
        switch (self.instruction & 0xF) {
            4 => zero_page: {
                const value = self.GetZeroPage() & self.accumulator;

                self.status.negative = @truncate(value >> 7);
                self.status.overflow = @truncate((value & 0x40) >> 6);
                if (value == 0) {
                    self.status.zero = 1;
                } else {
                    self.status.zero = 0;
                }

                self.pc += 2;
                self.cycle(time, 3);
                break :zero_page;
            },
            0xC => absolute: {
                const value = self.GetAbsolute() & self.accumulator;

                self.status.negative = @truncate(value >> 7);
                self.status.overflow = @truncate((value & 0x40) >> 6);
                if (value == 0) {
                    self.status.zero = 1;
                } else {
                    self.status.zero = 0;
                }

                self.pc += 3;
                self.cycle(time, 4);
                break :absolute;
            },
            else => default: {
                std.debug.print("No Addressing Mode found (Bit Test)!\n", .{});
                break :default;
            },
        }
    }

    pub fn exclusiveOr(self: *Cpu, time: i128) void {
        if (self.instruction & 0xF0 == 0x50) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    self.accumulator ^= self.GetIndirectY();

                    self.pc += 2;
                    self.cycle(time, 5 + self.extra_cycle);
                    break :indirecty;
                },
                5 => zero_pagex: {
                    self.accumulator ^= self.GetZeroPageX();

                    self.pc += 2;
                    self.cycle(time, 4);
                    break :zero_pagex;
                },
                9 => absolutey: {
                    self.accumulator ^= self.GetAbsoluteIndexed(1);

                    self.pc += 3;
                    self.cycle(time, 4 + self.extra_cycle);
                    break :absolutey;
                },
                0xD => absolutex: {
                    self.accumulator ^= self.GetAbsoluteIndexed(0);

                    self.pc += 3;
                    self.cycle(time, 4 + self.extra_cycle);
                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Logical XOR)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    self.accumulator ^= self.GetIndirectX();

                    self.pc += 2;
                    self.cycle(time, 6);
                    break :indirectx;
                },
                5 => zero_page: {
                    self.accumulator ^= self.GetZeroPage();

                    self.pc += 2;
                    self.cycle(time, 3);
                    break :zero_page;
                },
                9 => immediate: {
                    self.accumulator ^= self.GetImmediate();

                    self.pc += 2;
                    self.cycle(time, 2);
                    break :immediate;
                },
                0xD => absolute: {
                    self.accumulator ^= self.GetAbsolute();

                    self.pc += 3;
                    self.cycle(time, 4);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Logical XOR)!\n", .{});
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

    pub fn logicalOr(self: *Cpu, time: i128) void {
        if (self.instruction & 0xF0 == 0x10) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    self.accumulator |= self.GetIndirectY();

                    self.pc += 2;
                    self.cycle(time, 5 + self.extra_cycle);
                    break :indirecty;
                },
                5 => zero_pagex: {
                    self.accumulator |= self.GetZeroPageX();

                    self.pc += 2;
                    self.cycle(time, 4);
                    break :zero_pagex;
                },
                9 => absolutey: {
                    self.accumulator |= self.GetAbsoluteIndexed(1);

                    self.pc += 3;
                    self.cycle(time, 4 + self.extra_cycle);
                    break :absolutey;
                },
                0xD => absolutex: {
                    self.accumulator |= self.GetAbsoluteIndexed(0);

                    self.pc += 3;
                    self.cycle(time, 4 + self.extra_cycle);
                    break :absolutex;
                },
                else => default: {
                    std.debug.print("No Addresing Mode found (Logical Or)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    self.accumulator |= self.GetIndirectX();

                    self.pc += 2;
                    self.cycle(time, 6);
                    break :indirectx;
                },
                5 => zero_page: {
                    self.accumulator |= self.GetZeroPage();

                    self.pc += 2;
                    self.cycle(time, 3);
                    break :zero_page;
                },
                9 => immediate: {
                    self.accumulator |= self.GetImmediate();

                    self.pc += 2;
                    self.cycle(time, 2);
                    break :immediate;
                },
                0xD => absolute: {
                    self.accumulator |= self.GetAbsolute();

                    self.pc += 3;
                    self.cycle(time, 4);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Addressing Mode Found (Logical Or)\n!", .{});
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

    pub fn logicalAnd(self: *Cpu, time: i128) void {
        //I know its an annd because the lowest nib % 4 == 1
        if (self.instruction & 0xF0 == 0x30) {
            switch (self.instruction & 0xF) {
                1 => indirecty: {
                    self.accumulator &= self.GetIndirectY();

                    self.pc += 2;
                    self.cycle(time, 5 + self.extra_cycle);
                    break :indirecty;
                },
                5 => zero_pagex: {
                    self.accumulator &= self.GetZeroPageX();
                    self.pc += 2;
                    self.cycle(time, 4);
                    break :zero_pagex;
                },
                9 => absolute_y: {
                    self.accumulator &= self.GetAbsoluteIndexed(1);

                    self.pc += 3;
                    self.cycle(time, 4 + self.extra_cycle);
                    break :absolute_y;
                },
                0xD => absolute_x: {
                    self.accumulator &= self.GetAbsoluteIndexed(0);

                    self.pc += 3;
                    self.cycle(time, 4 + self.extra_cycle);
                    break :absolute_x;
                },
                else => default: {
                    std.debug.print("No Addressing mode found (Logical And)!\n", .{});
                    break :default;
                },
            }
        } else {
            switch (self.instruction & 0xF) {
                1 => indirectx: {
                    self.accumulator &= self.GetIndirectX();

                    self.pc += 2;
                    self.cycle(time, 6);
                    break :indirectx;
                },
                5 => zero_page: {
                    self.accumulator &= self.GetZeroPage();

                    self.pc += 2;
                    self.cycle(time, 3);
                    break :zero_page;
                },
                9 => immediate: {
                    self.accumulator &= self.GetImmediate();

                    self.pc += 2;
                    self.cycle(time, 2);
                    break :immediate;
                },
                0xD => absolute: {
                    self.accumulator &= self.GetAbsolute();

                    self.pc += 3;
                    self.cycle(time, 4);
                    break :absolute;
                },
                else => default: {
                    std.debug.print("No Addressing Mode found (Logical And)!\n", .{});
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
            std.debug.print("Non-maskable Interrupt!\n\n", .{});
            self.interruptRequest(std.time.nanoTimestamp(), 0xFFFA);
            self.bus.ppu_ptr.nmi = 0;
        } else if (self.irq_line == 1 and self.status.interrupt_dsble != 1) {
            std.debug.print("Interrupt Request!\n\n", .{});
            self.interruptRequest(std.time.nanoTimestamp(), 0xFFFE);
            self.irq_line = 0;
        }
    }

    pub fn execute(self: *Cpu) void {
        //instruction decode
        const time: i128 = std.time.nanoTimestamp();
        self.bus.addr_bus = self.pc;
        self.bus.getMmo();

        self.instruction = self.bus.data_bus;

        const first_nib = (self.instruction & 0xF);
        const second_nib = (self.instruction & 0xF0);

        //std.debug.print("Instruction: 0x{X}, Address: 0x{X}!\n", .{ self.instruction, self.pc });
        //instruction execute
        switch (first_nib % 4) {
            0 => CONTROL: {
                switch (self.instruction) {
                    0x00 => {
                        self.forceInterrupt(time);
                        //std.debug.print("6502: Force Interrupt Found!\n", .{});
                        break :CONTROL;
                    },
                    0x04, 0x0C, 0x14, 0x1C, 0x34, 0x3C, 0x44, 0x54, 0x5C, 0x64, 0x74, 0x7C, 0x80, 0xD4, 0xDC, 0xF4, 0xFC => {
                        self.nop(time);
                        //std.debug.print("6502: NOP Found!\n", .{});
                        break :CONTROL;
                    },
                    0x08 => {
                        self.pushStatus(time);
                        //std.debug.print("6502: PHP Found!\n", .{});
                        break :CONTROL;
                    },
                    0x10 => {
                        self.branchNoNegative(time);
                        //std.debug.print("6502: BPL Found!\n", .{});
                        break :CONTROL;
                    },
                    0x18 => {
                        self.clearCarry(time);
                        //std.debug.print("6502: CLC Found!\n", .{});
                        break :CONTROL;
                    },
                    0x20 => {
                        self.jumpSubroutine(time);
                        //std.debug.print("6502: JSR Found!\n", .{});
                        break :CONTROL;
                    },
                    0x24, 0x2C => {
                        self.bitTest(time);
                        //std.debug.print("6502: BIT Found!\n", .{});
                        break :CONTROL;
                    },
                    0x28 => {
                        self.pullStatus(time);
                        //std.debug.print("6502: PLP Found!\n", .{});
                        break :CONTROL;
                    },
                    0x30 => {
                        self.branchOnNegative(time);
                        //std.debug.print("6502: BMI Found!\n", .{});
                        break :CONTROL;
                    },
                    0x38 => {
                        self.setCarry(time);
                        //std.debug.print("6502: SEC Found!\n", .{});
                        break :CONTROL;
                    },
                    0x40 => {
                        self.returnInterrupt(time);
                        //std.debug.print("6502: RTI Found!\n", .{});
                        break :CONTROL;
                    },
                    0x48 => {
                        self.pushAccumulator(time);
                        //std.debug.print("6502: PHA Found!\n", .{});
                        break :CONTROL;
                    },
                    0x4C, 0x6C => {
                        self.jump(time);
                        //std.debug.print("6502: JMP Found!\n", .{});
                        break :CONTROL;
                    },
                    0x50 => {
                        self.branchNoOverflow(time);
                        //std.debug.print("6502: BVC Found!\n", .{});
                        break :CONTROL;
                    },
                    0x58 => {
                        self.clearInterrupt(time);
                        //std.debug.print("6502: CLI Found!\n", .{});
                        break :CONTROL;
                    },
                    0x60 => {
                        self.returnSubroutine(time);
                        //std.debug.print("6502: RTS Found!\n", .{});
                        break :CONTROL;
                    },
                    0x68 => {
                        self.pullAccumulator(time);
                        //std.debug.print("6502: PLA Found!\n", .{});
                        break :CONTROL;
                    },
                    0x70 => {
                        self.branchOnOverflow(time);
                        //std.debug.print("6502: BVS Found!\n", .{});
                        break :CONTROL;
                    },
                    0x78 => {
                        self.setInterrupt(time);
                        //std.debug.print("6502: SEI Found!\n", .{});
                        break :CONTROL;
                    },
                    0x84, 0x94 => {
                        self.storeYRegister(time);
                        //std.debug.print("6502: STY Found!\n", .{});
                        break :CONTROL;
                    },
                    0x88 => {
                        self.decrementY(time);
                        //std.debug.print("6502: DEY Found!\n", .{});
                        break :CONTROL;
                    },
                    0x90 => {
                        self.branchNoCarry(time);
                        //std.debug.print("6502: BCC Found!\n", .{});
                        break :CONTROL;
                    },
                    0x98 => {
                        self.yToAccumulator(time);
                        //std.debug.print("6502: TYA Found!\n", .{});
                        break :CONTROL;
                        //SHY is 0x9C
                    },
                    0xA0, 0xA4, 0xAC, 0xB4, 0xBC => {
                        //complete this instruction
                        self.loadYRegister(time);
                        //std.debug.print("6502: LDY Found!\n", .{});
                        break :CONTROL;
                    },
                    0xA8 => {
                        self.accumulatorToY(time);
                        //std.debug.print("6502: TAY Found!\n", .{});
                        break :CONTROL;
                    },
                    0xB0 => {
                        self.branchOnCarry(time);
                        //std.debug.print("6502: BCS Found!\n", .{});
                        break :CONTROL;
                    },
                    0xB8 => {
                        self.clearOverflow(time);
                        //std.debug.print("6502: CLV Found!\n", .{});
                        break :CONTROL;
                    },
                    0xC0, 0xC4, 0xCC => {
                        self.compareYRegister(time);
                        //std.debug.print("6502: CPY Found!\n", .{});
                        break :CONTROL;
                    },
                    0xC8 => {
                        self.incrementYRegister(time);
                        //std.debug.print("6502: INY Found!\n", .{});
                        break :CONTROL;
                    },
                    0xD0 => {
                        self.branchNoZero(time);
                        //std.debug.print("6502: BNE Found!\n", .{});
                        break :CONTROL;
                    },
                    0xD8 => {
                        self.clearDecimal(time);
                        //std.debug.print("6502: CLD Found!\n", .{});
                        break :CONTROL;
                    },
                    0xE0, 0xE4, 0xEC => {
                        self.compareXRegister(time);
                        //std.debug.print("6502: CPX Found!\n", .{});
                        break :CONTROL;
                    },
                    0xE8 => {
                        self.incrementXRegister(time);
                        //std.debug.print("6502: INX Found!\n", .{});
                        break :CONTROL;
                    },
                    0xF0 => {
                        self.branchOnZero(time);
                        //std.debug.print("6502: BEQ Found!\n", .{});
                        break :CONTROL;
                    },
                    0xF8 => {
                        self.setDecimal(time);
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
                        self.logicalOr(time);
                        //std.debug.print("6502: ORA Found!\n", .{});
                        break :ALU;
                    },
                    0x20, 0x30 => {
                        self.logicalAnd(time);
                        //std.debug.print("6502: AND Found!\n", .{});
                        break :ALU;
                    },
                    0x40, 0x50 => {
                        self.exclusiveOr(time);
                        //std.debug.print("6502: EOR Found!\n", .{});
                        break :ALU;
                    },
                    0x60, 0x70 => {
                        self.addWithCarry(time);
                        //std.debug.print("6502: ADC Found!\n", .{});
                        break :ALU;
                    },
                    0x80, 0x90 => {
                        if (self.instruction == 0x89) {
                            self.nop(time);
                            //std.debug.print("6502: NOP Found!\n", .{});
                        } else {
                            self.storeAccumulator(time);
                            //std.debug.print("6502: STA Found!\n", .{});
                        }
                        break :ALU;
                    },
                    0xA0, 0xB0 => {
                        self.loadAccumulator(time);
                        //std.debug.print("6502: LDA Found!\n", .{});
                        break :ALU;
                    },
                    0xC0, 0xD0 => {
                        self.compareAccumulator(time);
                        //std.debug.print("6502: CMP Found!\n", .{});
                        break :ALU;
                    },
                    0xE0, 0xF0 => {
                        self.subtractWithCarry(time);
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
                            self.nop(time);
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else {
                            self.arithmeticShiftLeft(time);
                            //std.debug.print("6502: ASL Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0x20, 0x30 => {
                        if (self.instruction == 0x22 or self.instruction == 0x32) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x3A) {
                            self.nop(time);
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else {
                            self.rotateLeft(time);
                            //std.debug.print("6502: ROL Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0x40, 0x50 => {
                        if (self.instruction == 0x42 or self.instruction == 0x52) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x5A) {
                            self.nop(time);
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else {
                            self.logicalShiftRight(time);
                            //std.debug.print("6502: LSR Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0x60, 0x70 => {
                        if (self.instruction == 0x62 or self.instruction == 0x72) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x7A) {
                            self.nop(time);
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else {
                            self.rotateRight(time);
                            //std.debug.print("6502: ROR Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0x80, 0x90 => {
                        if (self.instruction == 0x92) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x80) {
                            self.nop(time);
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x86 or self.instruction == 0x8E or self.instruction == 0x96) {
                            self.storeXRegister(time);
                            //std.debug.print("6502: STX Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x8A) {
                            self.xToAccumulator(time);
                            //std.debug.print("6502: TXA Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0x9A) {
                            self.xToStackPointer(time);
                            //std.debug.print("6502: TXS Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0xA0, 0xB0 => {
                        if (self.instruction == 0xB2) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0xAA) {
                            self.accumulatorToX(time);
                            //std.debug.print("6502: TAX Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0xBA) {
                            self.xToStackPointer(time);
                            //std.debug.print("6502: TSX Found!\n", .{});
                            break :RMW;
                        } else {
                            self.loadXRegister(time);
                            //std.debug.print("6502: LDX Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0xC0, 0xD0 => {
                        if (self.instruction == 0xE2) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0xC0 or self.instruction == 0xEA) {
                            self.nop(time);
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0xCA) {
                            self.decrementX(time);
                            //std.debug.print("6502: DEX found!\n", .{});
                        } else {
                            self.decrement(time);
                            //std.debug.print("6502: DEC Found!\n", .{});
                            break :RMW;
                        }
                    },
                    0xE0, 0xF0 => {
                        if (self.instruction == 0xF2) {
                            //std.debug.print("6502: No Valid Instruction 'STP' Found!\n", .{});
                            break :RMW;
                        } else if (self.instruction == 0xE0 or self.instruction == 0xEA or self.instruction == 0xFA) {
                            self.nop(time);
                            //std.debug.print("6502: NOP Found!\n", .{});
                            break :RMW;
                        } else {
                            self.increment(time);
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
