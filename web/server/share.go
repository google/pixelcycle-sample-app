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
