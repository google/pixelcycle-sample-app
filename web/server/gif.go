package server

import (
	"bytes"
	"encoding/json"
	"image"
	"image/color"
	"image/gif"
	"net/http"

	"server/gifencoder"

	"appengine"
)

const pixelsize = 6

func init() {
	http.HandleFunc("/gif", gifHandler)
}

func gifHandler(w http.ResponseWriter, r *http.Request) {
	c := appengine.NewContext(r)

	if r.Method != "GET" {
		c.Debugf("not a GET")
		w.Header().Set("Allow", "GET")
		http.Error(w, "not a GET", http.StatusMethodNotAllowed)
		return
	}

	m, id, ok := loadMovie(w, r)
	if !ok {
		return
	}

	palette := color.Palette{}
	for i := 0; i < len(m.Palette); i += 3 {
		palette = append(palette, color.RGBA{m.Palette[i], m.Palette[i+1], m.Palette[i+2], 255})
	}
	delay := int(100 / m.Speed)

	anim := gif.GIF{LoopCount: 0}
	for _, data := range m.Frames {
		var pix []byte
		json.Unmarshal([]byte(data), &pix)

		bounds := image.Rect(0, 0, m.Width*pixelsize, m.Height*pixelsize)
		scaled := make([]byte, bounds.Max.X*bounds.Max.Y)
		idx := 0
		for y := 0; y < m.Height; y++ {
			for i := 0; i < pixelsize; i++ {
				for x := 0; x < m.Width; x++ {
					pixel := pix[x+y*m.Width]
					for j := 0; j < pixelsize; j++ {
						scaled[idx] = pixel
						idx++
					}
				}
			}
		}

		img := image.Paletted{
			Pix:     scaled,
			Stride:  m.Width * pixelsize,
			Rect:    bounds,
			Palette: palette,
		}

		anim.Image = append(anim.Image, &img)
		anim.Delay = append(anim.Delay, delay)
	}

	var buf bytes.Buffer
	if err := gifencoder.EncodeAll(&buf, anim); err != nil {
		c.Errorf("can't create gif for %v: %v", id, err)
		http.Error(w, "can't create gif", http.StatusInternalServerError)
	}

	w.Header().Set("Content-Type", "image/gif")
	_, err := buf.WriteTo(w)
	c.Debugf("can't write HTTP response: %v", err)
}
