package server

import (
	"bytes"
	"encoding/json"
	"image/color"
	"net/http"
	"strconv"
	"strings"

	"appengine"
	"appengine/datastore"
)

const standardWidth = 60
const standardHeight = 36
const standardFrames = 8

// using ascii non-control chars for version 2 pixels
const startColorChar = 33
const stopColorChar = 127
const maxColors = stopColorChar - startColorChar

type movie struct {
	Version int
	Speed   float64 // frames per second
	Width   int
	Height  int
	Palette []byte
	// in version 1, frames are JSON arrays of ints
	// in version 2, pixels are ascii non-control characters; subtract startColorChar for palette index
	Frames []string `datastore:",noindex"`
}

func (m *movie) palette() color.Palette {
	in := m.Palette
	if len(in) == 0 {
		in = standardPalette
	}
	out := color.Palette{}
	for i := 0; i < len(in); i += 3 {
		out = append(out, color.RGBA{in[i], in[i+1], in[i+2], 255})
	}
	return out
}

func (m *movie) normalize(c appengine.Context) {

	if m.Palette != nil && bytes.Equal(m.Palette, standardPalette) {
		m.Palette = nil
	}

	if m.Speed < 0 {
		c.Debugf("normalize reversed speed")
		// GIF format doesn't handle negative speeds
		m.Speed = -m.Speed
		reverse(m.Frames)
	} else if m.Speed == 0 {
		c.Debugf("set non-zero speed")
		// choose an arbitrary default
		m.Speed = 10
	}

	if m.Version == 1 {
		c.Debugf("upgrade from version 1 to 2")
		for i, f := range m.Frames {
			var pix []byte
			json.Unmarshal([]byte(f), &pix)
			for i := range pix {
				pix[i] = pix[i] + 33
			}
			m.Frames[i] = string(pix)
		}
		m.Version = 2
	}
}

func parseIdParam(w http.ResponseWriter, r *http.Request) (id int64, ok bool) {
	c := appengine.NewContext(r)

	path := r.URL.Path
	lastSlash := strings.LastIndex(path, "/")
	if lastSlash == -1 {
		sendError(c, w, "id not found in path")
		return 0, false
	}

	idString := path[lastSlash+1:]
	id, err := strconv.ParseInt(idString, 10, 64)
	if err != nil {
		c.Debugf("can't parse id: %#v", idString)
		http.Error(w, "can't parse id", http.StatusBadRequest)
		return 0, false
	}

	return id, true
}

func loadMovie(w http.ResponseWriter, r *http.Request, id int64) (out *movie, ok bool) {
	c := appengine.NewContext(r)

	k := datastore.NewKey(c, "Movie", "", id, nil)

	c.Debugf("calling Get")
	var m movie
	err := datastore.Get(c, k, &m)
	c.Debugf("Get returned error=%v", err)

	if err != nil {
		http.Error(w, "can't load data", http.StatusBadRequest)
		return nil, false
	}

	// normalize

	m.normalize(c)
	return &m, true
}

func reverse(l []string) {
	i := 0
	j := len(l) - 1
	for i < j {
		l[j], l[i] = l[i], l[j]
		i++
		j--
	}
}
