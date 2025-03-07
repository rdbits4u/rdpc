const std = @import("std");
const parse = @import("parse");
const strings = @import("strings");
const rdpc_priv = @import("rdpc_priv.zig");
const rdpc_gcc = @import("rdpc_gcc.zig");
const rdpc_caps = @import("rdpc_caps.zig");
const c = @cImport(
{
    @cInclude("librdpc.h");
});

pub const MsgError = error
{
    BadTag,
    BadCode,
    BadUser,
    BadResult,
    BadSize,
    BadVersion,
    BadLength,
    BadParse,
    BadMemory,
};

//*****************************************************************************
pub inline fn err_if(b: bool, err: MsgError) !void
{
    if (b) return err else return;
}

//*****************************************************************************
fn rv_to_err(rv: c_int) !void
{
    switch (rv)
    {
        c.LIBRDPC_ERROR_MEMORY => return MsgError.BadMemory,
        c.LIBRDPC_ERROR_PARSE => return MsgError.BadParse,
        else => return,
    }
}

//*********************************************************************************
/// get the bytes of a structure when streamed, this is not the same as
/// sizeof(struct)
pub fn get_struct_bytes(comptime T: type) u16
{
    var rv: u16 = 0;
    switch (@typeInfo(T))
    {
        .@"struct" => |struct_info|
        {
            inline for (struct_info.fields) |field|
            {
                rv += switch (@typeInfo(field.type))
                {
                    .@"struct" => get_struct_bytes(field.type),
                    .int => @sizeOf(field.type),
                    .array => @sizeOf(field.type),
                    else => @compileError("bad field type " ++ field.name),
                };
            }
        },
        else => @compileError("can not get_struct_bytes " ++ @typeName(T)),
    }
    return rv;
}

