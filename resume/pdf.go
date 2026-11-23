// Package resume prints the page to the résumé PDF with headless Chromium, using the print stylesheet.
package resume

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"time"
)

// Browser is the Chromium binary: $CHROMIUM_BIN, or chromium on PATH.
func Browser() string {
	if b := os.Getenv("CHROMIUM_BIN"); b != "" {
		return b
	}
	return "chromium"
}

// Print renders the page at url to a PDF at output.
func Print(ctx context.Context, url, output string) error {
	profile, err := os.MkdirTemp("", "portfolio-pdf-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(profile)
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, Browser(), "--headless", "--no-sandbox", "--disable-gpu", "--no-pdf-header-footer", "--user-data-dir="+profile, "--print-to-pdf="+output, url)
	if data, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("print resume: %w\n%s", err, data)
	}
	return nil
}
