//
//  MP4.swift
//
//  Created by Vincent Neo on 25/8/25.
//  Contains AI generated code.
//

import Foundation

struct MP4 {
    
    // UTC Time, 1904-01-01 00:00:00
    static let midnight1904 = Date(timeIntervalSince1970: -2082844800)
    
    protocol Atom {
        var type: String { get }
        func encode() -> Data
    }
    
    struct Ftyp: Atom {
        let type = "ftyp"
        let brand: Brand
        var version: UInt32
        var compatibleBrands: [Brand] = [.baseMedia, .baseMedia2, .mp41, .mp42]
        
        func encode() -> Data {
            var data = Data()
            let typeData = Data(type.utf8)
            let brandData = brand.data
            let versionData = version.data
            let compatibleBrandsData = Data(compatibleBrands.map({$0.data}).joined())
            let countSize = 4
            let count = UInt32(countSize + typeData.count + brandData.count + versionData.count + compatibleBrandsData.count)
            
            data.append(count.data)
            data.append(typeData)
            data.append(brandData)
            data.append(versionData)
            data.append(compatibleBrandsData)
            return data
        }
        
        enum Brand: String {
            /// MP4 Base Media v1 (ISO 14496-12:2003)
            case baseMedia = "isom"
            case baseMedia2 = "iso2"
            case mp41 = "mp41"
            case mp42 = "mp42"
            
            var data: Data {
                return Data(rawValue.utf8)
            }
        }
    }
    
    // ... (Mdat, Movie, etc unchanged)

    struct SampleTable: Atom {
        let type = "stbl"
        let stsd: SampleDescription
        let stts: TimeToSample
        let stss: SyncSample?
        let stsc: SampleToChunk
        let stsz: SampleSize
        let stco: ChunkOffset
        let sgpd: SampleGroupDescription?
        let sbgp: SampleToGroup?
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = stsd.encode() + stts.encode()
            if let stss = stss { content.append(stss.encode()) }
            content.append(stsc.encode())
            content.append(stsz.encode())
            content.append(stco.encode())
            if let sgpd = sgpd { content.append(sgpd.encode()) }
            if let sbgp = sbgp { content.append(sbgp.encode()) }
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct SyncSample: Atom {
         let type = "stss"
         let version: UInt8 = 0
         let flags: [UInt8] = [0,0,0]
         let entries: [UInt32]
         
         func encode() -> Data {
             var result = Data()
             let typeData = Data(type.utf8)
             var content = Data()
             content.append(version)
             content.append(contentsOf: flags)
             content.append(UInt32(entries.count).data)
             // Optimization: If entries is huge, appending directly might be slow?
             // But for Watch app test file it's fine.
             for entry in entries {
                 content.append(entry.data)
             }
             
             let count = UInt32(4 + typeData.count + content.count)
             result.append(count.data)
             result.append(typeData)
             result.append(content)
             return result
         }
     }
    
    struct Mdat: Atom {
        let type = "mdat"
        let data: Data
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            let count = UInt32(4 + typeData.count + data.count)
            result.append(count.data)
            result.append(typeData)
            result.append(data)
            return result
        }
    }
    
    struct Movie: Atom {
        let type = "moov"
        let mvhd: MovieHeader
        let trak: Track
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            let content = mvhd.encode() + trak.encode()
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct MovieHeader: Atom {
        let type = "mvhd"
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,0]
        let creationTime: Date
        let modificationTime: Date
        let timescale: UInt32
        let duration: UInt32
        let rate: UInt32 = 0x00010000 // 1.0
        let volume: UInt16 = 0x0100 // 1.0
        let reserved: [UInt8] = Array(repeating: 0, count: 10)
        let matrix: [UInt32] = [0x00010000,0,0,0,0x00010000,0,0,0,0x40000000]
        let preDefined: [UInt32] = Array(repeating: 0, count: 6)
        let nextTrackID: UInt32
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            
            let cTime = UInt32(creationTime.timeIntervalSince(MP4.midnight1904))
            let mTime = UInt32(modificationTime.timeIntervalSince(MP4.midnight1904))
            
