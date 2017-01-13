import Foundation
import YapDatabase
import KeychainSwift

protocol Singleton: class {
    static var sharedInstance: Self { get }
}

public final class Yap: Singleton {
    var database: YapDatabase

    public var mainConnection: YapDatabaseConnection

    public static let sharedInstance = Yap()

    private var databasePassword: Data

    private init() {
        guard let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(".Signal.sqlite").path else { fatalError("Missing resource path!") }

        let options = YapDatabaseOptions()
        options.corruptAction = .fail

        /**
         NSString *dbPassword = [SAMKeychain passwordForService:keychainService account:keychainDBPassAccount];

         if (!dbPassword) {
         dbPassword = [[Randomness generateRandomBytes:30] base64EncodedString];
         NSError *error;
         [SAMKeychain setPassword:dbPassword forService:keychainService account:keychainDBPassAccount error:&error];
         if (error) {
         // Sync log to ensure it logs before exiting
         NSLog(@"Exiting because we failed to set new DB password. error: %@", error);
         exit(1);
         } else {
         DDLogError(@"Succesfully set new DB password. First launch?");
         }
         }

         return [dbPassword dataUsingEncoding:NSUTF8StringEncoding];

         */
        let keychain = KeychainSwift()
        var databasePassword: Data

        if let dbPwd = keychain.getData("DBPWD") {
            options.cipherKeyBlock = {
                return dbPwd
            };

            databasePassword = dbPwd
        } else {
            databasePassword = Randomness.generateRandomBytes(60).base64EncodedString().data(using: .utf8)!

            keychain.set(databasePassword, forKey: "DBPWD")
            options.cipherKeyBlock = {
                return databasePassword
            };
        }

        self.databasePassword = databasePassword

        self.database = YapDatabase(path: path, options: options)

        self.mainConnection = self.database.newConnection()
    }

    /// Insert a object into the database using the main thread default connection.
    ///
    /// - Parameters:
    ///   - object: Object to be stored. Must be serialisable. If nil, delete the record from the database.
    ///   - key: Key to store and retrieve object.
    ///   - collection: Optional. The name of the collection the object belongs to. Helps with organisation.
    ///   - metadata: Optional. Any serialisable object. Could be a related object, a description, a timestamp, a dictionary, and so on.
    public final func insert(object: Any?, for key: String, in collection: String? = nil, with metadata: Any? = nil) {
        self.mainConnection.readWrite { (transaction) in
            transaction.setObject(object, forKey: key, inCollection: collection, withMetadata: metadata)
        }
    }

    /// Checks whether an object was stored for a given key inside a given (optional) collection.
    ///
    /// - Parameter key: Key to check for the presence of a stored object.
    /// - Returns: Bool whether or not a certain object was stored for that key.
    public final func containsObject(for key: String, in collection: String? = nil) -> Bool {
        return self.retrieveObject(for: key, in: collection) != nil
    }

    /// Retrieve an object for a given key inside a given (optional) collection.
    ///
    /// - Parameters:
    ///   - key: Key used to store the object
    ///   - collection: Optional. The name of the collection the object was stored in.
    /// - Returns: The stored object.
    public final func retrieveObject(for key: String, in collection: String? = nil) -> Any? {
        var object: Any? = nil
        self.mainConnection.read { (transaction) in
            object = transaction.object(forKey: key, inCollection: collection)
        }

        return object
    }
}