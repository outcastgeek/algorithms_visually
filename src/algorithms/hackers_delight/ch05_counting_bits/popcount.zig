//! Chapter 5, Section 5-1: Population Count (Hamming Weight)
//!
//! Count the number of 1-bits in a word. Also known as "popcount"
//! or "Hamming weight."
//!
//! Reference: "Hacker's Delight" 2nd Ed., pp. 81-96
//!
//! Instructions: Implement the divide-and-conquer version that
//! processes bits in parallel -- pairs, nibbles, bytes, halfwords, word.
//! Use the magic constants 0x55555555, 0x33333333, 0x0F0F0F0F, etc.

const std = @import("std");

/// Count the number of 1-bits in x using divide-and-conquer.
///
/// Example: popcount(0b00000000) == 0
///          popcount(0b11111111) == 8
///          popcount(0b10101010) == 4
///          popcount(0xFFFFFFFF) == 32
///
/// Hint: sum adjacent pairs, then nibbles, then bytes, then halfwords.
///   Step 1: x = (x & 0x55555555) + ((x >> 1) & 0x55555555)  -- pairs
///   Step 2: x = (x & 0x33333333) + ((x >> 2) & 0x33333333)  -- nibbles
///   Step 3: ... continue doubling the group size
pub fn popcount(x: u32) u6 {
    _ = x;
    @panic("TODO: implement popcount");
}

/// Naive loop-based popcount for comparison.
/// Count bits by checking and shifting one at a time.
///
/// Hint: loop 32 times, check lowest bit with (x & 1), shift right.
pub fn popcountNaive(x: u32) u6 {
    _ = x;
    @panic("TODO: implement popcountNaive");
}

// ============================================================
// Tests
// ============================================================

test "popcount" {
    try std.testing.expectEqual(@as(u6, 0), popcount(0));
    try std.testing.expectEqual(@as(u6, 1), popcount(1));
    try std.testing.expectEqual(@as(u6, 1), popcount(0x80000000));
    try std.testing.expectEqual(@as(u6, 8), popcount(0xFF));
    try std.testing.expectEqual(@as(u6, 16), popcount(0xFFFF));
    try std.testing.expectEqual(@as(u6, 32), popcount(0xFFFFFFFF));
    try std.testing.expectEqual(@as(u6, 4), popcount(0b10101010));
    try std.testing.expectEqual(@as(u6, 16), popcount(0x55555555));
    try std.testing.expectEqual(@as(u6, 16), popcount(0xAAAAAAAA));
    try std.testing.expectEqual(@as(u6, 3), popcount(0b10110000));
}

test "popcountNaive" {
    try std.testing.expectEqual(@as(u6, 0), popcountNaive(0));
    try std.testing.expectEqual(@as(u6, 1), popcountNaive(1));
    try std.testing.expectEqual(@as(u6, 32), popcountNaive(0xFFFFFFFF));
    try std.testing.expectEqual(@as(u6, 4), popcountNaive(0b10101010));
    try std.testing.expectEqual(@as(u6, 16), popcountNaive(0x55555555));
    try std.testing.expectEqual(@as(u6, 3), popcountNaive(0b10110000));
}
