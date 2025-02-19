const std = @import("std");
const rdpc_priv = @import("rdpc_priv.zig");
const c = @cImport(
{
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
// int rdpc_init(void);
export fn rdpc_deinit() c_int
{
    return c.LIBRDPC_ERROR_NONE;
}

//*****************************************************************************
// int rdpc_create(rdpc_settings_t* settings, rdpc_t** rdpc);
export fn rdpc_create(settings: ?*c.rdpc_settings_t, rdpc: ?**c.rdpc_t) c_int
{
    // check if rdpc is nil
    if (rdpc) |ardpc|
    {
        // check if settings is nil
        if (settings) |asettings|
        {
            const priv = rdpc_priv.create(&g_allocator, asettings) catch
                return c.LIBRDPC_ERROR_MEMORY;
            ardpc.* = @ptrCast(priv);
            return c.LIBRDPC_ERROR_NONE;
        }
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
        // cast c.rdpc_t to rdpc_priv.rdpc_priv_t
        const priv: *rdpc_priv.rdpc_priv_t = @ptrCast(ardpc);
        priv.delete();
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
        // cast c.rdpc_t to rdpc_priv.rdpc_priv_t
        const priv: *rdpc_priv.rdpc_priv_t = @ptrCast(ardpc);
        return priv.start() catch c.LIBRDPC_ERROR_MEMORY;
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
            // cast c.rdpc_t to rdpc_priv.rdpc_priv_t
            const priv: *rdpc_priv.rdpc_priv_t = @ptrCast(ardpc);
            var slice: []u8 = undefined;
            slice.ptr = @ptrCast(adata);
            slice.len = @intCast(bytes);
            const rv: c_int = priv.process_server_slice_data(slice,
                    bytes_processed) catch c.LIBRDPC_ERROR_MEMORY;
            return rv;
        }
    }
    return c.LIBRDPC_ERROR_PARSE;
}
