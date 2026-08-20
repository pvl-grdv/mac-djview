import Foundation

/// JB2 decoder for Sjbz chunks (mask/text layer).
/// Faithfully ported from DjVu.js JB2Image.js
final class JB2Decoder {

    static func decode(data: Data, sharedDict: JB2Dict?) throws -> JB2Image {
        let stream = ByteStream(data: data)
        let zp = ZPCodec(stream: stream)

        var directBitmapCtx = [UInt8](repeating: 0, count: 1024)
        var refinementBitmapCtx = [UInt8](repeating: 0, count: 2048)
        var offsetTypeCtx: [UInt8] = [0]

        let recordTypeCtx = NumContext()
        let imageSizeCtx = NumContext()
        let inheritDictSizeCtx = NumContext()
        let symbolWidthCtx = NumContext()
        let symbolHeightCtx = NumContext()
        let symbolIndexCtx = NumContext()
        let symbolWidthDiffCtx = NumContext()
        let symbolHeightDiffCtx = NumContext()
        let hoffCtx = NumContext()
        let voffCtx = NumContext()
        let shoffCtx = NumContext()
        let svoffCtx = NumContext()
        let commentLengthCtx = NumContext()
        let commentOctetCtx = NumContext()
        let horizontalAbsLocationCtx = NumContext()
        let verticalAbsLocationCtx = NumContext()

        var decodedBitmapPixels = 0
        var decodedCommentBytes = 0
        var cumulativeBlitPixels = 0
        var recordCount = 0

        func recordDecodedBitmap(_ bitmap: JB2Bitmap) throws {
            let pixels = try DecodeLimits.checkedMultiply(
                bitmap.width, bitmap.height, context: "JB2 decoded bitmap pixels"
            )
            decodedBitmapPixels = try DecodeLimits.checkedAdd(
                decodedBitmapPixels, pixels, context: "JB2 cumulative decoded pixels"
            )
            guard decodedBitmapPixels <= DecodeLimits.maxJB2DecodedBitmapPixels else {
                throw DjVuError.resourceLimitExceeded("JB2 decodes too many bitmap pixels")
            }
        }

        func appendLibrary(_ bitmap: JB2Bitmap, to library: inout [JB2Bitmap]) throws {
            guard library.count < DecodeLimits.maxJB2Symbols else {
                throw DjVuError.resourceLimitExceeded("JB2 contains too many symbols")
            }
            library.append(bitmap)
        }

        func addBlit(_ bitmap: JB2Bitmap, x: Int, y: Int, to image: JB2Image) throws {
            guard image.blits.count < DecodeLimits.maxJB2Blits else {
                throw DjVuError.resourceLimitExceeded("JB2 contains too many blits")
            }
            let pixels = try DecodeLimits.checkedMultiply(
                bitmap.width, bitmap.height, context: "JB2 blit pixel work"
            )
            cumulativeBlitPixels = try DecodeLimits.checkedAdd(
                cumulativeBlitPixels, pixels, context: "JB2 cumulative blit pixel work"
            )
            guard cumulativeBlitPixels <= DecodeLimits.maxJB2BlitPixels else {
                throw DjVuError.resourceLimitExceeded("JB2 blits require too much pixel work")
            }
            image.addBlit(JB2Blit(bitmap: bitmap, x: x, y: y))
        }

        var initialDictLength = 0
        var type = zp.decodeNum(ctx: recordTypeCtx, low: 0, high: 11)
        if type == 9 {
            initialDictLength = zp.decodeNum(ctx: inheritDictSizeCtx, low: 0, high: 262142)
            guard initialDictLength <= DecodeLimits.maxJB2Symbols else {
                throw DjVuError.resourceLimitExceeded("JB2 inherited dictionary is too large")
            }
            type = zp.decodeNum(ctx: recordTypeCtx, low: 0, high: 11)
        }

        let imgWidth = zp.decodeNum(ctx: imageSizeCtx, low: 0, high: 262142)
        let imgHeight = zp.decodeNum(ctx: imageSizeCtx, low: 0, high: 262142)
        let w = imgWidth > 0 ? imgWidth : 200
        let h = imgHeight > 0 ? imgHeight : 200
        try DecodeLimits.validatePage(width: w, height: h, context: "JB2 image")

        var flagCtx: [UInt8] = [0]
        let flag = zp.decode(ctx: &flagCtx, n: 0)
        if flag != 0 {
            throw DjVuError.decodingFailed("JB2: bad flag")
        }

        let image = JB2Image(width: w, height: h)

        var library: [JB2Bitmap] = []
        if initialDictLength > 0, let sharedDict {
            library = Array(sharedDict.symbols.prefix(initialDictLength))
        }
        guard library.count <= DecodeLimits.maxJB2Symbols else {
            throw DjVuError.resourceLimitExceeded("JB2 inherited symbol library is too large")
        }

        var lastRight = 0
        var firstLeft = -1
        var firstBottom = h - 1
        let baseline = Baseline()
        baseline.fill(0)

        type = zp.decodeNum(ctx: recordTypeCtx, low: 0, high: 11)

        while type != 11 {
            recordCount += 1
            guard recordCount <= DecodeLimits.maxJB2Records else {
                throw DjVuError.resourceLimitExceeded("JB2 contains too many records")
            }

            switch type {
            case 1:
                let bw = zp.decodeNum(ctx: symbolWidthCtx, low: 0, high: 262142)
                let bh = zp.decodeNum(ctx: symbolHeightCtx, low: 0, high: 262142)
                let bm = try decodeBitmap(zp: zp, width: bw, height: bh, ctx: &directBitmapCtx)
                try recordDecodedBitmap(bm)
                let (x, y) = decodeSymbolCoords(
                    zp: zp, bmWidth: bm.width, bmHeight: bm.height,
                    offsetTypeCtx: &offsetTypeCtx,
                    hoffCtx: hoffCtx, voffCtx: voffCtx,
                    shoffCtx: shoffCtx, svoffCtx: svoffCtx,
                    baseline: baseline,
                    lastRight: &lastRight,
                    firstLeft: &firstLeft, firstBottom: &firstBottom,
                    imgHeight: h)
                try addBlit(bm, x: x, y: y, to: image)
                try appendLibrary(bm.removeEmptyEdges(), to: &library)

            case 2:
                let bw = zp.decodeNum(ctx: symbolWidthCtx, low: 0, high: 262142)
                let bh = zp.decodeNum(ctx: symbolHeightCtx, low: 0, high: 262142)
                let bm = try decodeBitmap(zp: zp, width: bw, height: bh, ctx: &directBitmapCtx)
                try recordDecodedBitmap(bm)
                try appendLibrary(bm.removeEmptyEdges(), to: &library)

            case 3:
                let bw = zp.decodeNum(ctx: symbolWidthCtx, low: 0, high: 262142)
                let bh = zp.decodeNum(ctx: symbolHeightCtx, low: 0, high: 262142)
                let bm = try decodeBitmap(zp: zp, width: bw, height: bh, ctx: &directBitmapCtx)
                try recordDecodedBitmap(bm)
                let (x, y) = decodeSymbolCoords(
                    zp: zp, bmWidth: bm.width, bmHeight: bm.height,
                    offsetTypeCtx: &offsetTypeCtx,
                    hoffCtx: hoffCtx, voffCtx: voffCtx,
                    shoffCtx: shoffCtx, svoffCtx: svoffCtx,
                    baseline: baseline,
                    lastRight: &lastRight,
                    firstLeft: &firstLeft, firstBottom: &firstBottom,
                    imgHeight: h)
                try addBlit(bm, x: x, y: y, to: image)

            case 4, 5, 6:
                let idx = zp.decodeNum(ctx: symbolIndexCtx, low: 0, high: max(0, library.count - 1))
                let wdiff = zp.decodeNum(ctx: symbolWidthDiffCtx, low: -262143, high: 262142)
                let hdiff = zp.decodeNum(ctx: symbolHeightDiffCtx, low: -262143, high: 262142)
                let model = idx < library.count ? library[idx] : JB2Bitmap(width: 1, height: 1)
                let refinedWidth = try DecodeLimits.checkedAdd(model.width, wdiff, context: "JB2 refinement width")
                let refinedHeight = try DecodeLimits.checkedAdd(model.height, hdiff, context: "JB2 refinement height")
                let bm = try decodeRefinementBitmap(
                    zp: zp, width: refinedWidth, height: refinedHeight,
                    model: model, ctx: &refinementBitmapCtx)
                try recordDecodedBitmap(bm)

                if type == 4 || type == 6 {
                    let (x, y) = decodeSymbolCoords(
                        zp: zp, bmWidth: bm.width, bmHeight: bm.height,
                        offsetTypeCtx: &offsetTypeCtx,
                        hoffCtx: hoffCtx, voffCtx: voffCtx,
                        shoffCtx: shoffCtx, svoffCtx: svoffCtx,
                        baseline: baseline,
                        lastRight: &lastRight,
                        firstLeft: &firstLeft, firstBottom: &firstBottom,
                        imgHeight: h)
                    try addBlit(bm, x: x, y: y, to: image)
                }
                if type == 4 || type == 5 {
                    try appendLibrary(bm.removeEmptyEdges(), to: &library)
                }

            case 7:
                let idx = zp.decodeNum(ctx: symbolIndexCtx, low: 0, high: max(0, library.count - 1))
                let bm = idx < library.count ? library[idx] : JB2Bitmap(width: 1, height: 1)
                let (x, y) = decodeSymbolCoords(
                    zp: zp, bmWidth: bm.width, bmHeight: bm.height,
                    offsetTypeCtx: &offsetTypeCtx,
                    hoffCtx: hoffCtx, voffCtx: voffCtx,
                    shoffCtx: shoffCtx, svoffCtx: svoffCtx,
                    baseline: baseline,
                    lastRight: &lastRight,
                    firstLeft: &firstLeft, firstBottom: &firstBottom,
                    imgHeight: h)
                try addBlit(bm, x: x, y: y, to: image)

            case 8:
                let bw = zp.decodeNum(ctx: symbolWidthCtx, low: 0, high: 262142)
                let bh = zp.decodeNum(ctx: symbolHeightCtx, low: 0, high: 262142)
                let bm = try decodeBitmap(zp: zp, width: bw, height: bh, ctx: &directBitmapCtx)
                try recordDecodedBitmap(bm)
                let left = zp.decodeNum(ctx: horizontalAbsLocationCtx, low: 1, high: w)
                let top = zp.decodeNum(ctx: verticalAbsLocationCtx, low: 1, high: h)
                try addBlit(bm, x: left, y: top - bh, to: image)

            case 9:
                resetNumContexts(recordTypeCtx, imageSizeCtx, inheritDictSizeCtx,
                                 symbolWidthCtx, symbolHeightCtx, symbolIndexCtx,
                                 symbolWidthDiffCtx, symbolHeightDiffCtx,
                                 hoffCtx, voffCtx, shoffCtx, svoffCtx,
                                 commentLengthCtx, commentOctetCtx,
                                 horizontalAbsLocationCtx, verticalAbsLocationCtx)

            case 10:
                let length = zp.decodeNum(ctx: commentLengthCtx, low: 0, high: 262142)
                decodedCommentBytes = try DecodeLimits.checkedAdd(
                    decodedCommentBytes, length, context: "JB2 comment bytes"
                )
                guard decodedCommentBytes <= DecodeLimits.maxJB2CommentBytes else {
                    throw DjVuError.resourceLimitExceeded("JB2 comments are too large")
                }
                for _ in 0..<length {
                    _ = zp.decodeNum(ctx: commentOctetCtx, low: 0, high: 255)
                }

            default:
                break
            }

            type = zp.decodeNum(ctx: recordTypeCtx, low: 0, high: 11)
            if type > 11 { break }
        }

        return image
    }

