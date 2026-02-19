//! Chapter 2, Section 2-4: Absolute Value Function
//!
//! Branchless absolute value using bit manipulation.
//! The key insight: arithmetic right shift of a signed integer by 31
//! produces a mask that is all-0s for positive, all-1s for negative.
//!
//! Reference: "Hacker's Delight" 2nd Ed., pp. 18-19
//!
//! Instructions: Implement using ONLY bitwise operations and arithmetic.
//! No if/else, no ternary, no branches. Each should be 1-2 expressions.

const std = @import("std");

/// Branchless absolute value.
///
/// Example: branchlessAbs(5)  == 5
///          branchlessAbs(-5) == 5
///          branchlessAbs(0)  == 0
///
/// Hint: arithmetic right shift by 31 creates a mask:
///   positive numbers -> mask = 0x00000000 (all zeros)
///   negative numbers -> mask = 0xFFFFFFFF (all ones)
/// Then XOR with the mask and subtract the mask.
pub fn branchlessAbs(x: i32) i32 {
    _ = x;
    @panic("TODO: implement branchlessAbs");
}

/// Branchless negative absolute value (always returns <= 0).
///
/// Example: branchlessNabs(5)  == -5
///          branchlessNabs(-5) == -5
///          branchlessNabs(0)  == 0
///
/// Hint: similar to branchlessAbs but with the operations inverted.
/// Advantage: nabs(INT_MIN) is well-defined, while abs(INT_MIN) overflows.
pub fn branchlessNabs(x: i32) i32 {
    _ = x;
    @panic("TODO: implement branchlessNabs");
}

// ============================================================
// Tests
// ============================================================

test "branchlessAbs" {
    try std.testing.expectEqual(@as(i32, 0), branchlessAbs(0));
    try std.testing.expectEqual(@as(i32, 1), branchlessAbs(1));
    try std.testing.expectEqual(@as(i32, 1), branchlessAbs(-1));
    try std.testing.expectEqual(@as(i32, 42), branchlessAbs(42));
    try std.testing.expectEqual(@as(i32, 42), branchlessAbs(-42));
    try std.testing.expectEqual(@as(i32, 2147483647), branchlessAbs(2147483647));
    try std.testing.expectEqual(@as(i32, 2147483647), branchlessAbs(-2147483647));
}

test "branchlessNabs" {
    try std.testing.expectEqual(@as(i32, 0), branchlessNabs(0));
    try std.testing.expectEqual(@as(i32, -1), branchlessNabs(1));
    try std.testing.expectEqual(@as(i32, -1), branchlessNabs(-1));
    try std.testing.expectEqual(@as(i32, -42), branchlessNabs(42));
    try std.testing.expectEqual(@as(i32, -42), branchlessNabs(-42));
    try std.testing.expectEqual(@as(i32, -2147483647), branchlessNabs(2147483647));
    try std.testing.expectEqual(@as(i32, -2147483647), branchlessNabs(-2147483647));
    // nabs(INT_MIN) is well-defined:
    try std.testing.expectEqual(@as(i32, -2147483648), branchlessNabs(-2147483648));
}
