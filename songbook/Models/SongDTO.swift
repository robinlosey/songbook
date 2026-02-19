//
//  SongDTO.swift
//  songbook
//
//  Data transfer object for parsed CSV rows - decoupled from CoreData.
//

import Foundation

struct SongDTO: Sendable, Equatable {
    let title: String
    let artist: String
    let firstLine: String
    let filename: String      // stable identifier for matching
    let reference: String
    let categories: [String]
}

