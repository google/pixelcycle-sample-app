package gifencoder

import (
	"compress/lzw"
	"encoding/binary"
	"fmt"
	"image"
	"image/gif"
	"io"
)

func EncodeAll(w io.Writer, m gif.GIF) error {
	if len(m.Image) != 1 {
		panic("not implemented")
	}

	img := m.Image[0]

	// add header

	var data = []interface{}{
		[]byte("GIF89a"),
	}

	logicalSize := img.Rect.Max
	if logicalSize.X >= (1<<16) || logicalSize.Y >= (1<<16) {
		return fmt.Errorf("logical size too large: %v", logicalSize)
	}

	data = append(data,
		uint16(logicalSize.X),
		uint16(logicalSize.Y),
	)

	colorBits := bits(len(img.Palette))
	if colorBits < 1 {
		colorBits = 1
	} else if colorBits > 8 {
		return fmt.Errorf("palette too large: %v", len(img.Palette))
	}

	data = append(data,
		byte(0xF0|colorBits-1), byte(0), byte(0))

	// add palette; ignoring alpha

	for _, c := range img.Palette {
		r, g, b, _ := c.RGBA()
		data = append(data,
			byte(r>>8), byte(g>>8), byte(b>>8),
		)
	}
	paddingColors := (1 << colorBits) - len(img.Palette)
	data = append(data, make([]byte, paddingColors*3))

	if err := writeData(w, data); err != nil {
		return err
	}

	if err := encodeImageBlock(w, img); err != nil {
		return err
	}

	// add trailer
	_, err := w.Write([]byte{byte(0x3b)})
	return err
}

func encodeImageBlock(w io.Writer, img *image.Paletted) error {

	// start image

	colorBits := bits(len(img.Palette))
	litWidth := int(colorBits)
	if litWidth < 2 {
		litWidth = 2
	}

	bounds := img.Bounds()
	data := []interface{}{
		byte(0x2C),
		uint16(bounds.Min.X), uint16(bounds.Min.Y), uint16(bounds.Dx()), uint16(bounds.Dy()),
		byte(0),
		byte(litWidth),
	}

	if err := writeData(w, data); err != nil {
		return err
	}

	// start compression

	blocks := &blockWriter{w: w}
	compress := lzw.NewWriter(blocks, lzw.LSB, litWidth)

	// write each scan line (might not be contiguous)

	startX := img.Rect.Min.X
	stopX := img.Rect.Max.X
	stopY := img.Rect.Max.Y
	for y := img.Rect.Min.Y; y < stopY; y++ {
		start := img.PixOffset(startX, y)
		stop := img.PixOffset(stopX, y)
		if _, err := compress.Write(img.Pix[start:stop]); err != nil {
			return err
		}
	}

	if err := compress.Close(); err != nil {
		return err
	}

	return blocks.Close()
}

func writeData(w io.Writer, data []interface{}) error {
	for _, v := range data {
		err := binary.Write(w, binary.LittleEndian, v)
		if err != nil {
			return err
		}
	}
	return nil
}

// Bits returns the number of bits needed to represent numbers from 0 to n-1.
func bits(n int) uint {
	n--
	count := uint(0)
	for n > 0 {
		count++
		n = n >> 1
	}
	return count
}

// BlockWriter converts a stream of bytes into blocks where each block starts with a one-byte
// length. All blocks except the last will have length 255, and the last block is followed by a
// zero to indicate no more blocks.
//
// If an error occurs writing to the writer, no more data will be accepted and all subsequent
// writes return the error.
type blockWriter struct {
	w   io.Writer
	err error     // non-nil means we've seen an error and gave up writing
	buf [256]byte // first byte stores the length
}

// Write adds some input to the buffer and returns the number of bytes written,
// which will always be len(input) unless there's an error. Any blocks written
// to the underlying Writer will have length 255.
func (b *blockWriter) Write(input []byte) (int, error) {
	if b.err != nil {
		return 0, b.err
	}

	// fill buffer if possible
	n := b.buf[0] // n is block size
	copied := copy(b.buf[n+1:], input)
	b.buf[0] = n + byte(copied)

	if n+byte(copied) < 255 {
		// buffer not full; don't write yet
		return copied, nil
	}

	// loop precondition: buffer is full
	for {
		var n2 int
		n2, b.err = b.w.Write(b.buf[:])
		if n2 < 256 && b.err == nil {
			b.err = io.ErrShortWrite
		}
		if b.err != nil {
			return copied, b.err
		}

		n := copy(b.buf[1:], input[copied:])
		b.buf[0] = byte(n)
		copied += n
		if n < 255 {
			// buffer not full
			return copied, nil
		}
	}

	// postcondition: b.buf contains a block with n < 255, or b.err is set
}

// Close writes any buffered data to the Writer as a block with length < 255,
// followed by a zero-length block to terminate.
func (b *blockWriter) Close() error {
	if b.err != nil {
		return b.err
	}

	n := b.buf[0]
	b.buf[n+1] = 0 // terminate block stream

	var n2 int
	n2, b.err = b.w.Write(b.buf[0 : n+2])
	if n2 < int(n)+2 && b.err == nil {
		b.err = io.ErrShortWrite
	}
	b.buf[0] = 0
	return b.err
}
