//
//  PDFViewer.swift
//  songbook
//
//  Created by acemavrick on 6/4/25.
//

import SwiftUI
import PDFKit

struct PDFViewer: UIViewRepresentable {
    let forSong: String
    
    func makeUIView(context: Context) -> UIView {
        guard let url = Bundle.main.url(forResource: forSong, withExtension: "pdf") else {
            let label = UILabel()
            label.text = "Error retrieving PDF for \(forSong)"
            label.textAlignment = .center
            label.numberOfLines = 0
            label.textColor = .systemRed
            return label
        }
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        // unnecessary
    }
}

#Preview {
    PDFViewer(forSong: "Fort Tabarsi")
}
