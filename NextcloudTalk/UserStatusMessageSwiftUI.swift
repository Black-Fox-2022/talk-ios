//
// Copyright (c) 2023 Lukas Lauerer <lukas.lauerer@gmx.net>
//
// Author Lukas Lauerer <lukas.lauerer@gmx.net>
//
// GNU GPL version 3 or any later version
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import SwiftUI
import NextcloudKit

struct UserStatusMessageSwiftUIView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var changed: Bool
    @State var showClearAtAlert: Bool = false
    
    @State private var changedStatusFromPredif: Bool = false
    @State private var customStatusSelected: Bool = false
    @State private var selectedPredifinedStatus: NKUserStatus?
    @State private var statusPredefinedStatuses: [NKUserStatus] = []
    
    @State private var selectedIcon: String = ""
    @State private var selectedMessage: String = ""
    @State private var selectedClearAt: Double = 0
    @State private var selectedClearAtString: String = ""
    
    @State private var isLoading: Bool = true
    let clearAtOptions = [
        NSLocalizedString("Don't clear", comment: ""),
        NSLocalizedString("30 minutes", comment: ""),
        NSLocalizedString("1 hour", comment: ""),
        NSLocalizedString("4 hours", comment: ""),
        NSLocalizedString("Today", comment: ""),
        NSLocalizedString("This week", comment: "")
    ]
    
    init(changed: Binding<Bool>) {
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: NCAppBranding.themeColor()]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: NCAppBranding.themeTextColor()]
        
        UINavigationBar.appearance().backgroundColor = NCAppBranding.themeColor()
        UINavigationBar.appearance().barTintColor = NCAppBranding.themeColor()
        
        _changed = changed
    }
    
    var body: some View {
        NavigationView {
            VStack {
                HStack (spacing: 10){
                    EmojiTextFieldWrapper(placeholder: "😀", text: $selectedIcon)
                        .frame(width: 40)
                        .opacity(selectedIcon == "" ? 0.5 : 1.0)
                        .onChange(of: selectedIcon) { newString in
                            customStatusSelected = true
                            print("Now its: \(newString)")
                            if newString.count > 1 { //Never more than one for some reason.... Even if i add more, the if is never right
                                print("More than one character")
                                selectedIcon = String(newString.first!)
                                print("Now sI is: \(selectedIcon)")
                            }
                        }
                    TextField(NSLocalizedString("What is your status?", comment: ""), text: $selectedMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: selectedIcon) { _ in
                            if changedStatusFromPredif {
                                customStatusSelected = false
                            }else {
                                customStatusSelected = true
                            }
                            changedStatusFromPredif = false
                        }
                }
                .frame(height: 32)
                .padding(.vertical)
                VStack (spacing: 20){
                    ForEach(statusPredefinedStatuses, id: \.id) { status in
                        Button(action: {
                            changedStatusFromPredif = true
                            selectedPredifinedStatus = status
                            customStatusSelected = false
                            selectedIcon = selectedPredifinedStatus!.icon ?? "Empty"
                            selectedMessage = selectedPredifinedStatus!.message ?? "Empty"
                            selectedClearAt = selectedPredifinedStatus!.clearAt?.timeIntervalSince1970 ?? 0
                            selectedClearAtString = getPredefinedClearStatusText(clearAt: status.clearAt, clearAtTime: status.clearAtTime, clearAtType: status.clearAtType)
                            setClearAt(clearAt: selectedClearAtString)
                        }) {
                            HStack{
                                Text(getStatusMessage(icon: status.icon ?? "", message: status.message ?? ""))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(getPredefinedClearStatusText(clearAt: status.clearAt, clearAtTime: status.clearAtTime, clearAtType: status.clearAtType))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                HStack {
                    Text(NSLocalizedString("Clear status message after", comment: ""))
                    Spacer()
                    Button(action: {
                        showClearAtAlert.toggle()
                    }) {
                        Text(selectedClearAtString)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 3)
                            .frame(width: 116)
                            .background(.clear)
                            .foregroundColor(.primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 0.5)
                            )
                    }
                }
                .padding(.vertical)
                Spacer()
                HStack (spacing: 10){
                    Button(action: {
                        clearActiveUserStatus()
                    }) {
                        Text(NSLocalizedString("Clear", comment: ""))
                            .font(.system(size: 18,weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.vertical)
                            .padding(.horizontal, 20)
                            .background(Color.clear)
                            .cornerRadius(20)
                            .opacity(selectedMessage == "" ? 0.5 : 1.0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                    }
                    .disabled(selectedMessage == "" ? true : false)
                    Button(action: {
                        setActiveUserStatus()
                    }) {
                        Text(NSLocalizedString("Set status message", comment: ""))
                            .font(.system(size: 18,weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical)
                            .padding(.horizontal, 20)
                            .background(Color(NCAppBranding.themeColor()))
                            .opacity(selectedMessage == "" ? 0.75 : 1.0)
                            .cornerRadius(20)
                    }
                    .disabled(selectedMessage == "" ? true : false)
                }

            }
            .opacity(isLoading ? 0.0 : 1.0)
            .padding(.top, 10)
            .padding(.horizontal, 20)
            .navigationBarTitle(Text(NSLocalizedString("Status message", comment: "")), displayMode: .inline)
            .navigationBarHidden(false)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                            }) {
                                Text("Cancel")
                                    .foregroundColor(Color(NCAppBranding.themeTextColor()))
                            }
                }
            })
        }
        
        .onAppear {
            getStatus()
        }
        .confirmationDialog("Clear status message after", isPresented: $showClearAtAlert, titleVisibility: .visible) {
            Button("Don't clear") {
                selectedClearAtString = "Don't clear"
                showClearAtAlert = false
                setClearAt(clearAt: NSLocalizedString("Don't clear", comment: ""))
            }
            
            Button("30 minutes") {
                selectedClearAtString = "30 minutes"
                showClearAtAlert = false
                setClearAt(clearAt: NSLocalizedString("30 minutes", comment: ""))
            }
            
            Button("1 hour") {
                selectedClearAtString = "1 hour"
                showClearAtAlert = false
                setClearAt(clearAt: NSLocalizedString("1 hour", comment: ""))
            }
            
            Button("4 hours") {
                selectedClearAtString = "4 hours"
                showClearAtAlert = false
                setClearAt(clearAt: NSLocalizedString("4 hours", comment: ""))
            }
            
            Button("Today") {
                selectedClearAtString = "Today"
                showClearAtAlert = false
                setClearAt(clearAt: NSLocalizedString("Today", comment: ""))
            }
            
            Button("This week") {
                selectedClearAtString = "This week"
                showClearAtAlert = false
                setClearAt(clearAt: NSLocalizedString("This week", comment: ""))
            }
        }
    }
    
    
    func getStatus() {
        isLoading = true
        NCAPIController.sharedInstance().setupNCCommunication(for: NCDatabaseManager.sharedInstance().activeAccount())
        NextcloudKit.shared.getUserStatus { _, clearAt, icon, message, _, _, _, _, _, _, error in
            if error.errorCode == 0 {
                selectedIcon = icon ?? "😀"
                selectedMessage = message ?? ""
                selectedClearAt = clearAt?.timeIntervalSince1970 ?? 0
                selectedClearAtString = getPredefinedClearStatusText(clearAt: clearAt, clearAtTime: nil, clearAtType: nil)
            }
        }
        NextcloudKit.shared.getUserStatusPredefinedStatuses { _, userStatuses, _, error in
            if error.errorCode == 0 {
                statusPredefinedStatuses = userStatuses!
                
                withAnimation{
                    isLoading = false
                }
            }
        }
    }
    
    func setActiveUserStatus() {
        if !customStatusSelected{
            NextcloudKit.shared.setCustomMessagePredefined(messageId: selectedPredifinedStatus!.id!, clearAt: selectedClearAt) { _, error in
                if error.errorCode == 0 {
                 //   let clearAtDate = NSDate(timeIntervalSince1970: selectedClearAt)
                 //   self.delegate?.didSetStatusMessage(icon: self.predefinedStatusSelected?.icon, message: self.predefinedStatusSelected?.message, clearAt: clearAtDate)
                    dismiss()
                    changed.toggle()
                } else {
                    self.showErrorDialog(title: NSLocalizedString("Could not set status message", comment: ""),
                                         message: NSLocalizedString("An error occurred while setting status message", comment: ""))
                }
            }
        } else {
            NextcloudKit.shared.setCustomMessageUserDefined(statusIcon: selectedIcon == "" ? "😀" : selectedIcon, message: selectedMessage, clearAt: selectedClearAt) { _, error in
                if error.errorCode == 0 {
                   // let clearAtDate = NSDate(timeIntervalSince1970: clearAtDate)
                   // self.delegate?.didSetStatusMessage(icon: self.iconSelected, message: selectedMessage, clearAt: clearAtDate)
                    dismiss()
                    changed.toggle()
                } else {
                    self.showErrorDialog(title: NSLocalizedString("Could not set status message", comment: ""),
                                         message: NSLocalizedString("An error occurred while setting status message", comment: ""))
                }
            }
        }
    }
    
    func clearActiveUserStatus() {
        NextcloudKit.shared.clearMessage { _, error in
            if error.errorCode == 0 {
                dismiss()
                changed.toggle()
            } else {
                self.showErrorDialog(title: NSLocalizedString("Could not clear status message", comment: ""),
                                     message: NSLocalizedString("An error occurred while clearing status message", comment: ""))
            }
        }
    }
    
    func getClearAt(_ clearAtString: String) -> Double {
        let now = Date()
        let calendar = Calendar.current
        let gregorian = Calendar(identifier: .gregorian)
        let midnight = calendar.startOfDay(for: now)

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: midnight) else { return 0 }
        guard let startweek = gregorian.date(from: gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return 0 }
        guard let endweek = gregorian.date(byAdding: .day, value: 6, to: startweek) else { return 0 }

        switch clearAtString {
        case NSLocalizedString("Don't clear", comment: ""):
            return 0
        case NSLocalizedString("30 minutes", comment: ""):
            let date = now.addingTimeInterval(1800)
            return date.timeIntervalSince1970
        case NSLocalizedString("1 hour", comment: ""), NSLocalizedString("an hour", comment: ""):
            let date = now.addingTimeInterval(3600)
            return date.timeIntervalSince1970
        case NSLocalizedString("4 hours", comment: ""):
            let date = now.addingTimeInterval(14400)
            return date.timeIntervalSince1970
        case NSLocalizedString("Today", comment: ""):
            return tomorrow.timeIntervalSince1970
        case NSLocalizedString("This week", comment: ""):
            return endweek.timeIntervalSince1970
        default:
            return 0
        }
    }
    /*
    func clearAtLabelPressed() {
        let clearAtOptions = [
            NSLocalizedString("Don't clear", comment: ""),
            NSLocalizedString("30 minutes", comment: ""),
            NSLocalizedString("1 hour", comment: ""),
            NSLocalizedString("4 hours", comment: ""),
            NSLocalizedString("Today", comment: ""),
            NSLocalizedString("This week", comment: "")
        ]

        let alert = Alert(title: Text("Clear status message after"), message: nil, buttons: [
            for clearAtOption in clearAtOptions {
                .default(clearAtOption, action: {
                    self.setClearAt(clearAt: clearAtOption)
                })
            },
            .cancel(NSLocalizedString("Cancel", comment: ""))
        ])

        alert.popoverPresentationController?.sourceView = clearAtLabel

        present(alert, animated: true)
    }*/
    
    func setClearAt(clearAt: String) {
        selectedClearAt = getClearAt(clearAt)
        selectedClearAtString = clearAt
    }
    
    func getStatusMessage(icon: String, message: String) -> String {
        let statusString = icon + "     " + message
        return statusString
    }
        
    func getPredefinedClearStatusText(clearAt: NSDate?, clearAtTime: String?, clearAtType: String?) -> String {
        // Date
        if clearAt != nil {
            let from = Date()
            let to = clearAt! as Date

            let day = Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
            let hour = Calendar.current.dateComponents([.hour], from: from, to: to).hour ?? 0
            let minute = Calendar.current.dateComponents([.minute], from: from, to: to).minute ?? 0

            if day > 0 {
                if day == 1 { return NSLocalizedString("Today", comment: "") }
                return "\(day) " + NSLocalizedString("days", comment: "")
            }

            if hour > 0 {
                if hour == 1 { return NSLocalizedString("an hour", comment: "") }
                if hour == 4 { return NSLocalizedString("4 hours", comment: "") }
                return "\(hour) " + NSLocalizedString("hours", comment: "")
            }

            if minute > 0 {
                if minute >= 25 && minute <= 30 { return NSLocalizedString("30 minutes", comment: "") }
                if minute > 30 { return NSLocalizedString("an hour", comment: "") }
                return "\(minute) " + NSLocalizedString("minutes", comment: "")
            }
        }

        // Period
        if clearAtTime != nil && clearAtType == "period" {
            switch clearAtTime {
            case "14400":
                return NSLocalizedString("4 hours", comment: "")
            case "3600":
                return NSLocalizedString("an hour", comment: "")
            case "1800":
                return NSLocalizedString("30 minutes", comment: "")
            default:
                return clearAtTime!
            }
        }

        // End of
        if clearAtTime != nil && clearAtType == "end-of" {
            switch clearAtTime {
            case "day":
                return NSLocalizedString("Today", comment: "")
            case "week":
                return NSLocalizedString("This week", comment: "")
            default:
                return clearAtTime!
            }
        }

        return NSLocalizedString("Don't clear", comment: "")
    }
    
    func showErrorDialog(title: String?, message: String?) {
      //  let alert = Alert(title: title, message: message, dismissButton: .cancel())
     //   if let parent = self.parent {
      //          parent.present(alert, animated: true)
      //      }
    }

    
}

