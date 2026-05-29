//
//  UserDefaultsValueEditView.swift
//  KnowledgeBaseApp
//
//  Created by Korotaev Danil on 16.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import SwiftUI
import UIKit

struct UserDefaultsValueEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: UserDefaultsDetailView.ViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.valueType == .date {
                DatePicker("Value", selection: $viewModel.dateValue)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                Spacer(minLength: 0)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .foregroundColor(.clear)
                    TextEditor(text: $viewModel.stringValue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .autocapitalization(.none)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Edit value")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Update") {
                    viewModel.didUpdateActionRequested()
                }
            }
        }
        .kbErrorAlert(error: $viewModel.error)
        .onChange(of: viewModel.success) { _, success in
            if success {
                dismiss()
            }
        }
    }
}
