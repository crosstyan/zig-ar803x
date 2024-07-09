const std = @import("std");
const bb = @import("c.zig");

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
        const ev = switch (event) {
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
            else => std.debug.panic("unknown C enum for `bb_event_e` {}", .{event}),
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
        const cmd = switch (soCmd) {
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
    return bb.BB_REQ_CB << 24 | SUBSCRIBE_REQ << 16 | @as(u32, event.toC());
}

/// see `dev_dat_so_write_proc`
pub fn socketRequestId(soCmd: SoCmdOpt, slot: u8, port: u8) u32 {
    std.debug.assert(slot < bb.BB_SLOT_MAX);
    std.debug.assert(port < bb.BB_CONFIG_MAX_TRANSPORT_PER_SLOT);
    return 4 << 24 | @as(u32, soCmd.toByte()) << 16 | slot << 8 | port;
}
