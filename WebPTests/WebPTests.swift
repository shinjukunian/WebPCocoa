//
//  WebPTests.swift
//  WebPTests
//
//  Created by Morten Bertz on 2017/09/13.
//  Copyright © 2017 telethon k.k. All rights reserved.
//

import XCTest
import WebP

class WebPTests: XCTestCase {
    
    let outURL=URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("WebP").appendingPathExtension("webp")
    let timeInterval:TimeInterval=0.1
    lazy var imageURLS:[URL]={
        guard let urls=Bundle(for: type(of: self)).urls(forResourcesWithExtension: nil, subdirectory: "testData")?.sorted(by: {u1,u2 in
            return u1.lastPathComponent.compare(u2.lastPathComponent, options:[.numeric]) == .orderedAscending
        }) else{
            XCTFail("No Images Loaded")
            return [URL]()
        }
        XCTAssertGreaterThan(urls.count, 1, "insufficient images loaded")
        return urls
    }()
    lazy var webPImageURL:URL={
        let url=Bundle(for: type(of: self)).url(forResource: "GenevaDrive", withExtension: "webp")
        XCTAssertNotNil(url, "WebP not found")
        return url!
    }()
    
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    
    func testEncoding() {
       
        let images=self.imageURLS.flatMap({url->CGImage? in
            guard let source=CGImageSourceCreateWithURL(url as CFURL, nil) else{return nil}
            XCTAssert(CGImageSourceGetCount(source) == 1, "Image Source has image count too high")
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        })
        XCTAssertEqual(images.count, self.imageURLS.count)
        
        let encoder=WebPEncoder()
        var startTime:TimeInterval=0
        for image in images{
            let success=encoder.addFrame(image, withTimeStamp: startTime)
            startTime+=self.timeInterval
            XCTAssert(success, "Image Encoding failed")
        }
        let expectation=self.expectation(description: "Image Encoding")
        encoder.encodeFrames(to: self.outURL, withCompletion: {url in
            XCTAssertNotNil(url, "Encoding failed")
            expectation.fulfill()
        })
        
        self.waitForExpectations(timeout: 10, handler: {_ in
            
            let decoder=WebPDecoder(url: self.outURL, shouldCache: true)
            XCTAssert(decoder.numberOfFrames <= images.count, "Number of Encoded Frames wrong")
            XCTAssert(decoder.numberOfFrames > 0, "Number of Encoded Frames wrong")
            XCTAssertEqual(decoder.frameSize.width, CGFloat(images.first?.width ?? 0), accuracy: 1, "image width wrong")
            XCTAssertEqual(decoder.frameSize.height, CGFloat(images.first?.height ?? 0), accuracy: 1, "image width wrong")
            let totalDuration=decoder.durations.map({$0.doubleValue}).reduce(0, +)/1000
            XCTAssertEqual(totalDuration, self.timeInterval*TimeInterval(self.imageURLS.count), accuracy: totalDuration/100, "Total duration Wrong")
            for i in 0..<decoder.numberOfFrames{
                let image=decoder.image(at: i)
                XCTAssertNotNil(image, "image coul not be decoded")
            }
            
        })
        
        self.addTeardownBlock {
            do{
                try FileManager.default.removeItem(at: self.outURL)
            }
            catch let error{
                print(error)
            }
        }
    }
    
    
    
    func testDecoding(){
        let decoder=WebPDecoder(url: self.webPImageURL, shouldCache: true)
        XCTAssert(decoder.numberOfFrames>0, "number of frames is 0")
        XCTAssert(decoder.frameSize != .zero, "frame size zero")
        for duration in decoder.durations.map({$0.doubleValue}){
            XCTAssert(duration>0, "frame duration is 0")
        }
        for i in 0..<decoder.numberOfFrames{
            let image=decoder.image(at: i)
            XCTAssertNotNil(image, "image coul not be decoded")
        }
        
    }
    
    
    
}
