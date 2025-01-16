const std = @import("std");
const parse = @import("parse");
const rdpc_msg = @import("rdpc_msg.zig");
const rdpc_gcc = @import("rdpc_gcc.zig");
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
        const ins = parse.create_from_slice(self.allocator, slice) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer ins.delete();
        if (self.msg.connection_confirm(ins)) |_| { } else |err|
        {
            _ = self.logln(@src(),
                    "connection_confirm failed err [{}]", .{err});
            return c.LIBRDPC_ERROR_PARSE;
        }
        const outs = parse.create(self.allocator, 8192) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer outs.delete();
        if (self.msg.conference_create_request(outs)) |_| { } else |err|
        {
            _ = self.logln(@src(),
                    "conference_create_request failed err [{}]", .{err});
            return c.LIBRDPC_ERROR_PARSE;
        }
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
        const ins = parse.create_from_slice(self.allocator, slice) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer ins.delete();
        if (self.msg.conference_create_response(ins)) |_| { } else |err|
        {
            _ = self.logln(@src(),
                    "conference_create_response failed err [{}]", .{err});
            return c.LIBRDPC_ERROR_PARSE;
        }
        const outs = parse.create(self.allocator, 8192) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer outs.delete();
        if (self.msg.erect_domain_request(outs)) |_| { } else |err|
        {
            _ = self.logln(@src(),
                    "erect_domain_request failed err [{}]", .{err});
            return c.LIBRDPC_ERROR_PARSE;
        }
        var rv = self.send_slice_to_server(outs.get_out_slice());
        if (rv == c.LIBRDPC_ERROR_NONE)
        {
            outs.reset(0) catch
                return c.LIBRDPC_ERROR_MEMORY;
            if (self.msg.attach_user_request(outs)) |_| { } else |err|
            {
                _ = self.logln(@src(),
                        "attach_user_request failed err [{}]", .{err});
                return c.LIBRDPC_ERROR_PARSE;
            }
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
        const ins = parse.create_from_slice(self.allocator, slice) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer ins.delete();
        if (self.msg.attach_user_confirm(ins)) |_| { } else |err|
        {
            _ = self.logln(@src(),
                    "attach_user_confirm failed err [{}]", .{err});
            return c.LIBRDPC_ERROR_PARSE;
        }
        const outs = parse.create(self.allocator, 8192) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer outs.delete();
        var rv: c_int = c.LIBRDPC_ERROR_NONE;
        // join MCS_USER_CHANNEL
        var chanid: u16 = c.MCS_USERCHANNEL_BASE;
        chanid += self.msg.mcs_userid;
        if (self.msg.channel_join_request(outs, chanid)) |_| { } else |err|
        {
            _ = self.logln(@src(),
                    "channel_join_request failed err [{}]", .{err});
            return c.LIBRDPC_ERROR_PARSE;
        }
        rv = self.send_slice_to_server(outs.get_out_slice());
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
        const ins = parse.create_from_slice(self.allocator, slice) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer ins.delete();
        var chanid: u16 = 0;
        if (self.msg.channel_join_confirm(ins, &chanid)) |_| { } else |err|
        {
            _ = self.logln(@src(),
                    "channel_join_confirm failed err [{}]", .{err});
            return c.LIBRDPC_ERROR_PARSE;
        }
        var rv: c_int = c.LIBRDPC_ERROR_NONE;
        const outs = parse.create(self.allocator, 8192) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer outs.delete();
        // join MCS_GLOBAL_CHANNEL
        chanid = c.MCS_GLOBAL_CHANNEL;
        if (self.msg.channel_join_request(outs, chanid)) |_| { } else |err|
        {
            _ = self.logln(@src(),
                    "channel_join_request failed err [{}]", .{err});
            return c.LIBRDPC_ERROR_PARSE;
        }
        rv = self.send_slice_to_server(outs.get_out_slice());
        if (rv == c.LIBRDPC_ERROR_NONE)
        {
            self.sub.state_fn = rdpc_priv_t.state4_fn;
        }
        return rv;
    }

    /// state3_fn sent channel_join_request, process
    /// channel_join_confirm and send channel_join_request
    //*************************************************************************
    fn state4_fn(self: *rdpc_priv_t, slice: []u8) c_int
    {
        _ = self.logln(@src(), "", .{});
        const ins = parse.create_from_slice(self.allocator, slice) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer ins.delete();
        var chanid: u16 = 0;
        if (self.msg.channel_join_confirm(ins, &chanid)) |_| { } else |err|
        {
            _ = self.logln(@src(),
                    "channel_join_confirm failed err [{}]", .{err});
            return c.LIBRDPC_ERROR_PARSE;
        }
        var rv: c_int = c.LIBRDPC_ERROR_NONE;
        const outs = parse.create(self.allocator, 8192) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer outs.delete();
        const joined = self.msg.mcs_channels_joined;
        if (joined < self.rdpc.cgcc.net.channelCount)
        {
            chanid = self.rdpc.sgcc.net.channelIdArray[joined];
            _ = self.logln(@src(), "chanid {} joined {}", .{chanid, joined});
            if (self.msg.channel_join_request(outs, chanid)) |_| { } else |err|
            {
                _ = self.logln(@src(),
                        "channel_join_request failed err [{}]", .{err});
                return c.LIBRDPC_ERROR_PARSE;
            }
            rv = self.send_slice_to_server(outs.get_out_slice());
            self.msg.mcs_channels_joined += 1;

        }
        else
        {
            if (self.msg.security_exchange(outs)) |_| { } else |err|
            {
                _ = self.logln(@src(),
                        "security_exchange failed err [{}]", .{err});
                return c.LIBRDPC_ERROR_PARSE;
            }
            rv = self.send_slice_to_server(outs.get_out_slice());
            if (rv == c.LIBRDPC_ERROR_NONE)
            {
                outs.reset(0) catch
                    return c.LIBRDPC_ERROR_MEMORY;
                if (self.msg.client_info(outs)) |_| { } else |err|
                {
                    _ = self.logln(@src(),
                            "client_info failed err [{}]", .{err});
                    return c.LIBRDPC_ERROR_PARSE;
                }
                rv = self.send_slice_to_server(outs.get_out_slice());
                if (rv == c.LIBRDPC_ERROR_NONE)
                {
                    self.sub.state_fn = rdpc_priv_t.state5_fn;
                }
            }
        }
        return rv;
    }

    /// state4_fn sent security_exchange and client_info, process
    /// auto_detect_request and send auto_detect_respone
    //*************************************************************************
    fn state5_fn(self: *rdpc_priv_t, slice: []u8) c_int
    {
        _ = self.logln(@src(), "", .{});
        const ins = parse.create_from_slice(self.allocator, slice) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer ins.delete();
        if (self.msg.auto_detect_request(ins)) |_| { } else |err|
        {
            _ = self.logln(@src(),
                    "auto_detect_request failed err [{}]", .{err});
            return c.LIBRDPC_ERROR_PARSE;
        }
        const outs = parse.create(self.allocator, 8192) catch
            return c.LIBRDPC_ERROR_MEMORY;
        defer outs.delete();
        if (self.msg.auto_detect_response(outs)) |_| { } else |err|
        {
            _ = self.logln(@src(),
                    "auto_detect_response failed err [{}]", .{err});
            return c.LIBRDPC_ERROR_PARSE;
        }
        const rv = self.send_slice_to_server(outs.get_out_slice());
        if (rv == c.LIBRDPC_ERROR_NONE)
        {
            //self.sub.state_fn = rdpc_priv_t.state5_fn;
        }
        return rv;
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
    // priv.msg gets initalized in create
    try rdpc_gcc.init_gcc_defaults(priv.msg, settings);
    try rdpc_msg.init_client_info_defaults(priv.msg, settings);
    return priv;
}
