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
        try gcc_in_data(self, ls);
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
            s: *parse.parse_t) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        try s.check_rem(7 + 5);
        s.push_layer(7, 0);
        s.out_u8(c.MCS_CJRQ << 2); // Channel Join Request(14) << 2
        s.out_u16_be(self.mcs_userid);
        s.out_u16_be(0x03ea); // chanid todo
        s.push_layer(0, 1);
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(1, 0));
        s.pop_layer(1);
    }

    //*************************************************************************
    // 2.2.1.9 Server MCS Channel Join Confirm PDU
    // in
    pub fn channel_join_confirm(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
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
            self.mcs_userid = s.in_u16_be();
            try s.check_rem(2);
            const chanid = s.in_u16_be(); // chanid todo
            _ = self.priv.logln(@src(), "chanid {}", .{chanid});
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
    }

    //*************************************************************************
    // 2.2.1.11 Client Info PDU
    // out
    pub fn client_info(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        _ = self.priv.logln(@src(), "", .{});
        try s.check_rem(1024);
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
fn gcc_out_data(msg: *rdpc_msg_t, s: *parse.parse_t) !void
{
    // Generic Conference Control (T.124) ConferenceCreateRequest
    try s.check_rem(7);
    s.out_u16_be(5);
    s.out_u16_be(0x14);
    s.out_u8(0x7c);
    s.out_u16_be(1);

    try s.check_rem(2);
    s.out_u8_skip(2); // ?

    // PER encoded GCC conference create request PDU
    try s.check_rem(14);
    s.out_u16_be(0x0008);
    s.out_u16_be(0x0010);
    s.out_u16_be(0x0001);
    s.out_u16_be(0xc000);
    s.out_u16_be(0x4475); // Du
    s.out_u16_be(0x6361); // ca

    s.push_layer(2, 0);

    var core = msg.priv.rdpc.cgcc.core;
    var sec = msg.priv.rdpc.cgcc.sec;
    var net = msg.priv.rdpc.cgcc.net;
    var cluster = msg.priv.rdpc.cgcc.cluster;
    var monitor = msg.priv.rdpc.cgcc.monitor;
    var msgchannel = msg.priv.rdpc.cgcc.msgchannel;
    var monitor_ex = msg.priv.rdpc.cgcc.monitor_ex;
    var multitransport = msg.priv.rdpc.cgcc.multitransport;

    // CS_CORE
    if (core.header.type != 0)
    {
        try s.check_rem(24 + core.clientName.len + 12 +
                core.imeFileName.len + 14 +
                core.clientDigProductId.len + 24);
        s.push_layer(4, 1);
        s.out_u32_le(core.version);
        s.out_u16_le(core.desktopWidth);
        s.out_u16_le(core.desktopHeight);
        s.out_u16_le(core.colorDepth);
        s.out_u16_le(core.SASSequence);
        s.out_u32_le(core.keyboardLayout);
        s.out_u32_le(core.clientBuild);
        s.out_u8_slice(&core.clientName);
        s.out_u32_le(core.keyboardType);
        s.out_u32_le(core.keyboardSubType);
        s.out_u32_le(core.keyboardFunctionKey);
        s.out_u8_slice(&core.imeFileName);
        s.out_u16_le(core.postBeta2ColorDepth);
        s.out_u16_le(core.clientProductId);
        s.out_u32_le(core.serialNumber);
        s.out_u16_le(core.highColorDepth);
        s.out_u16_le(core.supportedColorDepths);
        s.out_u16_le(core.earlyCapabilityFlags);
        s.out_u8_slice(&core.clientDigProductId);
        s.out_u8(core.connectionType);
        s.out_u8(0); // pad1octet
        s.out_u32_le(core.serverSelectedProtocol);
        s.out_u32_le(core.desktopPhysicalWidth);
        s.out_u32_le(core.desktopPhysicalHeight);
        s.out_u16_be(core.desktopOrientation);
        s.out_u32_le(core.desktopScaleFactor);
        s.out_u32_le(core.deviceScaleFactor);
        s.push_layer(0, 2);
        core.header.length = s.layer_subtract(2, 1);
        s.pop_layer(1);
        s.out_u16_le(core.header.type);
        s.out_u16_le(core.header.length);
        s.pop_layer(2);
    }

    // CS_SEC
    if (sec.header.type != 0)
    {
        try s.check_rem(12);
        s.push_layer(4, 1);
        s.out_u32_le(sec.encryptionMethods);
        s.out_u32_le(sec.extEncryptionMethods);
        s.push_layer(0, 2);
        sec.header.length = s.layer_subtract(2, 1);
        s.pop_layer(1);
        s.out_u16_le(sec.header.type);
        s.out_u16_le(sec.header.length);
        s.pop_layer(2);
    }

    // CS_NET
    if (net.header.type != 0)
    {
        try s.check_rem(8 + net.channelCount * (8 + 4));
        s.push_layer(4, 1);
        s.out_u32_le(net.channelCount);
        var index: u32 = 0;
        const count = net.channelCount;
        while (index < count)
        {
            s.out_u8_slice(&net.channelDefArray[index].name);
            s.out_u32_le(net.channelDefArray[index].options);
            index += 1;
        }
        s.push_layer(0, 2);
        net.header.length = s.layer_subtract(2, 1);
        s.pop_layer(1);
        s.out_u16_le(net.header.type);
        s.out_u16_le(net.header.length);
        s.pop_layer(2);
    }

    // CS_CLUSTER
    if (cluster.header.type != 0)
    {
        try s.check_rem(12);
        s.push_layer(4, 1);
        s.out_u32_le(cluster.Flags);
        s.out_u32_le(cluster.RedirectedSessionID);
        s.push_layer(0, 2);
        cluster.header.length = s.layer_subtract(2, 1);
        s.pop_layer(1);
        s.out_u16_le(cluster.header.type);
        s.out_u16_le(cluster.header.length);
        s.pop_layer(2);
    }

    // CS_MONITOR
    if (monitor.header.type != 0)
    {
        try s.check_rem(12 + monitor.monitorCount * (5 + 4));
        s.push_layer(4, 1);
        s.out_u32_le(monitor.flags);
        s.out_u32_le(monitor.monitorCount);
        var index: u32 = 0;
        const count = monitor.monitorCount;
        while (index < count)
        {
            const mon = monitor.monitorDefArray[index];
            s.out_i32_le(mon.left);
            s.out_i32_le(mon.top);
            s.out_i32_le(mon.right);
            s.out_i32_le(mon.bottom);
            s.out_u32_le(mon.flags);
            index += 1;
        }
        s.push_layer(0, 2);
        monitor.header.length = s.layer_subtract(2, 1);
        s.pop_layer(1);
        s.out_u16_le(monitor.header.type);
        s.out_u16_le(monitor.header.length);
        s.pop_layer(2);
    }

    // CS_MCS_MSGCHANNEL
    if (msgchannel.header.type != 0)
    {
        try s.check_rem(8);
        s.push_layer(4, 1);
        s.out_u32_le(msgchannel.flags);
        s.push_layer(0, 2);
        msgchannel.header.length = s.layer_subtract(2, 1);
        s.pop_layer(1);
        s.out_u16_le(msgchannel.header.type);
        s.out_u16_le(msgchannel.header.length);
        s.pop_layer(2);
    }

    // CS_MONITOR_EX
    if (monitor_ex.header.type != 0)
    {
        try s.check_rem(16 + monitor_ex.monitorCount * (5 + 4));
        s.push_layer(4, 1);
        s.out_u32_le(monitor_ex.flags);
        s.out_u32_le(monitor_ex.monitorAttributeSize);
        s.out_u32_le(monitor_ex.monitorCount);
        var index: u32 = 0;
        const count = monitor_ex.monitorCount;
        while (index < count)
        {
            const mon = monitor_ex.monitorAttributesArray[index];
            s.out_u32_le(mon.physicalWidth);
            s.out_u32_le(mon.physicalHeight);
            s.out_u32_le(mon.orientation);
            s.out_u32_le(mon.desktopScaleFactor);
            s.out_u32_le(mon.deviceScaleFactor);
            index += 1;
        }
        s.push_layer(0, 2);
        monitor_ex.header.length = s.layer_subtract(2, 1);
        s.pop_layer(1);
        s.out_u16_le(monitor_ex.header.type);
        s.out_u16_le(monitor_ex.header.length);
        s.pop_layer(2);
    }

    // CS_MULTITRANSPORT
    if (multitransport.header.type != 0)
    {
        try s.check_rem(8);
        s.push_layer(4, 1);
        s.out_u32_le(multitransport.flags);
        s.push_layer(0, 2);
        multitransport.header.length = s.layer_subtract(2, 1);
        s.pop_layer(1);
        s.out_u16_le(multitransport.header.type);
        s.out_u16_le(multitransport.header.length);
        s.pop_layer(2);
    }

    s.push_layer(0, 2);
    var size_after = s.layer_subtract(2, 0) - 2;
    s.pop_layer(0);
    size_after = size_after | 0x8000;
    s.out_u16_be(size_after);
    s.pop_layer(2);
}

//*****************************************************************************
fn gcc_in_data(msg: *rdpc_msg_t, s: *parse.parse_t) !void
{
    try s.check_rem(21 + 1);
    s.in_u8_skip(21);
    var length: u16 = s.in_u8();
    if ((length & 0x80) != 0)
    {
        try s.check_rem(1);
        length = (length << 8) | s.in_u8();
        length = length & 0x7FFF;
    }
    try s.check_rem(length);
    var core = msg.priv.rdpc.sgcc.core;
    var sec = msg.priv.rdpc.sgcc.sec;
    var net = msg.priv.rdpc.sgcc.net;
    var msgchannel = msg.priv.rdpc.sgcc.msgchannel;
    var multitransport = msg.priv.rdpc.sgcc.multitransport;
    while (s.check_rem_bool(4))
    {
        s.push_layer(0, 0);
        const tag = s.in_u16_le();
        const tag_len = s.in_u16_le();
        if (tag_len < 5)
        {
            return error.BadResult;
        }
        try s.check_rem(tag_len - 4);
        // code block for defer
        {
            const ls = try parse.create_from_slice(msg.allocator,
                    s.in_u8_slice(tag_len - 4));
            defer ls.delete();
            switch (tag)
            {
                c.SC_CORE => // 0x0C01
                {
                    _ = msg.priv.logln(@src(), "SC_CORE", .{});
                    core.header.type = tag;
                    core.header.length = tag_len;
                    try ls.check_rem(8);
                    core.clientRequestedProtocols = ls.in_u32_le();
                    core.earlyCapabilityFlags = ls.in_u32_le();
                },
                c.SC_SECURITY => // 0xC02
                {
                    _ = msg.priv.logln(@src(), "CS_SECURITY", .{});
                    sec.header.type = tag;
                    sec.header.length = tag_len;
                    try ls.check_rem(8);
                    sec.encryptionMethod = ls.in_u32_le();
                    sec.encryptionLevel = ls.in_u32_le();
                    _ = msg.priv.logln(@src(),
                            "CS_SECURITY encryptionMethod {} encryptionLevel {}",
                            .{sec.encryptionMethod, sec.encryptionLevel});
                    // optional after this
                    if (!ls.check_rem_bool(8))
                    {
                        break;
                    }
                    sec.serverRandomLen = ls.in_u32_le();
                    sec.serverCertLen = ls.in_u32_le();
                    const rand_size = @sizeOf(@TypeOf(sec.serverRandom));
                    if ((sec.serverRandomLen > rand_size) or
                            !ls.check_rem_bool(sec.serverRandomLen))
                    {
                        break;
                    }
                    const rand_slice = sec.serverRandom[0..sec.serverRandomLen];
                    @memcpy(rand_slice, ls.in_u8_slice(sec.serverRandomLen));
                    const cert_size = @sizeOf(@TypeOf(sec.serverCertificate));
                    if ((sec.serverCertLen > cert_size) or
                            !ls.check_rem_bool(sec.serverCertLen))
                    {
                        break;
                    }
                    const cert_slice = sec.serverCertificate[0..sec.serverCertLen];
                    @memcpy(cert_slice, ls.in_u8_slice(sec.serverCertLen));
                },
                c.SC_NET => // 0xC03
                {
                    _ = msg.priv.logln(@src(), "SC_NET", .{});
                    net.header.type = tag;
                    net.header.length = tag_len;
                    try ls.check_rem(4);
                    net.MCSChannelId = ls.in_u16_le();
                    _ = msg.priv.logln(@src(), "SC_NET MCSChannelId {}",
                            .{net.MCSChannelId});
                    net.channelCount = ls.in_u16_le();
                    _ = msg.priv.logln(@src(), "SC_NET channelCount {}",
                            .{net.channelCount});
                    try ls.check_rem(net.channelCount * 2);
                    for (0..net.channelCount) |index|
                    {
                        net.channelIdArray[index] = ls.in_u16_le();
                        _ = msg.priv.logln(@src(),
                                "SC_NET channelIdArray index {} chanid {}",
                                .{index, net.channelIdArray[index]});
                    }
                },
                c.SC_MCS_MSGCHANNEL => // 0x0C04
                {
                    _ = msg.priv.logln(@src(), "SC_MCS_MSGCHANNEL", .{});
                    msgchannel.header.type = tag;
                    msgchannel.header.length = tag_len;
                    try ls.check_rem(2);
                    msgchannel.MCSChannelID = ls.in_u16_le();
                },
                c.SC_MULTITRANSPORT => // 0x0C08
                {
                    _ = msg.priv.logln(@src(), "SC_MULTITRANSPORT", .{});
                    multitransport.header.type = tag;
                    multitransport.header.length = tag_len;
                    try ls.check_rem(4);
                    multitransport.flags = ls.in_u32_le();
                },
                else =>
                {
                    _ = msg.priv.logln(@src(), "unknown tag 0x{X}", .{tag});
                }
            }
        }
        s.pop_layer(0);
        s.in_u8_skip(tag_len);
    }
}

//*********************************************************************************
fn pixels_to_mm(pixels: u32, dpi: i32) u32
{
    if (dpi == 0)
    {
        return 0;
    }
    const ldpi: u32 = @intCast(dpi);
    return (pixels * 254 + ldpi * 5) / (ldpi * 10);
}

//*********************************************************************************
fn out_channel(chan: *c.struct_CHANNEL_DEF, name: []const u8, options: u32) void
{
    @memcpy(chan.name[0..name.len], name);
    chan.options = options;
}

//*********************************************************************************
// convert utf8 to utf16le but still writes out to u8
// make sure there is a 2 byte nil in the output
fn out_uni(utf16_out: []u8, utf8_in: []const u8) !void
{
    @memset(utf16_out, 0);
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
            utf16_out[out_index * 2] = @intCast(chr21);
            utf16_out[out_index * 2 + 1] = @intCast(chr21 >> 8);
            out_index += 1;
        }
        else
        {
            if (out_index + 2 > out_count)
            {
                return error.NoRoom;
            }
            const high = @as(u16, @intCast((chr21 - 0x10000) >> 10)) + 0xD800;
            const low = @as(u16, @intCast(chr21 & 0x3FF)) + 0xDC00;
            utf16_out[out_index * 2] = @intCast(low);
            utf16_out[out_index * 2 + 1] = @intCast(low >> 8);
            utf16_out[out_index * 2 + 2] = @intCast(high);
            utf16_out[out_index * 2 + 3] = @intCast(high >> 8);
            out_index += 2;
        }
    }
}

