import SwiftUI
import UIKit

enum PageTurningMode {
    case curl     // 仿真翻页效果
    case horizontal  // 水平滑动
    case direct   // 直接切换
}

struct PageTurningView<Content: View>: UIViewControllerRepresentable {
    let mode: PageTurningMode
    @Binding var currentPage: Int
    let totalPages: Int
    let onPageChange: (Int) -> Void
    let onNextChapter: () -> Void
    let onPreviousChapter: () -> Void
    let contentView: (Int) -> Content  // 根据页码生成内容视图

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        switch mode {
        case .curl:
            let pageViewController = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal)
            pageViewController.dataSource = context.coordinator
            pageViewController.delegate = context.coordinator
            if let initialVC = context.coordinator.viewControllerAtIndex(index: currentPage) {
                pageViewController.setViewControllers([initialVC], direction: .forward, animated: false)
            }
            return pageViewController
        case .horizontal, .direct:
            let hostingController = UIHostingController(rootView: contentView(currentPage))
            return hostingController
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 更新视图控制器
        if mode == .curl, let pageViewController = uiViewController as? UIPageViewController {
            if let currentVC = context.coordinator.viewControllerAtIndex(index: currentPage) {
                pageViewController.setViewControllers([currentVC], direction: .forward, animated: false)
            }
        } else if let hostingController = uiViewController as? UIHostingController<Content> {
            hostingController.rootView = contentView(currentPage)
        }
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageTurningView

        init(_ parent: PageTurningView) {
            self.parent = parent
        }

        func viewControllerAtIndex(index: Int) -> UIViewController? {
            guard index >= 0 && index < parent.totalPages else { return nil }
            let vc = UIHostingController(rootView: parent.contentView(index))
            vc.view.tag = index
            return vc
        }

        func indexOfViewController(viewController: UIViewController) -> Int {
            return viewController.view.tag
        }

        // MARK: - UIPageViewControllerDataSource

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            let index = indexOfViewController(viewController: viewController)
            if index == 0 {
                // 如果是第一页，调用上一章
                DispatchQueue.main.async {
                    self.parent.onPreviousChapter()
                }
                return nil
            }
            return viewControllerAtIndex(index: index - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            let index = indexOfViewController(viewController: viewController)
            if index == parent.totalPages - 1 {
                // 如果是最后一页，调用下一章
                DispatchQueue.main.async {
                    self.parent.onNextChapter()
                }
                return nil
            }
            return viewControllerAtIndex(index: index + 1)
        }

        // MARK: - UIPageViewControllerDelegate

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed, let visibleViewController = pageViewController.viewControllers?.first {
                let index = indexOfViewController(viewController: visibleViewController)
                parent.currentPage = index
                parent.onPageChange(index)
            }
        }
    }
}