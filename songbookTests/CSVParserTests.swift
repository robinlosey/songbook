//
//  CSVParserTests.swift
//  songbookTests
//
//  unit tests for csv parsing
//

import Testing
@testable import songbook

@Suite("CSVParser Tests")
struct CSVParserTests {

    @Test("parse valid csv with multiple songs and categories")
    func parseValidCSV() throws {
        let csv = """
        title,artist,first line,filename,Reference,Indices
        Song One,Artist A,First line one,song_one,Ref1,Category1:Category2
        Song Two,Artist B,First line two,song_two,Ref2,Category1
        """

        let songs = try CSVParser.parse(csv)

        #expect(songs.count == 2)

        #expect(songs[0].title == "Song One")
        #expect(songs[0].artist == "Artist A")
        #expect(songs[0].firstLine == "First line one")
        #expect(songs[0].filename == "song_one")
        #expect(songs[0].reference == "Ref1")
        #expect(songs[0].categories == ["Category1", "Category2"])

        #expect(songs[1].title == "Song Two")
        #expect(songs[1].categories == ["Category1"])
    }

    @Test("parse quoted fields with commas and escaped quotes")
    func parseQuotedFields() throws {
        let csv = #"""
        title,artist,first line,filename,Reference,Indices
        "Song, With Comma","Artist ""Quoted""",First line,song_file,Ref,Cat
        """#

        let songs = try CSVParser.parse(csv)

        #expect(songs.count == 1)
        #expect(songs[0].title == "Song, With Comma")
        #expect(songs[0].artist == "Artist \"Quoted\"")
    }

    @Test("skip empty lines in csv")
    func skipEmptyLines() throws {
        let csv = """
        title,artist,first line,filename,Reference,Indices
        Song One,Artist A,First line,song_one,Ref,Cat

        Song Two,Artist B,First line,song_two,Ref,Cat

        """

        let songs = try CSVParser.parse(csv)
        #expect(songs.count == 2)
    }

    @Test("skip malformed lines with wrong column count")
    func skipMalformedLines() throws {
        let csv = """
        title,artist,first line,filename,Reference,Indices
        Song One,Artist A,First line,song_one,Ref,Cat
        This line has wrong column count
        Song Two,Artist B,First line,song_two,Ref,Cat
        """

        let songs = try CSVParser.parse(csv)
        #expect(songs.count == 2)
    }

    @Test("skip rows with missing required fields")
    func skipMissingRequiredFields() throws {
        let csv = """
        title,artist,first line,filename,Reference,Indices
        ,Artist A,First line,song_one,Ref,Cat
        Song Two,,First line,song_two,Ref,Cat
        Song Three,Artist C,First line,,Ref,Cat
        Song Four,Artist D,First line,song_four,Ref,Cat
        """

        let songs = try CSVParser.parse(csv)
        #expect(songs.count == 1) // only song four is valid
        #expect(songs[0].title == "Song Four")
    }

    @Test("handle empty categories field")
    func emptyCategories() throws {
        let csv = """
        title,artist,first line,filename,Reference,Indices
        Song One,Artist A,First line,song_one,Ref,
        """

        let songs = try CSVParser.parse(csv)
        #expect(songs.count == 1)
        #expect(songs[0].categories == [])
    }

    @Test("parse real world csv format with special chars")
    func realWorldCSVFormat() throws {
        // matches the actual songs.csv format
        let csv = """
        title,artist,first line,filename,Reference,Indices
        'Abdu'l-Baha,"Losey, Elaine","'Abdu'l-Baha, 'Abdu'l-Baha",Abdu'l-Baha,Abdu'l-Baha,Holy Words:Children's Songs
        """

        let songs = try CSVParser.parse(csv)
        #expect(songs.count == 1)
        #expect(songs[0].title == "'Abdu'l-Baha")
        #expect(songs[0].artist == "Losey, Elaine")
        #expect(songs[0].categories == ["Holy Words", "Children's Songs"])
    }
}
