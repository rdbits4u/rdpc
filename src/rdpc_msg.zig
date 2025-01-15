const std = @import("std");
const parse = @import("parse");
const rdpc_priv = @import("rdpc_priv.zig");
const rdpc_gcc = @import("rdpc_gcc.zig");
const c = @cImport(
{
    @cInclude("librdpc.h");
});

pub const rdpc_msg_t = struct
{
    allocator: *const std.mem.Allocator = undefined,
    mcs_userid: u16 = 0,
    mcs_channels_joined: u16 = 0,
    pad0: i32 = 0,
    priv: *rdpc_priv.rdpc_priv_t = undefined,

    //*************************************************************************
    pub fn delete(self: *rdpc_msg_t) void
    {
        self.allocator.destroy(self);
    }

    //*************************************************************************
    // 2.2.1.1 Client X.224 Connection Request PDU
    // out
    pub fn connection_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        try s.check_rem(19);
        s.push_layer(5, 0);
        s.out_u8(c.ISO_PDU_CR); // Connection Request - 0xE0
        s.out_u8_skip(2); // dst_ref
        s.out_u8_skip(2); // src_ref
        s.out_u8_skip(1); // class
        // optional RDP protocol negotiation request for RDPv5
        s.out_u8(1);
        s.out_u8(0);
        s.out_u16_le(8);
        s.out_u32_le(3);
        s.push_layer(0, 1); // end
        const bytes = s.layer_subtract(1, 0);
        const li: u8 = @truncate(bytes - 5);
        s.pop_layer(0); // go back
        s.out_u8(3); // version
        s.out_u8(0);
        s.out_u16_be(bytes); // set PDU size
        s.out_u8(li); // LI (length indicator)
        s.pop_layer(1); // go back to end
    }

    //*************************************************************************
    // 2.2.1.2 Server X.224 Connection Confirm PDU
    // in
    pub fn connection_confirm(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        try s.check_rem(6);
        s.in_u8_skip(5);
        const code = s.in_u8();
        if (code != c.ISO_PDU_CC) // Connection Confirm - 0xD0
        {
            return error.BadTag;
        }
    }

    //*************************************************************************
    // 2.2.1.3 Client MCS Connect Initial PDU with GCC Conference Create
    // Request
    // out
    pub fn conference_create_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        const gccs = try parse.create(self.allocator, 1024);
        defer gccs.delete();
        try rdpc_gcc.gcc_out_data(self, gccs);
        const gcc_slice = gccs.get_out_slice();
        try s.check_rem(7);
        s.push_layer(7, 0);
        s.push_layer(0, 1);
        try ber_out_header(s, c.MCS_CONNECT_INITIAL, 0x80); // update later
        s.push_layer(0, 2);
        try ber_out_header(s, c.BER_TAG_OCTET_STRING, 1);
        try s.check_rem(1);
        s.out_u8(1);
        try ber_out_header(s, c.BER_TAG_OCTET_STRING, 1);
        try s.check_rem(1);
        s.out_u8(1);
        try ber_out_header(s, c.BER_TAG_BOOLEAN, 1);
        try s.check_rem(1);
        s.out_u8(0xFF);
        // target params: see table in section 3.2.5.3.3 in RDPBCGR
        try mcs_out_domain_params(s, 34, 2, 0, 0xffff);
        // min params: see table in section 3.2.5.3.3 in RDPBCGR
        try mcs_out_domain_params(s, 1, 1, 1, 0x420);
        // max params: see table in section 3.2.5.3.3 in RDPBCGR
        try mcs_out_domain_params(s, 0xffff, 0xffff, 0xffff, 0xffff);
        // insert gcc_data
        const gcc_bytes: u16 = @truncate(gcc_slice.len);
        try ber_out_header(s, c.BER_TAG_OCTET_STRING, gcc_bytes);
        try s.check_rem(gcc_slice.len);
        s.out_u8_slice(gcc_slice);
        s.push_layer(0, 3); // save end
        // update MCS_CONNECT_INITIAL
        const length_after = s.layer_subtract(3, 2);
        if (length_after < 0x80)
        {
            // length_after must be >= 0x80 or above space for
            // MCS_CONNECT_INITIAL will be wrong
            return error.BadSize;
        }
        s.pop_layer(1);
        try ber_out_header(s, c.MCS_CONNECT_INITIAL, length_after);
        s.pop_layer(0); // go to iso header
        try iso_out_data_header(s, s.layer_subtract(3, 0));
        s.pop_layer(3); // go to end
    }

    //*************************************************************************
    // 2.2.1.4 Server MCS Connect Response PDU with GCC Conference Create
    // Response
    // in
    pub fn conference_create_response(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        var length: u16 = undefined;
        try iso_in_data_header(s, &length);
        try s.check_rem(length - 7);
        try ber_in_header(s, c.MCS_CONNECT_RESPONSE, &length);
        try s.check_rem(length);
        try ber_in_header(s, c.BER_TAG_RESULT, &length);
        try s.check_rem(length);
        var result: u64 = 0;
        while (length > 0) : (length -= 1)
        {
            result = (result << 8) | s.in_u8();
        }
        if (result != 0)
        {
            return error.BadResult;
        }
        try ber_in_header(s, c.BER_TAG_INTEGER, &length);
        try s.check_rem(length);
        result = 0;
        while (length > 0) : (length -= 1)
        {
            result = (result << 8) | s.in_u8();
        }
        if (result != 0)
        {
            return error.BadResult;
        }
        try mcs_in_domain_params(s);
        try ber_in_header(s, c.BER_TAG_OCTET_STRING, &length);
        try s.check_rem(length);
        const ls = try parse.create_from_slice(self.allocator,
                    s.in_u8_slice(length));
        defer ls.delete();
        try rdpc_gcc.gcc_in_data(self, ls);
    }

    //*************************************************************************
    // 2.2.1.5 Client MCS Erect Domain Request PDU
    // out
    pub fn erect_domain_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        try s.check_rem(7 + 5);
        s.push_layer(7, 0);
        s.out_u8(c.MCS_EDRQ << 2); // Erect Domain Request(1) << 2
        s.out_u16_be(1); // subHeight
        s.out_u16_be(1); // subInterval
        s.push_layer(0, 1);
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(1, 0));
        s.pop_layer(1);
    }

    //*************************************************************************
    // 2.2.1.6 Client MCS Attach User Request PDU
    // out
    pub fn attach_user_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        try s.check_rem(7 + 1);
        s.push_layer(7, 0);
        s.out_u8(c.MCS_AURQ << 2); // Attach User Request(10) << 2
        s.push_layer(0, 1);
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(1, 0));
        s.pop_layer(1);
    }

    //*************************************************************************
    // 2.2.1.7 Server MCS Attach User Confirm PDU
    // in
    pub fn attach_user_confirm(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        var length: u16 = undefined;
        try iso_in_data_header(s, &length);
        try s.check_rem(length - 7);
        try s.check_rem(1);
        const opcode = s.in_u8(); // Attach User Confirm(11) << 2
        if ((opcode >> 2) != c.MCS_AUCF)
        {
            return error.BadCode;
        }
        if ((opcode & 2) != 0)
        {
            try s.check_rem(1);
            const result = s.in_u8();
            if (result != 0)
            {
                return error.BadCode;
            }
            try s.check_rem(2);
            self.mcs_userid = s.in_u16_be();
            _ = self.priv.logln(@src(), "mcs_userid {}", .{self.mcs_userid});
        }
        else
        {
            return error.BadCode;
        }
    }

    //*************************************************************************
    // 2.2.1.8 Client MCS Channel Join Request PDU
    // out
    pub fn channel_join_request(self: *rdpc_msg_t,
            s: *parse.parse_t, chanid: u16) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        try s.check_rem(7 + 5);
        s.push_layer(7, 0);
        s.out_u8(c.MCS_CJRQ << 2); // Channel Join Request(14) << 2
        s.out_u16_be(self.mcs_userid);
        s.out_u16_be(chanid);
        s.push_layer(0, 1);
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(1, 0));
        s.pop_layer(1);
    }

    //*************************************************************************
    // 2.2.1.9 Server MCS Channel Join Confirm PDU
    // in
    pub fn channel_join_confirm(self: *rdpc_msg_t,
            s: *parse.parse_t, chanid: *u16) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        var length: u16 = undefined;
        try iso_in_data_header(s, &length);
        try s.check_rem(length - 7);
        try s.check_rem(1);
        const opcode = s.in_u8(); // Channel Join Confirm(15) << 2
        if ((opcode >> 2) != c.MCS_CJCF)
        {
            return error.BadCode;
        }
        if ((opcode & 2) != 0)
        {
            try s.check_rem(1);
            const result = s.in_u8();
            if (result != 0)
            {
                return error.BadCode;
            }
            try s.check_rem(2);
            const mcs_userid = s.in_u16_be();
            if (self.mcs_userid != mcs_userid)
            {
                return error.BadUser;
            }
            try s.check_rem(2);
            chanid.* = s.in_u16_be();
            _ = self.priv.logln(@src(), "chanid {}", .{chanid.*});
        }
        else
        {
            return error.BadCode;
        }
    }

    //*************************************************************************
    // 2.2.1.10 Client Security Exchange PDU
    // out
    pub fn security_exchange(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        try s.check_rem(1024);
        // skip for now
    }

    //*************************************************************************
    // 2.2.1.11 Client Info PDU
    // out
    pub fn client_info(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        const ci = self.priv.rdpc.client_info;
        try s.check_rem(7);
        s.push_layer(7, 0); // iso
        try s.check_rem(8);
        s.push_layer(8, 1); // mcs
        try s.check_rem(4);
        s.push_layer(4, 2); // sec
        try s.check_rem(18);
        s.out_u32_le(ci.CodePage);
        s.out_u32_le(ci.flags);
        s.out_u16_le(ci.cbDomain);
        s.out_u16_le(ci.cbUserName);
        s.out_u16_le(ci.cbPassword);
        s.out_u16_le(ci.cbAlternateShell);
        s.out_u16_le(ci.cbWorkingDir);
        try s.check_rem(ci.cbDomain + 2 + ci.cbUserName + 2 +
                ci.cbPassword + 2 + ci.cbAlternateShell + 2 +
                ci.cbWorkingDir + 2);
        s.out_u8_slice(ci.Domain[0..ci.cbDomain + 2]);
        s.out_u8_slice(ci.UserName[0..ci.cbUserName + 2]);
        s.out_u8_slice(ci.Password[0..ci.cbPassword + 2]);
        s.out_u8_slice(ci.AlternateShell[0..ci.cbAlternateShell + 2]);
        s.out_u8_slice(ci.WorkingDir[0..ci.cbWorkingDir + 2]);
        // extra info
        try s.check_rem(2 + 2 + ci.extraInfo.cbClientAddress +
                2 + ci.extraInfo.cbClientDir +
                @sizeOf(@TypeOf(ci.extraInfo.clientTimeZone)) +
                4 + 4);
        s.out_u16_le(ci.extraInfo.clientAddressFamily);
        s.out_u16_le(ci.extraInfo.cbClientAddress);
        s.out_u8_slice(ci.extraInfo.clientAddress[0..ci.extraInfo.cbClientAddress]);
        s.out_u16_le(ci.extraInfo.cbClientDir);
        s.out_u8_slice(ci.extraInfo.clientDir[0..ci.extraInfo.cbClientDir]);
        s.out_u8_slice(ci.extraInfo.clientTimeZone[0..]);
        s.out_u32_le(ci.extraInfo.clientSessionId);
        s.out_u32_le(ci.extraInfo.performanceFlags);
        s.push_layer(0, 3);
        // sec layer
        s.pop_layer(2);
        s.out_u32_le(c.SEC_LOGON_INFO);
        // mcs layer
        s.pop_layer(1);
        try mcs_out_header(s, s.layer_subtract(3, 1), self.mcs_userid,
                c.MCS_GLOBAL_CHANNEL);
        // iso layer
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(3, 0));
        // back to end
        s.pop_layer(3);
    }

    //*************************************************************************
    // in
    pub fn auto_detect_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        try s.check_rem(6);
    }

    //*************************************************************************
    // out
    pub fn auto_detect_response(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        try s.check_rem(1024);
    }

};

