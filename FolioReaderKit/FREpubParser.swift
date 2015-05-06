//
//  FREpubParser.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 04/05/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import SSZipArchive

class FREpubParser: NSObject {
    let book = FRBook()
    var bookBasePath: String!
    var resourcesBasePath: String!
    
    /**
    Unzip and read an epub file.
    Returns a FRBook.
    */
    func readEpub(epubPath withEpubPath: String) -> FRBook {
        
        // Unzip   
        let bookName = withEpubPath.lastPathComponent.stringByDeletingPathExtension
        let separator = "/"
        bookBasePath = kApplicationDocumentsDirectory + separator + bookName + separator
//        SSZipArchive.unzipFileAtPath(withEpubPath, toDestination: bookBasePath)
        
        readContainer()
        readOpf()
        

        return book
    }
    
    /**
    Read an unziped epub file.
    Returns a FRBook.
    */
    func readEpub(filePath withFilePath: String) -> FRBook {
        
        return book
    }
    
    /**
    Read and parse container.xml file.
    */
    private func readContainer() {
        let containerPath = "META-INF/container.xml"
        let containerData = NSData(contentsOfFile: bookBasePath+containerPath, options: .DataReadingMappedAlways, error: nil)
        var error: NSError?
        
        if let xmlDoc = AEXMLDocument(xmlData: containerData!, error: &error) {
//            println(xmlDoc.xmlString)
            let opfResource = FRResource()
            opfResource.href = xmlDoc.root["rootfiles"]["rootfile"].attributes["full-path"] as! String
            opfResource.mediaType = FRMediaType.determineMediaType(xmlDoc.root["rootfiles"]["rootfile"].attributes["full-path"] as! String)
            book.opfResource = opfResource
            resourcesBasePath = bookBasePath + book.opfResource.href.stringByDeletingLastPathComponent + "/"
        }
    }
    
    /**
    Read and parse .opf file.
    */
    private func readOpf() {
        let opfPath = bookBasePath + book.opfResource.href
        let opfData = NSData(contentsOfFile: opfPath, options: .DataReadingMappedAlways, error: nil)
        var error: NSError?
        
        if let xmlDoc = AEXMLDocument(xmlData: opfData!, error: &error) {
//            println(xmlDoc.xmlString)
            for item in xmlDoc.root["manifest"]["item"].all! {
                let resource = FRResource()
                resource.id = item.attributes["id"] as! String
                resource.href = item.attributes["href"] as! String
                resource.mediaType = FRMediaType.mediaTypesByName[item.attributes["media-type"] as! String]
                book.resources.add(resource)
            }
            
            // Get the first resource with the NCX mediatype
            book.ncxResource = book.resources.findFirstResource(byMediaType: FRMediaType.NCX)
            
            if book.ncxResource == nil {
                println("ERROR: Could not find table of contents resource. The book don't have a NCX resource.")
            }
            
            // The book TOC
            book.tableOfContents = findTableOfContents()
            
            // Read metadata
            book.metadata = readMetadata(xmlDoc.root["metadata"].children)
        }
    }
    
    private func findTableOfContents() -> [FRTOCReference] {
        let ncxPath = resourcesBasePath + book.ncxResource.href
        let ncxData = NSData(contentsOfFile: ncxPath, options: .DataReadingMappedAlways, error: nil)
        var error: NSError?
        
        var tableOfContent = [FRTOCReference]()
        
        if let xmlDoc = AEXMLDocument(xmlData: ncxData!, error: &error) {
            for item in xmlDoc.root["navMap"]["navPoint"].all! {
                tableOfContent.append(readTOCReference(item))
            }
        }
        
        return tableOfContent
    }
    
    private func readTOCReference(navpointElement: AEXMLElement) -> FRTOCReference {
        let label = navpointElement["navLabel"]["text"].value as String!
        let reference = navpointElement["content"].attributes["src"] as! String!
        
        let hrefSplit = split(reference) {$0 == "#"}
        let fragmentID = hrefSplit.count > 1 ? hrefSplit[1] : ""
        let href = hrefSplit[0]
        
        let resource = book.resources.getByHref(href)
        let toc = FRTOCReference(title: label, resource: resource!, fragmentID: fragmentID)
        
        if navpointElement["navPoint"].all != nil {
            for navPoint in navpointElement["navPoint"].all! {
                toc.children.append(readTOCReference(navPoint))
            }
        }        
        return toc
    }
    
    private func readMetadata(tags: [AEXMLElement]) -> FRMetadata {
        let metadata = FRMetadata()
        
        for tag in tags {
            println(tag.xmlString)
            
            if tag.name == "dc:title" {
                metadata.titles.append(tag.value!)
            }
            
            if tag.name == "dc:identifier" {
                metadata.identifiers.append(Identifier(scheme: tag.attributes["opf:scheme"] as! String, value: tag.value!))
            }
            
            if tag.name == "dc:language" {
                metadata.language = tag.value != nil ? tag.value! : ""
            }
            
            if tag.name == "dc:creator" {
                metadata.creators.append(Author(name: tag.value!, role: tag.attributes["opf:role"] as! String, fileAs: tag.attributes["opf:file-as"] as! String))
            }
            
            if tag.name == "dc:contributor" {
                metadata.creators.append(Author(name: tag.value!, role: tag.attributes["opf:role"] as! String, fileAs: tag.attributes["opf:file-as"] as! String))
            }
            
            if tag.name == "dc:publisher" {
                metadata.publishers.append(tag.value != nil ? tag.value! : "")
            }
            
            if tag.name == "dc:description" {
                metadata.descriptions.append(tag.value != nil ? tag.value! : "")
            }
            
            if tag.name == "dc:subject" {
                metadata.subjects.append(tag.value != nil ? tag.value! : "")
            }
            
            if tag.name == "dc:rights" {
                metadata.rights.append(tag.value != nil ? tag.value! : "")
            }
            
            if tag.name == "dc:date" {
                metadata.dates.append(Date(date: tag.value!, event: tag.attributes["opf:event"] as! String))
            }
            
            if tag.name == "meta" {
                metadata.metaAttributes = [tag.attributes["name"] as! String: tag.attributes["content"] as! String]
            }
            
        }
        return metadata
    }
}