pub const rdpc_msg_t = struct
{
    allocator: *const std.mem.Allocator = undefined,
    mcs_userid: u16 = 0,
    mcs_channels_joined: u16 = 0,
    rdp_share_id: u32 = 0,
    priv: *rdpc_priv.rdpc_priv_t = undefined,

    //*************************************************************************
    pub fn delete(self: *rdpc_msg_t) void
    {
        self.allocator.destroy(self);
    }

    //*************************************************************************
    // 2.2.1.1 Client X.224 Connection Request PDU
    // out
    pub fn connection_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        try s.check_rem(19);
        s.push_layer(5, 0);
        s.out_u8(c.ISO_PDU_CR); // Connection Request - 0xE0
        s.out_u8_skip(2); // dst_ref
        s.out_u8_skip(2); // src_ref
        s.out_u8_skip(1); // class
        // optional RDP protocol negotiation request for RDPv5
        s.out_u8(1);
        s.out_u8(0);
        s.out_u16_le(8);
        s.out_u32_le(3);
        s.push_layer(0, 1); // end
        const bytes = s.layer_subtract(1, 0);
        const li: u8 = @truncate(bytes - 5);
        s.pop_layer(0); // go back
        s.out_u8(3); // version
        s.out_u8(0);
        s.out_u16_be(bytes); // set PDU size
        s.out_u8(li); // LI (length indicator)
        s.pop_layer(1); // go back to end
    }

    //*************************************************************************
    // 2.2.1.2 Server X.224 Connection Confirm PDU
    // in
    pub fn connection_confirm(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        try s.check_rem(6);
        s.in_u8_skip(5);
        const code = s.in_u8();
        // Connection Confirm - 0xD0
        try err_if(code != c.ISO_PDU_CC, MsgError.BadCode);
    }

    //*************************************************************************
    // 2.2.1.3 Client MCS Connect Initial PDU with GCC Conference Create
    // Request
    // out
    pub fn conference_create_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        const gccs = try parse.create(self.allocator, 1024);
        defer gccs.delete();
        try rdpc_gcc.gcc_out_data(self, gccs);
        const gcc_slice = gccs.get_out_slice();
        try s.check_rem(7);
        s.push_layer(7, 0);
        s.push_layer(0, 1);
        try ber_out_header(s, c.MCS_CONNECT_INITIAL, 0x80); // update later
        s.push_layer(0, 2);
        try ber_out_header(s, c.BER_TAG_OCTET_STRING, 1);
        try s.check_rem(1);
        s.out_u8(1);
        try ber_out_header(s, c.BER_TAG_OCTET_STRING, 1);
        try s.check_rem(1);
        s.out_u8(1);
        try ber_out_header(s, c.BER_TAG_BOOLEAN, 1);
        try s.check_rem(1);
        s.out_u8(0xFF);
        // target params: see table in section 3.2.5.3.3 in RDPBCGR
        try mcs_out_domain_params(s, 34, 2, 0, 0xffff);
        // min params: see table in section 3.2.5.3.3 in RDPBCGR
        try mcs_out_domain_params(s, 1, 1, 1, 0x420);
        // max params: see table in section 3.2.5.3.3 in RDPBCGR
        try mcs_out_domain_params(s, 0xffff, 0xffff, 0xffff, 0xffff);
        // insert gcc_data
        const gcc_bytes: u16 = @truncate(gcc_slice.len);
        try ber_out_header(s, c.BER_TAG_OCTET_STRING, gcc_bytes);
        try s.check_rem(gcc_slice.len);
        s.out_u8_slice(gcc_slice);
        s.push_layer(0, 3); // save end
        // update MCS_CONNECT_INITIAL
        const length_after = s.layer_subtract(3, 2);
        // length_after must be >= 0x80 or above space for
        // MCS_CONNECT_INITIAL will be wrong
        try err_if(length_after < 0x80, MsgError.BadSize);
        s.pop_layer(1);
        try ber_out_header(s, c.MCS_CONNECT_INITIAL, length_after);
        s.pop_layer(0); // go to iso header
        try iso_out_data_header(s, s.layer_subtract(3, 0));
        s.pop_layer(3); // go to end
    }

    //*************************************************************************
    // 2.2.1.4 Server MCS Connect Response PDU with GCC Conference Create
    // Response
    // in
    pub fn conference_create_response(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        var length: u16 = undefined;
        try iso_in_data_header(s, &length);
        try s.check_rem(length - 7);
        try ber_in_header(s, c.MCS_CONNECT_RESPONSE, &length);
        try s.check_rem(length);
        try ber_in_header(s, c.BER_TAG_RESULT, &length);
        try s.check_rem(length);
        var result: u64 = 0;
        while (length > 0) : (length -= 1)
        {
            result = (result << 8) | s.in_u8();
        }
        try err_if(result != 0, MsgError.BadResult);
        try ber_in_header(s, c.BER_TAG_INTEGER, &length);
        try s.check_rem(length);
        result = 0;
        while (length > 0) : (length -= 1)
        {
            result = (result << 8) | s.in_u8();
        }
        try err_if(result != 0, MsgError.BadResult);
        try mcs_in_domain_params(s);
        try ber_in_header(s, c.BER_TAG_OCTET_STRING, &length);
        try s.check_rem(length);
        const ls = try parse.create_from_slice(self.allocator,
                    s.in_u8_slice(length));
        defer ls.delete();
        try rdpc_gcc.gcc_in_data(self, ls);
    }

    //*************************************************************************
    // 2.2.1.5 Client MCS Erect Domain Request PDU
    // out
    pub fn erect_domain_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        try s.check_rem(7 + 5);
        s.push_layer(7, 0);
        s.out_u8(c.MCS_EDRQ << 2); // Erect Domain Request(1) << 2
        s.out_u16_be(1); // subHeight
        s.out_u16_be(1); // subInterval
        s.push_layer(0, 1);
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(1, 0));
        s.pop_layer(1);
    }

    //*************************************************************************
    // 2.2.1.6 Client MCS Attach User Request PDU
    // out
    pub fn attach_user_request(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        try s.check_rem(7 + 1);
        s.push_layer(7, 0);
        s.out_u8(c.MCS_AURQ << 2); // Attach User Request(10) << 2
        s.push_layer(0, 1);
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(1, 0));
        s.pop_layer(1);
    }

    //*************************************************************************
    // 2.2.1.7 Server MCS Attach User Confirm PDU
    // in
    pub fn attach_user_confirm(self: *rdpc_msg_t,
            s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        var length: u16 = undefined;
        try iso_in_data_header(s, &length);
        try s.check_rem(length - 7);
        try s.check_rem(1);
        const opcode = s.in_u8(); // Attach User Confirm(11) << 2
        try err_if((opcode >> 2) != c.MCS_AUCF, MsgError.BadCode);
        try err_if((opcode & 2) == 0, MsgError.BadCode);
        try s.check_rem(1);
        try err_if(s.in_u8() != 0, MsgError.BadResult);
        try s.check_rem(2);
        self.mcs_userid = s.in_u16_be();
        try self.priv.logln(@src(), "mcs_userid {}", .{self.mcs_userid});
    }

    //*************************************************************************
    // 2.2.1.8 Client MCS Channel Join Request PDU
    // out
    pub fn channel_join_request(self: *rdpc_msg_t,
            s: *parse.parse_t, chanid: u16) !void
    {
        try self.priv.logln(@src(), "chanid {}", .{chanid});
        try s.check_rem(7 + 5);
        s.push_layer(7, 0);
        s.out_u8(c.MCS_CJRQ << 2); // Channel Join Request(14) << 2
        s.out_u16_be(self.mcs_userid);
        s.out_u16_be(chanid);
        s.push_layer(0, 1);
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(1, 0));
        s.pop_layer(1);
    }

    //*************************************************************************
    // 2.2.1.9 Server MCS Channel Join Confirm PDU
    // in
    pub fn channel_join_confirm(self: *rdpc_msg_t,
            s: *parse.parse_t, chanid: *u16) !void
    {
        try self.priv.logln(@src(), "", .{});
        var length: u16 = undefined;
        try iso_in_data_header(s, &length);
        try s.check_rem(length - 7);
        try s.check_rem(1);
        const opcode = s.in_u8(); // Channel Join Confirm(15) << 2
        try err_if((opcode >> 2) != c.MCS_CJCF, MsgError.BadCode);
        try err_if((opcode & 2) == 0, MsgError.BadCode);
        try s.check_rem(1);
        try err_if(s.in_u8() != 0, MsgError.BadResult);
        try s.check_rem(2);
        const mcs_userid = s.in_u16_be();
        try err_if(self.mcs_userid != mcs_userid, MsgError.BadUser);
        try s.check_rem(2);
        chanid.* = s.in_u16_be();
        try self.priv.logln(@src(), "chanid {}", .{chanid.*});
    }

    //*************************************************************************
    // 2.2.1.10 Client Security Exchange PDU
    // out
    pub fn security_exchange(self: *rdpc_msg_t, s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        try s.check_rem(1024);
        // skip for now
    }

    //*************************************************************************
    // 2.2.1.11 Client Info PDU
    // out
    pub fn client_info(self: *rdpc_msg_t, s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        const ci = self.priv.rdpc.client_info;
        try s.check_rem(7);
        s.push_layer(7, 0); // iso
        try s.check_rem(8);
        s.push_layer(8, 1); // mcs
        try s.check_rem(4);
        s.push_layer(4, 2); // sec
        try s.check_rem(18);
        s.out_u32_le(ci.CodePage);
        s.out_u32_le(ci.flags);
        s.out_u16_le(ci.cbDomain);
        s.out_u16_le(ci.cbUserName);
        s.out_u16_le(ci.cbPassword);
        s.out_u16_le(ci.cbAlternateShell);
        s.out_u16_le(ci.cbWorkingDir);
        try s.check_rem(ci.cbDomain + 2 + ci.cbUserName + 2 +
                ci.cbPassword + 2 + ci.cbAlternateShell + 2 +
                ci.cbWorkingDir + 2);
        s.out_u8_slice(ci.Domain[0..ci.cbDomain + 2]);
        s.out_u8_slice(ci.UserName[0..ci.cbUserName + 2]);
        s.out_u8_slice(ci.Password[0..ci.cbPassword + 2]);
        s.out_u8_slice(ci.AlternateShell[0..ci.cbAlternateShell + 2]);
        s.out_u8_slice(ci.WorkingDir[0..ci.cbWorkingDir + 2]);
        // extra info
        try s.check_rem(2 + 2 + ci.extraInfo.cbClientAddress +
                2 + ci.extraInfo.cbClientDir +
                @sizeOf(@TypeOf(ci.extraInfo.clientTimeZone)) +
                4 + 4);
        s.out_u16_le(ci.extraInfo.clientAddressFamily);
        s.out_u16_le(ci.extraInfo.cbClientAddress);
        s.out_u8_slice(ci.extraInfo.clientAddress[0..ci.extraInfo.cbClientAddress]);
        s.out_u16_le(ci.extraInfo.cbClientDir);
        s.out_u8_slice(ci.extraInfo.clientDir[0..ci.extraInfo.cbClientDir]);
        s.out_u8_slice(ci.extraInfo.clientTimeZone[0..]);
        s.out_u32_le(ci.extraInfo.clientSessionId);
        s.out_u32_le(ci.extraInfo.performanceFlags);
        s.push_layer(0, 3);
        // sec layer
        s.pop_layer(2);
        s.out_u32_le(c.SEC_LOGON_INFO);
        // mcs layer
        s.pop_layer(1);
        try mcs_out_header(s, s.layer_subtract(3, 1), self.mcs_userid,
                c.MCS_GLOBAL_CHANNEL);
        // iso layer
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(3, 0));
        // back to end
        s.pop_layer(3);
    }

    //*************************************************************************
    // in
    pub fn process_sec(self: *rdpc_msg_t, s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        var length: u16 = 0;
        try iso_in_data_header(s, &length);
        try s.check_rem(length - 7);
        try self.priv.logln(@src(), "iso length {}", .{length});
        var userid: u16 = 0;
        var channel: u16 = 0;
        try mcs_in_header(s, &length, &userid, &channel);
        try s.check_rem(length);
        try self.priv.logln(@src(), "mcs length {} userid {} channel {}",
                .{length, userid, channel});
        const flags = s.in_u16_le();
        const flagshi = s.in_u16_le();
        try self.priv.logln(@src(), "sec flags 0x{X} sec flagshi 0x{X}",
                .{flags, flagshi});
        try err_if((flags & c.SEC_LICENCE_NEG) == 0, MsgError.BadCode);
    }

    //*************************************************************************
    // in
    pub fn process_rdp(self: *rdpc_msg_t, s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        try s.check_rem(1);
        s.push_layer(0, 0);
        const code = s.in_u8();
        s.pop_layer(0);
        if (code != 3)
        {
            return process_rdp_fastpath_pdu(self, s);
        }
        // non fastpath
        var length: u16 = 0;
        try iso_in_data_header(s, &length);
        try s.check_rem(length - 7);
        try self.priv.logln(@src(), "iso length {}", .{length});
        var userid: u16 = 0;
        var channel: u16 = 0;
        try mcs_in_header(s, &length, &userid, &channel);
        try s.check_rem(length);
        try self.priv.logln(@src(),
                "mcs length {} userid {} channel {}",
                .{length, userid, channel});
        try err_if(userid != self.mcs_userid, MsgError.BadUser);
        if (channel != c.MCS_GLOBAL_CHANNEL)
        {
            return process_rdp_channel_pdu(self, s);
        }
        while (s.check_rem_bool(2))
        {
            s.push_layer(0, 0);
            const pduLength = s.in_u16_le();
            try self.priv.logln(@src(), "pduLength {}", .{pduLength});
            try err_if(pduLength < 6, MsgError.BadLength);
            try s.check_rem(pduLength - 2);
            s.pop_layer(0);
            const ins = try parse.create_from_slice(self.allocator,
                    s.in_u8_slice(pduLength));
            defer ins.delete();
            try self.process_rdp_pdu(ins);
        }
    }

    //*************************************************************************
    // in
    fn process_rdp_pdu(self: *rdpc_msg_t, s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        try s.check_rem(6);
        const totallength = s.in_u16_le();
        const pdutype = s.in_u16_le();
        const pdusource = s.in_u16_le();
        try self.priv.logln(@src(),
                "rdp totallength 0x{X} sec pdutype 0x{X} pdusource 0x{X}",
                .{totallength, pdutype, pdusource});
        switch (pdutype & 0xF)
        {
            c.SCH_PDUTYPE_DEMANDACTIVEPDU => try process_rdp_demand_active(self, s),
            c.SCH_PDUTYPE_DATAPDU => try process_rdp_data(self, s),
            else => return MsgError.BadCode,
        }
    }

    //*************************************************************************
    // in
    fn process_rdp_demand_active(self: *rdpc_msg_t, s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        try s.check_rem(8);
        self.rdp_share_id = s.in_u32_le();
        const tag_len = s.in_u16_le();
        const caps_len = s.in_u16_le();
        try err_if(tag_len != 4, MsgError.BadLength);
        try s.check_rem(tag_len + 4);
        var tag_text: [4]u8 = undefined;
        std.mem.copyForwards(u8, &tag_text, s.in_u8_slice(tag_len));
        try err_if(!std.mem.eql(u8, &tag_text, "RDP\x00"), MsgError.BadTag);
        const caps_count = s.in_u32_le();
        try self.priv.logln(@src(), "caps_count {} caps_len {}",
                .{caps_count, caps_len});
        try s.check_rem(caps_len);
        var cap_type: u16 = undefined;
        var cap_len: u16 = undefined;
        for (0..caps_count) |index|
        {
            try s.check_rem(4);
            s.push_layer(0, 0);
            cap_type = s.in_u16_le();
            cap_len = s.in_u16_le();
            try self.priv.logln(@src(),
                    "index {} cap_type {} cap_len {}",
                    .{index, cap_type, cap_len});
            try s.check_rem(cap_len - 4);
            s.pop_layer(0);
            const ins = try parse.create_from_slice(self.allocator,
                    s.in_u8_slice(cap_len));
            defer ins.delete();
            try rdpc_caps.process_cap(self, cap_type, ins);
        }
        try self.priv.logln(@src(),"s.offset {} s.data.len {}",
                .{s.offset, s.data.len});

        try send_confirm_active(self);
        try send_synchronize(self);
        try send_control_cooperate(self);
        try send_control_req_control(self);
        try send_client_persistent_key_list(self);
        try send_client_font_list(self);
    }

    //*************************************************************************
    // out
    fn send_confirm_active(self: *rdpc_msg_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        const s = try parse.create(self.allocator, 8192);
        defer s.delete();
        try s.check_rem(7 + 8 + 2 + 2 + 2 + 4 + 2 + 2 + 2 + 4 + 4);
        s.push_layer(7, 0);
        s.push_layer(8, 1);
        s.push_layer(2, 2);
        // shareControlHeader: insert pdu type; 2 bytes
        // we support protocol version 1
        s.out_u16_le((1 << 4) | c.SCH_PDUTYPE_CONFIRMACTIVEPDU);
        // shareControlHeader: insert pdu source, i.e our channel ID; 2 bytes
        s.out_u16_le(self.mcs_userid);
        // insert share ID; 4 bytes
        s.out_u32_le(self.rdp_share_id);
        // insert originator ID, hardcoded by spec to 0x03EA
        s.out_u16_le(0x03EA);
        // insert length of string "MSTC"
        s.out_u16_le(4);
        // insert combined cap length; we do this later
        s.push_layer(2, 3);
        // insert source descriptor
        s.out_u8_slice("MSTC");
        // insert number of capabilities + pad2octets
        s.push_layer(4, 4);
        var total_caps: u16 = 0;
        total_caps += try rdpc_caps.out_cap_general(self, s);
        total_caps += try rdpc_caps.out_cap_bitmap(self, s);
        total_caps += try rdpc_caps.out_cap_order(self, s);
        total_caps += try rdpc_caps.out_cap_bitmapcache(self, s);
        total_caps += try rdpc_caps.out_cap_control(self, s);
        total_caps += try rdpc_caps.out_cap_windowactivation(self, s);
        total_caps += try rdpc_caps.out_cap_pointer(self, s);
        total_caps += try rdpc_caps.out_cap_share(self, s);
        total_caps += try rdpc_caps.out_cap_colortable(self, s);
        total_caps += try rdpc_caps.out_cap_sound(self, s);
        total_caps += try rdpc_caps.out_cap_input(self, s);
        total_caps += try rdpc_caps.out_cap_font(self, s);
        total_caps += try rdpc_caps.out_cap_brush(self, s);
        total_caps += try rdpc_caps.out_cap_glyphcache(self, s);
        total_caps += try rdpc_caps.out_cap_offscreen(self, s);
        total_caps += try rdpc_caps.out_cap_bitmapcache_rev2(self, s);
        total_caps += try rdpc_caps.out_cap_virtualchannel(self, s);
        total_caps += try rdpc_caps.out_cap_draw_ninegrid(self, s);
        total_caps += try rdpc_caps.out_cap_draw_gdiplus(self, s);
        total_caps += try rdpc_caps.out_cap_rail(self, s);
        total_caps += try rdpc_caps.out_cap_windowlist(self, s);
        total_caps += try rdpc_caps.out_cap_compdesk(self, s);
        total_caps += try rdpc_caps.out_cap_multifrag(self, s);
        total_caps += try rdpc_caps.out_cap_largepointer(self, s);
        total_caps += try rdpc_caps.out_cap_surfcmds(self, s);
        total_caps += try rdpc_caps.out_cap_bitmapcodecs(self, s);
        total_caps += try rdpc_caps.out_cap_frameack(self, s);
        // save end
        s.push_layer(0, 5);
        // number of caps
        s.pop_layer(4);
        s.out_u16_le(total_caps);
        s.out_u16_le(0);
        // combined cap length
        s.pop_layer(3);
        s.out_u16_le(s.layer_subtract(5, 3));
        // rdp length
        s.pop_layer(2);
        s.out_u16_le(s.layer_subtract(5, 2));
        // mcs
        s.pop_layer(1);
        const userid = self.mcs_userid;
        const chanid = c.MCS_GLOBAL_CHANNEL;
        try mcs_out_header(s, s.layer_subtract(5, 1), userid, chanid);
        // iso
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(5, 0));
        // back to end
        s.pop_layer(5);
        const rv = try self.priv.send_slice_to_server(s.get_out_slice());
        try rv_to_err(rv);
    }

    //*************************************************************************
    // out
    fn send_synchronize(self: *rdpc_msg_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        const s = try parse.create(self.allocator, 8192);
        defer s.delete();
        try s.check_rem(7 + 8 + 2 + 2 + 2 + 4 + 8);
        s.push_layer(7, 0); // iso
        s.push_layer(8, 1); // mcs
        // sec
        s.push_layer(18, 2); // rdp data

        // shareControlHeader: insert pdu type; 2 bytes
        // we support protocol version 1
        s.out_u16_le((1 << 4) | c.SCH_PDUTYPE_DATAPDU);
        // shareControlHeader: insert pdu source, i.e our channel ID; 2 bytes
        s.out_u16_le(self.mcs_userid);
        // insert share ID; 4 bytes
        s.out_u32_le(self.rdp_share_id);
        s.out_u8(0);                            // pad1
        s.out_u8(c.RDP_STREAM_MED);             // stream ID
        s.out_u16_le(0);                        // uncompressed length
        s.out_u8(c.RDP_PDUTYPE2_SYNCHRONIZE);   // pduType2
        s.out_u8(0);                            // compressed type
        s.out_u16_le(0);                        // compressed length

        // save end
        s.push_layer(0, 5);
        // rdp length
        s.pop_layer(2);
        s.out_u16_le(s.layer_subtract(5, 2));
        // mcs
        s.pop_layer(1);
        const userid = self.mcs_userid;
        const chanid = c.MCS_GLOBAL_CHANNEL;
        try mcs_out_header(s, s.layer_subtract(5, 1), userid, chanid);
        // iso
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(5, 0));
        // back to end
        s.pop_layer(5);
        const rv = try self.priv.send_slice_to_server(s.get_out_slice());
        try rv_to_err(rv);
    }

    //*************************************************************************
    // out
    fn send_control_cooperate(self: *rdpc_msg_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        const s = try parse.create(self.allocator, 8192);
        defer s.delete();
        try s.check_rem(7 + 8 + 2);
        s.push_layer(7, 0);
        s.push_layer(8, 1);
        s.push_layer(2, 2);
        // shareControlHeader: insert pdu type; 2 bytes
        // we support protocol version 1
        s.out_u16_le((1 << 4) | c.SCH_PDUTYPE_DATAPDU);
        // shareControlHeader: insert pdu source, i.e our channel ID; 2 bytes
        s.out_u16_le(self.mcs_userid);
        // insert share ID; 4 bytes
        s.out_u32_le(self.rdp_share_id);
        s.out_u8(0);                            // pad1
        s.out_u8(c.RDP_STREAM_MED);             // stream ID
        s.out_u16_le(0);                        // uncompressed length
        s.out_u8(c.RDP_PDUTYPE2_CONTROL);       // pduType2
        s.out_u8(0);                            // compressed type
        s.out_u16_le(0);                        // compressed length
        s.out_u16_le(c.RDP_CTRLACTION_COOPERATE);   // action
        s.out_u16_le(0);                        // grantID
        s.out_u32_le(0);                        // controlID
        // save end
        s.push_layer(0, 5);
        // rdp length
        s.pop_layer(2);
        s.out_u16_le(s.layer_subtract(5, 2));
        // mcs
        s.pop_layer(1);
        const userid = self.mcs_userid;
        const chanid = c.MCS_GLOBAL_CHANNEL;
        try mcs_out_header(s, s.layer_subtract(5, 1), userid, chanid);
        // iso
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(5, 0));
        // back to end
        s.pop_layer(5);
        const rv = try self.priv.send_slice_to_server(s.get_out_slice());
        try rv_to_err(rv);
    }

    //*************************************************************************
    // out
    fn send_control_req_control(self: *rdpc_msg_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        const s = try parse.create(self.allocator, 8192);
        defer s.delete();
        try s.check_rem(7 + 8 + 2);
        s.push_layer(7, 0);
        s.push_layer(8, 1);
        s.push_layer(2, 2);
        // shareControlHeader: insert pdu type; 2 bytes
        // we support protocol version 1
        s.out_u16_le((1 << 4) | c.SCH_PDUTYPE_DATAPDU);
        // shareControlHeader: insert pdu source, i.e our channel ID; 2 bytes
        s.out_u16_le(self.mcs_userid);
        // insert share ID; 4 bytes
        s.out_u32_le(self.rdp_share_id);
        s.out_u8(0);                            // pad1
        s.out_u8(c.RDP_STREAM_MED);             // stream ID
        s.out_u16_le(0);                        // uncompressed length
        s.out_u8(c.RDP_PDUTYPE2_CONTROL);       // pduType2
        s.out_u8(0);                            // compressed type
        s.out_u16_le(0);                        // compressed length
        s.out_u16_le(c.RDP_CTRLACTION_REQUEST_CONTROL); // action
        s.out_u16_le(0);                        // grantID
        s.out_u32_le(0);                        // controlID
        // save end
        s.push_layer(0, 5);
        // rdp length
        s.pop_layer(2);
        s.out_u16_le(s.layer_subtract(5, 2));
        // mcs
        s.pop_layer(1);
        const userid = self.mcs_userid;
        const chanid = c.MCS_GLOBAL_CHANNEL;
        try mcs_out_header(s, s.layer_subtract(5, 1), userid, chanid);
        // iso
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(5, 0));
        // back to end
        s.pop_layer(5);
        const rv = try self.priv.send_slice_to_server(s.get_out_slice());
        try rv_to_err(rv);
    }

    //*************************************************************************
    // out
    fn send_client_persistent_key_list(self: *rdpc_msg_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        const s = try parse.create(self.allocator, 8192);
        defer s.delete();
        try s.check_rem(7 + 8 + 2);
        s.push_layer(7, 0);
        s.push_layer(8, 1);
        s.push_layer(2, 2);
        // shareControlHeader: insert pdu type; 2 bytes
        // we support protocol version 1
        s.out_u16_le((1 << 4) | c.SCH_PDUTYPE_DATAPDU);
        // shareControlHeader: insert pdu source, i.e our channel ID; 2 bytes
        s.out_u16_le(self.mcs_userid);
        // insert share ID; 4 bytes
        s.out_u32_le(self.rdp_share_id);
        s.out_u8(0);                            // pad1
        s.out_u8(c.RDP_STREAM_MED);             // stream ID
        s.out_u16_le(0);                        // uncompressed length
        s.out_u8(c.RDP_PDUTYPE2_BITMAPCACHE_PERSISTENT_LIST);   // pduType2
        s.out_u8(0);                            // compressed type
        s.out_u16_le(0);                        // compressed length
        s.out_u16_le(0);                        // numEntriesCache0
        s.out_u16_le(1);                        // numEntriesCache1
        s.out_u16_le(2);                        // numEntriesCache2
        s.out_u16_le(3);                        // numEntriesCache3
        s.out_u16_le(4);                        // numEntriesCache4
        s.out_u16_le(0);                        // totalEntriesCache0
        s.out_u16_le(1);                        // totalEntriesCache1
        s.out_u16_le(2);                        // totalEntriesCache2
        s.out_u16_le(3);                        // totalEntriesCache3
        s.out_u16_le(4);                        // totalEntriesCache4
        s.out_u8(3);                            // bBitMask
        s.out_u8_skip(2);                       // padding
        // save end
        s.push_layer(0, 5);
        // rdp length
        s.pop_layer(2);
        s.out_u16_le(s.layer_subtract(5, 2));
        // mcs
        s.pop_layer(1);
        const userid = self.mcs_userid;
        const chanid = c.MCS_GLOBAL_CHANNEL;
        try mcs_out_header(s, s.layer_subtract(5, 1), userid, chanid);
        // iso
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(5, 0));
        // back to end
        s.pop_layer(5);
        const rv = try self.priv.send_slice_to_server(s.get_out_slice());
        try rv_to_err(rv);
    }

    //*************************************************************************
    // out
    fn send_client_font_list(self: *rdpc_msg_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        const s = try parse.create(self.allocator, 8192);
        defer s.delete();
        try s.check_rem(7 + 8 + 2);
        s.push_layer(7, 0); // iso
        s.push_layer(8, 1); // mcs
        s.push_layer(2, 2);
        // shareControlHeader: insert pdu type; 2 bytes
        // we support protocol version 1
        s.out_u16_le((1 << 4) | c.SCH_PDUTYPE_DATAPDU);
        // shareControlHeader: insert pdu source, i.e our channel ID; 2 bytes
        s.out_u16_le(self.mcs_userid);
        // insert share ID; 4 bytes
        s.out_u32_le(self.rdp_share_id);
        s.out_u8(0);                            // pad1
        s.out_u8(c.RDP_STREAM_MED);             // stream ID
        s.out_u16_le(0);                        // uncompressed length
        s.out_u8(c.RDP_PDUTYPE2_FONTLIST);      // pduType2
        s.out_u8(0);                            // compressed type
        s.out_u16_le(0);                        // compressed length
        s.out_u16_le(0);                        // numberFonts
        s.out_u16_le(0);                        // totalNumFonts
        s.out_u16_le(3);                        // listFlags
        s.out_u16_le(50);                       // entrysize
        // save end
        s.push_layer(0, 5);
        // rdp length
        s.pop_layer(2);
        s.out_u16_le(s.layer_subtract(5, 2));
        // mcs
        s.pop_layer(1);
        const userid = self.mcs_userid;
        const chanid = c.MCS_GLOBAL_CHANNEL;
        try mcs_out_header(s, s.layer_subtract(5, 1), userid, chanid);
        // iso
        s.pop_layer(0);
        try iso_out_data_header(s, s.layer_subtract(5, 0));
        // back to end
        s.pop_layer(5);
        const rv = try self.priv.send_slice_to_server(s.get_out_slice());
        try rv_to_err(rv);
    }

    //*************************************************************************
    // in
    fn process_rdp_data(self: *rdpc_msg_t, s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        _ = s;
    }

    //*************************************************************************
    // in
    fn process_rdp_fastpath_pdu(self: *rdpc_msg_t, s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        _ = s;
    }

    //*************************************************************************
    // in
    fn process_rdp_channel_pdu(self: *rdpc_msg_t, s: *parse.parse_t) !void
    {
        try self.priv.logln(@src(), "", .{});
        _ = s;
    }

};

