//
//  CSVParserTests.swift
//  songbookTests
//
//  Unit tests for CSV parsing.
//

import XCTest
@testable import songbook

final class CSVParserTests: XCTestCase {
    
    func testParseValidCSV() throws {
        let csv = """
        title,artist,first line,filename,Reference,Indices
        Song One,Artist A,First line one,song_one,Ref1,Category1:Category2
        Song Two,Artist B,First line two,song_two,Ref2,Category1
        """
        
        let songs = try CSVParser.parse(csv)
        
        XCTAssertEqual(songs.count, 2)
        
        XCTAssertEqual(songs[0].title, "Song One")
        XCTAssertEqual(songs[0].artist, "Artist A")
        XCTAssertEqual(songs[0].firstLine, "First line one")
        XCTAssertEqual(songs[0].filename, "song_one")
        XCTAssertEqual(songs[0].reference, "Ref1")
        XCTAssertEqual(songs[0].categories, ["Category1", "Category2"])
        
        XCTAssertEqual(songs[1].title, "Song Two")
        XCTAssertEqual(songs[1].categories, ["Category1"])
    }
    
    func testParseQuotedFields() throws {
        let csv = """
        title,artist,first line,filename,Reference,Indices
        "Song, With Comma","Artist ""Quote""",First line,song_file,Ref,Cat
        """
        
        let songs = try CSVParser.parse(csv)
        
        XCTAssertEqual(songs.count, 1)
        XCTAssertEqual(songs[0].title, "Song, With Comma")
        XCTAssertEqual(songs[0].artist, "Artist \"Quote\"")
    }
    
    func testSkipEmptyLines() throws {
        let csv = """
        title,artist,first line,filename,Reference,Indices
        Song One,Artist A,First line,song_one,Ref,Cat
        
        Song Two,Artist B,First line,song_two,Ref,Cat
        
        """
        
        let songs = try CSVParser.parse(csv)
        XCTAssertEqual(songs.count, 2)
    }
    
    func testSkipMalformedLines() throws {
        let csv = """
        title,artist,first line,filename,Reference,Indices
        Song One,Artist A,First line,song_one,Ref,Cat
        This line has wrong column count
        Song Two,Artist B,First line,song_two,Ref,Cat
        """
        
        let songs = try CSVParser.parse(csv)
        XCTAssertEqual(songs.count, 2)
    }
    
    func testSkipMissingRequiredFields() throws {
        let csv = """
        title,artist,first line,filename,Reference,Indices
        ,Artist A,First line,song_one,Ref,Cat
        Song Two,,First line,song_two,Ref,Cat
        Song Three,Artist C,First line,,Ref,Cat
        Song Four,Artist D,First line,song_four,Ref,Cat
        """
        
        let songs = try CSVParser.parse(csv)
        XCTAssertEqual(songs.count, 1) // only Song Four is valid
        XCTAssertEqual(songs[0].title, "Song Four")
    }
    
    func testEmptyCategories() throws {
        let csv = """
        title,artist,first line,filename,Reference,Indices
        Song One,Artist A,First line,song_one,Ref,
        """
        
        let songs = try CSVParser.parse(csv)
        XCTAssertEqual(songs.count, 1)
        XCTAssertEqual(songs[0].categories, [])
    }
    
    func testRealWorldCSVFormat() throws {
        // matches the actual songs.csv format
        let csv = """
        title,artist,first line,filename,Reference,Indices
        'Abdu'l-Baha,"Losey, Elaine","'Abdu'l-Baha, 'Abdu'l-Baha",Abdu'l-Baha,Abdu'l-Baha,Holy Words:Children's Songs
        """
        
        let songs = try CSVParser.parse(csv)
        XCTAssertEqual(songs.count, 1)
        XCTAssertEqual(songs[0].title, "'Abdu'l-Baha")
        XCTAssertEqual(songs[0].artist, "Losey, Elaine")
        XCTAssertEqual(songs[0].categories, ["Holy Words", "Children's Songs"])
    }
}

