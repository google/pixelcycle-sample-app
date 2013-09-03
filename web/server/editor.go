package server

import (
	"fmt"
	"html/template"
	"net/http"
	"regexp"
)

var moviePattern = regexp.MustCompile("^/m([0-9]+)$")

var editorPage *template.Template

func init() {
	http.HandleFunc("/", editorHandler)
	var err error
	editorPage, err = template.ParseFiles("pixelcycle2.html")
	if err != nil {
		panic(fmt.Sprintf("can't load editorPage template: %v", err))
	}
}

func editorHandler(w http.ResponseWriter, r *http.Request) {
	imageUrl := ""

	groups := moviePattern.FindStringSubmatch(r.URL.Path)
	if groups != nil {
		id := groups[1]
		imageUrl = "/gif/" + id
	}

	w.Header().Set("Content-Type", "text/html")
	editorPage.Execute(w, imageUrl)
}
