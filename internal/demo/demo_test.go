package demo

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCreateVault(t *testing.T) {
	path, err := CreateVault()
	if err != nil {
		t.Fatalf("CreateVault failed: %v", err)
	}
	defer CleanupVault(path)

	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("vault dir not found: %v", err)
	}
	if !info.IsDir() {
		t.Fatal("expected vault path to be a directory")
	}

	expectedFiles := []string{
		"welcome.md",
		"project-plan.md",
		"kanban.md",
		"knowledge/golang.md",
		"knowledge/markdown.md",
		"knowledge/wiki-links.md",
		"knowledge/zettelkasten.md",
		"daily-notes/2026-03-15.md",
	}
	for _, f := range expectedFiles {
		p := filepath.Join(path, f)
		if _, err := os.Stat(p); err != nil {
			t.Errorf("expected file %s not found: %v", f, err)
		}
	}
}

func TestCreateVaultContent(t *testing.T) {
	path, err := CreateVault()
	if err != nil {
		t.Fatalf("CreateVault failed: %v", err)
	}
	defer CleanupVault(path)

	data, err := os.ReadFile(filepath.Join(path, "welcome.md"))
	if err != nil {
		t.Fatalf("failed to read welcome.md: %v", err)
	}
	if len(data) == 0 {
		t.Fatal("welcome.md is empty")
	}
}

func TestCleanupVault(t *testing.T) {
	path, err := CreateVault()
	if err != nil {
		t.Fatalf("CreateVault failed: %v", err)
	}

	CleanupVault(path)

	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Errorf("expected vault dir to be removed, but it still exists")
	}
}