//*****************************************************************************
pub fn create(allocator: *const std.mem.Allocator,
        priv: *rdpc_priv.rdpc_priv_t) !*rdpc_msg_t
{
    const msg: *rdpc_msg_t = try allocator.create(rdpc_msg_t);
    msg.* = .{};
    msg.priv = priv;
    msg.allocator = allocator;
    return msg;
}

//*****************************************************************************
fn ber_out_header(s: *parse.parse_t, tagval: u16, length: u16) !void
{
    if (tagval > 0xFF)
    {
        try s.check_rem(2);
        s.out_u16_be(tagval);
    }
    else
    {
        try s.check_rem(1);
        s.out_u8(@truncate(tagval));
    }
    if (length >= 0x80)
    {
        try s.check_rem(3);
        s.out_u8(0x82);
        s.out_u16_be(length);
    }
    else
    {
        try s.check_rem(1);
        s.out_u8(@truncate(length));
    }
}

//*****************************************************************************
fn ber_in_header(s: *parse.parse_t, tagval: u16, length: *u16) !void
{
    var ltagval: u16 = undefined;
    var llength: u16 = undefined;
    if (tagval > 0xFF)
    {
        try s.check_rem(2);
        ltagval = s.in_u16_be();
    }
    else
    {
        try s.check_rem(1);
        ltagval = s.in_u8();
    }
    if (ltagval != tagval)
    {
        return error.BadTag;
    }
    try s.check_rem(1);
    llength = s.in_u8();
    if ((llength & 0x80) != 0)
    {
        if (llength == 0x82)
        {
            try s.check_rem(2);
            length.* = s.in_u16_be();
        }
        else if (llength == 0x81)
        {
            try s.check_rem(1);
            length.* = s.in_u8();
        }
        else
        {
            return error.BadParse;
        }
    }
    else
    {
        length.* = llength;
    }
}

