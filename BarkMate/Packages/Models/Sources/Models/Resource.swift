//
//  Resource.swift
//  Models
//

import Foundation
import SwiftData

/// 附件资源（图片、文件等）。
///
/// 归属 `step` 或 `memo` 二选一（业务约束，schema 上仍是两个独立可空关系）。
@Model
public final class Resource {
    @Attribute(.unique) public var id: UUID
    public var filename: String
    public var mimeType: String
    /// 相对于 App Group shared container 的路径。
    public var localPath: String
    public var size: Int64
    public var createdAt: Date

    public var step: AgentStep?
    public var memo: Memo?

    public init(
        id: UUID = UUID(),
        filename: String,
        mimeType: String,
        localPath: String,
        size: Int64,
        createdAt: Date = .now,
        step: AgentStep? = nil,
        memo: Memo? = nil
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.localPath = localPath
        self.size = size
        self.createdAt = createdAt
        self.step = step
        self.memo = memo
    }
}