//*****************************************************************************
pub fn create(allocator: *const std.mem.Allocator,
        priv: *rdpc_priv.rdpc_priv_t) !*rdpc_msg_t
{
    const msg = try allocator.create(rdpc_msg_t);
    msg.* = .{};
    msg.priv = priv;
    msg.allocator = allocator;
    return msg;
}

//*****************************************************************************
fn ber_out_header(s: *parse.parse_t, tagval: u16, length: u16) !void
{
    if (tagval > 0xFF)
    {
        try s.check_rem(2);
        s.out_u16_be(tagval);
    }
    else
    {
        try s.check_rem(1);
        s.out_u8(@truncate(tagval));
    }
    if (length >= 0x80)
    {
        try s.check_rem(3);
        s.out_u8(0x82);
        s.out_u16_be(length);
    }
    else
    {
        try s.check_rem(1);
        s.out_u8(@truncate(length));
    }
}

//*****************************************************************************
fn ber_in_header(s: *parse.parse_t, tagval: u16, length: *u16) !void
{
    var ltagval: u16 = undefined;
    var llength: u16 = undefined;
    if (tagval > 0xFF)
    {
        try s.check_rem(2);
        ltagval = s.in_u16_be();
    }
    else
    {
        try s.check_rem(1);
        ltagval = s.in_u8();
    }
    try err_if(ltagval != tagval, MsgError.BadTag);
    try s.check_rem(1);
    llength = s.in_u8();
    if ((llength & 0x80) != 0)
    {
        if (llength == 0x82)
        {
            try s.check_rem(2);
            length.* = s.in_u16_be();
        }
        else if (llength == 0x81)
        {
            try s.check_rem(1);
            length.* = s.in_u8();
        }
        else
        {
            return MsgError.BadParse;
        }
    }
    else
    {
        length.* = llength;
    }
}

