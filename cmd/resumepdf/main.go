// Generate the downloadable resume from the same template and print stylesheet.
package main

import (
	"context"
	"log"
	"net/http"
	"net/http/httptest"
	"path/filepath"

	"github.com/a-h/templ"
	"portfolio/resume"
	"portfolio/templates"
)

func main() {
	if err := generate(); err != nil {
		log.Fatal(err)
	}
}

func generate() error {
	mux := http.NewServeMux()
	mux.Handle("/", templ.Handler(templates.Page()))
	mux.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))
	server := httptest.NewServer(mux)
	defer server.Close()
	output, err := filepath.Abs("static/resume.pdf")
	if err != nil {
		return err
	}
	if err := resume.Print(context.Background(), server.URL, output); err != nil {
		return err
	}
	log.Printf("Generated %s", output)
	return nil
}
