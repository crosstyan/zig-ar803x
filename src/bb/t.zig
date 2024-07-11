const std = @import("std");
const bb = @import("c.zig");
const logz = @import("logz");

pub const SUBSCRIBE_REQ = 1;
pub const SUBSCRIBE_REQ_RET = 2;
pub const SUBSCRIBE_DAT_RET = 3;
pub const SUBSCRIBE_REQ_FAL = 4;

pub const Event = enum {
    link_state,
    mcs_change,
    chan_change,
    plot_data,
    frame_start,
    offline,
    prj_dispatch,
    pair_result,
    prj_dispatch_2,
    mcs_change_end,

    pub fn toC(event: Event) u8 {
        const ev: c_int = switch (event) {
            .link_state => bb.BB_EVENT_LINK_STATE,
            .mcs_change => bb.BB_EVENT_MCS_CHANGE,
            .chan_change => bb.BB_EVENT_CHAN_CHANGE,
            .plot_data => bb.BB_EVENT_PLOT_DATA,
            .frame_start => bb.BB_EVENT_FRAME_START,
            .offline => bb.BB_EVENT_OFFLINE,
            .prj_dispatch => bb.BB_EVENT_PRJ_DISPATCH,
            .pair_result => bb.BB_EVENT_PAIR_RESULT,
            .prj_dispatch_2 => bb.BB_EVENT_PRJ_DISPATCH2,
            .mcs_change_end => bb.BB_EVENT_MCS_CHANGE_END,
        };
        return @intCast(ev);
    }

    pub fn fromC(event: c_int) Event {
        switch (event) {
            bb.BB_EVENT_LINK_STATE => return Event.link_state,
            bb.BB_EVENT_MCS_CHANGE => return Event.mcs_change,
            bb.BB_EVENT_CHAN_CHANGE => return Event.chan_change,
            bb.BB_EVENT_PLOT_DATA => return Event.plot_data,
            bb.BB_EVENT_FRAME_START => return Event.frame_start,
            bb.BB_EVENT_OFFLINE => return Event.offline,
            bb.BB_EVENT_PRJ_DISPATCH => return Event.prj_dispatch,
            bb.BB_EVENT_PAIR_RESULT => return Event.pair_result,
            bb.BB_EVENT_PRJ_DISPATCH2 => return Event.prj_dispatch_2,
            bb.BB_EVENT_MCS_CHANGE_END => return Event.mcs_change_end,
            else => std.debug.panic("unknown C enum for `bb_event_e` {}", .{event}),
        }
    }
};

pub const SoCmdOpt = enum {
    open,
    write,
    read,
    close,

    pub fn toByte(soCmd: SoCmdOpt) u8 {
        const cmd: u8 = switch (soCmd) {
            .open => 0,
            .write => 1,
            .read => 2,
            .close => 3,
        };
        return @intCast(cmd);
    }

    pub fn fromByte(cmd: u8) SoCmdOpt {
        switch (cmd) {
            0 => return SoCmdOpt.open,
            1 => return SoCmdOpt.write,
            2 => return SoCmdOpt.read,
            3 => return SoCmdOpt.close,
            else => std.debug.panic("unknown C enum for `so_cmd_opt` {}", .{cmd}),
        }
    }
};

/// see `BB_EVENT_*` constants
pub fn subscribeRequestId(event: Event) u32 {
    return @as(u32, bb.BB_REQ_CB) << 24 | @as(u32, SUBSCRIBE_REQ) << 16 | @as(u32, event.toC());
}

/// see `dev_dat_so_write_proc`
pub fn socketRequestId(soCmd: SoCmdOpt, slot: u8, port: u8) u32 {
    std.debug.assert(slot < bb.BB_SLOT_MAX);
    std.debug.assert(port < bb.BB_CONFIG_MAX_TRANSPORT_PER_SLOT);
    // https://github.com/ziglang/zig/issues/7605
    // needs explicit cast
    // wait for upstream to fix
    return @as(u32, 4) << @as(u32, 24) | @as(u32, soCmd.toByte()) << @as(u32, 16) | @as(u32, slot) << @intCast(8) | @as(u32, port);
}

