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
    // 可以添加其他静态方法
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
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    func image(for key: String) -> UIImage? {
        if let cachedImage = cache.object(forKey: key as NSString) {
            return cachedImage
        }
        
        let fileURL = cacheDirectory.appendingPathComponent(key)
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            cache.setObject(image, forKey: key as NSString)
            return image
        }
        
        return nil
    }
    
    func setImage(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
        
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? image.pngData()?.write(to: fileURL)
    }
    
    // 添加下标方法
    subscript(url: URL) -> UIImage? {
        get {
            return image(for: url.absoluteString)
        }
        set {
            if let newValue = newValue {
                setImage(newValue, for: url.absoluteString)
            }
        }
    }
}

extension ImageUtils {
    @MainActor
    static func convertToUIImage(from image: Image) -> UIImage? {
        let renderer = ImageRenderer(content: image)
        return renderer.uiImage
    }
    
    static func imageSizeInBytes(_ image: UIImage) -> Int {
        if let imageData = image.jpegData(compressionQuality: 1.0) {
            return imageData.count
        }
        return 0
    }
    
    @MainActor
    static func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        
        return resizedImage
    }
}
