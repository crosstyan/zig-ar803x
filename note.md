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

See `05aa009b106f9c6a463c870e74570c0c483f0762`

```
@ts=1720747668724 @l=INFO serial_number=A335F7528032 bus=0 port=1 src="src/main.zig:671 @query_status" role=dev mode=single_user sync_mode=0 sync_master=1 cfg_bmp="0x01" rt_bmp="0x01" slot=0 user=tx mcs=mcs_10 rf_mode="bb.t.RfMode{ .tx = bb.t.TxMode.tx_2tx_stbc }" tintlv_enable=on tintlv_num=block_2 tintlv_len=len_48 bandwidth=bw_10m freq_hz=2477000 user=rx mcs=invalid rf_mode="bb.t.RfMode{ .rx = bb.t.RxMode.rx_2t2r_stbc }" tintlv_enable=on tintlv_num=block_2 tintlv_len=len_48 bandwidth=bw_10m freq_hz=2100000 state=connect rx_mcs=mcs_0 peer_mac="a3:35:87:97"
```
