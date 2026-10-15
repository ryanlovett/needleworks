//
//  DesignSettings.swift
//  Needle Works
//
//  Copyright 2026 Ryan Lovett <ryan@spacecoaster.org>. All rights reserved.
//  
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//  
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//   
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
//  02111-1307, USA.


import AppKit
import CryptoKit
import NeedleWorksKit

/// The choices made for a design's window, remembered for the next time it's
/// opened. Choices not made are nil, and the window follows Settings for them.
///
/// Needle Works never writes to design files, so the choices are kept in its
/// own preferences, keyed by a fingerprint of the file's contents. They follow
/// a design that's moved or renamed, and a copy opens the same way. Only the
/// designs used most recently are kept.
struct DesignSettings: Equatable {
	var fabric: Fabric?
	var stitchStyle: StitchStyle?
	var lineWidth: CGFloat?
	var showJumpStitches: Bool?

	/// The user defaults key, and how many designs are remembered
	private static let key = "designSettings"
	private static let limit = 500

	/// A design file's fingerprint: the SHA-256 hash of its contents
	static func fingerprint(of data: Data) -> String {
		SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
	}

	/// The choices remembered for a design, or none
	static func load(for fingerprint: String) -> DesignSettings {
		guard let entry = UserDefaults.standard.dictionary(forKey: key)?[fingerprint] as? [String: Any] else {
			return DesignSettings()
		}
		var settings = DesignSettings()
		if let fabric = entry["fabric"] as? [String: Any] {
			settings.fabric = Fabric(propertyList: fabric)
		}
		if let style = entry["stitchStyle"] as? Int {
			settings.stitchStyle = StitchStyle(rawValue: style)
		}
		if let width = entry["lineWidth"] as? Double {
			settings.lineWidth = CGFloat(width)
		}
		settings.showJumpStitches = entry["showJumpStitches"] as? Bool
		return settings
	}

	/// Remembers the choices for a design, or forgets it if none were made
	static func save(_ settings: DesignSettings, for fingerprint: String) {
		var all = UserDefaults.standard.dictionary(forKey: key) ?? [:]
		var entry: [String: Any] = [:]
		if let fabric = settings.fabric?.propertyList {
			entry["fabric"] = fabric
		}
		if let style = settings.stitchStyle {
			entry["stitchStyle"] = style.rawValue
		}
		if let width = settings.lineWidth {
			entry["lineWidth"] = Double(width)
		}
		if let show = settings.showJumpStitches {
			entry["showJumpStitches"] = show
		}

		if entry.isEmpty {
			all[fingerprint] = nil
		} else {
			entry["used"] = Date()
			all[fingerprint] = entry

			/* Forget the designs used longest ago */
			if all.count > limit {
				let byAge = all.sorted { (($0.value as? [String: Any])?["used"] as? Date ?? .distantPast) <
										 (($1.value as? [String: Any])?["used"] as? Date ?? .distantPast) }
				for (oldest, _) in byAge.prefix(all.count - limit) {
					all[oldest] = nil
				}
			}
		}
		UserDefaults.standard.set(all, forKey: key)
	}
}

extension Fabric {
	/// The fabric as a property list, to keep in the user defaults: its weave
	/// and its archived color
	var propertyList: [String: Any]? {
		guard let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true) else {
			return nil
		}
		return ["weave": weave.rawValue, "color": data]
	}

	init?(propertyList: [String: Any]) {
		guard let weave = (propertyList["weave"] as? String).flatMap(Weave.init(rawValue:)),
			  let data = propertyList["color"] as? Data,
			  let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
			return nil
		}
		self.init(weave: weave, color: color)
	}
}
