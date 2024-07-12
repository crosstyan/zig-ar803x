# Note

```c
typedef enum {
    sock_not_init = 0,
    sock_need_send_cmd,
    sock_wait_usb_cmd,

    sock_can_send_data,
    sock_wait_usb_data,

    sock_need_send_close,
    sock_wait_usb_close,
} SOCK_STATUS;
```
