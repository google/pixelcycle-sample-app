package server

type movie struct {
	Version int
	Speed   float64 // frames per second
	Width   int
	Height  int
	Frames  []string `datastore:",noindex"`
}
