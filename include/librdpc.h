
#if !defined(_LIBRDPC_H)
#define _LIBRDPC_H

#define LIBRDPC_ERROR_NONE                  0
#define LIBRDPC_ERROR_MEMORY                1
#define LIBRDPC_ERROR_NEED_MORE             2
#define LIBRDPC_ERROR_PARSE                 3

struct rdpc_settings_t
{
    int i1;
    int i2;
};
typedef struct rdpc_settings_t rdpc_settings_t;

struct rdpc_t
{
    int i1;
    int i2;
    int (*test1)(void);
    int (*log_msg)(struct rdpc_t* rdpc, const char* msg);
    int (*send_to_server)(struct rdpc_t* rdpc, void* data, int bytes);
    void* user[16];
    struct client_gcc cgcc;
    struct server_gcc sgcc;
};
typedef struct rdpc_t rdpc_t;

int rdpc_init(void);
int rdpc_create(rdpc_settings_t* settings, rdpc_t** rdpc);
int rdpc_delete(rdpc_t* rdpc);
int rdpc_start(rdpc_t* rdpc);
int rdpc_process_server_data(rdpc_t* rdpc, void* data, int bytes_in_buf,
                             int* bytes_processed);

#endif