const Role = enum {
    ap,
    dev,

    pub fn toC(role: Role) u8 {
        const r: c_int = switch (role) {
            .ap => bb.BB_ROLE_AP,
            .dev => bb.BB_ROLE_DEV,
        };
        return @intCast(r);
    }

    pub fn fromC(role: c_int) Role {
        switch (role) {
            bb.BB_ROLE_AP => return Role.ap,
            bb.BB_ROLE_DEV => return Role.dev,
            else => std.debug.panic("unknown C enum for `bb_role_e` {}", .{role}),
        }
    }
};

const Mode = enum {
    single_user,
    multi_user,
    relay,
    /// 导演模式, 一对多可靠广播模式, 不支持MCS负数
    director,

    pub fn toC(mode: Mode) u8 {
        const m: c_int = switch (mode) {
            .single_user => bb.BB_MODE_SINGLE_USER,
            .multi_user => bb.BB_MODE_MULTI_USER,
            .relay => bb.BB_MODE_RELAY,
            .director => bb.BB_MODE_DIRECTOR,
        };
        return @intCast(m);
    }

    pub fn fromC(mode: c_int) Mode {
        switch (mode) {
            bb.BB_MODE_SINGLE_USER => return Mode.single_user,
            bb.BB_MODE_MULTI_USER => return Mode.multi_user,
            bb.BB_MODE_RELAY => return Mode.relay,
            bb.BB_MODE_DIRECTOR => return Mode.director,
            else => std.debug.panic("unknown C enum for `bb_mode_e` {}", .{mode}),
        }
    }
};

