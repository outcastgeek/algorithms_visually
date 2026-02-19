//! Chapter 2, Section 2-1: Manipulating Rightmost Bits
//!
//! These are the fundamental building blocks of bit manipulation.
//! Each function operates on a single 32-bit unsigned word.
//!
//! Reference: "Hacker's Delight" 2nd Ed., pp. 11-15
//!
//! Instructions: Implement each function using ONLY bitwise operations
//! and arithmetic (+, -, &, |, ^, ~). No loops, no branches.
//! Each function should be a single expression.
//!
//! To try alternate implementations, add _v2, _v3 suffixed functions
//! below the original. The tests validate the primary function.

const std = @import("std");

// ============================================================
// Section 2-1: Rightmost Bit Operations
// ============================================================

/// Turn off the rightmost 1-bit in x.
///
/// Example: 0b01011000 -> 0b01010000
///          0b00000001 -> 0b00000000
///
/// Hint: involves (x - 1)
/// Use: test if x is a power of 2 (result == 0 means yes)
pub fn turnOffLowestBit(x: u32) u32 {
    _ = x;
    @panic("TODO: implement turnOffLowestBit");
}

/// Turn on the rightmost 0-bit in x.
///
/// Example: 0b10100111 -> 0b10101111
///          0b01010100 -> 0b01010101
///
/// Hint: involves (x + 1)
pub fn turnOnLowestZeroBit(x: u32) u32 {
    _ = x;
    @panic("TODO: implement turnOnLowestZeroBit");
}

/// Isolate the rightmost 1-bit (all other bits become 0).
///
/// Example: 0b01011000 -> 0b00001000
///          0b01010100 -> 0b00000100
///
/// Hint: involves negation
/// Use: Fenwick trees, memory allocators, finding lowest priority
pub fn isolateLowestBit(x: u32) u32 {
    _ = x;
    @panic("TODO: implement isolateLowestBit");
}

/// Isolate the rightmost 0-bit (result has a single 1 where x had its rightmost 0).
///
/// Example: 0b10100111 -> 0b00001000
///          0b11111110 -> 0b00000001
///
/// Hint: involves complement (~x)
pub fn isolateLowestZeroBit(x: u32) u32 {
    _ = x;
    @panic("TODO: implement isolateLowestZeroBit");
}

/// Create a mask from the rightmost 1-bit down through all trailing zeros.
///
/// Example: 0b01011000 -> 0b00001111
///          0b01010100 -> 0b00000111
///          0b00000001 -> 0b00000001
///
/// Hint: involves (x - 1) and XOR
pub fn maskFromLowestBit(x: u32) u32 {
    _ = x;
    @panic("TODO: implement maskFromLowestBit");
}

/// Turn off trailing 1-bits.
///
/// Example: 0b10100111 -> 0b10100000
///          0b11111111 -> 0b00000000
///          0b10101000 -> 0b10101000 (no trailing 1s, unchanged)
///
/// Hint: involves (x + 1)
/// Use: test if x is of the form 2^n - 1 (result == 0 means yes)
pub fn turnOffTrailingOnes(x: u32) u32 {
    _ = x;
    @panic("TODO: implement turnOffTrailingOnes");
}

/// Turn on trailing 0-bits.
///
/// Example: 0b10101000 -> 0b10101111
///          0b01010111 -> 0b01010111 (no trailing 0s, unchanged)
///
/// Hint: involves (x - 1)
pub fn turnOnTrailingZeros(x: u32) u32 {
    _ = x;
    @panic("TODO: implement turnOnTrailingZeros");
}

/// Test if x is a power of 2 (exactly one bit set).
/// Returns false for 0, true for 1, 2, 4, 8, ...
///
/// Hint: a power of 2 has exactly one bit set;
///       turning off that bit gives zero.
pub fn isPowerOfTwo(x: u32) bool {
    _ = x;
    @panic("TODO: implement isPowerOfTwo");
}

// ============================================================
// Tests
// ============================================================

test "turnOffLowestBit" {
    try std.testing.expectEqual(@as(u32, 0b01010000), turnOffLowestBit(0b01011000));
    try std.testing.expectEqual(@as(u32, 0b01010000), turnOffLowestBit(0b01010100));
    try std.testing.expectEqual(@as(u32, 0), turnOffLowestBit(0b00000001));
    try std.testing.expectEqual(@as(u32, 0), turnOffLowestBit(0b10000000_00000000_00000000_00000000));
    try std.testing.expectEqual(@as(u32, 0b11111110), turnOffLowestBit(0b11111111));
    try std.testing.expectEqual(@as(u32, 0), turnOffLowestBit(0));
    try std.testing.expectEqual(@as(u32, 0), turnOffLowestBit(16));
    try std.testing.expectEqual(@as(u32, 0), turnOffLowestBit(1024));
}