//*********************************************************************************
// convert utf8 to utf16le but ignore when all does not fit
fn out_uni_no_room_ok(out: []u8, text: []const u8) !void
{
    const result = out_uni(out, text);
    if (result) |_| { } else |err|
    {
        if (err != error.NoRoom)
        {
            return err;
        }
    }
}

//*********************************************************************************
pub fn init_gcc_defaults(msg: *rdpc_msg_t, settings: *c.rdpc_settings_t) !void
{
    const rdpc = &msg.priv.rdpc;
    const core = &rdpc.cgcc.core;
    const sec = &rdpc.cgcc.sec;
    const net = &rdpc.cgcc.net;

    _ = msg.priv.logln(@src(), "", .{});
    // CS_CORE
    core.header.type = c.CS_CORE;           // 0xC001
    core.header.length = 0;                 // calculated
    core.version = 0x00080004;              // RDP 5.0, 5.1, 5.2, 6.0, 6.1,
                                            // 7.0, 7.1, 8.0, and
                                            // 8.1 clients
    core.desktopWidth = @intCast(settings.width);
    core.desktopHeight = @intCast(settings.height);
    core.desktopPhysicalWidth =
            pixels_to_mm(core.desktopWidth, settings.dpix);
    core.desktopPhysicalHeight =
            pixels_to_mm(core.desktopHeight, settings.dpiy);
    core.colorDepth = @intCast(settings.bpp);
    std.debug.print("width {} mmwidth {} height {} mmheight {}\n",
            .{core.desktopWidth, core.desktopHeight,
            core.desktopPhysicalWidth, core.desktopPhysicalHeight});
    core.colorDepth = c.RNS_UD_COLOR_8BPP;  // 0xCA01 8 bits/pixel
    // secure access sequence
    core.SASSequence = c.RNS_UD_SAS_DEL;    // 0xAA03
    core.keyboardLayout = @intCast(settings.keyboard_layout);
    core.clientBuild = 2600;

    try out_uni_no_room_ok(&core.clientName, "PC1");

    // CS_SEC
    sec.header.type = c.CS_SECURITY;        // 0xC002;
    sec.header.length = 0;                  // calculated
    sec.encryptionMethods = c.CRYPT_METHOD_NONE;
    sec.extEncryptionMethods = 0;

    // CS_NET
    net.header.type = c.CS_NET;             // 0xC003
    net.header.length = 0;                  // calculated
    net.channelCount = 0;
    if (settings.rdpsnd != 0)
    {
        out_channel(&net.channelDefArray[net.channelCount], "RDPSND", 0);
        net.channelCount += 1;
    }
    if (settings.cliprdr != 0)
    {
        out_channel(&net.channelDefArray[net.channelCount], "CLIPRDR", 0);
        net.channelCount += 1;
    }
    if (settings.rail != 0)
    {
        out_channel(&net.channelDefArray[net.channelCount], "RAIL", 0);
        net.channelCount += 1;
    }
    if (settings.rdpdr != 0)
    {
        out_channel(&net.channelDefArray[net.channelCount], "RDPDR", 0);
        net.channelCount += 1;
    }
}
