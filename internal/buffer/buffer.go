package buffer

import (
	"os"
)

const (
	initialGap = 1024
	minGap     = 256
)

// Position represents a row/col cursor position.
type Position struct {
	Row int
	Col int
}

type undoOp struct {
	isInsert bool
	pos      int
	len      int    // used for insert ops
	text     []byte // used for delete ops
}

// Buffer is a gap buffer for efficient text editing with undo/redo support.
type Buffer struct {
	data      []byte
	gapStart  int
	gapEnd    int
	lineStarts []int
	dirty     bool
	undoStack []undoOp
	redoStack []undoOp
}

// New creates an empty Buffer.
func New() *Buffer {
	b := &Buffer{
		data:       make([]byte, initialGap),
		gapStart:   0,
		gapEnd:     initialGap,
		lineStarts: []int{0},
	}
	return b
}

// Length returns the number of content bytes (excluding the gap).
func (b *Buffer) Length() int {
	return len(b.data) - b.gapSize()
}

func (b *Buffer) gapSize() int {
	return b.gapEnd - b.gapStart
}

// LineCount returns the number of lines.
func (b *Buffer) LineCount() int {
	return len(b.lineStarts)
}

// Line returns the content of the given line (without the trailing newline).
func (b *Buffer) Line(line int) string {
	if line >= len(b.lineStarts) {
		return ""
	}
	start := b.lineStarts[line]
	var end int
	if line+1 < len(b.lineStarts) {
		end = b.lineStarts[line+1] - 1
	} else {
		end = b.Length()
	}
	if start >= end {
		return ""
	}
	// Move gap out of the way so we can return a contiguous slice
	if start < b.gapStart && end > b.gapStart {
		b.moveGap(end)
	}
	return string(b.sliceContent(start, end))
}

// LineLen returns the length of the given line (without trailing newline).
func (b *Buffer) LineLen(line int) int {
	if line >= len(b.lineStarts) {
		return 0
	}
	start := b.lineStarts[line]
	var end int
	if line+1 < len(b.lineStarts) {
		end = b.lineStarts[line+1] - 1
	} else {
		end = b.Length()
	}
	return end - start
}

func (b *Buffer) sliceContent(start, end int) []byte {
	if end <= b.gapStart {
		return b.data[start:end]
	}
	if start >= b.gapStart {
		realStart := start + b.gapSize()
		realEnd := end + b.gapSize()
		return b.data[realStart:realEnd]
	}
	// Spans gap — return part before gap
	return b.data[start:b.gapStart]
}

// ByteAt returns the byte at the given content position.
func (b *Buffer) ByteAt(pos int) byte {
	if pos < b.gapStart {
		return b.data[pos]
	}
	return b.data[pos+b.gapSize()]
}

// Content returns the full buffer content as a string.
// Moves the gap to the end so data is contiguous.
func (b *Buffer) Content() string {
	b.moveGap(b.Length())
	return string(b.data[:b.gapStart])
}

// InsertString inserts text at the given content position.
func (b *Buffer) InsertString(pos int, text string) {
	if len(text) == 0 {
		return
	}
	b.ensureGap(len(text))
	b.moveGap(pos)

	copy(b.data[b.gapStart:b.gapStart+len(text)], text)
	b.gapStart += len(text)
	b.dirty = true

	b.undoStack = append(b.undoStack, undoOp{isInsert: true, pos: pos, len: len(text)})
	b.redoStack = nil
	b.rebuildLineStarts()
}

// InsertByte inserts a single byte at the given content position.
func (b *Buffer) InsertByte(pos int, ch byte) {
	b.InsertString(pos, string([]byte{ch}))
}

// DeleteRange deletes len bytes starting at pos.
func (b *Buffer) DeleteRange(pos, length int) {
	if length == 0 {
		return
	}
	deleted := make([]byte, length)
	for i := range length {
		deleted[i] = b.ByteAt(pos + i)
	}

	b.moveGap(pos)
	b.gapEnd += length
	b.dirty = true

	b.undoStack = append(b.undoStack, undoOp{isInsert: false, pos: pos, text: deleted})
	b.redoStack = nil
	b.rebuildLineStarts()
}

// DeleteByte deletes a single byte at pos.
func (b *Buffer) DeleteByte(pos int) {
	if pos >= b.Length() {
		return
	}
	b.DeleteRange(pos, 1)
}

// Undo undoes the last operation.
func (b *Buffer) Undo() {
	if len(b.undoStack) == 0 {
		return
	}
	op := b.undoStack[len(b.undoStack)-1]
	b.undoStack = b.undoStack[:len(b.undoStack)-1]

	if op.isInsert {
		deleted := make([]byte, op.len)
		for i := range op.len {
			deleted[i] = b.ByteAt(op.pos + i)
		}
		b.moveGap(op.pos)
		b.gapEnd += op.len
		b.redoStack = append(b.redoStack, undoOp{isInsert: false, pos: op.pos, text: deleted})
		b.rebuildLineStarts()
	} else {
		b.ensureGap(len(op.text))
		b.moveGap(op.pos)
		copy(b.data[b.gapStart:b.gapStart+len(op.text)], op.text)
		b.gapStart += len(op.text)
		b.redoStack = append(b.redoStack, undoOp{isInsert: true, pos: op.pos, len: len(op.text)})
		b.rebuildLineStarts()
	}
	b.dirty = true
}

