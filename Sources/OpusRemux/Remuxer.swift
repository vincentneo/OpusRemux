//
//  Remuxer.swift
//
//  Contains AI generated code.
//

import Foundation
import COgg

public class Remuxer {
    
    public enum RemuxError: Error {
        case fileOpenFailed
        case oggSyncInitFailed
        case oggStreamInitFailed
        case invalidContinuedPacket
        case opusHeadMissing
    }
    
    private struct OpusHead {
        let version: UInt8
        let channelCount: UInt8
        let preSkip: UInt16
        let inputSampleRate: UInt32
        let outputGain: Int16
        let mappingFamily: UInt8
    }
    
    public static func remux(source: URL, destination: URL) throws {
        let reader = try FileHandle(forReadingFrom: source)
        // Clean up destination if exists
        try? FileManager.default.removeItem(at: destination)
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let writer = try FileHandle(forWritingTo: destination)
        
        // 1. Ogg State
        var sync = ogg_sync_state()
        ogg_sync_init(&sync)
        defer { ogg_sync_clear(&sync) }
        
        var stream = ogg_stream_state()
        var streamInitialized = false
        defer { if streamInitialized { ogg_stream_clear(&stream) } }
        
        // 2. Data collection
        var opusHead: OpusHead?
        var samplesData = Data()
        var packetSizes: [UInt32] = []
        var packetDurations: [UInt32] = [] // In 48kHz
        
        // 3. Read Loop
        let bufferSize = 8192
        var headersRead = false
        
        while true {
            guard let chunk = try reader.read(upToCount: bufferSize), !chunk.isEmpty else {
                break
            }
            
            let buffer = ogg_sync_buffer(&sync, chunk.count)!
            chunk.withUnsafeBytes { pointer in
                guard let ba = pointer.baseAddress else { return }
                memcpy(buffer, ba, chunk.count)
            }
            ogg_sync_wrote(&sync, chunk.count)
            
            var page = ogg_page()
            while ogg_sync_pageout(&sync, &page) > 0 {
                if !streamInitialized {
                    let serial = ogg_page_serialno(&page)
                    ogg_stream_init(&stream, serial)
                    streamInitialized = true
                }
                
                ogg_stream_pagein(&stream, &page)
                
                var packet = ogg_packet()
                while ogg_stream_packetout(&stream, &packet) > 0 {
                    // Process Packet
                    let packetData = Data(bytes: packet.packet, count: Int(packet.bytes))
                    
                    if !headersRead {
                        // Check for OpusHead
                        if packetData.starts(with: [0x4f, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64]) { // OpusHead
                             // Parse OpusHead
                             if packetData.count >= 19 {
                                 let version = packetData[8]
                                 let channels = packetData[9]
                                 let preSkip = packetData[10..<12].withUnsafeBytes { $0.load(as: UInt16.self) } // LE in Ogg
                                 let rate = packetData[12..<16].withUnsafeBytes { $0.load(as: UInt32.self) } // LE
                                 let gain = packetData[16..<18].withUnsafeBytes { $0.load(as: Int16.self) } // LE
                                 let family = packetData[18]
                                 
                                 opusHead = OpusHead(version: version, channelCount: channels, preSkip: preSkip, inputSampleRate: rate, outputGain: gain, mappingFamily: family)
                             }
                        } else if packetData.starts(with: [0x4f, 0x70, 0x75, 0x73, 0x54, 0x61, 0x67, 0x73]) { // OpusTags
                            headersRead = true
                        }
                    } else {
                        // Audio Data
                        samplesData.append(packetData)
                        packetSizes.append(UInt32(packetData.count))
                        let duration = parseOpusDuration(packet: packetData)
                        packetDurations.append(UInt32(duration))
                    }
                }
            }
        }
        
        guard let head = opusHead else {
            throw RemuxError.opusHeadMissing
        }
        
        // 4. Construct MP4 Atoms (Fast Start: ftyp -> moov -> mdat)
        
        let fileDuration = packetDurations.reduce(0, +)
        let creationDate = Date()
        // Per Opus ISOBMFF spec 4.4: movie timescale should match media timescale (48000) to avoid rounding
        let movieTimescale: UInt32 = 48000
        let movieDuration = fileDuration
        
        let ftyp = MP4.Ftyp(brand: .baseMedia, version: 1)
        let ftypData = ftyp.encode()
        
        // --- Helper to build Moov with given offsets ---
        func buildMoov(chunkOffsets: [UInt32]) -> MP4.Movie {
             let opusSpecific = MP4.OpusSpecificBox(
                outputChannelCount: head.channelCount,
                preSkip: head.preSkip,
                inputSampleRate: head.inputSampleRate,
                outputGain: head.outputGain,
                channelMappingFamily: head.mappingFamily
            )
            
            let opusEntry = MP4.OpusSampleEntry(
                channelCount: UInt16(head.channelCount),
                dOps: opusSpecific
            )
            
            let stsd = MP4.SampleDescription(entry: opusEntry)
            
            // stts
            var sttsEntries: [(UInt32, UInt32)] = []
            if !packetDurations.isEmpty {
                var currentDur = packetDurations[0]
                var count: UInt32 = 1
                for i in 1..<packetDurations.count {
                    if packetDurations[i] == currentDur {
                        count += 1
                    } else {
                        sttsEntries.append((count, currentDur))
                        currentDur = packetDurations[i]
                        count = 1
                    }
                }
                sttsEntries.append((count, currentDur))
            }
            let stts = MP4.TimeToSample(entries: sttsEntries.map { (count: $0.0, duration: $0.1) })
            
            let stsz = MP4.SampleSize(sizes: packetSizes)
            let stco = MP4.ChunkOffset(offsets: chunkOffsets)
            
            // Use single chunk for all samples
            // This simplifies seeking since all samples are in one contiguous block
            let stscEntries: [MP4.SampleToChunk.Entry] = [
                .init(firstChunk: 1, samplesPerChunk: UInt32(packetSizes.count), sampleDescriptionID: 1)
            ]
            let stsc = MP4.SampleToChunk(entries: stscEntries)
            
            // Opus pre-roll: Per spec 4.3.6.2, 80ms pre-roll is required after random access
            // roll_distance = -(number of samples needed for 80ms)
            // Calculate based on first packet duration (in 48kHz samples)
            let firstPacketDuration = packetDurations.first ?? 960 // Default 20ms
            let preRollSamples: UInt32 = 80 * 48 // 80ms * 48 samples/ms = 3840 samples
            let preRollPackets = max(1, (preRollSamples + firstPacketDuration - 1) / firstPacketDuration)
            let rollDistance = -Int16(preRollPackets)
            let sgpd = MP4.SampleGroupDescription(entries: [rollDistance])
            
            let sbgpEntries: [(sampleCount: UInt32, groupDescriptionIndex: UInt32)]
            let sampleCount = UInt32(packetSizes.count)
            if sampleCount > preRollPackets {
                // First preRollPackets samples don't need pre-roll (they ARE the pre-roll)
                // Remaining samples need pre-roll
                sbgpEntries = [
                    (sampleCount: preRollPackets, groupDescriptionIndex: 0),
                    (sampleCount: sampleCount - preRollPackets, groupDescriptionIndex: 1)
                ]
            } else {
                // Very short file - no roll needed
                sbgpEntries = [(sampleCount: sampleCount, groupDescriptionIndex: 0)]
            }
            let sbgp = MP4.SampleToGroup(entries: sbgpEntries)
            
            let stbl = MP4.SampleTable(
                stsd: stsd,
                stts: stts,
                stss: nil,
                stsc: stsc,
                stsz: stsz,
                stco: stco,
                sgpd: sgpd,
                sbgp: sbgp
            )
            
            let minf = MP4.MediaInformation(
                smhd: MP4.SoundMediaHeader(),
                dinf: MP4.DataInformation(dref: MP4.DataReference(url: MP4.DataReferenceUrl())),
                stbl: stbl
            )
            
            let mdhd = MP4.MediaHeader(
                creationTime: creationDate,
                modificationTime: creationDate,
                timescale: 48000,
                duration: fileDuration
            )
            
            let hdlr = MP4.HandlerReference(handlerType: "soun", name: "SoundHandler")
            let mdia = MP4.Media(mdhd: mdhd, hdlr: hdlr, minf: minf)
            
            // Edts - Use edit list for proper pre-skip handling
            // Per spec 4.4: segment_duration = valid samples, media_time = priming samples
            let preSkipSamples = UInt32(head.preSkip)
            let playableDuration = fileDuration > preSkipSamples ? fileDuration - preSkipSamples : 0
            let preSkipMediaTime = Int32(head.preSkip)
            let trackDuration = playableDuration // Same timescale now
            let elstEntry = MP4.EditList.Entry(
                segmentDuration: trackDuration,
                mediaTime: preSkipMediaTime,
                mediaRateInteger: 1,
                mediaRateFraction: 0
            )
            let edts = MP4.EditBox(elst: MP4.EditList(entries: [elstEntry]))
            
            let tkhd = MP4.TrackHeader(
                creationTime: creationDate,
                modificationTime: creationDate,
                trackID: 1,
                duration: trackDuration
            )
            
            let trak = MP4.Track(tkhd: tkhd, edts: edts, mdia: mdia)
            let mvhd = MP4.MovieHeader(
                creationTime: creationDate,
                modificationTime: creationDate,
                timescale: movieTimescale,
                duration: movieDuration,
                nextTrackID: 2
            )
            
            return MP4.Movie(mvhd: mvhd, trak: trak)
        }
        
        // --- Calculate Initial Offsets & Measure Moov ---
        
        // Use single chunk at offset 0 (will be shifted later)
        // All samples are in one contiguous chunk starting at the mdat body
        let relativeChunkOffsets: [UInt32] = [0]
        
        // 1. Build temporary moov with dummy offsets to measure size
        let dummyMoov = buildMoov(chunkOffsets: relativeChunkOffsets) // offsets are 0-based, size of stco is consistent
        let dummyMoovData = dummyMoov.encode()
        let moovSize = UInt32(dummyMoovData.count)
        
        // 2. Calculate shift
        // Layout: [ftyp] [moov] [mdat header(8)] [mdat body]
        let mdatHeaderSize: UInt32 = 8
        let offsetShift = UInt32(ftypData.count) + moovSize + mdatHeaderSize
        
        // 3. Shift offsets
        let finalChunkOffsets = relativeChunkOffsets.map { $0 + offsetShift }
        
        // 4. Build final Moov
        let finalMoov = buildMoov(chunkOffsets: finalChunkOffsets)
        
        // 5. Construct Mdat
        let mdat = MP4.Mdat(data: samplesData)
        
        // 6. Write
        writer.write(ftypData)
        writer.write(finalMoov.encode())
        writer.write(mdat.encode())
        
        try writer.close()
    }
    
