
const std = @import("std");

//const g_check_check = false;
const g_check_check = true;
const g_num_layers = 4;

pub const parse_t = struct
{
    allocator: *const std.mem.Allocator = undefined,
    data: []u8 = undefined,
    offset: usize = 0,
    check_offset: usize = 0,
    layer_offsets: [g_num_layers]usize = .{0} ** g_num_layers,
    did_alloc: bool = false,

    //*************************************************************************
    pub fn delete(parse: *parse_t) void
    {
        if (parse.did_alloc)
        {
            parse.allocator.free(parse.data);
        }
        parse.allocator.destroy(parse);
    }

    //*************************************************************************
    pub fn reset(parse: *parse_t, size: usize) !void
    {
        if (parse.did_alloc)
        {
            if (size > parse.data.len)
            {
                parse.allocator.free(parse.data);
                parse.data = try parse.allocator.alloc(u8, size);
            }
        }
        else
        {
            if (size > parse.data.len)
            {
                return error.InvalidParam;
            }
        }
        parse.offset = 0;
        parse.check_offset = 0;
    }

    //*************************************************************************
    pub fn get_out_slice(parse: *parse_t) []u8
    {
        return parse.data[0..parse.offset];
    }

    //*************************************************************************
    pub fn check_rem(parse: *parse_t, size: usize) bool
    {
        parse.check_offset = parse.offset + size;
        return parse.offset + size <= parse.data.len;
    }

    //*************************************************************************
    pub inline fn out_u8(parse: *parse_t, val: u8) void
    {
        var offset = parse.offset;
        parse.data[offset] = val;
        offset += 1;
        parse.offset = offset;
        check_check(parse, @src().fn_name);
    }

    //*************************************************************************
    pub inline fn out_i8(parse: *parse_t, val: i8) void
    {
        out_u8(parse, @bitCast(val));
    }

    //*************************************************************************
    pub inline fn out_u16_le(parse: *parse_t, val: u16) void
    {
        var offset = parse.offset;
        parse.data[offset] = @truncate(val);
        offset += 1;
        parse.data[offset] = @truncate(val >> 8);
        offset += 1;
        parse.offset = offset;
        check_check(parse, @src().fn_name);
    }

    //*************************************************************************
    pub inline fn out_u16_be(parse: *parse_t, val: u16) void
    {
        var offset = parse.offset;
        parse.data[offset] = @truncate(val >> 8);
        offset += 1;
        parse.data[offset] = @truncate(val);
        offset += 1;
        parse.offset = offset;
        check_check(parse, @src().fn_name);
    }

    //*************************************************************************
    pub inline fn out_i16_le(parse: *parse_t, val: i16) void
    {
        return out_u16_le(parse, @bitCast(val));
    }

    //*************************************************************************
    pub inline fn out_i16_be(parse: *parse_t, val: i16) void
    {
        return out_u16_be(parse, @bitCast(val));
    }

    //*************************************************************************
    pub inline fn out_u32_le(parse: *parse_t, val: u32) void
    {
        var offset = parse.offset;
        parse.data[offset] = @truncate(val);
        offset += 1;
        parse.data[offset] = @truncate(val >> 8);
        offset += 1;
        parse.data[offset] = @truncate(val >> 16);
        offset += 1;
        parse.data[offset] = @truncate(val >> 24);
        offset += 1;
        parse.offset = offset;
        check_check(parse, @src().fn_name);
    }

    //*************************************************************************
    pub inline fn out_u32_be(parse: *parse_t, val: u32) void
    {
        var offset = parse.offset;
        parse.data[offset] = @truncate(val >> 24);
        offset += 1;
        parse.data[offset] = @truncate(val >> 16);
        offset += 1;
        parse.data[offset] = @truncate(val >> 8);
        offset += 1;
        parse.data[offset] = @truncate(val);
        offset += 1;
        parse.offset = offset;
        check_check(parse, @src().fn_name);
    }

    //*************************************************************************
    pub inline fn out_i32_le(parse: *parse_t, val: i32) void
    {
        out_u32_le(parse, @bitCast(val));
    }

    //*************************************************************************
    pub inline fn out_i32_be(parse: *parse_t, val: i32) void
    {
        out_u32_be(parse, @bitCast(val));
    }

    //*************************************************************************
    pub inline fn out_u64_le(parse: *parse_t, val: u64) void
    {
        out_u32_le(parse, @truncate(val));
        out_u32_le(parse, @truncate(val >> 32));
    }

    //*************************************************************************
    pub inline fn out_u64_be(parse: *parse_t, val: u64) void
    {
        out_u32_be(parse, @truncate(val >> 32));
        out_u32_be(parse, @truncate(val));
    }

    //*************************************************************************
    pub inline fn out_i64_le(parse: *parse_t, val: i64) void
    {
        out_u64_le(parse, @bitCast(val));
    }

    //*************************************************************************
    pub inline fn out_i64_be(parse: *parse_t, val: i64) void
    {
        out_u64_be(parse, @bitCast(val));
    }

    //*************************************************************************
    pub fn out_u8_slice(parse: *parse_t, slice: []const u8) void
    {
        var offset = parse.offset;
        for (slice) |byte|
        {
            parse.data[offset] = byte;
            offset += 1;
        }
        parse.offset = offset;
        check_check(parse, @src().fn_name);
    }

    //*************************************************************************
    pub fn out_u8_skip(parse: *parse_t, bytes: usize) void
    {
        var offset = parse.offset;
        var index: usize = 0;
        while (index < bytes)
        {
            parse.data[offset] = 0;
            offset += 1;
            index += 1;
        }
        parse.offset = offset;
        check_check(parse, @src().fn_name);
    }

    //*************************************************************************
    pub inline fn in_u8(parse: *parse_t) u8
    {
        var offset = parse.offset;
        const rv: u8 = parse.data[offset];
        offset += 1;
        parse.offset = offset;
        check_check(parse, @src().fn_name);
        return rv;
    }

    //*************************************************************************
    pub inline fn in_u16_le(parse: *parse_t) u16
    {
        var offset = parse.offset;
        var rv: u16 = parse.data[offset];
        offset += 1;
        const rv1: u16 = parse.data[offset];
        offset += 1;
        rv = rv | (rv1 << 8);
        parse.offset = offset;
        check_check(parse, @src().fn_name);
        return rv;
    }

    //*************************************************************************
    pub inline fn in_u16_be(parse: *parse_t) u16
    {
        var offset = parse.offset;
        var rv: u16 = parse.data[offset];
        offset += 1;
        rv = (rv << 8) | parse.data[offset];
        offset += 1;
        parse.offset = offset;
        check_check(parse, @src().fn_name);
        return rv;
    }

    //*************************************************************************
    pub inline fn in_i16_le(parse: *parse_t) i16
    {
        return @bitCast(in_u16_le(parse));
    }

    //*************************************************************************
    pub inline fn in_i16_be(parse: *parse_t) i16
    {
        return @bitCast(in_u16_be(parse));
    }

    //*************************************************************************
    pub inline fn in_u32_le(parse: *parse_t) u32
    {
        var offset = parse.offset;
        var rv: u32 = parse.data[offset];
        offset += 1;
        const rv1: u32 = parse.data[offset];
        offset += 1;
        const rv2: u32 = parse.data[offset];
        offset += 1;
        const rv3: u32 = parse.data[offset];
        offset += 1;
        rv = rv | (rv1 << 8) | (rv2 << 16) | (rv3 << 24);
        parse.offset = offset;
        check_check(parse, @src().fn_name);
        return rv;
    }

    //*************************************************************************
    pub inline fn in_u32_be(parse: *parse_t) u32
    {
        var offset = parse.offset;
        var rv: u32 = parse.data[offset];
        offset += 1;
        rv = (rv << 8) | parse.data[offset];
        offset += 1;
        rv = (rv << 8) | parse.data[offset];
        offset += 1;
        rv = (rv << 8) | parse.data[offset];
        offset += 1;
        parse.offset = offset;
        check_check(parse, @src().fn_name);
        return rv;
    }

    //*************************************************************************
    pub inline fn in_i32_le(parse: *parse_t) i32
    {
        return @bitCast(in_u32_le(parse));
    }

    //*************************************************************************
    pub inline fn in_i32_be(parse: *parse_t) i32
    {
        return @bitCast(in_u32_be(parse));
    }

    //*************************************************************************
    pub inline fn in_u64_le(parse: *parse_t) u64
    {
        const rv: u64 = in_u32_le(parse);
        const rv1: u64 = in_u32_le(parse);
        return rv | (rv1 << 32);
    }

    //*************************************************************************
    pub inline fn in_u64_be(parse: *parse_t) u64
    {
        const rv: u64 = in_u32_be(parse);
        return (rv << 32) | in_u32_be(parse);
    }

    //*************************************************************************
    pub inline fn in_i64_le(parse: *parse_t) i64
    {
        return @bitCast(in_u64_le(parse));
    }

    //*************************************************************************
    pub inline fn in_i64_be(parse: *parse_t) i64
    {
        return @bitCast(in_u64_be(parse));
    }

    //*************************************************************************
    pub fn in_u8_slice(parse: *parse_t, bytes: usize) []u8
    {
        var offset = parse.offset;
        const end = offset + bytes;
        const slice: []u8 = parse.data[offset..end];
        offset += bytes;
        parse.offset = offset;
        check_check(parse, @src().fn_name);
        return slice;
    }

    //*************************************************************************
    pub fn in_u8_skip(parse: *parse_t, bytes: usize) void
    {
        var offset = parse.offset;
        offset += bytes;
        parse.offset = offset;
        check_check(parse, @src().fn_name);
    }

    pub fn push_layer(parse: *parse_t, bytes: usize, layer: u8) void
    {
        var offset = parse.offset;
        parse.layer_offsets[layer] = offset;
        offset += bytes;
        parse.offset = offset;
        check_check(parse, @src().fn_name);
    }

    pub fn pop_layer(parse: *parse_t, layer: u8) void
    {
        parse.offset = parse.layer_offsets[layer];
    }

    pub fn layer_subtract(parse: *parse_t, a: usize, b: usize) u16
    {
         return @truncate(parse.layer_offsets[a] - parse.layer_offsets[b]);
    }

};

//*****************************************************************************
pub fn create(allocator: *const std.mem.Allocator, size: usize) !*parse_t
{
    const parse: *parse_t = try allocator.create(parse_t);
    errdefer allocator.destroy(parse);
    parse.* = .{};
    parse.allocator = allocator;
    parse.data = try allocator.alloc(u8, size);
    parse.did_alloc = true;
    return parse;
}

//*****************************************************************************
pub fn create_from_slice(allocator: *const std.mem.Allocator,
        slice: []u8) !*parse_t
{
    const parse: *parse_t = try allocator.create(parse_t);
    parse.* = .{};
    parse.allocator = allocator;
    parse.data = slice;
    parse.did_alloc = false;
    return parse;
}

//*****************************************************************************
inline fn check_check(parse: *parse_t, fn_name: []const u8) void
{
    if (g_check_check and (parse.check_offset < parse.offset))
    {
        std.debug.print("check_check: {s}\n", .{fn_name});
    }
}
