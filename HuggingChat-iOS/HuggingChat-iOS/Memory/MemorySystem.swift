//
//  MemorySystem.swift
//  HuggingChat-iOS
//
//  Persistent memory system with learning capabilities
//

import Foundation
import CoreData
import Observation

// MARK: - Memory Manager

@Observable
class MemoryManager {
    static let shared = MemoryManager()

    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    var totalMemories: Int = 0
    var recentMemories: [Memory] = []

    private init() {
        container = NSPersistentContainer(name: "MemoryModel")
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        context = container.viewContext
        context.automaticallyMergesChangesFromParent = true

        loadRecentMemories()
    }

    // MARK: - Store Memories

    func storeMemory(_ memory: Memory) {
        let entity = MemoryEntity(context: context)
        entity.id = memory.id
        entity.type = memory.type.rawValue
        entity.content = memory.content
        entity.context = memory.context
        entity.timestamp = memory.timestamp
        entity.importance = memory.importance
        entity.tags = memory.tags.joined(separator: ",")
        entity.associatedConversationId = memory.associatedConversationId
        entity.userFeedback = memory.userFeedback?.rawValue

        saveContext()
        loadRecentMemories()
    }

    func storeConversationMemory(
        conversationId: String,
        content: String,
        context: String?,
        importance: Double = 0.5,
        tags: [String] = []
    ) {
        let memory = Memory(
            type: .conversation,
            content: content,
            context: context,
            importance: importance,
            tags: tags,
            associatedConversationId: conversationId
        )
        storeMemory(memory)
    }

    func storeUserPreference(
        key: String,
        value: String,
        importance: Double = 0.7
    ) {
        let memory = Memory(
            type: .preference,
            content: "\(key): \(value)",
            context: "User preference",
            importance: importance,
            tags: ["preference", key]
        )
        storeMemory(memory)
    }

    func storeUserPattern(
        pattern: String,
        frequency: Int,
        importance: Double = 0.6
    ) {
        let memory = Memory(
            type: .pattern,
            content: pattern,
            context: "Frequency: \(frequency)",
            importance: importance,
            tags: ["pattern", "behavior"]
        )
        storeMemory(memory)
    }

    func storeContextualInfo(
        context: String,
        source: String,
        importance: Double = 0.5
    ) {
        let memory = Memory(
            type: .context,
            content: context,
            context: "Source: \(source)",
            importance: importance,
            tags: ["context", source]
        )
        storeMemory(memory)
    }

    // MARK: - Retrieve Memories