//*****************************************************************************
fn ber_out_integer(s: *parse.parse_t, val: u16) !void
{
    try ber_out_header(s, c.BER_TAG_INTEGER, 2);
    try s.check_rem(2);
    s.out_u16_be(val);
}

//*****************************************************************************
fn iso_out_data_header(s: *parse.parse_t, length: u16) !void
{
    if (length < 7)
    {
        return MsgError.BadTag;
    }
    s.out_u8(3);            // version
    s.out_u8(0);            // reserved
    s.out_u16_be(length);
    s.out_u8(2);            // hdrlen
    s.out_u8(c.ISO_PDU_DT); // code - data 0xF0
    s.out_u8(0x80);         // eot
}

//*****************************************************************************
fn iso_in_data_header(s: *parse.parse_t, length: *u16) !void
{
    try s.check_rem(7);
    try err_if(s.in_u8() != 3, MsgError.BadVersion);  // version
    s.in_u8_skip(1);                // reserved
    const len = s.in_u16_be();
    try err_if(len < 7, MsgError.BadLength);
    s.in_u8_skip(1);                // hdrlen
    // code - data 0xF0
    try err_if(s.in_u8() != c.ISO_PDU_DT, MsgError.BadTag);
    s.in_u8_skip(1);                // eot
    length.* = len;
}

