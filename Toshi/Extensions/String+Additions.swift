// Copyright (c) 2017 Token Browser, Inc
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

extension String {

    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        
        return UIApplication.shared.canOpenURL(url)
    }
    
    var asPossibleURLString: String? {
        let lowerSelf = self.lowercased()

        if lowerSelf.contains("://") && !lowerSelf.hasSuffix("://") {
            // Already a possible url string if it has a `://` somewhere in it that is not the last character.
            return lowerSelf
        }
        
        // Definitely can't be turned into a URL string if no `.` plus at least one other character
        guard lowerSelf.contains("."), !lowerSelf.hasSuffix(".") else {  return nil  }
        
        return "https://" + lowerSelf
    }
    
    private func matches(pattern: String) -> Bool {
         do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: utf16.count)) != nil
        } catch {
            return false
        }
    }

    var isValidSha3Hash: Bool {
        do {
            let regex = try NSRegularExpression(pattern: "0x[a-fA-F0-9]{64}")
            let results = regex.matches(in: self, range: NSRange(startIndex..., in: self))
            return results.count == 1
        } catch let error {
            fatalError("invalid regex: \(error.localizedDescription)")
        }
    }

    func truncate(length: Int, trailing: String? = "...") -> String {
        if self.length > length {
            let end = index(startIndex, offsetBy: length)
            return String(self[..<end]) + (trailing ?? "")
        } else {
            return self
        }
    }
}
