//
//  ContactService.swift
//  imessage
//
//  Created by hunter diamond on 1/22/26.
//

import Foundation
import Contacts

class ContactService {
    static let shared = ContactService()

    private let contactStore = CNContactStore()
    private var contactLookup: [String: String] = [:]
    private var isLoaded = false

    private init() {
        requestAccessAndLoad()
    }

    private func requestAccessAndLoad() {
        contactStore.requestAccess(for: .contacts) { [weak self] granted, error in
            if granted {
                print("Contact access granted")
                self?.loadAllContacts()
            } else {
                print("Contact access denied: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }

    private func loadAllContacts() {
        let keysToFetch = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]

        do {
            let contacts = try contactStore.unifiedContacts(matching: NSPredicate(value: true), keysToFetch: keysToFetch)
            print("Loading \(contacts.count) contacts...")

            for contact in contacts {
                let name = formatContactName(contact)

                // Map all phone numbers to this contact
                for phoneNumber in contact.phoneNumbers {
                    let number = phoneNumber.value.stringValue
                    let cleanNumber = cleanPhoneNumber(number)

                    contactLookup[number] = name
                    contactLookup[cleanNumber] = name
                }

                // Map all email addresses to this contact
                for email in contact.emailAddresses {
                    let emailString = (email.value as String).lowercased()
                    contactLookup[emailString] = name
                }
            }

            isLoaded = true
            print("Loaded \(contactLookup.count) contact mappings")
        } catch {
            print("Failed to fetch contacts: \(error)")
        }
    }

    func getContactName(for identifier: String?) -> String? {
        guard let identifier = identifier else { return nil }

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
