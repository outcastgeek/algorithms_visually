//! Chapter 5, Sections 5-3 and 5-4: Counting Leading and Trailing Zeros
//!
//! Count the number of leading (from MSB) or trailing (from LSB) zero bits.
//!
//! Reference: "Hacker's Delight" 2nd Ed., pp. 99-109
//!
//! Instructions: Implement using binary search (checking half the word
//! at a time, then a quarter, etc.) or using popcount tricks.

const std = @import("std");

/// Count leading zeros (number of 0-bits before the first 1-bit from the left).
///
/// Example: countLeadingZeros(0)          == 32
///          countLeadingZeros(1)          == 31
///          countLeadingZeros(0x80000000) == 0
///          countLeadingZeros(0xFF)       == 24
///
/// Hint (binary search approach): if the top 16 bits are zero, add 16 to count
/// and shift left by 16. Then check the top 8, add 8 if zero, shift. Repeat
/// for 4, 2, 1.
pub fn countLeadingZeros(x: u32) u6 {
    _ = x;
    @panic("TODO: implement countLeadingZeros");
}

/// Count trailing zeros (number of 0-bits after the last 1-bit from the right).
///
/// Example: countTrailingZeros(0)          == 32
///          countTrailingZeros(1)          == 0
///          countTrailingZeros(0x80000000) == 31
///          countTrailingZeros(0b01011000) == 3
///
/// Hint: ntz(x) = 32 - popcount(x | (x - 1)), or
///       ntz(x) = popcount(~x & (x - 1))
pub fn countTrailingZeros(x: u32) u6 {
    _ = x;
    @panic("TODO: implement countTrailingZeros");
}

// ============================================================
// Tests
// ============================================================

test "countLeadingZeros" {
    try std.testing.expectEqual(@as(u6, 32), countLeadingZeros(0));
    try std.testing.expectEqual(@as(u6, 31), countLeadingZeros(1));
    try std.testing.expectEqual(@as(u6, 0), countLeadingZeros(0x80000000));
    try std.testing.expectEqual(@as(u6, 24), countLeadingZeros(0xFF));
    try std.testing.expectEqual(@as(u6, 16), countLeadingZeros(0xFFFF));
    try std.testing.expectEqual(@as(u6, 0), countLeadingZeros(0xFFFFFFFF));
    try std.testing.expectEqual(@as(u6, 28), countLeadingZeros(0b1010));
    try std.testing.expectEqual(@as(u6, 1), countLeadingZeros(0x40000000));
}

test "countTrailingZeros" {
    try std.testing.expectEqual(@as(u6, 32), countTrailingZeros(0));
    try std.testing.expectEqual(@as(u6, 0), countTrailingZeros(1));
    try std.testing.expectEqual(@as(u6, 31), countTrailingZeros(0x80000000));
    try std.testing.expectEqual(@as(u6, 0), countTrailingZeros(0xFF));
    try std.testing.expectEqual(@as(u6, 3), countTrailingZeros(0b01011000));
    try std.testing.expectEqual(@as(u6, 0), countTrailingZeros(0xFFFFFFFF));
    try std.testing.expectEqual(@as(u6, 4), countTrailingZeros(0b10110000));
    try std.testing.expectEqual(@as(u6, 2), countTrailingZeros(12));
}
