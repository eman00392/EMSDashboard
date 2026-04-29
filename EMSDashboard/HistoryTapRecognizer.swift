//
//  HistoryTapRecognizer.swift
//  EMSDashboard
//
//  Created by Ethan Bernstein on 4/25/26.
//
import UIKit

// UITapGestureRecognizer subclass that carries the call record
// so the handler knows which history card was tapped.

class HistoryTapRecognizer: UITapGestureRecognizer {
    var record: EMSCallRecord?
}