//*****************************************************************************
fn ber_out_integer(s: *parse.parse_t, val: u16) !void
{
    try ber_out_header(s, c.BER_TAG_INTEGER, 2);
    try s.check_rem(2);
    s.out_u16_be(val);
}

//*****************************************************************************
fn iso_out_data_header(s: *parse.parse_t, length: u16) !void
{
    if (length < 7)
    {
        return error.BadTag;
    }
    s.out_u8(3);            // version
    s.out_u8(0);            // reserved
    s.out_u16_be(length);
    s.out_u8(2);            // hdrlen
    s.out_u8(c.ISO_PDU_DT); // code - data 0xF0
    s.out_u8(0x80);         // eot
}

//*****************************************************************************
fn iso_in_data_header(s: *parse.parse_t, length: *u16) !void
{
    try s.check_rem(7);
    if (s.in_u8() != 3)             // version
    {
        return error.BadVersion;
    }
    s.in_u8_skip(1);                // reserved
    const len = s.in_u16_be();
    if (len < 7)
    {
        return error.BadLength;
    }
    s.in_u8_skip(1);                // hdrlen
    if (s.in_u8() != c.ISO_PDU_DT)  // code - data 0xF0
    {
        return error.BadTag;
    }
    s.in_u8_skip(1);                // eot
    length.* = len;
}

