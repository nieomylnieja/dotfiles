package main

import (
	"context"
	"fmt"
	"os"

	"github.com/nieomylnieja/aicommit/internal"
)

func main() {
	handler := internal.NewRootHandler()
	if err := handler.Run(context.Background()); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
