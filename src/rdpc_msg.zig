const std = @import("std");
const parse = @import("parse");
const rdpc_priv = @import("rdpc_priv.zig");
const c = @cImport(
{
    @cInclude("librdpc.h");
});

pub const rdpc_msg_t = struct
{
    allocator: *const std.mem.Allocator = undefined,
    i1: i32 = 1,
    i2: i32 = 2,
    i3: i32 = 3,
    priv: *rdpc_priv.rdpc_priv_t = undefined,

    //*************************************************************************
    pub fn delete(self: *rdpc_msg_t) void
    {
        self.allocator.destroy(self);
    }

    //*************************************************************************
    // X.224 Connection Request PDU
    // out
    pub fn connection_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self;
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
    // X.224 Connection Confirm PDU
    // in
    pub fn connection_confirm(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self;
        try s.check_rem(6);
        s.in_u8_skip(5);
        const code = s.in_u8();
        if (code != c.ISO_PDU_CC) // Connection Confirm - 0xD0
        {
            return error.BadTag;
        }
    }

    //*************************************************************************
    // out
    pub fn conference_create_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        const gccs = try parse.create(self.allocator, 1024);
        defer gccs.delete();
        try gcc_out_data(self, gccs);
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
    // in
    pub fn conference_create_response(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        var length: u16 = undefined;
        try iso_in_data_header(s, &length);
        try ber_in_header(s, c.MCS_CONNECT_RESPONSE, &length);
        try ber_in_header(s, c.BER_TAG_RESULT, &length);
        try s.check_rem(1);
        const result = s.in_u8();
        if (result != 0)
        {
            return error.BadResult;
        }
        try ber_in_header(s, c.BER_TAG_INTEGER, &length);
        try s.check_rem(1);
        const remaining = s.in_u8();
        try s.check_rem(remaining);

        try mcs_in_domain_params(s);
        try ber_in_header(s, c.BER_TAG_OCTET_STRING, &length);

        try s.check_rem(21 + 1);
        s.in_u8_skip(21);
        length = s.in_u8();
        std.debug.print("a len {X}\n", .{length});
        if ((length & 0x80) != 0)
        {
            try s.check_rem(1);
            length = (length << 8) | s.in_u8();
            length = length & 0x7FFF;
            std.debug.print("b len {X}\n", .{length});
        }

        var core = self.priv.rdpc.sgcc.core;
        var sec = self.priv.rdpc.sgcc.sec;
        var net = self.priv.rdpc.sgcc.net;
        var msgchannel = self.priv.rdpc.sgcc.msgchannel;
        var multitransport = self.priv.rdpc.sgcc.multitransport;
        while (s.check_rem_bool(4))
        {
            s.push_layer(0, 0);
            const tag = s.in_u16_le();
            const tag_len = s.in_u16_le();
            std.debug.print("tag 0x{X} len 0x{X}\n", .{tag, tag_len});
            if (tag_len < 5)
            {
                return error.BadResult;
            }
            try s.check_rem(tag_len - 4);
            const ls = try parse.create_from_slice(self.allocator,
                    s.in_u8_slice(tag_len - 4));
            switch (tag)
            {
                c.SC_CORE => // 0x0C01
                {
                    _ = self.priv.logln(@src(), "SC_CORE", .{});
                    core.header.type = tag;
                    core.header.length = tag_len;
                    try ls.check_rem(8);
                    core.clientRequestedProtocols = ls.in_u32_le();
                    core.earlyCapabilityFlags = ls.in_u32_le();
                },
                c.SC_SECURITY => // 0xC02
                {
                    _ = self.priv.logln(@src(), "CS_SECURITY", .{});
                    sec.header.type = tag;
                    sec.header.length = tag_len;
                    try ls.check_rem(8);
                    sec.encryptionMethod = ls.in_u32_le();
                    sec.encryptionLevel = ls.in_u32_le();
                },
                c.SC_NET => // 0xC03
                {
                    net.header.type = tag;
                    net.header.length = tag_len;
                    try ls.check_rem(4);
                    net.MCSChannelId = ls.in_u16_le();
                    net.channelCount = ls.in_u16_le();
                    _ = self.priv.logln(@src(), "SC_NET channelCount {}", .{net.channelCount});
                },
                c.SC_MCS_MSGCHANNEL => // 0x0C04
                {
                    _ = self.priv.logln(@src(), "SC_MCS_MSGCHANNEL", .{});
                    msgchannel.header.type = tag;
                    msgchannel.header.length = tag_len;
                },
                c.SC_MULTITRANSPORT => // 0x0C08
                {
                    _ = self.priv.logln(@src(), "SC_MULTITRANSPORT", .{});
                    multitransport.header.type = tag;
                    multitransport.header.length = tag_len;
                },
                else =>
                {
                    _ = self.priv.logln(@src(), "unknown tag 0x{X}", .{tag});
                }
            }
            ls.delete();
            s.pop_layer(0);
            s.in_u8_skip(tag_len);
        }

    }

    //*************************************************************************
    // out
    pub fn erect_domain_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        const gccs = try parse.create(self.allocator, 1024);
        defer gccs.delete();
        try s.check_rem(1024);
    }

    //*************************************************************************
    // out
    pub fn attach_user_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        const gccs = try parse.create(self.allocator, 1024);
        defer gccs.delete();
        try s.check_rem(1024);
    }

    //*************************************************************************
    // in
    pub fn attach_user_confirm(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self;
        try s.check_rem(6);
    }

    //*************************************************************************
    // out
    pub fn channel_join_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        const gccs = try parse.create(self.allocator, 1024);
        defer gccs.delete();
        try s.check_rem(1024);
    }

    //*************************************************************************
    // in
    pub fn channel_join_confirm(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self;
        try s.check_rem(6);
    }

    //*************************************************************************
    // out
    pub fn security_exchange(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        const gccs = try parse.create(self.allocator, 1024);
        defer gccs.delete();
        try s.check_rem(1024);
    }

    //*************************************************************************
    // out
    pub fn client_info(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        const gccs = try parse.create(self.allocator, 1024);
        defer gccs.delete();
        try s.check_rem(1024);
    }

    //*************************************************************************
    // in
    pub fn auto_detect_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self;
        try s.check_rem(6);
    }

    //*************************************************************************
    // out
    pub fn auto_detect_response(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        const gccs = try parse.create(self.allocator, 1024);
        defer gccs.delete();
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
    try s.check_rem(7);
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

//*****************************************************************************
fn gcc_out_data(rdpc_msg: *rdpc_msg_t, s: *parse.parse_t) !void
{
    // Generic Conference Control (T.124) ConferenceCreateRequest
    try s.check_rem(7);
    s.out_u16_be(5);
    s.out_u16_be(0x14);
    s.out_u8(0x7c);
    s.out_u16_be(1);

    try s.check_rem(2);
    s.push_layer(2, 0);

    // PER encoded GCC conference create request PDU
    try s.check_rem(14);
    s.out_u16_be(0x0008);
    s.out_u16_be(0x0010);
    s.out_u16_be(0x0001);
    s.out_u16_be(0xc000);
    s.out_u16_be(0x4475); // Du
    s.out_u16_be(0x6361); // ca
    s.out_u16_be(0x811c);

    const rdpc = &rdpc_msg.priv.rdpc;

    // CS_CORE
    try s.check_rem(24 + rdpc.cgcc.core.clientName.len + 12 +
            rdpc.cgcc.core.imeFileName.len + 14 +
            rdpc.cgcc.core.clientDigProductId.len + 24);
    s.push_layer(4, 1);
    s.out_u32_le(rdpc.cgcc.core.version);
    s.out_u16_le(rdpc.cgcc.core.desktopWidth);
    s.out_u16_le(rdpc.cgcc.core.desktopHeight);
    s.out_u16_le(rdpc.cgcc.core.colorDepth);
    s.out_u16_le(rdpc.cgcc.core.SASSequence);
    s.out_u32_le(rdpc.cgcc.core.keyboardLayout);
    s.out_u32_le(rdpc.cgcc.core.clientBuild);
    s.out_u8_slice(&rdpc.cgcc.core.clientName);
    s.out_u32_le(rdpc.cgcc.core.keyboardType);
    s.out_u32_le(rdpc.cgcc.core.keyboardSubType);
    s.out_u32_le(rdpc.cgcc.core.keyboardFunctionKey);
    s.out_u8_slice(&rdpc.cgcc.core.imeFileName);
    s.out_u16_le(rdpc.cgcc.core.postBeta2ColorDepth);
    s.out_u16_le(rdpc.cgcc.core.clientProductId);
    s.out_u32_le(rdpc.cgcc.core.serialNumber);
    s.out_u16_le(rdpc.cgcc.core.highColorDepth);
    s.out_u16_le(rdpc.cgcc.core.supportedColorDepths);
    s.out_u16_le(rdpc.cgcc.core.earlyCapabilityFlags);
    s.out_u8_slice(&rdpc.cgcc.core.clientDigProductId);
    s.out_u8(rdpc.cgcc.core.connectionType);
    s.out_u8(0); // pad1octet
    s.out_u32_le(rdpc.cgcc.core.serverSelectedProtocol);
    s.out_u32_le(rdpc.cgcc.core.desktopPhysicalWidth);
    s.out_u32_le(rdpc.cgcc.core.desktopPhysicalHeight);
    s.out_u16_be(rdpc.cgcc.core.desktopOrientation);
    s.out_u32_le(rdpc.cgcc.core.desktopScaleFactor);
    s.out_u32_le(rdpc.cgcc.core.deviceScaleFactor);
    s.push_layer(0, 2);
    rdpc.cgcc.core.header.length = s.layer_subtract(2, 1);
    s.pop_layer(1);
    s.out_u16_le(rdpc.cgcc.core.header.type);
    s.out_u16_le(rdpc.cgcc.core.header.length);
    s.pop_layer(2);

    // CS_SEC
    try s.check_rem(12);
    s.push_layer(4, 1);
    s.out_u32_le(rdpc.cgcc.sec.encryptionMethods);
    s.out_u32_le(rdpc.cgcc.sec.extEncryptionMethods);
    s.push_layer(0, 2);
    rdpc.cgcc.sec.header.length = s.layer_subtract(2, 1);
    s.pop_layer(1);
    s.out_u16_le(rdpc.cgcc.sec.header.type);
    s.out_u16_le(rdpc.cgcc.sec.header.length);
    s.pop_layer(2);

    // CS_NET
    try s.check_rem(8 + rdpc.cgcc.net.channelCount * (8 + 4));
    s.push_layer(4, 1);
    s.out_u32_le(rdpc.cgcc.net.channelCount);
    var index: u32 = 0;
    const count = rdpc.cgcc.net.channelCount;
    while (index < count)
    {
        s.out_u8_slice(&rdpc.cgcc.net.channelDefArray[index].name);
        s.out_u32_le(rdpc.cgcc.net.channelDefArray[index].options);
        index += 1;
    }
    s.push_layer(0, 2);
    rdpc.cgcc.net.header.length = s.layer_subtract(2, 1);
    s.pop_layer(1);
    s.out_u16_le(rdpc.cgcc.net.header.type);
    s.out_u16_le(rdpc.cgcc.net.header.length);
    s.pop_layer(2);

    // CS_CLUSTER
    try s.check_rem(12);
    s.push_layer(4, 1);
    s.out_u32_le(rdpc.cgcc.cluster.Flags);
    s.out_u32_le(rdpc.cgcc.cluster.RedirectedSessionID);
    s.push_layer(0, 2);
    rdpc.cgcc.cluster.header.length = s.layer_subtract(2, 1);
    s.pop_layer(1);
    s.out_u16_le(rdpc.cgcc.cluster.header.type);
    s.out_u16_le(rdpc.cgcc.cluster.header.length);
    s.pop_layer(2);

    s.pop_layer(0);
    s.out_u8_skip(2);
    s.pop_layer(2);
}
