//
//  ShareViewController.swift
//  ShareExtension
//
//  Share extension to send content to HuggingChat
//

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private var textToShare: String = ""
    private var selectedModel: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        setupUI()
        extractSharedContent()
    }

    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "Share to HuggingChat"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textView = UITextView()
        textView.text = textToShare
        textView.font = .systemFont(ofSize: 16)
        textView.isEditable = false
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.translatesAutoresizingMaskIntoConstraints = false

        let shareButton = UIButton(type: .system)
        shareButton.setTitle("Send to Chat", for: .normal)
        shareButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        shareButton.backgroundColor = .systemBlue
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.layer.cornerRadius = 12
        shareButton.addTarget(self, action: #selector(shareToChat), for: .touchUpInside)
        shareButton.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(textView)
        view.addSubview(shareButton)
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textView.heightAnchor.constraint(equalToConstant: 200),

            shareButton.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 20),
            shareButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            shareButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            shareButton.heightAnchor.constraint(equalToConstant: 50),

            cancelButton.topAnchor.constraint(equalTo: shareButton.bottomAnchor, constant: 12),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func extractSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            return
        }

        // Handle text
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (item, error) in
                if let text = item as? String {
                    DispatchQueue.main.async {
                        self?.textToShare = text
                        self?.view.setNeedsLayout()
                    }
                }
            }
        }

        // Handle URLs
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                if let url = item as? URL {
                    DispatchQueue.main.async {
                        self?.textToShare = "Shared URL: \(url.absoluteString)"
                        self?.view.setNeedsLayout()
                    }
                }
            }
        }
    }

    @objc private func shareToChat() {
        // Save to shared container
        let defaults = UserDefaults(suiteName: "group.com.huggingface.huggingchat")
        defaults?.set(textToShare, forKey: "sharedText")
        defaults?.set(Date(), forKey: "sharedDate")

        // Open main app
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(URL(string: "huggingchat://share")!, options: [:]) { success in
                    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
                return
            }
            responder = responder?.next
        }

        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 0))
    }
}
