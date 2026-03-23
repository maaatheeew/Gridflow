import Foundation

struct ImportExportService {
    struct ImportResult {
        let projectsUpserted: Int
        let tasksUpserted: Int
    }

    private struct ExportPayload: Codable {
        let version: Int
        let exportedAt: Date
        let projects: [Project]
        let tasks: [TaskItem]
    }

    static func exportJSON(tasks: [TaskItem], projects: [Project]) throws -> Data {
        let payload = ExportPayload(version: 2, exportedAt: .now, projects: projects, tasks: tasks)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    static func importJSON(_ data: Data) throws -> (projects: [Project], tasks: [TaskItem]) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let payload = try decoder.decode(ExportPayload.self, from: data)
        return (payload.projects, payload.tasks)
    }
}
