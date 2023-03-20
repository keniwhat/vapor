import Foundation
import NIOCore
import NIOHTTP1

extension JSONEncoder: ContentEncoder {
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws
        where E: Encodable
    {
        try self.encode(encodable, to: &body, headers: &headers, userInfo: [:])
    }
    
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders, userInfo: [CodingUserInfoKey: Any]) throws
        where E: Encodable
    {
        headers.contentType = .json
        
        if !userInfo.isEmpty {
            let actualEncoder = JSONEncoder()
            actualEncoder.outputFormatting = self.outputFormatting
            actualEncoder.dateEncodingStrategy = self.dateEncodingStrategy
            actualEncoder.dataEncodingStrategy = self.dataEncodingStrategy
            actualEncoder.nonConformingFloatEncodingStrategy = self.nonConformingFloatEncodingStrategy
            actualEncoder.keyEncodingStrategy = self.keyEncodingStrategy
            actualEncoder.userInfo = self.userInfo.merging(userInfo) { $1 }
            try body.writeBytes(actualEncoder.encode(encodable))
        } else {
            try body.writeBytes(self.encode(encodable))
        }
    }
}

extension JSONDecoder: ContentDecoder {
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D
        where D: Decodable
    {
        try self.decode(D.self, from: body, headers: headers, userInfo: [:])
    }
    
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders, userInfo: [CodingUserInfoKey: Any]) throws -> D
        where D: Decodable
    {
        let data = body.getData(at: body.readerIndex, length: body.readableBytes) ?? Data()
        
        if !userInfo.isEmpty {
            let actualDecoder = JSONDecoder()
            actualDecoder.dateDecodingStrategy = self.dateDecodingStrategy
            actualDecoder.dataDecodingStrategy = self.dataDecodingStrategy
            actualDecoder.nonConformingFloatDecodingStrategy = self.nonConformingFloatDecodingStrategy
            actualDecoder.keyDecodingStrategy = self.keyDecodingStrategy
            if #available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *) {
                actualDecoder.allowsJSON5 = self.allowsJSON5
                actualDecoder.assumesTopLevelDictionary = self.assumesTopLevelDictionary
            }
            actualDecoder.userInfo = self.userInfo.merging(userInfo) { $1 }
            return try actualDecoder.decode(D.self, from: data)
        } else {
            return try self.decode(D.self, from: data)
        }
    }
}