//*****************************************************************************
fn mcs_out_header(s: *parse.parse_t, length: u16,
        userid: u16, channel: u16) !void
{
    try err_if(length < 1, MsgError.BadTag);
    s.out_u8(c.MCS_SDRQ << 2);
    s.out_u16_be(userid);
    s.out_u16_be(channel);
    s.out_u8(0x70); // flags
    s.out_u16_be(0x8000 | (length - 8));
}

//*****************************************************************************
fn mcs_in_header(s: *parse.parse_t, length: *u16,
        userid: *u16, channel: *u16) !void
{
    try s.check_rem(7);
    const code = s.in_u8();
    try err_if(code != 0x68, MsgError.BadCode);
    userid.* = s.in_u16_be();
    channel.* = s.in_u16_be();
    const flags = s.in_u8();
    try err_if(flags != 0x70, MsgError.BadCode);
    var llength: u16 = s.in_u8();
    if ((llength & 0x80) != 0)
    {
        try s.check_rem(1);
        llength = (llength << 8) | s.in_u8();
        llength = llength & 0x7FFF;
    }
    length.* = llength;
}

//*****************************************************************************
fn mcs_out_domain_params(s: *parse.parse_t, max_channels: u16,
        max_users: u16, max_tokens: u16, max_pdusize: u16) !void
{
    try ber_out_header(s, c.MCS_TAG_DOMAIN_PARAMS, 32);
    try ber_out_integer(s, max_channels);
    try ber_out_integer(s, max_users);
    try ber_out_integer(s, max_tokens);
    try ber_out_integer(s, 1);          // num_priorities
    try ber_out_integer(s, 0);          // min_throughput
    try ber_out_integer(s, 1);          // max_height
    try ber_out_integer(s, max_pdusize);
    try ber_out_integer(s, 2);          // ver_protocol
}

