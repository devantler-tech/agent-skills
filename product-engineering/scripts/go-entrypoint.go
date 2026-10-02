// Parse one source blob without importing, building or executing its package.
package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io"
	"os"
)

func main() {
	entrypoint, err := inspect(os.Stdin)
	if err != nil {
		fmt.Fprintln(os.Stderr, "UNKNOWN: Go source could not be classified:", err)
		os.Exit(2)
	}
	fmt.Println(entrypoint)
}

func inspect(source io.Reader) (bool, error) {
	// A bounded observation refuses oversized source rather than inspecting a prefix.
	const limit = 4 << 20
	data, err := io.ReadAll(io.LimitReader(source, limit+1))
	if err != nil {
		return false, err
	}
	if len(data) > limit {
		return false, fmt.Errorf("source exceeds 4 MiB")
	}
	file, err := parser.ParseFile(token.NewFileSet(), "", data, 0)
	if err != nil {
		return false, err
	}
	if file.Name.Name != "main" {
		return false, nil
	}
	found := false
	for _, declaration := range file.Decls {
		function, ok := declaration.(*ast.FuncDecl)
		if !ok || function.Recv != nil || function.Name.Name != "main" {
			continue
		}
		if found || function.Type.Params.NumFields() != 0 ||
			function.Type.Results.NumFields() != 0 || function.Type.TypeParams.NumFields() != 0 || function.Body == nil {
			return false, fmt.Errorf("main declaration has no unambiguous func main() body")
		}
		found = true
	}
	return found, nil
}
