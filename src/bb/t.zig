const std = @import("std");
pub const c = @import("c.zig");
const logz = @import("logz");
const utils = @import("../utils.zig");
const BadEnum = utils.BadEnum;

const u8ToArray = utils.u8ToArray;
pub const STA_OK: c_int = 0;
pub const SUBSCRIBE_REQ = 1;
pub const SUBSCRIBE_REQ_RET = 2;
pub const SUBSCRIBE_DAT_RET = 3;
pub const SUBSCRIBE_REQ_FAL = 4;

/// ```c
/// static const BBCB_TAB cbtab[] = {
///     { BB_EVENT_LINK_STATE       ,   sizeof(bb_event_link_state_t    )   },
///     { BB_EVENT_MCS_CHANGE       ,   sizeof(bb_event_mcs_change_t    )   },
///     { BB_EVENT_MCS_CHANGE_END   ,   sizeof(bb_event_mcs_change_end_t)   },
///     { BB_EVENT_CHAN_CHANGE      ,   sizeof(bb_event_chan_change_t   )   },
///     { BB_EVENT_PLOT_DATA        ,   sizeof(bb_event_plot_data_t     )   },
///     { BB_EVENT_PRJ_DISPATCH     ,   sizeof(bb_event_prj_dispatch_t  )   },
///     { BB_EVENT_PAIR_RESULT      ,   sizeof(bb_event_pair_result_t   )   },
///     { BB_EVENT_PRJ_DISPATCH2    ,   sizeof(bb_event_prj_dispatch2_t )   },
/// };
/// ```
///
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
            .link_state => c.BB_EVENT_LINK_STATE,
            .mcs_change => c.BB_EVENT_MCS_CHANGE,
            .chan_change => c.BB_EVENT_CHAN_CHANGE,
            .plot_data => c.BB_EVENT_PLOT_DATA,
            .frame_start => c.BB_EVENT_FRAME_START,
            .offline => c.BB_EVENT_OFFLINE,
            .prj_dispatch => c.BB_EVENT_PRJ_DISPATCH,
            .pair_result => c.BB_EVENT_PAIR_RESULT,
            .prj_dispatch_2 => c.BB_EVENT_PRJ_DISPATCH2,
            .mcs_change_end => c.BB_EVENT_MCS_CHANGE_END,
        };
        return @intCast(ev);
    }

    pub fn fromC(event: c_int) Event {
        switch (event) {
            c.BB_EVENT_LINK_STATE => return Event.link_state,
            c.BB_EVENT_MCS_CHANGE => return Event.mcs_change,
            c.BB_EVENT_CHAN_CHANGE => return Event.chan_change,
            c.BB_EVENT_PLOT_DATA => return Event.plot_data,
            c.BB_EVENT_FRAME_START => return Event.frame_start,
            c.BB_EVENT_OFFLINE => return Event.offline,
            c.BB_EVENT_PRJ_DISPATCH => return Event.prj_dispatch,
            c.BB_EVENT_PAIR_RESULT => return Event.pair_result,
            c.BB_EVENT_PRJ_DISPATCH2 => return Event.prj_dispatch_2,
            c.BB_EVENT_MCS_CHANGE_END => return Event.mcs_change_end,
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
    return @as(u32, c.BB_REQ_CB) << 24 | @as(u32, SUBSCRIBE_REQ) << 16 | @as(u32, event.toC());
}

/// see `dev_dat_so_write_proc`
pub fn socketRequestId(soCmd: SoCmdOpt, slot: u8, port: u8) u32 {
    std.debug.assert(slot < c.BB_SLOT_MAX);
    std.debug.assert(port < c.BB_CONFIG_MAX_TRANSPORT_PER_SLOT);
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
            .ap => c.BB_ROLE_AP,
            .dev => c.BB_ROLE_DEV,
        };
        return @intCast(r);
    }

    pub fn fromC(role: c_int) BadEnum!Role {
        switch (role) {
            c.BB_ROLE_AP => return Role.ap,
            c.BB_ROLE_DEV => return Role.dev,
            else => return BadEnum.BadEnum,
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
            .single_user => c.BB_MODE_SINGLE_USER,
            .multi_user => c.BB_MODE_MULTI_USER,
            .relay => c.BB_MODE_RELAY,
            .director => c.BB_MODE_DIRECTOR,
        };
        return @intCast(m);
    }

    pub fn fromC(mode: c_int) BadEnum!Mode {
        switch (mode) {
            c.BB_MODE_SINGLE_USER => return Mode.single_user,
            c.BB_MODE_MULTI_USER => return Mode.multi_user,
            c.BB_MODE_RELAY => return Mode.relay,
            c.BB_MODE_DIRECTOR => return Mode.director,
            else => return BadEnum.BadEnum,
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
            .neg_2 => c.BB_PHY_MCS_NEG_2,
            .neg_1 => c.BB_PHY_MCS_NEG_1,
            .mcs_0 => c.BB_PHY_MCS_0,
            .mcs_1 => c.BB_PHY_MCS_1,
            .mcs_2 => c.BB_PHY_MCS_2,
            .mcs_3 => c.BB_PHY_MCS_3,
            .mcs_4 => c.BB_PHY_MCS_4,
            .mcs_5 => c.BB_PHY_MCS_5,
            .mcs_6 => c.BB_PHY_MCS_6,
            .mcs_7 => c.BB_PHY_MCS_7,
            .mcs_8 => c.BB_PHY_MCS_8,
            .mcs_9 => c.BB_PHY_MCS_9,
            .mcs_10 => c.BB_PHY_MCS_10,
            .mcs_11 => c.BB_PHY_MCS_11,
            .mcs_12 => c.BB_PHY_MCS_12,
            .mcs_13 => c.BB_PHY_MCS_13,
            .mcs_14 => c.BB_PHY_MCS_14,
            .mcs_15 => c.BB_PHY_MCS_15,
            .mcs_16 => c.BB_PHY_MCS_16,
            .mcs_17 => c.BB_PHY_MCS_17,
            .mcs_18 => c.BB_PHY_MCS_18,
            .mcs_19 => c.BB_PHY_MCS_19,
            .mcs_20 => c.BB_PHY_MCS_20,
            .mcs_21 => c.BB_PHY_MCS_21,
            .mcs_22 => c.BB_PHY_MCS_22,
        };
        return @intCast(m);
    }

    pub fn fromC(mcs: c_int) PhyMcs {
        return switch (mcs) {
            c.BB_PHY_MCS_NEG_2 => .neg_2,
            c.BB_PHY_MCS_NEG_1 => .neg_1,
            c.BB_PHY_MCS_0 => .mcs_0,
            c.BB_PHY_MCS_1 => .mcs_1,
            c.BB_PHY_MCS_2 => .mcs_2,
            c.BB_PHY_MCS_3 => .mcs_3,
            c.BB_PHY_MCS_4 => .mcs_4,
            c.BB_PHY_MCS_5 => .mcs_5,
            c.BB_PHY_MCS_6 => .mcs_6,
            c.BB_PHY_MCS_7 => .mcs_7,
            c.BB_PHY_MCS_8 => .mcs_8,
            c.BB_PHY_MCS_9 => .mcs_9,
            c.BB_PHY_MCS_10 => .mcs_10,
            c.BB_PHY_MCS_11 => .mcs_11,
            c.BB_PHY_MCS_12 => .mcs_12,
            c.BB_PHY_MCS_13 => .mcs_13,
            c.BB_PHY_MCS_14 => .mcs_14,
            c.BB_PHY_MCS_15 => .mcs_15,
            c.BB_PHY_MCS_16 => .mcs_16,
            c.BB_PHY_MCS_17 => .mcs_17,
            c.BB_PHY_MCS_18 => .mcs_18,
            c.BB_PHY_MCS_19 => .mcs_19,
            c.BB_PHY_MCS_20 => .mcs_20,
            c.BB_PHY_MCS_21 => .mcs_21,
            c.BB_PHY_MCS_22 => .mcs_22,
            else => .invalid,
        };
    }
};

