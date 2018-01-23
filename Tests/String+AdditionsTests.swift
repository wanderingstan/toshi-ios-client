// Copyright (c) 2018 Token Browser, Inc
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

@testable import Toshi
import XCTest

class StringAdditionsTests: XCTestCase {
    
    func testEnteringAValidPrefixDoesntCreateAPossibleURL() {
        XCTAssertNil("h".asPossibleURLString)
        XCTAssertNil("ht".asPossibleURLString)
        XCTAssertNil("htt".asPossibleURLString)
        XCTAssertNil("http".asPossibleURLString)
        
        XCTAssertNil("http:".asPossibleURLString)
        XCTAssertNil("http:/".asPossibleURLString)
        XCTAssertNil("http://".asPossibleURLString)
        XCTAssertEqual("http://a".asPossibleURLString, "http://a")

        XCTAssertNil("https".asPossibleURLString)
        XCTAssertNil("https:".asPossibleURLString)
        XCTAssertNil("https:/".asPossibleURLString)
        XCTAssertNil("https://".asPossibleURLString)
        XCTAssertEqual("https://a".asPossibleURLString, "https://a")

        XCTAssertNil("f".asPossibleURLString)
        XCTAssertNil("ft".asPossibleURLString)
        XCTAssertNil("ftp".asPossibleURLString)
        XCTAssertNil("ftp:".asPossibleURLString)
        XCTAssertNil("ftp:/".asPossibleURLString)
        XCTAssertNil("ftp://".asPossibleURLString)
        XCTAssertEqual("ftp://a".asPossibleURLString, "ftp://a")
        
        XCTAssertNil("fo".asPossibleURLString)
        XCTAssertNil("foo".asPossibleURLString)
        XCTAssertNil("foo:".asPossibleURLString)
        XCTAssertNil("foo:/".asPossibleURLString)
        XCTAssertNil("foo://".asPossibleURLString)
        XCTAssertEqual("foo://a".asPossibleURLString, "foo://a")
    }
    
    func testAddingSomethingWithADotAndOneExtraCharacterCreatesPossibleURLString() {
        XCTAssertNil("foo".asPossibleURLString)
        XCTAssertNil("foo.".asPossibleURLString)
        XCTAssertEqual("foo.b".asPossibleURLString, "https://foo.b")
    }
    
    func testCaseCorrectionInPossibleURLStrings() {
        XCTAssertEqual("foo.bar".asPossibleURLString, "https://foo.bar")
        XCTAssertEqual("Foo.bar".asPossibleURLString, "https://foo.bar")
        XCTAssertEqual("FOO.BAR".asPossibleURLString, "https://foo.bar")
    }
    
    func testDescribesValueLargerThanZero() {
        XCTAssertTrue("1.00".isValidValue())
        XCTAssertTrue("1,00".isValidValue())
        XCTAssertTrue("0.10".isValidValue())
        XCTAssertTrue("0,10".isValidValue())
        XCTAssertFalse("0.00".isValidValue())
        XCTAssertFalse("0,00".isValidValue())
        XCTAssertFalse("-1.00".isValidValue())
        XCTAssertFalse("-1,00".isValidValue())
        XCTAssertFalse("hi".isValidValue())
    }
}
