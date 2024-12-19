
const std = @import("std");
const nsrdpc_priv = @import("rdpc_priv.zig");
const nsparse = @import("parse.zig");
const c = @cImport(
{
    @cInclude("librdpc_gcc.h");
    @cInclude("librdpc_constants.h");
    @cInclude("librdpc.h");
});

pub const rdpc_msg_t = struct
{
    allocator: *const std.mem.Allocator = undefined,
    i1: i32 = 1,
    i2: i32 = 2,
    i3: i32 = 3,
    rdpc_priv: *nsrdpc_priv.rdpc_priv_t = undefined,

    //*************************************************************************
    pub fn delete(rdpc_msg: *rdpc_msg_t) void
    {
        rdpc_msg.allocator.destroy(rdpc_msg);
    }

    //*************************************************************************
    pub fn connection_request(rdpc_msg: *rdpc_msg_t, s: *nsparse.parse_t) bool
    {
        _ = rdpc_msg;
        if (!s.check_rem(19))
        //if (!s.check_rem(1))
        {
            return false;
        }
        // X.224 Connection Request PDU
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
        return true;
    }

    //*************************************************************************
    pub fn connection_confirm(rdpc_msg: *rdpc_msg_t, s: *nsparse.parse_t) bool
    {
        _ = rdpc_msg;
        if (!s.check_rem(6))
        {
            return false;
        }
        s.in_u8_skip(5);
        const code = s.in_u8();
        if (code != 0xD0) // Connection Confirm
        {
            return false;
        }
        return true;
    }

    //*************************************************************************
    pub fn conference_create_request(rdpc_msg: *rdpc_msg_t,
            s: *nsparse.parse_t) bool
    {
        const gccs = nsparse.create(rdpc_msg.allocator, 1024) catch
            return false;
        defer gccs.delete();

        if (!gcc_out_data(rdpc_msg, gccs))
        {
            return false;
        }

        const gcc_slice = gccs.get_out_slice();

        //if (!s.check_rem(7 + 5 + 5 + 1 + 5 + 1 + 5 + 1))
        if (!s.check_rem(1024))
        {
            return false;
        }
        s.push_layer(7, 0);

        s.push_layer(0, 1);
        ber_out_header(s, c.MCS_CONNECT_INITIAL, 0x80); // update later
        s.push_layer(0, 2);

        ber_out_header(s, c.BER_TAG_OCTET_STRING, 1);
        s.out_u8(1);

        ber_out_header(s, c.BER_TAG_OCTET_STRING, 1);
        s.out_u8(1);

        ber_out_header(s, c.BER_TAG_BOOLEAN, 1);
        s.out_u8(0xFF);

        // target params: see table in section 3.2.5.3.3 in RDPBCGR
        mcs_out_domain_params(s, 34, 2, 0, 0xffff);

        // min params: see table in section 3.2.5.3.3 in RDPBCGR
        mcs_out_domain_params(s, 1, 1, 1, 0x420);

        // max params: see table in section 3.2.5.3.3 in RDPBCGR
        mcs_out_domain_params(s, 0xffff, 0xffff, 0xffff, 0xffff);

        // insert gcc_data
        const gcc_bytes: u16 = @truncate(gcc_slice.len);
        ber_out_header(s, c.BER_TAG_OCTET_STRING, gcc_bytes);
        s.out_u8_slice(gcc_slice);

        s.push_layer(0, 3); // save end

        // update MCS_CONNECT_INITIAL
        const length_after = s.layer_subtract(3, 2);
        if (length_after < 0x80)
        {
            // length_after must be >= 0x80 or above space for
            // MCS_CONNECT_INITIAL will be wrong
            return false;
        }
        s.pop_layer(1);
        ber_out_header(s, c.MCS_CONNECT_INITIAL, length_after);

        s.pop_layer(0); // go to iso header
        iso_out_data_header(s, s.layer_subtract(3, 0));

        s.pop_layer(3); // go to end
        return true;
    }

};

//*****************************************************************************
pub fn create(allocator: *const std.mem.Allocator,
        rdpc_priv: *nsrdpc_priv.rdpc_priv_t) !*rdpc_msg_t
{
    const rdpc_msg: *rdpc_msg_t = try allocator.create(rdpc_msg_t);
    rdpc_msg.* = .{};
    rdpc_msg.rdpc_priv = rdpc_priv;
    rdpc_msg.allocator = allocator;
    return rdpc_msg;
}

//*****************************************************************************
fn ber_out_header(s: *nsparse.parse_t, tagval: u16, length: u16) void
{
    if (tagval > 0xFF)
    {
        s.out_u16_be(tagval);
    }
    else
    {
        s.out_u8(@truncate(tagval));
    }
    if (length >= 0x80)
    {
        s.out_u8(0x82);
        s.out_u16_be(length);
    }
    else
    {
        s.out_u8(@truncate(length));
    }
}

//*****************************************************************************
fn ber_out_integer(s: *nsparse.parse_t, val: u16) void
{
    ber_out_header(s, c.BER_TAG_INTEGER, 2);
    s.out_u16_be(val);
}

//*****************************************************************************
fn iso_out_data_header(s: *nsparse.parse_t, length: u16) void
{
    s.out_u8(3);            //version
    s.out_u8(0);            // reserved
    s.out_u16_be(length);
    s.out_u8(2);            // hdrlen
    s.out_u8(c.ISO_PDU_DT); // code - data
    s.out_u8(0x80);         // eot
}

fn mcs_out_domain_params(s: *nsparse.parse_t, max_channels: u16,
        max_users: u16, max_tokens: u16, max_pdusize: u16) void
{
    ber_out_header(s, c.MCS_TAG_DOMAIN_PARAMS, 32);
    ber_out_integer(s, max_channels);
    ber_out_integer(s, max_users);
    ber_out_integer(s, max_tokens);
    ber_out_integer(s, 1);              // num_priorities
    ber_out_integer(s, 0);              // min_throughput
    ber_out_integer(s, 1);              // max_height
    ber_out_integer(s, max_pdusize);
    ber_out_integer(s, 2);              // ver_protocol
}

fn gcc_out_data(rdpc_msg: *rdpc_msg_t, s: *nsparse.parse_t) bool
{
    if (!s.check_rem(512))
    {
        return false;
    }
    
    // Generic Conference Control (T.124) ConferenceCreateRequest
    s.out_u16_be(5);
    s.out_u16_be(0x14);
    s.out_u8(0x7c);
    s.out_u16_be(1);

    s.push_layer(2, 0);

    // PER encoded GCC conference create request PDU
    s.out_u16_be(0x0008);
    s.out_u16_be(0x0010);
    s.out_u16_be(0x0001);
    s.out_u16_be(0xc000);
    s.out_u16_be(0x4475); // Du
    s.out_u16_be(0x6361); // ca
    s.out_u16_be(0x811c);

    const rdpc = &rdpc_msg.rdpc_priv.rdpc;

    // CS_CORE
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

    return true;
}