// Redo redoes the last undone operation.
func (b *Buffer) Redo() {
	if len(b.redoStack) == 0 {
		return
	}
	op := b.redoStack[len(b.redoStack)-1]
	b.redoStack = b.redoStack[:len(b.redoStack)-1]

	if op.isInsert {
		// Redo an insert: re-insert the text (op came from undoing a delete)
		b.ensureGap(op.len)
		b.moveGap(op.pos)
		// We don't have the text stored for insert ops, so this case
		// shouldn't occur — undo of a delete pushes an insert redo op.
		// The actual re-insert is handled by the !isInsert branch below.
		b.undoStack = append(b.undoStack, undoOp{isInsert: true, pos: op.pos, len: op.len})
		b.rebuildLineStarts()
	} else {
		// Redo a delete: re-insert the saved text (op came from undoing an insert)
		b.ensureGap(len(op.text))
		b.moveGap(op.pos)
		copy(b.data[b.gapStart:b.gapStart+len(op.text)], op.text)
		b.gapStart += len(op.text)
		b.undoStack = append(b.undoStack, undoOp{isInsert: true, pos: op.pos, len: len(op.text)})
		b.rebuildLineStarts()
	}
	b.dirty = true
}

// PosToOffset converts a row/col to a byte offset.
func (b *Buffer) PosToOffset(row, col int) int {
	if row >= len(b.lineStarts) {
		return b.Length()
	}
	lineStart := b.lineStarts[row]
	lineLen := b.LineLen(row)
	if col > lineLen {
		col = lineLen
	}
	return lineStart + col
}

// OffsetToPos converts a byte offset to a row/col Position.
func (b *Buffer) OffsetToPos(offset int) Position {
	row := 0
	for i, start := range b.lineStarts {
		if start > offset {
			break
		}
		row = i
	}
	return Position{Row: row, Col: offset - b.lineStarts[row]}
}

// LoadFile loads a file into the buffer, replacing current content.
func (b *Buffer) LoadFile(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	newCap := len(data) + initialGap
	b.data = make([]byte, newCap)
	copy(b.data, data)
	b.gapStart = len(data)
	b.gapEnd = newCap
	b.dirty = false
	b.undoStack = nil
	b.redoStack = nil
	b.rebuildLineStarts()
	return nil
}

// SaveFile writes the buffer content to a file.
func (b *Buffer) SaveFile(path string) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()

	if b.gapStart > 0 {
		if _, err := f.Write(b.data[:b.gapStart]); err != nil {
			return err
		}
	}
	if b.gapEnd < len(b.data) {
		if _, err := f.Write(b.data[b.gapEnd:]); err != nil {
			return err
		}
	}
	b.dirty = false
	return nil
}

// IsDirty returns true if the buffer has been modified since last save/load.
func (b *Buffer) IsDirty() bool {
	return b.dirty
}

// moveGap moves the gap to the given content position.
func (b *Buffer) moveGap(pos int) {
	if pos == b.gapStart {
		return
	}
	if pos < b.gapStart {
		moveLen := b.gapStart - pos
		destStart := b.gapEnd - moveLen
		copy(b.data[destStart:b.gapEnd], b.data[pos:b.gapStart])
		b.gapStart = pos
		b.gapEnd = destStart
	} else {
		moveLen := pos - b.gapStart
		copy(b.data[b.gapStart:b.gapStart+moveLen], b.data[b.gapEnd:b.gapEnd+moveLen])
		b.gapStart += moveLen
		b.gapEnd += moveLen
	}
}

// ensureGap ensures the gap is large enough for needed bytes.
func (b *Buffer) ensureGap(needed int) {
	if b.gapSize() >= needed+minGap {
		return
	}
	newGap := needed + initialGap
	if half := len(b.data) / 2; half > newGap {
		newGap = half
	}
	oldLen := len(b.data)
	newLen := oldLen + newGap - b.gapSize() + needed

	newData := make([]byte, newLen)
	copy(newData[:b.gapStart], b.data[:b.gapStart])
	afterGapLen := oldLen - b.gapEnd
	newGapEnd := newLen - afterGapLen
	copy(newData[newGapEnd:], b.data[b.gapEnd:])

	b.data = newData
	b.gapEnd = newGapEnd
}

// rebuildLineStarts recalculates line start positions.
func (b *Buffer) rebuildLineStarts() {
	b.lineStarts = b.lineStarts[:0]
	b.lineStarts = append(b.lineStarts, 0)
	total := b.Length()
	for i := range total {
		if b.ByteAt(i) == '\n' {
			b.lineStarts = append(b.lineStarts, i+1)
		}
	}
}
