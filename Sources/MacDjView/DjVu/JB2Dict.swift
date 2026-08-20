import Foundation

/// JB2 symbol dictionary - stores decoded bitmaps.
/// Faithfully ported from DjVu.js JB2Dict.js
final class JB2Dict {
    var symbols: [JB2Bitmap] = []

    init() {}

    static func decode(from data: Data) throws -> JB2Dict {
        let stream = ByteStream(data: data)
        let zp = ZPCodec(stream: stream)
        let dict = JB2Dict()

        var directBitmapCtx = [UInt8](repeating: 0, count: 1024)
        var refinementBitmapCtx = [UInt8](repeating: 0, count: 2048)

        let recordTypeCtx = NumContext()
        let imageSizeCtx = NumContext()
        let inheritDictSizeCtx = NumContext()
        let symbolWidthCtx = NumContext()
        let symbolHeightCtx = NumContext()
        let symbolIndexCtx = NumContext()
        let symbolWidthDiffCtx = NumContext()
        let symbolHeightDiffCtx = NumContext()
        let commentLengthCtx = NumContext()
        let commentOctetCtx = NumContext()

        var decodedBitmapPixels = 0
        var decodedCommentBytes = 0
        var recordCount = 0

        func recordDecodedBitmap(_ bitmap: JB2Bitmap) throws {
            let pixels = try DecodeLimits.checkedMultiply(
                bitmap.width, bitmap.height, context: "JB2 dictionary decoded bitmap pixels"
            )
            decodedBitmapPixels = try DecodeLimits.checkedAdd(
                decodedBitmapPixels, pixels, context: "JB2 dictionary decoded pixels"
            )
            guard decodedBitmapPixels <= DecodeLimits.maxJB2DecodedBitmapPixels else {
                throw DjVuError.resourceLimitExceeded("JB2 dictionary decodes too many bitmap pixels")
            }
        }

        func appendSymbol(_ bitmap: JB2Bitmap) throws {
            guard dict.symbols.count < DecodeLimits.maxJB2Symbols else {
                throw DjVuError.resourceLimitExceeded("JB2 dictionary contains too many symbols")
            }
            dict.symbols.append(bitmap)
        }

        var type = zp.decodeNum(ctx: recordTypeCtx, low: 0, high: 11)
        if type == 9 {
            let inheritedCount = zp.decodeNum(ctx: inheritDictSizeCtx, low: 0, high: 262142)
            guard inheritedCount <= DecodeLimits.maxJB2Symbols else {
                throw DjVuError.resourceLimitExceeded("JB2 inherited dictionary is too large")
            }
            type = zp.decodeNum(ctx: recordTypeCtx, low: 0, high: 11)
        }

        _ = zp.decodeNum(ctx: imageSizeCtx, low: 0, high: 262142)
        _ = zp.decodeNum(ctx: imageSizeCtx, low: 0, high: 262142)

        var flagCtx: [UInt8] = [0]
        let flag = zp.decode(ctx: &flagCtx, n: 0)
        if flag != 0 {
            throw DjVuError.decodingFailed("JB2Dict: bad flag")
        }

        type = zp.decodeNum(ctx: recordTypeCtx, low: 0, high: 11)

        while type != 11 {
            recordCount += 1
            guard recordCount <= DecodeLimits.maxJB2Records else {
                throw DjVuError.resourceLimitExceeded("JB2 dictionary contains too many records")
            }

            switch type {
            case 2:
                let w = zp.decodeNum(ctx: symbolWidthCtx, low: 0, high: 262142)
                let h = zp.decodeNum(ctx: symbolHeightCtx, low: 0, high: 262142)
                let bm = try decodeBitmap(zp: zp, width: w, height: h, ctx: &directBitmapCtx)
                try recordDecodedBitmap(bm)
                try appendSymbol(bm)

            case 5:
                let idx = zp.decodeNum(ctx: symbolIndexCtx, low: 0, high: max(0, dict.symbols.count - 1))
                let wdiff = zp.decodeNum(ctx: symbolWidthDiffCtx, low: -262143, high: 262142)
                let hdiff = zp.decodeNum(ctx: symbolHeightDiffCtx, low: -262143, high: 262142)
                let model = idx < dict.symbols.count ? dict.symbols[idx] : JB2Bitmap(width: 1, height: 1)
                let width = try DecodeLimits.checkedAdd(model.width, wdiff, context: "JB2 refinement width")
                let height = try DecodeLimits.checkedAdd(model.height, hdiff, context: "JB2 refinement height")
                let bm = try decodeRefinementBitmap(
                    zp: zp, width: width, height: height,
                    model: model, ctx: &refinementBitmapCtx
                )
                try recordDecodedBitmap(bm)
                try appendSymbol(bm.removeEmptyEdges())

            case 9:
                resetNumContexts(recordTypeCtx, imageSizeCtx, inheritDictSizeCtx,
                                 symbolWidthCtx, symbolHeightCtx, symbolIndexCtx,
                                 symbolWidthDiffCtx, symbolHeightDiffCtx,
                                 commentLengthCtx, commentOctetCtx)

            case 10:
                let length = zp.decodeNum(ctx: commentLengthCtx, low: 0, high: 262142)
                decodedCommentBytes = try DecodeLimits.checkedAdd(
                    decodedCommentBytes, length, context: "JB2 dictionary comment bytes"
                )
                guard decodedCommentBytes <= DecodeLimits.maxJB2CommentBytes else {
                    throw DjVuError.resourceLimitExceeded("JB2 dictionary comments are too large")
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

        return dict
    }
}

func decodeBitmap(zp: ZPCodec, width: Int, height: Int, ctx: inout [UInt8]) throws -> JB2Bitmap {
    let bm = try JB2Bitmap.validated(width: width, height: height)
    guard width > 0, height > 0 else { return bm }

    for i in stride(from: height - 1, through: 0, by: -1) {
        for j in 0..<width {
            var index = 0
            if bm.hasRow(i + 2) {
                index = bm.getBits(i + 2, j - 1, 3) << 7
            }
            if bm.hasRow(i + 1) {
                index |= bm.getBits(i + 1, j - 2, 5) << 2
            }
            index |= bm.getBits(i, j - 2, 2)
            if zp.decode(ctx: &ctx, n: index & 0x3FF) != 0 {
                bm.set(i, j)
            }
        }
    }
    return bm
}

func decodeRefinementBitmap(zp: ZPCodec, width: Int, height: Int,
                            model: JB2Bitmap, ctx: inout [UInt8]) throws -> JB2Bitmap {
    if width <= 0 || height <= 0 {
        return try JB2Bitmap.validated(width: max(width, 0), height: max(height, 0))
    }

    let cbm = try JB2Bitmap.validated(width: width, height: height)

    let crow = (height - 1) >> 1
    let ccol = (width - 1) >> 1
    let mrow = (model.height - 1) >> 1
    let mcol = (model.width - 1) >> 1
    let rowshift = mrow - crow
    let colshift = mcol - ccol

    for i in stride(from: height - 1, through: 0, by: -1) {
        for j in 0..<width {
            var index = 0

            let r1 = i + 1
            if cbm.hasRow(r1) {
                index = cbm.getBits(r1, j - 1, 3) << 8
            }
            index |= cbm.get(i, j - 1) << 7

            var mr = i + rowshift + 1
            let mc = j + colshift
            index |= (model.hasRow(mr) ? model.get(mr, mc) : 0) << 6
            mr -= 1
            if model.hasRow(mr) {
                index |= model.getBits(mr, mc - 1, 3) << 3
            }
            mr -= 1
            if model.hasRow(mr) {
                index |= model.getBits(mr, mc - 1, 3)
            }

            if zp.decode(ctx: &ctx, n: index & 0x7FF) != 0 {
                cbm.set(i, j)
            }
        }
    }
    return cbm
}

func resetNumContexts(_ ctxs: NumContext...) {
    for ctx in ctxs {
        ctx.reset()
    }
}
