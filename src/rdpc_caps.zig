const std = @import("std");
const parse = @import("parse");
const rdpc_msg = @import("rdpc_msg.zig");
const c = @cImport(
{
    @cInclude("librdpc.h");
});

//*****************************************************************************
fn process_cap_general(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const gen = &msg.priv.rdpc.scaps.general;
    try s.check_rem(11 * 2 + 2);
    gen.capabilitySetType = s.in_u16_le();
    gen.lengthCapability = s.in_u16_le();
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
    _ = msg.priv.logln(@src(), "", .{});
    const bitmap = &msg.priv.rdpc.scaps.bitmap;
    try s.check_rem(11 * 2 + 2 + 2 * 2);
    bitmap.capabilitySetType = s.in_u16_le();
    bitmap.lengthCapability = s.in_u16_le();
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
    _ = msg.priv.logln(@src(), "", .{});
    const order = &msg.priv.rdpc.scaps.order;
    try s.check_rem(4 + 16 + 4 + 2 * 6 + 32 + 2 * 2 + 2 * 4 + 4 * 2);
    order.capabilitySetType = s.in_u16_le();
    order.lengthCapability = s.in_u16_le();
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
    _ = msg.priv.logln(@src(), "", .{});
    const pointer = &msg.priv.rdpc.scaps.pointer;
    try s.check_rem(4 + 3 * 2);
    pointer.capabilitySetType = s.in_u16_le();
    pointer.lengthCapability = s.in_u16_le();
    pointer.colorPointerFlag = s.in_u16_le();
    pointer.colorPointerCacheSize = s.in_u16_le();
    pointer.pointerCacheSize = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_share(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const share = &msg.priv.rdpc.scaps.share;
    try s.check_rem(4 + 2 * 2);
    share.capabilitySetType = s.in_u16_le();
    share.lengthCapability = s.in_u16_le();
    share.nodeID = s.in_u16_le();
    share.pad2octets = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_colorcache(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const colortable = &msg.priv.rdpc.scaps.colortable;
    try s.check_rem(4 + 2 * 2);
    colortable.capabilitySetType = s.in_u16_le();
    colortable.lengthCapability = s.in_u16_le();
    colortable.colorTableCacheSize = s.in_u16_le();
    colortable.pad2octets = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_input(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const input = &msg.priv.rdpc.scaps.input;
    try s.check_rem(4 + 2 * 2 + 4 * 4 + 64);
    input.capabilitySetType = s.in_u16_le();
    input.lengthCapability = s.in_u16_le();
    input.inputFlags = s.in_u16_le();
    input.pad2octetsA = s.in_u16_le();
    input.keyboardLayout = s.in_u32_le();
    input.keyboardType = s.in_u32_le();
    input.keyboardSubType = s.in_u32_le();
    input.keyboardFunctionKey = s.in_u32_le();
    std.mem.copyForwards(u8, input.imeFileName[0..64], s.in_u8_slice(64));
}

//*****************************************************************************
fn process_cap_font(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
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
    _ = msg.priv.logln(@src(), "", .{});
    const bitmapcache_hostsupport = &msg.priv.rdpc.scaps.bitmapcache_hostsupport;
    try s.check_rem(4 + 1 + 1 + 2);
    bitmapcache_hostsupport.capabilitySetType = s.in_u16_le();
    bitmapcache_hostsupport.lengthCapability = s.in_u16_le();
    bitmapcache_hostsupport.cacheVersion = s.in_u8();
    bitmapcache_hostsupport.pad1 = s.in_u8();
    bitmapcache_hostsupport.pad2 = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_virtualchannel(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const virtualchannel = &msg.priv.rdpc.scaps.virtualchannel;
    try s.check_rem(4 + 4 + 4);
    virtualchannel.capabilitySetType = s.in_u16_le();
    virtualchannel.lengthCapability = s.in_u16_le();
    virtualchannel.flags = s.in_u32_le();
    virtualchannel.VCChunkSize = s.in_u32_le();
}

//*****************************************************************************
fn process_cap_drawgdiplus(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const draw_gdiplus = &msg.priv.rdpc.scaps.draw_gdiplus;
    try s.check_rem(4 + 3 * 4 + 5 * 2 + 4 * 2 + 3 * 2);
    draw_gdiplus.capabilitySetType = s.in_u16_le();
    draw_gdiplus.lengthCapability = s.in_u16_le();
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
    _ = msg.priv.logln(@src(), "", .{});
    const rail = &msg.priv.rdpc.scaps.rail;
    try s.check_rem(4 + 4);
    rail.capabilitySetType = s.in_u16_le();
    rail.lengthCapability = s.in_u16_le();
    rail.RailSupportLevel = s.in_u32_le();
}

//*****************************************************************************
fn process_cap_window(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const windowlist = &msg.priv.rdpc.scaps.windowlist;
    try s.check_rem(4 + 4 + 1 + 2);
    windowlist.capabilitySetType = s.in_u16_le();
    windowlist.lengthCapability = s.in_u16_le();
    windowlist.WndSupportLevel = s.in_u32_le();
    windowlist.NumIconCaches = s.in_u8();
    windowlist.NumIconCacheEntries = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_compdesk(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const compdesk = &msg.priv.rdpc.scaps.compdesk;
    try s.check_rem(4 + 2);
    compdesk.capabilitySetType = s.in_u16_le();
    compdesk.lengthCapability = s.in_u16_le();
    compdesk.CompDeskSupportLevel = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_multifragmentupdate(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const multifragmentupdate = &msg.priv.rdpc.scaps.multifragmentupdate;
    try s.check_rem(4 + 4);
    multifragmentupdate.capabilitySetType = s.in_u16_le();
    multifragmentupdate.lengthCapability = s.in_u16_le();
    multifragmentupdate.MaxRequestSize = s.in_u32_le();
}

//*****************************************************************************
fn process_cap_large_pointer(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const large_pointer = &msg.priv.rdpc.scaps.large_pointer;
    try s.check_rem(4 + 2);
    large_pointer.capabilitySetType = s.in_u16_le();
    large_pointer.lengthCapability = s.in_u16_le();
    large_pointer.largePointerSupportFlags = s.in_u16_le();
}

//*****************************************************************************
fn process_cap_surface_commands(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const surfcmds = &msg.priv.rdpc.scaps.surfcmds;
    try s.check_rem(4 + 2 * 4);
    surfcmds.capabilitySetType = s.in_u16_le();
    surfcmds.lengthCapability = s.in_u16_le();
    surfcmds.cmdFlags = s.in_u32_le();
    surfcmds.reserved = s.in_u32_le();
}

//*****************************************************************************
fn process_cap_bitmap_codecs(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const bitmapcodecs = &msg.priv.rdpc.scaps.bitmapcodecs;
    try s.check_rem(4);
    bitmapcodecs.capabilitySetType = s.in_u16_le();
    bitmapcodecs.lengthCapability = s.in_u16_le();
    if (bitmapcodecs.lengthCapability > 4)
    {
        const sbc_max = @sizeOf(@TypeOf(bitmapcodecs.supportedBitmapCodecs));
        var sbc_len = bitmapcodecs.lengthCapability - 4;
        sbc_len = if (sbc_len > sbc_max) sbc_max else sbc_len;
        _ = msg.priv.logln(@src(), "sbc_max {} sbc_len {}",
                .{sbc_max, sbc_len});
        try s.check_rem(sbc_len);
        std.mem.copyForwards(u8,
                bitmapcodecs.supportedBitmapCodecs[0..sbc_len],
                s.in_u8_slice(sbc_len));
    }
}

//*****************************************************************************
fn process_cap_frame_ack(msg: *rdpc_msg.rdpc_msg_t, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
    const frame_acknowledge = &msg.priv.rdpc.scaps.frame_acknowledge;
    try s.check_rem(4 + 4);
    frame_acknowledge.capabilitySetType = s.in_u16_le();
    frame_acknowledge.lengthCapability = s.in_u16_le();
    frame_acknowledge.maxUnacknowledgedFrameCount = s.in_u32_le();
}

//*****************************************************************************
pub fn process_cap(msg: *rdpc_msg.rdpc_msg_t, cap_type: u16, s: *parse.parse_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});
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
        else => _ = msg.priv.logln(@src(), "unknown cap_type {}", .{cap_type}),
    }
}

//*********************************************************************************
pub fn init_caps_defaults(msg: *rdpc_msg.rdpc_msg_t,
        settings: *c.rdpc_settings_t) !void
{
    _ = msg.priv.logln(@src(), "", .{});

    const ccaps = &msg.priv.rdpc.ccaps;
    const rdpc = &msg.priv.rdpc;
    const core = &rdpc.cgcc.core;

    ccaps.general.capabilitySetType = c.CAPSTYPE_GENERAL;
    ccaps.general.lengthCapability = 0; // calculated
    ccaps.general.osMajorType = c.OSMAJORTYPE_UNIX;
    ccaps.general.osMinorType = c.OSMINORTYPE_NATIVE_XSERVER;
    ccaps.general.protocolVersion = c.TS_CAPS_PROTOCOLVERSION;
    ccaps.general.pad2octetsA = 0;
    ccaps.general.compressionTypes = 0;
    ccaps.general.extraFlags = c.FASTPATH_OUTPUT_SUPPORTED;
    ccaps.general.updateCapabilityFlag = 0;
    ccaps.general.remoteUnshareFlag = 0;
    ccaps.general.compressionLevel = 0;
    ccaps.general.refreshRectSupport = 1;
    ccaps.general.suppressOutputSupport = 1;

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

    ccaps.order.capabilitySetType = c.CAPSTYPE_ORDER;
    ccaps.order.lengthCapability = 0; // calculated
    @memset(&ccaps.order.terminalDescriptor, 0);
    ccaps.order.pad4octetsA = 0;
    ccaps.order.desktopSaveXGranularity = 1;
    ccaps.order.desktopSaveYGranularity = 20;
    ccaps.order.pad2octetsA = 0;
    ccaps.order.maximumOrderLevel = c.ORD_LEVEL_1_ORDERS;
    ccaps.order.numberFonts = 0;
    ccaps.order.orderFlags = c.NEGOTIATEORDERSUPPORT;
    @memset(&ccaps.order.orderSupport, 0);
    ccaps.order.textFlags = 0;
    ccaps.order.orderSupportExFlags = 0;
    ccaps.order.pad4octetsB = 0;
    ccaps.order.desktopSaveSize = 480 * 480;
    ccaps.order.pad2octetsC = 0;
    ccaps.order.pad2octetsD = 0;
    ccaps.order.textANSICodePage = 0;
    ccaps.order.pad2octetsE = 0;

    ccaps.bitmapcache.capabilitySetType = c.CAPSTYPE_BITMAPCACHE;
    ccaps.bitmapcache.lengthCapability = 0; // calculated
    ccaps.bitmapcache.pad1 = 0;
    ccaps.bitmapcache.pad2 = 0;
    ccaps.bitmapcache.pad3 = 0;
    ccaps.bitmapcache.pad4 = 0;
    ccaps.bitmapcache.pad5 = 0;
    ccaps.bitmapcache.pad6 = 0;
    ccaps.bitmapcache.Cache0Entries = 0;
    ccaps.bitmapcache.Cache0MaximumCellSize = 0;
    ccaps.bitmapcache.Cache1Entries = 0;
    ccaps.bitmapcache.Cache1MaximumCellSize = 0;
    ccaps.bitmapcache.Cache2Entries = 0;
    ccaps.bitmapcache.Cache2MaximumCellSize = 0;

    ccaps.pointer.capabilitySetType = c.CAPSTYPE_POINTER;
    ccaps.pointer.lengthCapability = 0; //calculated
    ccaps.pointer.colorPointerFlag = 1;
    ccaps.pointer.colorPointerCacheSize = 32;
    ccaps.pointer.pointerCacheSize = 32;

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

    ccaps.glyphcache.capabilitySetType = c.CAPSTYPE_GLYPHCACHE;
    ccaps.glyphcache.lengthCapability = 0; // calculated

    ccaps.offscreen.capabilitySetType = c.CAPSTYPE_OFFSCREENCACHE;
    ccaps.offscreen.lengthCapability = 0; // calculated
    ccaps.offscreen.offscreenSupportLevel = 0;
    ccaps.offscreen.offscreenCacheSize = 0;
    ccaps.offscreen.offscreenCacheEntries = 0;

    ccaps.virtualchannel.capabilitySetType = c.CAPSTYPE_VIRTUALCHANNEL;
    ccaps.virtualchannel.lengthCapability = 0; // calculated
    ccaps.virtualchannel.flags = c.VCCAPS_NO_COMPR;
    ccaps.virtualchannel.VCChunkSize = 0;

    ccaps.sound.capabilitySetType = c.CAPSTYPE_SOUND;
    ccaps.sound.lengthCapability = 0; // calculated
    ccaps.sound.soundFlags = c.SOUND_FLAG_BEEPS;
    ccaps.sound.pad2octetsA = 0;

}
