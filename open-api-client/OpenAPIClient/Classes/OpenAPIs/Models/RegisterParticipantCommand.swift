//
// RegisterParticipantCommand.swift
//
// Generated by openapi-generator
// https://openapi-generator.tech
//

import Foundation

public struct RegisterParticipantCommand: Codable {

    public var eventId: String?
    public var name: String?

    public init(eventId: String? = nil, name: String? = nil) {
        self.eventId = eventId
        self.name = name
    }

}
