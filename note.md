# Note

random interesting stuff

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

## message table

See `bb_api.h` and `ioctl_tab.c`

```c
/**
 * @brief 控制命令对照表
 *
 */
static const BBIOCTL_TAB cmdtab[] = {
  // conf
    {BB_CFG_CHANNEL,            sizeof(bb_conf_chan_t),                0                                     },

 // get
    { BB_GET_STATUS,            sizeof(bb_get_status_in_t),            sizeof(bb_get_status_out_t)           },
    { BB_GET_PAIR_RESULT,       0,                                     sizeof(bb_get_pair_out_t)             },
    { BB_GET_AP_MAC,            0,                                     sizeof(bb_get_ap_mac_out_t)           },
    { BB_GET_CANDIDATES,        sizeof(bb_get_candidates_in_t),        sizeof(bb_get_candidates_out_t)       },
    { BB_GET_USER_QUALITY,      sizeof(bb_get_user_quality_in_t),      sizeof(bb_get_user_quality_out_t)     },
    { BB_GET_DISTC_RESULT,      sizeof(bb_get_distc_result_in_t),      sizeof(bb_get_distc_result_out_t)     },
    { BB_GET_PEER_QUALITY,      sizeof(bb_get_peer_quality_in_t),      sizeof(bb_get_peer_quality_out_t)     },
    { BB_GET_AP_TIME,           0,                                     sizeof(bb_get_ap_time_out_t)          },
    { BB_GET_MCS,               sizeof(bb_get_mcs_in_t),               sizeof(bb_get_mcs_out_t)              },
    { BB_GET_CHAN_INFO,         0,                                     sizeof(bb_get_chan_info_out_t)        },
    { BB_GET_REG,               sizeof(bb_get_reg_in_t),               sizeof(bb_get_reg_out_t)              },
    { BB_GET_CFG,               sizeof(bb_get_cfg_in_t),               sizeof(bb_get_cfg_out_t)              },
    { BB_GET_DBG_MODE,          0,                                     sizeof(bb_get_dbg_mode_out_t)         },
    { BB_GET_POWER_MODE,        0,                                     sizeof(bb_get_pwr_mode_out_t)         },
    { BB_GET_CUR_POWER,         sizeof(bb_get_cur_pwr_in_t),           sizeof(bb_get_cur_pwr_out_t)          },
    { BB_GET_POWER_AUTO,        0,                                     sizeof(bb_get_pwr_auto_out_t)         },
    { BB_GET_SYS_INFO,          0,                                     sizeof(bb_get_sys_info_out_t)         },
    { BB_GET_PRJ_DISPATCH,      sizeof(bb_get_prj_dispatch_in_t),      sizeof(bb_get_prj_dispatch_out_t)     },
    { BB_GET_BAND_INFO,         sizeof(bb_get_band_info_in_t),         sizeof(bb_get_band_info_out_t)        },
    { BB_GET_USER_INFO,         sizeof(bb_get_user_info_in_t),         sizeof(bb_get_user_info_out_t)        },
    { BB_GET_REMOTE,            sizeof(bb_get_remote_in_t),            sizeof(bb_get_remote_out_t)           },
    { BB_GET_1V1_INFO,          sizeof(bb_get_1v1_info_in_t),          sizeof(bb_get_1v1_info_out_t)         },

 // set
    { BB_SET_PAIR_MODE,         sizeof(bb_set_pair_mode_t),            0                                     },
    { BB_SET_AP_MAC,            sizeof(bb_set_ap_mac_t),               0                                     },
    { BB_SET_CANDIDATES,        sizeof(bb_set_candidate_t),            0                                     },
    { BB_SET_CHAN_MODE,         sizeof(bb_set_chan_mode_t),            0                                     },
    { BB_SET_CHAN,              sizeof(bb_set_chan_t),                 0                                     },
    { BB_SET_MCS_MODE,          sizeof(bb_set_mcs_mode_t),             0                                     },
    { BB_SET_MCS,               sizeof(bb_set_mcs_t),                  0                                     },
    { BB_SET_REG,               sizeof(bb_set_reg_t),                  0                                     },
    { BB_SET_CFG,               sizeof(bb_set_cfg_t),                  0                                     },
    { BB_RESET_CFG,             0,                                     0                                     },
    { BB_SET_PLOT,              sizeof(bb_set_plot_t),                 0                                     },
    { BB_SET_DBG_MODE,          sizeof(bb_set_dbg_mode_t),             0                                     },
    { BB_SET_POWER_MODE,        sizeof(bb_set_pwr_mode_in_t),          0                                     },
    { BB_SET_POWER,             sizeof(bb_set_pwr_in_t),               0                                     },
    { BB_SET_POWER_AUTO,        sizeof(bb_set_pwr_auto_in_t),          0                                     },
    { BB_SET_FREQ,              sizeof(bb_set_freq_t),                 0                                     },
    { BB_SET_TX_MCS,            sizeof(bb_set_tx_mcs_t),               0                                     },
    { BB_SET_RESET,             sizeof(bb_set_reset_t),                0                                     },
    { BB_SET_POWER_OFFSET,      sizeof(bb_set_power_offset_t),         0                                     },
    { BB_SET_HOT_UPGRADE_WRITE, sizeof(bb_set_hot_upgrade_write_in_t), sizeof(bb_set_hot_upgrade_write_out_t)},
    { BB_SET_HOT_UPGRADE_CRC32, sizeof(bb_set_hot_upgrade_crc32_in_t), sizeof(bb_set_hot_upgrade_crc32_out_t)},
    { BB_SET_TX_PATH,           sizeof(bb_set_tx_path_t),              0                                     },
    { BB_SET_RX_PATH,           sizeof(bb_set_rx_path_t),              0                                     },
    { BB_SET_POWER_TEST_MODE,   0,                                     0                                     },
    { BB_SET_SENSE_TEST_MODE,   0,                                     0                                     },
    { BB_SET_SINGLE_TONE,       0,                                     0                                     },
    { BB_SET_PURE_SLOT,         0,                                     0                                     },
    { BB_SET_PRJ_DISPATCH,      sizeof(bb_set_prj_dispatch_in_t),      0                                     },
    { BB_SET_PRJ_DISPATCH2,     sizeof(bb_set_prj_dispatch2_in_t),     0                                     },
    { BB_SET_SYS_REBOOT,        sizeof(uint32_t),                      0                                     },
    { BB_SET_MASTER_DEV,        sizeof(bb_set_master_dev_t),           0                                     },
    { BB_SET_FRAME_CHANGE,      sizeof(bb_set_frame_change_t),         0                                     },
    { BB_SET_COMPLIANCE_MODE,   sizeof(bb_set_compliance_mode_t),      0                                     },
    { BB_SET_BAND_MODE,         sizeof(bb_set_band_mode_t),            0                                     },
    { BB_SET_BAND,              sizeof(bb_set_band_t),                 0,                                    },
    { BB_FORCE_CLS_SOCKET_ALL,  0,                                     0                                     },
    { BB_SET_REMOTE,            sizeof(bb_set_remote_t),               0                                     },
    { BB_SET_BANDWIDTH,         sizeof(bb_set_bandwidth_t),            0                                     },
    { BB_SET_DFS,               sizeof(bb_set_dfs_t),                  0                                     },
    { BB_SET_RF,                sizeof(bb_set_rf_t),                   0                                     },
    { BB_SET_POWER_SAVE_MODE,   sizeof(bb_set_power_save_mode_t),      0                                     },
    { BB_SET_POWER_SAVE,        sizeof(bb_set_power_save_t),           0                                     },

 // inner ioctl
    { BB_START_REQ,             0,                                     0                                     },
    { BB_STOP_REQ,              0,                                     0                                     },
    { BB_INIT_REQ,              0,                                     0                                     },
    { BB_DEINIT_REQ,            0,                                     0                                     },

 // rpc
    { BB_RPC_SOCK_BUF_STA,      sizeof(QUERY_TX_IN),                   sizeof(QUERY_TX_OUT)                  },
};

/**
 * @brief callback 数据长度表
 *
 */
static const BBCB_TAB cbtab[] = {
    { BB_EVENT_LINK_STATE       ,   sizeof(bb_event_link_state_t    )   },
    { BB_EVENT_MCS_CHANGE       ,   sizeof(bb_event_mcs_change_t    )   },
    { BB_EVENT_MCS_CHANGE_END   ,   sizeof(bb_event_mcs_change_end_t)   },
    { BB_EVENT_CHAN_CHANGE      ,   sizeof(bb_event_chan_change_t   )   },
    { BB_EVENT_PLOT_DATA        ,   sizeof(bb_event_plot_data_t     )   },
    { BB_EVENT_PRJ_DISPATCH     ,   sizeof(bb_event_prj_dispatch_t  )   },
    { BB_EVENT_PAIR_RESULT      ,   sizeof(bb_event_pair_result_t   )   },
    { BB_EVENT_PRJ_DISPATCH2    ,   sizeof(bb_event_prj_dispatch2_t )   },
};
```