    // Helper to parse Opus duration from TOC
    private static func parseOpusDuration(packet: Data) -> Int {
        guard !packet.isEmpty else { return 960 }
        let toc = packet[0]
        let config = (toc >> 3) & 0x1F
        let countCode = toc & 0x03
        
        // RFC 6716 Table 2
        let frameSizes: [Int] = [
            480, 960, 1920, 2880, // 0-3
            480, 960, 1920, 2880, // 4-7
            480, 960, 1920, 2880, // 8-11
            480, 960,         // 12-13
            480, 960,         // 14-15
            120, 240, 480, 960, // 16-19
            120, 240, 480, 960, // 20-23
            120, 240, 480, 960, // 24-27
            120, 240, 480, 960  // 28-31
        ]
        
        let frameSize = (Int(config) < frameSizes.count) ? frameSizes[Int(config)] : 960
        
        // Frame count
        var frames = 1
        if countCode == 0 { frames = 1 }
        else if countCode == 1 { frames = 2 } // 2 equal sizes
        else if countCode == 2 { frames = 2 } // 2 different sizes
        else if countCode == 3 {
            // arbitrary number of frames
            if packet.count > 1 {
                let frameCountByte = packet[1]
                frames = Int(frameCountByte & 0x3F)
            }
        }
        
        return frameSize * frames
    }
}
