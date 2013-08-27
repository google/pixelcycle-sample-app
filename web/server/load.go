package server

import (
	"encoding/json"
	"net/http"
	"strconv"

	"appengine"
	"appengine/datastore"
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

	idString := r.FormValue("id")
	id, err := strconv.ParseInt(idString, 10, 64)
	if err != nil {
		c.Debugf("can't parse id: %#v", idString)
		http.Error(w, "can't parse id", http.StatusBadRequest)
		return
	}

	k := datastore.NewKey(c, "Movie", "", id, nil)
	var m movie

	c.Debugf("calling Get")
	err = datastore.Get(c, k, &m)
	c.Debugf("Get returned error=%v", err)

	if err != nil {
		c.Errorf("can't load movie: %v", err)
		http.Error(w, "can't load movie", http.StatusServiceUnavailable)
		return
	}

	data, err := json.Marshal(&m)
	if err != nil {
		c.Debugf("can't marshal JSON: %v", err)
		http.Error(w, "can't encode movie", http.StatusBadRequest)
		return
	}

	w.Header().Add("Content-Type", "text/json") // not correct but needed by Dart
	_, err = w.Write(data)
	if err != nil {
		c.Errorf("can't write json to client: %v", err)
	}
}