const SlotMode = enum {
    fixed,
    dynamic,

    pub fn toC(mode: SlotMode) u8 {
        const m: c_int = switch (mode) {
            .fixed => c.BB_SLOT_MODE_FIXED,
            .dynamic => c.BB_SLOT_MODE_DYNAMIC,
        };
        return @intCast(m);
    }

    pub fn fromC(mode: c_int) BadEnum!SlotMode {
        switch (mode) {
            c.BB_SLOT_MODE_FIXED => return SlotMode.fixed,
            c.BB_SLOT_MODE_DYNAMIC => return SlotMode.dynamic,
            else => return BadEnum.BadEnum,
        }
    }
};

const LinkState = enum {
    idle,
    lock,
    connect,

    pub fn toC(state: LinkState) u8 {
        const s: c_int = switch (state) {
            .idle => c.BB_LINK_STATE_IDLE,
            .lock => c.BB_LINK_STATE_LOCK,
            .connect => c.BB_LINK_STATE_CONNECT,
        };
        return @intCast(s);
    }

    pub fn fromC(state: c_int) BadEnum!LinkState {
        switch (state) {
            c.BB_LINK_STATE_IDLE => return LinkState.idle,
            c.BB_LINK_STATE_LOCK => return LinkState.lock,
            c.BB_LINK_STATE_CONNECT => return LinkState.connect,
            else => return BadEnum.BadEnum,
        }
    }
};