struct EmojiTextField2: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        // Implement EmojiTextField
        TextField(placeholder, text: $text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
}

class UserStatusMessageViewModel: ObservableObject {
    @Published var statusEmoji = "😀"
    @Published var statusMessage = "What is your status?"
    @Published var clearAtLabel = NSLocalizedString("Don't clear", comment: "")
    @Published var predefinedStatusSelected: NKUserStatus?
    @Published var statusPredefinedStatuses: [NKUserStatus] = []
    @Published var userStatusOptions: UserStatusOptions

    init(userStatus: NCUserStatus?) {
        self.userStatusOptions = UserStatusOptions(userStatus: userStatus)
    }
    
    var formattedClearStatusText: String {
            guard let status = predefinedStatusSelected else {
                return NSLocalizedString("Don't clear", comment: "")
            }
            return "\(status.icon ?? "")   \(status.message ?? "") - \(getPredefinedClearStatusText(clearAt: status.clearAt, clearAtTime: status.clearAtTime, clearAtType: status.clearAtType))"
        }
    
    func clearStatusMessage() {
        // Implement clear status message functionality
    }

    func setStatusMessage() {
        // Implement set status message functionality
    }

    func cancelButtonPressed() {
        // Implement cancel button functionality
    }

    func showClearAtActionSheet() {
        // Implement action sheet for clear status
    }