const PhyMcs = enum {
    neg_2, // BPSK   CR_1/2 REP_4 single stream
    neg_1, // BPSK   CR_1/2 REP_2 single stream
    mcs_0, // BPSK   CR_1/2 REP_1 single stream
    mcs_1, // BPSK   CR_2/3 REP_1 single stream
    mcs_2, // BPSK   CR_3/4 REP_1 single stream
    mcs_3, // QPSK   CR_1/2 REP_1 single stream
    mcs_4, // QPSK   CR_2/3 REP_1 single stream
    mcs_5, // QPSK   CR_3/4 REP_1 single stream
    mcs_6, // 16QAM  CR_1/2 REP_1 single stream
    mcs_7, // 16QAM  CR_2/3 REP_1 single stream
    mcs_8, // 16QAM  CR_3/4 REP_1 single stream
    mcs_9, // 64QAM  CR_1/2 REP_1 single stream
    mcs_10, // 64QAM  CR_2/3 REP_1 single stream
    mcs_11, // 64QAM  CR_3/4 REP_1 single stream
    mcs_12, // 256QAM CR_1/2 REP_1 single stream
    mcs_13, // 256QAM CR_2/3 REP_1 single stream
    mcs_14, // QPSK   CR_1/2 REP_1 dual stream
    mcs_15, // QPSK   CR_2/3 REP_1 dual stream
    mcs_16, // QPSK   CR_3/4 REP_1 dual stream
    mcs_17, // 16QAM  CR_1/2 REP_1 dual stream
    mcs_18, // 16QAM  CR_2/3 REP_1 dual stream
    mcs_19, // 16QAM  CR_3/4 REP_1 dual stream
    mcs_20, // 64QAM  CR_1/2 REP_1 dual stream
    mcs_21, // 64QAM  CR_2/3 REP_1 dual stream
    mcs_22, // 64QAM  CR_3/4 REP_1 dual stream
    invalid,

    pub fn toC(mcs: PhyMcs) u8 {
        const m: c_int = switch (mcs) {
            .neg_2 => bb.BB_PHY_MCS_NEG_2,
            .neg_1 => bb.BB_PHY_MCS_NEG_1,
            .mcs_0 => bb.BB_PHY_MCS_0,
            .mcs_1 => bb.BB_PHY_MCS_1,
            .mcs_2 => bb.BB_PHY_MCS_2,
            .mcs_3 => bb.BB_PHY_MCS_3,
            .mcs_4 => bb.BB_PHY_MCS_4,
            .mcs_5 => bb.BB_PHY_MCS_5,
            .mcs_6 => bb.BB_PHY_MCS_6,
            .mcs_7 => bb.BB_PHY_MCS_7,
            .mcs_8 => bb.BB_PHY_MCS_8,
            .mcs_9 => bb.BB_PHY_MCS_9,
            .mcs_10 => bb.BB_PHY_MCS_10,
            .mcs_11 => bb.BB_PHY_MCS_11,
            .mcs_12 => bb.BB_PHY_MCS_12,
            .mcs_13 => bb.BB_PHY_MCS_13,
            .mcs_14 => bb.BB_PHY_MCS_14,
            .mcs_15 => bb.BB_PHY_MCS_15,
            .mcs_16 => bb.BB_PHY_MCS_16,
            .mcs_17 => bb.BB_PHY_MCS_17,
            .mcs_18 => bb.BB_PHY_MCS_18,
            .mcs_19 => bb.BB_PHY_MCS_19,
            .mcs_20 => bb.BB_PHY_MCS_20,
            .mcs_21 => bb.BB_PHY_MCS_21,
            .mcs_22 => bb.BB_PHY_MCS_22,
        };
        return @intCast(m);
    }

    pub fn fromC(mcs: c_int) PhyMcs {
        return switch (mcs) {
            bb.BB_PHY_MCS_NEG_2 => .neg_2,
            bb.BB_PHY_MCS_NEG_1 => .neg_1,
            bb.BB_PHY_MCS_0 => .mcs_0,
            bb.BB_PHY_MCS_1 => .mcs_1,
            bb.BB_PHY_MCS_2 => .mcs_2,
            bb.BB_PHY_MCS_3 => .mcs_3,
            bb.BB_PHY_MCS_4 => .mcs_4,
            bb.BB_PHY_MCS_5 => .mcs_5,
            bb.BB_PHY_MCS_6 => .mcs_6,
            bb.BB_PHY_MCS_7 => .mcs_7,
            bb.BB_PHY_MCS_8 => .mcs_8,
            bb.BB_PHY_MCS_9 => .mcs_9,
            bb.BB_PHY_MCS_10 => .mcs_10,
            bb.BB_PHY_MCS_11 => .mcs_11,
            bb.BB_PHY_MCS_12 => .mcs_12,
            bb.BB_PHY_MCS_13 => .mcs_13,
            bb.BB_PHY_MCS_14 => .mcs_14,
            bb.BB_PHY_MCS_15 => .mcs_15,
            bb.BB_PHY_MCS_16 => .mcs_16,
            bb.BB_PHY_MCS_17 => .mcs_17,
            bb.BB_PHY_MCS_18 => .mcs_18,
            bb.BB_PHY_MCS_19 => .mcs_19,
            bb.BB_PHY_MCS_20 => .mcs_20,
            bb.BB_PHY_MCS_21 => .mcs_21,
            bb.BB_PHY_MCS_22 => .mcs_22,
            else => .invalid,
        };
    }
};

const SlotMode = enum {
    fixed,
    dynamic,

    pub fn toC(mode: SlotMode) u8 {
        const m: c_int = switch (mode) {
            .fixed => bb.BB_SLOT_MODE_FIXED,
            .dynamic => bb.BB_SLOT_MODE_DYNAMIC,
        };
        return @intCast(m);
    }

    pub fn fromC(mode: c_int) SlotMode {
        switch (mode) {
            bb.BB_SLOT_MODE_FIXED => return SlotMode.fixed,
            bb.BB_SLOT_MODE_DYNAMIC => return SlotMode.dynamic,
            else => std.debug.panic("unknown C enum for `bb_slot_mode_e` {}", .{mode}),
        }
    }
};