const Band = enum {
    band_1g,
    band_2g,
    band_5g,

    pub fn toC(band: Band) u8 {
        const b: c_int = switch (band) {
            .band_1g => c.BB_BAND_1G,
            .band_2g => c.BB_BAND_2G,
            .band_5g => c.BB_BAND_5G,
        };
        return @intCast(b);
    }

    pub fn fromC(band: c_int) BadEnum!Band {
        switch (band) {
            c.BB_BAND_1G => return Band.band_1g,
            c.BB_BAND_2G => return Band.band_2g,
            c.BB_BAND_5G => return Band.band_5g,
            else => return BadEnum.BadEnum,
        }
    }
};

const RFPath = enum {
    path_a,
    path_b,

    pub fn toC(path: RFPath) u8 {
        const p: c_int = switch (path) {
            .path_a => c.BB_RF_PATH_A,
            .path_b => c.BB_RF_PATH_B,
        };
        return @intCast(p);
    }

    pub fn fromC(path: c_int) BadEnum!RFPath {
        switch (path) {
            c.BB_RF_PATH_A => return RFPath.path_a,
            c.BB_RF_PATH_B => return RFPath.path_b,
            else => return BadEnum.BadEnum,
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
            .single => c.BB_BAND_MODE_SINGLE,
            .band_2g_5g => c.BB_BAND_MODE_2G_5G,
            .band_1g_2g => c.BB_BAND_MODE_1G_2G,
            .band_1g_5g => c.BB_BAND_MODE_1G_5G,
        };
        return @intCast(m);
    }

    pub fn fromC(mode: c_int) BadEnum!BandMode {
        switch (mode) {
            c.BB_BAND_MODE_SINGLE => return BandMode.single,
            c.BB_BAND_MODE_2G_5G => return BandMode.band_2g_5g,
            c.BB_BAND_MODE_1G_2G => return BandMode.band_1g_2g,
            c.BB_BAND_MODE_1G_5G => return BandMode.band_1g_5g,
            else => return BadEnum.BadEnum,
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
            .bw_1_25m => c.BB_BW_1_25M,
            .bw_2_5m => c.BB_BW_2_5M,
            .bw_5m => c.BB_BW_5M,
            .bw_10m => c.BB_BW_10M,
            .bw_20m => c.BB_BW_20M,
            .bw_40m => c.BB_BW_40M,
        };
        return @intCast(b);
    }

    pub fn fromC(bw: c_int) BadEnum!Bandwidth {
        switch (bw) {
            c.BB_BW_1_25M => return Bandwidth.bw_1_25m,
            c.BB_BW_2_5M => return Bandwidth.bw_2_5m,
            c.BB_BW_5M => return Bandwidth.bw_5m,
            c.BB_BW_10M => return Bandwidth.bw_10m,
            c.BB_BW_20M => return Bandwidth.bw_20m,
            c.BB_BW_40M => return Bandwidth.bw_40m,
            else => return BadEnum.BadEnum,
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
            .len_3 => c.BB_TIMEINTLV_LEN_3,
            .len_6 => c.BB_TIMEINTLV_LEN_6,
            .len_12 => c.BB_TIMEINTLV_LEN_12,
            .len_24 => c.BB_TIMEINTLV_LEN_24,
            .len_48 => c.BB_TIMEINTLV_LEN_48,
        };
        return @intCast(l);
    }

    pub fn fromC(len: c_int) BadEnum!TimeIntlvLen {
        switch (len) {
            c.BB_TIMEINTLV_LEN_3 => return TimeIntlvLen.len_3,
            c.BB_TIMEINTLV_LEN_6 => return TimeIntlvLen.len_6,
            c.BB_TIMEINTLV_LEN_12 => return TimeIntlvLen.len_12,
            c.BB_TIMEINTLV_LEN_24 => return TimeIntlvLen.len_24,
            c.BB_TIMEINTLV_LEN_48 => return TimeIntlvLen.len_48,
            else => return BadEnum.BadEnum,
        }
    }
};

