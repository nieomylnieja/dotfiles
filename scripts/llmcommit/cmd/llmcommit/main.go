package main

import (
	"context"
	"flag"
	"fmt"
	"os"

	"github.com/nieomylnieja/llmcommit/internal"
)

func main() {
	flag.Usage = func() {
		fmt.Fprintln(flag.CommandLine.Output(), "Usage: llmcommit [--] [path...]")
		fmt.Fprintln(flag.CommandLine.Output(), "\nSelect staged files that match the given Git pathspecs.")
		fmt.Fprintln(flag.CommandLine.Output(), "Without paths, select from all staged files.")
	}
	flag.Parse()

	handler := internal.NewRootHandler()
	if err := handler.Run(context.Background(), flag.Args()...); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
