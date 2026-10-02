package main

import (
	"errors"
	"strings"
	"testing"
)

func TestSourceClassification(t *testing.T) {
	for _, test := range []struct {
		name, source string
		entrypoint   bool
		unknown      bool
	}{
		{"entrypoint with dangerous init", "package main\nfunc init(){ panic(\"do not run\") }; func main(){}", true, false},
		{"build constrained entrypoint", "//go:build impossible\n\npackage main\nfunc main(){}", true, false},
		{"package name in comment", "package helper\n// package main\nfunc main(){}", false, false},
		{"function name in string", "package main\nconst example = `func main(){}`", false, false},
		{"method named main", "package main\ntype T struct{}; func (T) main(){}", false, false},
		{"main package helper", "package main\nfunc helper(){}", false, false},
		{"invalid signature", "package main\nfunc main(a int){}", false, true},
		{"result signature", "package main\nfunc main() int{return 0}", false, true},
		{"generic signature", "package main\nfunc main[T any](){}", false, true},
		{"declaration without body", "package main\nfunc main()", false, true},
		{"duplicate main", "package main\nfunc main(){}; func main(){}", false, true},
		{"malformed main", "package main\nfunc main(){", false, true},
		{"malformed library", "package helper\nfunc helper(){", false, true},
		{"invalid encoding", "package main\n\xff", false, true},
	} {
		t.Run(test.name, func(t *testing.T) {
			entrypoint, err := inspect(strings.NewReader(test.source))
			if entrypoint != test.entrypoint || (err != nil) != test.unknown {
				t.Fatalf("entrypoint=%v err=%v; want entrypoint=%v unknown=%v", entrypoint, err, test.entrypoint, test.unknown)
			}
		})
	}
}

type failedReader struct{}

func (failedReader) Read([]byte) (int, error) { return 0, errors.New("read failed") }

func TestIncompleteSource(t *testing.T) {
	if entrypoint, err := inspect(failedReader{}); entrypoint || err == nil {
		t.Fatal("reader failure must remain unknown")
	}
	const limit = 4 << 20
	base := "package main\nfunc main(){}\n"
	complete := base + strings.Repeat(" ", limit-len(base))
	if entrypoint, err := inspect(strings.NewReader(complete)); !entrypoint || err != nil {
		t.Fatalf("exact source limit should be observed: %v", err)
	}
	if entrypoint, err := inspect(strings.NewReader(complete + " ")); entrypoint || err == nil {
		t.Fatal("oversized source must not be classified from a prefix")
	}
}
