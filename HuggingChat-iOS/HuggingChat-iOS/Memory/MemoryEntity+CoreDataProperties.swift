//
//  MemoryEntity+CoreDataProperties.swift
//  HuggingChat-iOS
//

import Foundation
import CoreData

extension MemoryEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MemoryEntity> {
        return NSFetchRequest<MemoryEntity>(entityName: "MemoryEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var type: String?
    @NSManaged public var content: String?
    @NSManaged public var context: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var importance: Double
    @NSManaged public var tags: String?
    @NSManaged public var associatedConversationId: String?
    @NSManaged public var userFeedback: String?
}

extension MemoryEntity: Identifiable {}
