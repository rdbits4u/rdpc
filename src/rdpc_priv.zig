const std = @import("std");
const parse = @import("parse");
const hexdump = @import("hexdump");
const rdpc_msg = @import("rdpc_msg.zig");
const rdpc_gcc = @import("rdpc_gcc.zig");
const rdpc_caps = @import("rdpc_caps.zig");
const c = @cImport(
{
    @cInclude("librdpc.h");
});

// sub struct for assigning functions
const rdpc_priv_sub_t = struct
{
    state_fn: *const fn (self: *rdpc_priv_t, slice: []u8) anyerror!c_int =
            rdpc_priv_t.state_defalt_fn,
};

// c abi struct
pub const rdpc_priv_t = extern struct
{
    rdpc: c.struct_rdpc_t = .{},
    allocator: *const std.mem.Allocator = undefined,
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
            comptime fmt: []const u8, args: anytype) !void
    {
        // check if function is assigned
        if (self.rdpc.log_msg) |alog_msg|
        {
            const alloc_buf = try std.fmt.allocPrint(self.allocator.*, fmt, args);
            defer self.allocator.free(alloc_buf);
            const alloc1_buf = try std.fmt.allocPrintZ(self.allocator.*, "{s}:{s}", .{src.fn_name, alloc_buf});
            defer self.allocator.free(alloc1_buf);
            _ = alog_msg(&self.rdpc, alloc1_buf.ptr);
        }
    }

    //*************************************************************************
    pub fn send_slice_to_server(self: *rdpc_priv_t, data: []u8) !c_int
    {
        // check if function is assigned
        if (self.rdpc.send_to_server) |asend_to_server|
        {
            //try self.logln(@src(), "hexdump len {}", .{data.len});
            //try hexdump.printHexDump(0, data);
            // call the c callback
            return asend_to_server(&self.rdpc, data.ptr, @intCast(data.len));
        }
        return c.LIBRDPC_ERROR_PARSE;
    }

    //*************************************************************************
    /// this starts the back and forth connection process
    pub fn start(self: *rdpc_priv_t) !c_int
    {
        try self.logln(@src(), "", .{});
        const outs = try parse.create(self.allocator, 1024);
        defer outs.delete();
        self.sub.state_fn = rdpc_priv_t.state0_fn;
        try self.msg.connection_request(outs);
        return self.send_slice_to_server(outs.get_out_slice());
    }

    //*************************************************************************
    pub fn process_server_slice_data(self: *rdpc_priv_t, slice: []u8,
            bytes_processed: ?*c_int) !c_int
    {
        try self.logln(@src(), "bytes {}", .{slice.len});
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
            try self.logln(@src(),
                    "returning LIBRDPC_ERROR_NEED_MORE len {} slice.len {}",
                    .{len, slice.len});
            try hexdump.printHexDump(0, slice[0..len]);
            return c.LIBRDPC_ERROR_NEED_MORE;
        }
        // check if bytes_processed is nil
        if (bytes_processed) |abytes_processed|
        {
            abytes_processed.* = len;
        }
        try self.logln(@src(), "len {}", .{len});
        //try self.logln(@src(), "hexdump len {}", .{len});
        //try hexdump.printHexDump(0, slice[0..len]);
        return self.sub.state_fn(self, slice[0..len]);
    }

    //*************************************************************************
    fn state_defalt_fn(self: *rdpc_priv_t, slice: []u8) !c_int
    {
        _ = slice;
        try self.logln(@src(), "", .{});
        return c.LIBRDPC_ERROR_PARSE;
    }

    /// start sent connection_request, process
    /// connection_confirm and send conference_create_request
    //*************************************************************************
    fn state0_fn(self: *rdpc_priv_t, slice: []u8) !c_int
    {
        try self.logln(@src(), "", .{});
        const ins = try parse.create_from_slice(self.allocator, slice);
        defer ins.delete();
        try self.msg.connection_confirm(ins);
        const outs = try parse.create(self.allocator, 8192);
        defer outs.delete();
        try self.msg.conference_create_request(outs);
        const rv = try self.send_slice_to_server(outs.get_out_slice());
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
    fn state1_fn(self: *rdpc_priv_t, slice: []u8) !c_int
    {
        try self.logln(@src(), "", .{});
        const ins = try parse.create_from_slice(self.allocator, slice);
        defer ins.delete();
        try self.msg.conference_create_response(ins);
        const outs = try parse.create(self.allocator, 8192);
        defer outs.delete();
        try self.msg.erect_domain_request(outs);
        var rv = try self.send_slice_to_server(outs.get_out_slice());
        if (rv == c.LIBRDPC_ERROR_NONE)
        {
            try outs.reset(0);
            try self.msg.attach_user_request(outs);
            rv = try self.send_slice_to_server(outs.get_out_slice());
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
    fn state2_fn(self: *rdpc_priv_t, slice: []u8) !c_int
    {
        try self.logln(@src(), "", .{});
        const ins = try parse.create_from_slice(self.allocator, slice);
        defer ins.delete();
        try self.msg.attach_user_confirm(ins);
        const outs = try parse.create(self.allocator, 8192);
        defer outs.delete();
        var rv: c_int = c.LIBRDPC_ERROR_NONE;
        // join MCS_USER_CHANNEL
        var chanid: u16 = c.MCS_USERCHANNEL_BASE;
        chanid += self.msg.mcs_userid;
        try self.msg.channel_join_request(outs, chanid);
        rv = try self.send_slice_to_server(outs.get_out_slice());
        if (rv == c.LIBRDPC_ERROR_NONE)
        {
            self.sub.state_fn = rdpc_priv_t.state3_fn;
        }
        return rv;
    }

    /// state2_fn sent channel_join_request, process
    /// channel_join_confirm and send channel_join_request
    //*************************************************************************
    fn state3_fn(self: *rdpc_priv_t, slice: []u8) !c_int
    {
        try self.logln(@src(), "", .{});
        const ins = try parse.create_from_slice(self.allocator, slice);
        defer ins.delete();
        var chanid: u16 = 0;
        try self.msg.channel_join_confirm(ins, &chanid);
        var rv: c_int = c.LIBRDPC_ERROR_NONE;
        const outs = try parse.create(self.allocator, 8192);
        defer outs.delete();
        // join MCS_GLOBAL_CHANNEL
        chanid = c.MCS_GLOBAL_CHANNEL;
        try self.msg.channel_join_request(outs, chanid);
        rv = try self.send_slice_to_server(outs.get_out_slice());
        if (rv == c.LIBRDPC_ERROR_NONE)
        {
            self.sub.state_fn = rdpc_priv_t.state4_fn;
        }
        return rv;
    }

    /// state3_fn sent channel_join_request, process
    /// channel_join_confirm and send channel_join_request
    //*************************************************************************
    fn state4_fn(self: *rdpc_priv_t, slice: []u8) !c_int
    {
        try self.logln(@src(), "", .{});
        const ins = try parse.create_from_slice(self.allocator, slice);
        defer ins.delete();
        var chanid: u16 = 0;
        try self.msg.channel_join_confirm(ins, &chanid);
        var rv: c_int = c.LIBRDPC_ERROR_NONE;
        const outs = try parse.create(self.allocator, 8192);
        defer outs.delete();
        const joined = self.msg.mcs_channels_joined;
        if (joined < self.rdpc.cgcc.net.channelCount)
        {
            chanid = self.rdpc.sgcc.net.channelIdArray[joined];
            try self.logln(@src(), "chanid {} joined {}", .{chanid, joined});
            try self.msg.channel_join_request(outs, chanid);
            rv = try self.send_slice_to_server(outs.get_out_slice());
            self.msg.mcs_channels_joined += 1;
        }
        else
        {
            try self.msg.security_exchange(outs);
            rv = try self.send_slice_to_server(outs.get_out_slice());
            if (rv == c.LIBRDPC_ERROR_NONE)
            {
                try outs.reset(0);
                try self.msg.client_info(outs);
                rv = try self.send_slice_to_server(outs.get_out_slice());
                if (rv == c.LIBRDPC_ERROR_NONE)
                {
                    self.sub.state_fn = rdpc_priv_t.state5_fn;
                }
            }
        }
        return rv;
    }

    /// state4_fn sent security_exchange and client_info, process
    /// process_sec
    //*************************************************************************
    fn state5_fn(self: *rdpc_priv_t, slice: []u8) !c_int
    {
        try self.logln(@src(), "", .{});
        const ins = try parse.create_from_slice(self.allocator, slice);
        defer ins.delete();
        try self.msg.process_sec(ins);
        self.sub.state_fn = rdpc_priv_t.state6_fn;
        return c.LIBRDPC_ERROR_NONE;
    }

    /// process_rdp
    //*************************************************************************
    fn state6_fn(self: *rdpc_priv_t, slice: []u8) !c_int
    {
        try self.logln(@src(), "", .{});
        const ins = try parse.create_from_slice(self.allocator, slice);
        defer ins.delete();
        try self.msg.process_rdp(ins);
        return c.LIBRDPC_ERROR_NONE;
    }

};

//*****************************************************************************
pub fn create(allocator: *const std.mem.Allocator,
        settings: *c.struct_rdpc_settings_t) !*rdpc_priv_t
{
    const priv: *rdpc_priv_t = try allocator.create(rdpc_priv_t);
    errdefer allocator.destroy(priv);
    priv.* = .{};
    priv.allocator = allocator;
    priv.sub = try allocator.create(rdpc_priv_sub_t);
    errdefer allocator.destroy(priv.sub);
    priv.sub.* = .{};
    priv.msg = try rdpc_msg.create(allocator, priv);
    errdefer priv.msg.delete();
    // priv.msg gets initalized in create
    try rdpc_gcc.init_gcc_defaults(priv.msg, settings);
    try rdpc_msg.init_client_info_defaults(priv.msg, settings);
    try rdpc_caps.init_caps_defaults(priv.msg, settings);
    return priv;
}
