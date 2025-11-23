import Foundation
import AppKit
import PDFKit

class SummaryExporter {
    
    // MARK: - Export to PDF
    func exportToPDF(summary: StudySummary) -> URL? {
        // Create attributed string with formatting
        let attributedString = createFormattedDocument(summary: summary)
        
        // Set up page size (US Letter)
        let pageWidth: CGFloat = 612  // 8.5 inches
        let pageHeight: CGFloat = 792 // 11 inches
        let margin: CGFloat = 50
        
        let filename = "StudySummary_\(Date().timeIntervalSince1970).pdf"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let pdfURL = documentsPath.appendingPathComponent(filename)
        
        // Create PDF data
        let pdfData = NSMutableData()
        
        // Create consumer
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            print("Failed to create PDF consumer")
            return nil
        }
        
        // Create context
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            print("Failed to create PDF context")
            return nil
        }
        
        // Begin page
        pdfContext.beginPDFPage(nil)
        
        // Create a flipped coordinate system for text drawing
        pdfContext.translateBy(x: 0, y: pageHeight)
        pdfContext.scaleBy(x: 1.0, y: -1.0)
        
        // Draw the attributed string
        let drawRect = CGRect(x: margin, y: margin, width: pageWidth - (margin * 2), height: pageHeight - (margin * 2))
        
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: true)
        NSGraphicsContext.current = nsContext
        
        attributedString.draw(in: drawRect)
        
        NSGraphicsContext.restoreGraphicsState()
        
        // End page and close
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        // Write to file
        do {
            try pdfData.write(to: pdfURL, options: .atomic)
            print("PDF created at: \(pdfURL.path)")
            return pdfURL
        } catch {
            print("Failed to write PDF: \(error)")
            return nil
        }
    }
    
    // MARK: - Export to Markdown
    func exportToMarkdown(summary: StudySummary) -> URL? {
        let markdown = generateMarkdownText(summary: summary)
        
        let filename = "StudySummary_\(Date().timeIntervalSince1970).md"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let markdownURL = documentsPath.appendingPathComponent(filename)
        
        do {
            try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
            return markdownURL
        } catch {
            print("Failed to save Markdown: \(error)")
            return nil
        }
    }
    
    // MARK: - Generate Markdown Text
    func generateMarkdownText(summary: StudySummary) -> String {
        var markdown = ""
        
        // Title
        markdown += "# Study Session Summary\n\n"
        
        // Metadata
        markdown += "**Date:** \(summary.date.formatted(date: .long, time: .shortened))\n\n"
        
        markdown += "---\n\n"
        
        // Summary
        markdown += "## Summary\n\n"
        markdown += "\(summary.summaryText)\n\n"
        
        markdown += "---\n\n"
        
        // Key Points
        if !summary.keyPoints.isEmpty {
            markdown += "## Key Points\n\n"
            for (index, point) in summary.keyPoints.enumerated() {
                markdown += "\(index + 1). \(point)\n"
            }
            markdown += "\n---\n\n"
        }
        
        // Quiz Questions
        markdown += "## Quiz Questions\n\n"
        for (index, question) in summary.quizQuestions.enumerated() {
            markdown += "### Question \(index + 1)\n\n"
            markdown += "**Q:** \(question.question)\n\n"
            markdown += "**A:** \(question.answer)\n\n"
        }
        
        return markdown
    }
    
    // MARK: - Create Formatted Document
    private func createFormattedDocument(summary: StudySummary) -> NSAttributedString {
        let document = NSMutableAttributedString()
        
        // Fonts
        let titleFont = NSFont.boldSystemFont(ofSize: 24)
        let headingFont = NSFont.boldSystemFont(ofSize: 18)
        let subheadingFont = NSFont.boldSystemFont(ofSize: 14)
        let bodyFont = NSFont.systemFont(ofSize: 12)
        let metadataFont = NSFont.systemFont(ofSize: 10)
        
        // Paragraph styles
        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center
        titleParagraph.paragraphSpacing = 20
        
        let headingParagraph = NSMutableParagraphStyle()
        headingParagraph.paragraphSpacing = 12
        headingParagraph.paragraphSpacingBefore = 12
        
        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = 4
        bodyParagraph.paragraphSpacing = 10
        
        // Title
        let title = NSAttributedString(
            string: "Study Session Summary\n\n",
            attributes: [
                .font: titleFont,
                .paragraphStyle: titleParagraph,
                .foregroundColor: NSColor.black
            ]
        )
        document.append(title)
        
        // Metadata
        let metadata = NSAttributedString(
            string: "Date: \(summary.date.formatted(date: .long, time: .shortened))\n",
            attributes: [
                .font: metadataFont,
                .foregroundColor: NSColor.darkGray,
                .paragraphStyle: bodyParagraph
            ]
        )
        document.append(metadata)
        
        // Divider
        document.append(NSAttributedString(string: "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n",
                                          attributes: [.foregroundColor: NSColor.lightGray]))
        
        // Summary section
        let summaryHeading = NSAttributedString(
            string: "Summary\n",
            attributes: [
                .font: headingFont,
                .paragraphStyle: headingParagraph,
                .foregroundColor: NSColor.black
            ]
        )
        document.append(summaryHeading)
        
        let summaryText = NSAttributedString(
            string: "\(summary.summaryText)\n\n",
            attributes: [
                .font: bodyFont,
                .paragraphStyle: bodyParagraph,
                .foregroundColor: NSColor.black
            ]
        )
        document.append(summaryText)
        
        // Key Points
        if !summary.keyPoints.isEmpty {
            document.append(NSAttributedString(string: "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n",
                                              attributes: [.foregroundColor: NSColor.lightGray]))
            
            let keyPointsHeading = NSAttributedString(
                string: "Key Points\n",
                attributes: [
                    .font: headingFont,
                    .paragraphStyle: headingParagraph,
                    .foregroundColor: NSColor.black
                ]
            )
            document.append(keyPointsHeading)
            
            for (index, point) in summary.keyPoints.enumerated() {
                let pointText = NSAttributedString(
                    string: "\(index + 1). \(point)\n",
                    attributes: [
                        .font: bodyFont,
                        .paragraphStyle: bodyParagraph,
                        .foregroundColor: NSColor.black
                    ]
                )
                document.append(pointText)
            }
            document.append(NSAttributedString(string: "\n"))
        }
        
        // Quiz Questions
        document.append(NSAttributedString(string: "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n",
                                          attributes: [.foregroundColor: NSColor.lightGray]))
        
        let quizHeading = NSAttributedString(
            string: "Quiz Questions\n\n",
            attributes: [
                .font: headingFont,
                .paragraphStyle: headingParagraph,
                .foregroundColor: NSColor.black
            ]
        )
        document.append(quizHeading)
        
        for (index, question) in summary.quizQuestions.enumerated() {
            let questionNumber = NSAttributedString(
                string: "Question \(index + 1)\n",
                attributes: [
                    .font: subheadingFont,
                    .paragraphStyle: headingParagraph,
                    .foregroundColor: NSColor.black
                ]
            )
            document.append(questionNumber)
            
            let questionText = NSAttributedString(
                string: "Q: \(question.question)\n",
                attributes: [
                    .font: bodyFont,
                    .paragraphStyle: bodyParagraph,
                    .foregroundColor: NSColor.black
                ]
            )
            document.append(questionText)
            
            let answerText = NSAttributedString(
                string: "A: \(question.answer)\n\n",
                attributes: [
                    .font: bodyFont,
                    .foregroundColor: NSColor.darkGray,
                    .paragraphStyle: bodyParagraph
                ]
            )
            document.append(answerText)
        }
        
        return document
    }
}