const TimeIntlvEnable = enum {
    off,
    on,

    pub fn toC(enable: TimeIntlvEnable) u8 {
        const e: c_int = switch (enable) {
            .off => c.BB_TIMEINTLV_OFF,
            .on => c.BB_TIMEINTLV_ON,
        };
        return @intCast(e);
    }

    pub fn fromC(enable: c_int) BadEnum!TimeIntlvEnable {
        switch (enable) {
            c.BB_TIMEINTLV_OFF => return TimeIntlvEnable.off,
            c.BB_TIMEINTLV_ON => return TimeIntlvEnable.on,
            else => return BadEnum.BadEnum,
        }
    }
};

const TimeIntlvNum = enum {
    block_1,
    block_2,

    pub fn toC(num: TimeIntlvNum) u8 {
        const n: c_int = switch (num) {
            .block_1 => c.BB_TIMEINTLV_1_BLOCK,
            .block_2 => c.BB_TIMEINTLV_2_BLOCK,
        };
        return @intCast(n);
    }

    pub fn fromC(num: c_int) BadEnum!TimeIntlvNum {
        switch (num) {
            c.BB_TIMEINTLV_1_BLOCK => return TimeIntlvNum.block_1,
            c.BB_TIMEINTLV_2_BLOCK => return TimeIntlvNum.block_2,
            else => return BadEnum.BadEnum,
        }
    }
};

pub const MacAddr = [@intCast(c.BB_MAC_LEN)]u8;

pub fn logWithMacAddr(logger: logz.Logger, key: []const u8, mac: *const MacAddr) logz.Logger {
    if (c.BB_MAC_LEN != 4) {
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
            .tx_1tx => c.BB_TX_1TX,
            .tx_2tx_stbc => c.BB_TX_2TX_STBC,
            .tx_2tx_mimo => c.BB_TX_2TX_MIMO,
        };
        return @intCast(m);
    }

    pub fn fromC(mode: c_int) BadEnum!TxMode {
        switch (mode) {
            c.BB_TX_1TX => return TxMode.tx_1tx,
            c.BB_TX_2TX_STBC => return TxMode.tx_2tx_stbc,
            c.BB_TX_2TX_MIMO => return TxMode.tx_2tx_mimo,
            else => return BadEnum.BadEnum,
        }
    }
};

