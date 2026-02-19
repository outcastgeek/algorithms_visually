//! Chapter 13: Gray Code
//!
//! Gray code is a binary encoding where consecutive values differ
//! in exactly one bit. This minimizes transition errors in hardware
//! (rotary encoders, ADC) and creates smooth motion patterns.
//!
//! Reference: "Hacker's Delight" 2nd Ed., pp. 311-318
//!
//! Instructions: binaryToGray is a single expression.
//! grayToBinary requires a parallel prefix XOR (multiple steps).

const std = @import("std");

/// Convert a standard binary number to Gray code.
///
/// Example: binaryToGray(0) == 0
///          binaryToGray(1) == 1
///          binaryToGray(2) == 3  (0b10 -> 0b11)
///          binaryToGray(3) == 2  (0b11 -> 0b10)
///          binaryToGray(4) == 6  (0b100 -> 0b110)
///
/// Hint: a single XOR with a shifted version of x.
pub fn binaryToGray(x: u32) u32 {
    _ = x;
    @panic("TODO: implement binaryToGray");
}

/// Convert a Gray code number back to standard binary.
///
/// Example: grayToBinary(0) == 0
///          grayToBinary(1) == 1
///          grayToBinary(3) == 2  (0b11 -> 0b10)
///          grayToBinary(2) == 3  (0b10 -> 0b11)
///          grayToBinary(6) == 4  (0b110 -> 0b100)
///
/// Hint: parallel prefix XOR. XOR g with shifted versions of itself:
///   g ^= (g >> 1); g ^= (g >> 2); g ^= (g >> 4); ... up to >> 16
pub fn grayToBinary(g: u32) u32 {
    _ = g;
    @panic("TODO: implement grayToBinary");
}

// ============================================================
// Tests
// ============================================================

test "binaryToGray" {
    try std.testing.expectEqual(@as(u32, 0), binaryToGray(0));
    try std.testing.expectEqual(@as(u32, 1), binaryToGray(1));
    try std.testing.expectEqual(@as(u32, 3), binaryToGray(2));
    try std.testing.expectEqual(@as(u32, 2), binaryToGray(3));
    try std.testing.expectEqual(@as(u32, 6), binaryToGray(4));
    try std.testing.expectEqual(@as(u32, 7), binaryToGray(5));
    try std.testing.expectEqual(@as(u32, 5), binaryToGray(6));
    try std.testing.expectEqual(@as(u32, 4), binaryToGray(7));
    try std.testing.expectEqual(@as(u32, 12), binaryToGray(8));
    // Full byte: 0xFF -> 0x80
    try std.testing.expectEqual(@as(u32, 0x80), binaryToGray(0xFF));
}

test "grayToBinary" {
    try std.testing.expectEqual(@as(u32, 0), grayToBinary(0));
    try std.testing.expectEqual(@as(u32, 1), grayToBinary(1));
    try std.testing.expectEqual(@as(u32, 2), grayToBinary(3));
    try std.testing.expectEqual(@as(u32, 3), grayToBinary(2));
    try std.testing.expectEqual(@as(u32, 4), grayToBinary(6));
    try std.testing.expectEqual(@as(u32, 5), grayToBinary(7));
    try std.testing.expectEqual(@as(u32, 6), grayToBinary(5));
    try std.testing.expectEqual(@as(u32, 7), grayToBinary(4));
    try std.testing.expectEqual(@as(u32, 8), grayToBinary(12));
    try std.testing.expectEqual(@as(u32, 0xFF), grayToBinary(0x80));
}

test "roundtrip: binary -> gray -> binary" {
    // Every value 0..255 should survive a roundtrip
    var i: u32 = 0;
    while (i < 256) : (i += 1) {
        try std.testing.expectEqual(i, grayToBinary(binaryToGray(i)));
    }
}

test "gray code: consecutive values differ by one bit" {
    var i: u32 = 0;
    while (i < 255) : (i += 1) {
        const g1 = binaryToGray(i);
        const g2 = binaryToGray(i + 1);
        const diff = g1 ^ g2;
        // diff should be a power of 2 (exactly one bit different)
        try std.testing.expect(diff != 0 and (diff & (diff - 1)) == 0);
    }
}
