
#if !defined(_LIBRDPC_H)
#define _LIBRDPC_H

#include <stdint.h>
#include <rdp_gcc.h>
#include <rdp_client_info.h>
#include <rdp_caps.h>
#include <rdp_constants.h>

#define LIBRDPC_ERROR_NEED_MORE             1
#define LIBRDPC_ERROR_NONE                  0
#define LIBRDPC_ERROR_MEMORY                -1
#define LIBRDPC_ERROR_PARSE                 -2
#define LIBRDPC_ERROR_SURFACE               -3
#define LIBRDPC_ERROR_OTHER                 -16

struct rdpc_settings_t
{
    char domain[64];
    char username[64];
    char password[64];
    char altshell[64];
    char workingdir[64];
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
    int rfx;
    int jpg;
};

struct bitmap_data_t
{
    uint8_t bits_per_pixel;
    uint8_t flags;
    uint8_t codec_id;
    uint8_t pad0;
    uint16_t dest_left;
    uint16_t dest_top;
    uint16_t dest_right;
    uint16_t dest_bottom;
    uint16_t width;
    uint16_t height;
    uint32_t bitmap_data_len;
    uint32_t high_unique_id;
    uint32_t low_unique_id;
    uint32_t pad1;
    uint64_t tm_milliseconds;
    uint64_t tm_seconds;
    void* bitmap_data;
};

struct rdpc_t
{
    // function calls this library makes, assigned by application
    int (*log_msg)(struct rdpc_t* rdpc, const char* msg);
    int (*send_to_server)(struct rdpc_t* rdpc, void* data, int bytes);
    int (*set_surface_bits)(struct rdpc_t* rdpc,
                            struct bitmap_data_t* bitmap_data);
    void* user[16];
    struct client_gcc cgcc;
    struct server_gcc sgcc;
    struct TS_INFO_PACKET client_info;
    struct client_caps ccaps;
    struct server_caps scaps;
};

// functions calls into this library
int rdpc_init(void);
int rdpc_deinit(void);
int rdpc_create(struct rdpc_settings_t* settings, struct rdpc_t** rdpc);
int rdpc_delete(struct rdpc_t* rdpc);
int rdpc_start(struct rdpc_t* rdpc);
int rdpc_process_server_data(struct rdpc_t* rdpc, void* data,
                             int bytes_in_buf, int* bytes_processed);
int rdpc_send_mouse_event(struct rdpc_t* rdpc, uint16_t event,
                          uint16_t xpos, uint16_t ypos);
int rdpc_send_mouse_event_ex(struct rdpc_t* rdpc, uint16_t event,
                             uint16_t xpos, uint16_t ypos);
int rdpc_send_keyboard_scancode(struct rdpc_t*, uint16_t keyboard_flags,
                                uint16_t key_code);

#endif
