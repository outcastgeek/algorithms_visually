//! Chapter 3, Section 3-2: Rounding to a Power of 2
//!
//! Round integers up or down to the nearest power of 2.
//! The technique: right-propagate the highest set bit (the "bit flood"),
//! then adjust.
//!
//! Reference: "Hacker's Delight" 2nd Ed., pp. 59-66
//!
//! Instructions: Implement using shifts and OR to flood bits rightward.
//! No loops needed -- five shift+OR steps cover all 32 bits.

const std = @import("std");

/// Round up to the next power of 2 (or return x if already a power of 2).
/// Returns 0 for input 0.
///
/// Example: roundUpToPow2(5)  == 8
///          roundUpToPow2(8)  == 8
///          roundUpToPow2(1)  == 1
///          roundUpToPow2(13) == 16
///
/// Hint: subtract 1, then flood rightward with OR-shifts (1, 2, 4, 8, 16),
///       then add 1.
pub fn roundUpToPow2(x: u32) u32 {
    _ = x;
    @panic("TODO: implement roundUpToPow2");
}

/// Round down to the previous power of 2 (or return x if already a power of 2).
/// Returns 0 for input 0.
///
/// Example: roundDownToPow2(5)  == 4
///          roundDownToPow2(8)  == 8
///          roundDownToPow2(13) == 8
///          roundDownToPow2(1)  == 1
///
/// Hint: flood rightward with OR-shifts, then subtract half.
pub fn roundDownToPow2(x: u32) u32 {
    _ = x;
    @panic("TODO: implement roundDownToPow2");
}

/// Floor of log base 2 (position of the highest set bit, 0-indexed).
/// Undefined for input 0.
///
/// Example: floorLog2(1)  == 0
///          floorLog2(8)  == 3
///          floorLog2(15) == 3
///          floorLog2(16) == 4
///
/// Hint: use roundDownToPow2 or a binary search approach.
pub fn floorLog2(x: u32) u5 {
    _ = x;
    @panic("TODO: implement floorLog2");
}

// ============================================================
// Tests
// ============================================================

test "roundUpToPow2" {
    try std.testing.expectEqual(@as(u32, 0), roundUpToPow2(0));
    try std.testing.expectEqual(@as(u32, 1), roundUpToPow2(1));
    try std.testing.expectEqual(@as(u32, 2), roundUpToPow2(2));
    try std.testing.expectEqual(@as(u32, 4), roundUpToPow2(3));
    try std.testing.expectEqual(@as(u32, 8), roundUpToPow2(5));
    try std.testing.expectEqual(@as(u32, 8), roundUpToPow2(8));
    try std.testing.expectEqual(@as(u32, 16), roundUpToPow2(9));
    try std.testing.expectEqual(@as(u32, 16), roundUpToPow2(13));
    try std.testing.expectEqual(@as(u32, 256), roundUpToPow2(200));
    try std.testing.expectEqual(@as(u32, 0x80000000), roundUpToPow2(0x80000000));
}

test "roundDownToPow2" {
    try std.testing.expectEqual(@as(u32, 0), roundDownToPow2(0));
    try std.testing.expectEqual(@as(u32, 1), roundDownToPow2(1));
    try std.testing.expectEqual(@as(u32, 2), roundDownToPow2(2));
    try std.testing.expectEqual(@as(u32, 2), roundDownToPow2(3));
    try std.testing.expectEqual(@as(u32, 4), roundDownToPow2(5));
    try std.testing.expectEqual(@as(u32, 8), roundDownToPow2(8));
    try std.testing.expectEqual(@as(u32, 8), roundDownToPow2(13));
    try std.testing.expectEqual(@as(u32, 128), roundDownToPow2(200));
    try std.testing.expectEqual(@as(u32, 0x80000000), roundDownToPow2(0xFFFFFFFF));
}

test "floorLog2" {
    try std.testing.expectEqual(@as(u5, 0), floorLog2(1));
    try std.testing.expectEqual(@as(u5, 1), floorLog2(2));
    try std.testing.expectEqual(@as(u5, 1), floorLog2(3));
    try std.testing.expectEqual(@as(u5, 3), floorLog2(8));
    try std.testing.expectEqual(@as(u5, 3), floorLog2(15));
    try std.testing.expectEqual(@as(u5, 4), floorLog2(16));
    try std.testing.expectEqual(@as(u5, 7), floorLog2(200));
    try std.testing.expectEqual(@as(u5, 31), floorLog2(0xFFFFFFFF));
}