const LinkState = enum {
    idle,
    lock,
    connect,

    pub fn toC(state: LinkState) u8 {
        const s: c_int = switch (state) {
            .idle => bb.BB_LINK_STATE_IDLE,
            .lock => bb.BB_LINK_STATE_LOCK,
            .connect => bb.BB_LINK_STATE_CONNECT,
        };
        return @intCast(s);
    }

    pub fn fromC(state: c_int) LinkState {
        switch (state) {
            bb.BB_LINK_STATE_IDLE => return LinkState.idle,
            bb.BB_LINK_STATE_LOCK => return LinkState.lock,
            bb.BB_LINK_STATE_CONNECT => return LinkState.connect,
            else => std.debug.panic("unknown C enum for `bb_link_state_e` {}", .{state}),
        }
    }
};

const Band = enum {
    band_1g,
    band_2g,
    band_5g,

    pub fn toC(band: Band) u8 {
        const b: c_int = switch (band) {
            .band_1g => bb.BB_BAND_1G,
            .band_2g => bb.BB_BAND_2G,
            .band_5g => bb.BB_BAND_5G,
        };
        return @intCast(b);
    }

    pub fn fromC(band: c_int) Band {
        switch (band) {
            bb.BB_BAND_1G => return Band.band_1g,
            bb.BB_BAND_2G => return Band.band_2g,
            bb.BB_BAND_5G => return Band.band_5g,
            else => std.debug.panic("unknown C enum for `bb_band_e` {}", .{band}),
        }
    }
};

const RFPath = enum {
    path_a,
    path_b,

    pub fn toC(path: RFPath) u8 {
        const p: c_int = switch (path) {
            .path_a => bb.BB_RF_PATH_A,
            .path_b => bb.BB_RF_PATH_B,
        };
        return @intCast(p);
    }

    pub fn fromC(path: c_int) RFPath {
        switch (path) {
            bb.BB_RF_PATH_A => return RFPath.path_a,
            bb.BB_RF_PATH_B => return RFPath.path_b,
            else => std.debug.panic("unknown C enum for `bb_rf_path_e` {}", .{path}),
        }
    }
};

const BandMode = enum {
    single,
    band_2g_5g,
    band_1g_2g,
    band_1g_5g,

    pub fn toC(mode: BandMode) u8 {
        const m: c_int = switch (mode) {
            .single => bb.BB_BAND_MODE_SINGLE,
            .band_2g_5g => bb.BB_BAND_MODE_2G_5G,
            .band_1g_2g => bb.BB_BAND_MODE_1G_2G,
            .band_1g_5g => bb.BB_BAND_MODE_1G_5G,
        };
        return @intCast(m);
    }

    pub fn fromC(mode: c_int) BandMode {
        switch (mode) {
            bb.BB_BAND_MODE_SINGLE => return BandMode.single,
            bb.BB_BAND_MODE_2G_5G => return BandMode.band_2g_5g,
            bb.BB_BAND_MODE_1G_2G => return BandMode.band_1g_2g,
            bb.BB_BAND_MODE_1G_5G => return BandMode.band_1g_5g,
            else => std.debug.panic("unknown C enum for `bb_band_mode_e` {}", .{mode}),
        }
    }
};

const Bandwidth = enum {
    bw_1_25m,
    bw_2_5m,
    bw_5m,
    bw_10m,
    bw_20m,
    bw_40m,

    pub fn toC(bw: Bandwidth) u8 {
        const b: c_int = switch (bw) {
            .bw_1_25m => bb.BB_BW_1_25M,
            .bw_2_5m => bb.BB_BW_2_5M,
            .bw_5m => bb.BB_BW_5M,
            .bw_10m => bb.BB_BW_10M,
            .bw_20m => bb.BB_BW_20M,
            .bw_40m => bb.BB_BW_40M,
        };
        return @intCast(b);
    }

    pub fn fromC(bw: c_int) Bandwidth {
        switch (bw) {
            bb.BB_BW_1_25M => return Bandwidth.bw_1_25m,
            bb.BB_BW_2_5M => return Bandwidth.bw_2_5m,
            bb.BB_BW_5M => return Bandwidth.bw_5m,
            bb.BB_BW_10M => return Bandwidth.bw_10m,
            bb.BB_BW_20M => return Bandwidth.bw_20m,
            bb.BB_BW_40M => return Bandwidth.bw_40m,
            else => std.debug.panic("unknown C enum for `bb_bandwidth_e` {}", .{bw}),
        }
    }
};

