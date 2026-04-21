# Interface Design

Where to define Go interfaces: consumer side vs producer side,
when to create interfaces, and how to keep them small.

## Core Rule: Consumer Defines the Interface

**Define interfaces in the consumer package, not the producer.**
This is the single most important interface rule in Go.
The consumer knows what behavior it needs —
the producer should not dictate abstractions for all possible callers.

Go's implicit interface satisfaction makes this natural:
the concrete type never references the interface,
so the interface can live wherever it is used.

```go
// RIGHT — consumer defines only what it needs:
package orderservice

type PaymentProcessor interface {
    Charge(ctx context.Context, amount int) error
}

func PlaceOrder(ctx context.Context, p PaymentProcessor, items []Item) error {
    total := calculateTotal(items)
    return p.Charge(ctx, total)
}
```

```go
// WRONG — producer forces an interface on all consumers:
package payment

type Processor interface {
    Charge(ctx context.Context, amount int) error
    Refund(ctx context.Context, id string) error
    ListTransactions(ctx context.Context) ([]Tx, error)
}

func NewProcessor() Processor { return &stripeProcessor{} }
```

The producer should return a concrete type.
Each consumer then defines a narrow interface
covering only the methods it actually calls.

**Do not define interfaces before they are used.**
Without a realistic consumer, it is impossible to know
whether an interface is necessary or what methods it should contain.
Abstractions should be discovered, not invented up front.

**Do not define interfaces on the producer side "for mocking".**
Design the API so that it can be tested using the public API
of the real implementation.
If a consumer needs a mock, it defines its own interface —
that is the consumer's concern, not the producer's.

**Keep interfaces small.**
One or two methods is the sweet spot.
The bigger the interface, the weaker the abstraction —
fewer types can satisfy a large interface,
which defeats the purpose.

## When the Producer MAY Define the Interface

There are narrow, well-established exceptions.
Apply them only when the conditions clearly hold —
default to consumer-side placement.

**1. Multiple unexported implementations behind a constructor.**
When a constructor returns different concrete types
depending on runtime conditions (e.g., hardware support),
it must return an interface because the concrete types are unexported.
The `cipher.Block` / `aes.NewCipher` pattern is the canonical example:

```go
// crypto/aes
func NewCipher(key []byte) (cipher.Block, error) {
    if supportsAES && supportsGFMUL {
        return &aesCipherGCM{c}, nil
    }
    return &c, nil
}
```

**2. Interface-only "standard" packages.**
A package whose sole purpose is to define a shared contract
that many producers implement and many consumers accept.
Examples: `hash.Hash`, `encoding.BinaryMarshaler`, `fmt.Stringer`.
These work because the interfaces are tiny, stable,
and represent a widely agreed-upon abstraction.

**3. A type exists only to implement the interface.**
Per Effective Go: if a type will never have exported methods
beyond those of the interface, there is no need to export the type.
Return the interface instead.
Example: `rand.NewSource` returns `rand.Source`;
the underlying `rngSource` struct is unexported.

## Rules of Thumb

<!-- markdownlint-disable MD013 -->
| Signal                                                   | Placement                   |
| -------------------------------------------------------- | --------------------------- |
| One consumer or a few consumers with different needs     | Consumer side               |
| Interface has > 2 methods                                | Consumer side (split it)    |
| Multiple unexported implementations behind a constructor | Producer side               |
| Shared standard contract (`hash.Hash`) across packages   | Separate interface-only pkg |
| You want mocking in tests                                | Consumer side — always      |
| You are unsure                                           | Consumer side               |
<!-- markdownlint-enable MD013 -->

## Sources

<!-- markdownlint-disable MD013 -->
- [Go Wiki: CodeReviewComments — Interfaces](https://go.dev/wiki/CodeReviewComments#interfaces) —
  official Go project guidance on interface placement
- [Effective Go — Generality](https://go.dev/doc/effective_go#generality) —
  when to return an interface vs a concrete type
- [Exposing interfaces in Go — Efe Karakus](https://www.efekarakus.com/golang/2019/12/29/working-with-interfaces-in-go.html) —
  std lib examples of producer-side exceptions
- [7 Common Interface Mistakes in Go — Andrei Boar](https://medium.com/@andreiboar/7-common-interface-mistakes-in-go-1d3f8e58be60) —
  anti-patterns and common pitfalls
- [Define interfaces in the consumer package — devtrovert](https://blog.devtrovert.com/p/go-ep2-define-interfaces-in-the-consumer) —
  consumer-side pattern walkthrough
<!-- markdownlint-enable MD013 -->