    private static func decodeSymbolCoords(
        zp: ZPCodec,
        bmWidth: Int, bmHeight: Int,
        offsetTypeCtx: inout [UInt8],
        hoffCtx: NumContext, voffCtx: NumContext,
        shoffCtx: NumContext, svoffCtx: NumContext,
        baseline: Baseline,
        lastRight: inout Int,
        firstLeft: inout Int, firstBottom: inout Int,
        imgHeight: Int
    ) -> (Int, Int) {
        let isNewLine = zp.decode(ctx: &offsetTypeCtx, n: 0) != 0
        var x: Int
        var y: Int

        if isNewLine {
            let hoff = zp.decodeNum(ctx: hoffCtx, low: -262143, high: 262142)
            let voff = zp.decodeNum(ctx: voffCtx, low: -262143, high: 262142)
            x = firstLeft + hoff
            y = firstBottom + voff - bmHeight + 1
            firstLeft = x
            firstBottom = y
            baseline.fill(y)
        } else {
            let hoff = zp.decodeNum(ctx: shoffCtx, low: -262143, high: 262142)
            let voff = zp.decodeNum(ctx: svoffCtx, low: -262143, high: 262142)
            x = lastRight + hoff
            y = baseline.getVal() + voff
        }

        baseline.add(y)
        lastRight = x + bmWidth - 1
        return (x, y)
    }
}