test "turnOnLowestZeroBit" {
    try std.testing.expectEqual(@as(u32, 0b10101111), turnOnLowestZeroBit(0b10100111));
    try std.testing.expectEqual(@as(u32, 0b01010101), turnOnLowestZeroBit(0b01010100));
    try std.testing.expectEqual(@as(u32, 0b00000001), turnOnLowestZeroBit(0b00000000));
    try std.testing.expectEqual(@as(u32, 0b11111111), turnOnLowestZeroBit(0b01111111));
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), turnOnLowestZeroBit(0b01111111_11111111_11111111_11111111));
}

test "isolateLowestBit" {
    try std.testing.expectEqual(@as(u32, 0b00001000), isolateLowestBit(0b01011000));
    try std.testing.expectEqual(@as(u32, 0b00000100), isolateLowestBit(0b01010100));
    try std.testing.expectEqual(@as(u32, 0b00000001), isolateLowestBit(0b11111111));
    try std.testing.expectEqual(@as(u32, 0), isolateLowestBit(0));
    try std.testing.expectEqual(@as(u32, 64), isolateLowestBit(64));
    try std.testing.expectEqual(@as(u32, 2), isolateLowestBit(0b10101010));
}

test "isolateLowestZeroBit" {
    try std.testing.expectEqual(@as(u32, 0b00001000), isolateLowestZeroBit(0b10100111));
    try std.testing.expectEqual(@as(u32, 0b00000001), isolateLowestZeroBit(0b11111110));
    try std.testing.expectEqual(@as(u32, 0b00000001), isolateLowestZeroBit(0));
    try std.testing.expectEqual(@as(u32, 0b00000010), isolateLowestZeroBit(0b11111101));
    try std.testing.expectEqual(@as(u32, 0), isolateLowestZeroBit(0xFFFFFFFF));
}

test "maskFromLowestBit" {
    try std.testing.expectEqual(@as(u32, 0b00001111), maskFromLowestBit(0b01011000));
    try std.testing.expectEqual(@as(u32, 0b00000111), maskFromLowestBit(0b01010100));
    try std.testing.expectEqual(@as(u32, 0b00000001), maskFromLowestBit(0b11111111));
    try std.testing.expectEqual(@as(u32, 0b00000001), maskFromLowestBit(0b00000001));
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), maskFromLowestBit(0b10000000_00000000_00000000_00000000));
    // Edge case: x=0 has no rightmost 1-bit; formula yields all-ones
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), maskFromLowestBit(0));
}

test "turnOffTrailingOnes" {
    try std.testing.expectEqual(@as(u32, 0b10100000), turnOffTrailingOnes(0b10100111));
    try std.testing.expectEqual(@as(u32, 0), turnOffTrailingOnes(0b11111111));
    try std.testing.expectEqual(@as(u32, 0b10101000), turnOffTrailingOnes(0b10101000));
    try std.testing.expectEqual(@as(u32, 0), turnOffTrailingOnes(0));
    try std.testing.expectEqual(@as(u32, 0), turnOffTrailingOnes(0xFFFFFFFF));
}

test "turnOnTrailingZeros" {
    try std.testing.expectEqual(@as(u32, 0b10101111), turnOnTrailingZeros(0b10101000));
    try std.testing.expectEqual(@as(u32, 0b01010111), turnOnTrailingZeros(0b01010111));
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), turnOnTrailingZeros(0));
    try std.testing.expectEqual(@as(u32, 0b11111111), turnOnTrailingZeros(0b11111111));
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), turnOnTrailingZeros(0b10000000_00000000_00000000_00000000));
}

test "isPowerOfTwo" {
    try std.testing.expect(!isPowerOfTwo(0));
    try std.testing.expect(isPowerOfTwo(1));
    try std.testing.expect(isPowerOfTwo(2));
    try std.testing.expect(isPowerOfTwo(4));
    try std.testing.expect(isPowerOfTwo(1024));
    try std.testing.expect(isPowerOfTwo(0x80000000));
    try std.testing.expect(!isPowerOfTwo(3));
    try std.testing.expect(!isPowerOfTwo(6));
    try std.testing.expect(!isPowerOfTwo(255));
    try std.testing.expect(!isPowerOfTwo(0xFFFFFFFF));
}