const TimeIntlvLen = enum {
    len_3,
    len_6,
    len_12,
    len_24,
    len_48,

    pub fn toC(len: TimeIntlvLen) u8 {
        const l: c_int = switch (len) {
            .len_3 => bb.BB_TIMEINTLV_LEN_3,
            .len_6 => bb.BB_TIMEINTLV_LEN_6,
            .len_12 => bb.BB_TIMEINTLV_LEN_12,
            .len_24 => bb.BB_TIMEINTLV_LEN_24,
            .len_48 => bb.BB_TIMEINTLV_LEN_48,
        };
        return @intCast(l);
    }

    pub fn fromC(len: c_int) TimeIntlvLen {
        switch (len) {
            bb.BB_TIMEINTLV_LEN_3 => return TimeIntlvLen.len_3,
            bb.BB_TIMEINTLV_LEN_6 => return TimeIntlvLen.len_6,
            bb.BB_TIMEINTLV_LEN_12 => return TimeIntlvLen.len_12,
            bb.BB_TIMEINTLV_LEN_24 => return TimeIntlvLen.len_24,
            bb.BB_TIMEINTLV_LEN_48 => return TimeIntlvLen.len_48,
            else => std.debug.panic("unknown C enum for `bb_timeintlv_len_e` {}", .{len}),
        }
    }
};

const TimeIntlvEnable = enum {
    off,
    on,

    pub fn toC(enable: TimeIntlvEnable) u8 {
        const e: c_int = switch (enable) {
            .off => bb.BB_TIMEINTLV_OFF,
            .on => bb.BB_TIMEINTLV_ON,
        };
        return @intCast(e);
    }

    pub fn fromC(enable: c_int) TimeIntlvEnable {
        switch (enable) {
            bb.BB_TIMEINTLV_OFF => return TimeIntlvEnable.off,
            bb.BB_TIMEINTLV_ON => return TimeIntlvEnable.on,
            else => std.debug.panic("unknown C enum for `bb_timeintlv_enable_e` {}", .{enable}),
        }
    }
};

const TimeIntlvNum = enum {
    block_1,
    block_2,

    pub fn toC(num: TimeIntlvNum) u8 {
        const n: c_int = switch (num) {
            .block_1 => bb.BB_TIMEINTLV_1_BLOCK,
            .block_2 => bb.BB_TIMEINTLV_2_BLOCK,
        };
        return @intCast(n);
    }

    pub fn fromC(num: c_int) TimeIntlvNum {
        switch (num) {
            bb.BB_TIMEINTLV_1_BLOCK => return TimeIntlvNum.block_1,
            bb.BB_TIMEINTLV_2_BLOCK => return TimeIntlvNum.block_2,
            else => std.debug.panic("unknown C enum for `bb_timeintlv_num_e` {}", .{num}),
        }
    }
};

pub const MacAddr = [@intCast(bb.BB_MAC_LEN)]u8;

pub fn logWithMacAddr(logger: logz.Logger, key: []const u8, mac: *const MacAddr) logz.Logger {
    if (bb.BB_MAC_LEN != 4) {
        @compileError("unmatched MAC address length");
    }
    return logger.fmt(key, "{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}", .{ mac[0], mac[1], mac[2], mac[3] });
}

