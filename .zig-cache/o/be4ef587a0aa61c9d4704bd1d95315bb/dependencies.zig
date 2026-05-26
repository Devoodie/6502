pub const packages = struct {
    pub const @"N-V-__8AAHvybwBw1kyBGn0BW_s1RqIpycNjLf_XbE-fpLUF" = struct {
        pub const build_root = "/home/devooty/programming/nes/zig-pkg/N-V-__8AAHvybwBw1kyBGn0BW_s1RqIpycNjLf_XbE-fpLUF";
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
    pub const @"N-V-__8AAJl1DwBezhYo_VE6f53mPVm00R-Fk28NPW7P14EQ" = struct {
        pub const build_root = "/home/devooty/programming/nes/zig-pkg/N-V-__8AAJl1DwBezhYo_VE6f53mPVm00R-Fk28NPW7P14EQ";
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
    pub const @"N-V-__8AALShqgXkvqYU6f__FrA22SMWmi2TXCJjNTO1m8XJ" = struct {
        pub const available = false;
    };
    pub const @"raylib-6.0.0-whq8uCSwLgWWeF3ec3dbG6Rr36SLFL-s2WJ1Q_2E22Bb" = struct {
        pub const build_root = "/home/devooty/programming/nes/zig-pkg/raylib-6.0.0-whq8uCSwLgWWeF3ec3dbG6Rr36SLFL-s2WJ1Q_2E22Bb";
        pub const build_zig = @import("raylib-6.0.0-whq8uCSwLgWWeF3ec3dbG6Rr36SLFL-s2WJ1Q_2E22Bb");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "xcode_frameworks", "N-V-__8AALShqgXkvqYU6f__FrA22SMWmi2TXCJjNTO1m8XJ" },
            .{ "raygui", "N-V-__8AAHvybwBw1kyBGn0BW_s1RqIpycNjLf_XbE-fpLUF" },
            .{ "emsdk", "N-V-__8AAJl1DwBezhYo_VE6f53mPVm00R-Fk28NPW7P14EQ" },
            .{ "zemscripten", "zemscripten-0.2.0-dev-sRlDqApRAACspTbAZnuNKWIzfWzSYgYkb2nWAXZ-tqqt" },
        };
    };
    pub const @"raylib_zig-6.0.0-KE8REDJ4BQBu7lKwYNt6R4j5ywPeS37zqW6zrtjCcRwH" = struct {
        pub const build_root = "/home/devooty/programming/nes/zig-pkg/raylib_zig-6.0.0-KE8REDJ4BQBu7lKwYNt6R4j5ywPeS37zqW6zrtjCcRwH";
        pub const build_zig = @import("raylib_zig-6.0.0-KE8REDJ4BQBu7lKwYNt6R4j5ywPeS37zqW6zrtjCcRwH");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "raylib", "raylib-6.0.0-whq8uCSwLgWWeF3ec3dbG6Rr36SLFL-s2WJ1Q_2E22Bb" },
            .{ "raygui", "N-V-__8AAHvybwBw1kyBGn0BW_s1RqIpycNjLf_XbE-fpLUF" },
            .{ "emsdk", "N-V-__8AAJl1DwBezhYo_VE6f53mPVm00R-Fk28NPW7P14EQ" },
            .{ "zemscripten", "zemscripten-0.2.0-dev-sRlDqEtQAAB_1tPdqJsxQIqXxvvklcFu6VN5p6ANy8hw" },
        };
    };
    pub const @"zemscripten-0.2.0-dev-sRlDqApRAACspTbAZnuNKWIzfWzSYgYkb2nWAXZ-tqqt" = struct {
        pub const build_root = "/home/devooty/programming/nes/zig-pkg/zemscripten-0.2.0-dev-sRlDqApRAACspTbAZnuNKWIzfWzSYgYkb2nWAXZ-tqqt";
        pub const build_zig = @import("zemscripten-0.2.0-dev-sRlDqApRAACspTbAZnuNKWIzfWzSYgYkb2nWAXZ-tqqt");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"zemscripten-0.2.0-dev-sRlDqEtQAAB_1tPdqJsxQIqXxvvklcFu6VN5p6ANy8hw" = struct {
        pub const build_root = "/home/devooty/programming/nes/zig-pkg/zemscripten-0.2.0-dev-sRlDqEtQAAB_1tPdqJsxQIqXxvvklcFu6VN5p6ANy8hw";
        pub const build_zig = @import("zemscripten-0.2.0-dev-sRlDqEtQAAB_1tPdqJsxQIqXxvvklcFu6VN5p6ANy8hw");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "raylib_zig", "raylib_zig-6.0.0-KE8REDJ4BQBu7lKwYNt6R4j5ywPeS37zqW6zrtjCcRwH" },
};
