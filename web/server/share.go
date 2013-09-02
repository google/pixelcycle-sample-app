package server

import (
	"encoding/json"
	"fmt"
	"net/http"

	"appengine"
	"appengine/datastore"
)

func init() {
	http.HandleFunc("/_share", shareHandler)
}

func shareHandler(w http.ResponseWriter, r *http.Request) {
	c := appengine.NewContext(r)

	if r.Method != "POST" {
		c.Debugf("not a POST")
		w.Header().Set("Allow", "POST")
		http.Error(w, "not a POST", http.StatusMethodNotAllowed)
		return
	}

	decoder := json.NewDecoder(r.Body)
	var m movie
	err := decoder.Decode(&m)
	if err != nil {
		c.Debugf("can't parse JSON: %v", err)
		http.Error(w, "can't parse JSON", http.StatusBadRequest)
		return
	}

	// Validate

	if m.Version != 2 {
		sendError(c, w, "version not implemented: %v", m.Version)
		return
	}

	if m.Speed < -60 || m.Speed > 60 {
		sendError(c, w, "frame rate out of range: %v", m.Speed)
		return
	}

	if m.Width != standardWidth || m.Height != standardHeight {
		sendError(c, w, "frame size is unsupported: (%v,%v)", m.Width, m.Height)
		return
	}

	if len(m.Palette)%3 != 0 || len(m.Palette) > (maxColors*3) {
		sendError(c, w, "palette is wrong size: %v", len(m.Palette))
		return
	}

	colors := len(standardPalette) / 3
	if len(m.Palette) > 0 {
		colors = len(m.Palette) / 3
	}

	if len(m.Frames) != standardFrames {
		sendError(c, w, "nonstandard number of frames: %v", len(m.Palette))
		return
	}

	for fnum, f := range m.Frames {
		if len(f) != standardWidth*standardHeight {
			sendError(c, w, "wrong number of pixels for frame %v: %v", fnum, len(f))
			return
		}
		for _, p := range f {
			if p < startColorChar || p >= rune(startColorChar+colors) {
				sendError(c, w, "pixel out of range in frame %v", fnum)
				return
			}
		}
	}

	// Save

	k := datastore.NewIncompleteKey(c, "Movie", nil)
	c.Debugf("calling Put")
	k, err = datastore.Put(c, k, &m)
	c.Debugf("Put returned error=%v", err)

	if err != nil {
		c.Errorf("can't save movie: %v", err)
		http.Error(w, "can't save movie", http.StatusServiceUnavailable)
		return
	}

	fmt.Fprintf(w, "/m%v", k.IntID())
}
