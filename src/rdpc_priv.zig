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

const g_devel = false;

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
    allocator: *const std.mem.Allocator,
    msg: *rdpc_msg.rdpc_msg_t,
    sub: *rdpc_priv_sub_t,

    //*************************************************************************
    pub fn create(allocator: *const std.mem.Allocator,
            settings: *c.struct_rdpc_settings_t) !*rdpc_priv_t
    {
        const priv: *rdpc_priv_t = try allocator.create(rdpc_priv_t);
        errdefer allocator.destroy(priv);
        const  sub = try allocator.create(rdpc_priv_sub_t);
        errdefer allocator.destroy(sub);
        sub.* = .{};
        const msg = try rdpc_msg.rdpc_msg_t.create(allocator, priv);
        errdefer msg.delete();
        priv.* = .{.allocator = allocator, .msg = msg, .sub = sub};
        // priv.msg gets initalized in create
        try rdpc_gcc.init_gcc_defaults(priv.msg, settings);
        try rdpc_msg.init_client_info_defaults(priv.msg, settings);
        try rdpc_caps.init_caps_defaults(priv.msg, settings);
        return priv;
    }

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
            const alloc_buf = try std.fmt.allocPrint(self.allocator.*,
                    fmt, args);
            defer self.allocator.free(alloc_buf);
            const alloc1_buf = try std.fmt.allocPrintZ(self.allocator.*,
                    "rdpc:{s}:{s}", .{src.fn_name, alloc_buf});
            defer self.allocator.free(alloc1_buf);
            _ = alog_msg(&self.rdpc, alloc1_buf.ptr);
        }
    }

    //*************************************************************************
    pub fn logln_devel(self: *rdpc_priv_t, src: std.builtin.SourceLocation,
            comptime fmt: []const u8, args: anytype) !void
    {
        if (g_devel)
        {
            return self.logln(src, fmt, args);
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
        const outs = try parse.parse_t.create(self.allocator, 1024);
        defer outs.delete();
        self.sub.state_fn = rdpc_priv_t.state0_fn;
        try self.msg.connection_request(outs);
        return self.send_slice_to_server(outs.get_out_slice());
    }

    //*************************************************************************
    pub fn process_server_slice_data(self: *rdpc_priv_t, slice: []u8,
            bytes_processed: ?*u32) !c_int
    {
        try self.logln_devel(@src(), "in slice bytes {}", .{slice.len});
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
            try self.logln_devel(@src(), "RDP PDU TPKT len {}", .{len});
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
                try self.logln_devel(@src(),
                        "RDP PDU Fast-Path len {}", .{len});
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
            try self.logln_devel(@src(),
                    "returning LIBRDPC_ERROR_NEED_MORE len {} " ++
                    "slice.len {}",
                    .{len, slice.len});
            //try hexdump.printHexDump(0, slice[0..len]);
            return c.LIBRDPC_ERROR_NEED_MORE;
        }
        // check if bytes_processed is nil
        if (bytes_processed) |abytes_processed|
        {
            abytes_processed.* = len;
        }
        try self.logln_devel(@src(), "len {}", .{len});
        //try self.logln(@src(), "hexdump len {}", .{len});
        //try hexdump.printHexDump(0, slice[0..len]);
        return self.sub.state_fn(self, slice[0..len]);
    }

    //*************************************************************************
    pub fn send_mouse_event(self: *rdpc_priv_t, event: u16,
            xpos: u16, ypos: u16) !c_int
    {
        try self.logln_devel(@src(), "event 0x{X} xpos {} ypos {}",
                .{event, xpos, ypos});
        // make sure we are connected
        if (rdpc_priv_t.state6_fn == self.sub.state_fn)
        {
            try self.logln_devel(@src(), "connected", .{});
            return self.msg.send_mouse_event(event, xpos, ypos);
        }
        try self.logln(@src(), "not fully connected", .{});
        return c.LIBRDPC_ERROR_NOT_CONNECTED;
    }

    //*************************************************************************
    pub fn send_mouse_event_ex(self: *rdpc_priv_t, event: u16,
            xpos: u16, ypos: u16) !c_int
    {
        try self.logln_devel(@src(), "event 0x{X} xpos {} ypos {}",
                .{event, xpos, ypos});
        // make sure we are connected
        if (rdpc_priv_t.state6_fn == self.sub.state_fn)
        {
            try self.logln_devel(@src(), "connected", .{});
            return self.msg.send_mouse_event_ex(event, xpos, ypos);
        }
        try self.logln(@src(), "not fully connected", .{});
        return c.LIBRDPC_ERROR_NOT_CONNECTED;
    }

    //*************************************************************************
    pub fn send_keyboard_scancode(self: *rdpc_priv_t, keyboard_flags: u16,
            key_code: u16) !c_int
    {
        try self.logln_devel(@src(),
                "keyboard_flags 0x{X} key_code {}",
                .{keyboard_flags, key_code});
        // make sure we are connected
        if (rdpc_priv_t.state6_fn == self.sub.state_fn)
        {
            try self.logln_devel(@src(), "connected", .{});
            return self.msg.send_keyboard_scancode(keyboard_flags,
                    key_code);
        }
        try self.logln(@src(), "not fully connected", .{});
        return c.LIBRDPC_ERROR_NOT_CONNECTED;
    }

    //*************************************************************************
    pub fn send_keyboard_sync(self: *rdpc_priv_t, toggle_flags: u32) !c_int
    {
        try self.logln_devel(@src(), "toggle_flags 0x{X}", .{toggle_flags});
        // make sure we are connected
        if (rdpc_priv_t.state6_fn == self.sub.state_fn)
        {
            try self.logln_devel(@src(), "connected", .{});
            return self.msg.send_keyboard_sync(toggle_flags);
        }
        try self.logln(@src(), "not fully connected", .{});
        return c.LIBRDPC_ERROR_NOT_CONNECTED;
    }

    //*************************************************************************
    pub fn send_frame_ack(self: *rdpc_priv_t, frame_id: u32) !c_int
    {
        try self.logln_devel(@src(), "frame_id 0x{X}", .{frame_id});
        // make sure we are connected
        if (rdpc_priv_t.state6_fn == self.sub.state_fn)
        {
            try self.logln_devel(@src(), "connected", .{});
            return self.msg.send_frame_ack(frame_id);
        }
        try self.logln(@src(), "not fully connected", .{});
        return c.LIBRDPC_ERROR_NOT_CONNECTED;
    }

    //*************************************************************************
    pub fn channel_send_data(self: *rdpc_priv_t, channel_id: u16,
            total_bytes: u32, flags: u32, slice: []u8) !c_int
    {
        // make sure we are connected
        if (rdpc_priv_t.state6_fn == self.sub.state_fn)
        {
            try self.logln_devel(@src(), "connected", .{});
            return self.msg.channel_send_data(channel_id, total_bytes,
                    flags, slice);
        }
        try self.logln(@src(), "not fully connected", .{});
        return c.LIBRDPC_ERROR_NOT_CONNECTED;
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
        const ins = try parse.parse_t.create_from_slice(self.allocator, slice);
        defer ins.delete();
        try self.msg.connection_confirm(ins);
        const outs = try parse.parse_t.create(self.allocator, 8192);
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
        const ins = try parse.parse_t.create_from_slice(self.allocator, slice);
        defer ins.delete();
        try self.msg.conference_create_response(ins);
        const outs = try parse.parse_t.create(self.allocator, 8192);
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
        const ins = try parse.parse_t.create_from_slice(self.allocator, slice);
        defer ins.delete();
        try self.msg.attach_user_confirm(ins);
        const outs = try parse.parse_t.create(self.allocator, 8192);
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
        const ins = try parse.parse_t.create_from_slice(self.allocator, slice);
        defer ins.delete();
        var chanid: u16 = 0;
        try self.msg.channel_join_confirm(ins, &chanid);
        var rv: c_int = c.LIBRDPC_ERROR_NONE;
        const outs = try parse.parse_t.create(self.allocator, 8192);
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
        const ins = try parse.parse_t.create_from_slice(self.allocator, slice);
        defer ins.delete();
        var chanid: u16 = 0;
        try self.msg.channel_join_confirm(ins, &chanid);
        var rv: c_int = c.LIBRDPC_ERROR_NONE;
        const outs = try parse.parse_t.create(self.allocator, 8192);
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
        const ins = try parse.parse_t.create_from_slice(self.allocator, slice);
        defer ins.delete();
        try self.msg.process_sec(ins);
        self.sub.state_fn = rdpc_priv_t.state6_fn;
        return c.LIBRDPC_ERROR_NONE;
    }

    /// process_rdp
    //*************************************************************************
    fn state6_fn(self: *rdpc_priv_t, slice: []u8) !c_int
    {
        try self.logln_devel(@src(), "", .{});
        const ins = try parse.parse_t.create_from_slice(self.allocator, slice);
        defer ins.delete();
        try self.msg.process_rdp(ins);
        return c.LIBRDPC_ERROR_NONE;
    }

};

//*****************************************************************************
pub fn error_to_c_int(err: anyerror) c_int
{
    return rdpc_msg.error_to_c_int(err);
}
