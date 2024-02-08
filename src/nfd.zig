//! Zig bindings/wrapper for nativefiledialog-extended
//!
//! TODO:
//! - Custom allocator

const builtin = @import("builtin");
const std = @import("std");

const options = @import("build_options");

const force_utf8 = (options.native_char_encoding == false and builtin.os.tag == .windows);

const nfdresult_t = c_int;

const nfdnchar_t = switch (builtin.target.os.tag) {
    .windows => std.os.windows.WCHAR,
    else => u8,
};

const nfdu8char_t = u8;

const nfdnfilteritem_t = extern struct {
    name: [*:0]const nfdnchar_t,
    spec: [*:0]const nfdnchar_t,
};

const nfdu8filteritem_t = extern struct {
    name: [*:0]const nfdu8char_t,
    spec: [*:0]const nfdu8char_t,
};

const nfdfiltersize_t = c_uint;

pub const Char = if (force_utf8) nfdu8char_t else nfdnchar_t;

pub const FilterItem = if (force_utf8) nfdu8filteritem_t else nfdnfilteritem_t;

pub const Result = enum(nfdresult_t) {
    /// programmatic error
    @"error",
    /// user pressed okay, or successful return
    okay,
    //// user pressed cancel
    cancel,
};

/// free a file path that was returned by the dialogs
/// Note: use `pathSetFreePath` to free path from pathset instead of this function
pub fn freePath(path: [*:0]Char) void {
    NFD_FreePath(path);
}
const NFD_FreePath = if (force_utf8) NFD_FreePathU8 else NFD_FreePathN;
extern fn NFD_FreePathN([*:0]nfdnchar_t) void;
extern fn NFD_FreePathU8([*:0]nfdu8char_t) void;

/// initialize NFD - call this for every thread that might use NFD, before calling any other NFD
/// functions on that thread
pub fn init() Result {
    return @enumFromInt(NFD_Init());
}
extern fn NFD_Init() callconv(.C) nfdresult_t;

/// call this to de-initialize NFD, if NFD_Init returned NFD_OKAY
pub const quit = NFD_Quit;
extern fn NFD_Quit() callconv(.C) void;

/// single file open dialog
/// It is the caller's responsibility to free `out_path` via freePath() if this function returns
/// NFD_OKAY
/// If default_path is null, the operating system will decide */
pub fn openDialog(
    out_path: *[*:0]Char,
    filter_list: []const FilterItem,
    maybe_default_path: ?[:0]Char,
) Result {
    return @enumFromInt(NFD_OpenDialog(
        out_path,
        if (filter_list.len > 0) filter_list.ptr else null,
        @intCast(filter_list.len),
        if (maybe_default_path) |default_path| default_path.ptr else null,
    ));
}
const NFD_OpenDialog = if (force_utf8) NFD_OpenDialogU8 else NFD_OpenDialogN;
extern fn NFD_OpenDialogN(
    outPath: ?*[*:0]nfdnchar_t,
    filterList: ?[*]const nfdnfilteritem_t,
    filterCount: nfdfiltersize_t,
    defaultPath: ?[*:0]const nfdnchar_t,
) callconv(.C) nfdresult_t;
extern fn NFD_OpenDialogU8(
    outPath: ?*[*:0]nfdu8char_t,
    filterList: ?[*]const nfdu8filteritem_t,
    filterCount: nfdfiltersize_t,
    defaultPath: ?[*:0]const nfdu8char_t,
) callconv(.C) nfdresult_t;

/// save dialog
/// It is the caller's responsibility to free `out_path` via `freePath`
/// NFD_OKAY
/// If `default_path` is null, the operating system will decide
pub fn saveDialog(
    out_path: *[*:0]Char,
    filter_list: []const FilterItem,
    maybe_default_path: ?[:0]Char,
    maybe_default_name: ?[:0]Char,
) Result {
    return @enumFromInt(NFD_SaveDialog(
        out_path,
        if (filter_list.len > 0) filter_list.ptr else null,
        @intCast(filter_list.len),
        if (maybe_default_path) |default_path| default_path.ptr else null,
        if (maybe_default_name) |default_name| default_name.ptr else null,
    ));
}
const NFD_SaveDialog = if (force_utf8) NFD_SaveDialogU8 else NFD_SaveDialogN;
extern fn NFD_SaveDialogN(
    outPath: ?*[*:0]nfdnchar_t,
    filterList: ?[*]const nfdnfilteritem_t,
    filterCount: nfdfiltersize_t,
    defaultPath: ?[*:0]const nfdnchar_t,
    defaultName: ?[*:0]const nfdnchar_t,
) callconv(.C) nfdresult_t;
extern fn NFD_SaveDialogU8(
    outPath: ?*[*:0]nfdu8char_t,
    filterList: ?[*]const nfdu8filteritem_t,
    filterCount: nfdfiltersize_t,
    defaultPath: ?[*:0]const nfdu8char_t,
    defaultName: ?[*:0]const nfdu8char_t,
) callconv(.C) nfdresult_t;

/// Get last error -- set when nfdresult_t returns NFD_ERROR
/// Returns the last error that was set, or null if there is no error.
/// The memory is owned by NFD and should not be freed by user code.
/// This is *always* ASCII printable characters, so it can be interpreted as UTF-8 without any
/// conversion.
pub fn getError() ?[]const u8 {
    if (NFD_GetError()) |err_string| {
        return std.mem.span(err_string);
    }
    return null;
}
extern fn NFD_GetError() ?[*:0]u8;

/// clear the error
pub const clearError = NFD_ClearError;
extern fn NFD_ClearError() void;
