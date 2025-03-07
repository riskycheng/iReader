//
//  ImageUtils.swift
//  iReader
//
//  Created by Jian Cheng on 2024/9/10.
//

import Foundation
import UIKit
import Combine
import SwiftUI

class ImageUtils {
    static let shared = ImageUtils()
    
    private init() {}
    
    @MainActor
    static func convertToUIImage(from image: Image) async -> UIImage? {
        let renderer = ImageRenderer(content: image)
        return renderer.uiImage
    }
    
    static func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // 使用较小的比例，确保图片完全适应目标尺寸
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
    
    static func imageSizeInBytes(_ image: UIImage) -> Int {
        if let cgImage = image.cgImage {
            return cgImage.bytesPerRow * cgImage.height
        }
        return 0
    }
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var url: URL?
    private var cache: ImageCache?
    private var cancellable: AnyCancellable?
    
    init(cache: ImageCache? = nil) {
        self.cache = cache ?? ImageCache.shared
    }
    
    func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL for image: \(urlString)")
            return
        }
        
        self.url = url
        
        if let cachedImage = cache?.image(for: url.absoluteString) {
            print("Image loaded from cache: \(url)")
            DispatchQueue.main.async {
                self.image = cachedImage
            }
            return
        }
        
        print("Fetching image from URL: \(url)")
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loadedImage in
                guard let self = self, let loadedImage = loadedImage else { return }
                print("Image successfully loaded and cached: \(url)")
                self.cache?.setImage(loadedImage, for: url.absoluteString)
                if self.url == url {
                    self.image = loadedImage
                }
            }
    }
}

class ImageCache {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100 // 限制缓存图片数量
        cache.totalCostLimit = 50 * 1024 * 1024 // 限制缓存大小为50MB
    }
    
    func setImage(_ image: UIImage, for url: String) {
        cache.setObject(image, forKey: url as NSString)
    }
    
    func image(for url: String) -> UIImage? {
        return cache.object(forKey: url as NSString)
    }
    
    func removeImage(for url: String) {
        cache.removeObject(forKey: url as NSString)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}
