import Foundation

struct Annotation: Codable, Hashable, Identifiable {
    let id: UUID
    let tool: AnnotationTool
    let color: AnnotationColor
    let bounds: NormalizedRect?
    let calloutSource: NormalizedRect?
    let inkDataBase64: String?

    enum CodingKeys: String, CodingKey {
        case id, tool, color, bounds
        case calloutSource = "callout_source"
        case inkDataBase64 = "ink_data_base64"
    }

    init(
        id: UUID = UUID(),
        tool: AnnotationTool,
        color: AnnotationColor,
        bounds: NormalizedRect? = nil,
        calloutSource: NormalizedRect? = nil,
        inkDataBase64: String? = nil
    ) {
        self.id = id
        self.tool = tool
        self.color = color
        self.bounds = bounds
        self.calloutSource = calloutSource
        self.inkDataBase64 = inkDataBase64
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.tool = try c.decode(AnnotationTool.self, forKey: .tool)
        let hex = try c.decode(String.self, forKey: .color)
        guard let parsed = AnnotationColor(hex: hex) else {
            throw DecodingError.dataCorruptedError(forKey: .color, in: c, debugDescription: "Unknown color hex \(hex)")
        }
        self.color = parsed
        self.bounds = try c.decodeIfPresent(NormalizedRect.self, forKey: .bounds)
        self.calloutSource = try c.decodeIfPresent(NormalizedRect.self, forKey: .calloutSource)
        self.inkDataBase64 = try c.decodeIfPresent(String.self, forKey: .inkDataBase64)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(tool, forKey: .tool)
        try c.encode(color.hex, forKey: .color)
        try c.encodeIfPresent(bounds, forKey: .bounds)
        try c.encodeIfPresent(calloutSource, forKey: .calloutSource)
        try c.encodeIfPresent(inkDataBase64, forKey: .inkDataBase64)
    }
}
