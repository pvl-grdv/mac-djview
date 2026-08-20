import Foundation

/// 1-bit packed bitmap for JB2
final class JB2Bitmap {
    let width: Int
    let height: Int
    var data: [UInt8]

    init(width: Int, height: Int) {
        self.width = max(0, width)
        self.height = max(0, height)
        let length = (self.width * self.height + 7) / 8
        self.data = [UInt8](repeating: 0, count: length)
    }

    static func validated(width: Int, height: Int) throws -> JB2Bitmap {
        _ = try DecodeLimits.validateJB2Bitmap(width: width, height: height)
        return JB2Bitmap(width: width, height: height)
    }

    func hasRow(_ r: Int) -> Bool { r >= 0 && r < height }

    func get(_ row: Int, _ col: Int) -> Int {
        guard row >= 0, row < height, col >= 0, col < width else { return 0 }
        let idx = row * width + col
        return Int((data[idx >> 3] >> (7 - (idx & 7))) & 1)
    }

    func set(_ row: Int, _ col: Int) {
        guard row >= 0, row < height, col >= 0, col < width else { return }
        let idx = row * width + col
        data[idx >> 3] |= (0x80 >> (idx & 7))
    }

    func getBits(_ row: Int, _ col: Int, _ bitCount: Int) -> Int {
        guard row >= 0, row < height else { return 0 }
        var result = 0
        var j = col
        for bit in 0..<bitCount {
            if j >= 0 && j < width {
                result |= get(row, j) << (bitCount - 1 - bit)
            }
            j += 1
        }
        return result
    }

    /// Remove empty rows and columns with one bounding-box scan, then one copy pass.
    func removeEmptyEdges() -> JB2Bitmap {
        guard width > 0, height > 0 else {
            return JB2Bitmap(width: 1, height: 1)
        }

        var minRow = height
        var maxRow = -1
        var minCol = width
        var maxCol = -1

        for row in 0..<height {
            for col in 0..<width where get(row, col) != 0 {
                minRow = min(minRow, row)
                maxRow = max(maxRow, row)
                minCol = min(minCol, col)
                maxCol = max(maxCol, col)
            }
        }

        guard maxRow >= minRow, maxCol >= minCol else {
            return JB2Bitmap(width: 1, height: 1)
        }

        if minRow == 0, maxRow == height - 1, minCol == 0, maxCol == width - 1 {
            return self
        }

        let newWidth = maxCol - minCol + 1
        let newHeight = maxRow - minRow + 1
        let newBitmap = JB2Bitmap(width: newWidth, height: newHeight)

        for row in minRow...maxRow {
            for col in minCol...maxCol where get(row, col) != 0 {
                newBitmap.set(row - minRow, col - minCol)
            }
        }
        return newBitmap
    }
}

struct JB2Blit {
    let bitmap: JB2Bitmap
    let x: Int
    let y: Int
}

final class Baseline {
    private var arr: [Int] = [0, 0, 0]
    private var index: Int = -1

    func add(_ val: Int) {
        index += 1
        if index == 3 { index = 0 }
        arr[index] = val
    }

    func getVal() -> Int {
        if (arr[0] >= arr[1] && arr[0] <= arr[2]) || (arr[0] <= arr[1] && arr[0] >= arr[2]) {
            return arr[0]
        } else if (arr[1] >= arr[0] && arr[1] <= arr[2]) || (arr[1] <= arr[0] && arr[1] >= arr[2]) {
            return arr[1]
        } else {
            return arr[2]
        }
    }

    func fill(_ val: Int) {
        arr[0] = val; arr[1] = val; arr[2] = val
    }
}
