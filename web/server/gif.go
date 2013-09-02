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

	bounds := image.Rect(0, 0, m.Width, m.Height)
	palette := color.Palette {}
	for i := 0; i < len(m.Palette); i+=3 {
		palette = append(palette, color.RGBA{m.Palette[i], m.Palette[i+1], m.Palette[i+2], 255})
	}
	delay := int(100 / m.Speed)

	anim := gif.GIF {LoopCount: 0}

	for _, data := range m.Frames {
		var pix []byte
		json.Unmarshal([]byte(data), &pix)
		
		img := image.Paletted{
			Pix: pix,
			Stride: m.Width,
			Rect: bounds,
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
