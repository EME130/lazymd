package demo

import (
	"embed"
	"io/fs"
	"os"
	"path/filepath"
)

//go:embed vault
var vaultFS embed.FS

// CreateVault extracts the embedded demo vault to a temp directory.
func CreateVault() (string, error) {
	tmpDir, err := os.MkdirTemp("", "lm-demo-*")
	if err != nil {
		return "", err
	}

	err = fs.WalkDir(vaultFS, "vault", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		rel, err := filepath.Rel("vault", path)
		if err != nil {
			return err
		}
		if rel == "." {
			return nil
		}

		target := filepath.Join(tmpDir, rel)

		if d.IsDir() {
			return os.MkdirAll(target, 0o755)
		}

		data, err := vaultFS.ReadFile(path)
		if err != nil {
			return err
		}
		return os.WriteFile(target, data, 0o644)
	})

	if err != nil {
		os.RemoveAll(tmpDir)
		return "", err
	}

	return tmpDir, nil
}

// CleanupVault removes a previously created demo vault.
func CleanupVault(path string) {
	os.RemoveAll(path)
}
