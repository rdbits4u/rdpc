
#if !defined(_LIBRDPC_H)
#define _LIBRDPC_H

#include <rdp_gcc.h>
#include <rdp_client_info.h>
#include <rdp_caps.h>
#include <rdp_constants.h>

#define LIBRDPC_ERROR_NONE                  0
#define LIBRDPC_ERROR_MEMORY                1
#define LIBRDPC_ERROR_NEED_MORE             2
#define LIBRDPC_ERROR_PARSE                 3

struct rdpc_settings_t
{
    char clientname[64];
    int keyboard_layout;
    int width;
    int height;
    int bpp;
    int dpix;
    int dpiy;
    int rdpsnd;
    int cliprdr;
    int rail;
    int rdpdr;
};

struct rdpc_t
{
    // function calls this library makes, assigned by application
    int (*test1)(void);
    int (*log_msg)(struct rdpc_t* rdpc, const char* msg);
    int (*send_to_server)(struct rdpc_t* rdpc, void* data, int bytes);
    void* user[16];
    struct client_gcc cgcc;
    struct server_gcc sgcc;
    struct TS_INFO_PACKET client_info;
    struct TS_CAPS_SET ccaps;
    struct TS_CAPS_SET scaps;
};

// functions calls into this library
int rdpc_init(void);
int rdpc_deinit(void);
int rdpc_create(struct rdpc_settings_t* settings, struct rdpc_t** rdpc);
int rdpc_delete(struct rdpc_t* rdpc);
int rdpc_start(struct rdpc_t* rdpc);
int rdpc_process_server_data(struct rdpc_t* rdpc, void* data, int bytes_in_buf,
                             int* bytes_processed);

#endif
