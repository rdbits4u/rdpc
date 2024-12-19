
const std = @import("std");
const nsrdpc_priv = @import("rdpc_priv.zig");
const nsparse = @import("parse.zig");
const c = @cImport(
{
    @cInclude("librdpc_gcc.h");
    @cInclude("librdpc_constants.h");
    @cInclude("librdpc.h");
});

var g_allocator: std.mem.Allocator = std.heap.c_allocator;

//*****************************************************************************
// int rdpc_init(void);
export fn rdpc_init() c_int
{
    return c.LIBRDPC_ERROR_NONE;
}

//*****************************************************************************
// int rdpc_create(rdpc_settings_t* settings, rdpc_t** rdpc);
export fn rdpc_create(settings: ?*c.rdpc_settings_t, rdpc: ?**c.rdpc_t) c_int
{

    if (rdpc) |ardpc|
    {
        const rdpc_priv = nsrdpc_priv.create(&g_allocator) catch
            return c.LIBRDPC_ERROR_MEMORY;
        init_defaults(rdpc_priv);
        // check if settings is nil
        if (settings) |asettings|
        {
            rdpc_priv.rdpc.i1 = asettings.i1;
            rdpc_priv.rdpc.i2 = asettings.i2;
        }
        ardpc.* = @ptrCast(rdpc_priv);
        return c.LIBRDPC_ERROR_NONE;
    }
    return c.LIBRDPC_ERROR_PARSE;
}

//*****************************************************************************
// int rdpc_delete(rdpc_t* rdpc);
export fn rdpc_delete(rdpc: ?*c.rdpc_t) c_int
{
    // check if rdpc is nil
    if (rdpc) |ardpc|
    {
        // cast c.rdpc_t to nsrdpc_priv.rdpc_priv_t
        const rdpc_priv: *nsrdpc_priv.rdpc_priv_t = @ptrCast(ardpc);
        rdpc_priv.delete();
    }
    return c.LIBRDPC_ERROR_NONE;
}

//*****************************************************************************
// int rdpc_start(rdpc_t* rdpc);
export fn rdpc_start(rdpc: ?*c.rdpc_t) c_int
{
    // check if rdpc is nil
    if (rdpc) |ardpc|
    {
        // cast c.rdpc_t to nsrdpc_priv.rdpc_priv_t
        const rdpc_priv: *nsrdpc_priv.rdpc_priv_t = @ptrCast(ardpc);
        return rdpc_priv.start();
    }
    return c.LIBRDPC_ERROR_PARSE;
}


//*****************************************************************************
// int rdpc_process_server_data(rdpc_t* rdpc, void* data, int bytes_in_buf,
//                         int* bytes_processed);
export fn rdpc_process_server_data(rdpc: ?*c.rdpc_t,
        data: ?*anyopaque, bytes: c_int, bytes_processed: ?*c_int) c_int
{
    // check if rdpc is nil
    if (rdpc) |ardpc|
    {
        // check if data is nil
        if (data) |adata|
        {
            // cast c.rdpc_t to nsrdpc_priv.rdpc_priv_t
            const rdpc_priv: *nsrdpc_priv.rdpc_priv_t = @ptrCast(ardpc);
            var slice: []u8 = undefined;
            slice.ptr = @ptrCast(adata);
            slice.len = @intCast(bytes);
            const rv: c_int = rdpc_priv.process_server_data(slice,
                    bytes_processed);
            return rv;
        }
    }
    return c.LIBRDPC_ERROR_PARSE;
}

//*****************************************************************************
fn init_defaults(rdpc_priv: *nsrdpc_priv.rdpc_priv_t) void
{
    const rdpc = &rdpc_priv.rdpc;
    const core = &rdpc.cgcc.core;
    const sec = &rdpc.cgcc.sec;
    const net = &rdpc.cgcc.net;

    // CS_CORE
    core.header.type = c.CS_CORE;           // 0xC001
    core.header.length = 0;                 // calculated
    core.version = 0x00080004;              // RDP 5.0, 5.1, 5.2, 6.0, 6.1, 7.0, 7.1, 8.0, and 8.1 clients
    core.desktopWidth = 800;
    core.desktopHeight = 600;
    core.colorDepth = c.RNS_UD_COLOR_8BPP;  // 0xCA01 8 bits/pixel
    core.SASSequence = c.RNS_UD_SAS_DEL;    // 0xAA03 secure access sequence
    core.keyboardLayout = 0x0409;           // United States - English
    core.clientBuild = 2600;

    // CS_SEC
    sec.header.type = c.CS_SECURITY;        // 0xC002;
    sec.header.length = 0;                  // calculated
    sec.encryptionMethods = c.CRYPT_METHOD_40BIT;
    sec.extEncryptionMethods = 0;

    // CS_NET
    net.header.type = c.CS_NET;             // 0xC003
    net.header.length = 0;                  // calculated
    net.channelCount = 0;

    // CS_CLUSTER

}
