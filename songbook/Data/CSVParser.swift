//
//  CSVParser.swift
//  songbook
//
//  Pure CSV parsing logic, returns [SongDTO].
//

import Foundation
import os.log

struct CSVParser {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CSVParser")
    
    /// parses CSV content into SongDTO array
    static func parse(_ content: String) throws -> [SongDTO] {
        var songs = [SongDTO]()
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.dropFirst().enumerated() { // skip header
            let lineNumber = index + 2 // 1-indexed, accounting for header
            
            // skip empty lines
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let cols = parseLine(line)
            
            // csv structure: title,artist,first line,filename,Reference,Indices
            guard cols.count == 6 else {
                logger.warning("Skipping malformed line \(lineNumber) (expected 6 columns, got \(cols.count))")
                continue
            }
            
            let title = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let artist = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let firstLine = cols[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let filename = cols[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let reference = cols[4].trimmingCharacters(in: .whitespacesAndNewlines)
            let categoriesRaw = cols[5]
            
            // skip if required fields are missing
            guard !title.isEmpty, !artist.isEmpty, !filename.isEmpty else {
                logger.warning("Skipping line \(lineNumber) with missing required fields")
                continue
            }
            
            // parse categories (colon-separated)
            let categories = categoriesRaw
                .components(separatedBy: ":")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            let dto = SongDTO(
                title: title,
                artist: artist,
                firstLine: firstLine,
                filename: filename,
                reference: reference,
                categories: categories
            )
            
            songs.append(dto)
        }
        
        logger.info("Parsed \(songs.count) songs from CSV")
        return songs
    }
    
    /// parses a single CSV line, handling quoted fields and escaped quotes
    private static func parseLine(_ line: String) -> [String] {
        var fields = [String]()
        var buffer = String()
        var inQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                // check for escaped quote ("")
                let nextIndex = line.index(after: i)
                if inQuotes && nextIndex < line.endIndex && line[nextIndex] == "\"" {
                    buffer.append("\"")
                    i = line.index(after: nextIndex)
                    continue
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                fields.append(buffer)
                buffer = String()
            } else {
                buffer.append(char)
            }
            
            i = line.index(after: i)
        }
        
        fields.append(buffer) // final field
        return fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

