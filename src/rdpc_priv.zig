
const std = @import("std");
const nsparse = @import("parse.zig");
const nsrdpc_msg = @import("rdpc_msg.zig");
const c = @cImport(
{
    @cInclude("librdpc_gcc.h");
    @cInclude("librdpc_constants.h");
    @cInclude("librdpc.h");
});

// c abi struct
pub const rdpc_priv_t = extern struct
{
    rdpc: c.rdpc_t = .{},
    allocator: *const std.mem.Allocator = undefined,
    i1: i32 = 0,
    i2: i32 = 0,
    state: i32 = 0,
    pad0: i32 = 0,
    rdpc_msg: *nsrdpc_msg.rdpc_msg_t = undefined,

    //*************************************************************************
    pub fn delete(rdpc_priv: *rdpc_priv_t) void
    {
        rdpc_priv.rdpc_msg.delete();
        rdpc_priv.allocator.destroy(rdpc_priv);
    }

    //*************************************************************************
    pub fn log_msg(rdpc_priv: *rdpc_priv_t, comptime fmt: []const u8,
            args: anytype) c_int
    {
        // check if function is assigned
        if (rdpc_priv.rdpc.log_msg) |alog_msg|
        {
            const alloc_buf = std.fmt.allocPrint(rdpc_priv.allocator.*,
                    fmt, args) catch
                return c.LIBRDPC_ERROR_MEMORY;
            defer rdpc_priv.allocator.free(alloc_buf);
            // alloc for copy
            const lmsg: []u8 = rdpc_priv.allocator.alloc(u8,
                    alloc_buf.len + 1) catch
                return c.LIBRDPC_ERROR_MEMORY;
            defer rdpc_priv.allocator.free(lmsg);
            // make a copy
            var index: usize = 0;
            for (alloc_buf) |byte|
            {
                lmsg[index] = byte;
                index += 1;
            }
            lmsg[index] = 0; // set nil at end
            return alog_msg(&rdpc_priv.rdpc, lmsg.ptr);
        }
        return c.LIBRDPC_ERROR_PARSE;
    }

    //*************************************************************************
    pub fn send_to_server(rdpc_priv: *rdpc_priv_t, data: []u8) c_int
    {
        // check if function is assigned
        if (rdpc_priv.rdpc.send_to_server) |asend_to_server|
        {
            return asend_to_server(&rdpc_priv.rdpc,
                    data.ptr, @intCast(data.len));
        }
        return c.LIBRDPC_ERROR_PARSE;
    }

    //*************************************************************************
    /// this starts the back and forth connection process
    pub fn start(rdpc_priv: *rdpc_priv_t) c_int
    {
        _ = rdpc_priv.log_msg("rdpc_priv::start:", .{});
        const outs = nsparse.create(rdpc_priv.allocator, 1024) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer outs.delete();
        rdpc_priv.state = 0;
        if (!rdpc_priv.rdpc_msg.connection_request(outs))
        {
            return c.LIBRDPC_ERROR_PARSE;
        }
        return rdpc_priv.send_to_server(outs.get_out_slice());
    }

    //*************************************************************************
    pub fn process_server_data(rdpc_priv: *rdpc_priv_t, slice: []u8,
            bytes_processed: ?*c_int) c_int
    {
        _ = rdpc_priv.log_msg("rdpc_priv::process_server_data: bytes {}",
                .{slice.len});
        var len: u16 = 0;
        if (slice.len < 2)
        {
            return c.LIBRDPC_ERROR_NEED_MORE;
        }
        if (slice[0] == 0x03)
        {
            // TPKT
            if (slice.len < 4)
            {
                return c.LIBRDPC_ERROR_NEED_MORE;
            }
            len = slice[2];
            len = (len << 8) | slice[3];
        }
        else
        {
            // Fast-Path
            if ((slice[1] & 0x80) != 0)
            {
                if (slice.len < 3)
                {
                    return c.LIBRDPC_ERROR_NEED_MORE;
                }
                len = slice[1];
                len = ((len & 0x7F) << 8) | slice[2];
            }
            else
            {
                len = slice[1];
            }
        }
        if (len < 1)
        {
            return c.LIBRDPC_ERROR_PARSE;
        }
        if (slice.len < len)
        {
            return c.LIBRDPC_ERROR_NEED_MORE;
        }
        // check if bytes_processed is nil
        if (bytes_processed) |abytes_processed|
        {
            abytes_processed.* = len;
        }
        if (rdpc_priv.state == 0)
        {
            const sub_slice = slice[0..len];
            // block for defer
            {
                const ins = nsparse.create_from_slice(rdpc_priv.allocator,
                        sub_slice) catch
                    return c.LIBRDPC_ERROR_MEMORY;
                defer ins.delete();
                if (!rdpc_priv.rdpc_msg.connection_confirm(ins))
                {
                    return c.LIBRDPC_ERROR_PARSE;
                }
            }
            const outs = nsparse.create(rdpc_priv.allocator, 8192) catch
                return c.LIBRDPC_ERROR_MEMORY;
            defer outs.delete();
            rdpc_priv.state = 1;
            if (!rdpc_priv.rdpc_msg.conference_create_request(outs))
            {
                return c.LIBRDPC_ERROR_PARSE;
            }
            return rdpc_priv.send_to_server(outs.get_out_slice());
        }
        else
        {
            _ = rdpc_priv.log_msg("rdpc_priv::process_server_data: unknown state {}",
                    .{rdpc_priv.state});
        }
        return c.LIBRDPC_ERROR_NONE;
    }

};

//*****************************************************************************
pub fn create(allocator: *const std.mem.Allocator) !*rdpc_priv_t
{
    const rdpc_priv: *rdpc_priv_t = try allocator.create(rdpc_priv_t);
    errdefer allocator.destroy(rdpc_priv);
    rdpc_priv.* = .{};
    rdpc_priv.allocator = allocator;
    rdpc_priv.rdpc_msg = try nsrdpc_msg.create(allocator, rdpc_priv);
    return rdpc_priv;
}
