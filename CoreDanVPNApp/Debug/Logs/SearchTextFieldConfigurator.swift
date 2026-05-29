import SwiftUI
import UIKit

struct SearchTextFieldConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { UIView() }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let viewController = uiView.nearestViewController(),
                  let searchTextField = viewController.navigationItem.searchController?.searchBar.searchTextField
            else { return }

            searchTextField.autocorrectionType = .no
            searchTextField.spellCheckingType = .no
            searchTextField.smartInsertDeleteType = .no
            searchTextField.inputAssistantItem.leadingBarButtonGroups = []
            searchTextField.inputAssistantItem.trailingBarButtonGroups = []
        }
    }
}

private extension UIView {
    func nearestViewController() -> UIViewController? {
        sequence(first: next, next: { $0?.next })
            .first(where: { $0 is UIViewController }) as? UIViewController
    }
}