pub const RxMode = enum {
    rx_1t1r,
    rx_1t2r,
    rx_2t2r_stbc,
    rx_2t2r_mimo,

    pub fn toC(mode: RxMode) u8 {
        const m: c_int = switch (mode) {
            .rx_1t1r => c.BB_RX_1T1R,
            .rx_1t2r => c.BB_RX_1T2R,
            .rx_2t2r_stbc => c.BB_RX_2T2R_STBC,
            .rx_2t2r_mimo => c.BB_RX_2T2R_MIMO,
        };
        return @intCast(m);
    }

    pub fn fromC(mode: c_int) BadEnum!RxMode {
        switch (mode) {
            c.BB_RX_1T1R => return RxMode.rx_1t1r,
            c.BB_RX_1T2R => return RxMode.rx_1t2r,
            c.BB_RX_2T2R_STBC => return RxMode.rx_2t2r_stbc,
            c.BB_RX_2T2R_MIMO => return RxMode.rx_2t2r_mimo,
            else => return BadEnum.BadEnum,
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

    pub inline fn default() Self {
        return Self{
            .mcs = PhyMcs.neg_1,
            .rf_mode = RfMode{ .tx = TxMode.tx_1tx },
            .tinvlv_enable = TimeIntlvEnable.off,
            .tintlv_num = TimeIntlvNum.block_1,
            .tintlv_len = TimeIntlvLen.len_3,
            .bandwidth = Bandwidth.bw_1_25m,
            .freq_hz = 0,
        };
    }

    pub fn fromC(status: *const c.bb_phy_status_t, is_tx: bool) BadEnum!Self {
        var rf_mode: RfMode = undefined;
        if (is_tx) {
            rf_mode = RfMode{ .tx = try TxMode.fromC(@intCast(status.rf_mode)) };
        } else {
            rf_mode = RfMode{ .rx = try RxMode.fromC(@intCast(status.rf_mode)) };
        }
        return Self{
            .mcs = PhyMcs.fromC(status.mcs),
            .rf_mode = rf_mode,
            .tinvlv_enable = try TimeIntlvEnable.fromC(@intCast(status.tintlv_enable)),
            .tintlv_num = try TimeIntlvNum.fromC(@intCast(status.tintlv_num)),
            .tintlv_len = try TimeIntlvLen.fromC(@intCast(status.tintlv_len)),
            .bandwidth = try Bandwidth.fromC(@intCast(status.bandwidth)),
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

    pub inline fn default() Self {
        return Self{
            .state = LinkState.idle,
            .rx_mcs = PhyMcs.neg_1,
            .peer_mac = [_]u8{ 0x00, 0x00, 0x00, 0x00 },
        };
    }

    const Self = @This();
    pub fn fromC(status: *const c.bb_link_status_t) BadEnum!Self {
        return Self{
            .state = try LinkState.fromC(@intCast(status.state)),
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

pub fn logWithUserStatus(logger: logz.Logger, status: *const c.bb_user_status_t) logz.Logger {
    const tx = &status.tx_status;
    const rx = &status.rx_status;
    var lg = logger.string("user", "tx");
    lg = logWithPhyStatus(lg, tx, true);
    lg = lg.string("user", "rx");
    lg = logWithPhyStatus(lg, rx, false);
    return lg;
}

pub const UserStatus = struct {
    tx_status: PhyStatus,
    rx_status: PhyStatus,
    const Self = @This();

    pub fn logWith(self: *const Self, logger: logz.Logger) logz.Logger {
        var lg = logger.string("user", "tx");
        lg = self.tx_status.logWith(lg);
        lg = lg.string("user", "rx");
        lg = self.rx_status.logWith(lg);
        return lg;
    }

    pub inline fn default() Self {
        return Self{
            .tx_status = PhyStatus.default(),
            .rx_status = PhyStatus.default(),
        };
    }
};

pub const RefStatus = struct { u8, *const UserStatus, *const LinkStatus };

pub const SLOT_MAX = 8;
pub const Status = struct {
    role: Role,
    mode: Mode,
    /// 1: enable, 0: disable
    en_sync: bool,
    /// 1: enable, 0: disable
    is_master: bool,
    cfg_bmp: u8,
    rt_bmp: u8,
    user_status: [SLOT_MAX]UserStatus,
    link_status: [SLOT_MAX]LinkStatus,
    const Self = @This();

    fn bmp_status(self: *const Self, alloc: std.mem.Allocator, bmp: u8) []RefStatus {
        var list = std.ArrayList(RefStatus).init(alloc);
        defer list.deinit();
        const bmp_arr = u8ToArray(bmp, false);
        const user_status = self.user_status[0..SLOT_MAX];
        const link_status = self.link_status[0..SLOT_MAX];
        for (0..SLOT_MAX, bmp_arr, link_status, user_status) |i, ok, *link, *user| {
            if (ok) {
                list.append(.{ @intCast(i), user, link }) catch @panic("OOM");
            }
        }
        return list.toOwnedSlice() catch @panic("OOM");
    }

    pub fn cfg_status(self: *const Self, alloc: std.mem.Allocator) []RefStatus {
        return self.bmp_status(alloc, self.cfg_bmp);
    }

    pub fn rt_status(self: *const Self, alloc: std.mem.Allocator) []RefStatus {
        return self.bmp_status(alloc, self.rt_bmp);
    }

    pub fn fromC(status: *const c.bb_get_status_out_t) BadEnum!Self {
        var user_status: [SLOT_MAX]UserStatus = undefined;
        var link_status: [SLOT_MAX]LinkStatus = undefined;
        for (0..SLOT_MAX) |i| {
            user_status[i] = UserStatus{
                .tx_status = PhyStatus.fromC(&status.user_status[i].tx_status, true) catch continue,
                .rx_status = PhyStatus.fromC(&status.user_status[i].rx_status, false) catch continue,
            };
            link_status[i] = LinkStatus.fromC(&status.link_status[i]) catch continue;
        }
        return Self{
            .role = try Role.fromC(status.role),
            .mode = try Mode.fromC(status.mode),
            .en_sync = status.sync_mode != 0,
            .is_master = status.sync_master != 0,
            .cfg_bmp = status.cfg_sbmp,
            .rt_bmp = status.rt_sbmp,
            .user_status = user_status,
            .link_status = link_status,
        };
    }

    pub fn logWith(self: *const Self, logger: logz.Logger) logz.Logger {
        var fixed_buf: [@sizeOf(RefStatus) * (SLOT_MAX + 2)]u8 = undefined;
        var fixed = std.heap.FixedBufferAllocator.init(fixed_buf[0..]);
        const alloc = fixed.allocator();

        var lg = logger
            .string("role", @tagName(self.role))
            .string("mode", @tagName(self.mode))
            .boolean("sync_mode", self.en_sync)
            .boolean("sync_master", self.is_master)
            .fmt("cfg_bmp", "0x{x:0>2}", .{self.cfg_bmp})
            .fmt("rt_bmp", "0x{x:0>2}", .{self.rt_bmp});
        const refs = self.cfg_status(alloc);
        for (refs) |r| {
            const i, const user, const link = r;
            lg = lg.int("slot", i);
            lg = user.logWith(lg);
            lg = link.logWith(lg);
        }
        return lg;
    }
};

pub fn logWithPhyStatus(logger: logz.Logger, status: *const c.bb_phy_status_t, is_tx: bool) logz.Logger {
    const st = PhyStatus.fromC(status, is_tx) catch {
        return logger
            .string("error", "invalid `bb_phy_status_t`")
            .fmt("phy_status", "{any}", .{status});
    };
    return st.logWith(logger);
}

pub fn logWithLinkStatus(logger: logz.Logger, status: *const c.bb_link_status_t) logz.Logger {
    const st = LinkStatus.fromC(status) catch {
        return logger
            .string("error", "invalid `bb_link_status_t`")
            .fmt("link_status", "{any}", .{status});
    };
    return st.logWith(logger);
}

pub fn logWithStatus(logger: logz.Logger, status: *const c.bb_get_status_out_t) logz.Logger {
    const st = Status.fromC(status) catch {
        return logger
            .string("error", "invalid `bb_get_status_out_t`")
            .fmt("status", "{any}", .{status});
    };
    return st.logWith(logger);
}

pub const socket_msg_ret_t = extern struct {
    pos: u64,
    len: u32,
};

pub const err_socket_msg_ret_t = extern struct {
    got_pos: u64,
    expected_pos: u32,
};
