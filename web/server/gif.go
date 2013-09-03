package server

import (
	"bytes"
	"image"
	"image/gif"
	"net/http"
	"strconv"
	"time"

	"server/gifencoder"

	"appengine"
	"appengine/memcache"
)

const pixelsize = 6

func init() {
	http.HandleFunc("/gif/", gifHandler)
}

func gifHandler(w http.ResponseWriter, r *http.Request) {
	c := appengine.NewContext(r)

	if r.Method != "GET" {
		c.Debugf("not a GET")
		w.Header().Set("Allow", "GET")
		http.Error(w, "not a GET", http.StatusMethodNotAllowed)
		return
	}

	id, ok := parseIdParam(w, r)
	if !ok {
		return
	}

	// try memcache

	memId := gifMemId(id)
	if item, err := memcache.Get(c, memId); err == nil {
		sendGif(c, w, item.Value)
		return
	}
	c.Debugf("cache miss for %v", memId)

	// try datastore

	m, ok := loadMovie(w, r, id)
	if !ok {
		return
	}

	gif, err := makeGif(m)
	if err != nil {
		c.Errorf("can't create gif for %v: %v", id, err)
		http.Error(w, "can't create gif", http.StatusInternalServerError)
		return
	}

	cacheGif(c, id, gif)
	sendGif(c, w, gif)
}

func makeGif(m *movie) ([]byte, error) {
	palette := m.palette()

	delay := int(100 / m.Speed)

	anim := gif.GIF{LoopCount: 0}
	for _, pix := range m.Frames {

		bounds := image.Rect(0, 0, m.Width*pixelsize, m.Height*pixelsize)
		scaled := make([]byte, bounds.Max.X*bounds.Max.Y)
		idx := 0
		for y := 0; y < m.Height; y++ {
			for i := 0; i < pixelsize; i++ {
				for x := 0; x < m.Width; x++ {
					pixel := pix[x+y*m.Width] - startColorChar
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
	err := gifencoder.EncodeAll(&buf, anim)
	return buf.Bytes(), err
}

func gifMemId(id int64) string {
	return "gif-" + strconv.FormatInt(id, 10)
}

func cacheGif(c appengine.Context, id int64, gif []byte) error {
	memId := gifMemId(id)
	item := &memcache.Item{
		Key:   memId,
		Value: gif,
	}
	err := memcache.Set(c, item)
	if err != nil {
		c.Warningf("can't write %v to memcache: %v", memId, err)
	}
	return err
}

var maxAge = strconv.Itoa(int((24 * time.Hour).Seconds()))

func sendGif(c appengine.Context, w http.ResponseWriter, bytes []byte) {
	w.Header().Set("Content-Type", "image/gif")
	w.Header().Set("Cache-Control", "max-age="+maxAge)
	if _, err := w.Write(bytes); err != nil {
		c.Debugf("can't write HTTP response: %v", err)
	}
}

var standardPalette = []byte{
	0, 0, 0, 51, 51, 51, 102, 102, 102, 204, 102, 102,
	204, 127, 102, 204, 153, 102, 204, 178, 102, 204, 204, 102,
	171, 204, 102, 102, 204, 102, 102, 204, 169, 102, 204, 204,
	102, 170, 204, 102, 136, 204, 102, 102, 204, 135, 102, 204,
	170, 102, 204, 204, 102, 204, 204, 102, 153, 153, 153, 153,
	204, 204, 204, 255, 255, 255, 255, 0, 0, 255, 63, 0,
	255, 127, 0, 255, 191, 0, 255, 255, 0, 171, 255, 0,
	0, 255, 0, 0, 255, 169, 0, 255, 255, 0, 170, 255,
	0, 85, 255, 0, 0, 255, 84, 0, 255, 170, 0, 255,
	255, 0, 255, 255, 0, 128, 51, 0, 0, 51, 51, 0,
	0, 51, 0, 191, 0, 0, 191, 47, 0, 191, 95, 0,
	191, 143, 0, 191, 191, 0, 128, 191, 0, 0, 191, 0,
	0, 191, 127, 0, 191, 191, 0, 128, 191, 0, 64, 191,
	0, 0, 191, 63, 0, 191, 127, 0, 191, 191, 0, 191,
	191, 0, 96, 0, 51, 51, 0, 0, 51, 51, 0, 51,
	127, 0, 0, 127, 31, 0, 127, 63, 0, 127, 95, 0,
	127, 127, 0, 85, 127, 0, 0, 127, 0, 0, 127, 84,
	0, 127, 127, 0, 85, 127, 0, 42, 127, 0, 0, 127,
	42, 0, 127, 85, 0, 127, 127, 0, 127, 127, 0, 64,
}
