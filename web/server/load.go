package server

import (
	"encoding/json"
	"net/http"

	"appengine"
)

func init() {
	http.HandleFunc("/_load", loadHandler)
}

func loadHandler(w http.ResponseWriter, r *http.Request) {
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

	data, err := json.Marshal(&m)
	if err != nil {
		c.Errorf("can't marshal JSON for movie %v: %v", id, err)
		http.Error(w, "can't encode movie", http.StatusBadRequest)
		return
	}

	w.Header().Add("Content-Type", "text/json") // not correct but "text/" is needed by Dart
	_, err = w.Write(data)
	if err != nil {
		c.Debugf("can't write json to client: %v", err)
	}
}