pub const TxMode = enum {
    tx_1tx,
    tx_2tx_stbc,
    tx_2tx_mimo,

    pub fn toC(mode: TxMode) u8 {
        const m: c_int = switch (mode) {
            .tx_1tx => bb.BB_TX_1TX,
            .tx_2tx_stbc => bb.BB_TX_2TX_STBC,
            .tx_2tx_mimo => bb.BB_TX_2TX_MIMO,
        };
        return @intCast(m);
    }

    pub fn fromC(mode: c_int) TxMode {
        switch (mode) {
            bb.BB_TX_1TX => return TxMode.tx_1tx,
            bb.BB_TX_2TX_STBC => return TxMode.tx_2tx_stbc,
            bb.BB_TX_2TX_MIMO => return TxMode.tx_2tx_mimo,
            else => std.debug.panic("unknown C enum for `bb_tx_mode_e` {}", .{mode}),
        }
    }
};

// pub const BB_RX_1T1R: c_int = 0;
// pub const BB_RX_1T2R: c_int = 1;
// pub const BB_RX_2T2R_STBC: c_int = 2;
// pub const BB_RX_2T2R_MIMO: c_int = 3;
// pub const BB_RX_MODE_MAX: c_int = 4;
// pub const bb_rx_mode_e = c_uint;
pub const RxMode = enum {
    rx_1t1r,
    rx_1t2r,
    rx_2t2r_stbc,
    rx_2t2r_mimo,

    pub fn toC(mode: RxMode) u8 {
        const m: c_int = switch (mode) {
            .rx_1t1r => bb.BB_RX_1T1R,
            .rx_1t2r => bb.BB_RX_1T2R,
            .rx_2t2r_stbc => bb.BB_RX_2T2R_STBC,
            .rx_2t2r_mimo => bb.BB_RX_2T2R_MIMO,
        };
        return @intCast(m);
    }

    pub fn fromC(mode: c_int) RxMode {
        switch (mode) {
            bb.BB_RX_1T1R => return RxMode.rx_1t1r,
            bb.BB_RX_1T2R => return RxMode.rx_1t2r,
            bb.BB_RX_2T2R_STBC => return RxMode.rx_2t2r_stbc,
            bb.BB_RX_2T2R_MIMO => return RxMode.rx_2t2r_mimo,
            else => std.debug.panic("unknown C enum for `bb_rx_mode_e` {}", .{mode}),
        }
    }
};

const RfMode = union(enum) {
    tx: TxMode,
    rx: RxMode,
};

const PhyStatus = struct {
    mcs: PhyMcs,
    rf_mode: RfMode,
    tinvlv_enable: TimeIntlvEnable,
    tintlv_num: TimeIntlvNum,
    tintlv_len: TimeIntlvLen,
    bandwidth: Bandwidth,
    freq_hz: u32,

    const Self = @This();

    pub fn fromC(status: *const bb.bb_phy_status_t, is_tx: bool) Self {
        var rf_mode: RfMode = undefined;
        if (is_tx) {
            rf_mode = RfMode{ .tx = TxMode.fromC(@intCast(status.rf_mode)) };
        } else {
            rf_mode = RfMode{ .rx = RxMode.fromC(@intCast(status.rf_mode)) };
        }
        return Self{
            .mcs = PhyMcs.fromC(status.mcs),
            .rf_mode = rf_mode,
            .tinvlv_enable = TimeIntlvEnable.fromC(@intCast(status.tintlv_enable)),
            .tintlv_num = TimeIntlvNum.fromC(@intCast(status.tintlv_num)),
            .tintlv_len = TimeIntlvLen.fromC(@intCast(status.tintlv_len)),
            .bandwidth = Bandwidth.fromC(@intCast(status.bandwidth)),
            .freq_hz = status.freq_khz,
        };
    }

    pub fn logWith(self: *const Self, logger: logz.Logger) logz.Logger {
        const lg = logger
            .string("mcs", @tagName(self.mcs))
            .fmt("rf_mode", "{any}", .{self.rf_mode})
            .string("tintlv_enable", @tagName(self.tinvlv_enable))
            .string("tintlv_num", @tagName(self.tintlv_num))
            .string("tintlv_len", @tagName(self.tintlv_len))
            .string("bandwidth", @tagName(self.bandwidth))
            .int("freq_hz", self.freq_hz);
        return lg;
    }
};

