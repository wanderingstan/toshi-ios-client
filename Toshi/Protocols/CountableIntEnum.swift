import Foundation

/**
 A swift protocol to make any Int enum able to count its cases.
 
 Super-useful for making enums to help you deal with sections in tableviews without having to maintain a case for the count of the enum.
 
 Originally developed by Logan Wright for Swift 2.0 here:
 https://gist.github.com/LoganWright/c8a26b1faf538e40f747
 
 Based on this and the subsequent 3 slides from Ellen Shapiro's talk about
 Laziness-Driven Development at CocoaConf Boston 2015:
 https://speakerdeck.com/designatednerd/laziness-driven-development-in-ios-cocoaconf-boston-september-2015?slide=28
 */
public protocol CountableIntEnum {
    /// - parameter rawValue: The raw Int value. Matches the initializer of RawRepresentable without the Self restrictions.
    init?(rawValue: Int)
}

//MARK: Default Implementation
public extension CountableIntEnum {
    
    /**
     - returns: A generated array of all the cases in this enum. Mostly useful for calling with
     .count so you can get the number of items in this enum.
     */
    public static var AllCases: [Self] {
        var caseIndex: Int = 0
        let generator: AnyIterator<Self> = AnyIterator {
            let _generator = Self(rawValue: caseIndex)
            caseIndex += 1
            return _generator
        }
        return Array(generator)
    }
    
    /**
     Method to consolidate fatal erroring out if something ain't there.
     
     - parameter index: The index (indexPath.row or indexPath.section, usually) of the thing you want to grab.
     
     - returns: The retrieved enum case. Fatal errors if it can't find it.
     */
    public static func forIndex(_ index: Int) -> Self {
        guard let rowOrSection = Self(rawValue: index) else {
            fatalError("Issue unwrapping row or section.")
        }
        return rowOrSection
    }
}
