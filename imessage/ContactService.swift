//
//  ContactService.swift
//  imessage
//
//  Created by hunter diamond on 1/22/26.
//

import Foundation
internal import Contacts

extension Notification.Name {
    static let contactsDidLoad = Notification.Name("contactsDidLoad")
}

class ContactService {
    static let shared = ContactService()

    private let contactStore = CNContactStore()
    private var contactLookup: [String: String] = [:]
    private var contactPhotoLookup: [String: Data] = [:]
    private var isLoaded = false

    private init() {
        // Don't automatically request access - wait for explicit user action
        // Check if we already have access and load contacts if so
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if hasContactsAccess(status) {
            loadAllContacts()
        }
    }
    
    /// Check current authorization status
    var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }
    
    /// Returns true if we have contacts access (authorized or limited)
    var hasAccess: Bool {
        hasContactsAccess(authorizationStatus)
    }
    
    /// Check if a status grants contacts access (authorized or limited on macOS 14+)
    private func hasContactsAccess(_ status: CNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .limited:
            return true
        case .denied, .restricted, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
    
    /// Request contacts access - call this from a user-initiated action (e.g., button tap)
    func requestAccess(completion: @escaping (Bool) -> Void) {
        // Check if we already have authorization - don't prompt again
        let currentStatus = CNContactStore.authorizationStatus(for: .contacts)
        
        if hasContactsAccess(currentStatus) {
            // Already authorized, just ensure contacts are loaded
            if !isLoaded {
                loadAllContacts()
            }
            DispatchQueue.main.async {
                completion(true)
            }
            return
        }
        
        // Only request if not determined yet
        if currentStatus == .notDetermined {
            contactStore.requestAccess(for: .contacts) { [weak self] granted, error in
                if granted {
                    self?.loadAllContacts()
                }
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            // Status is denied or restricted - can't request again
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }

    private func loadAllContacts() {
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactThumbnailImageDataKey
        ] as [CNKeyDescriptor]

        do {
            let contacts = try contactStore.unifiedContacts(matching: NSPredicate(value: true), keysToFetch: keysToFetch)
            print("Loading \(contacts.count) contacts...")

            for contact in contacts {
                let name = formatContactName(contact)
                let photoData = contact.thumbnailImageData

                // Map all phone numbers to this contact
                for phoneNumber in contact.phoneNumbers {
                    let number = phoneNumber.value.stringValue
                    let cleanNumber = cleanPhoneNumber(number)

                    contactLookup[number] = name
                    contactLookup[cleanNumber] = name
                    
                    if let photo = photoData {
                        contactPhotoLookup[number] = photo
                        contactPhotoLookup[cleanNumber] = photo
                    }
                }

                // Map all email addresses to this contact
                for email in contact.emailAddresses {
                    let emailString = (email.value as String).lowercased()
                    contactLookup[emailString] = name
                    
                    if let photo = photoData {
                        contactPhotoLookup[emailString] = photo
                    }
                }
            }

            isLoaded = true
            print("Loaded \(contactLookup.count) contact mappings")
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .contactsDidLoad, object: nil)
            }
        } catch {
            print("Failed to fetch contacts: \(error)")
        }
    }

    func getContactName(for identifier: String?, groupChatName: String? = nil, participants: String? = nil) -> String? {
        guard let identifier = identifier, !identifier.isEmpty else { return nil }

        // Check if this is a group chat (identifier starts with "chat")
        if identifier.hasPrefix("chat") {
            // If we have an explicit group chat name, use it
            if let groupName = groupChatName, !groupName.isEmpty {
                return groupName
            }

            // If we have participants, format them
            if let participantString = participants, !participantString.isEmpty {
                let participantList = participantString.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                if !participantList.isEmpty {
                    return formatGroupChatName(participants: participantList)
                }
            }

            // Fallback: just show it's a group chat
            return "Group Chat"
        }

        // Single contact - try to look up their name
        return lookupSingleContact(identifier)
    }

    private func formatGroupChatName(participants: [String]) -> String {
        guard !participants.isEmpty else {
            return "Group Chat"
        }

        var resolvedNames: [String] = []

        for participant in participants {
            guard !participant.isEmpty else { continue }

            // Try to resolve each participant to a contact name
            if let name = lookupSingleContact(participant) {
                // Extract first name only
                let components = name.components(separatedBy: " ")
                let firstName = components.first ?? name
                if !firstName.isEmpty {
                    resolvedNames.append(firstName)
                }
            }
        }

        // Show first 3 names, then "(and n others)"
        if resolvedNames.count > 3 {
            let firstThree = resolvedNames.prefix(3).joined(separator: ", ")
            let remaining = resolvedNames.count - 3
            return "\(firstThree) (and \(remaining) other\(remaining == 1 ? "" : "s"))"
        } else if !resolvedNames.isEmpty {
            return resolvedNames.joined(separator: ", ")
        } else {
            // Couldn't resolve any names
            return "Group Chat (\(participants.count) people)"
        }
    }

    private func lookupSingleContact(_ identifier: String) -> String? {
        // Try exact match first
        if let name = contactLookup[identifier] {
            return name
        }

        // Try lowercase for emails
        if let name = contactLookup[identifier.lowercased()] {
            return name
        }

        // Try cleaned phone number
        let cleanIdentifier = cleanPhoneNumber(identifier)
        if let name = contactLookup[cleanIdentifier] {
            return name
        }

        return nil
    }
    
    func getContactPhoto(for identifier: String?) -> Data? {
        guard let identifier = identifier, !identifier.isEmpty else { return nil }
        
        // Skip group chats
        if identifier.hasPrefix("chat") {
            return nil
        }
        
        // Try exact match first
        if let photo = contactPhotoLookup[identifier] {
            return photo
        }
        
        // Try lowercase for emails
        if let photo = contactPhotoLookup[identifier.lowercased()] {
            return photo
        }
        
        // Try cleaned phone number
        let cleanIdentifier = cleanPhoneNumber(identifier)
        if let photo = contactPhotoLookup[cleanIdentifier] {
            return photo
        }
        
        return nil
    }

    private func formatContactName(_ contact: CNContact) -> String {
        let firstName = contact.givenName
        let lastName = contact.familyName

        if !firstName.isEmpty && !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        } else if !firstName.isEmpty {
            return firstName
        } else if !lastName.isEmpty {
            return lastName
        } else {
            return "Unknown"
        }
    }

    private func cleanPhoneNumber(_ number: String) -> String {
        // Remove all non-numeric characters
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        // Normalize to last 10 digits for US numbers
        if cleaned.count >= 10 {
            return String(cleaned.suffix(10))
        }

        return cleaned
    }
}
