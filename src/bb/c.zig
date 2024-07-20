// This file is generated with `zig translate-c`
// Don't edit this file manually
//
// See also `bb_api.h`

pub const __builtin_bswap16 = @import("std").zig.c_builtins.__builtin_bswap16;
pub const __builtin_bswap32 = @import("std").zig.c_builtins.__builtin_bswap32;
pub const __builtin_bswap64 = @import("std").zig.c_builtins.__builtin_bswap64;
pub const __builtin_signbit = @import("std").zig.c_builtins.__builtin_signbit;
pub const __builtin_signbitf = @import("std").zig.c_builtins.__builtin_signbitf;
pub const __builtin_popcount = @import("std").zig.c_builtins.__builtin_popcount;
pub const __builtin_ctz = @import("std").zig.c_builtins.__builtin_ctz;
pub const __builtin_clz = @import("std").zig.c_builtins.__builtin_clz;
pub const __builtin_sqrt = @import("std").zig.c_builtins.__builtin_sqrt;
pub const __builtin_sqrtf = @import("std").zig.c_builtins.__builtin_sqrtf;
pub const __builtin_sin = @import("std").zig.c_builtins.__builtin_sin;
pub const __builtin_sinf = @import("std").zig.c_builtins.__builtin_sinf;
pub const __builtin_cos = @import("std").zig.c_builtins.__builtin_cos;
pub const __builtin_cosf = @import("std").zig.c_builtins.__builtin_cosf;
pub const __builtin_exp = @import("std").zig.c_builtins.__builtin_exp;
pub const __builtin_expf = @import("std").zig.c_builtins.__builtin_expf;
pub const __builtin_exp2 = @import("std").zig.c_builtins.__builtin_exp2;
pub const __builtin_exp2f = @import("std").zig.c_builtins.__builtin_exp2f;
pub const __builtin_log = @import("std").zig.c_builtins.__builtin_log;
pub const __builtin_logf = @import("std").zig.c_builtins.__builtin_logf;
pub const __builtin_log2 = @import("std").zig.c_builtins.__builtin_log2;
pub const __builtin_log2f = @import("std").zig.c_builtins.__builtin_log2f;
pub const __builtin_log10 = @import("std").zig.c_builtins.__builtin_log10;
pub const __builtin_log10f = @import("std").zig.c_builtins.__builtin_log10f;
pub const __builtin_abs = @import("std").zig.c_builtins.__builtin_abs;
pub const __builtin_labs = @import("std").zig.c_builtins.__builtin_labs;
pub const __builtin_llabs = @import("std").zig.c_builtins.__builtin_llabs;
pub const __builtin_fabs = @import("std").zig.c_builtins.__builtin_fabs;
pub const __builtin_fabsf = @import("std").zig.c_builtins.__builtin_fabsf;
pub const __builtin_floor = @import("std").zig.c_builtins.__builtin_floor;
pub const __builtin_floorf = @import("std").zig.c_builtins.__builtin_floorf;
pub const __builtin_ceil = @import("std").zig.c_builtins.__builtin_ceil;
pub const __builtin_ceilf = @import("std").zig.c_builtins.__builtin_ceilf;
pub const __builtin_trunc = @import("std").zig.c_builtins.__builtin_trunc;
pub const __builtin_truncf = @import("std").zig.c_builtins.__builtin_truncf;
pub const __builtin_round = @import("std").zig.c_builtins.__builtin_round;
pub const __builtin_roundf = @import("std").zig.c_builtins.__builtin_roundf;
pub const __builtin_strlen = @import("std").zig.c_builtins.__builtin_strlen;
pub const __builtin_strcmp = @import("std").zig.c_builtins.__builtin_strcmp;
pub const __builtin_object_size = @import("std").zig.c_builtins.__builtin_object_size;
pub const __builtin___memset_chk = @import("std").zig.c_builtins.__builtin___memset_chk;
pub const __builtin_memset = @import("std").zig.c_builtins.__builtin_memset;
pub const __builtin___memcpy_chk = @import("std").zig.c_builtins.__builtin___memcpy_chk;
pub const __builtin_memcpy = @import("std").zig.c_builtins.__builtin_memcpy;
pub const __builtin_expect = @import("std").zig.c_builtins.__builtin_expect;
pub const __builtin_nanf = @import("std").zig.c_builtins.__builtin_nanf;
pub const __builtin_huge_valf = @import("std").zig.c_builtins.__builtin_huge_valf;
pub const __builtin_inff = @import("std").zig.c_builtins.__builtin_inff;
pub const __builtin_isnan = @import("std").zig.c_builtins.__builtin_isnan;
pub const __builtin_isinf = @import("std").zig.c_builtins.__builtin_isinf;
pub const __builtin_isinf_sign = @import("std").zig.c_builtins.__builtin_isinf_sign;
pub const __has_builtin = @import("std").zig.c_builtins.__has_builtin;
pub const __builtin_assume = @import("std").zig.c_builtins.__builtin_assume;
pub const __builtin_unreachable = @import("std").zig.c_builtins.__builtin_unreachable;
pub const __builtin_constant_p = @import("std").zig.c_builtins.__builtin_constant_p;
pub const __builtin_mul_overflow = @import("std").zig.c_builtins.__builtin_mul_overflow;
pub const int_least64_t = i64;
pub const uint_least64_t = u64;
pub const int_fast64_t = i64;
pub const uint_fast64_t = u64;
pub const int_least32_t = i32;
pub const uint_least32_t = u32;
pub const int_fast32_t = i32;
pub const uint_fast32_t = u32;
pub const int_least16_t = i16;
pub const uint_least16_t = u16;
pub const int_fast16_t = i16;
pub const uint_fast16_t = u16;
pub const int_least8_t = i8;
pub const uint_least8_t = u8;
pub const int_fast8_t = i8;
pub const uint_fast8_t = u8;
pub const intmax_t = c_longlong;
pub const uintmax_t = c_ulonglong;
pub const bb_mac_t = extern struct {
    addr: [4]u8 = @import("std").mem.zeroes([4]u8),
};
pub const BB_DIR_TX: c_int = 0;
pub const BB_DIR_RX: c_int = 1;
pub const BB_DIR_MAX: c_int = 2;
pub const bb_dir_e = c_uint;
pub const BB_DBG_CLIENT_CHANGE: c_int = 0;
pub const BB_DBG_DATA: c_int = 1;
pub const BB_DBG_MAX: c_int = 2;
pub const bb_debug_id_e = c_uint;
pub const BB_CLK_100M_SEL: c_int = 0;
pub const BB_CLK_200M_SEL: c_int = 1;
pub const bb_clk_sel_e = c_uint;
pub const BB_ROLE_AP: c_int = 0;
pub const BB_ROLE_DEV: c_int = 1;
pub const BB_ROLE_MAX: c_int = 2;
pub const bb_role_e = c_uint;
pub const BB_MODE_SINGLE_USER: c_int = 0;
pub const BB_MODE_MULTI_USER: c_int = 1;
pub const BB_MODE_RELAY: c_int = 2;
pub const BB_MODE_DIRECTOR: c_int = 3;
pub const BB_MODE_MAX: c_int = 4;
pub const bb_mode_e = c_uint;
pub const BB_SLOT_0: c_int = 0;
pub const BB_SLOT_AP: c_int = 0;
pub const BB_SLOT_1: c_int = 1;
pub const BB_SLOT_2: c_int = 2;
pub const BB_SLOT_3: c_int = 3;
pub const BB_SLOT_4: c_int = 4;
pub const BB_SLOT_5: c_int = 5;
pub const BB_SLOT_6: c_int = 6;
pub const BB_SLOT_7: c_int = 7;
pub const BB_SLOT_MAX: c_int = 8;
pub const bb_slot_e = c_uint;
pub const BB_USER_0: c_int = 0;
pub const BB_USER_1: c_int = 1;
pub const BB_USER_2: c_int = 2;
pub const BB_USER_3: c_int = 3;
pub const BB_USER_4: c_int = 4;
pub const BB_USER_5: c_int = 5;
pub const BB_USER_6: c_int = 6;
pub const BB_USER_7: c_int = 7;
pub const BB_USER_BR_CS: c_int = 8;
pub const BB_USER_BR2_CS2: c_int = 9;
pub const BB_DATA_USER_MAX: c_int = 10;
pub const BB_USER_SWEEP: c_int = 10;
pub const BB_USER_SWEEP_SHORT: c_int = 11;
pub const BB_USER_MAX: c_int = 12;
pub const bb_user_e = c_uint;
pub const BB_PHY_MCS_NEG_2: c_int = 0;
pub const BB_PHY_MCS_NEG_1: c_int = 1;
pub const BB_PHY_MCS_0: c_int = 2;
pub const BB_PHY_MCS_1: c_int = 3;
pub const BB_PHY_MCS_2: c_int = 4;
pub const BB_PHY_MCS_3: c_int = 5;
pub const BB_PHY_MCS_4: c_int = 6;
pub const BB_PHY_MCS_5: c_int = 7;
pub const BB_PHY_MCS_6: c_int = 8;
pub const BB_PHY_MCS_7: c_int = 9;
pub const BB_PHY_MCS_8: c_int = 10;
pub const BB_PHY_MCS_9: c_int = 11;
pub const BB_PHY_MCS_10: c_int = 12;
pub const BB_PHY_MCS_11: c_int = 13;
pub const BB_PHY_MCS_12: c_int = 14;
pub const BB_PHY_MCS_13: c_int = 15;
pub const BB_PHY_MCS_14: c_int = 16;
pub const BB_PHY_MCS_15: c_int = 17;
pub const BB_PHY_MCS_16: c_int = 18;
pub const BB_PHY_MCS_17: c_int = 19;
pub const BB_PHY_MCS_18: c_int = 20;
pub const BB_PHY_MCS_19: c_int = 21;
pub const BB_PHY_MCS_20: c_int = 22;
pub const BB_PHY_MCS_21: c_int = 23;
pub const BB_PHY_MCS_22: c_int = 24;
pub const BB_PHY_MCS_MAX: c_int = 25;
pub const bb_phy_mcs_e = c_uint;
pub const BB_SLOT_MODE_FIXED: c_int = 0;
pub const BB_SLOT_MODE_DYNAMIC: c_int = 1;
pub const bb_slot_mode_e = c_uint;
pub const BB_LINK_STATE_IDLE: c_int = 0;
pub const BB_LINK_STATE_LOCK: c_int = 1;
pub const BB_LINK_STATE_CONNECT: c_int = 2;
pub const BB_LINK_STATE_MAX: c_int = 3;
pub const bb_link_state_e = c_uint;
pub const BB_EVENT_LINK_STATE: c_int = 0;
pub const BB_EVENT_MCS_CHANGE: c_int = 1;
pub const BB_EVENT_CHAN_CHANGE: c_int = 2;
pub const BB_EVENT_PLOT_DATA: c_int = 3;
pub const BB_EVENT_FRAME_START: c_int = 4;
pub const BB_EVENT_OFFLINE: c_int = 5;
pub const BB_EVENT_PRJ_DISPATCH: c_int = 6;
pub const BB_EVENT_PAIR_RESULT: c_int = 7;
pub const BB_EVENT_PRJ_DISPATCH2: c_int = 8;
pub const BB_EVENT_MCS_CHANGE_END: c_int = 9;
pub const BB_EVENT_MAX: c_int = 10;
pub const bb_event_e = c_uint;
pub const chan_t = u16;
pub const bb_quality_t = extern struct {
    snr: u16 = @import("std").mem.zeroes(u16),
    ldpc_err: u16 = @import("std").mem.zeroes(u16),
    ldpc_num: u16 = @import("std").mem.zeroes(u16),
    gain_a: u8 = @import("std").mem.zeroes(u8),
    gain_b: u8 = @import("std").mem.zeroes(u8),
};
pub const BB_BAND_1G: c_int = 0;
pub const BB_BAND_2G: c_int = 1;
pub const BB_BAND_5G: c_int = 2;
pub const BB_BAND_MAX: c_int = 3;
pub const bb_band_e = c_uint;
pub const BB_RF_PATH_A: c_int = 0;
pub const BB_RF_PATH_B: c_int = 1;
pub const BB_RF_PATH_MAX: c_int = 2;
pub const bb_rf_path_e = c_uint;
pub const BB_BAND_MODE_SINGLE: c_int = 0;
pub const BB_BAND_MODE_2G_5G: c_int = 1;
pub const BB_BAND_MODE_1G_2G: c_int = 2;
pub const BB_BAND_MODE_1G_5G: c_int = 3;
pub const BB_BAND_MODE_MAX: c_int = 4;
pub const bb_band_mode_e = c_uint;
pub const BB_BW_1_25M: c_int = 0;
pub const BB_BW_2_5M: c_int = 1;
pub const BB_BW_5M: c_int = 2;
pub const BB_BW_10M: c_int = 3;
pub const BB_BW_20M: c_int = 4;
pub const BB_BW_40M: c_int = 5;
pub const BB_BW_MAX: c_int = 6;
pub const bb_bandwidth_e = c_uint;
pub const BB_TIMEINTLV_LEN_3: c_int = 0;
pub const BB_TIMEINTLV_LEN_6: c_int = 1;
pub const BB_TIMEINTLV_LEN_12: c_int = 2;
pub const BB_TIMEINTLV_LEN_24: c_int = 3;
pub const BB_TIMEINTLV_LEN_48: c_int = 4;
pub const BB_TIMEINTLV_LEN_MAX: c_int = 5;
pub const bb_timeintlv_len_e = c_uint;
pub const BB_TIMEINTLV_OFF: c_int = 0;
pub const BB_TIMEINTLV_ON: c_int = 1;
pub const BB_TIMEINTLV_ENABLE_MAX: c_int = 2;
pub const bb_timeintlv_enable_e = c_uint;
pub const BB_TIMEINTLV_1_BLOCK: c_int = 0;
pub const BB_TIMEINTLV_2_BLOCK: c_int = 1;
pub const BB_TIMEINTLV_NUM_MAX: c_int = 2;
pub const bb_timeintlv_num_e = c_uint;
pub const BB_PAYLOAD_ON: c_int = 0;
pub const BB_PAYLOAD_OFF: c_int = 1;
pub const BB_PAYLOAD_MAX: c_int = 2;
pub const bb_payload_e = c_uint;
pub const BB_FCH_INFO_96BITS: c_int = 0;
pub const BB_FCH_INFO_48BITS: c_int = 1;
pub const BB_FCH_INFO_192BITS: c_int = 2;
pub const BB_FCH_INFO_MAX: c_int = 3;
pub const bb_fch_info_len_e = c_uint;
pub const BB_TX_1TX: c_int = 0;
pub const BB_TX_2TX_STBC: c_int = 1;
pub const BB_TX_2TX_MIMO: c_int = 2;
pub const BB_TX_MODE_MAX: c_int = 3;
pub const bb_tx_mode_e = c_uint;
pub const BB_RX_1T1R: c_int = 0;
pub const BB_RX_1T2R: c_int = 1;
pub const BB_RX_2T2R_STBC: c_int = 2;
pub const BB_RX_2T2R_MIMO: c_int = 3;
pub const BB_RX_MODE_MAX: c_int = 4;
pub const bb_rx_mode_e = c_uint;
pub const BB_PHY_PWR_OPENLOOP: c_int = 0;
pub const BB_PHY_PWR_CLOSELOOP: c_int = 1;
pub const bb_phy_pwr_mode_e = c_uint;
pub const BB_BR_HOP_MODE_FIXED: c_int = 0;
pub const BB_BR_HOP_MODE_FOLLOW_UP_CHAN: c_int = 1;
pub const BB_BR_HOP_MODE_HOP_ON_IDLE: c_int = 2;
pub const BB_BR_HOP_MODE_MAX: c_int = 3;
pub const bb_br_hop_mode_e = c_uint;
pub const BB_BAND_HOP_2G_2_5G: c_int = 0;
pub const BB_BAND_HOP_5G_2_2G: c_int = 1;
pub const BB_BAND_HOP_ITEM_MAX: c_int = 2;
pub const bb_band_hop_item_e = c_uint;
pub const BB_DFS_TYPE_FCC: c_int = 0;
pub const BB_DFS_TYPE_CE: c_int = 1;
pub const bb_dfs_type_e = c_uint;
pub const BB_DFS_CONF_GET: c_int = 0;
pub const BB_DFS_CONF_SET: c_int = 1;
pub const BB_DFS_EVENT: c_int = 2;
pub const bb_dfs_sub_cmd_e = c_uint;
pub const bb_event_link_state_t = extern struct {
    slot: u8 = @import("std").mem.zeroes(u8),
    cur_state: u8 = @import("std").mem.zeroes(u8),
    prev_state: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_event_mcs_change_t = extern struct {
    slot: u8 = @import("std").mem.zeroes(u8),
    dir: u8 = @import("std").mem.zeroes(u8),
    cur_mcs: u8 = @import("std").mem.zeroes(u8),
    prev_mcs: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_event_mcs_change_end_t = extern struct {
    info: bb_event_mcs_change_t = @import("std").mem.zeroes(bb_event_mcs_change_t),
    tx_result: u32 = @import("std").mem.zeroes(u32),
    pkt_num: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_event_chan_change_t = extern struct {
    slot: u8 = @import("std").mem.zeroes(u8),
    dir: u8 = @import("std").mem.zeroes(u8),
    cur_chan: u8 = @import("std").mem.zeroes(u8),
    prev_chan: u8 = @import("std").mem.zeroes(u8),
};
// .\inc\bb_api.h:489:21: warning: struct demoted to opaque type - has bitfield
pub const bb_plot_data_t = opaque {};
pub const bb_event_plot_data_t = extern struct {
    user: u8 = @import("std").mem.zeroes(u8),
    plot_num: u8 = @import("std").mem.zeroes(u8),
    plot_data: [10]bb_plot_data_t = @import("std").mem.zeroes([10]bb_plot_data_t),
};
pub const bb_event_frame_start_t = extern struct {
    slot_state: [8]u8 = @import("std").mem.zeroes([8]u8),
};
pub const struct_bb_dev_info_t = extern struct {
    mac: [32]u8 = @import("std").mem.zeroes([32]u8),
    maclen: c_int = @import("std").mem.zeroes(c_int),
};
pub const bb_dev_info_t = struct_bb_dev_info_t;
pub const bb_event_hotplug_t = extern struct {
    id: u32 = @import("std").mem.zeroes(u32),
    status: u32 = @import("std").mem.zeroes(u32),
    bb_mac: bb_dev_info_t = @import("std").mem.zeroes(bb_dev_info_t),
};
pub const bb_event_prj_dispatch_t = extern struct {
    data: [256]u8 = @import("std").mem.zeroes([256]u8),
};
pub const bb_event_prj_dispatch2_t = extern struct {
    data: [1024]u8 = @import("std").mem.zeroes([1024]u8),
};
pub const sock_opt_echo: c_int = 0;
pub const enum_ctl_opt = c_uint;
pub const BB_SOCK_QUERY_TX_BUFF_LEN: c_int = 0;
pub const BB_SOCK_QUERY_RX_BUFF_LEN: c_int = 1;
pub const BB_SOCK_READ_INV_DATA: c_int = 2;
pub const BB_SOCK_SET_TX_LIMIT: c_int = 3;
pub const BB_SOCK_GET_TX_LIMIT: c_int = 4;
pub const BB_SOCK_IOCTL_ECHO: c_int = 192;
pub const BB_SOCK_TX_LEN_GET: c_int = 193;
pub const BB_SOCK_TX_LEN_RESET: c_int = 194;
pub const BB_SOCK_IOCTL_MAX: c_int = 195;
pub const bb_sock_cmd_e = c_uint;
pub const struct_bb_sock_opt_t = extern struct {
    tx_buf_size: u32 = @import("std").mem.zeroes(u32),
    rx_buf_size: u32 = @import("std").mem.zeroes(u32),
};
pub const bb_sock_opt_t = struct_bb_sock_opt_t;
pub const bb_mem_block_t = extern struct {
    addr: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    size: u32 = @import("std").mem.zeroes(u32),
};
pub const bb_query_mem_t = extern struct {
    block: [2]bb_mem_block_t = @import("std").mem.zeroes([2]bb_mem_block_t),
};
pub const bb_event_callback = ?*const fn (?*anyopaque, ?*anyopaque) callconv(.C) void;
pub const uart_list_hd = extern struct {
    num: u32 = @import("std").mem.zeroes(u32),
    uart_dev_name: [1000]u8 = @import("std").mem.zeroes([1000]u8),
};
pub const uart_par = extern struct {
    BaudRate: c_int = @import("std").mem.zeroes(c_int),
    ByteSize: c_int = @import("std").mem.zeroes(c_int),
    Parity: c_int = @import("std").mem.zeroes(c_int),
    StopBits: c_int = @import("std").mem.zeroes(c_int),
};
pub const uart_add_ok: c_int = 0;
pub const uart_open_fail: c_int = 1;
pub const uart_had_added: c_int = 2;
pub const uart_msg = c_uint;
pub const uart_ioctl = extern struct {
    uart_dev_name: [24]u8 = @import("std").mem.zeroes([24]u8),
    par: uart_par = @import("std").mem.zeroes(uart_par),
};
pub const struct_bb_dev_t = opaque {};
pub const bb_dev_t = struct_bb_dev_t;
pub const struct_bb_dev_handle_t = opaque {};
pub const bb_dev_handle_t = struct_bb_dev_handle_t;
pub const struct_bb_host_t = opaque {};
pub const bb_host_t = struct_bb_host_t;
pub const bb_dev_list_t = ?*struct_bb_dev_t;
pub const bb_conf_ap_t = extern struct {
    ap_mac: bb_mac_t = @import("std").mem.zeroes(bb_mac_t),
    clock: u8 = @import("std").mem.zeroes(u8),
    init_mcs: u8 = @import("std").mem.zeroes(u8),
    sq_report: u8 = @import("std").mem.zeroes(u8),
    bb_mode: u8 = @import("std").mem.zeroes(u8),
    slot_mode: u8 = @import("std").mem.zeroes(u8),
    slot_bmp: u8 = @import("std").mem.zeroes(u8),
    compact_br: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_conf_dev_t = extern struct {
    ap_mac: bb_mac_t = @import("std").mem.zeroes(bb_mac_t),
    clock: u8 = @import("std").mem.zeroes(u8),
    init_mcs: u8 = @import("std").mem.zeroes(u8),
    sq_report: u8 = @import("std").mem.zeroes(u8),
    dev_mac: bb_mac_t = @import("std").mem.zeroes(bb_mac_t),
};
pub const bb_conf_ap_sync_mode_t = extern struct {
    enable: u8 = @import("std").mem.zeroes(u8),
    master: u8 = @import("std").mem.zeroes(u8),
    pin_group: u8 = @import("std").mem.zeroes(u8),
    pin_port: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_conf_br_hop_policy_t = extern struct {
    mode: u8 = @import("std").mem.zeroes(u8),
    option: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_chan_hop_item_t = extern struct {
    retx_cnt: u8 = @import("std").mem.zeroes(u8),
    power_diff: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_chan_hop_para_t = extern struct {
    item_num: u8 = @import("std").mem.zeroes(u8),
    items: [5]bb_chan_hop_item_t = @import("std").mem.zeroes([5]bb_chan_hop_item_t),
};
pub const bb_chan_hop_multi_para_t = extern struct {
    retx_cnt: u8 = @import("std").mem.zeroes(u8),
    power_diff: u8 = @import("std").mem.zeroes(u8),
    chan_inr: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_band_hop_item_t = extern struct {
    snr_diff: u16 = @import("std").mem.zeroes(u16),
    rssi_diff: u16 = @import("std").mem.zeroes(u16),
};
pub const bb_auto_band_para_t = extern struct {
    snr_thred: u16 = @import("std").mem.zeroes(u16),
    scan_count: u8 = @import("std").mem.zeroes(u8),
    scan_inr: u8 = @import("std").mem.zeroes(u8),
    round_inr: u8 = @import("std").mem.zeroes(u8),
    items: [2]bb_band_hop_item_t = @import("std").mem.zeroes([2]bb_band_hop_item_t),
};
pub const bb_subchan_t = extern struct {
    main_bw: u8 = @import("std").mem.zeroes(u8),
    sub_bw: u8 = @import("std").mem.zeroes(u8),
    chan_num: u8 = @import("std").mem.zeroes(u8),
    offset: i32 = @import("std").mem.zeroes(i32),
};
pub const bb_conf_rc_hop_policy_t = extern struct {
    enable: u8 = @import("std").mem.zeroes(u8),
    max_freq_num: u8 = @import("std").mem.zeroes(u8),
    stat_period: u8 = @import("std").mem.zeroes(u8),
    remove_percent: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_conf_chan_t = extern struct {
    band_mode: u8 = @import("std").mem.zeroes(u8),
    init_band: u8 = @import("std").mem.zeroes(u8),
    init_chan: i8 = @import("std").mem.zeroes(i8),
    bonus_low_band: i8 = @import("std").mem.zeroes(i8),
    flags: u8 = @import("std").mem.zeroes(u8),
    fs_bw: u8 = @import("std").mem.zeroes(u8),
    chan_num: u8 = @import("std").mem.zeroes(u8),
    chan_freq: [32]u32 = @import("std").mem.zeroes([32]u32),
    chan_freq_slave: [32]u32 = @import("std").mem.zeroes([32]u32),
    subchan: bb_subchan_t = @import("std").mem.zeroes(bb_subchan_t),
    hop_para: bb_chan_hop_para_t = @import("std").mem.zeroes(bb_chan_hop_para_t),
    hop_para_multi: bb_chan_hop_multi_para_t = @import("std").mem.zeroes(bb_chan_hop_multi_para_t),
    auto_band_para: bb_auto_band_para_t = @import("std").mem.zeroes(bb_auto_band_para_t),
};
pub const bb_freq_range_t = extern struct {
    freq_low: u32 = @import("std").mem.zeroes(u32),
    freq_high: u32 = @import("std").mem.zeroes(u32),
};
pub const bb_conf_candidates_t = extern struct {
    slot: u8 = @import("std").mem.zeroes(u8),
    mac_num: u8 = @import("std").mem.zeroes(u8),
    mac_tab: [5]bb_mac_t = @import("std").mem.zeroes([5]bb_mac_t),
};
pub const bb_user_para_t = extern struct {
    payload: u8 = @import("std").mem.zeroes(u8),
    fch_info_len: u8 = @import("std").mem.zeroes(u8),
    tintlv_enable: u8 = @import("std").mem.zeroes(u8),
    tintlv_num: u8 = @import("std").mem.zeroes(u8),
    tintlv_len: u8 = @import("std").mem.zeroes(u8),
    tx_mode: u8 = @import("std").mem.zeroes(u8),
    rx_mode: u8 = @import("std").mem.zeroes(u8),
    bandwidth: u8 = @import("std").mem.zeroes(u8),
    retx_count: i8 = @import("std").mem.zeroes(i8),
    pre_enc_ref: i8 = @import("std").mem.zeroes(i8),
    pre_enc_sp: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_conf_user_para_t = extern struct {
    user: u8 = @import("std").mem.zeroes(u8),
    tx_para: bb_user_para_t = @import("std").mem.zeroes(bb_user_para_t),
    rx_para: bb_user_para_t = @import("std").mem.zeroes(bb_user_para_t),
};
pub const bb_mcs_para_t = extern struct {
    mcs: u8 = @import("std").mem.zeroes(u8),
    snr_up: u16 = @import("std").mem.zeroes(u16),
    snr_dw: u16 = @import("std").mem.zeroes(u16),
    ldpc_up_num: u8 = @import("std").mem.zeroes(u8),
    ldpc_dw_num: u8 = @import("std").mem.zeroes(u8),
    up_keep_time: u16 = @import("std").mem.zeroes(u16),
    dw_keep_time: u16 = @import("std").mem.zeroes(u16),
};
pub const bb_conf_mcs_t = extern struct {
    slot: u8 = @import("std").mem.zeroes(u8),
    flags: u8 = @import("std").mem.zeroes(u8),
    delay_start: u16 = @import("std").mem.zeroes(u16),
    hold_time: u16 = @import("std").mem.zeroes(u16),
    init_mcs: u8 = @import("std").mem.zeroes(u8),
    mcs_num: u8 = @import("std").mem.zeroes(u8),
    max_wait_time: u16 = @import("std").mem.zeroes(u16),
    mcs_tab: [16]bb_mcs_para_t = @import("std").mem.zeroes([16]bb_mcs_para_t),
};
pub const bb_conf_distc_t = extern struct {
    enable: u8 = @import("std").mem.zeroes(u8),
    window: u8 = @import("std").mem.zeroes(u8),
    timeout: u8 = @import("std").mem.zeroes(u8),
    offset: u32 = @import("std").mem.zeroes(u32),
};
pub const bb_phy_pwr_basic_t = extern struct {
    pwr_mode: bb_phy_pwr_mode_e = @import("std").mem.zeroes(bb_phy_pwr_mode_e),
    pwr_init: u8 = @import("std").mem.zeroes(u8),
    pwr_auto: u8 = @import("std").mem.zeroes(u8),
    pwr_min: u8 = @import("std").mem.zeroes(u8),
    pwr_max: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_auto_power_save_t = extern struct {
    up_thred: u8 = @import("std").mem.zeroes(u8),
    dw_thred: u8 = @import("std").mem.zeroes(u8),
    keep_count: u8 = @import("std").mem.zeroes(u8),
    period_max: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_conf_power_save_t = extern struct {
    flags: u8 = @import("std").mem.zeroes(u8),
    period_fix: u8 = @import("std").mem.zeroes(u8),
    auto_policy: bb_auto_power_save_t = @import("std").mem.zeroes(bb_auto_power_save_t),
};
pub const bb_phy_status_t = extern struct {
    mcs: u8 = @import("std").mem.zeroes(u8),
    rf_mode: u8 = @import("std").mem.zeroes(u8),
    tintlv_enable: u8 = @import("std").mem.zeroes(u8),
    tintlv_num: u8 = @import("std").mem.zeroes(u8),
    tintlv_len: u8 = @import("std").mem.zeroes(u8),
    bandwidth: u8 = @import("std").mem.zeroes(u8),
    freq_khz: u32 = @import("std").mem.zeroes(u32),
};
pub const bb_link_status_t = extern struct {
    state: u8 = @import("std").mem.zeroes(u8),
    rx_mcs: u8 = @import("std").mem.zeroes(u8),
    peer_mac: bb_mac_t = @import("std").mem.zeroes(bb_mac_t),
};
pub const bb_user_status_t = extern struct {
    tx_status: bb_phy_status_t = @import("std").mem.zeroes(bb_phy_status_t),
    rx_status: bb_phy_status_t = @import("std").mem.zeroes(bb_phy_status_t),
};
pub const bb_get_status_out_t = extern struct {
    role: u8 = @import("std").mem.zeroes(u8),
    mode: u8 = @import("std").mem.zeroes(u8),
    sync_mode: u8 = @import("std").mem.zeroes(u8),
    sync_master: u8 = @import("std").mem.zeroes(u8),
    cfg_sbmp: u8 = @import("std").mem.zeroes(u8),
    rt_sbmp: u8 = @import("std").mem.zeroes(u8),
    mac: bb_mac_t = @import("std").mem.zeroes(bb_mac_t),
    user_status: [10]bb_user_status_t = @import("std").mem.zeroes([10]bb_user_status_t),
    link_status: [8]bb_link_status_t = @import("std").mem.zeroes([8]bb_link_status_t),
};
pub const bb_get_status_in_t = extern struct {
    user_bmp: u16 = @import("std").mem.zeroes(u16),
};
pub const bb_get_pair_out_t = extern struct {
    slot_bmp: u8 = @import("std").mem.zeroes(u8),
    peer_mac: [8]bb_mac_t = @import("std").mem.zeroes([8]bb_mac_t),
    quality: [8]bb_quality_t = @import("std").mem.zeroes([8]bb_quality_t),
};
pub const bb_get_ap_mac_out_t = extern struct {
    mac: bb_mac_t = @import("std").mem.zeroes(bb_mac_t),
};
pub const bb_get_candidates_in_t = extern struct {
    slot: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_get_candidates_out_t = extern struct {
    mac_num: u8 = @import("std").mem.zeroes(u8),
    mac_tab: [5]bb_mac_t = @import("std").mem.zeroes([5]bb_mac_t),
};
pub const bb_get_user_quality_in_t = extern struct {
    user_bmp: u16 = @import("std").mem.zeroes(u16),
    average: u16 = @import("std").mem.zeroes(u16),
};
pub const bb_get_user_quality_out_t = extern struct {
    qualities: [10]bb_quality_t = @import("std").mem.zeroes([10]bb_quality_t),
};
pub const bb_get_distc_result_in_t = extern struct {
    slot_bmp: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_get_peer_quality_in_t = extern struct {
    slot_bmp: u8 = @import("std").mem.zeroes(u8),
    arverage: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_get_peer_quality_out_t = extern struct {
    qualities: [8]bb_quality_t = @import("std").mem.zeroes([8]bb_quality_t),
};
pub const bb_get_ap_time_out_t = extern struct {
    timestamp: u32 = @import("std").mem.zeroes(u32),
};
pub const bb_get_distc_result_out_t = extern struct {
    distance: [8]i32 = @import("std").mem.zeroes([8]i32),
};
pub const bb_get_mcs_in_t = extern struct {
    dir: u8 = @import("std").mem.zeroes(u8),
    slot: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_get_mcs_out_t = extern struct {
    mcs: u8 = @import("std").mem.zeroes(u8),
    throughput: u32 = @import("std").mem.zeroes(u32),
};
pub const bb_get_chan_info_out_t = extern struct {
    chan_num: u8 = @import("std").mem.zeroes(u8),
    auto_mode: u8 = @import("std").mem.zeroes(u8),
    acs_chan: u8 = @import("std").mem.zeroes(u8),
    work_chan: u8 = @import("std").mem.zeroes(u8),
    freq: [32]u32 = @import("std").mem.zeroes([32]u32),
    power: [32]i32 = @import("std").mem.zeroes([32]i32),
};
pub const bb_get_reg_in_t = extern struct {
    offset: u16 = @import("std").mem.zeroes(u16),
    length: u16 = @import("std").mem.zeroes(u16),
};
pub const bb_get_reg_out_t = extern struct {
    data: [256]u8 = @import("std").mem.zeroes([256]u8),
};
pub const bb_get_cfg_in_t = extern struct {
    seq: u16 = @import("std").mem.zeroes(u16),
    mode: u8 = @import("std").mem.zeroes(u8),
    rsv: u8 = @import("std").mem.zeroes(u8),
    offset: u16 = @import("std").mem.zeroes(u16),
    length: u16 = @import("std").mem.zeroes(u16),
};
pub const bb_get_cfg_out_t = extern struct {
    seq: u16 = @import("std").mem.zeroes(u16),
    rsv: u16 = @import("std").mem.zeroes(u16),
    total_length: u16 = @import("std").mem.zeroes(u16),
    total_crc16: u16 = @import("std").mem.zeroes(u16),
    offset: u16 = @import("std").mem.zeroes(u16),
    length: u16 = @import("std").mem.zeroes(u16),
    data: [1012]u8 = @import("std").mem.zeroes([1012]u8),
};
pub const bb_get_dbg_mode_out_t = extern struct {
    enable: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_get_pwr_mode_out_t = extern struct {
    pwr_mode: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_get_cur_pwr_in_t = extern struct {
    usr: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_get_cur_pwr_out_t = extern struct {
    usr: u8 = @import("std").mem.zeroes(u8),
    pwr: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_get_pwr_auto_out_t = extern struct {
    pwr_auto: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_get_sys_info_out_t = extern struct {
    uptime: u64 = @import("std").mem.zeroes(u64),
    compile_time: [32]u8 = @import("std").mem.zeroes([32]u8),
    soft_ver: [32]u8 = @import("std").mem.zeroes([32]u8),
    hardware_ver: [32]u8 = @import("std").mem.zeroes([32]u8),
    firmware_ver: [32]u8 = @import("std").mem.zeroes([32]u8),
};
pub const bb_get_prj_dispatch_in_t = extern struct {
    data: [256]u8 = @import("std").mem.zeroes([256]u8),
};
pub const bb_get_prj_dispatch_out_t = bb_get_prj_dispatch_in_t;
pub const bb_get_band_info_in_t = extern struct {
    rsv: [32]u8 = @import("std").mem.zeroes([32]u8),
};
pub const bb_get_band_info_out_t = extern struct {
    band_mode: u8 = @import("std").mem.zeroes(u8),
    work_band: u8 = @import("std").mem.zeroes(u8),
    rsv: [30]u8 = @import("std").mem.zeroes([30]u8),
};
pub const bb_get_user_info_in_t = extern struct {
    user: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_get_user_info_out_t = extern struct {
    freq_offset: i32 = @import("std").mem.zeroes(i32),
    rsv: [124]u8 = @import("std").mem.zeroes([124]u8),
};
pub const bb_get_1v1_info_in_t = extern struct {
    frame_num: u8 = @import("std").mem.zeroes(u8),
    rsv: [3]u8 = @import("std").mem.zeroes([3]u8),
};
pub const bb_info_t = extern struct {
    snr: u16 = @import("std").mem.zeroes(u16),
    ldpc_tlv_err_ratio: u16 = @import("std").mem.zeroes(u16),
    ldpc_num_err_ratio: u16 = @import("std").mem.zeroes(u16),
    gain_a: u8 = @import("std").mem.zeroes(u8),
    gain_b: u8 = @import("std").mem.zeroes(u8),
    tx_mcs: u8 = @import("std").mem.zeroes(u8),
    tx_chan: u8 = @import("std").mem.zeroes(u8),
    rev: [62]u8 = @import("std").mem.zeroes([62]u8),
};
pub const bb_get_1v1_info_out_t = extern struct {
    self: bb_info_t = @import("std").mem.zeroes(bb_info_t),
    peer: bb_info_t = @import("std").mem.zeroes(bb_info_t),
    rev: [64]u8 = @import("std").mem.zeroes([64]u8),
};
pub const BB_REMOTE_TYPE_BAND_MODE: c_int = 0;
pub const BB_REMOTE_TYPE_TARGET_BAND: c_int = 1;
pub const BB_REMOTE_TYPE_CHAN_MODE: c_int = 2;
pub const BB_REMOTE_TYPE_TARGET_CHAN: c_int = 3;
pub const BB_REMOTE_TYPE_COMPLIANCE_MODE: c_int = 4;
pub const BB_REMOTE_TYPE_MAX: c_int = 5;
pub const bb_remote_type_e = c_uint;
pub const bb_remote_setting_t = extern struct {
    auto_band: u8 = @import("std").mem.zeroes(u8),
    target_band: u8 = @import("std").mem.zeroes(u8),
    auto_chan: u8 = @import("std").mem.zeroes(u8),
    target_chan: u8 = @import("std").mem.zeroes(u8),
    compliance_mode: u8 = @import("std").mem.zeroes(u8),
    padding: [123]u8 = @import("std").mem.zeroes([123]u8),
};
pub const bb_get_remote_in_t = extern struct {
    slot: u8 = @import("std").mem.zeroes(u8),
    padding: [3]u8 = @import("std").mem.zeroes([3]u8),
    type_bmp: u32 = @import("std").mem.zeroes(u32),
};
pub const bb_get_remote_out_t = extern struct {
    valid_bmp: u32 = @import("std").mem.zeroes(u32),
    setting: bb_remote_setting_t = @import("std").mem.zeroes(bb_remote_setting_t),
};
pub const bb_set_event_callback_t = extern struct {
    event: bb_event_e = @import("std").mem.zeroes(bb_event_e),
    callback: bb_event_callback = @import("std").mem.zeroes(bb_event_callback),
    user: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
};
pub const bb_set_pair_mode_t = extern struct {
    start: u8 = @import("std").mem.zeroes(u8),
    slot_bmp: u8 = @import("std").mem.zeroes(u8),
    black_list: [3]bb_mac_t = @import("std").mem.zeroes([3]bb_mac_t),
};
pub const bb_set_ap_mac_t = extern struct {
    mac: bb_mac_t = @import("std").mem.zeroes(bb_mac_t),
};
pub const bb_set_chan_mode_t = extern struct {
    auto_mode: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_chan_t = extern struct {
    chan_dir: u8 = @import("std").mem.zeroes(u8),
    chan_index: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_mcs_mode_t = extern struct {
    slot: u8 = @import("std").mem.zeroes(u8),
    auto_mode: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_mcs_t = extern struct {
    slot: u8 = @import("std").mem.zeroes(u8),
    mcs: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_master_dev_t = extern struct {
    slot: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_candidate_t = bb_conf_candidates_t;
pub const bb_set_reg_t = extern struct {
    offset: u16 = @import("std").mem.zeroes(u16),
    length: u16 = @import("std").mem.zeroes(u16),
    data: [256]u8 = @import("std").mem.zeroes([256]u8),
};
pub const bb_set_cfg_t = extern struct {
    seq: u32 = @import("std").mem.zeroes(u32),
    total_length: u16 = @import("std").mem.zeroes(u16),
    total_crc16: u16 = @import("std").mem.zeroes(u16),
    offset: u16 = @import("std").mem.zeroes(u16),
    length: u16 = @import("std").mem.zeroes(u16),
    data: [1012]u8 = @import("std").mem.zeroes([1012]u8),
};
pub const bb_set_plot_t = extern struct {
    user: u8 = @import("std").mem.zeroes(u8),
    enable: u8 = @import("std").mem.zeroes(u8),
    cache_num: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_dbg_mode_t = bb_get_dbg_mode_out_t;
pub const bb_set_pwr_mode_in_t = bb_get_pwr_mode_out_t;
pub const bb_set_pwr_in_t = bb_get_cur_pwr_out_t;
pub const bb_set_pwr_auto_in_t = bb_get_pwr_auto_out_t;
pub const bb_set_freq_t = extern struct {
    user: u8 = @import("std").mem.zeroes(u8),
    dir_bmp: u8 = @import("std").mem.zeroes(u8),
    freq_khz: u32 = @import("std").mem.zeroes(u32),
};
pub const bb_set_tx_mcs_t = extern struct {
    user: u8 = @import("std").mem.zeroes(u8),
    mcs: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_reset_t = extern struct {
    user: u8 = @import("std").mem.zeroes(u8),
    dir_bmp: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_reboot_t = extern struct {
    tim_ms: u32 = @import("std").mem.zeroes(u32),
};
pub const bb_set_tx_path_t = extern struct {
    path_bmp: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_rx_path_t = bb_set_tx_path_t;
pub const bb_set_orig_cfg_t = extern struct {
    role: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_rf_t = extern struct {
    rf_path: u8 = @import("std").mem.zeroes(u8),
    dir: u8 = @import("std").mem.zeroes(u8),
    state: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_power_offset_t = extern struct {
    band: u8 = @import("std").mem.zeroes(u8),
    offset: i8 = @import("std").mem.zeroes(i8),
    path: u8 = @import("std").mem.zeroes(u8),
    rsv: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_hot_upgrade_write_in_t = extern struct {
    seq: u16 = @import("std").mem.zeroes(u16),
    len: u16 = @import("std").mem.zeroes(u16),
    addr: u32 = @import("std").mem.zeroes(u32),
    data: [1016]u8 = @import("std").mem.zeroes([1016]u8),
};
pub const bb_set_hot_upgrade_write_out_t = extern struct {
    seq: u16 = @import("std").mem.zeroes(u16),
    ret: i16 = @import("std").mem.zeroes(i16),
};
pub const bb_set_hot_upgrade_crc32_in_t = extern struct {
    seq: u16 = @import("std").mem.zeroes(u16),
    reserve: u16 = @import("std").mem.zeroes(u16),
    len: u32 = @import("std").mem.zeroes(u32),
    addr: u32 = @import("std").mem.zeroes(u32),
    crc32: u32 = @import("std").mem.zeroes(u32),
};
pub const bb_set_prj_dispatch_in_t = bb_get_prj_dispatch_in_t;
pub const bb_set_prj_dispatch2_in_t = extern struct {
    data: [1024]u8 = @import("std").mem.zeroes([1024]u8),
};
pub const bb_set_frame_change_t = extern struct {
    mode: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_compliance_mode_t = extern struct {
    enable: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_band_mode_t = extern struct {
    auto_mode: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_band_t = extern struct {
    target_band: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_remote_t = extern struct {
    slot: u8 = @import("std").mem.zeroes(u8),
    padding: [3]u8 = @import("std").mem.zeroes([3]u8),
    type_bmp: u32 = @import("std").mem.zeroes(u32),
    setting: bb_remote_setting_t = @import("std").mem.zeroes(bb_remote_setting_t),
};
pub const bb_set_bandwidth_t = extern struct {
    slot: u8 = @import("std").mem.zeroes(u8),
    dir: u8 = @import("std").mem.zeroes(u8),
    bandwidth: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_set_power_save_mode_t = extern struct {
    mode: i8 = @import("std").mem.zeroes(i8),
};
pub const bb_set_power_save_t = extern struct {
    period: u8 = @import("std").mem.zeroes(u8),
};
pub const bb_dfs_polic_t = extern struct {
    pwr_min: i16 = @import("std").mem.zeroes(i16),
    pwr_max: i16 = @import("std").mem.zeroes(i16),
    gain: u8 = @import("std").mem.zeroes(u8),
    detected_mask: u8 = @import("std").mem.zeroes(u8),
    dynamic: u8 = @import("std").mem.zeroes(u8),
};
pub const BB_DFS_POLIC_LEVEL0: c_int = 0;
pub const BB_DFS_POLIC_LEVEL1: c_int = 1;
pub const BB_DFS_POLIC_LEVEL2: c_int = 2;
pub const BB_DFS_POLIC_LEVEL3: c_int = 3;
pub const BB_DFS_POLIC_LAB: c_int = 4;
pub const BB_DFS_POLIC_MAX: c_int = 5;
pub const bb_dfs_polic_e = c_uint;
// .\inc\bb_api.h:1296:13: warning: struct demoted to opaque type - has bitfield
pub const bb_conf_dfs_t = opaque {};
// .\inc\bb_api.h:1315:14: warning: struct demoted to opaque type - has bitfield
pub const bb_conf_dfs_mask_t = opaque {};
// .\inc\bb_api.h:1334:14: warning: struct demoted to opaque type - has bitfield
pub const bb_dfs_act_t = opaque {};
// .\inc\bb_api.h:1339:14: warning: struct demoted to opaque type - has bitfield
pub const bb_set_dfs_t = opaque {};
pub const QUERY_TX_IN = extern struct {
    slot: c_int = @import("std").mem.zeroes(c_int),
    port: c_int = @import("std").mem.zeroes(c_int),
};
pub const QUERY_TX_OUT = extern struct {
    buff_index: u64 = @import("std").mem.zeroes(u64),
    buff_len: i32 = @import("std").mem.zeroes(i32),
    buff_avail: i32 = @import("std").mem.zeroes(i32),
};
pub const QUERY_RX_OUT = extern struct {
    buff_len: i32 = @import("std").mem.zeroes(i32),
};
pub const BUFF_LIMIT = extern struct {
    buff_len: i32 = @import("std").mem.zeroes(i32),
};
pub const bb_event_pair_result_t = extern struct {
    ret: i32 = @import("std").mem.zeroes(i32),
};
pub const bb_set_hot_upgrade_crc32_out_t = bb_set_hot_upgrade_write_out_t;
pub const __llvm__ = @as(c_int, 1);
pub const __clang__ = @as(c_int, 1);
pub const __clang_major__ = @as(c_int, 18);
pub const __clang_minor__ = @as(c_int, 1);
pub const __clang_patchlevel__ = @as(c_int, 7);
pub const __clang_version__ = "18.1.7 (https://github.com/ziglang/zig-bootstrap ec2dca85a340f134d2fcfdc9007e91f9abed6996)";
pub const __GNUC__ = @as(c_int, 4);
pub const __GNUC_MINOR__ = @as(c_int, 2);
pub const __GNUC_PATCHLEVEL__ = @as(c_int, 1);
pub const __GXX_ABI_VERSION = @as(c_int, 1002);
pub const __ATOMIC_RELAXED = @as(c_int, 0);
pub const __ATOMIC_CONSUME = @as(c_int, 1);
pub const __ATOMIC_ACQUIRE = @as(c_int, 2);
pub const __ATOMIC_RELEASE = @as(c_int, 3);
pub const __ATOMIC_ACQ_REL = @as(c_int, 4);
pub const __ATOMIC_SEQ_CST = @as(c_int, 5);
pub const __MEMORY_SCOPE_SYSTEM = @as(c_int, 0);
pub const __MEMORY_SCOPE_DEVICE = @as(c_int, 1);
pub const __MEMORY_SCOPE_WRKGRP = @as(c_int, 2);
pub const __MEMORY_SCOPE_WVFRNT = @as(c_int, 3);
pub const __MEMORY_SCOPE_SINGLE = @as(c_int, 4);
pub const __OPENCL_MEMORY_SCOPE_WORK_ITEM = @as(c_int, 0);
pub const __OPENCL_MEMORY_SCOPE_WORK_GROUP = @as(c_int, 1);
pub const __OPENCL_MEMORY_SCOPE_DEVICE = @as(c_int, 2);
pub const __OPENCL_MEMORY_SCOPE_ALL_SVM_DEVICES = @as(c_int, 3);
pub const __OPENCL_MEMORY_SCOPE_SUB_GROUP = @as(c_int, 4);
pub const __FPCLASS_SNAN = @as(c_int, 0x0001);
pub const __FPCLASS_QNAN = @as(c_int, 0x0002);
pub const __FPCLASS_NEGINF = @as(c_int, 0x0004);
pub const __FPCLASS_NEGNORMAL = @as(c_int, 0x0008);
pub const __FPCLASS_NEGSUBNORMAL = @as(c_int, 0x0010);
pub const __FPCLASS_NEGZERO = @as(c_int, 0x0020);
pub const __FPCLASS_POSZERO = @as(c_int, 0x0040);
pub const __FPCLASS_POSSUBNORMAL = @as(c_int, 0x0080);
pub const __FPCLASS_POSNORMAL = @as(c_int, 0x0100);
pub const __FPCLASS_POSINF = @as(c_int, 0x0200);
pub const __PRAGMA_REDEFINE_EXTNAME = @as(c_int, 1);
pub const __VERSION__ = "Clang 18.1.7 (https://github.com/ziglang/zig-bootstrap ec2dca85a340f134d2fcfdc9007e91f9abed6996)";
pub const __OBJC_BOOL_IS_BOOL = @as(c_int, 0);
pub const __CONSTANT_CFSTRINGS__ = @as(c_int, 1);
pub const __SEH__ = @as(c_int, 1);
pub const __clang_literal_encoding__ = "UTF-8";
pub const __clang_wide_literal_encoding__ = "UTF-16";
pub const __ORDER_LITTLE_ENDIAN__ = @as(c_int, 1234);
pub const __ORDER_BIG_ENDIAN__ = @as(c_int, 4321);
pub const __ORDER_PDP_ENDIAN__ = @as(c_int, 3412);
pub const __BYTE_ORDER__ = __ORDER_LITTLE_ENDIAN__;
pub const __LITTLE_ENDIAN__ = @as(c_int, 1);
pub const __CHAR_BIT__ = @as(c_int, 8);
pub const __BOOL_WIDTH__ = @as(c_int, 8);
pub const __SHRT_WIDTH__ = @as(c_int, 16);
pub const __INT_WIDTH__ = @as(c_int, 32);
pub const __LONG_WIDTH__ = @as(c_int, 32);
pub const __LLONG_WIDTH__ = @as(c_int, 64);
pub const __BITINT_MAXWIDTH__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 8388608, .decimal);
pub const __SCHAR_MAX__ = @as(c_int, 127);
pub const __SHRT_MAX__ = @as(c_int, 32767);
pub const __INT_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __LONG_MAX__ = @as(c_long, 2147483647);
pub const __LONG_LONG_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __WCHAR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __WCHAR_WIDTH__ = @as(c_int, 16);
pub const __WINT_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __WINT_WIDTH__ = @as(c_int, 16);
pub const __INTMAX_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __INTMAX_WIDTH__ = @as(c_int, 64);
pub const __SIZE_MAX__ = @as(c_ulonglong, 18446744073709551615);
pub const __SIZE_WIDTH__ = @as(c_int, 64);
pub const __UINTMAX_MAX__ = @as(c_ulonglong, 18446744073709551615);
pub const __UINTMAX_WIDTH__ = @as(c_int, 64);
pub const __PTRDIFF_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __PTRDIFF_WIDTH__ = @as(c_int, 64);
pub const __INTPTR_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __INTPTR_WIDTH__ = @as(c_int, 64);
pub const __UINTPTR_MAX__ = @as(c_ulonglong, 18446744073709551615);
pub const __UINTPTR_WIDTH__ = @as(c_int, 64);
pub const __SIZEOF_DOUBLE__ = @as(c_int, 8);
pub const __SIZEOF_FLOAT__ = @as(c_int, 4);
pub const __SIZEOF_INT__ = @as(c_int, 4);
pub const __SIZEOF_LONG__ = @as(c_int, 4);
pub const __SIZEOF_LONG_DOUBLE__ = @as(c_int, 16);
pub const __SIZEOF_LONG_LONG__ = @as(c_int, 8);
pub const __SIZEOF_POINTER__ = @as(c_int, 8);
pub const __SIZEOF_SHORT__ = @as(c_int, 2);
pub const __SIZEOF_PTRDIFF_T__ = @as(c_int, 8);
pub const __SIZEOF_SIZE_T__ = @as(c_int, 8);
pub const __SIZEOF_WCHAR_T__ = @as(c_int, 2);
pub const __SIZEOF_WINT_T__ = @as(c_int, 2);
pub const __SIZEOF_INT128__ = @as(c_int, 16);
pub const __INTMAX_TYPE__ = c_longlong;
pub const __INTMAX_FMTd__ = "lld";
pub const __INTMAX_FMTi__ = "lli";
pub const __INTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `LL`");
// (no file):94:9
pub const __UINTMAX_TYPE__ = c_ulonglong;
pub const __UINTMAX_FMTo__ = "llo";
pub const __UINTMAX_FMTu__ = "llu";
pub const __UINTMAX_FMTx__ = "llx";
pub const __UINTMAX_FMTX__ = "llX";
pub const __UINTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `ULL`");
// (no file):100:9
pub const __PTRDIFF_TYPE__ = c_longlong;
pub const __PTRDIFF_FMTd__ = "lld";
pub const __PTRDIFF_FMTi__ = "lli";
pub const __INTPTR_TYPE__ = c_longlong;
pub const __INTPTR_FMTd__ = "lld";
pub const __INTPTR_FMTi__ = "lli";
pub const __SIZE_TYPE__ = c_ulonglong;
pub const __SIZE_FMTo__ = "llo";
pub const __SIZE_FMTu__ = "llu";
pub const __SIZE_FMTx__ = "llx";
pub const __SIZE_FMTX__ = "llX";
pub const __WCHAR_TYPE__ = c_ushort;
pub const __WINT_TYPE__ = c_ushort;
pub const __SIG_ATOMIC_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __SIG_ATOMIC_WIDTH__ = @as(c_int, 32);
pub const __CHAR16_TYPE__ = c_ushort;
pub const __CHAR32_TYPE__ = c_uint;
pub const __UINTPTR_TYPE__ = c_ulonglong;
pub const __UINTPTR_FMTo__ = "llo";
pub const __UINTPTR_FMTu__ = "llu";
pub const __UINTPTR_FMTx__ = "llx";
pub const __UINTPTR_FMTX__ = "llX";
pub const __FLT16_DENORM_MIN__ = @as(f16, 5.9604644775390625e-8);
pub const __FLT16_HAS_DENORM__ = @as(c_int, 1);
pub const __FLT16_DIG__ = @as(c_int, 3);
pub const __FLT16_DECIMAL_DIG__ = @as(c_int, 5);
pub const __FLT16_EPSILON__ = @as(f16, 9.765625e-4);
pub const __FLT16_HAS_INFINITY__ = @as(c_int, 1);
pub const __FLT16_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __FLT16_MANT_DIG__ = @as(c_int, 11);
pub const __FLT16_MAX_10_EXP__ = @as(c_int, 4);
pub const __FLT16_MAX_EXP__ = @as(c_int, 16);
pub const __FLT16_MAX__ = @as(f16, 6.5504e+4);
pub const __FLT16_MIN_10_EXP__ = -@as(c_int, 4);
pub const __FLT16_MIN_EXP__ = -@as(c_int, 13);
pub const __FLT16_MIN__ = @as(f16, 6.103515625e-5);
pub const __FLT_DENORM_MIN__ = @as(f32, 1.40129846e-45);
pub const __FLT_HAS_DENORM__ = @as(c_int, 1);
pub const __FLT_DIG__ = @as(c_int, 6);
pub const __FLT_DECIMAL_DIG__ = @as(c_int, 9);
pub const __FLT_EPSILON__ = @as(f32, 1.19209290e-7);
pub const __FLT_HAS_INFINITY__ = @as(c_int, 1);
pub const __FLT_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __FLT_MANT_DIG__ = @as(c_int, 24);
pub const __FLT_MAX_10_EXP__ = @as(c_int, 38);
pub const __FLT_MAX_EXP__ = @as(c_int, 128);
pub const __FLT_MAX__ = @as(f32, 3.40282347e+38);
pub const __FLT_MIN_10_EXP__ = -@as(c_int, 37);
pub const __FLT_MIN_EXP__ = -@as(c_int, 125);
pub const __FLT_MIN__ = @as(f32, 1.17549435e-38);
pub const __DBL_DENORM_MIN__ = @as(f64, 4.9406564584124654e-324);
pub const __DBL_HAS_DENORM__ = @as(c_int, 1);
pub const __DBL_DIG__ = @as(c_int, 15);
pub const __DBL_DECIMAL_DIG__ = @as(c_int, 17);
pub const __DBL_EPSILON__ = @as(f64, 2.2204460492503131e-16);
pub const __DBL_HAS_INFINITY__ = @as(c_int, 1);
pub const __DBL_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __DBL_MANT_DIG__ = @as(c_int, 53);
pub const __DBL_MAX_10_EXP__ = @as(c_int, 308);
pub const __DBL_MAX_EXP__ = @as(c_int, 1024);
pub const __DBL_MAX__ = @as(f64, 1.7976931348623157e+308);
pub const __DBL_MIN_10_EXP__ = -@as(c_int, 307);
pub const __DBL_MIN_EXP__ = -@as(c_int, 1021);
pub const __DBL_MIN__ = @as(f64, 2.2250738585072014e-308);
pub const __LDBL_DENORM_MIN__ = @as(c_longdouble, 3.64519953188247460253e-4951);
pub const __LDBL_HAS_DENORM__ = @as(c_int, 1);
pub const __LDBL_DIG__ = @as(c_int, 18);
pub const __LDBL_DECIMAL_DIG__ = @as(c_int, 21);
pub const __LDBL_EPSILON__ = @as(c_longdouble, 1.08420217248550443401e-19);
pub const __LDBL_HAS_INFINITY__ = @as(c_int, 1);
pub const __LDBL_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __LDBL_MANT_DIG__ = @as(c_int, 64);
pub const __LDBL_MAX_10_EXP__ = @as(c_int, 4932);
pub const __LDBL_MAX_EXP__ = @as(c_int, 16384);
pub const __LDBL_MAX__ = @as(c_longdouble, 1.18973149535723176502e+4932);
pub const __LDBL_MIN_10_EXP__ = -@as(c_int, 4931);
pub const __LDBL_MIN_EXP__ = -@as(c_int, 16381);
pub const __LDBL_MIN__ = @as(c_longdouble, 3.36210314311209350626e-4932);
pub const __POINTER_WIDTH__ = @as(c_int, 64);
pub const __BIGGEST_ALIGNMENT__ = @as(c_int, 16);
pub const __WCHAR_UNSIGNED__ = @as(c_int, 1);
pub const __WINT_UNSIGNED__ = @as(c_int, 1);
pub const __INT8_TYPE__ = i8;
pub const __INT8_FMTd__ = "hhd";
pub const __INT8_FMTi__ = "hhi";
pub const __INT8_C_SUFFIX__ = "";
pub const __INT16_TYPE__ = c_short;
pub const __INT16_FMTd__ = "hd";
pub const __INT16_FMTi__ = "hi";
pub const __INT16_C_SUFFIX__ = "";
pub const __INT32_TYPE__ = c_int;
pub const __INT32_FMTd__ = "d";
pub const __INT32_FMTi__ = "i";
pub const __INT32_C_SUFFIX__ = "";
pub const __INT64_TYPE__ = c_longlong;
pub const __INT64_FMTd__ = "lld";
pub const __INT64_FMTi__ = "lli";
pub const __INT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `LL`");
// (no file):198:9
pub const __UINT8_TYPE__ = u8;
pub const __UINT8_FMTo__ = "hho";
pub const __UINT8_FMTu__ = "hhu";
pub const __UINT8_FMTx__ = "hhx";
pub const __UINT8_FMTX__ = "hhX";
pub const __UINT8_C_SUFFIX__ = "";
pub const __UINT8_MAX__ = @as(c_int, 255);
pub const __INT8_MAX__ = @as(c_int, 127);
pub const __UINT16_TYPE__ = c_ushort;
pub const __UINT16_FMTo__ = "ho";
pub const __UINT16_FMTu__ = "hu";
pub const __UINT16_FMTx__ = "hx";
pub const __UINT16_FMTX__ = "hX";
pub const __UINT16_C_SUFFIX__ = "";
pub const __UINT16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __INT16_MAX__ = @as(c_int, 32767);
pub const __UINT32_TYPE__ = c_uint;
pub const __UINT32_FMTo__ = "o";
pub const __UINT32_FMTu__ = "u";
pub const __UINT32_FMTx__ = "x";
pub const __UINT32_FMTX__ = "X";
pub const __UINT32_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `U`");
// (no file):220:9
pub const __UINT32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __INT32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __UINT64_TYPE__ = c_ulonglong;
pub const __UINT64_FMTo__ = "llo";
pub const __UINT64_FMTu__ = "llu";
pub const __UINT64_FMTx__ = "llx";
pub const __UINT64_FMTX__ = "llX";
pub const __UINT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `ULL`");
// (no file):228:9
pub const __UINT64_MAX__ = @as(c_ulonglong, 18446744073709551615);
pub const __INT64_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __INT_LEAST8_TYPE__ = i8;
pub const __INT_LEAST8_MAX__ = @as(c_int, 127);
pub const __INT_LEAST8_WIDTH__ = @as(c_int, 8);
pub const __INT_LEAST8_FMTd__ = "hhd";
pub const __INT_LEAST8_FMTi__ = "hhi";
pub const __UINT_LEAST8_TYPE__ = u8;
pub const __UINT_LEAST8_MAX__ = @as(c_int, 255);
pub const __UINT_LEAST8_FMTo__ = "hho";
pub const __UINT_LEAST8_FMTu__ = "hhu";
pub const __UINT_LEAST8_FMTx__ = "hhx";
pub const __UINT_LEAST8_FMTX__ = "hhX";
pub const __INT_LEAST16_TYPE__ = c_short;
pub const __INT_LEAST16_MAX__ = @as(c_int, 32767);
pub const __INT_LEAST16_WIDTH__ = @as(c_int, 16);
pub const __INT_LEAST16_FMTd__ = "hd";
pub const __INT_LEAST16_FMTi__ = "hi";
pub const __UINT_LEAST16_TYPE__ = c_ushort;
pub const __UINT_LEAST16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __UINT_LEAST16_FMTo__ = "ho";
pub const __UINT_LEAST16_FMTu__ = "hu";
pub const __UINT_LEAST16_FMTx__ = "hx";
pub const __UINT_LEAST16_FMTX__ = "hX";
pub const __INT_LEAST32_TYPE__ = c_int;
pub const __INT_LEAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_LEAST32_WIDTH__ = @as(c_int, 32);
pub const __INT_LEAST32_FMTd__ = "d";
pub const __INT_LEAST32_FMTi__ = "i";
pub const __UINT_LEAST32_TYPE__ = c_uint;
pub const __UINT_LEAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __UINT_LEAST32_FMTo__ = "o";
pub const __UINT_LEAST32_FMTu__ = "u";
pub const __UINT_LEAST32_FMTx__ = "x";
pub const __UINT_LEAST32_FMTX__ = "X";
pub const __INT_LEAST64_TYPE__ = c_longlong;
pub const __INT_LEAST64_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __INT_LEAST64_WIDTH__ = @as(c_int, 64);
pub const __INT_LEAST64_FMTd__ = "lld";
pub const __INT_LEAST64_FMTi__ = "lli";
pub const __UINT_LEAST64_TYPE__ = c_ulonglong;
pub const __UINT_LEAST64_MAX__ = @as(c_ulonglong, 18446744073709551615);
pub const __UINT_LEAST64_FMTo__ = "llo";
pub const __UINT_LEAST64_FMTu__ = "llu";
pub const __UINT_LEAST64_FMTx__ = "llx";
pub const __UINT_LEAST64_FMTX__ = "llX";
pub const __INT_FAST8_TYPE__ = i8;
pub const __INT_FAST8_MAX__ = @as(c_int, 127);
pub const __INT_FAST8_WIDTH__ = @as(c_int, 8);
pub const __INT_FAST8_FMTd__ = "hhd";
pub const __INT_FAST8_FMTi__ = "hhi";
pub const __UINT_FAST8_TYPE__ = u8;
pub const __UINT_FAST8_MAX__ = @as(c_int, 255);
pub const __UINT_FAST8_FMTo__ = "hho";
pub const __UINT_FAST8_FMTu__ = "hhu";
pub const __UINT_FAST8_FMTx__ = "hhx";
pub const __UINT_FAST8_FMTX__ = "hhX";
pub const __INT_FAST16_TYPE__ = c_short;
pub const __INT_FAST16_MAX__ = @as(c_int, 32767);
pub const __INT_FAST16_WIDTH__ = @as(c_int, 16);
pub const __INT_FAST16_FMTd__ = "hd";
pub const __INT_FAST16_FMTi__ = "hi";
pub const __UINT_FAST16_TYPE__ = c_ushort;
pub const __UINT_FAST16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __UINT_FAST16_FMTo__ = "ho";
pub const __UINT_FAST16_FMTu__ = "hu";
pub const __UINT_FAST16_FMTx__ = "hx";
pub const __UINT_FAST16_FMTX__ = "hX";
pub const __INT_FAST32_TYPE__ = c_int;
pub const __INT_FAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_FAST32_WIDTH__ = @as(c_int, 32);
pub const __INT_FAST32_FMTd__ = "d";
pub const __INT_FAST32_FMTi__ = "i";
pub const __UINT_FAST32_TYPE__ = c_uint;
pub const __UINT_FAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __UINT_FAST32_FMTo__ = "o";
pub const __UINT_FAST32_FMTu__ = "u";
pub const __UINT_FAST32_FMTx__ = "x";
pub const __UINT_FAST32_FMTX__ = "X";
pub const __INT_FAST64_TYPE__ = c_longlong;
pub const __INT_FAST64_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __INT_FAST64_WIDTH__ = @as(c_int, 64);
pub const __INT_FAST64_FMTd__ = "lld";
pub const __INT_FAST64_FMTi__ = "lli";
pub const __UINT_FAST64_TYPE__ = c_ulonglong;
pub const __UINT_FAST64_MAX__ = @as(c_ulonglong, 18446744073709551615);
pub const __UINT_FAST64_FMTo__ = "llo";
pub const __UINT_FAST64_FMTu__ = "llu";
pub const __UINT_FAST64_FMTx__ = "llx";
pub const __UINT_FAST64_FMTX__ = "llX";
pub const __USER_LABEL_PREFIX__ = "";
pub const __FINITE_MATH_ONLY__ = @as(c_int, 0);
pub const __GNUC_STDC_INLINE__ = @as(c_int, 1);
pub const __GCC_ATOMIC_TEST_AND_SET_TRUEVAL = @as(c_int, 1);
pub const __CLANG_ATOMIC_BOOL_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_SHORT_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_INT_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_LONG_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_LLONG_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_POINTER_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_BOOL_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_SHORT_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_INT_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_LONG_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_LLONG_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_POINTER_LOCK_FREE = @as(c_int, 2);
pub const __NO_INLINE__ = @as(c_int, 1);
pub const __PIC__ = @as(c_int, 2);
pub const __pic__ = @as(c_int, 2);
pub const __FLT_RADIX__ = @as(c_int, 2);
pub const __DECIMAL_DIG__ = __LDBL_DECIMAL_DIG__;
pub const __GCC_ASM_FLAG_OUTPUTS__ = @as(c_int, 1);
pub const __code_model_small__ = @as(c_int, 1);
pub const __amd64__ = @as(c_int, 1);
pub const __amd64 = @as(c_int, 1);
pub const __x86_64 = @as(c_int, 1);
pub const __x86_64__ = @as(c_int, 1);
pub const __SEG_GS = @as(c_int, 1);
pub const __SEG_FS = @as(c_int, 1);
pub const __seg_gs = @compileError("unable to translate macro: undefined identifier `address_space`");
// (no file):356:9
pub const __seg_fs = @compileError("unable to translate macro: undefined identifier `address_space`");
// (no file):357:9
pub const __corei7 = @as(c_int, 1);
pub const __corei7__ = @as(c_int, 1);
pub const __tune_corei7__ = @as(c_int, 1);
pub const __REGISTER_PREFIX__ = "";
pub const __NO_MATH_INLINES = @as(c_int, 1);
pub const __AES__ = @as(c_int, 1);
pub const __PCLMUL__ = @as(c_int, 1);
pub const __LAHF_SAHF__ = @as(c_int, 1);
pub const __LZCNT__ = @as(c_int, 1);
pub const __RDRND__ = @as(c_int, 1);
pub const __FSGSBASE__ = @as(c_int, 1);
pub const __BMI__ = @as(c_int, 1);
pub const __BMI2__ = @as(c_int, 1);
pub const __POPCNT__ = @as(c_int, 1);
pub const __PRFCHW__ = @as(c_int, 1);
pub const __RDSEED__ = @as(c_int, 1);
pub const __ADX__ = @as(c_int, 1);
pub const __MOVBE__ = @as(c_int, 1);
pub const __FMA__ = @as(c_int, 1);
pub const __F16C__ = @as(c_int, 1);
pub const __FXSR__ = @as(c_int, 1);
pub const __XSAVE__ = @as(c_int, 1);
pub const __XSAVEOPT__ = @as(c_int, 1);
pub const __XSAVEC__ = @as(c_int, 1);
pub const __XSAVES__ = @as(c_int, 1);
pub const __CLFLUSHOPT__ = @as(c_int, 1);
pub const __INVPCID__ = @as(c_int, 1);
pub const __CRC32__ = @as(c_int, 1);
pub const __AVX2__ = @as(c_int, 1);
pub const __AVX__ = @as(c_int, 1);
pub const __SSE4_2__ = @as(c_int, 1);
pub const __SSE4_1__ = @as(c_int, 1);
pub const __SSSE3__ = @as(c_int, 1);
pub const __SSE3__ = @as(c_int, 1);
pub const __SSE2__ = @as(c_int, 1);
pub const __SSE2_MATH__ = @as(c_int, 1);
pub const __SSE__ = @as(c_int, 1);
pub const __SSE_MATH__ = @as(c_int, 1);
pub const __MMX__ = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_1 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_2 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_4 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_8 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_16 = @as(c_int, 1);
pub const __SIZEOF_FLOAT128__ = @as(c_int, 16);
pub const _WIN32 = @as(c_int, 1);
pub const _WIN64 = @as(c_int, 1);
pub const WIN32 = @as(c_int, 1);
pub const __WIN32 = @as(c_int, 1);
pub const __WIN32__ = @as(c_int, 1);
pub const WINNT = @as(c_int, 1);
pub const __WINNT = @as(c_int, 1);
pub const __WINNT__ = @as(c_int, 1);
pub const WIN64 = @as(c_int, 1);
pub const __WIN64 = @as(c_int, 1);
pub const __WIN64__ = @as(c_int, 1);
pub const __MINGW64__ = @as(c_int, 1);
pub const __MSVCRT__ = @as(c_int, 1);
pub const __MINGW32__ = @as(c_int, 1);
pub const __declspec = @compileError("unable to translate C expr: unexpected token '__attribute__'");
// (no file):417:9
pub const _cdecl = @compileError("unable to translate macro: undefined identifier `__cdecl__`");
// (no file):418:9
pub const __cdecl = @compileError("unable to translate macro: undefined identifier `__cdecl__`");
// (no file):419:9
pub const _stdcall = @compileError("unable to translate macro: undefined identifier `__stdcall__`");
// (no file):420:9
pub const __stdcall = @compileError("unable to translate macro: undefined identifier `__stdcall__`");
// (no file):421:9
pub const _fastcall = @compileError("unable to translate macro: undefined identifier `__fastcall__`");
// (no file):422:9
pub const __fastcall = @compileError("unable to translate macro: undefined identifier `__fastcall__`");
// (no file):423:9
pub const _thiscall = @compileError("unable to translate macro: undefined identifier `__thiscall__`");
// (no file):424:9
pub const __thiscall = @compileError("unable to translate macro: undefined identifier `__thiscall__`");
// (no file):425:9
pub const _pascal = @compileError("unable to translate macro: undefined identifier `__pascal__`");
// (no file):426:9
pub const __pascal = @compileError("unable to translate macro: undefined identifier `__pascal__`");
// (no file):427:9
pub const __STDC__ = @as(c_int, 1);
pub const __STDC_HOSTED__ = @as(c_int, 1);
pub const __STDC_VERSION__ = @as(c_long, 201710);
pub const __STDC_UTF_16__ = @as(c_int, 1);
pub const __STDC_UTF_32__ = @as(c_int, 1);
pub const _DEBUG = @as(c_int, 1);
pub const __BB_API_H__ = "";
pub const __CLANG_STDINT_H = "";
pub const __int_least64_t = i64;
pub const __uint_least64_t = u64;
pub const __int_least32_t = i64;
pub const __uint_least32_t = u64;
pub const __int_least16_t = i64;
pub const __uint_least16_t = u64;
pub const __int_least8_t = i64;
pub const __uint_least8_t = u64;
pub const __uint32_t_defined = "";
pub const __int8_t_defined = "";
pub const __stdint_join3 = @compileError("unable to translate C expr: unexpected token '##'");
// C:\tools\zig\lib\include/stdint.h:287:9
pub const __intptr_t_defined = "";
pub const _INTPTR_T = "";
pub const _UINTPTR_T = "";
pub const __int_c_join = @compileError("unable to translate C expr: unexpected token '##'");
// C:\tools\zig\lib\include/stdint.h:324:9
pub inline fn __int_c(v: anytype, suffix: anytype) @TypeOf(__int_c_join(v, suffix)) {
    _ = &v;
    _ = &suffix;
    return __int_c_join(v, suffix);
}
pub const __uint_c = @compileError("unable to translate macro: undefined identifier `U`");
// C:\tools\zig\lib\include/stdint.h:326:9
pub const __int64_c_suffix = __INT64_C_SUFFIX__;
pub const __int32_c_suffix = __INT64_C_SUFFIX__;
pub const __int16_c_suffix = __INT64_C_SUFFIX__;
pub const __int8_c_suffix = __INT64_C_SUFFIX__;
pub inline fn INT64_C(v: anytype) @TypeOf(__int_c(v, __int64_c_suffix)) {
    _ = &v;
    return __int_c(v, __int64_c_suffix);
}
pub inline fn UINT64_C(v: anytype) @TypeOf(__uint_c(v, __int64_c_suffix)) {
    _ = &v;
    return __uint_c(v, __int64_c_suffix);
}
pub inline fn INT32_C(v: anytype) @TypeOf(__int_c(v, __int32_c_suffix)) {
    _ = &v;
    return __int_c(v, __int32_c_suffix);
}
pub inline fn UINT32_C(v: anytype) @TypeOf(__uint_c(v, __int32_c_suffix)) {
    _ = &v;
    return __uint_c(v, __int32_c_suffix);
}
pub inline fn INT16_C(v: anytype) @TypeOf(__int_c(v, __int16_c_suffix)) {
    _ = &v;
    return __int_c(v, __int16_c_suffix);
}
pub inline fn UINT16_C(v: anytype) @TypeOf(__uint_c(v, __int16_c_suffix)) {
    _ = &v;
    return __uint_c(v, __int16_c_suffix);
}
pub inline fn INT8_C(v: anytype) @TypeOf(__int_c(v, __int8_c_suffix)) {
    _ = &v;
    return __int_c(v, __int8_c_suffix);
}
pub inline fn UINT8_C(v: anytype) @TypeOf(__uint_c(v, __int8_c_suffix)) {
    _ = &v;
    return __uint_c(v, __int8_c_suffix);
}
pub const INT64_MAX = INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const INT64_MIN = -INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const UINT64_MAX = UINT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const __INT_LEAST64_MIN = INT64_MIN;
pub const __INT_LEAST64_MAX = INT64_MAX;
pub const __UINT_LEAST64_MAX = UINT64_MAX;
pub const __INT_LEAST32_MIN = INT64_MIN;
pub const __INT_LEAST32_MAX = INT64_MAX;
pub const __UINT_LEAST32_MAX = UINT64_MAX;
pub const __INT_LEAST16_MIN = INT64_MIN;
pub const __INT_LEAST16_MAX = INT64_MAX;
pub const __UINT_LEAST16_MAX = UINT64_MAX;
pub const __INT_LEAST8_MIN = INT64_MIN;
pub const __INT_LEAST8_MAX = INT64_MAX;
pub const __UINT_LEAST8_MAX = UINT64_MAX;
pub const INT_LEAST64_MIN = __INT_LEAST64_MIN;
pub const INT_LEAST64_MAX = __INT_LEAST64_MAX;
pub const UINT_LEAST64_MAX = __UINT_LEAST64_MAX;
pub const INT_FAST64_MIN = __INT_LEAST64_MIN;
pub const INT_FAST64_MAX = __INT_LEAST64_MAX;
pub const UINT_FAST64_MAX = __UINT_LEAST64_MAX;
pub const INT32_MAX = INT32_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal));
pub const INT32_MIN = -INT32_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal)) - @as(c_int, 1);
pub const UINT32_MAX = UINT32_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 4294967295, .decimal));
pub const INT_LEAST32_MIN = __INT_LEAST32_MIN;
pub const INT_LEAST32_MAX = __INT_LEAST32_MAX;
pub const UINT_LEAST32_MAX = __UINT_LEAST32_MAX;
pub const INT_FAST32_MIN = __INT_LEAST32_MIN;
pub const INT_FAST32_MAX = __INT_LEAST32_MAX;
pub const UINT_FAST32_MAX = __UINT_LEAST32_MAX;
pub const INT16_MAX = INT16_C(@as(c_int, 32767));
pub const INT16_MIN = -INT16_C(@as(c_int, 32767)) - @as(c_int, 1);
pub const UINT16_MAX = UINT16_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal));
pub const INT_LEAST16_MIN = __INT_LEAST16_MIN;
pub const INT_LEAST16_MAX = __INT_LEAST16_MAX;
pub const UINT_LEAST16_MAX = __UINT_LEAST16_MAX;
pub const INT_FAST16_MIN = __INT_LEAST16_MIN;
pub const INT_FAST16_MAX = __INT_LEAST16_MAX;
pub const UINT_FAST16_MAX = __UINT_LEAST16_MAX;
pub const INT8_MAX = INT8_C(@as(c_int, 127));
pub const INT8_MIN = -INT8_C(@as(c_int, 127)) - @as(c_int, 1);
pub const UINT8_MAX = UINT8_C(@as(c_int, 255));
pub const INT_LEAST8_MIN = __INT_LEAST8_MIN;
pub const INT_LEAST8_MAX = __INT_LEAST8_MAX;
pub const UINT_LEAST8_MAX = __UINT_LEAST8_MAX;
pub const INT_FAST8_MIN = __INT_LEAST8_MIN;
pub const INT_FAST8_MAX = __INT_LEAST8_MAX;
pub const UINT_FAST8_MAX = __UINT_LEAST8_MAX;
pub const __INTN_MIN = @compileError("unable to translate macro: undefined identifier `INT`");
// C:\tools\zig\lib\include/stdint.h:871:10
pub const __INTN_MAX = @compileError("unable to translate macro: undefined identifier `INT`");
// C:\tools\zig\lib\include/stdint.h:872:10
pub const __UINTN_MAX = @compileError("unable to translate macro: undefined identifier `UINT`");
// C:\tools\zig\lib\include/stdint.h:873:9
pub const __INTN_C = @compileError("unable to translate macro: undefined identifier `INT`");
// C:\tools\zig\lib\include/stdint.h:874:10
pub const __UINTN_C = @compileError("unable to translate macro: undefined identifier `UINT`");
// C:\tools\zig\lib\include/stdint.h:875:9
pub const INTPTR_MIN = -__INTPTR_MAX__ - @as(c_int, 1);
pub const INTPTR_MAX = __INTPTR_MAX__;
pub const UINTPTR_MAX = __UINTPTR_MAX__;
pub const PTRDIFF_MIN = -__PTRDIFF_MAX__ - @as(c_int, 1);
pub const PTRDIFF_MAX = __PTRDIFF_MAX__;
pub const SIZE_MAX = __SIZE_MAX__;
pub const INTMAX_MIN = -__INTMAX_MAX__ - @as(c_int, 1);
pub const INTMAX_MAX = __INTMAX_MAX__;
pub const UINTMAX_MAX = __UINTMAX_MAX__;
pub const SIG_ATOMIC_MIN = __INTN_MIN(__SIG_ATOMIC_WIDTH__);
pub const SIG_ATOMIC_MAX = __INTN_MAX(__SIG_ATOMIC_WIDTH__);
pub const WINT_MIN = __UINTN_C(__WINT_WIDTH__, @as(c_int, 0));
pub const WINT_MAX = __UINTN_MAX(__WINT_WIDTH__);
pub const WCHAR_MAX = __WCHAR_MAX__;
pub const WCHAR_MIN = __UINTN_C(__WCHAR_WIDTH__, @as(c_int, 0));
pub inline fn INTMAX_C(v: anytype) @TypeOf(__int_c(v, __INTMAX_C_SUFFIX__)) {
    _ = &v;
    return __int_c(v, __INTMAX_C_SUFFIX__);
}
pub inline fn UINTMAX_C(v: anytype) @TypeOf(__int_c(v, __UINTMAX_C_SUFFIX__)) {
    _ = &v;
    return __int_c(v, __UINTMAX_C_SUFFIX__);
}
pub const __BB_CONFIG_H__ = "";
pub const BB_CONFIG_FPGA_TEST_MODE = @as(c_int, 0);
pub const BB_CONFIG_DEBUG_BUILD = @as(c_int, 1);
pub const BB_CONFIG_PSRAM_ENABLE = @as(c_int, 1);
pub const BB_CONFIG_MRC_ENABLE = @as(c_int, 1);
pub const BB_CONFIG_MAX_TRANSPORT_PER_SLOT = @as(c_int, 4);
pub const BB_CONFIG_MAX_INTERNAL_MSG_SIZE = @as(c_int, 128);
pub const BB_CONFIG_MAX_TX_NODE_NUM = @as(c_int, 10);
pub const BB_CONFIG_MAC_RX_BUF_SIZE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 60000, .decimal);
pub const BB_CONFIG_MAC_TX_BUF_SIZE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 40000, .decimal);
pub const BB_CONFIG_MAX_USER_MCS_NUM = @as(c_int, 16);
pub const BB_CONFIG_MAX_CHAN_NUM = @as(c_int, 32);
pub const BB_CONFIG_MAX_CHAN_HOP_ITEM_NUM = @as(c_int, 5);
pub const BB_CONFIG_MAX_SLOT_CANDIDATE = @as(c_int, 5);
pub const BB_CONFIG_BR_FREQ_OFFSET = @as(c_int, 0);
pub const BB_CONFIG_LINK_UNLOCK_TIMEOUT = @as(c_int, 1000);
pub const BB_CONFIG_SLOT_UNLOCK_TIMEOUT = @as(c_int, 1000);
pub const BB_CONFIG_IDLE_SLOT_THRED = @as(c_int, 10);
pub const BB_CONFIG_EOP_SAMPLE_NUM = @as(c_int, 8);
pub const BB_CONFIG_ENABLE_BR_MCS = @as(c_int, 1);
pub const BB_CONFIG_ENABLE_BLOCK_SWITCH = @as(c_int, 1);
pub const BB_CONFIG_1V1_DEV_CTRL_BR_CHAN = @as(c_int, 1);
pub const BB_CONFIG_1V1_COMPT_BR = @as(c_int, 1);
pub const BB_CONFIG_ENABLE_LTP = @as(c_int, 1);
pub const BB_CONFIG_ENABLE_TIME_DISPATCH = @as(c_int, 1);
pub const BB_CONFIG_ENABLE_FRAME_CHANGE = @as(c_int, 1);
pub const BB_CONFIG_ENABLE_RC_HOP_POLICY = @as(c_int, 1);
pub const BB_CONFIG_ENABLE_AUTO_BAND_POLICY = @as(c_int, 0);
pub const BB_CONFIG_ENABLE_1V1_POWER_SAVE = @as(c_int, 1);
pub const BB_CONFIG_DEMO_STREAM = @as(c_int, 0);
pub const BB_CONFIG_OLD_PLOT_MODE = @as(c_int, 0);
pub const BB_CONFIG_FRAME_CROPPING = @as(c_int, 1);
pub const BB_CONFIG_LINK_BY_GROUPID = @as(c_int, 0);
pub const BB_CONFIG_ENABLE_RF_FILTER_PATCH = @as(c_int, 0);
pub const BB_CONFIG_INCLUDE_D_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_M_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_BI_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_MT_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_CL_CMD = @as(c_int, 0);
pub const BB_CONFIG_INCLUDE_BL_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_FRAME_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_FREQ_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_IRQ_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_CHAN_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_MCS_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_SWITCH_CMD = @as(c_int, 0);
pub const BB_CONFIG_INCLUDE_CFG_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_EOP_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_SLEEP_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_ECHO_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_DISTC_CMD = @as(c_int, 1);
pub const BB_CONFIG_INCLUDE_BR_CMD = @as(c_int, 0);
pub const BB_CONFIG_INCLUDE_CI_CMD = @as(c_int, 0);
pub const BB_CONFIG_INCLUDE_RT_CMD = @as(c_int, 1);
pub const BB_CONFIG_SO_BUFFER_CNT = @as(c_int, 16);
pub const BB_PORT_DEFAULT = @import("std").zig.c_translation.promoteIntLiteral(c_int, 50000, .decimal);
pub const AR8030_API = @compileError("unable to translate macro: undefined identifier `dllexport`");
// .\inc\bb_api.h:20:9
pub const BB_MAC_LEN = @as(c_int, 4);
pub const BB_REG_PAGE_NUM = @as(c_int, 16);
pub const BB_REG_PAGE_SIZE = @as(c_int, 256);
pub const BB_CFG_PAGE_SIZE = @as(c_int, 1024);
pub const BB_PLOT_POINT_MAX = @as(c_int, 10);
pub const BB_BLACK_LIST_SIZE = @as(c_int, 3);
pub const BB_RC_FREQ_NUM = @as(c_int, 4);
pub const BB_SOCK_FLAG_RX = @as(c_int, 1) << @as(c_int, 0);
pub const BB_SOCK_FLAG_TX = @as(c_int, 1) << @as(c_int, 1);
pub const BB_SOCK_FLAG_TROC = @as(c_int, 1) << @as(c_int, 2);
pub const BB_SOCK_FLAG_DATAGRAM = @as(c_int, 1) << @as(c_int, 3);
pub const BB_CHAN_HOP_AUTO = @as(c_int, 1) << @as(c_int, 0);
pub const BB_CHAN_BAND_HOP_AUTO = @as(c_int, 1) << @as(c_int, 1);
pub const BB_CHAN_COMPLIANCE = @as(c_int, 1) << @as(c_int, 2);
pub const BB_CHAN_MULTI_MODE = @as(c_int, 1) << @as(c_int, 3);
pub const BB_CHAN_SUBCHAN_ENABLE = @as(c_int, 1) << @as(c_int, 4);
pub const BB_MCS_SWITCH_ENABLE = @as(c_int, 1) << @as(c_int, 0);
pub const BB_MCS_SWITCH_AUTO = @as(c_int, 1) << @as(c_int, 1);
pub const BB_REQ_CFG = @as(c_int, 0);
pub const BB_REQ_GET = @as(c_int, 1);
pub const BB_REQ_SET = @as(c_int, 2);
pub const BB_REQ_CB = @as(c_int, 3);
pub const BB_REQ_SOCKET = @as(c_int, 4);
pub const BB_REQ_DBG = @as(c_int, 5);
pub const BB_REQ_RPC = @as(c_int, 10);
pub const BB_REQ_RPC_IOCTL = @as(c_int, 11);
pub const BB_REQ_PLAT_CTL = @as(c_int, 12);
pub inline fn BB_REQUEST(@"type": anytype, order: anytype) @TypeOf((@"type" << @as(c_int, 24)) | order) {
    _ = &@"type";
    _ = &order;
    return (@"type" << @as(c_int, 24)) | order;
}
pub inline fn BB_REQUEST_TYPE(req: anytype) @TypeOf(req >> @as(c_int, 24)) {
    _ = &req;
    return req >> @as(c_int, 24);
}
pub const BB_CFG_AP_BASIC = BB_REQUEST(BB_REQ_CFG, @as(c_int, 0));
pub const BB_CFG_DEV_BASIC = BB_REQUEST(BB_REQ_CFG, @as(c_int, 1));
pub const BB_CFG_CHANNEL = BB_REQUEST(BB_REQ_CFG, @as(c_int, 2));
pub const BB_CFG_CANDIDATES = BB_REQUEST(BB_REQ_CFG, @as(c_int, 3));
pub const BB_CFG_USER_PARA = BB_REQUEST(BB_REQ_CFG, @as(c_int, 4));
pub const BB_CFG_SLOT_RX_MCS = BB_REQUEST(BB_REQ_CFG, @as(c_int, 5));
pub const BB_CFG_ANY_CHANNEL = BB_REQUEST(BB_REQ_CFG, @as(c_int, 6));
pub const BB_CFG_DISTC = BB_REQUEST(BB_REQ_CFG, @as(c_int, 7));
pub const BB_CFG_AP_SYNC_MODE = BB_REQUEST(BB_REQ_CFG, @as(c_int, 9));
pub const BB_CFG_BR_HOP_POLICY = BB_REQUEST(BB_REQ_CFG, @as(c_int, 10));
pub const BB_CFG_PWR_BASIC = BB_REQUEST(BB_REQ_CFG, @as(c_int, 11));
pub const BB_CFG_RC_HOP_POLICY = BB_REQUEST(BB_REQ_CFG, @as(c_int, 12));
pub const BB_CFG_POWER_SAVE = BB_REQUEST(BB_REQ_CFG, @as(c_int, 13));
pub const BB_GET_STATUS = BB_REQUEST(BB_REQ_GET, @as(c_int, 0));
pub const BB_GET_PAIR_RESULT = BB_REQUEST(BB_REQ_GET, @as(c_int, 1));
pub const BB_GET_AP_MAC = BB_REQUEST(BB_REQ_GET, @as(c_int, 2));
pub const BB_GET_CANDIDATES = BB_REQUEST(BB_REQ_GET, @as(c_int, 3));
pub const BB_GET_USER_QUALITY = BB_REQUEST(BB_REQ_GET, @as(c_int, 4));
pub const BB_GET_DISTC_RESULT = BB_REQUEST(BB_REQ_GET, @as(c_int, 5));
pub const BB_GET_MCS = BB_REQUEST(BB_REQ_GET, @as(c_int, 6));
pub const BB_GET_POWER_MODE = BB_REQUEST(BB_REQ_GET, @as(c_int, 7));
pub const BB_GET_CUR_POWER = BB_REQUEST(BB_REQ_GET, @as(c_int, 8));
pub const BB_GET_POWER_AUTO = BB_REQUEST(BB_REQ_GET, @as(c_int, 9));
pub const BB_GET_CHAN_INFO = BB_REQUEST(BB_REQ_GET, @as(c_int, 10));
pub const BB_GET_PEER_QUALITY = BB_REQUEST(BB_REQ_GET, @as(c_int, 11));
pub const BB_GET_AP_TIME = BB_REQUEST(BB_REQ_GET, @as(c_int, 12));
pub const BB_GET_BAND_INFO = BB_REQUEST(BB_REQ_GET, @as(c_int, 13));
pub const BB_GET_REMOTE = BB_REQUEST(BB_REQ_GET, @as(c_int, 14));
pub const BB_GET_REG = BB_REQUEST(BB_REQ_GET, @as(c_int, 100));
pub const BB_GET_CFG = BB_REQUEST(BB_REQ_GET, @as(c_int, 101));
pub const BB_GET_DBG_MODE = BB_REQUEST(BB_REQ_GET, @as(c_int, 102));
pub const BB_GET_HARDWARE_VERSION = BB_REQUEST(BB_REQ_GET, @as(c_int, 103));
pub const BB_GET_FIRMWARE_VERSION = BB_REQUEST(BB_REQ_GET, @as(c_int, 104));
pub const BB_GET_SYS_INFO = BB_REQUEST(BB_REQ_GET, @as(c_int, 105));
pub const BB_GET_USER_INFO = BB_REQUEST(BB_REQ_GET, @as(c_int, 106));
pub const BB_GET_1V1_INFO = BB_REQUEST(BB_REQ_GET, @as(c_int, 107));
pub const BB_GET_PRJ_DISPATCH = BB_REQUEST(BB_REQ_GET, @as(c_int, 200));
pub const BB_SET_EVENT_SUBSCRIBE = BB_REQUEST(BB_REQ_SET, @as(c_int, 0));
pub const BB_SET_EVENT_UNSUBSCRIBE = BB_REQUEST(BB_REQ_SET, @as(c_int, 1));
pub const BB_SET_PAIR_MODE = BB_REQUEST(BB_REQ_SET, @as(c_int, 2));
pub const BB_SET_AP_MAC = BB_REQUEST(BB_REQ_SET, @as(c_int, 3));
pub const BB_SET_CANDIDATES = BB_REQUEST(BB_REQ_SET, @as(c_int, 4));
pub const BB_SET_CHAN_MODE = BB_REQUEST(BB_REQ_SET, @as(c_int, 5));
pub const BB_SET_CHAN = BB_REQUEST(BB_REQ_SET, @as(c_int, 6));
pub const BB_SET_POWER_MODE = BB_REQUEST(BB_REQ_SET, @as(c_int, 7));
pub const BB_SET_POWER = BB_REQUEST(BB_REQ_SET, @as(c_int, 8));
pub const BB_SET_POWER_AUTO = BB_REQUEST(BB_REQ_SET, @as(c_int, 9));
pub const BB_SET_HOT_UPGRADE_WRITE = BB_REQUEST(BB_REQ_SET, @as(c_int, 10));
pub const BB_SET_HOT_UPGRADE_CRC32 = BB_REQUEST(BB_REQ_SET, @as(c_int, 11));
pub const BB_SET_MCS_MODE = BB_REQUEST(BB_REQ_SET, @as(c_int, 12));
pub const BB_SET_MCS = BB_REQUEST(BB_REQ_SET, @as(c_int, 13));
pub const BB_SET_SYS_REBOOT = BB_REQUEST(BB_REQ_SET, @as(c_int, 14));
pub const BB_SET_MASTER_DEV = BB_REQUEST(BB_REQ_SET, @as(c_int, 15));
pub const BB_SET_FRAME_CHANGE = BB_REQUEST(BB_REQ_SET, @as(c_int, 16));
pub const BB_SET_COMPLIANCE_MODE = BB_REQUEST(BB_REQ_SET, @as(c_int, 17));
pub const BB_SET_BAND_MODE = BB_REQUEST(BB_REQ_SET, @as(c_int, 18));
pub const BB_SET_BAND = BB_REQUEST(BB_REQ_SET, @as(c_int, 19));
pub const BB_FORCE_CLS_SOCKET_ALL = BB_REQUEST(BB_REQ_SET, @as(c_int, 20));
pub const BB_SET_REMOTE = BB_REQUEST(BB_REQ_SET, @as(c_int, 21));
pub const BB_SET_BANDWIDTH = BB_REQUEST(BB_REQ_SET, @as(c_int, 22));
pub const BB_SET_DFS = BB_REQUEST(BB_REQ_SET, @as(c_int, 23));
pub const BB_SET_RF = BB_REQUEST(BB_REQ_SET, @as(c_int, 24));
pub const BB_SET_POWER_SAVE_MODE = BB_REQUEST(BB_REQ_SET, @as(c_int, 25));
pub const BB_SET_POWER_SAVE = BB_REQUEST(BB_REQ_SET, @as(c_int, 26));
pub const BB_SET_REG = BB_REQUEST(BB_REQ_SET, @as(c_int, 100));
pub const BB_SET_CFG = BB_REQUEST(BB_REQ_SET, @as(c_int, 101));
pub const BB_RESET_CFG = BB_REQUEST(BB_REQ_SET, @as(c_int, 102));
pub const BB_SET_PLOT = BB_REQUEST(BB_REQ_SET, @as(c_int, 103));
pub const BB_SET_DBG_MODE = BB_REQUEST(BB_REQ_SET, @as(c_int, 104));
pub const BB_SET_FREQ = BB_REQUEST(BB_REQ_SET, @as(c_int, 105));
pub const BB_SET_TX_MCS = BB_REQUEST(BB_REQ_SET, @as(c_int, 106));
pub const BB_SET_RESET = BB_REQUEST(BB_REQ_SET, @as(c_int, 107));
pub const BB_SET_TX_PATH = BB_REQUEST(BB_REQ_SET, @as(c_int, 108));
pub const BB_SET_RX_PATH = BB_REQUEST(BB_REQ_SET, @as(c_int, 109));
pub const BB_SET_POWER_OFFSET = BB_REQUEST(BB_REQ_SET, @as(c_int, 110));
pub const BB_SET_POWER_TEST_MODE = BB_REQUEST(BB_REQ_SET, @as(c_int, 111));
pub const BB_SET_SENSE_TEST_MODE = BB_REQUEST(BB_REQ_SET, @as(c_int, 112));
pub const BB_SET_ORIG_CFG = BB_REQUEST(BB_REQ_SET, @as(c_int, 113));
pub const BB_SET_SINGLE_TONE = BB_REQUEST(BB_REQ_SET, @as(c_int, 114));
pub const BB_SET_PURE_SLOT = BB_REQUEST(BB_REQ_SET, @as(c_int, 115));
pub const BB_SET_FACTORY_POWER_OFFSET_SAVE = BB_REQUEST(BB_REQ_SET, @as(c_int, 116));
pub const BB_SET_PRJ_DISPATCH = BB_REQUEST(BB_REQ_SET, @as(c_int, 200));
pub const BB_SET_PRJ_DISPATCH2 = BB_REQUEST(BB_REQ_SET, @as(c_int, 201));
pub const BB_START_REQ = BB_REQUEST(BB_REQ_RPC_IOCTL, @as(c_int, 0));
pub const BB_STOP_REQ = BB_REQUEST(BB_REQ_RPC_IOCTL, @as(c_int, 1));
pub const BB_INIT_REQ = BB_REQUEST(BB_REQ_RPC_IOCTL, @as(c_int, 2));
pub const BB_DEINIT_REQ = BB_REQUEST(BB_REQ_RPC_IOCTL, @as(c_int, 3));
pub const BB_RPC_GET_LIST = BB_REQUEST(BB_REQ_RPC, @as(c_int, 0));
pub const BB_RPC_SEL_ID = BB_REQUEST(BB_REQ_RPC, @as(c_int, 1));
pub const BB_RPC_GET_MAC = BB_REQUEST(BB_REQ_RPC, @as(c_int, 2));
pub const BB_RPC_GET_HOTPLUG_EVENT = BB_REQUEST(BB_REQ_RPC, @as(c_int, 3));
pub const BB_RPC_SOCK_BUF_STA = BB_REQUEST(BB_REQ_RPC, @as(c_int, 4));
pub const BB_RPC_TEST = BB_REQUEST(BB_REQ_RPC, @as(c_int, 5));
pub const BB_RPC_SERIAL_LIST = BB_REQUEST(BB_REQ_PLAT_CTL, @as(c_int, 0));
pub const BB_RPC_SERIAL_SETUP = BB_REQUEST(BB_REQ_PLAT_CTL, @as(c_int, 1));
pub const SO_USER_BASE_START = @as(c_int, 0xc0);
pub const UART_LIST_MAX = @as(c_int, 32);
pub const UART_NAME_LEN = @as(c_int, 24);
pub const ctl_opt = enum_ctl_opt;