            content.append(cTime.data)
            content.append(mTime.data)
            content.append(timescale.data)
            content.append(duration.data)
            content.append(rate.data)
            content.append(volume.data)
            content.append(contentsOf: reserved)
            matrix.forEach { content.append($0.data) }
            preDefined.forEach { content.append($0.data) }
            content.append(nextTrackID.data)
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct Track: Atom {
        let type = "trak"
        let tkhd: TrackHeader
        let edts: EditBox?
        let mdia: Media
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = tkhd.encode()
            if let edts = edts {
                content.append(edts.encode())
            }
            content.append(mdia.encode())
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct EditBox: Atom {
        let type = "edts"
        let elst: EditList
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            let content = elst.encode()
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct EditList: Atom {
        let type = "elst"
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,0]
        struct IPv4 { } // Just a placeholder naming?
        struct Entry {
            let segmentDuration: UInt32
            let mediaTime: Int32 // -1 for empty
            let mediaRateInteger: Int16
            let mediaRateFraction: Int16
        }
        let entries: [Entry]
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            content.append(UInt32(entries.count).data)
            for entry in entries {
                content.append(entry.segmentDuration.data)
                content.append(entry.mediaTime.data)
                content.append(entry.mediaRateInteger.data)
                content.append(entry.mediaRateFraction.data)
            }
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct TrackHeader: Atom {
        let type = "tkhd"
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,3] // Enabled, In Movie
        let creationTime: Date
        let modificationTime: Date
        let trackID: UInt32
        let duration: UInt32
        let layer: UInt16 = 0
        let alternateGroup: UInt16 = 0
        let volume: UInt16 = 0x0100
        let matrix: [UInt32] = [0x00010000,0,0,0,0x00010000,0,0,0,0x40000000]
        let width: UInt32 = 0
        let height: UInt32 = 0
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            
            let cTime = UInt32(creationTime.timeIntervalSince(MP4.midnight1904))
            let mTime = UInt32(modificationTime.timeIntervalSince(MP4.midnight1904))
            
            content.append(cTime.data)
            content.append(mTime.data)
            content.append(trackID.data)
            content.append(UInt32(0).data) // Reserved
            content.append(duration.data)
            content.append(UInt32(0).data) // Reserved 8 bytes
            content.append(UInt32(0).data)
            content.append(layer.data)
            content.append(alternateGroup.data)
            content.append(volume.data)
            content.append(UInt16(0).data) // Reserved
            matrix.forEach { content.append($0.data) }
            content.append(width.data)
            content.append(height.data)
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct Media: Atom {
        let type = "mdia"
        let mdhd: MediaHeader
        let hdlr: HandlerReference
        let minf: MediaInformation
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            let content = mdhd.encode() + hdlr.encode() + minf.encode()
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct MediaHeader: Atom {
        let type = "mdhd"
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,0]
        let creationTime: Date
        let modificationTime: Date
        let timescale: UInt32
        let duration: UInt32
        let language: UInt16 = 0x55C4 // 'und'
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            
            let cTime = UInt32(creationTime.timeIntervalSince(MP4.midnight1904))
            let mTime = UInt32(modificationTime.timeIntervalSince(MP4.midnight1904))
            
            content.append(cTime.data)
            content.append(mTime.data)
            content.append(timescale.data)
            content.append(duration.data)
            content.append(language.data)
            content.append(UInt16(0).data) // Predefined
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct HandlerReference: Atom {
        let type = "hdlr"
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,0]
        let handlerType: String
        let name: String
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            content.append(UInt32(0).data) // Predefined
            content.append(Data(handlerType.utf8))
            content.append(UInt32(0).data) // Reserved 12 bytes
            content.append(UInt32(0).data)
            content.append(UInt32(0).data)
            content.append(Data(name.utf8))
            content.append(UInt8(0)) // null terminator? No, name is usually Pascal string or C string? ISO says utf8 string ending with 0.
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct MediaInformation: Atom {
        let type = "minf"
        let smhd: SoundMediaHeader
        let dinf: DataInformation
        let stbl: SampleTable
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            let content = smhd.encode() + dinf.encode() + stbl.encode()
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct SoundMediaHeader: Atom {
        let type = "smhd"
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,0]
        let balance: UInt16 = 0
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            content.append(balance.data)
            content.append(UInt16(0).data) // Reserved
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct DataInformation: Atom {
        let type = "dinf"
        let dref: DataReference
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            let content = dref.encode()
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct DataReference: Atom {
        let type = "dref"
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,0]
        let url: DataReferenceUrl
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            content.append(UInt32(1).data) // Entry count
            content.append(url.encode())
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct DataReferenceUrl: Atom {
        let type = "url "
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,1] // Self contained
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            // Empty location
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    
    struct SampleGroupDescription: Atom {
        let type = "sgpd"
        let version: UInt8 = 1 // Version 1 is typical for 'roll'
        let flags: [UInt8] = [0,0,0]
        let groupingType = "roll"
        let defaultLength: UInt32 = 2 // 2 bytes for roll_distance
        let entryCount: UInt32 = 1
        let rollDistance: Int16 = -1 // -1 means typical pre-roll? Wait. Roll distance is usually negative of samples?
        // Actually ISO 14496-12: 'roll' grouping entry.
        // int(16) roll_distance.
        // "positive integer... indicating constant number of samples to roll back"
        // Wait, some specs say negative.
        // Inspecting workingexample.m4a:
        // sgpd ... roll ... 02 (length?) ... 01 (count) ...
        // FF FC (Big Endian) -> -4? Or 65532?
        // Opus pre-roll is samples. 3840 (0xF00).
        // Let's implement generic structure.
        
        let entries: [Int16]
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            content.append(Data(groupingType.utf8))
            if version == 1 {
                content.append(defaultLength.data)
            }
            content.append(UInt32(entries.count).data)
            for entry in entries {
                content.append(entry.data)
            }
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct SampleToGroup: Atom {
        let type = "sbgp"
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,0]
        let groupingType = "roll"
        let entries: [(sampleCount: UInt32, groupDescriptionIndex: UInt32)]
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            content.append(Data(groupingType.utf8))
            content.append(UInt32(entries.count).data)
            for entry in entries {
                content.append(entry.sampleCount.data)
                content.append(entry.groupDescriptionIndex.data)
            }
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct SampleDescription: Atom {
        let type = "stsd"
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,0]
        let entry: OpusSampleEntry
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            content.append(UInt32(1).data) // Count
            content.append(entry.encode())
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct OpusSampleEntry: Atom {
        let type = "Opus"
        let dataReferenceIndex: UInt16 = 1
        let channelCount: UInt16
        let sampleSize: UInt16 = 16
        let sampleRate: UInt32 = 48000 << 16
        let dOps: OpusSpecificBox
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            // Reserved 6 bytes
            content.append(Data(repeating: 0, count: 6))
            content.append(dataReferenceIndex.data)
            // Reserved 8 bytes
            content.append(Data(repeating: 0, count: 8))
            content.append(channelCount.data)
            content.append(sampleSize.data)
            content.append(UInt32(0).data) // Reserved
            content.append(sampleRate.data)
            
            content.append(dOps.encode())
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct OpusSpecificBox: Atom {
        let type = "dOps"
        let version: UInt8 = 0
        let outputChannelCount: UInt8
        let preSkip: UInt16
        let inputSampleRate: UInt32
        let outputGain: Int16
        let channelMappingFamily: UInt8
        
        init(outputChannelCount: UInt8, preSkip: UInt16, inputSampleRate: UInt32, outputGain: Int16, channelMappingFamily: UInt8) {
            self.outputChannelCount = outputChannelCount
            self.preSkip = preSkip
            self.inputSampleRate = inputSampleRate
            self.outputGain = outputGain
            self.channelMappingFamily = channelMappingFamily
        }
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(outputChannelCount)
            content.append(preSkip.data)
            content.append(inputSampleRate.data)
            content.append(outputGain.data)
            content.append(channelMappingFamily)
            if channelMappingFamily != 0 {
                // Implement if needed
            }
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct TimeToSample: Atom {
        let type = "stts"
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,0]
        let entries: [(count: UInt32, duration: UInt32)]
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            content.append(UInt32(entries.count).data)
            for entry in entries {
                content.append(entry.count.data)
                content.append(entry.duration.data)
            }
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct SampleToChunk: Atom {
        let type = "stsc"
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,0]
        struct Entry {
            let firstChunk: UInt32
            let samplesPerChunk: UInt32
            let sampleDescriptionID: UInt32
        }
        let entries: [Entry]
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            content.append(UInt32(entries.count).data)
            for entry in entries {
                content.append(entry.firstChunk.data)
                content.append(entry.samplesPerChunk.data)
                content.append(entry.sampleDescriptionID.data)
            }
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct SampleSize: Atom {
        let type = "stsz"
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,0]
        let sampleSize: UInt32 = 0 // 0 means variable size
        let sizes: [UInt32]
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            content.append(sampleSize.data)
            content.append(UInt32(sizes.count).data)
            for size in sizes {
                content.append(size.data)
            }
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
    
    struct ChunkOffset: Atom {
        let type = "stco"
        let version: UInt8 = 0
        let flags: [UInt8] = [0,0,0]
        let offsets: [UInt32]
        
        func encode() -> Data {
            var result = Data()
            let typeData = Data(type.utf8)
            var content = Data()
            content.append(version)
            content.append(contentsOf: flags)
            content.append(UInt32(offsets.count).data)
            for offset in offsets {
                content.append(offset.data)
            }
            
            let count = UInt32(4 + typeData.count + content.count)
            result.append(count.data)
            result.append(typeData)
            result.append(content)
            return result
        }
    }
}