//*****************************************************************************
fn mcs_in_domain_params(s: *parse.parse_t) !void
{
    var length: u16 = undefined;
    try ber_in_header(s, c.MCS_TAG_DOMAIN_PARAMS, &length);
    try s.check_rem(length);
    s.in_u8_skip(length);
}

//*****************************************************************************
// 2.2.1.11.1 Client Info PDU Data (CLIENT_INFO_PDU)
pub fn init_client_info_defaults(msg: *rdpc_msg_t,
        settings: *c.rdpc_settings_t) !void
{
    try msg.priv.logln(@src(), "", .{});
    const rdpc = &msg.priv.rdpc;
    var client_info = &rdpc.client_info;
    client_info.CodePage = 0;
    client_info.flags = c.RDP_INFO_MOUSE |
            c.RDP_INFO_DISABLECTRLALTDEL |
            c.RDP_INFO_UNICODE |
            c.RDP_INFO_MAXIMIZESHELL;
    var u32_array = std.ArrayList(u32).init(msg.allocator.*);
    defer u32_array.deinit();
    try strings.utf8_to_utf16Z_as_u8(&u32_array,
            std.mem.sliceTo(&settings.domain, 0),
            &client_info.Domain, &client_info.cbDomain);
    try strings.utf8_to_utf16Z_as_u8(&u32_array,
            std.mem.sliceTo(&settings.username, 0),
            &client_info.UserName, &client_info.cbUserName);
    try strings.utf8_to_utf16Z_as_u8(&u32_array,
            std.mem.sliceTo(&settings.password, 0),
            &client_info.Password, &client_info.cbPassword);
    try strings.utf8_to_utf16Z_as_u8(&u32_array,
            std.mem.sliceTo(&settings.altshell, 0),
            &client_info.AlternateShell, &client_info.cbAlternateShell);
    try strings.utf8_to_utf16Z_as_u8(&u32_array,
            std.mem.sliceTo(&settings.workingdir, 0),
            &client_info.WorkingDir, &client_info.cbWorkingDir);
}
