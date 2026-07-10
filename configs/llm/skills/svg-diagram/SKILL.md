---
name: svg-diagram
description: >
  Create or edit SVG diagrams that must remain editable in diagrams.net/draw.io
  or the drawio-obsidian plugin, instead of becoming plain static SVG images.
metadata:
  short-description: 可编辑 SVG 图
---

# `svg-diagram` — 可编辑 SVG diagram

## 触发时机

- 用户要求创建或修改 `.svg` diagram，并提到 Obsidian、drawio、diagrams.net、draw.io、`drawio-obsidian`、diagram 编辑，或上下文显示目标 SVG 需要后续可编辑。
- 用户反馈 SVG “不能编辑”“只能预览”“diagram 打不开”时，用本 skill 诊断和修复格式。

## 目标

生成或修改后的 SVG 必须同时满足两件事：

- 作为普通 SVG 可以预览。
- 作为 diagrams.net/draw.io 文件可以被重新打开并编辑其中的图形节点。

## 执行步骤

1. 先检查目标文件是否已经是 diagrams.net 导出的 SVG：读取根 `<svg>` 的 `content` 属性，确认里面是否是 `mxfile` 或 `mxGraphModel`。
2. 修改已有 diagram 时，优先编辑嵌入的 `content` graph model，并让外层可见 SVG 与 graph model 表达同一内容；不要只改外层 SVG。
3. 新建可编辑 SVG 时，在根 `<svg>` 上写入 diagrams.net 可识别的 `content`，优先使用完整结构：

```xml
<mxfile>
  <diagram>
    <mxGraphModel>
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
        ...
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

4. 外层 SVG 可以手写用于预览，但不能替代 `content` 里的可编辑 graph model。
5. 如果本机有 diagrams.net/drawio 导出器，优先从 `.drawio` / `mxfile` 源导出 SVG，避免手写格式偏差；没有导出器时，手写 `content` 但必须验证。

## 验证

- 用 XML 工具验证外层 SVG 合法，例如 `xmllint --noout <file.svg>`。
- 解出根 `<svg>` 的 `content` 属性，确认能解析成 XML，根节点是 `mxfile` 或 `mxGraphModel`，并且包含预期的 `mxCell` 节点。
- 对 `drawio-obsidian` 场景，提醒用户应通过右键 `Edit diagram` 进入编辑视图；直接点开 `.svg` 通常是预览视图。

## 约束

- 不要把可编辑 diagram 覆盖成只有 `<path>` / `<rect>` / `<circle>` 的普通 SVG。
- 不要删除已有的 diagrams.net 元数据，如根 `<svg content="...">` 中的 graph XML。
- 不要用静默 fallback 糊过格式问题；如果 `content` 缺失或解析失败，要明确说明文件已不是可编辑 diagram，或直接修复为可编辑结构。
