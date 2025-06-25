const std = @import("std");
const parse = @import("parse");
const rdpc_msg = @import("rdpc_msg.zig");
const c = @cImport(
{
    @cInclude("librdpc.h");
});

const get_struct_bytes = rdpc_msg.get_struct_bytes;
const MsgError = rdpc_msg.MsgError;
const err_if = rdpc_msg.err_if;

//*****************************************************************************
fn process_cap_general(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const gen = &msg.priv.rdpc.scaps.general;
    const struct_bytes = get_struct_bytes(@TypeOf(gen.*));
    try s.check_rem(struct_bytes);
    gen.capabilitySetType = s.in_u16_le();
    gen.lengthCapability = s.in_u16_le();
    try err_if(gen.lengthCapability != struct_bytes, MsgError.BadSize);
    gen.osMajorType = s.in_u16_le();
    gen.osMinorType = s.in_u16_le();
    gen.protocolVersion = s.in_u16_le();
    gen.pad2octetsA = s.in_u16_le();
    gen.compressionTypes = s.in_u16_le();
    gen.extraFlags = s.in_u16_le();
    gen.updateCapabilityFlag = s.in_u16_le();
    gen.remoteUnshareFlag = s.in_u16_le();
    gen.compressionLevel = s.in_u16_le();
    gen.refreshRectSupport = s.in_u8();
    gen.suppressOutputSupport = s.in_u8();
}

