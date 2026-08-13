import Foundation

enum ChatSidebarSearch {
    static func query(from text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func visibleAgents(
        agents: [SavedAgent],
        query: String,
        matchingConversations: (SavedAgent) -> [Conversation]
    ) -> [SavedAgent] {
        guard !query.isEmpty else {
            return agents
        }

        return agents.filter { agent in
            agentMatches(agent, query: query)
                || !matchingConversations(agent).isEmpty
        }
    }

    static func resultCount(
        visibleAgents: [SavedAgent],
        query: String,
        matchingConversations: (SavedAgent) -> [Conversation]
    ) -> Int {
        guard !query.isEmpty else {
            return visibleAgents.count
        }

        return visibleAgents.reduce(0) { count, agent in
            count
                + (agentMatches(agent, query: query) ? 1 : 0)
                + matchingConversations(agent).count
        }
    }

    static func agentMatches(_ agent: SavedAgent, query: String) -> Bool {
        agent.name.localizedStandardContains(query)
            || agent.address.localizedStandardContains(query)
    }
}
