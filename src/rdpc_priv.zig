const std = @import("std");
const parse = @import("parse");
const rdpc_msg = @import("rdpc_msg.zig");
const c = @cImport(
{
    @cInclude("librdpc.h");
});

// sub struct for assigning functions
const rdpc_priv_sub_t = struct
{
    state_fn: *const fn (self: *rdpc_priv_t, slice: []u8) c_int =
            rdpc_priv_t.state_defalt_fn,
};

// c abi struct
pub const rdpc_priv_t = extern struct
{
    rdpc: c.rdpc_t = .{},
    allocator: *const std.mem.Allocator = undefined,
    i1: i32 = 0,
    i2: i32 = 0,
    channel_count: u32 = 0,
    channels_joined: u32 = 0,
    msg: *rdpc_msg.rdpc_msg_t = undefined,
    sub: *rdpc_priv_sub_t = undefined,

    //*************************************************************************
    pub fn delete(self: *rdpc_priv_t) void
    {
        self.msg.delete();
        self.allocator.destroy(self.sub);
        self.allocator.destroy(self);
    }

    //*************************************************************************
    pub fn logln(self: *rdpc_priv_t, src: std.builtin.SourceLocation,
            comptime fmt: []const u8, args: anytype) c_int
    {
        // check if function is assigned
        if (self.rdpc.log_msg) |alog_msg|
        {
            const alloc_buf = std.fmt.allocPrint(self.allocator.*,
                    fmt, args) catch
                return c.LIBRDPC_ERROR_MEMORY;
            defer self.allocator.free(alloc_buf);
            const alloc1_buf = std.fmt.allocPrintZ(self.allocator.*,
                    "{s}:{s}", .{src.fn_name, alloc_buf}) catch
                return c.LIBRDPC_ERROR_MEMORY;
            defer self.allocator.free(alloc1_buf);
            return alog_msg(&self.rdpc, alloc1_buf.ptr);
        }
        return c.LIBRDPC_ERROR_PARSE;
    }

    //*************************************************************************
    pub fn send_slice_to_server(self: *rdpc_priv_t, data: []u8) c_int
    {
        // check if function is assigned
        if (self.rdpc.send_to_server) |asend_to_server|
        {
            // call the c callback
            return asend_to_server(&self.rdpc,
                    data.ptr, @intCast(data.len));
        }
        return c.LIBRDPC_ERROR_PARSE;
    }

    //*************************************************************************
    /// this starts the back and forth connection process
    pub fn start(self: *rdpc_priv_t) c_int
    {
        _ = self.logln(@src(), "", .{});
        const outs = parse.create(self.allocator, 1024) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer outs.delete();
        self.sub.state_fn = rdpc_priv_t.state0_fn;
        self.msg.connection_request(outs) catch
            return c.LIBRDPC_ERROR_PARSE;
        return self.send_slice_to_server(outs.get_out_slice());
    }

    //*************************************************************************
    pub fn process_server_slice_data(self: *rdpc_priv_t, slice: []u8,
            bytes_processed: ?*c_int) c_int
    {
        _ = self.logln(@src(), "bytes {}", .{slice.len});
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
        return self.sub.state_fn(self, slice[0..len]);
    }

    //*************************************************************************
    fn state_defalt_fn(self: *rdpc_priv_t, slice: []u8) c_int
    {
        _ = slice;
        _ = self.logln(@src(), "", .{});
        return c.LIBRDPC_ERROR_PARSE;
    }

    /// start sent connection_request, process
    /// connection_confirm and send conference_create_request
    //*************************************************************************
    fn state0_fn(self: *rdpc_priv_t, slice: []u8) c_int
    {
        _ = self.logln(@src(), "", .{});
        // code block for defer
        {
            const ins = parse.create_from_slice(self.allocator, slice) catch
                return c.LIBRDPC_ERROR_MEMORY;
            defer ins.delete();
            self.msg.connection_confirm(ins) catch
                return c.LIBRDPC_ERROR_PARSE;
        }
        const outs = parse.create(self.allocator, 8192) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer outs.delete();
        self.msg.conference_create_request(outs) catch
            return c.LIBRDPC_ERROR_PARSE;
        const rv = self.send_slice_to_server(outs.get_out_slice());
        if (rv == c.LIBRDPC_ERROR_NONE)
        {
            self.sub.state_fn = rdpc_priv_t.state1_fn;
        }
        return rv;
    }

    /// state0_fn sent conference_create_request, process
    /// conference_create_response and send
    /// erect_domain_request and attach_user_request
    //*************************************************************************
    fn state1_fn(self: *rdpc_priv_t, slice: []u8) c_int
    {
        _ = self.logln(@src(), "", .{});
        // code block for defer
        {
            const ins = parse.create_from_slice(self.allocator, slice) catch
                return c.LIBRDPC_ERROR_MEMORY;
            defer ins.delete();
            self.msg.conference_create_response(ins) catch
                return c.LIBRDPC_ERROR_PARSE;
        }
        const outs = parse.create(self.allocator, 8192) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer outs.delete();
        self.msg.erect_domain_request(outs) catch
            return c.LIBRDPC_ERROR_PARSE;
        var rv = self.send_slice_to_server(outs.get_out_slice());
        if (rv == c.LIBRDPC_ERROR_NONE)
        {
            outs.reset(0) catch
                return c.LIBRDPC_ERROR_MEMORY;
            self.msg.attach_user_request(outs) catch
                return c.LIBRDPC_ERROR_PARSE;
            rv = self.send_slice_to_server(outs.get_out_slice());
            if (rv == c.LIBRDPC_ERROR_NONE)
            {
                self.sub.state_fn = rdpc_priv_t.state2_fn;
            }
        }
        return rv;
    }

    /// state1_fn sent erect_domain_request and attach_user_request, process
    /// attach_user_confirm and send channel_join_request
    //*************************************************************************
    fn state2_fn(self: *rdpc_priv_t, slice: []u8) c_int
    {
        _ = self.logln(@src(), "", .{});
        // code block for defer
        {
            const ins = parse.create_from_slice(self.allocator, slice) catch
                return c.LIBRDPC_ERROR_MEMORY;
            defer ins.delete();
            self.msg.attach_user_confirm(ins) catch
                return c.LIBRDPC_ERROR_PARSE;
        }
        const outs = parse.create(self.allocator, 8192) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer outs.delete();
        self.msg.channel_join_request(outs) catch
            return c.LIBRDPC_ERROR_PARSE;
        const rv = self.send_slice_to_server(outs.get_out_slice());
        if (rv == c.LIBRDPC_ERROR_NONE)
        {
            self.sub.state_fn = rdpc_priv_t.state3_fn;
        }
        return rv;
    }

    /// state2_fn sent channel_join_request, process
    /// channel_join_confirm and send channel_join_request
    //*************************************************************************
    fn state3_fn(self: *rdpc_priv_t, slice: []u8) c_int
    {
        _ = self.logln(@src(), "", .{});
        // code block for defer
        {
            const ins = parse.create_from_slice(self.allocator, slice) catch
                return c.LIBRDPC_ERROR_MEMORY;
            defer ins.delete();
            self.msg.channel_join_confirm(ins) catch
                return c.LIBRDPC_ERROR_PARSE;
        }
        var rv: c_int = c.LIBRDPC_ERROR_NONE;
        const outs = parse.create(self.allocator, 8192) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer outs.delete();
        if (self.channels_joined < self.channel_count)
        {
            self.msg.channel_join_request(outs) catch
                return c.LIBRDPC_ERROR_PARSE;
            rv = self.send_slice_to_server(outs.get_out_slice());
        }
        else
        {
            self.msg.security_exchange(outs) catch
                return c.LIBRDPC_ERROR_PARSE;
            rv = self.send_slice_to_server(outs.get_out_slice());
            if (rv == c.LIBRDPC_ERROR_NONE)
            {
                outs.reset(0) catch
                    return c.LIBRDPC_ERROR_MEMORY;
                self.msg.client_info(outs) catch
                    return c.LIBRDPC_ERROR_PARSE;
                rv = self.send_slice_to_server(outs.get_out_slice());
                if (rv == c.LIBRDPC_ERROR_NONE)
                {
                    self.sub.state_fn = rdpc_priv_t.state4_fn;
                }
            }
        }
        return rv;
    }

    /// state1_fn sent security_exchange and client_info, process
    /// auto_detect_request and send auto_detect_respone
    //*************************************************************************
    fn state4_fn(self: *rdpc_priv_t, slice: []u8) c_int
    {
        _ = self.logln(@src(), "", .{});
        // code block for defer
        {
            const ins = parse.create_from_slice(self.allocator, slice) catch
                return c.LIBRDPC_ERROR_MEMORY;
            defer ins.delete();
            self.msg.auto_detect_request(ins) catch
                return c.LIBRDPC_ERROR_PARSE;
        }
        const outs = parse.create(self.allocator, 8192) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer outs.delete();
        self.msg.auto_detect_response(outs) catch
            return c.LIBRDPC_ERROR_PARSE;
        const rv = self.send_slice_to_server(outs.get_out_slice());
        if (rv == c.LIBRDPC_ERROR_NONE)
        {
            //self.sub.state_fn = rdpc_priv_t.state5_fn;
        }
        return rv;
    }

};

//*****************************************************************************
pub fn create(allocator: *const std.mem.Allocator) !*rdpc_priv_t
{
    const priv: *rdpc_priv_t = try allocator.create(rdpc_priv_t);
    errdefer allocator.destroy(priv);
    priv.* = .{};
    priv.allocator = allocator;
    priv.sub = try allocator.create(rdpc_priv_sub_t);
    errdefer allocator.destroy(priv.sub);
    priv.sub.* = .{};
    priv.msg = try rdpc_msg.create(allocator, priv);
    // priv.msg gets initalized in create
    return priv;
}
