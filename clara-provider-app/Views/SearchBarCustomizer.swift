import SwiftUI
import UIKit

struct SearchBarCustomizer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        // Set up a timer to continuously check and update search bars
        context.coordinator.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            context.coordinator.customizeSearchBars()
        }
        
        // Initial customization
        DispatchQueue.main.async {
            context.coordinator.customizeSearchBars()
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.customizeSearchBars()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var timer: Timer?
        
        func customizeSearchBars() {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            
            customizeSearchBars(in: window)
        }
        
        private func customizeSearchBars(in view: UIView) {
            for subview in view.subviews {
                if let searchBar = subview as? UISearchBar {
                    searchBar.searchTextField.backgroundColor = .white
                    searchBar.searchTextField.textColor = .black
                    if #available(iOS 13.0, *) {
                        searchBar.searchTextField.layer.backgroundColor = UIColor.white.cgColor
                    }
                    // Force update
                    searchBar.setNeedsLayout()
                    searchBar.layoutIfNeeded()
                }
                customizeSearchBars(in: subview)
            }
        }
    }
}