const LinkStatus = struct {
    state: LinkState,
    rx_mcs: PhyMcs,
    peer_mac: MacAddr,

    const Self = @This();
    pub fn fromC(status: *const bb.bb_link_status_t) Self {
        return Self{
            .state = LinkState.fromC(@intCast(status.state)),
            .rx_mcs = PhyMcs.fromC(@intCast(status.rx_mcs)),
            .peer_mac = status.peer_mac.addr,
        };
    }

    pub fn logWith(self: *const Self, logger: logz.Logger) logz.Logger {
        var lg = logger
            .string("state", @tagName(self.state))
            .string("rx_mcs", @tagName(self.rx_mcs));
        lg = logWithMacAddr(lg, "peer_mac", &self.peer_mac);
        return lg;
    }
};

pub fn logWithPhyStatus(logger: logz.Logger, status: *const bb.bb_phy_status_t, is_tx: bool) logz.Logger {
    const st = PhyStatus.fromC(status, is_tx);
    return st.logWith(logger);
}

pub fn logWithLinkStatus(logger: logz.Logger, status: *const bb.bb_link_status_t) logz.Logger {
    const st = LinkStatus.fromC(status);
    return st.logWith(logger);
}

pub fn logWithUserStatus(logger: logz.Logger, status: *const bb.bb_user_status_t) logz.Logger {
    const tx = &status.tx_status;
    const rx = &status.rx_status;
    var lg = logger.string("user", "tx");
    lg = logWithPhyStatus(lg, tx, true);
    lg = lg.string("user", "rx");
    lg = logWithPhyStatus(lg, rx, false);
    return lg;
}

pub fn u8ToArray(u: u8, comptime msb_first: bool) [8]bool {
    var ret: [8]bool = undefined;
    if (msb_first) {
        ret[0] = (u & 0x80) != 0x00;
        ret[1] = (u & 0x40) != 0x00;
        ret[2] = (u & 0x20) != 0x00;
        ret[3] = (u & 0x10) != 0x00;
        ret[4] = (u & 0x08) != 0x00;
        ret[5] = (u & 0x04) != 0x00;
        ret[6] = (u & 0x02) != 0x00;
        ret[7] = (u & 0x01) != 0x00;
    } else {
        ret[0] = (u & 0x01) != 0x00;
        ret[1] = (u & 0x02) != 0x00;
        ret[2] = (u & 0x04) != 0x00;
        ret[3] = (u & 0x08) != 0x00;
        ret[4] = (u & 0x10) != 0x00;
        ret[5] = (u & 0x20) != 0x00;
        ret[6] = (u & 0x40) != 0x00;
        ret[7] = (u & 0x80) != 0x00;
    }
    return ret;
}

pub fn logWithStatus(logger: logz.Logger, status: *const bb.bb_get_status_out_t) logz.Logger {
    var lg = logger.string("role", @tagName(Role.fromC(status.role)))
        .string("mode", @tagName(Mode.fromC(status.mode)))
        .int("sync_mode", status.sync_mode) // chip sync mode. 1: enable, 0: disable
        .int("sync_master", status.sync_master) // 1: master, 0: slave
        .fmt("cfg_bmp", "0x{x:0>2}", .{status.cfg_sbmp}) // config bitmap
        .fmt("rt_bmp", "0x{x:0>2}", .{status.rt_sbmp}) // runtime bitmap
    ;

    const SLOT_MAX = 8;
    const bmp = status.cfg_sbmp;
    const bmp_arr = u8ToArray(bmp, false);
    const user_status = status.user_status[0..8];
    for (0..SLOT_MAX, bmp_arr, status.link_status, user_status) |i, ok, link, user| {
        if (ok) {
            lg = lg.int("slot", i);
            lg = logWithUserStatus(lg, &user);
            lg = logWithLinkStatus(lg, &link);
        }
    }

    return lg;
}
