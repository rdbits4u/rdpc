const std = @import("std");
const parse = @import("parse");
const rdpc_priv = @import("rdpc_priv.zig");
const rdpc_msg = @import("rdpc_msg.zig");
const c = @cImport(
{
    @cInclude("librdpc.h");
});

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
fn out_channel(chan: *c.struct_CHANNEL_DEF, name: []const u8, options: u32) void
{
    @memcpy(chan.name[0..name.len], name);
    chan.options = options;
}

//*********************************************************************************
pub fn init_gcc_defaults(msg: *rdpc_msg.rdpc_msg_t,
        settings: *c.rdpc_settings_t) !void
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

//*****************************************************************************
pub fn gcc_out_data(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
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
pub fn gcc_in_data(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
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