    func getRelevantMemories(
        for query: String,
        limit: Int = 10,
        minImportance: Double = 0.3
    ) -> [Memory] {
        let request: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "importance >= %@ AND (content CONTAINS[cd] %@ OR tags CONTAINS[cd] %@)",
            NSNumber(value: minImportance),
            query,
            query
        )
        request.sortDescriptors = [
            NSSortDescriptor(key: "importance", ascending: false),
            NSSortDescriptor(key: "timestamp", ascending: false)
        ]
        request.fetchLimit = limit

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { Memory(from: $0) }
        } catch {
            print("Failed to fetch memories: \(error)")
            return []
        }
    }

    func getMemoriesByType(_ type: MemoryType, limit: Int = 20) -> [Memory] {
        let request: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@", type.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { Memory(from: $0) }
        } catch {
            print("Failed to fetch memories by type: \(error)")
            return []
        }
    }

    func getMemoriesForConversation(_ conversationId: String) -> [Memory] {
        let request: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "associatedConversationId == %@", conversationId)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { Memory(from: $0) }
        } catch {
            print("Failed to fetch conversation memories: \(error)")
            return []
        }
    }

    func getMemoriesByTags(_ tags: [String], limit: Int = 10) -> [Memory] {
        let predicates = tags.map { tag in
            NSPredicate(format: "tags CONTAINS[cd] %@", tag)
        }
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)

        let request: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        request.predicate = compoundPredicate
        request.sortDescriptors = [
            NSSortDescriptor(key: "importance", ascending: false),
            NSSortDescriptor(key: "timestamp", ascending: false)
        ]
        request.fetchLimit = limit

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { Memory(from: $0) }
        } catch {
            print("Failed to fetch memories by tags: \(error)")
            return []
        }
    }

    // MARK: - Update Memories

    func updateMemoryImportance(id: UUID, importance: Double) {
        let request: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.importance = importance
                saveContext()
            }
        } catch {
            print("Failed to update memory importance: \(error)")
        }
    }

    func markMemoryAsUseful(id: UUID) {
        let request: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.userFeedback = UserFeedback.helpful.rawValue
                entity.importance = min(1.0, entity.importance + 0.1)
                saveContext()
            }
        } catch {
            print("Failed to mark memory as useful: \(error)")
        }
    }

    func markMemoryAsNotUseful(id: UUID) {
        let request: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.userFeedback = UserFeedback.notHelpful.rawValue
                entity.importance = max(0.0, entity.importance - 0.2)
                saveContext()
            }
        } catch {
            print("Failed to mark memory as not useful: \(error)")
        }
    }

    // MARK: - Cleanup

    func cleanupOldMemories(olderThan days: Int = 90, minImportance: Double = 0.5) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        let request: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "timestamp < %@ AND importance < %@",
            cutoffDate as NSDate,
            NSNumber(value: minImportance)
        )

        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            saveContext()
            loadRecentMemories()
        } catch {
            print("Failed to cleanup old memories: \(error)")
        }
    }

    func deleteAllMemories() {
        let request: NSFetchRequest<NSFetchRequestResult> = MemoryEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try context.execute(deleteRequest)
            saveContext()
            loadRecentMemories()
        } catch {
            print("Failed to delete all memories: \(error)")
        }
    }

    // MARK: - Statistics

    func getMemoryStatistics() -> MemoryStatistics {
        let request: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()

        do {
            let allMemories = try context.fetch(request)

            let typeCount = Dictionary(grouping: allMemories) { entity in
                MemoryType(rawValue: entity.type ?? "") ?? .other
            }.mapValues { $0.count }

            let avgImportance = allMemories.map { $0.importance }.reduce(0.0, +) / Double(allMemories.count)

            let totalSize = allMemories.reduce(0) { total, entity in
                total + (entity.content?.count ?? 0)
            }

            return MemoryStatistics(
                totalMemories: allMemories.count,
                memoriesByType: typeCount,
                averageImportance: avgImportance,
                totalStorageSize: totalSize,
                oldestMemory: allMemories.map { $0.timestamp ?? Date() }.min(),
                newestMemory: allMemories.map { $0.timestamp ?? Date() }.max()
            )
        } catch {
            print("Failed to get statistics: \(error)")
            return MemoryStatistics(
                totalMemories: 0,
                memoriesByType: [:],
                averageImportance: 0,
                totalStorageSize: 0,
                oldestMemory: nil,
                newestMemory: nil
            )
        }
    }

    // MARK: - Private Helpers

    private func loadRecentMemories() {
        let request: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = 100

        do {
            let entities = try context.fetch(request)
            recentMemories = entities.compactMap { Memory(from: $0) }
            totalMemories = try context.count(for: MemoryEntity.fetchRequest())
        } catch {
            print("Failed to load recent memories: \(error)")
        }
    }

    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
}

// MARK: - Memory Model

struct Memory: Identifiable, Codable {
    let id: UUID
    let type: MemoryType
    let content: String
    let context: String?
    let timestamp: Date
    var importance: Double // 0.0 to 1.0
    let tags: [String]
    let associatedConversationId: String?
    var userFeedback: UserFeedback?

    init(
        id: UUID = UUID(),
        type: MemoryType,
        content: String,
        context: String?,
        timestamp: Date = Date(),
        importance: Double,
        tags: [String],
        associatedConversationId: String? = nil,
        userFeedback: UserFeedback? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.context = context
        self.timestamp = timestamp
        self.importance = importance
        self.tags = tags
        self.associatedConversationId = associatedConversationId
        self.userFeedback = userFeedback
    }

    init?(from entity: MemoryEntity) {
        guard let id = entity.id,
              let typeString = entity.type,
              let type = MemoryType(rawValue: typeString),
              let content = entity.content,
              let timestamp = entity.timestamp else {
            return nil
        }

        self.id = id
        self.type = type
        self.content = content
        self.context = entity.context
        self.timestamp = timestamp
        self.importance = entity.importance
        self.tags = (entity.tags ?? "").split(separator: ",").map(String.init)
        self.associatedConversationId = entity.associatedConversationId

        if let feedbackString = entity.userFeedback {
            self.userFeedback = UserFeedback(rawValue: feedbackString)
        }
    }
}

enum MemoryType: String, Codable, CaseIterable {
    case conversation = "conversation"
    case preference = "preference"
    case pattern = "pattern"
    case context = "context"
    case interaction = "interaction"
    case fact = "fact"
    case other = "other"
}

enum UserFeedback: String, Codable {
    case helpful = "helpful"
    case notHelpful = "not_helpful"
    case neutral = "neutral"
}

struct MemoryStatistics {
    let totalMemories: Int
    let memoriesByType: [MemoryType: Int]
    let averageImportance: Double
    let totalStorageSize: Int
    let oldestMemory: Date?
    let newestMemory: Date?
}