//*****************************************************************************
fn mcs_out_header(s: *parse.parse_t, length: u16,
        userid: u16, channel: u16) !void
{
    if (length < 8)
    {
        return error.BadTag;
    }
    s.out_u8(c.MCS_SDRQ << 2);
    s.out_u16_be(userid);
    s.out_u16_be(channel);
    s.out_u8(0x70); // flags
    s.out_u16_be(0x8000 | (length - 8));
}

//*****************************************************************************
fn mcs_out_domain_params(s: *parse.parse_t, max_channels: u16,
        max_users: u16, max_tokens: u16, max_pdusize: u16) !void
{
    try ber_out_header(s, c.MCS_TAG_DOMAIN_PARAMS, 32);
    try ber_out_integer(s, max_channels);
    try ber_out_integer(s, max_users);
    try ber_out_integer(s, max_tokens);
    try ber_out_integer(s, 1);          // num_priorities
    try ber_out_integer(s, 0);          // min_throughput
    try ber_out_integer(s, 1);          // max_height
    try ber_out_integer(s, max_pdusize);
    try ber_out_integer(s, 2);          // ver_protocol
}

//*****************************************************************************
fn mcs_in_domain_params(s: *parse.parse_t) !void
{
    var length: u16 = undefined;
    try ber_in_header(s, c.MCS_TAG_DOMAIN_PARAMS, &length);
    try s.check_rem(length);
    s.in_u8_skip(length);
}

