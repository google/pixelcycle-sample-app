package gifencoder

import (
	"bytes"
	"compress/lzw"
	"encoding/binary"
	"errors"
	"fmt"
	"image"
	"image/color"
	"image/gif"
	"io"
)

// EncodeAll writes all the frames in a gif.GIF struct to a GIF file.
// If there is more than one frame, it will be an animated GIF.
func EncodeAll(w io.Writer, m gif.GIF) error {

	if len(m.Image) < 1 {
		return errors.New("creating a gif with zero images isn't implemented")
	}

	// Determine a logical size that contains all images.
	var sizeX, sizeY int
	for _, img := range m.Image {
		if img.Rect.Max.X > sizeX {
			sizeX = img.Rect.Max.X
		}
		if img.Rect.Max.Y > sizeY {
			sizeY = img.Rect.Max.Y
		}
	}

	if sizeX >= (1<<16) || sizeY >= (1<<16) {
		return fmt.Errorf("logical size too large: (%v,%v)", sizeX, sizeY)
	}

	// Arbitrarily make the first image's palette global.
	globalPalette, colorBits, err := encodePalette(w, m.Image[0].Palette)
	if err != nil {
		return err
	}

	// header
	if err := writeData(w,
		[]byte("GIF89a"),
		uint16(sizeX), uint16(sizeY),
		byte(0xF0|colorBits-1),
		byte(0), byte(0),
		globalPalette,
	); err != nil {
		return err
	}

	// only write loop count for animations
	if len(m.Image) > 1 {
		if err := writeData(w,
			[]byte{0x21, 0xff, 0x0b},
			[]byte("NETSCAPE2.0"),
			[]byte{3, 1},
			uint16(m.LoopCount),
			byte(0),
		); err != nil {
			return err
		}
	}

	for i, img := range m.Image {
		// write delay block
		if i < len(m.Delay) && m.Delay[i] != 0 {
			err = writeData(w,
				[]byte{0x21, 0xf9, 4, 0},
				uint16(m.Delay[i]),
				[]byte{0, 0},
			)
			if err != nil {
				return err
			}
		}

		localPalette, _, err := encodePalette(w, img.Palette)
		if err != nil {
			return err
		}

		if !bytes.Equal(globalPalette, localPalette) {
			return errors.New("different palettes not implemented")
		}

		if err := encodeImageBlock(w, img); err != nil {
			return err
		}
	}

	// add trailer
	_, err = w.Write([]byte{byte(0x3b)})
	return err
}

// EncodePalette converts an image palette to a byte array using
// three bytes per color. (It ignores the alpha channel.)
func encodePalette(w io.Writer, palette color.Palette) ([]byte, uint, error) {

	bits := paletteBits(palette)
	if bits > 8 {
		return nil, 0, fmt.Errorf("palette too large: %v", len(palette))
	}

	var buf bytes.Buffer

	for _, c := range palette {
		r, g, b, _ := c.RGBA()
		buf.WriteByte(byte(r >> 8))
		buf.WriteByte(byte(g >> 8))
		buf.WriteByte(byte(b >> 8))
	}

	paddingColors := (1 << bits) - len(palette)
	buf.Write(make([]byte, paddingColors*3))

	return buf.Bytes(), bits, nil
}

func paletteBits(palette color.Palette) uint {
	b := log2(len(palette))
	if b < 1 {
		return 1
	}
	return b
}

// Log2 returns the number of bits needed to represent numbers from 0 to n-1.
func log2(n int) uint {
	n--
	count := uint(0)
	for n > 0 {
		count++
		n = n >> 1
	}
	return count
}

func encodeImageBlock(w io.Writer, img *image.Paletted) error {

	// start image

	litWidth := int(paletteBits(img.Palette))
	if litWidth < 2 {
		litWidth = 2
	}

	bounds := img.Bounds()

	if err := writeData(w,
		byte(0x2C),
		uint16(bounds.Min.X), uint16(bounds.Min.Y), uint16(bounds.Dx()), uint16(bounds.Dy()),
		byte(0),
		byte(litWidth),
	); err != nil {
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

func writeData(w io.Writer, data ...interface{}) error {
	for _, v := range data {
		err := binary.Write(w, binary.LittleEndian, v)
		if err != nil {
			return err
		}
	}
	return nil
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

var alreadyClosed = errors.New("already closed")

// Close writes any buffered data to the Writer as a block with length < 255
// (if needed), followed by a zero-length block to terminate.
func (b *blockWriter) Close() error {
	if b.err != nil {
		return b.err
	}

	// precondition: b.buf[0] != 255
	n := int(b.buf[0])
	if n == 0 {
		n++ // no short block needed, just terminate
	} else {
		b.buf[n+1] = 0 // append terminator
		n += 2
	}

	n2, err := b.w.Write(b.buf[0:n])
	if n2 < n && err == nil {
		err = io.ErrShortWrite
	}
	b.buf[0] = 0
	b.err = alreadyClosed
	return err
}
