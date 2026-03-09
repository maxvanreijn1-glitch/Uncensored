//
//  ViewExtensions.swift
//  Uncensored
//

import SwiftUI

// MARK: - Backward-compatible onChange

/// Internal modifier that fires an action when a value changes.
/// Uses `task(id:)` (iOS 15+) instead of the `onChange(of:perform:)` API
/// that was deprecated in iOS 17, eliminating the deprecation warning while
/// maintaining iOS 16 compatibility.
private struct ValueChangeModifier<T: Equatable>: ViewModifier {
    let value: T
    let action: (T) -> Void
    @State private var isInitial = true

    func body(content: Content) -> some View {
        content.task(id: value) {
            // Skip the first fire which happens on view appear.
            // Subsequent fires mean the value actually changed.
            guard !isInitial else { isInitial = false; return }
            // Note: task(id:) automatically cancels any previously running task for this
            // view before starting a new one when `value` changes, so there is no risk of
            // concurrent executions of `action`. All callers in this codebase pass
            // synchronous (or Task-launching) closures, so no additional cancellation
            // handling is needed.
            action(value)
        }
    }
}

extension View {
    /// Adds an action to perform when the given value changes.
    /// Compatible with iOS 16+ without triggering the `onChange(of:perform:)` deprecation warning.
    func onValueChange<T: Equatable>(
        of value: T,
        perform action: @escaping (T) -> Void
    ) -> some View {
        modifier(ValueChangeModifier(value: value, action: action))
    }
}