//*********************************************************************************
// convert utf8 to utf16le but still writes out to u8
// make sure there is a 2 byte nil in the output
pub fn out_uni(utf16_out: []u8, utf8_in: []const u8,
        bytes_written_out: *usize) !void
{
    @memset(utf16_out, 0);
    bytes_written_out.* = 0;
    var out_index: usize = 0;
    const out_count = (utf16_out.len >> 1) - 1;
    var in_index: usize = 0;
    const in_count = utf8_in.len;
    while (in_index < in_count)
    {
        var chr21: u21 = 0;
        const in_bytes =
                try std.unicode.utf8ByteSequenceLength(utf8_in[in_index]);
        if (in_index + in_bytes > in_count)
        {
            return error.Unexpected;
        }
        const in_start = in_index;
        const in_end = in_start + in_bytes;
        chr21 = switch (in_bytes)
        {
            1 => utf8_in[in_index],
            2 => try std.unicode.utf8Decode2(utf8_in[in_start..in_end]),
            3 => try std.unicode.utf8Decode3(utf8_in[in_start..in_end]),
            4 => try std.unicode.utf8Decode4(utf8_in[in_start..in_end]),
            else => return error.Unexpected,
        };
        in_index += in_bytes;
        if (chr21 < 0x10000)
        {
            if (out_index + 1 > out_count)
            {
                return error.NoRoom;
            }
            utf16_out[out_index * 2] = @truncate(chr21);
            utf16_out[out_index * 2 + 1] = @truncate(chr21 >> 8);
            out_index += 1;
            bytes_written_out.* += 1;
        }
        else
        {
            if (out_index + 2 > out_count)
            {
                return error.NoRoom;
            }
            const high = @as(u16, @intCast((chr21 - 0x10000) >> 10)) + 0xD800;
            const low = @as(u16, @intCast(chr21 & 0x3FF)) + 0xDC00;
            utf16_out[out_index * 2] = @truncate(low);
            utf16_out[out_index * 2 + 1] = @truncate(low >> 8);
            utf16_out[out_index * 2 + 2] = @truncate(high);
            utf16_out[out_index * 2 + 3] = @truncate(high >> 8);
            out_index += 2;
            bytes_written_out.* += 2;
        }
    }
}

//*********************************************************************************
// convert utf8 to utf16le but ignore when all does not fit
pub fn out_uni_no_room_ok(out: []u8, text: []const u8,
        bytes_written_out: *usize) !void
{
    const result = out_uni(out, text, bytes_written_out);
    if (result) |_| { } else |err|
    {
        if (err != error.NoRoom)
        {
            return err;
        }
    }
}

//*********************************************************************************
pub fn init_client_info_defaults(msg: *rdpc_msg_t,
        settings: *c.rdpc_settings_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const rdpc = &msg.priv.rdpc;
    var client_info = &rdpc.client_info;
    client_info.CodePage = 0;
    client_info.flags = c.RDP_INFO_MOUSE |
            c.RDP_INFO_DISABLECTRLALTDEL |
            c.RDP_INFO_UNICODE |
            c.RDP_INFO_MAXIMIZESHELL;
    var bytes_written_out: usize = 0;
    try out_uni_no_room_ok(&client_info.UserName, &settings.username,
            &bytes_written_out);
    client_info.cbUserName = @truncate(bytes_written_out);
}
