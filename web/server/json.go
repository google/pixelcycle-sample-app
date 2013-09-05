package server

import (
	"encoding/json"
	"net/http"
	"strconv"

	"appengine"
	"appengine/memcache"
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

	// try memcache

	memId := jsonMemId(id)
	if item, err := memcache.Get(c, memId); err == nil {
		sendJson(c, w, item.Value)
		return
	}
	c.Debugf("cache miss for %v", memId)

	// try datastore

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

	cacheJson(c, id, data)
	sendJson(c, w, data)
}

func jsonMemId(id int64) string {
	return "json-" + strconv.FormatInt(id, 10)
}

func cacheJson(c appengine.Context, id int64, data []byte) error {
	memId := jsonMemId(id)
	item := &memcache.Item{
		Key:   memId,
		Value: data,
	}
	err := memcache.Set(c, item)
	if err != nil {
		c.Warningf("can't write %v to memcache: %v", memId, err)
	}
	return err
}

func sendJson(c appengine.Context, w http.ResponseWriter, data []byte) {
	w.Header().Add("Content-Type", "application/json")
	_, err := w.Write(data)
	if err != nil {
		c.Debugf("can't write json to client: %v", err)
	}
}
