package server

import (
	"encoding/json"
	"net/http"

	"appengine"
)

func init() {
	http.HandleFunc("/json/", loadHandler)
}

func loadHandler(w http.ResponseWriter, r *http.Request) {
	c := appengine.NewContext(r)

	id, ok := parseIdParam(w, r)
	if !ok {
		return
	}

	m, ok := loadMovie(w, r, id)
	if !ok {
		return
	}

	data, err := json.Marshal(&m)
	if err != nil {
		c.Errorf("can't marshal JSON for movie %v: %v", id, err)
		http.Error(w, "can't encode movie", http.StatusBadRequest)
		return
	}

	w.Header().Add("Content-Type", "application/json")
	_, err = w.Write(data)
	if err != nil {
		c.Debugf("can't write json to client: %v", err)
	}
}
