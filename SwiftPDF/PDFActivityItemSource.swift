//
//  PDFActivityItemSource.swift
//  SwiftPDF
//
//  Created by Jim Washkau on 2/22/26.
//

import UIKit
import UniformTypeIdentifiers

final class PDFActivityItemSource: NSObject, UIActivityItemSource {
    private let data: Data
    private let title: String

    init(data: Data, title: String) {
        self.data = data
        self.title = title
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        data
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        data
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.pdf.identifier
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        title
    }
}