    func getPredefinedClearStatusText(clearAt: NSDate?, clearAtTime: String?, clearAtType: String?) -> String {
        // Date
        if clearAt != nil {
            let from = Date()
            let to = clearAt! as Date

            let day = Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
            let hour = Calendar.current.dateComponents([.hour], from: from, to: to).hour ?? 0
            let minute = Calendar.current.dateComponents([.minute], from: from, to: to).minute ?? 0

            if day > 0 {
                if day == 1 { return NSLocalizedString("Today", comment: "") }
                return "\(day) " + NSLocalizedString("days", comment: "")
            }

            if hour > 0 {
                if hour == 1 { return NSLocalizedString("an hour", comment: "") }
                if hour == 4 { return NSLocalizedString("4 hours", comment: "") }
                return "\(hour) " + NSLocalizedString("hours", comment: "")
            }

            if minute > 0 {
                if minute >= 25 && minute <= 30 { return NSLocalizedString("30 minutes", comment: "") }
                if minute > 30 { return NSLocalizedString("an hour", comment: "") }
                return "\(minute) " + NSLocalizedString("minutes", comment: "")
            }
        }

        // Period
        if clearAtTime != nil && clearAtType == "period" {
            switch clearAtTime {
            case "14400":
                return NSLocalizedString("4 hours", comment: "")
            case "3600":
                return NSLocalizedString("an hour", comment: "")
            case "1800":
                return NSLocalizedString("30 minutes", comment: "")
            default:
                return clearAtTime!
            }
        }

        // End of
        if clearAtTime != nil && clearAtType == "end-of" {
            switch clearAtTime {
            case "day":
                return NSLocalizedString("Today", comment: "")
            case "week":
                return NSLocalizedString("This week", comment: "")
            default:
                return clearAtTime!
            }
        }

        return NSLocalizedString("Don't clear", comment: "")
    }

    func setPredefinedStatusInView(predefinedStatus: NKUserStatus?) {
        // Implement setPredefinedStatusInView
    }


}

struct UserStatusMessageSwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        UserStatusMessageSwiftUIView(changed: Binding.constant(false))
    }
}
