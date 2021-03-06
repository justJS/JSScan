//
//  NSImage+Utils.swift
//  JSScan
//
//  Created by Julian Schiavo on 7/1/2019.
//  Copyright © 2019 Julian Schiavo. All rights reserved.
//

import Cocoa

extension NSImage {

    /// Returns the height of the current image.
    var height: CGFloat {
        return self.size.height
    }

    /// Returns the width of the current image.
    var width: CGFloat {
        return self.size.width
    }

    /// Returns a png representation of the current image.
    var pngRepresentation: Data? {
        if let tiff = self.tiffRepresentation, let tiffData = NSBitmapImageRep(data: tiff) {
            return tiffData.representation(using: .png, properties: [:])
        }

        return nil
    }

    ///  Copies the current image and resizes it to the given size.
    ///
    ///  - parameter size: The size of the new image.
    ///
    ///  - returns: The resized copy of the given image.
    func copy(size: NSSize) -> NSImage? {
        // Create a new rect with given width and height
        let frame = NSMakeRect(0, 0, size.width, size.height)

        // Get the best representation for the given size.
        guard let rep = self.bestRepresentation(for: frame, context: nil, hints: nil) else {
            return nil
        }

        // Create an empty image with the given size.
        let img = NSImage(size: size)

        // Set the drawing context and make sure to remove the focus before returning.
        img.lockFocus()
        defer { img.unlockFocus() }

        // Draw the new image
        if rep.draw(in: frame) {
            return img
        }

        // Return nil in case something went wrong.
        return nil
    }

    ///  Copies the current image and resizes it to the size of the given NSSize, while
    ///  maintaining the aspect ratio of the original image.
    ///
    ///  - parameter size: The size of the new image.
    ///
    ///  - returns: The resized copy of the given image.
    func resizeWhileMaintainingAspectRatioToSize(size: NSSize) -> NSImage? {
        let newSize: NSSize

        let widthRatio  = size.width / self.width
        let heightRatio = size.height / self.height

        if widthRatio > heightRatio {
            newSize = NSSize(width: floor(self.width * widthRatio), height: floor(self.height * widthRatio))
        } else {
            newSize = NSSize(width: floor(self.width * heightRatio), height: floor(self.height * heightRatio))
        }

        return self.copy(size: newSize)
    }

    ///  Copies and crops an image to the supplied size.
    ///
    ///  - parameter size: The size of the new image.
    ///
    ///  - returns: The cropped copy of the given image.
    func crop(size: NSSize) -> NSImage? {
        // Resize the current image, while preserving the aspect ratio.
        guard let resized = self.resizeWhileMaintainingAspectRatioToSize(size: size) else {
            return nil
        }
        // Get some points to center the cropping area.
        let x = floor((resized.width - size.width) / 2)
        let y = floor((resized.height - size.height) / 2)

        // Create the cropping frame.
        let frame = NSMakeRect(x, y, size.width, size.height)

        // Get the best representation of the image for the given cropping frame.
        guard let rep = resized.bestRepresentation(for: frame, context: nil, hints: nil) else {
            return nil
        }

        // Create a new image with the new size
        let img = NSImage(size: size)

        img.lockFocus()
        defer { img.unlockFocus() }

        if rep.draw(in: NSMakeRect(0, 0, size.width, size.height),
                    from: frame,
                    operation: NSCompositingOperation.copy,
                    fraction: 1.0,
                    respectFlipped: false,
                    hints: [:]) {
            // Return the cropped image.
            return img
        }

        // Return nil in case anything fails.
        return nil
    }

    ///  Saves the PNG representation of the current image to the HD.
    ///
    /// - parameter url: The location url to which to write the png file.
    func savePNGRepresentationToURL(url: URL) throws {
        if let png = self.pngRepresentation {
            try png.write(to: url, options: .atomicWrite)
        }
    }

    /// Crop image with given rect.
    ///
    /// - Parameter rect: The rect to crop relative to source image.
    /// - Returns: Cropped NSImage.
    func crop(to rect: NSRect) -> NSImage {
        let x = min(max(rect.origin.x, 0), size.width)
        let y = min(max(rect.origin.y, 0), size.height)
        let w = min(x + rect.size.width, size.width)
        let h = min(y + rect.size.height, size.height)
        let croppedRect = NSMakeRect(x, y, w, h)
        let newRect = NSRect(origin: .zero, size: croppedRect.size)
        let croppedImage = NSImage(size: croppedRect.size)
        
        croppedImage.lockFocus()
        draw(in: newRect, from: croppedRect, operation: .copy, fraction: 1)
        croppedImage.unlockFocus()
        
        return croppedImage
    }
    
    func croppedToQuad(_ quad: Quadrilateral) -> NSImage {
        guard let tiff = self.tiffRepresentation else { return self }
        
        let scaledQuad = quad.scale(CGSize(width: 400, height: 400), self.size)
        
        var cartesianScaledQuad = scaledQuad.toCartesian(withHeight: self.size.height)
        cartesianScaledQuad.reorganize()
        
        guard let ciImage = CIImage(data: tiff)?.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: cartesianScaledQuad.bottomLeft),
            "inputTopRight": CIVector(cgPoint: cartesianScaledQuad.bottomRight),
            "inputBottomLeft": CIVector(cgPoint: cartesianScaledQuad.topLeft),
            "inputBottomRight": CIVector(cgPoint: cartesianScaledQuad.topRight)
            ]) else { return self }
        
        let rep = NSCIImageRep(ciImage: ciImage)
        let finalImage = NSImage(size: rep.size)
        finalImage.addRepresentation(rep)
        
        return finalImage
    }
}
