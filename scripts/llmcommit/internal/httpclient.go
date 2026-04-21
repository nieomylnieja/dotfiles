package internal

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const (
	maxRetries     = 5
	initialBackoff = time.Second
)

// StatusCallback is called before each retry wait with a human-readable status message.
type StatusCallback func(status string)

// RetryClient wraps http.Client with 5xx retry and exponential backoff.
type RetryClient struct {
	client   *http.Client
	onStatus StatusCallback
}

// NewRetryClient creates a RetryClient that reports retry status via onStatus.
func NewRetryClient(onStatus StatusCallback) *RetryClient {
	return &RetryClient{
		client:   http.DefaultClient,
		onStatus: onStatus,
	}
}

// Do executes the request, retrying on 5xx with exponential backoff.
// The request body must be re-readable (e.g. via GetBody) for retries to work.
// Non-5xx errors and client errors are returned immediately.
func (rc *RetryClient) Do(ctx context.Context, req *http.Request) (*http.Response, error) {
	backoff := initialBackoff

	for attempt := range maxRetries {
		resp, err := rc.client.Do(req)
		if err != nil {
			return nil, err
		}

		if resp.StatusCode < http.StatusInternalServerError {
			return resp, nil
		}

		body, readErr := io.ReadAll(resp.Body)
		_ = resp.Body.Close()

		errMsg := fmt.Sprintf("status %d", resp.StatusCode)
		if readErr == nil {
			errMsg = fmt.Sprintf("status %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
		}

		if attempt >= maxRetries-1 {
			return nil, fmt.Errorf("server error after %d attempts: %s", maxRetries, errMsg)
		}

		if rc.onStatus != nil {
			rc.onStatus(fmt.Sprintf("[%d/%d] %s (retrying in %s)", attempt+1, maxRetries, errMsg, backoff))
		}

		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(backoff):
		}
		backoff *= 2

		if req.GetBody != nil {
			newBody, err := req.GetBody()
			if err != nil {
				return nil, fmt.Errorf("resetting request body for retry: %w", err)
			}
			req.Body = newBody
		}
	}
	panic("unreachable")
}