//*****************************************************************************
fn process_cap_bitmap(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const bitmap = &msg.priv.rdpc.scaps.bitmap;
    const struct_bytes = get_struct_bytes(@TypeOf(bitmap.*));
    try s.check_rem(struct_bytes);
    bitmap.capabilitySetType = s.in_u16_le();
    bitmap.lengthCapability = s.in_u16_le();
    try err_if(bitmap.lengthCapability != struct_bytes, MsgError.BadSize);
    bitmap.preferredBitsPerPixel = s.in_u16_le();
    bitmap.receive1BitPerPixel = s.in_u16_le();
    bitmap.receive4BitsPerPixel = s.in_u16_le();
    bitmap.receive8BitsPerPixel = s.in_u16_le();
    bitmap.desktopWidth = s.in_u16_le();
    bitmap.desktopHeight = s.in_u16_le();
    bitmap.pad2octets = s.in_u16_le();
    bitmap.desktopResizeFlag = s.in_u16_le();
    bitmap.bitmapCompressionFlag = s.in_u16_le();
    bitmap.highColorFlags = s.in_u8();
    bitmap.drawingFlags = s.in_u8();
    bitmap.multipleRectangleSupport = s.in_u16_le();
    bitmap.pad2octetsB = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_order(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const order = &msg.priv.rdpc.scaps.order;
    const struct_bytes = get_struct_bytes(@TypeOf(order.*));
    try s.check_rem(struct_bytes);
    order.capabilitySetType = s.in_u16_le();
    order.lengthCapability = s.in_u16_le();
    try err_if(order.lengthCapability != struct_bytes, MsgError.BadSize);
    const l1 = @sizeOf(@TypeOf(order.terminalDescriptor));
    std.mem.copyForwards(u8, &order.terminalDescriptor, s.in_u8_slice(l1));
    order.pad4octetsA = s.in_u32_le();
    order.desktopSaveXGranularity = s.in_u16_le();
    order.desktopSaveYGranularity = s.in_u16_le();
    order.pad2octetsA = s.in_u16_le();
    order.maximumOrderLevel = s.in_u16_le();
    order.numberFonts = s.in_u16_le();
    order.orderFlags = s.in_u16_le();
    const l2 = @sizeOf(@TypeOf(order.orderSupport));
    std.mem.copyForwards(u8, &order.orderSupport, s.in_u8_slice(l2));
    order.textFlags = s.in_u16_le();
    order.orderSupportExFlags = s.in_u16_le();
    order.pad4octetsB = s.in_u32_le();
    order.desktopSaveSize = s.in_u32_le();
    order.pad2octetsC = s.in_u16_le();
    order.pad2octetsD = s.in_u16_le();
    order.textANSICodePage = s.in_u16_le();
    order.pad2octetsE = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_pointer(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const pointer = &msg.priv.rdpc.scaps.pointer;
    const struct_bytes = get_struct_bytes(@TypeOf(pointer.*));
    try s.check_rem(struct_bytes);
    pointer.capabilitySetType = s.in_u16_le();
    pointer.lengthCapability = s.in_u16_le();
    try err_if(pointer.lengthCapability != struct_bytes, MsgError.BadSize);
    pointer.colorPointerFlag = s.in_u16_le();
    pointer.colorPointerCacheSize = s.in_u16_le();
    pointer.pointerCacheSize = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_share(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const share = &msg.priv.rdpc.scaps.share;
    const struct_bytes = get_struct_bytes(@TypeOf(share.*));
    try s.check_rem(struct_bytes);
    share.capabilitySetType = s.in_u16_le();
    share.lengthCapability = s.in_u16_le();
    try err_if(share.lengthCapability != struct_bytes, MsgError.BadSize);
    share.nodeID = s.in_u16_le();
    share.pad2octets = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_colorcache(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const colortable = &msg.priv.rdpc.scaps.colortable;
    const struct_bytes = get_struct_bytes(@TypeOf(colortable.*));
    try s.check_rem(struct_bytes);
    colortable.capabilitySetType = s.in_u16_le();
    colortable.lengthCapability = s.in_u16_le();
    try err_if(colortable.lengthCapability != struct_bytes, MsgError.BadSize);
    colortable.colorTableCacheSize = s.in_u16_le();
    colortable.pad2octets = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_input(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const input = &msg.priv.rdpc.scaps.input;
    const struct_bytes = get_struct_bytes(@TypeOf(input.*));
    try s.check_rem(struct_bytes);
    input.capabilitySetType = s.in_u16_le();
    input.lengthCapability = s.in_u16_le();
    try err_if(input.lengthCapability != struct_bytes, MsgError.BadSize);
    input.inputFlags = s.in_u16_le();
    input.pad2octetsA = s.in_u16_le();
    input.keyboardLayout = s.in_u32_le();
    input.keyboardType = s.in_u32_le();
    input.keyboardSubType = s.in_u32_le();
    input.keyboardFunctionKey = s.in_u32_le();
    std.mem.copyForwards(u8, &input.imeFileName, s.in_u8_slice(64));
}

//*****************************************************************************
fn process_cap_font(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const font = &msg.priv.rdpc.scaps.font;
    try s.check_rem(4);
    font.capabilitySetType = s.in_u16_le();
    font.lengthCapability = s.in_u16_le();
    if (s.check_rem_bool(4))
    {
        font.fontSupportFlags = s.in_u16_le();
        font.pad2octets = s.in_u16_le();
    }
}

//*****************************************************************************
fn process_cap_bitmapcache_host(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const bitmapcache_hostsupport = &msg.priv.rdpc.scaps.bitmapcache_hostsupport;
    const struct_bytes = get_struct_bytes(@TypeOf(bitmapcache_hostsupport.*));
    try s.check_rem(struct_bytes);
    bitmapcache_hostsupport.capabilitySetType = s.in_u16_le();
    bitmapcache_hostsupport.lengthCapability = s.in_u16_le();
    try err_if(bitmapcache_hostsupport.lengthCapability != struct_bytes, MsgError.BadSize);
    bitmapcache_hostsupport.cacheVersion = s.in_u8();
    bitmapcache_hostsupport.pad1 = s.in_u8();
    bitmapcache_hostsupport.pad2 = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_virtualchannel(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const virtualchannel = &msg.priv.rdpc.scaps.virtualchannel;
    const struct_bytes = get_struct_bytes(@TypeOf(virtualchannel.*));
    try s.check_rem(struct_bytes);
    virtualchannel.capabilitySetType = s.in_u16_le();
    virtualchannel.lengthCapability = s.in_u16_le();
    try err_if(virtualchannel.lengthCapability != struct_bytes, MsgError.BadSize);
    virtualchannel.flags = s.in_u32_le();
    virtualchannel.VCChunkSize = s.in_u32_le();
}

//*****************************************************************************
fn process_cap_drawgdiplus(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const draw_gdiplus = &msg.priv.rdpc.scaps.draw_gdiplus;
    const struct_bytes = get_struct_bytes(@TypeOf(draw_gdiplus.*));
    try s.check_rem(struct_bytes);
    draw_gdiplus.capabilitySetType = s.in_u16_le();
    draw_gdiplus.lengthCapability = s.in_u16_le();
    try err_if(draw_gdiplus.lengthCapability != struct_bytes, MsgError.BadSize);
    draw_gdiplus.drawGDIPlusSupportLevel = s.in_u32_le();
    draw_gdiplus.GdipVersion = s.in_u32_le();
    draw_gdiplus.drawGdiplusCacheLevel = s.in_u32_le();
    draw_gdiplus.GdipCacheEntries.GdipGraphicsCacheEntries = s.in_u16_le();
    draw_gdiplus.GdipCacheEntries.GdipBrushCacheEntries = s.in_u16_le();
    draw_gdiplus.GdipCacheEntries.GdipPenCacheEntries = s.in_u16_le();
    draw_gdiplus.GdipCacheEntries.GdipImageCacheEntries = s.in_u16_le();
    draw_gdiplus.GdipCacheEntries.GdipImageAttributesCacheEntries = s.in_u16_le();
    draw_gdiplus.GdipCacheChunkSize.GdipGraphicsCacheChunkSize = s.in_u16_le();
    draw_gdiplus.GdipCacheChunkSize.GdipObjectBrushCacheChunkSize = s.in_u16_le();
    draw_gdiplus.GdipCacheChunkSize.GdipObjectPenCacheChunkSize = s.in_u16_le();
    draw_gdiplus.GdipCacheChunkSize.GdipObjectImageAttributesCacheChunkSize = s.in_u16_le();
    draw_gdiplus.GdipImageCacheProperties.GdipObjectImageCacheChunkSize = s.in_u16_le();
    draw_gdiplus.GdipImageCacheProperties.GdipObjectImageCacheTotalSize = s.in_u16_le();
    draw_gdiplus.GdipImageCacheProperties.GdipObjectImageCacheMaxSize = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_rail(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const rail = &msg.priv.rdpc.scaps.rail;
    const struct_bytes = get_struct_bytes(@TypeOf(rail.*));
    try s.check_rem(struct_bytes);
    rail.capabilitySetType = s.in_u16_le();
    rail.lengthCapability = s.in_u16_le();
    try err_if(rail.lengthCapability != struct_bytes, MsgError.BadSize);
    rail.RailSupportLevel = s.in_u32_le();
}

//*****************************************************************************
fn process_cap_window(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const windowlist = &msg.priv.rdpc.scaps.windowlist;
    const struct_bytes = get_struct_bytes(@TypeOf(windowlist.*));
    try s.check_rem(struct_bytes);
    windowlist.capabilitySetType = s.in_u16_le();
    windowlist.lengthCapability = s.in_u16_le();
    try err_if(windowlist.lengthCapability != struct_bytes, MsgError.BadSize);
    windowlist.WndSupportLevel = s.in_u32_le();
    windowlist.NumIconCaches = s.in_u8();
    windowlist.NumIconCacheEntries = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_compdesk(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const compdesk = &msg.priv.rdpc.scaps.compdesk;
    const struct_bytes = get_struct_bytes(@TypeOf(compdesk.*));
    try s.check_rem(struct_bytes);
    compdesk.capabilitySetType = s.in_u16_le();
    compdesk.lengthCapability = s.in_u16_le();
    try err_if(compdesk.lengthCapability != struct_bytes, MsgError.BadSize);
    compdesk.CompDeskSupportLevel = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_multifragmentupdate(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const multifragmentupdate = &msg.priv.rdpc.scaps.multifragmentupdate;
    const struct_bytes = get_struct_bytes(@TypeOf(multifragmentupdate.*));
    try s.check_rem(struct_bytes);
    multifragmentupdate.capabilitySetType = s.in_u16_le();
    multifragmentupdate.lengthCapability = s.in_u16_le();
    try err_if(multifragmentupdate.lengthCapability != struct_bytes, MsgError.BadSize);
    multifragmentupdate.MaxRequestSize = s.in_u32_le();
}

//*****************************************************************************
fn process_cap_large_pointer(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const large_pointer = &msg.priv.rdpc.scaps.large_pointer;
    const struct_bytes = get_struct_bytes(@TypeOf(large_pointer.*));
    try s.check_rem(struct_bytes);
    large_pointer.capabilitySetType = s.in_u16_le();
    large_pointer.lengthCapability = s.in_u16_le();
    try err_if(large_pointer.lengthCapability != struct_bytes, MsgError.BadSize);
    large_pointer.largePointerSupportFlags = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_surface_commands(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const surfcmds = &msg.priv.rdpc.scaps.surfcmds;
    const struct_bytes = get_struct_bytes(@TypeOf(surfcmds.*));
    try s.check_rem(struct_bytes);
    surfcmds.capabilitySetType = s.in_u16_le();
    surfcmds.lengthCapability = s.in_u16_le();
    try err_if(surfcmds.lengthCapability != struct_bytes, MsgError.BadSize);
    surfcmds.cmdFlags = s.in_u32_le();
    surfcmds.reserved = s.in_u32_le();
}

//*****************************************************************************
fn process_cap_bitmap_codecs(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const bitmapcodecs = &msg.priv.rdpc.scaps.bitmapcodecs;
    try s.check_rem(4);
    bitmapcodecs.capabilitySetType = s.in_u16_le();
    bitmapcodecs.lengthCapability = s.in_u16_le();
    if (bitmapcodecs.lengthCapability > 4)
    {
        const sbc_max = @sizeOf(@TypeOf(bitmapcodecs.supportedBitmapCodecs));
        var sbc_len = bitmapcodecs.lengthCapability - 4;
        sbc_len = if (sbc_len > sbc_max) sbc_max else sbc_len;
        try msg.priv.logln(@src(), "sbc_max {} sbc_len {}",
                .{sbc_max, sbc_len});
        try s.check_rem(sbc_len);
        bitmapcodecs.lengthSupportedBitmapCodecs = sbc_len;
        std.mem.copyForwards(u8,
                bitmapcodecs.supportedBitmapCodecs[0..sbc_len],
                s.in_u8_slice(sbc_len));
    }
}

//*****************************************************************************
fn process_cap_frame_ack(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const frame_acknowledge = &msg.priv.rdpc.scaps.frame_acknowledge;
    const struct_bytes = get_struct_bytes(@TypeOf(frame_acknowledge.*));
    try s.check_rem(struct_bytes);
    frame_acknowledge.capabilitySetType = s.in_u16_le();
    frame_acknowledge.lengthCapability = s.in_u16_le();
    try err_if(frame_acknowledge.lengthCapability != struct_bytes, MsgError.BadSize);
    frame_acknowledge.maxUnacknowledgedFrameCount = s.in_u32_le();
}

//*****************************************************************************
pub fn process_cap(msg: *rdpc_msg.rdpc_msg_t, cap_type: u16, s: *parse.parse_t) !void
{
    try msg.priv.logln_devel(@src(), "", .{});
    switch (cap_type)
    {
        c.CAPSTYPE_GENERAL => try process_cap_general(msg, s),
        c.CAPSTYPE_BITMAP => try process_cap_bitmap(msg, s),
        c.CAPSTYPE_ORDER => try process_cap_order(msg, s),
        c.CAPSTYPE_POINTER => try process_cap_pointer(msg, s),
        c.CAPSTYPE_SHARE => try process_cap_share(msg, s),
        c.CAPSTYPE_COLORCACHE => try process_cap_colorcache(msg, s),
        c.CAPSTYPE_INPUT => try process_cap_input(msg, s),
        c.CAPSTYPE_FONT => try process_cap_font(msg, s),
        c.CAPSTYPE_BITMAPCACHE_HOSTSUPPORT => try process_cap_bitmapcache_host(msg, s),
        c.CAPSTYPE_VIRTUALCHANNEL => try process_cap_virtualchannel(msg, s),
        c.CAPSTYPE_DRAWGDIPLUS => try process_cap_drawgdiplus(msg, s),
        c.CAPSTYPE_RAIL => try process_cap_rail(msg, s),
        c.CAPSTYPE_WINDOW => try process_cap_window(msg, s),
        c.CAPSETTYPE_COMPDESK => try process_cap_compdesk(msg, s),
        c.CAPSETTYPE_MULTIFRAGMENTUPDATE => try process_cap_multifragmentupdate(msg, s),
        c.CAPSETTYPE_LARGE_POINTER => try process_cap_large_pointer(msg, s),
        c.CAPSETTYPE_SURFACE_COMMANDS => try process_cap_surface_commands(msg, s),
        c.CAPSETTYPE_BITMAP_CODECS => try process_cap_bitmap_codecs(msg, s),
        c.CAPSSETTYPE_FRAME_ACKNOWLEDGE => try process_cap_frame_ack(msg, s),
        else => try msg.priv.logln(@src(), "unknown cap_type {}", .{cap_type}),
    }
}

//*********************************************************************************
pub fn out_cap_general(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const general = &ccaps.general;
    if (general.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(general.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u16_le(general.osMajorType);
        s.out_u16_le(general.osMinorType);
        s.out_u16_le(general.protocolVersion);
        s.out_u16_le(general.pad2octetsA);
        s.out_u16_le(general.compressionTypes);
        s.out_u16_le(general.extraFlags);
        s.out_u16_le(general.updateCapabilityFlag);
        s.out_u16_le(general.remoteUnshareFlag);
        s.out_u16_le(general.compressionLevel);
        s.out_u8(general.refreshRectSupport);
        s.out_u8(general.suppressOutputSupport);
        s.push_layer(0, 6);
        general.lengthCapability = s.layer_subtract(6, 5);
        try err_if(general.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(general.capabilitySetType);
        s.out_u16_le(general.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_bitmap(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const bitmap = &ccaps.bitmap;
    if (bitmap.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(bitmap.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u16_le(bitmap.preferredBitsPerPixel);
        s.out_u16_le(bitmap.receive1BitPerPixel);
        s.out_u16_le(bitmap.receive4BitsPerPixel);
        s.out_u16_le(bitmap.receive8BitsPerPixel);
        s.out_u16_le(bitmap.desktopWidth);
        s.out_u16_le(bitmap.desktopHeight);
        s.out_u16_le(bitmap.pad2octets);
        s.out_u16_le(bitmap.desktopResizeFlag);
        s.out_u16_le(bitmap.bitmapCompressionFlag);
        s.out_u8(bitmap.highColorFlags);
        s.out_u8(bitmap.drawingFlags);
        s.out_u16_le(bitmap.multipleRectangleSupport);
        s.out_u16_le(bitmap.pad2octetsB);
        s.push_layer(0, 6);
        bitmap.lengthCapability = s.layer_subtract(6, 5);
        try err_if(bitmap.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(bitmap.capabilitySetType);
        s.out_u16_le(bitmap.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_order(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const order = &ccaps.order;
    if (order.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(order.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u8_slice(&order.terminalDescriptor);
        s.out_u32_le(order.pad4octetsA);
        s.out_u16_le(order.desktopSaveXGranularity);
        s.out_u16_le(order.desktopSaveYGranularity);
        s.out_u16_le(order.pad2octetsA);
        s.out_u16_le(order.maximumOrderLevel);
        s.out_u16_le(order.numberFonts);
        s.out_u16_le(order.orderFlags);
        s.out_u8_slice(&order.orderSupport);
        s.out_u16_le(order.textFlags);
        s.out_u16_le(order.orderSupportExFlags);
        s.out_u32_le(order.pad4octetsB);
        s.out_u32_le(order.desktopSaveSize);
        s.out_u16_le(order.pad2octetsC);
        s.out_u16_le(order.pad2octetsD);
        s.out_u16_le(order.textANSICodePage);
        s.out_u16_le(order.pad2octetsE);
        s.push_layer(0, 6);
        order.lengthCapability = s.layer_subtract(6, 5);
        try err_if(order.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(order.capabilitySetType);
        s.out_u16_le(order.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_bitmapcache(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const bitmapcache = &ccaps.bitmapcache;
    if (bitmapcache.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(bitmapcache.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u32_le(bitmapcache.pad1);
        s.out_u32_le(bitmapcache.pad2);
        s.out_u32_le(bitmapcache.pad3);
        s.out_u32_le(bitmapcache.pad4);
        s.out_u32_le(bitmapcache.pad5);
        s.out_u32_le(bitmapcache.pad6);
        s.out_u16_le(bitmapcache.Cache0Entries);
        s.out_u16_le(bitmapcache.Cache0MaximumCellSize);
        s.out_u16_le(bitmapcache.Cache1Entries);
        s.out_u16_le(bitmapcache.Cache1MaximumCellSize);
        s.out_u16_le(bitmapcache.Cache2Entries);
        s.out_u16_le(bitmapcache.Cache2MaximumCellSize);
        s.push_layer(0, 6);
        bitmapcache.lengthCapability = s.layer_subtract(6, 5);
        try err_if(bitmapcache.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(bitmapcache.capabilitySetType);
        s.out_u16_le(bitmapcache.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_control(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const control = &ccaps.control;
    if (control.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(control.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u16_le(control.controlFlags);
        s.out_u16_le(control.remoteDetachFlag);
        s.out_u16_le(control.controlInterest);
        s.out_u16_le(control.detachInterest);
        s.push_layer(0, 6);
        control.lengthCapability = s.layer_subtract(6, 5);
        try err_if(control.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(control.capabilitySetType);
        s.out_u16_le(control.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_windowactivation(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const windowactivation = &ccaps.windowactivation;
    if (windowactivation.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(windowactivation.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u16_le(windowactivation.helpKeyFlag);
        s.out_u16_le(windowactivation.helpKeyIndexFlag);
        s.out_u16_le(windowactivation.helpExtendedKeyFlag);
        s.out_u16_le(windowactivation.windowManagerKeyFlag);
        s.push_layer(0, 6);
        windowactivation.lengthCapability = s.layer_subtract(6, 5);
        try err_if(windowactivation.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(windowactivation.capabilitySetType);
        s.out_u16_le(windowactivation.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

// CAPSTYPE_POINTER
//*********************************************************************************
pub fn out_cap_pointer(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const scaps = &msg.priv.rdpc.scaps;
    const ccaps = &msg.priv.rdpc.ccaps;
    const pointer = &ccaps.pointer;
    if ((pointer.capabilitySetType != 0) and
        (scaps.pointer.capabilitySetType != 0))
    {
        // return what server sent
        pointer.colorPointerFlag = scaps.pointer.colorPointerFlag;
        pointer.colorPointerCacheSize = scaps.pointer.colorPointerCacheSize;
        pointer.pointerCacheSize = scaps.pointer.pointerCacheSize;
        try msg.priv.logln(@src(),
                "present colorPointerCacheSize {} pointerCacheSize {}",
                .{pointer.colorPointerCacheSize, pointer.pointerCacheSize});
        const struct_bytes = get_struct_bytes(@TypeOf(pointer.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u16_le(pointer.colorPointerFlag);
        s.out_u16_le(pointer.colorPointerCacheSize);
        s.out_u16_le(pointer.pointerCacheSize);
        s.push_layer(0, 6);
        pointer.lengthCapability = s.layer_subtract(6, 5);
        try err_if(pointer.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(pointer.capabilitySetType);
        s.out_u16_le(pointer.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_share(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const share = &ccaps.share;
    if (share.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(share.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u16_le(share.nodeID);
        s.out_u16_le(share.pad2octets);
        s.push_layer(0, 6);
        share.lengthCapability = s.layer_subtract(6, 5);
        try err_if(share.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(share.capabilitySetType);
        s.out_u16_le(share.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_colortable(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const colortable = &ccaps.colortable;
    if (colortable.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(colortable.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u16_le(colortable.colorTableCacheSize);
        s.out_u16_le(colortable.pad2octets);
        s.push_layer(0, 6);
        colortable.lengthCapability = s.layer_subtract(6, 5);
        try err_if(colortable.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(colortable.capabilitySetType);
        s.out_u16_le(colortable.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_sound(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const sound = &ccaps.sound;
    if (sound.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(sound.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u16_le(sound.soundFlags);
        s.out_u16_le(sound.pad2octetsA);
        s.push_layer(0, 6);
        sound.lengthCapability = s.layer_subtract(6, 5);
        try err_if(sound.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(sound.capabilitySetType);
        s.out_u16_le(sound.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_input(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const input = &ccaps.input;
    if (input.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(input.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u16_le(input.inputFlags);
        s.out_u16_le(input.pad2octetsA);
        s.out_u32_le(input.keyboardLayout);
        s.out_u32_le(input.keyboardType);
        s.out_u32_le(input.keyboardSubType);
        s.out_u32_le(input.keyboardFunctionKey);
        s.out_u8_slice(&input.imeFileName);
        s.push_layer(0, 6);
        input.lengthCapability = s.layer_subtract(6, 5);
        try err_if(input.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(input.capabilitySetType);
        s.out_u16_le(input.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_font(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const font = &ccaps.font;
    if (font.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(font.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u16_le(font.fontSupportFlags);
        s.out_u16_le(font.pad2octets);
        s.push_layer(0, 6);
        font.lengthCapability = s.layer_subtract(6, 5);
        try err_if(font.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(font.capabilitySetType);
        s.out_u16_le(font.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_brush(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const brush = &ccaps.brush;
    if (brush.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(brush.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u32_le(brush.brushSupportLevel);
        s.push_layer(0, 6);
        brush.lengthCapability = s.layer_subtract(6, 5);
        try err_if(brush.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(brush.capabilitySetType);
        s.out_u16_le(brush.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_glyphcache(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const glyphcache = &ccaps.glyphcache;
    if (glyphcache.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(glyphcache.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        for (0..10) |index|
        {
            s.out_u16_le(glyphcache.GlyphCache[index].CacheEntries);
            s.out_u16_le(glyphcache.GlyphCache[index].CacheMaximumCellSize);
        }
        s.out_u32_le(glyphcache.FragCache);
        s.out_u16_le(glyphcache.GlyphSupportLevel);
        s.out_u16_le(glyphcache.pad2octets);
        s.push_layer(0, 6);
        glyphcache.lengthCapability = s.layer_subtract(6, 5);
        try err_if(glyphcache.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(glyphcache.capabilitySetType);
        s.out_u16_le(glyphcache.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_offscreen(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const offscreen = &ccaps.offscreen;
    if (offscreen.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(offscreen.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u32_le(offscreen.offscreenSupportLevel);
        s.out_u16_le(offscreen.offscreenCacheSize);
        s.out_u16_le(offscreen.offscreenCacheEntries);
        s.push_layer(0, 6);
        offscreen.lengthCapability = s.layer_subtract(6, 5);
        try err_if(offscreen.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(offscreen.capabilitySetType);
        s.out_u16_le(offscreen.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_bitmapcache_rev2(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const bitmapcache_rev2 = &ccaps.bitmapcache_rev2;
    if (bitmapcache_rev2.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(bitmapcache_rev2.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u32_le(bitmapcache_rev2.CacheFlags);
        s.out_u8(bitmapcache_rev2.Pad2);
        s.out_u8(bitmapcache_rev2.NumCellCaches);
        s.out_u32_le(bitmapcache_rev2.BitmapCache0CellInfo);
        s.out_u32_le(bitmapcache_rev2.BitmapCache1CellInfo);
        s.out_u32_le(bitmapcache_rev2.BitmapCache2CellInfo);
        s.out_u32_le(bitmapcache_rev2.BitmapCache3CellInfo);
        s.out_u32_le(bitmapcache_rev2.BitmapCache4CellInfo);
        s.out_u8_slice(&bitmapcache_rev2.Pad3);
        s.push_layer(0, 6);
        bitmapcache_rev2.lengthCapability = s.layer_subtract(6, 5);
        try err_if(bitmapcache_rev2.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(bitmapcache_rev2.capabilitySetType);
        s.out_u16_le(bitmapcache_rev2.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_virtualchannel(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const virtualchannel = &ccaps.virtualchannel;
    if (virtualchannel.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(virtualchannel.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u32_le(virtualchannel.flags);
        s.out_u32_le(virtualchannel.VCChunkSize);
        s.push_layer(0, 6);
        virtualchannel.lengthCapability = s.layer_subtract(6, 5);
        try err_if(virtualchannel.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(virtualchannel.capabilitySetType);
        s.out_u16_le(virtualchannel.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_draw_ninegrid(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const draw_ninegrid = &ccaps.draw_ninegrid;
    if (draw_ninegrid.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(draw_ninegrid.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u32_le(draw_ninegrid.drawNineGridSupportLevel);
        s.out_u16_le(draw_ninegrid.drawNineGridCacheSize);
        s.out_u16_le(draw_ninegrid.drawNineGridCacheEntries);
        s.push_layer(0, 6);
        draw_ninegrid.lengthCapability = s.layer_subtract(6, 5);
        try err_if(draw_ninegrid.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(draw_ninegrid.capabilitySetType);
        s.out_u16_le(draw_ninegrid.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_draw_gdiplus(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const draw_gdiplus = &ccaps.draw_gdiplus;
    if (draw_gdiplus.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(draw_gdiplus.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u32_le(draw_gdiplus.drawGDIPlusSupportLevel);
        s.out_u32_le(draw_gdiplus.GdipVersion);
        s.out_u32_le(draw_gdiplus.drawGdiplusCacheLevel);
        s.out_u16_le(draw_gdiplus.GdipCacheEntries.GdipGraphicsCacheEntries);
        s.out_u16_le(draw_gdiplus.GdipCacheEntries.GdipBrushCacheEntries);
        s.out_u16_le(draw_gdiplus.GdipCacheEntries.GdipPenCacheEntries);
        s.out_u16_le(draw_gdiplus.GdipCacheEntries.GdipImageCacheEntries);
        s.out_u16_le(draw_gdiplus.GdipCacheEntries.GdipImageAttributesCacheEntries);
        s.out_u16_le(draw_gdiplus.GdipCacheChunkSize.GdipGraphicsCacheChunkSize);
        s.out_u16_le(draw_gdiplus.GdipCacheChunkSize.GdipObjectBrushCacheChunkSize);
        s.out_u16_le(draw_gdiplus.GdipCacheChunkSize.GdipObjectPenCacheChunkSize);
        s.out_u16_le(draw_gdiplus.GdipCacheChunkSize.GdipObjectImageAttributesCacheChunkSize);
        s.out_u16_le(draw_gdiplus.GdipImageCacheProperties.GdipObjectImageCacheChunkSize);
        s.out_u16_le(draw_gdiplus.GdipImageCacheProperties.GdipObjectImageCacheTotalSize);
        s.out_u16_le(draw_gdiplus.GdipImageCacheProperties.GdipObjectImageCacheMaxSize);
        s.push_layer(0, 6);
        draw_gdiplus.lengthCapability = s.layer_subtract(6, 5);
        try err_if(draw_gdiplus.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(draw_gdiplus.capabilitySetType);
        s.out_u16_le(draw_gdiplus.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_rail(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const rail = &ccaps.rail;
    if (rail.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(rail.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u32_le(rail.RailSupportLevel);
        s.push_layer(0, 6);
        rail.lengthCapability = s.layer_subtract(6, 5);
        try err_if(rail.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(rail.capabilitySetType);
        s.out_u16_le(rail.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_windowlist(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const windowlist = &ccaps.windowlist;
    if (windowlist.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(windowlist.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u32_le(windowlist.WndSupportLevel);
        s.out_u8(windowlist.NumIconCaches);
        s.out_u16_le(windowlist.NumIconCacheEntries);
        s.push_layer(0, 6);
        windowlist.lengthCapability = s.layer_subtract(6, 5);
        try err_if(windowlist.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(windowlist.capabilitySetType);
        s.out_u16_le(windowlist.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_compdesk(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const compdesk = &ccaps.compdesk;
    if (compdesk.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(compdesk.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u16_le(compdesk.CompDeskSupportLevel);
        s.push_layer(0, 6);
        compdesk.lengthCapability = s.layer_subtract(6, 5);
        try err_if(compdesk.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(compdesk.capabilitySetType);
        s.out_u16_le(compdesk.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_multifrag(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const multifrag = &ccaps.multifragmentupdate;
    if (multifrag.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(multifrag.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u32_le(multifrag.MaxRequestSize);
        s.push_layer(0, 6);
        multifrag.lengthCapability = s.layer_subtract(6, 5);
        try err_if(multifrag.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(multifrag.capabilitySetType);
        s.out_u16_le(multifrag.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_largepointer(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const largepointer = &ccaps.large_pointer;
    if (largepointer.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(largepointer.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u16_le(largepointer.largePointerSupportFlags);
        s.push_layer(0, 6);
        largepointer.lengthCapability = s.layer_subtract(6, 5);
        try err_if(largepointer.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(largepointer.capabilitySetType);
        s.out_u16_le(largepointer.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_surfcmds(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const surfcmds = &ccaps.surfcmds;
    if (surfcmds.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(surfcmds.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u32_le(surfcmds.cmdFlags);
        s.out_u32_le(surfcmds.reserved);
        s.push_layer(0, 6);
        surfcmds.lengthCapability = s.layer_subtract(6, 5);
        try err_if(surfcmds.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(surfcmds.capabilitySetType);
        s.out_u16_le(surfcmds.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_bitmapcodecs(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const bitmapcodecs = &ccaps.bitmapcodecs;
    if (bitmapcodecs.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        var struct_bytes = get_struct_bytes(@TypeOf(bitmapcodecs.*));
        // this struct is differnece, the size sent may be smaller
        // than the size of the struct
        try msg.priv.logln(@src(), "struct_bytes {}", .{struct_bytes});
        struct_bytes -= @sizeOf(@TypeOf(bitmapcodecs.supportedBitmapCodecs));
        struct_bytes -= 2;
        struct_bytes += bitmapcodecs.lengthSupportedBitmapCodecs;
        try msg.priv.logln(@src(), "struct_bytes {}", .{struct_bytes});
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        const len = bitmapcodecs.lengthSupportedBitmapCodecs;
        s.out_u8_slice(bitmapcodecs.supportedBitmapCodecs[0..len]);
        s.push_layer(0, 6);
        bitmapcodecs.lengthCapability = s.layer_subtract(6, 5);
        try msg.priv.logln(@src(), "bitmapcodecs.lengthCapability {}",
                .{bitmapcodecs.lengthCapability});
        try msg.priv.logln(@src(),
                "bitmapcodecs.lengthSupportedBitmapCodecs {}",
                .{bitmapcodecs.lengthSupportedBitmapCodecs});
        try err_if(bitmapcodecs.lengthCapability != struct_bytes,
                MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(bitmapcodecs.capabilitySetType);
        s.out_u16_le(bitmapcodecs.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
pub fn out_cap_frameack(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !u16
{
    const ccaps = &msg.priv.rdpc.ccaps;
    const frameack = &ccaps.frame_acknowledge;
    if (frameack.capabilitySetType != 0)
    {
        try msg.priv.logln(@src(), "present", .{});
        const struct_bytes = get_struct_bytes(@TypeOf(frameack.*));
        try s.check_rem(struct_bytes);
        s.push_layer(4, 5);
        s.out_u32_le(frameack.maxUnacknowledgedFrameCount);
        s.push_layer(0, 6);
        frameack.lengthCapability = s.layer_subtract(6, 5);
        try err_if(frameack.lengthCapability != struct_bytes, MsgError.BadSize);
        s.pop_layer(5);
        s.out_u16_le(frameack.capabilitySetType);
        s.out_u16_le(frameack.lengthCapability);
        s.pop_layer(6);
        return 1;
    }
    return 0;
}

//*********************************************************************************
fn add_rfx_bitmapcodec(s: *parse.parse_t) !void
{
    try s.check_rem(16 + 1 + 2);
    const codecGUID = c.CODEC_GUID_REMOTEFX;
    s.out_u8_slice(codecGUID[0..16]);
    s.out_u8(c.CODEC_ID_REMOTEFX);
    const captureFlags: u32 = 0; // 0 or CARDP_CAPS_CAPTURE_NON_CAC
    const codecMode: u8 = 0; // 0(video) or 2(image)
    s.out_u16_le(49); // codecPropertiesLength
    try s.check_rem(49);
    // TS_RFX_CLNT_CAPS_CONTAINER
    s.out_u32_le(49); // length
    s.out_u32_le(captureFlags); // captureFlags
    s.out_u32_le(37); // capsLength
    // TS_RFX_CAPS
    s.out_u16_le(c.CBY_CAPS); // blockType
    s.out_u32_le(8); // blockLen
    s.out_u16_le(1); // numCapsets
    // TS_RFX_CAPSET
    s.out_u16_le(c.CBY_CAPSET); // blockType
    s.out_u32_le(29); // blockLen
    s.out_u8(0x01); // codecId (MUST be set to 0x01)
    s.out_u16_le(c.CLY_CAPSET); // capsetType
    s.out_u16_le(2); // numIcaps
    s.out_u16_le(8); // icapLen
    // TS_RFX_ICAP (RLGR1)
    s.out_u16_le(c.CLW_VERSION_1_0); // version
    s.out_u16_le(c.CT_TILE_64x64); // tileSize
    s.out_u8(codecMode); // flags
    s.out_u8(c.CLW_COL_CONV_ICT); // colConvBits
    s.out_u8(c.CLW_XFORM_DWT_53_A); // transformBits
    s.out_u8(c.CLW_ENTROPY_RLGR1); // entropyBits
    // TS_RFX_ICAP (RLGR3)
    s.out_u16_le(c.CLW_VERSION_1_0); // version
    s.out_u16_le(c.CT_TILE_64x64); // tileSize
    s.out_u8(codecMode); // flags
    s.out_u8(c.CLW_COL_CONV_ICT); // colConvBits
    s.out_u8(c.CLW_XFORM_DWT_53_A); // transformBits
    s.out_u8(c.CLW_ENTROPY_RLGR3); // entropyBits
}

//*********************************************************************************
fn add_jpg_bitmapcodec(s: *parse.parse_t) !void
{
    try s.check_rem(16 + 1 + 2);
    const codecGUID = c.CODEC_GUID_JPEG;
    s.out_u8_slice(codecGUID[0..16]);
    s.out_u8(c.CODEC_ID_JPEG);
    s.out_u16_le(1); // codecPropertiesLength
    try s.check_rem(1);
    s.out_u8(75); // jpeg quality
}

//*********************************************************************************
pub fn init_caps_defaults(msg: *rdpc_msg.rdpc_msg_t,
        settings: *c.rdpc_settings_t) !void
{
    try msg.priv.logln(@src(), "", .{});

    const ccaps = &msg.priv.rdpc.ccaps;
    const rdpc = &msg.priv.rdpc;
    const core = &rdpc.cgcc.core;

    // CAPSTYPE_GENERAL
    ccaps.general.capabilitySetType = c.CAPSTYPE_GENERAL;
    ccaps.general.lengthCapability = 0; // calculated
    ccaps.general.osMajorType = c.OSMAJORTYPE_UNIX;
    ccaps.general.osMinorType = c.OSMINORTYPE_NATIVE_XSERVER;
    ccaps.general.protocolVersion = c.TS_CAPS_PROTOCOLVERSION;
    ccaps.general.pad2octetsA = 0;
    ccaps.general.compressionTypes = 0;
    ccaps.general.extraFlags = c.FASTPATH_OUTPUT_SUPPORTED |
            c.LONG_CREDENTIALS_SUPPORTED | c.NO_BITMAP_COMPRESSION_HDR;
    ccaps.general.updateCapabilityFlag = 0;
    ccaps.general.remoteUnshareFlag = 0;
    ccaps.general.compressionLevel = 0;
    ccaps.general.refreshRectSupport = 1;
    ccaps.general.suppressOutputSupport = 1;

    // CAPSTYPE_BITMAP
    ccaps.bitmap.capabilitySetType = c.CAPSTYPE_BITMAP;
    ccaps.bitmap.lengthCapability = 0; // calculated
    ccaps.bitmap.preferredBitsPerPixel = @intCast(settings.bpp);
    ccaps.bitmap.receive1BitPerPixel = 1;
    ccaps.bitmap.receive4BitsPerPixel = 1;
    ccaps.bitmap.receive8BitsPerPixel = 1;
    ccaps.bitmap.desktopWidth = @intCast(settings.width);
    ccaps.bitmap.desktopHeight = @intCast(settings.height);
    ccaps.bitmap.pad2octets = 0;
    ccaps.bitmap.desktopResizeFlag = 1;
    ccaps.bitmap.bitmapCompressionFlag = 1;
    ccaps.bitmap.highColorFlags = 0;
    ccaps.bitmap.drawingFlags = c.DRAW_ALLOW_SKIP_ALPHA;
    ccaps.bitmap.multipleRectangleSupport = 1;
    ccaps.bitmap.pad2octetsB = 0;

    // CAPSTYPE_ORDER
    ccaps.order.capabilitySetType = c.CAPSTYPE_ORDER;
    ccaps.order.lengthCapability = 0; // calculated
    @memset(&ccaps.order.terminalDescriptor, 0);
    ccaps.order.pad4octetsA = 0;
    ccaps.order.desktopSaveXGranularity = 1;
    ccaps.order.desktopSaveYGranularity = 20;
    ccaps.order.pad2octetsA = 0;
    ccaps.order.maximumOrderLevel = c.ORD_LEVEL_1_ORDERS;
    ccaps.order.numberFonts = 0;
    ccaps.order.orderFlags = c.NEGOTIATEORDERSUPPORT |
            c.ZEROBOUNDSDELTASSUPPORT | c.COLORINDEXSUPPORT;
    @memset(&ccaps.order.orderSupport, 0);
    ccaps.order.textFlags = 0;
    ccaps.order.orderSupportExFlags = 0;
    ccaps.order.pad4octetsB = 0;
    ccaps.order.desktopSaveSize = 480 * 480;
    ccaps.order.pad2octetsC = 0;
    ccaps.order.pad2octetsD = 0;
    ccaps.order.textANSICodePage = 65001;
    ccaps.order.pad2octetsE = 0;

    // CAPSTYPE_BITMAPCACHE
    ccaps.bitmapcache.capabilitySetType = c.CAPSTYPE_BITMAPCACHE;
    ccaps.bitmapcache.lengthCapability = 0; // calculated
    ccaps.bitmapcache.pad1 = 0;
    ccaps.bitmapcache.pad2 = 0;
    ccaps.bitmapcache.pad3 = 0;
    ccaps.bitmapcache.pad4 = 0;
    ccaps.bitmapcache.pad5 = 0;
    ccaps.bitmapcache.pad6 = 0;
    var bpp: u16 = @intCast(settings.bpp);
    bpp = @divTrunc(bpp + 7, 8);
    ccaps.bitmapcache.Cache0Entries = 200;
    ccaps.bitmapcache.Cache0MaximumCellSize = bpp * 256;
    ccaps.bitmapcache.Cache1Entries = 600;
    ccaps.bitmapcache.Cache1MaximumCellSize = bpp * 1024;
    ccaps.bitmapcache.Cache2Entries = 1000;
    ccaps.bitmapcache.Cache2MaximumCellSize = bpp * 4096;

    // CAPSTYPE_CONTROL
    ccaps.control.capabilitySetType = c.CAPSTYPE_CONTROL;
    ccaps.control.lengthCapability = 0; // calculated
    ccaps.control.controlFlags = 0;
    ccaps.control.remoteDetachFlag = 0;
    ccaps.control.controlInterest = 2;
    ccaps.control.detachInterest = 2;

    // CAPSTYPE_POINTER
    ccaps.pointer.capabilitySetType = c.CAPSTYPE_POINTER;
    ccaps.pointer.lengthCapability = 0; // calculated
    // these get overwritten with what server sends
    ccaps.pointer.colorPointerFlag = 0;
    ccaps.pointer.colorPointerCacheSize = 0;
    ccaps.pointer.pointerCacheSize = 0;

    // CAPSTYPE_SHARE
    ccaps.share.capabilitySetType = c.CAPSTYPE_SHARE;
    ccaps.share.lengthCapability = 0; // calculated
    ccaps.share.nodeID = 0;
    ccaps.share.pad2octets = 0;

    // CAPSTYPE_INPUT
    ccaps.input.capabilitySetType = c.CAPSTYPE_INPUT;
    ccaps.input.lengthCapability = 0; // calculated
    ccaps.input.inputFlags = c.INPUT_FLAG_SCANCODES | c.INPUT_FLAG_MOUSEX |
            c.INPUT_FLAG_FASTPATH_INPUT | c.INPUT_FLAG_UNICODE |
            c.INPUT_FLAG_FASTPATH_INPUT2 | c.TS_INPUT_FLAG_MOUSE_HWHEEL;
    ccaps.input.pad2octetsA = 0;
    ccaps.input.keyboardLayout = core.keyboardLayout;
    ccaps.input.keyboardType = core.keyboardType;
    ccaps.input.keyboardSubType = core.keyboardSubType;
    ccaps.input.keyboardFunctionKey = core.keyboardFunctionKey;
    std.mem.copyForwards(u8, &ccaps.input.imeFileName, &core.imeFileName);

    ccaps.brush.capabilitySetType = c.CAPSTYPE_BRUSH;
    ccaps.brush.lengthCapability = 0; // calculated
    ccaps.brush.brushSupportLevel = c.BRUSH_DEFAULT;

    // CAPSTYPE_GLYPHCACHE
    ccaps.glyphcache.capabilitySetType = c.CAPSTYPE_GLYPHCACHE;
    ccaps.glyphcache.lengthCapability = 0; // calculated

    // CAPSTYPE_OFFSCREENCACHE
    ccaps.offscreen.capabilitySetType = c.CAPSTYPE_OFFSCREENCACHE;
    ccaps.offscreen.lengthCapability = 0; // calculated
    ccaps.offscreen.offscreenSupportLevel = 0;
    ccaps.offscreen.offscreenCacheSize = 0;
    ccaps.offscreen.offscreenCacheEntries = 0;

    // CAPSTYPE_VIRTUALCHANNEL
    ccaps.virtualchannel.capabilitySetType = c.CAPSTYPE_VIRTUALCHANNEL;
    ccaps.virtualchannel.lengthCapability = 0; // calculated
    ccaps.virtualchannel.flags = c.VCCAPS_NO_COMPR;
    ccaps.virtualchannel.VCChunkSize = 0;

    // CAPSTYPE_SOUND
    ccaps.sound.capabilitySetType = c.CAPSTYPE_SOUND;
    ccaps.sound.lengthCapability = 0; // calculated
    ccaps.sound.soundFlags = c.SOUND_FLAG_BEEPS;
    ccaps.sound.pad2octetsA = 0;

    // CAPSETTYPE_MULTIFRAGMENTUPDATE
    ccaps.multifragmentupdate.capabilitySetType = c.CAPSETTYPE_MULTIFRAGMENTUPDATE;
    ccaps.multifragmentupdate.lengthCapability = 0; // calculated
    ccaps.multifragmentupdate.MaxRequestSize = 2146304;

    // CAPSETTYPE_SURFACE_COMMANDS
    ccaps.surfcmds.capabilitySetType = c.CAPSETTYPE_SURFACE_COMMANDS;
    ccaps.surfcmds.lengthCapability = 0; // calculated
    ccaps.surfcmds.cmdFlags = 0;
    ccaps.surfcmds.reserved = 0;

    // CAPSETTYPE_BITMAP_CODECS
    if ((settings.rfx != 0) or (settings.jpg != 0))
    {
        const bc = &ccaps.bitmapcodecs;
        bc.capabilitySetType = c.CAPSETTYPE_BITMAP_CODECS;
        bc.lengthCapability = 0; // calculated
        const s = try parse.parse_t.create_from_slice(msg.allocator,
                &bc.supportedBitmapCodecs);
        defer s.delete();
        try s.check_rem(1);
        s.push_layer(1, 0);
        var bitmapCodecCount: u8 = 0;
        if (settings.rfx != 0)
        {
            try add_rfx_bitmapcodec(s);
            bitmapCodecCount += 1;
        }
        if (settings.jpg != 0)
        {
            try add_jpg_bitmapcodec(s);
            bitmapCodecCount += 1;
        }
        s.push_layer(0, 6);
        bc.lengthSupportedBitmapCodecs = s.layer_subtract(6, 0);
        s.pop_layer(0);
        s.out_u8(bitmapCodecCount);
    }

    if (settings.use_frame_ack != 0)
    {
        // CAPSSETTYPE_FRAME_ACKNOWLEDGE
        ccaps.frame_acknowledge.capabilitySetType = c.CAPSSETTYPE_FRAME_ACKNOWLEDGE;
        ccaps.frame_acknowledge.lengthCapability = 0; // calculated
        ccaps.frame_acknowledge.maxUnacknowledgedFrameCount = settings.frames_in_flight;
    }
}
