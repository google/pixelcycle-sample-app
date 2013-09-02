package server

import (
	"fmt"
	"net/http"

	"appengine"
)

func sendError(c appengine.Context, w http.ResponseWriter, format string, args ...interface{}) {
	msg := fmt.Sprintf(format, args...)
	c.Errorf("%v", msg)
	http.Error(w, msg, http.StatusBadRequest)
}
