//! Chapter 7, Section 7-1: Reversing Bits and Bytes
//!
//! Reverse the bit order of a word using recursive swap:
//! swap halves, then quarters, then eighths, etc.
//!
//! Reference: "Hacker's Delight" 2nd Ed., pp. 129-134
//!
//! Instructions: Use mask-shift-OR to swap at each level.
//! Five steps: swap adjacent bits, pairs, nibbles, bytes, halfwords.

const std = @import("std");

/// Reverse all 32 bits of x (bit 0 becomes bit 31, etc.).
///
/// Example: reverseBits(0b00000001) == 0x80000000
///          reverseBits(0b10110000_00000000_00000000_00000000) == 0b00000000_00000000_00000000_00001101
///
/// Hint: five steps with masks 0x55555555, 0x33333333, 0x0F0F0F0F, 0x00FF00FF:
///   Step 1: swap adjacent bits       (1-bit groups)
///   Step 2: swap adjacent pairs      (2-bit groups)
///   Step 3: swap adjacent nibbles    (4-bit groups)
///   Step 4: swap adjacent bytes      (8-bit groups)
///   Step 5: swap halfwords           (16-bit groups)
pub fn reverseBits(x: u32) u32 {
    _ = x;
    @panic("TODO: implement reverseBits");
}

/// Reverse the byte order of x (byte 0 becomes byte 3, etc.).
///
/// Example: reverseBytes(0x12345678) == 0x78563412
///          reverseBytes(0x000000FF) == 0xFF000000
///
/// Hint: only the last two steps of reverseBits (swap bytes, swap halfwords),
///       or shift-and-mask directly.
pub fn reverseBytes(x: u32) u32 {
    _ = x;
    @panic("TODO: implement reverseBytes");
}

// ============================================================
// Tests
// ============================================================

test "reverseBits" {
    try std.testing.expectEqual(@as(u32, 0), reverseBits(0));
    try std.testing.expectEqual(@as(u32, 0x80000000), reverseBits(1));
    try std.testing.expectEqual(@as(u32, 1), reverseBits(0x80000000));
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), reverseBits(0xFFFFFFFF));
    try std.testing.expectEqual(@as(u32, 0xF0000000), reverseBits(0x0000000F));
    try std.testing.expectEqual(@as(u32, 0x0000000F), reverseBits(0xF0000000));
    // Palindrome: 0b1001...1001
    try std.testing.expectEqual(@as(u32, 0x55555555), reverseBits(0xAAAAAAAA));
    try std.testing.expectEqual(@as(u32, 0xAAAAAAAA), reverseBits(0x55555555));
}

test "reverseBytes" {
    try std.testing.expectEqual(@as(u32, 0), reverseBytes(0));
    try std.testing.expectEqual(@as(u32, 0x78563412), reverseBytes(0x12345678));
    try std.testing.expectEqual(@as(u32, 0xFF000000), reverseBytes(0x000000FF));
    try std.testing.expectEqual(@as(u32, 0x000000FF), reverseBytes(0xFF000000));
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), reverseBytes(0xFFFFFFFF));
    try std.testing.expectEqual(@as(u32, 0x01000000), reverseBytes(1));
    try std.testing.expectEqual(@as(u32, 0xEFBEADDE), reverseBytes(0xDEADBEEF));
}
