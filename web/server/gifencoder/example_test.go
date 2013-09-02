package gifencoder

import (
	"bytes"
	"fmt"
	"image"
	"image/color"
	"image/gif"
)

func Example1By1Gif() {
	frame := image.NewPaletted(image.Rect(0, 0, 1, 1), color.Palette{color.Black})
	frames := []*image.Paletted{frame}
	before := gif.GIF{frames, []int{0}, 1}

	var buf bytes.Buffer
	if err := EncodeAll(&buf, before); err != nil {
		panic(err)
	}

	gifBytes := buf.Bytes()

	fmt.Printf("header: % x\n", gifBytes[0:6])
	fmt.Printf("dimensions: % x\n", gifBytes[6:13])
	fmt.Printf("palette: % x\n", gifBytes[13:19])
	fmt.Printf("start image: % x\n", gifBytes[19:30])
	fmt.Printf("lzw: % x\n", gifBytes[30:33])
	fmt.Printf("trailer: % x\n", gifBytes[33:])

	buf.Write(gifBytes)

	after, err := gif.DecodeAll(bytes.NewReader(gifBytes))
	if err != nil {
		panic(err)
	}
	fmt.Printf("\nimage count: %v\n", len(after.Image))
	fmt.Printf("bounds: %v\n", after.Image[0].Bounds())
	r, g, b, a := after.Image[0].At(0, 0).RGBA()
	fmt.Printf("pixel: %v,%v,%v,%v\n", r, g, b, a)

	// Output:
	// header: 47 49 46 38 39 61
	// dimensions: 01 00 01 00 f0 00 00
	// palette: 00 00 00 00 00 00
	// start image: 2c 00 00 00 00 01 00 01 00 00 02
	// lzw: 01 28 00
	// trailer: 3b
	//
	// image count: 1
	// bounds: (0,0)-(1,1)
	// pixel: 0,0,0,65535
}

func ExampleTwoFrameAnimation() {
	palette := color.Palette{color.Black, color.White}
	bounds := image.Rect(0, 0, 2, 1)

	frame1 := image.NewPaletted(bounds, palette)
	frame1.SetColorIndex(1, 0, 1)

	frame2 := image.NewPaletted(bounds, palette)
	frame2.SetColorIndex(0, 0, 1)

	frames := []*image.Paletted{frame1, frame2}
	before := gif.GIF{frames, []int{10, 20}, 0xcafe}

	var buf bytes.Buffer
	if err := EncodeAll(&buf, before); err != nil {
		panic(err)
	}
	gifBytes := buf.Bytes()

	fmt.Printf("header: % x\n", gifBytes[0:6])
	fmt.Printf("dimensions: % x\n", gifBytes[6:13])
	fmt.Printf("palette: % x\n", gifBytes[13:19])
	fmt.Printf("loop count: % x\n", gifBytes[19:38])

	after, err := gif.DecodeAll(bytes.NewReader(gifBytes))
	if err != nil {
		panic(err)
	}

	fmt.Printf("\nimage count: %v\n", len(after.Image))
	fmt.Printf("bounds: %v\n", after.Image[0].Bounds())
	r, g, b, a := after.Image[0].At(0, 0).RGBA()
	fmt.Printf("left pixel(0): %v,%v,%v,%v\n", r, g, b, a)

	// Output:
	// header: 47 49 46 38 39 61
	// dimensions: 02 00 01 00 f0 00 00
	// palette: 00 00 00 ff ff ff
	// loop count: 21 ff 0b 4e 45 54 53 43 41 50 45 32 2e 30 03 01 fe ca 00
	//
	// image count: 2
    // bounds: (0,0)-(2,1)
    // left pixel(0): 0,0,0,65535
}
