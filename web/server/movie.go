package server

import (
	"net/http"
	"strconv"

	"appengine"
	"appengine/datastore"
)

type movie struct {
	Version int
	Speed   float64 // frames per second
	Width   int
	Height  int
	Palette []byte
	Frames  []string `datastore:",noindex"`
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

func loadMovie(w http.ResponseWriter, r *http.Request) (out *movie, id int64, ok bool) {
	c := appengine.NewContext(r)

	idString := r.FormValue("id")
	id, err := strconv.ParseInt(idString, 10, 64)
	if err != nil {
		c.Debugf("can't parse id: %#v", idString)
		http.Error(w, "can't parse id", http.StatusBadRequest)
		return nil, 0, false
	}

	k := datastore.NewKey(c, "Movie", "", id, nil)

	c.Debugf("calling Get")
	var m movie
	err = datastore.Get(c, k, &m)
	c.Debugf("Get returned error=%v", err)

	if err != nil {
		http.Error(w, "can't load data", http.StatusBadRequest)
		return nil, 0, false
	}

	if m.Palette == nil {
		m.Palette = standardPalette
	}

	return &m, id, true
}
