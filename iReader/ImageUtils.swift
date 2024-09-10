//
//  ImageUtils.swift
//  iReader
//
//  Created by Jian Cheng on 2024/9/10.
//

import Foundation
import SwiftUI

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var url: URL?
    private var cache: ImageCache?
    
    init(cache: ImageCache? = nil) {
        self.cache = cache ?? ImageCache.shared
    }
    
    func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL for image: \(urlString)")
            return
        }
        self.url = url
        
        if let cachedImage = cache?[url] {
            print("Image loaded from cache: \(url)")
            self.image = cachedImage
            return
        }
        
        print("Fetching image from URL: \(url)")
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error loading image: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let loadedImage = UIImage(data: data) else {
                print("Invalid image data received from URL: \(url)")
                return
            }
            
            DispatchQueue.main.async {
                print("Image successfully loaded and cached: \(url)")
                self.cache?[url] = loadedImage
                if self.url == url {
                    self.image = loadedImage
                }
            }
        }.resume()
    }
}

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSURL, UIImage>()
    
    subscript(_ url: URL) -> UIImage? {
        get { cache.object(forKey: url as NSURL) }
        set {
            if let newValue = newValue {
                cache.setObject(newValue, forKey: url as NSURL)
            } else {
                cache.removeObject(forKey: url as NSURL)
            }
        }
    }
}
